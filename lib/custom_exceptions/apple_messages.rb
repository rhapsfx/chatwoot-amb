# frozen_string_literal: true

module CustomExceptions::AppleMessages
  # Base exception for Apple Messages errors
  class BaseError < StandardError
    attr_reader :details, :apple_error

    def initialize(message = nil, details: nil, apple_error: nil)
      super(message)
      @details = details
      @apple_error = apple_error
    end

    def to_hash
      {
        error_type: error_type,
        message: message,
        details: details,
        apple_error: apple_error
      }.compact
    end

    def error_type
      self.class.name.demodulize.underscore
    end
  end

  class InvalidPayload < BaseError; end
  class PayloadTooLarge < BaseError; end
  class GatewayError < BaseError; end
  class RateLimitExceeded < BaseError; end
end
