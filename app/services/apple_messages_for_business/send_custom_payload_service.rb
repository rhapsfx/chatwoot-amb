# frozen_string_literal: true

module AppleMessagesForBusiness
  # Service for sending custom JSON payloads to Apple MSP Gateway
  #
  # Allows power users to send arbitrary interactive message payloads while:
  # - Auto-populating required Apple MSP fields (v, id, sourceId, destinationId)
  # - Validating payload size and structure
  # - Optionally applying CaseTransformer for snake_case → camelCase conversion
  # - Capturing detailed error information from Apple MSP Gateway
  #
  # Usage:
  #   service = SendCustomPayloadService.new(
  #     channel: channel,
  #     destination_id: destination_id,
  #     message: message
  #   )
  #   result = service.perform
  #
  class SendCustomPayloadService < SendMessageService
    MAX_PAYLOAD_SIZE = 500.kilobytes

    # Override parent's build_interactive_data to parse and validate custom payload
    #
    # @return [Hash] Parsed custom payload data
    # @raise [CustomExceptions::AppleMessages::InvalidPayload] If payload is invalid
    # @raise [CustomExceptions::AppleMessages::PayloadTooLarge] If payload exceeds size limit
    def build_interactive_data
      custom_payload_json = content_attributes['custom_payload']
      skip_validation = content_attributes['skip_validation']
      apply_case_transform = content_attributes['apply_case_transform']

      Rails.logger.info "[CustomPayload] Processing custom payload for message #{@message.id}"
      Rails.logger.info "[CustomPayload] skip_validation: #{skip_validation}, apply_case_transform: #{apply_case_transform}"

      # Validate payload size before parsing
      validate_payload_size(custom_payload_json)

      # Parse the custom payload JSON
      custom_data = parse_custom_payload(custom_payload_json, skip_validation)

      # Log payload structure and base64 summary
      log_payload_analysis(custom_data)

      # Strip auto-populated fields if user included them
      # These fields are always populated by the system and should not come from user input
      auto_fields = %w[v id sourceId destinationId source_id destination_id]
      removed_fields = []
      auto_fields.each do |field|
        if custom_data.key?(field)
          custom_data.delete(field)
          removed_fields << field
        end
      end

      Rails.logger.info "[CustomPayload] Stripped auto-populated fields from user payload: #{removed_fields.inspect}" if removed_fields.any?

      # Apply case transformation if requested
      if apply_case_transform
        Rails.logger.info '[CustomPayload] Applying CaseTransformer to payload'
        custom_data = CaseTransformer.to_apple_format(custom_data)
      end

      # Validate payload structure (unless validation is skipped)
      validate_payload_structure(custom_data) unless skip_validation

      Rails.logger.info "[CustomPayload] Successfully processed custom payload - keys: #{custom_data.keys.inspect}"

      # Log sanitized payload at debug level for troubleshooting
      log_sanitized_payload(custom_data)

      custom_data
    rescue CustomExceptions::AppleMessages::BaseError
      # Re-raise our custom exceptions as-is
      raise
    rescue StandardError => e
      # Catch any unexpected errors and wrap them
      Rails.logger.error "[CustomPayload] Unexpected error processing payload: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      raise CustomExceptions::AppleMessages::InvalidPayload.new(
        "Failed to process custom payload: #{e.message}",
        details: {
          error_class: e.class.name,
          error_message: e.message,
          backtrace: e.backtrace.first(5)
        }
      )
    end

    # Override parent's build_apple_msp_payload to merge custom payload directly
    #
    # For custom payloads, we merge the entire custom data into the root payload
    # instead of nesting it under interactiveData
    #
    # @param message_id [String] Unique message identifier
    # @return [Hash] Complete Apple MSP payload
    def build_apple_msp_payload(message_id)
      interactive_data = build_interactive_data

      # Build base payload with required Apple MSP fields
      base_payload = {
        v: 1,
        id: message_id,
        sourceId: @channel.business_id,
        destinationId: @destination_id
      }

      # Merge custom payload directly into base payload
      # User can override type, interactiveData, etc.
      merged_payload = base_payload.merge(interactive_data)

      # Ensure type defaults to 'interactive' if not specified
      merged_payload[:type] ||= 'interactive'

      Rails.logger.info "[CustomPayload] Built final payload - type: #{merged_payload[:type]}, keys: #{merged_payload.keys.inspect}"

      # Log sanitized final payload for debugging
      sanitized = LogSanitizer.sanitize_for_log(merged_payload, format: :compact)
      log_debug "[CustomPayload] Final payload (sanitized): #{sanitized.to_json}"

      merged_payload
    end

    # Override send_to_apple_gateway to catch and parse Apple MSP errors
    #
    # @param payload [Hash] Complete payload to send
    # @param message_id [String] Message identifier
    # @param request_idr [Boolean] Whether to request IDR
    # @return [HTTParty::Response] Response from Apple MSP
    # @raise [CustomExceptions::AppleMessages::GatewayError] If Apple MSP rejects payload
    def send_to_apple_gateway(payload, message_id, request_idr: false)
      Rails.logger.info "[CustomPayload] Sending to Apple MSP Gateway - message_id: #{message_id}"

      super
    rescue HTTParty::Error, Net::HTTPError, SocketError => e
      # Parse Apple's error response
      apple_error = parse_apple_error_response(e)

      Rails.logger.error "[CustomPayload] Apple MSP Gateway error: #{apple_error.inspect}"

      raise CustomExceptions::AppleMessages::GatewayError.new(
        "Apple MSP Gateway rejected the payload: #{apple_error[:message]}",
        apple_error: apple_error
      )
    end

    private

    # Parse custom payload JSON with error handling
    #
    # @param json_string [String] Raw JSON payload from user
    # @param skip_validation [Boolean] Whether to skip validation on parse errors
    # @return [Hash] Parsed JSON data
    # @raise [CustomExceptions::AppleMessages::InvalidPayload] If JSON is invalid
    def parse_custom_payload(json_string, skip_validation)
      JSON.parse(json_string)
    rescue JSON::ParserError => e
      unless skip_validation
        raise CustomExceptions::AppleMessages::InvalidPayload.new(
          "Invalid JSON: #{e.message}",
          details: {
            json_error: e.message,
            parse_error: e.to_s
          }
        )
      end

      # If validation is skipped and JSON is invalid, we cannot proceed
      # (we need to parse it to merge with base payload)
      Rails.logger.warn '[CustomPayload] JSON parse failed but skip_validation=true - cannot proceed with invalid JSON'
      raise CustomExceptions::AppleMessages::InvalidPayload.new(
        'Cannot send custom payload: JSON is invalid. Even with validation skipped, the payload must be valid JSON.',
        details: {
          json_error: e.message,
          hint: 'Fix JSON syntax errors or remove skip_validation flag'
        }
      )
    end

    # Validate payload size against maximum allowed
    #
    # @param json_string [String] Raw JSON payload
    # @raise [CustomExceptions::AppleMessages::PayloadTooLarge] If payload exceeds limit
    # @raise [CustomExceptions::AppleMessages::InvalidPayload] If payload is nil or empty
    def validate_payload_size(json_string)
      if json_string.nil? || json_string.empty?
        raise CustomExceptions::AppleMessages::InvalidPayload.new(
          'Custom payload is required',
          details: { hint: 'Provide a valid JSON payload in the custom_payload field' }
        )
      end

      payload_size = json_string.bytesize

      return unless payload_size > MAX_PAYLOAD_SIZE

      Rails.logger.error "[CustomPayload] Payload too large: #{payload_size} bytes (max: #{MAX_PAYLOAD_SIZE} bytes)"

      raise CustomExceptions::AppleMessages::PayloadTooLarge.new(
        "Payload size (#{payload_size} bytes) exceeds maximum allowed (#{MAX_PAYLOAD_SIZE} bytes)",
        details: {
          size: payload_size,
          max_size: MAX_PAYLOAD_SIZE,
          size_kb: (payload_size / 1024.0).round(2),
          max_size_kb: (MAX_PAYLOAD_SIZE / 1024.0).round(2)
        }
      )
    end

    # Validate payload structure (basic checks)
    #
    # @param data [Object] Parsed payload data
    # @raise [CustomExceptions::AppleMessages::InvalidPayload] If structure is invalid
    def validate_payload_structure(data)
      # Basic validation: ensure it's a hash
      unless data.is_a?(Hash)
        raise CustomExceptions::AppleMessages::InvalidPayload.new(
          'Payload must be a JSON object (not array or primitive)',
          details: {
            received_type: data.class.name,
            hint: 'Wrap your payload in curly braces: { ... }'
          }
        )
      end

      # Warn if payload doesn't have expected Apple MSP fields
      # (This is lenient - Apple will reject if truly invalid)
      if data['interactiveData'].nil? && data[:interactiveData].nil? && data['type'].nil? && data[:type].nil?
        Rails.logger.warn '[CustomPayload] Payload missing interactiveData or type field - may fail at Apple MSP'
      end

      true
    end

    # Parse error response from Apple MSP Gateway
    #
    # @param error [Exception] Exception from HTTP request
    # @return [Hash] Parsed error information
    def parse_apple_error_response(error)
      response = error.respond_to?(:response) ? error.response : nil

      {
        status: response&.code || 'unknown',
        message: response&.message || error.message,
        body: parse_error_body(response&.body)
      }
    end

    # Parse error body from Apple MSP response
    #
    # @param body [String, nil] Response body
    # @return [Hash, String, nil] Parsed body or raw string
    def parse_error_body(body)
      return nil if body.blank?

      # Try to parse as JSON
      JSON.parse(body)
    rescue JSON::ParserError
      # Return as string if not JSON
      body
    end

    # Log analysis of payload structure and base64 content
    #
    # @param data [Hash] Parsed custom payload
    def log_payload_analysis(data)
      # Check if payload contains base64 images
      if LogSanitizer.contains_base64?(data)
        summary = LogSanitizer.base64_summary(data)
        Rails.logger.info "[CustomPayload] Payload contains #{summary[:count]} base64 image(s), total size: #{summary[:total_kb]}KB"

        # Log details about each image
        summary[:images].each_with_index do |img, idx|
          Rails.logger.debug "[CustomPayload]   Image #{idx + 1}: #{img[:format] || 'unknown'} format, #{img[:size_kb]}KB, key: #{img[:key]}"
        end
      else
        Rails.logger.info '[CustomPayload] Payload does not contain base64 images'
      end
    end

    # Log sanitized version of payload for debugging
    #
    # @param data [Hash] Payload data
    def log_sanitized_payload(data)
      # Use detailed format for debug logs
      sanitized = LogSanitizer.sanitize_for_log(data, format: :detailed)
      Rails.logger.debug { "[CustomPayload] Payload structure (sanitized): #{sanitized.to_json}" }
    end
  end
end
