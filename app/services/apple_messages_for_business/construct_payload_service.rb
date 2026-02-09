# frozen_string_literal: true

class AppleMessagesForBusiness::ConstructPayloadService
  include AppleMessagesForBusiness::Concerns::Utf8Logging

  AMB_SERVER = 'https://mspgw.push.apple.com/v1'

  def initialize(channel:, url:, store_region: 'US')
    @channel = channel
    @url = url
    @store_region = store_region
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def perform
    # Validate inputs
    validator = AppleMessagesForBusiness::ConstructPayloadValidator.new(
      url: @url,
      store_region: @store_region
    )

    unless validator.valid?
      return {
        success: false,
        error: validator.errors.full_messages.join(', '),
        error_code: 'VALIDATION_FAILED'
      }
    end

    # Build request payload (snake_case internally)
    payload = build_request_payload

    # Transform to Apple format (camelCase)
    apple_payload = AppleMessagesForBusiness::CaseTransformer.to_apple_format(payload)

    log_info "🔍 Construct Payload - Request: #{apple_payload.to_json}"

    # Call Apple MSP Gateway
    response = call_apple_construct_payload(apple_payload)

    if response.success?
      # Parse response and convert from camelCase to snake_case
      result = JSON.parse(response.body)

      log_info "✅ Construct Payload - Success: #{result.keys}"

      # Convert richLinkDataRef from camelCase to snake_case for storage
      rich_link_data_ref = AppleMessagesForBusiness::CaseTransformer.from_apple_format(
        result['richLinkDataRef']
      )

      # Special case: handle signature-base64 (hyphen) → signature_base64 (underscore)
      rich_link_data_ref['signature_base64'] = rich_link_data_ref.delete('signature-base64') if rich_link_data_ref['signature-base64'].present?

      {
        success: true,
        rich_link_data_ref: rich_link_data_ref,
        version: result['version']
      }
    else
      error_message = response.code == 400 ? 'URL does not support App Clips' : "HTTP #{response.code}: #{response.body}"
      log_error "❌ Construct Payload - Error: #{error_message}"

      {
        success: false,
        error: error_message,
        error_code: response.code == 400 ? 'NO_APP_CLIPS_SUPPORT' : 'API_ERROR'
      }
    end
  rescue StandardError => e
    log_error "❌ Construct Payload - Exception: #{e.message}"
    {
      success: false,
      error: e.message,
      error_code: 'EXCEPTION'
    }
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  private

  def build_request_payload
    {
      'type' => 'link',
      'link' => {
        'url' => @url,
        'store_region' => @store_region
      },
      'version' => 1.0
    }
  end

  def call_apple_construct_payload(payload)
    message_id = SecureRandom.uuid

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@channel.generate_jwt_token}",
      'id' => message_id,
      'Source-Id' => @channel.business_id
    }

    HTTParty.post(
      "#{AMB_SERVER}/constructPayload",
      body: payload.to_json,
      headers: headers,
      timeout: 30
    )
  end
end
