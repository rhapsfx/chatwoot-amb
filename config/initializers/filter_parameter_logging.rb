# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [
  :password, :secret, :_key, :auth, :crypt, :salt, :certificate, :otp, :access, :private, :protected, :ssn,
  :otp_secret, :otp_code, :backup_code, :mfa_token, :otp_backup_codes
]

# Regex to filter all occurrences of 'token' in keys except for 'website_token'
filter_regex = /\A(?!.*\bwebsite_token\b).*token/i

# Apply the regex for filtering
Rails.application.config.filter_parameters += [filter_regex]

# Custom parameter filter for heavy data fields (base64 images, large content)
module ParameterFilterHelper
  HEAVY_DATA_KEYS = /\b(data|image|content|file|attachment|base64)\b/i
  MIN_SIZE = 1024 # Only filter data > 1KB

  def self.should_truncate?(key, value)
    value.is_a?(String) &&
      key.to_s.match?(HEAVY_DATA_KEYS) &&
      value.length > MIN_SIZE
  end

  def self.truncate(_key, value)
    size_kb = (value.length / 1024.0).round(2)
    preview_length = 100

    if value.match?(%r{\A[A-Za-z0-9+/]+=*\z})
      "[BASE64 DATA FILTERED - #{size_kb} KB - preview: #{value[0...preview_length]}...]"
    else
      "[LARGE DATA FILTERED - #{size_kb} KB - preview: #{value[0...preview_length]}...]"
    end
  end

  def self.filter_value(key, value)
    case value
    when Hash
      # Recurse into hash, checking each nested key
      value.each_with_object({}) do |(nested_key, nested_value), result|
        result[nested_key] = filter_value(nested_key, nested_value)
      end
    when Array
      # Recurse into array items
      value.map do |item|
        if item.is_a?(Hash)
          # Process each key-value pair in the hash
          item.each_with_object({}) do |(nested_key, nested_value), result|
            result[nested_key] = filter_value(nested_key, nested_value)
          end
        elsif item.is_a?(String)
          # Check if the array item itself should be truncated
          # This handles cases where the key applies to array items
          should_truncate?(key, item) ? truncate(key, item) : item
        else
          item
        end
      end
    when String
      should_truncate?(key, value) ? truncate(key, value) : value
    else
      value
    end
  end
end

# Apply recursive filtering for nested data structures
Rails.application.config.filter_parameters << lambda do |key, value|
  if value.is_a?(Hash)
    value.each do |nested_key, nested_value|
      value[nested_key] = ParameterFilterHelper.filter_value(nested_key, nested_value)
    end
  elsif value.is_a?(Array)
    value.map! do |item|
      if item.is_a?(Hash)
        item.each do |nested_key, nested_value|
          item[nested_key] = ParameterFilterHelper.filter_value(nested_key, nested_value)
        end
        item
      elsif item.is_a?(String)
        ParameterFilterHelper.should_truncate?(key, item) ? ParameterFilterHelper.truncate(key, item) : item
      else
        item
      end
    end
  elsif value.is_a?(String) && ParameterFilterHelper.should_truncate?(key, value)
    value.replace(ParameterFilterHelper.truncate(key, value))
  end
end
