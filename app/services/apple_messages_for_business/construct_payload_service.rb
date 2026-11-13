# frozen_string_literal: true

class AppleMessagesForBusiness::ConstructPayloadService
  include AppleMessagesForBusiness::Concerns::Utf8Logging
  include AppleMessagesForBusiness::Concerns::ConstructPayloadUrlDetection

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
      store_region: @store_region,
      url_type: url_type
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
      error_message = response.code == 400 ? "URL does not resolve to supported #{url_type} content" : "HTTP #{response.code}: #{response.body}"
      log_error "❌ Construct Payload - Error: #{error_message}"

      {
        success: false,
        error: error_message,
        error_code: response.code == 400 ? "NO_#{url_type.to_s.upcase}_SUPPORT" : 'API_ERROR'
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

  def url_type
    return :music if apple_music_url?(@url)
    return :maps if apple_maps_url?(@url)

    :link
  end

  # NOTE: the exact request-body shape Apple's live /v1/constructPayload endpoint expects for
  # type: music / type: maps is NOT documented in our vendored spec (construct-payload.md only
  # shows a worked example for type: link / App Clips). The shapes below are a best guess from
  # the doc's URL-type table and are NOT verified against Apple's real endpoint - confirm via
  # Apple's Postman collection/MSP support, or live sandbox testing, before relying on them.
  # TODO: verify music/maps request schema against Apple's real API before enabling in production.
  def build_request_payload
    case url_type
    when :music
      { 'type' => 'music', 'music' => { 'url' => @url }, 'version' => 1.0 }
    when :maps
      { 'type' => 'maps', 'maps' => { 'url' => @url }, 'version' => 1.0 }
    else
      { 'type' => 'link', 'link' => { 'url' => @url, 'store_region' => @store_region }, 'version' => 1.0 }
    end
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
