# frozen_string_literal: true

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
class AppleMessagesForBusiness::SendCustomPayloadService < AppleMessagesForBusiness::SendMessageService
  MAX_PAYLOAD_SIZE = 10.megabytes

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

    # Always validate basic payload structure (even if skip_validation is true)
    # This ensures the payload has the minimum required fields for Apple MSP
    validate_payload_structure(custom_data, skip_validation)

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

    # Convert string keys to symbols to ensure consistency
    # JSON.parse returns string keys, but we need symbol keys for Apple MSP
    interactive_data_symbolized = interactive_data.deep_symbolize_keys

    # CRITICAL: Regenerate requestIdentifier to ensure uniqueness
    # If user copied an existing payload, the requestIdentifier will be reused,
    # causing Apple MSP to reject or error on the device
    regenerate_request_identifier!(interactive_data_symbolized)

    # CRITICAL: Reorder interactiveData fields to match Apple's expected order
    # Apple is very picky about field order within interactiveData
    reorder_interactive_data!(interactive_data_symbolized)

    # Build payload in the EXACT order Apple MSP requires
    # CRITICAL: The order MUST be: v, id, type, sourceId, destinationId, interactiveData
    # Any other order will cause device errors!
    payload = {
      v: 1,
      id: message_id,
      type: interactive_data_symbolized.delete(:type) || 'interactive',  # Position 3: MUST come before sourceId!
      sourceId: @channel.business_id,
      destinationId: @destination_id
    }

    # Merge remaining custom fields (including interactiveData)
    payload.merge!(interactive_data_symbolized)

    Rails.logger.info "[CustomPayload] Built final payload - type: #{payload[:type]}, keys: #{payload.keys.inspect}"

    # Log sanitized final payload for debugging
    sanitized = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(payload, format: :compact)
    log_debug "[CustomPayload] Final payload (sanitized): #{sanitized.to_json}"

    payload
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
    if json_string.blank?
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

  # Validate payload structure (comprehensive validation)
  #
  # @param data [Object] Parsed payload data
  # @param skip_validation [Boolean] Whether to skip non-critical validation
  # @raise [CustomExceptions::AppleMessages::InvalidPayload] If structure is invalid
  def validate_payload_structure(data, skip_validation = false)
    # Basic validation: ensure it's a hash (always enforced)
    unless data.is_a?(Hash)
      raise CustomExceptions::AppleMessages::InvalidPayload.new(
        'Payload must be a JSON object (not array or primitive)',
        details: {
          received_type: data.class.name,
          hint: 'Wrap your payload in curly braces: { ... }'
        }
      )
    end

    # If skip_validation is true, only do basic structure check
    return true if skip_validation

    errors = []
    warnings = []

    # Check for nested "payload" wrapper (common mistake)
    if data['payload'] || data[:payload]
      warnings << 'Found nested "payload" object. Your custom_payload should contain the fields directly, not wrapped in another "payload" object.'
    end

    # Check if payload has required Apple MSP fields for interactive messages
    has_interactive_data = data['interactiveData'].present? || data[:interactiveData].present?
    has_interactive_data_ref = data['interactiveDataRef'].present? || data[:interactiveDataRef].present?

    # If type is 'interactive' (or will default to it), we need interactiveData or interactiveDataRef
    message_type = data['type'] || data[:type] || 'interactive'

    if message_type == 'interactive' && !has_interactive_data && !has_interactive_data_ref
      errors << 'Interactive messages require "interactiveData" or "interactiveDataRef" at the root level. ' \
                'Your payload should have: {"interactiveData": {"bid": "...", "data": {...}}}'
    end

    # Validate interactiveData structure if present
    if has_interactive_data
      interactive_data = data['interactiveData'] || data[:interactiveData]

      if interactive_data.is_a?(Hash)
        warnings << 'interactiveData should have a "bid" (bundle identifier) field' unless interactive_data['bid'] || interactive_data[:bid]

        if interactive_data['data'] || interactive_data[:data]
          # Validate specific interactive types
          interactive_data_obj = interactive_data['data'] || interactive_data[:data]
          validate_interactive_data_types!(interactive_data_obj, errors, warnings) if interactive_data_obj.is_a?(Hash)
        else
          warnings << 'interactiveData should have a "data" object containing your message data'
        end
      else
        errors << 'interactiveData must be a JSON object'
      end
    end

    # Log warnings but don't block
    warnings.each do |warning|
      Rails.logger.warn "[CustomPayload] Validation warning: #{warning}"
    end

    # Raise error if validation failed
    if errors.any?
      error_details = {
        errors: errors,
        warnings: warnings,
        received_keys: data.keys,
        hint: 'Fix these errors or enable "Allow experimental payloads" to bypass validation (not recommended)'
      }

      Rails.logger.error "[CustomPayload] Payload validation failed: #{errors.join('; ')}"
      Rails.logger.error "[CustomPayload] Received keys: #{data.keys.inspect}"

      raise CustomExceptions::AppleMessages::InvalidPayload.new(
        "Payload validation failed: #{errors.first}",
        details: error_details
      )
    end

    true
  end

  # Validate interactive data types (Quick Reply, List Picker, Time Picker, Form)
  #
  # @param data [Hash] Interactive data object
  # @param errors [Array] Array to collect errors
  # @param warnings [Array] Array to collect warnings
  def validate_interactive_data_types!(data, errors, warnings)
    # Validate Quick Reply
    if data['quickReply'] || data[:quickReply]
      qr = data['quickReply'] || data[:quickReply]
      items = qr['items'] || qr[:items] if qr.is_a?(Hash)

      if items.is_a?(Array)
        item_count = items.size
        warnings << "Quick Reply should have 2-5 items for optimal display (currently has #{item_count})" if item_count < 2 || item_count > 5
      else
        errors << 'quickReply must have an "items" array'
      end
    end

    # Validate List Picker
    if data['listPicker'] || data[:listPicker]
      lp = data['listPicker'] || data[:listPicker]
      sections = lp['sections'] || lp[:sections] if lp.is_a?(Hash)

      errors << 'listPicker must have a "sections" array' unless sections.is_a?(Array)
    end

    # Validate Time Picker
    if data['timePicker'] || data[:timePicker]
      tp = data['timePicker'] || data[:timePicker]
      if tp.is_a?(Hash)
        event = tp['event'] || tp[:event]
        if event.is_a?(Hash)
          timeslots = event['timeslots'] || event[:timeslots]
          errors << 'timePicker event must have a "timeslots" array' unless timeslots.is_a?(Array)
        else
          errors << 'timePicker must have an "event" object'
        end
      end
    end

    # Validate Form
    return unless data['form'] || data[:form]

    form = data['form'] || data[:form]
    pages = form['pages'] || form[:pages] if form.is_a?(Hash)

    return if pages.is_a?(Array)

    errors << 'form must have a "pages" array'
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
    if AppleMessagesForBusiness::LogSanitizer.contains_base64?(data)
      summary = AppleMessagesForBusiness::LogSanitizer.base64_summary(data)
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
    sanitized = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(data, format: :detailed)
    Rails.logger.debug { "[CustomPayload] Payload structure (sanitized): #{sanitized.to_json}" }
  end

  # Reorder interactiveData fields to match Apple's expected order
  #
  # Apple MSP is very strict about field order within interactiveData.
  # The correct order is: bid, useLiveLayout, data, receivedMessage, replyMessage
  #
  # @param data [Hash] Symbolized payload data (modified in place)
  def reorder_interactive_data!(data)
    return unless data.is_a?(Hash)
    return unless data[:interactiveData].is_a?(Hash)

    interactive = data[:interactiveData]

    # Extract all fields
    bid = interactive.delete(:bid)
    use_live_layout = interactive.delete(:useLiveLayout)
    inner_data = interactive.delete(:data)
    received_message = interactive.delete(:receivedMessage)
    reply_message = interactive.delete(:replyMessage)

    # Get any remaining fields (for extensibility)
    remaining = interactive.dup

    # Rebuild in correct order
    ordered = {}
    ordered[:bid] = bid if bid
    ordered[:useLiveLayout] = use_live_layout unless use_live_layout.nil?
    ordered[:data] = inner_data if inner_data
    ordered[:receivedMessage] = received_message if received_message
    ordered[:replyMessage] = reply_message if reply_message

    # Add any remaining fields at the end
    ordered.merge!(remaining)

    # Replace interactiveData with ordered version
    data[:interactiveData] = ordered

    Rails.logger.info "[CustomPayload] Reordered interactiveData fields: #{ordered.keys.inspect}"
  end

  # Regenerate requestIdentifier in interactiveData to ensure uniqueness
  #
  # When users copy existing payloads, the requestIdentifier is reused,
  # causing Apple MSP to reject or show errors on the device.
  # This method recursively finds and replaces requestIdentifier with a new UUID.
  #
  # @param data [Hash] Symbolized payload data (modified in place)
  def regenerate_request_identifier!(data)
    return unless data.is_a?(Hash)

    # Check if interactiveData exists and contains data.requestIdentifier
    return unless data[:interactiveData].is_a?(Hash) && data[:interactiveData][:data].is_a?(Hash)

    old_id = data[:interactiveData][:data][:requestIdentifier]

    new_id = SecureRandom.uuid
    data[:interactiveData][:data][:requestIdentifier] = new_id
    if old_id.present?
      Rails.logger.info "[CustomPayload] Regenerated requestIdentifier: #{old_id} → #{new_id}"
    else
      # If no requestIdentifier exists, add one
      Rails.logger.info "[CustomPayload] Added missing requestIdentifier: #{new_id}"
    end
  end
end
