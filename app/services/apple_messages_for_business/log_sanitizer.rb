# frozen_string_literal: true

module AppleMessagesForBusiness
  # Helper module to sanitize sensitive data (like base64 images) from logs
  module LogSanitizer
    # Sanitize a hash by truncating base64 image data
    # @param data [Hash] The data to sanitize
    # @param max_length [Integer] Maximum length for base64 strings (default: 100)
    # @return [Hash] Sanitized copy of the data
    def self.sanitize_for_log(data, max_length: 100)
      return data unless data.is_a?(Hash)

      data.deep_dup.tap do |sanitized|
        sanitize_hash!(sanitized, max_length)
      end
    end

    # Sanitize base64 data in place
    # @param hash [Hash] The hash to sanitize
    # @param max_length [Integer] Maximum length for base64 strings
    def self.sanitize_hash!(hash, max_length)
      hash.each do |key, value|
        case value
        when Hash
          sanitize_hash!(value, max_length)
        when Array
          value.each { |item| sanitize_hash!(item, max_length) if item.is_a?(Hash) }
        when String
          # Truncate if it looks like base64 data (long string with base64 chars)
          hash[key] = truncate_base64(value, max_length) if looks_like_base64?(value, key)
        end
      end
    end

    # Check if a string looks like base64 encoded data
    # @param value [String] The string to check
    # @param key [Symbol, String] The hash key (helps identify data fields)
    # @return [Boolean]
    def self.looks_like_base64?(value, key)
      return false if value.length < 200 # Short strings are probably not base64 images

      # Check if key suggests it's data (including just "data" which is common in images arrays)
      data_key = key.to_s.match?(/\A(data|image|base64)\z/i) || key.to_s.match?(/data|image|base64/i)

      # Check if value looks like base64 (only contains base64 chars and is long)
      # Base64 typically starts with common image headers like iVBOR (PNG), /9j/ (JPEG), R0lGOD (GIF)
      base64_pattern = value.length > 200 && value.match?(%r{\A[A-Za-z0-9+/]+=*\z})

      # Extra check: if it starts with common image base64 prefixes
      image_prefix = value.match?(%r{\A(iVBORw0KGgo|/9j/|R0lGOD|UklGR)})

      (data_key && base64_pattern) || image_prefix
    end

    # Truncate base64 string with indication of original length
    # @param value [String] The base64 string to truncate
    # @param max_length [Integer] Maximum length to show
    # @return [String] Truncated string with metadata
    def self.truncate_base64(value, _max_length)
      original_kb = (value.length / 1024.0).round(2)
      "[BASE64 #{original_kb}KB]"
    end
  end
end
