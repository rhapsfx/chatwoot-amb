# frozen_string_literal: true

# Concern to add log sanitization capabilities to controllers
# Include this in controllers that handle heavy data (images, files, etc.)
module LogSanitizable
  extend ActiveSupport::Concern

  included do
    # Override the default logger to sanitize params before logging
    around_action :sanitize_logs_for_action
  end

  private

  # Wrap action execution with log sanitization
  def sanitize_logs_for_action
    # Store original params for the action
    @original_params = params.to_unsafe_h

    yield
  ensure
    # Clean up
    @original_params = nil
  end

  # Log params with sanitization
  # Use this method instead of directly logging params
  def log_params(message = 'Request params', level: :info)
    sanitized = LogSanitizerService.sanitize_for_log(params.to_unsafe_h)
    Rails.logger.public_send(level, "#{message}: #{sanitized.inspect}")
  end

  # Log specific data with sanitization
  def log_sanitized(data, message = 'Data', level: :info)
    sanitized = LogSanitizerService.sanitize_for_log(data)
    Rails.logger.public_send(level, "#{message}: #{sanitized.inspect}")
  end

  # Get sanitized params for logging
  def sanitized_params
    LogSanitizerService.sanitize_for_log(params.to_unsafe_h)
  end
end
