class AppleMessagesForBusiness::CustomExtensionService
  include ApplicationHelper

  def initialize(channel:, destination_id:, app_config:)
    @channel = channel
    @destination_id = destination_id
    @app_config = app_config
  end

  def create_app_invocation_message
    validate_app_config!

    message_id = SecureRandom.uuid

    payload = build_apple_msp_payload(message_id)

    response = send_to_apple_gateway(payload, message_id)

    if response.success?
      { success: true, message_id: message_id, payload: payload }
    else
      { success: false, error: "HTTP #{response.code}: #{response.body}" }
    end
  rescue StandardError => e
    Rails.logger.error "Apple Messages custom app invocation failed: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def validate_app_config!
    required_fields = %w[app_id bid]
    missing_fields = required_fields.select { |field| @app_config[field].blank? }

    raise ArgumentError, "Missing required app configuration: #{missing_fields.join(', ')}" if missing_fields.any?

    # Validate BID format (should be Apple MSP bundle identifier format)
    return if @app_config['bid'].match?(/^[\w.-]+:[\w.-]+:[\w.-]+$/)

    raise ArgumentError, 'Invalid BID format. Expected format: com.apple.messages.MSMessageExtensionBalloonPlugin:bundleId:extension'
  end

  def build_apple_msp_payload(message_id)
    {
      v: 1,
      id: message_id,
      sourceId: @channel.business_id,
      destinationId: @destination_id,
      type: 'interactive',
      interactiveData: build_interactive_data
    }
  end

  def build_interactive_data
    base_data = {
      bid: @app_config['bid'],
      data: {
        version: @app_config['version'] || '1.0',
        requestIdentifier: SecureRandom.uuid
      },
      useLiveLayout: @app_config['use_live_layout'] != false # Default to true unless explicitly false
    }

    # Add URL if provided (for web-based extensions)
    base_data[:url] = @app_config['url'] if @app_config['url'].present?

    # Add custom app data if provided
    base_data[:data].merge!(@app_config['app_data']) if @app_config['app_data'].present?

    # Add images if provided
    base_data[:data][:images] = @app_config['images'] if @app_config['images'].present?

    # Add received and reply message structures for interactive apps
    base_data[:receivedMessage] = normalize_message_structure(@app_config['received_message']) if @app_config['received_message'].present?

    base_data[:replyMessage] = normalize_message_structure(@app_config['reply_message']) if @app_config['reply_message'].present?

    base_data
  end

  def normalize_message_structure(message_config)
    normalized = {
      title: message_config['title'] || '',
      style: validate_style_value(message_config['style'])
    }

    # Add optional fields if present
    normalized[:subtitle] = message_config['subtitle'] if message_config['subtitle'].present?
    normalized[:imageIdentifier] = message_config['image_identifier'] if message_config['image_identifier'].present?
    normalized[:imageTitle] = message_config['image_title'] if message_config['image_title'].present?
    normalized[:imageSubtitle] = message_config['image_subtitle'] if message_config['image_subtitle'].present?
    normalized[:secondarySubtitle] = message_config['secondary_subtitle'] if message_config['secondary_subtitle'].present?
    normalized[:tertiarySubtitle] = message_config['tertiary_subtitle'] if message_config['tertiary_subtitle'].present?

    normalized
  end

  def validate_style_value(style)
    valid_styles = %w[icon small large]
    return 'icon' unless style.present? && valid_styles.include?(style)

    style
  end

  def send_to_apple_gateway(payload, message_id)
    # PRE-SEND VALIDATION: Validate payload before sending to Apple MSP
    begin
      validator = AppleMessagesForBusiness::PayloadValidatorService.new(payload, 'apple_custom_app')
      validator.validate!
    rescue AppleMessagesForBusiness::PayloadValidatorService::ValidationError => e
      Rails.logger.error "[AMB CustomExtension] Payload validation failed: #{e.message}"
      Rails.logger.error "[AMB CustomExtension] Invalid payload: #{payload.to_json}"
      return OpenStruct.new(
        success?: false,
        code: 400,
        body: { error: 'Payload validation failed', details: e.message }.to_json
      )
    end

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@channel.generate_jwt_token}",
      'id' => message_id,
      'Source-Id' => @channel.business_id,
      'Destination-Id' => @destination_id
    }

    HTTParty.post(
      "#{AppleMessagesForBusiness::SendMessageService::AMB_SERVER}/message",
      body: payload.to_json,
      headers: headers,
      timeout: 30
    )
  end
end
