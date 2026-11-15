# frozen_string_literal: true

module AppleMessagesForBusiness
  module Concerns
    # Provides UTF-8 safe logging methods to prevent mojibake with emojis and special characters
    # Include this module in any service that needs to log messages with emojis
    module Utf8Logging
      private

      # Ensure UTF-8 encoding for log output to prevent mojibake
      def utf8_encode(obj)
        case obj
        when String
          obj.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
        when Hash
          obj.transform_keys { |k| utf8_encode(k) }
             .transform_values { |v| utf8_encode(v) }
        when Array
          obj.map { |item| utf8_encode(item) }
        when NilClass
          nil
        else
          # For other objects, convert to string and encode
          obj.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
        end
      end

      # Safe logging wrapper that ensures UTF-8 encoding
      def log_info(message)
        Rails.logger.info(utf8_encode(message))
      end

      def log_warn(message)
        Rails.logger.warn(utf8_encode(message))
      end

      def log_error(message)
        Rails.logger.error(utf8_encode(message))
      end

      def log_debug(message)
        Rails.logger.debug(utf8_encode(message))
      end
    end
  end
end
