# frozen_string_literal: true

module AppleMessagesForBusiness
  # Shared structured logging helpers for bot services.
  # Include this module to get UTF-8-safe log_info/warn/error/debug methods.
  module BotLogging
    private

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
        obj.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      end
    end

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
