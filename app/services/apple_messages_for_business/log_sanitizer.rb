# frozen_string_literal: true

module AppleMessagesForBusiness
  # Helper module to sanitize sensitive data (like base64 images) from logs
  #
  # Features:
  # - Detects and truncates base64 encoded images
  # - Handles data URLs (data:image/png;base64,...)
  # - Supports multiple output formats (compact, preview, detailed)
  # - Recursively sanitizes nested hashes and arrays
  # - Preserves non-sensitive data for debugging
  #
  # Usage:
  #   # Compact format (default): [BASE64 15.2KB]
  #   sanitized = LogSanitizer.sanitize_for_log(data)
  #
  #   # With preview: [BASE64 15.2KB | Preview: iVBORw0KGgo...]
  #   sanitized = LogSanitizer.sanitize_for_log(data, format: :preview, preview_length: 20)
  #
  #   # Detailed format: [BASE64 15.2KB | PNG image | identifier: logo_png]
  #   sanitized = LogSanitizer.sanitize_for_log(data, format: :detailed)
  #
  module LogSanitizer
    # Image format signatures for detection
    IMAGE_SIGNATURES = {
      'iVBORw0KGgo' => 'PNG',
      '/9j/' => 'JPEG',
      'R0lGOD' => 'GIF',
      'UklGR' => 'WebP',
      'Qk' => 'BMP',
      'SUkq' => 'TIFF',
      'TU0A' => 'TIFF',
      'AAABA' => 'ICO'
    }.freeze

    # Sanitize a data structure by truncating base64 image data
    #
    # @param data [Object] The data to sanitize (Hash, Array, String, or primitive)
    # @param format [Symbol] Output format (:compact, :preview, :detailed)
    # @param preview_length [Integer] Length of base64 preview to show
    # @param max_length [Integer] Deprecated - kept for backwards compatibility
    # @return [Object] Sanitized copy of the data
    def self.sanitize_for_log(data, format: :compact, preview_length: 20, max_length: nil)
      # Handle different data types
      case data
      when Hash
        data.deep_dup.tap do |sanitized|
          sanitize_hash!(sanitized, format: format, preview_length: preview_length)
        end
      when Array
        data.map { |item| sanitize_for_log(item, format: format, preview_length: preview_length) }
      when String
        # Check if this standalone string is base64
        looks_like_base64?(data, nil) ? truncate_base64(data, nil, format: format, preview_length: preview_length) : data
      else
        data
      end
    end

    # Sanitize base64 data in a hash (in place)
    #
    # @param hash [Hash] The hash to sanitize
    # @param format [Symbol] Output format
    # @param preview_length [Integer] Preview length
    def self.sanitize_hash!(hash, format:, preview_length:)
      hash.each do |key, value|
        case value
        when Hash
          sanitize_hash!(value, format: format, preview_length: preview_length)
        when Array
          hash[key] = value.map do |item|
            case item
            when Hash
              # Recursively sanitize hash items in array
              sanitize_for_log(item, format: format, preview_length: preview_length)
            when String
              # Check if array item is base64
              looks_like_base64?(item, key) ? truncate_base64(item, key, format: format, preview_length: preview_length) : item
            else
              item
            end
          end
        when String
          # Truncate if it looks like base64 data
          hash[key] = truncate_base64(value, key, format: format, preview_length: preview_length) if looks_like_base64?(value, key)
        end
      end
    end

    # Check if a string looks like base64 encoded data
    #
    # @param value [String] The string to check
    # @param key [Symbol, String, nil] The hash key (helps identify data fields)
    # @return [Boolean]
    def self.looks_like_base64?(value, key)
      return false unless value.is_a?(String)
      return false if value.length < 200 # Short strings are probably not base64 images

      # Check for data URL format: data:image/png;base64,iVBORw0KGgo...
      return true if value.match?(%r{\Adata:image/[a-z]+;base64,}i)

      # Check if key suggests it's data
      # Matches: data, image, base64, imageData, base64Data, etc.
      data_key = key && (
        key.to_s.match?(/\A(data|image|base64)\z/i) ||
        key.to_s.match?(/data|image|base64/i)
      )

      # Check if value looks like base64 (only contains base64 chars and is long)
      base64_pattern = value.length > 200 && value.match?(%r{\A[A-Za-z0-9+/]+=*\z})

      # Check if it starts with common image base64 prefixes
      image_prefix = IMAGE_SIGNATURES.keys.any? { |sig| value.start_with?(sig) }

      # Return true if it matches any criteria
      (data_key && base64_pattern) || image_prefix
    end

    # Truncate base64 string with metadata
    #
    # @param value [String] The base64 string to truncate
    # @param key [Symbol, String, nil] The hash key
    # @param format [Symbol] Output format (:compact, :preview, :detailed)
    # @param preview_length [Integer] Length of preview to show
    # @return [String] Truncated string with metadata
    def self.truncate_base64(value, key, format: :compact, preview_length: 20)
      # Handle data URLs
      data_url_match = value.match(%r{\Adata:image/([a-z]+);base64,(.+)\z}im)
      if data_url_match
        mime_type = data_url_match[1]&.upcase || 'unknown'
        base64_data = data_url_match[2] || ''
        return format_base64_info(base64_data, key, mime_type, format, preview_length, is_data_url: true)
      end

      # Detect image format from base64 content
      image_format = detect_image_format(value)

      format_base64_info(value, key, image_format, format, preview_length)
    end

    # Detect image format from base64 signature
    #
    # @param value [String] Base64 encoded string
    # @return [String, nil] Image format (PNG, JPEG, etc.) or nil
    def self.detect_image_format(value)
      IMAGE_SIGNATURES.each do |signature, format|
        return format if value.start_with?(signature)
      end
      nil
    end

    # Format base64 information based on format type
    #
    # @param base64_data [String] The base64 data
    # @param key [Symbol, String, nil] The hash key
    # @param image_format [String, nil] Detected image format
    # @param format [Symbol] Output format
    # @param preview_length [Integer] Preview length
    # @param is_data_url [Boolean] Whether this is a data URL
    # @return [String] Formatted output
    def self.format_base64_info(base64_data, key, image_format, format, preview_length, is_data_url: false)
      size_kb = (base64_data.length / 1024.0).round(2)

      case format
      when :compact
        # Compact: [BASE64 15.2KB]
        "[BASE64 #{size_kb}KB]"

      when :preview
        # Preview: [BASE64 15.2KB | Preview: iVBORw0KGgo...]
        preview = base64_data[0...preview_length]
        "[BASE64 #{size_kb}KB | Preview: #{preview}...]"

      when :detailed
        # Detailed: [BASE64 15.2KB | PNG image | identifier: logo_png | data URL]
        parts = ["BASE64 #{size_kb}KB"]
        parts << "#{image_format} image" if image_format
        parts << "identifier: #{key}" if key
        parts << 'data URL' if is_data_url
        "[#{parts.join(' | ')}]"

      else
        # Fallback to compact
        "[BASE64 #{size_kb}KB]"
      end
    end

    # Check if a payload likely contains base64 images
    # Useful for deciding whether to log at debug vs info level
    #
    # @param data [Hash, Array, String] Data to check
    # @return [Boolean] True if likely contains base64 images
    def self.contains_base64?(data)
      case data
      when Hash
        data.any? do |key, value|
          looks_like_base64?(value, key) || contains_base64?(value)
        end
      when Array
        data.any? { |item| contains_base64?(item) }
      when String
        looks_like_base64?(data, nil)
      else
        false
      end
    end

    # Get a summary of base64 content in data
    # Useful for logging payload statistics
    #
    # @param data [Hash, Array] Data to analyze
    # @return [Hash] Summary with count and total size
    def self.base64_summary(data)
      images = []

      case data
      when Hash
        extract_base64_from_hash(data, images)
      when Array
        data.each { |item| extract_base64_from_hash(item, images) if item.is_a?(Hash) }
      end

      total_kb = images.sum { |img| img[:size_kb] }

      {
        count: images.length,
        total_kb: total_kb.round(2),
        images: images
      }
    end

    # Extract base64 images from a hash
    #
    # @param hash [Hash] Hash to search
    # @param images [Array] Accumulator array for found images
    def self.extract_base64_from_hash(hash, images)
      hash.each do |key, value|
        case value
        when Hash
          extract_base64_from_hash(value, images)
        when Array
          value.each { |item| extract_base64_from_hash(item, images) if item.is_a?(Hash) }
        when String
          if looks_like_base64?(value, key)
            size_kb = (value.length / 1024.0).round(2)
            format = detect_image_format(value)
            images << {
              key: key,
              size_kb: size_kb,
              format: format
            }
          end
        end
      end
    end

    private_class_method :sanitize_hash!, :detect_image_format, :format_base64_info,
                         :extract_base64_from_hash
  end
end
