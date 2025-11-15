# frozen_string_literal: true

# Service to sanitize sensitive and heavy data from logs
# Prevents log files from being bloated with large base64 images, file data, etc.
class LogSanitizerService
  # Maximum length for data preview in logs
  DEFAULT_MAX_LENGTH = 100

  # Minimum size (in bytes) before truncation kicks in
  MIN_SIZE_FOR_TRUNCATION = 1024 # 1 KB

  class << self
    # Sanitize a hash by truncating large data fields
    # @param data [Hash, Array, String, Object] The data to sanitize
    # @param max_length [Integer] Maximum length for preview (default: 100)
    # @param aggressive [Boolean] If true, use ultra-minimal output (structure only, no content)
    # @return [Hash, Array, String, Object] Sanitized copy of the data
    def sanitize_for_log(data, max_length: DEFAULT_MAX_LENGTH, aggressive: false)
      # In aggressive mode, show structure only - no content
      return summarize_structure(data) if aggressive

      case data
      when Hash
        sanitize_hash(data, max_length, aggressive)
      when Array
        sanitize_array(data, max_length, aggressive)
      when String
        sanitize_string(data, max_length)
      else
        data
      end
    end

    private

    # Summarize data structure without showing actual content (ultra-aggressive mode)
    # Used for high-frequency job logs to minimize log bloat
    def summarize_structure(data)
      case data
      when Hash
        keys = data.keys
        total_size = calculate_hash_size(data)
        "[HASH: #{keys.length} keys, ~#{format_size(total_size)}]"
      when Array
        total_size = calculate_array_size(data)
        "[ARRAY: #{data.length} items, ~#{format_size(total_size)}]"
      when String
        "[STRING: #{format_size(data.bytesize)}]"
      when Integer, Float, TrueClass, FalseClass, NilClass
        data # Keep primitives as-is
      else
        "[#{data.class.name}]"
      end
    end

    # Calculate approximate size of a hash (for summary)
    def calculate_hash_size(hash)
      hash.to_s.bytesize
    rescue StandardError
      0
    end

    # Calculate approximate size of an array (for summary)
    def calculate_array_size(array)
      array.to_s.bytesize
    rescue StandardError
      0
    end

    # Format byte size for human readability
    def format_size(bytes)
      if bytes < 1024
        "#{bytes}B"
      elsif bytes < 1024 * 1024
        "#{(bytes / 1024.0).round(1)}KB"
      else
        "#{(bytes / (1024.0 * 1024.0)).round(1)}MB"
      end
    end

    # Sanitize a hash recursively
    def sanitize_hash(hash, max_length, aggressive = false)
      return hash unless hash.is_a?(Hash)

      hash.deep_dup.tap do |sanitized|
        sanitize_hash!(sanitized, max_length, aggressive)
      end
    end

    # Sanitize hash in place
    def sanitize_hash!(hash, max_length, aggressive = false)
      hash.each do |key, value|
        case value
        when Hash
          sanitize_hash!(value, max_length, aggressive)
        when Array
          hash[key] = sanitize_array(value, max_length, aggressive)
        when String
          hash[key] = sanitize_string_if_needed(value, key, max_length, aggressive)
        end
      end
    end

    # Sanitize an array
    def sanitize_array(array, max_length, aggressive = false)
      array.map do |item|
        case item
        when Hash
          sanitize_hash(item, max_length, aggressive)
        when Array
          sanitize_array(item, max_length, aggressive)
        when String
          sanitize_string(item, max_length)
        else
          item
        end
      end
    end

    # Sanitize a string if it's large
    def sanitize_string(string, max_length)
      return string unless string.is_a?(String)
      return string if string.length < MIN_SIZE_FOR_TRUNCATION

      truncate_large_string(string, max_length)
    end

    # Sanitize string only if key suggests it contains heavy data
    def sanitize_string_if_needed(value, key, max_length, aggressive = false)
      return value unless value.is_a?(String)

      # Check if key suggests it's heavy data
      if looks_like_heavy_data_key?(key)
        # In aggressive mode, truncate regardless of size
        if aggressive
          truncate_aggressive(value, max_length, key)
        elsif value.length >= MIN_SIZE_FOR_TRUNCATION
          truncate_large_string(value, max_length, key)
        else
          value
        end
      elsif value.length >= MIN_SIZE_FOR_TRUNCATION
        value
      else
        value
      end
    end

    # Check if a key suggests it contains heavy data
    # Match as standalone word or at the end (e.g., 'image_data', 'data')
    def looks_like_heavy_data_key?(key)
      key.to_s.match?(/\b(data|image|content|file|attachment|base64|binary|blob)\b/i)
    end

    # Truncate a large string with metadata
    def truncate_large_string(value, _max_length, key = nil)
      size_kb = (value.length / 1024.0).round(2)
      size_mb = (value.length / (1024.0 * 1024.0)).round(2)

      size_display = size_mb >= 1 ? "#{size_mb} MB" : "#{size_kb} KB"

      data_type = detect_data_type(value, key)

      # Don't show preview for base64 data - just the size is enough
      "[#{data_type} - #{size_display}]"
    end

    # Aggressively truncate data fields for high-frequency job logs
    # Shows minimal info regardless of size
    def truncate_aggressive(value, _max_length, key = nil)
      return '[TRUNCATED]' if value.empty?

      size_bytes = value.length

      # For very small data, show type only
      if size_bytes < 100
        data_type = detect_data_type(value, key)
        return "[#{data_type}]"
      end

      # For larger data, show size only (no preview)
      if size_bytes < 1024
        size_display = "#{size_bytes} bytes"
      else
        size_kb = (size_bytes / 1024.0).round(2)
        size_display = "#{size_kb} KB"
      end

      data_type = detect_data_type(value, key)

      "[#{data_type} - #{size_display}]"
    end

    # Detect the type of data
    def detect_data_type(value, key = nil)
      # Check key first for hints
      if key
        return 'BASE64 IMAGE DATA' if key.to_s.match?(/image.*data|data.*image/i)
        return 'FILE DATA' if key.to_s.match?(/file.*data|attachment/i)
        return 'CONTENT DATA' if key.to_s.match?(/content/i)
      end

      # Check value pattern
      if value.match?(%r{\A[A-Za-z0-9+/]+=*\z})
        'BASE64 DATA'
      elsif value.encoding == Encoding::ASCII_8BIT || !value.valid_encoding?
        'BINARY DATA'
      else
        'LARGE TEXT DATA'
      end
    end
  end
end
