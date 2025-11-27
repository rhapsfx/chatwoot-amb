# frozen_string_literal: true

# Sends OAuth authentication requests to Apple Messages for Business
# Implements Apple's OAuth 2.0 authentication flow with PKCE
class AppleMessagesForBusiness::SendAuthenticationService < AppleMessagesForBusiness::SendMessageService
  def initialize(channel:, destination_id:, authentication_data:, message_content: nil)
    @channel = channel
    @destination_id = destination_id
    @authentication_data = authentication_data
    @message_content = message_content
    super(channel: channel, destination_id: destination_id, message: nil)
  end

  # Override perform to skip message-specific logic
  def perform
    # OAuth authentication doesn't have a pre-created message, so skip idempotency and locking

    # CRITICAL: Check if user has opted out (Apple MSP requirement)
    if user_opted_out?
      log_info "[SendAuth] Cannot send authentication - user #{@destination_id} has opted out"
      return { success: false, error: 'User has opted out of receiving messages', error_code: 'USER_OPTED_OUT' }
    end

    # Build and send the OAuth payload
    send_interactive_message
  rescue StandardError => e
    log_info "[SendAuth] ❌ Failed to send OAuth authentication: #{e.message}"
    Rails.logger.error "Apple Messages OAuth send failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, error: e.message }
  end

  private

  # Override already_sent? since we don't have a message to track
  def already_sent?
    false
  end

  # Override mark_as_sent since we don't have a message to track
  def mark_as_sent
    # No-op: OAuth authentication doesn't create a message record
  end

  # Override send_interactive_message to use /authenticate endpoint instead of /message
  def send_interactive_message
    message_id = SecureRandom.uuid

    log_info "[SendAuth] Sending OAuth authentication - Apple MSP ID: #{message_id}"

    payload = build_payload

    # OAuth authentication uses the /authenticate endpoint, not /message
    response = send_to_apple_authenticate_endpoint(payload, message_id)

    log_info "[SendAuth] Apple MSP Response - Code: #{response.code}, Success: #{response.success?}"

    if response.success?
      log_info '[SendAuth] ✅ Successfully sent OAuth authentication to Apple MSP'
      { success: true, message_id: message_id }
    else
      error_msg = "Apple MSP returned error: #{response.code}"
      log_info "[SendAuth] ❌ #{error_msg}"

      # Log the actual error response from Apple
      log_info "[SendAuth] Apple MSP error body: #{response.body}" if response.body.present?

      { success: false, error: error_msg }
    end
  end

  def send_to_apple_authenticate_endpoint(payload, message_id)
    # Apple's authentication endpoint
    auth_endpoint = 'https://mspgw.push.apple.com/v1/authenticate'

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@channel.generate_jwt_token}",
      'id' => message_id,
      'Source-Id' => @channel.business_id,
      'Destination-Id' => @destination_id
    }

    log_info "[SendAuth] Sending to Apple authenticate endpoint: #{auth_endpoint}"
    log_info '[SendAuth] 📋 Payload structure:'
    log_info "[SendAuth]   - v: #{payload[:v]}"
    log_info "[SendAuth]   - type: #{payload[:type]}"
    log_info "[SendAuth]   - locale: #{payload[:locale]}"
    log_info "[SendAuth]   - interactiveData keys: #{payload[:interactiveData]&.keys&.inspect}"

    if payload[:interactiveData]
      log_info "[SendAuth]   - interactiveData.data keys: #{payload[:interactiveData][:data]&.keys&.inspect}"
      if payload[:interactiveData][:data]
        auth_data = payload[:interactiveData][:data][:authenticate]
        log_info "[SendAuth]   - interactiveData.data.authenticate keys: #{auth_data&.keys&.inspect}"
        if auth_data
          oauth2_data = auth_data[:oauth2]
          log_info "[SendAuth]   - interactiveData.data.authenticate.oauth2 keys: #{oauth2_data&.keys&.inspect}"
          if oauth2_data
            log_info "[SendAuth]   - oauth2.responseType: #{oauth2_data[:responseType] || oauth2_data['responseType']}"
            log_info "[SendAuth]   - oauth2.scope: #{oauth2_data[:scope] || oauth2_data['scope']}"
          end
        end
      end
    end

    HTTParty.post(
      auth_endpoint,
      body: payload.to_json,
      headers: headers,
      timeout: 30
    )
  end

  def build_payload
    log_info '[SendAuth] Building OAuth authentication payload'

    # Build base payload according to Apple's AuthV2 spec
    # Reference: https://register.apple.com/resources/messages/msp-rest-api/type-interactive#authentication-message
    payload = {
      v: 1,
      sourceId: "urn:biz:#{@channel.msp_id}",
      destinationId: @destination_id,
      type: 'interactive',
      locale: 'en_US',
      interactiveData: build_interactive_data
    }

    log_info "[SendAuth] Payload built successfully (size: #{payload.to_json.bytesize} bytes)"
    payload
  end

  def fetch_images(identifiers)
    # Use ImageFetchService to fetch images
    # For OAuth, we don't have an inbox_id, so use account-level images only
    image_service = AppleMessagesForBusiness::ImageFetchService.new(
      account_id: @channel.account_id,
      inbox_id: nil,
      embedded_images: []
    )

    image_service.fetch_and_encode(identifiers)
  end

  def build_interactive_data
    # Apple Messages for Business AuthV2 structure
    # Reference: https://register.apple.com/resources/messages/msp-rest-api/type-interactive#authentication-message
    provider = @authentication_data['provider'] || @authentication_data[:provider]
    branding = provider_branding(provider)

    data_hash = {
      version: '2.0',
      requestIdentifier: SecureRandom.uuid,
      authenticate: {
        oauth2: build_oauth_data
      }
    }

    # Add images if provider branding includes them
    # Images go in data object, not at interactiveData level (following Apple's pattern)
    if branding[:image_identifier]
      images = fetch_images([branding[:image_identifier]])
      if images.any?
        data_hash[:images] = images
        log_info "[SendAuth] Added #{images.count} image(s) to interactiveData.data"
      end
    end

    {
      bid: 'com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension',
      data: data_hash,
      receivedMessage: build_received_message,
      replyMessage: build_reply_message
    }
  end

  def build_oauth_data
    provider = @authentication_data['provider'] || @authentication_data[:provider]

    # Generate state and store in Redis for CSRF protection
    state = SecureRandom.hex(32)

    # Generate PKCE code verifier and challenge (RFC 7636)
    # Apple Messages for Business requires PKCE for OAuth authentication
    code_verifier = SecureRandom.urlsafe_base64(32)
    code_challenge = Base64.urlsafe_encode64(
      Digest::SHA256.digest(code_verifier),
      padding: false
    )

    # Store state, provider, and code_verifier in Redis for later verification
    store_oauth_state(state, provider, code_verifier)

    # Build oauth2 object according to Apple's PKCE OAuth spec
    # Apple Messages uses PKCE (Proof Key for Code Exchange) instead of client_id/redirect_uri
    # Reference: https://developer.apple.com/documentation/businesschatapi/messages_sent/interactive_messages/oauth_2_authentication
    oauth2_data = {
      state: state,
      response_type: 'code',
      scope: get_provider_scopes(provider),
      code_challenge_method: 'S256',
      code_challenge: code_challenge
    }

    log_info "[SendAuth] OAuth provider: #{provider}"
    log_info "[SendAuth] OAuth scopes: #{oauth2_data[:scope].inspect}"
    log_info "[SendAuth] OAuth state: #{state}"
    log_info '[SendAuth] PKCE code_challenge_method: S256'
    log_info "[SendAuth] PKCE code_challenge: #{code_challenge[0..20]}... (truncated)"
    log_info '[SendAuth] Note: Using PKCE OAuth flow (code_challenge instead of client_id)'

    # Transform to Apple's camelCase format
    AppleMessagesForBusiness::CaseTransformer.to_apple_format(oauth2_data)
  end

  def store_oauth_state(state, provider, code_verifier)
    # Store state, provider, and code_verifier in Redis for CSRF protection and PKCE verification
    # Expires in 10 minutes
    oauth_state_data = {
      channel_id: @channel.id,
      destination_id: @destination_id,
      provider: provider,
      code_verifier: code_verifier
    }.to_json

    Redis::Alfred.setex("oauth_state:#{state}", oauth_state_data, 600)
    log_info '[SendAuth] Stored OAuth state and PKCE code_verifier in Redis with 10-minute expiration'
  end

  def build_redirect_uri(_state, provider)
    # Build OAuth redirect URI for this channel
    # The callback will receive the authorization code from the OAuth provider
    # NOTE: redirect_uri should be the base URL without query parameters
    # The state parameter is sent separately in the OAuth2 config and will be added by the OAuth provider
    host = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    "#{host}/apple_messages_for_business/oauth/callback/#{provider}"
  end

  def get_provider_scopes(provider)
    case provider.to_s.downcase
    when 'linkedin'
      # LinkedIn now uses OpenID Connect (migrated from OAuth 2.0)
      # https://learn.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/sign-in-with-linkedin-v2
      %w[openid profile email]
    when 'google'
      %w[openid email profile]
    when 'facebook'
      %w[email public_profile]
    else
      %w[openid email profile]
    end
  end

  def get_provider_config(provider)
    log_info "[SendAuth] Getting provider config for: #{provider}"
    log_info "[SendAuth] Channel oauth2_providers: #{@channel.oauth2_providers.inspect}"

    case provider.to_s.downcase
    when 'google'
      {
        client_id: ENV.fetch('GOOGLE_OAUTH_CLIENT_ID', @channel.oauth2_providers&.dig('google', 'clientId')),
        client_secret: ENV.fetch('GOOGLE_OAUTH_CLIENT_SECRET', @channel.oauth2_providers&.dig('google', 'clientSecret'))
      }
    when 'linkedin'
      {
        client_id: @channel.oauth2_providers&.dig('linkedin', 'clientId'),
        client_secret: @channel.oauth2_providers&.dig('linkedin', 'clientSecret')
      }
    when 'facebook'
      {
        client_id: ENV.fetch('FACEBOOK_OAUTH_CLIENT_ID', @channel.oauth2_providers&.dig('facebook', 'clientId')),
        client_secret: ENV.fetch('FACEBOOK_OAUTH_CLIENT_SECRET', @channel.oauth2_providers&.dig('facebook', 'clientSecret'))
      }
    else
      { client_id: nil, client_secret: nil }
    end
  end

  def get_encryption_key
    key_pair_service = AppleMessagesForBusiness::KeyPairService.instance
    key_pair = key_pair_service.get_key_pair(@channel.id)

    log_info '[SendAuth] Using RSA public key for response encryption'
    key_pair[:public_key]
  end

  def build_received_message
    provider = @authentication_data['provider'] || @authentication_data[:provider]
    message_text = @message_content || default_message_text(provider)

    # Get provider-specific branding
    branding = provider_branding(provider)

    msg = {
      'title' => message_text,
      'subtitle' => branding[:subtitle],
      'style' => 'large'
    }

    # Add image identifier if available
    msg['image_identifier'] = branding[:image_identifier] if branding[:image_identifier]

    # Use CaseTransformer to convert to camelCase
    AppleMessagesForBusiness::CaseTransformer.to_apple_format(msg, context: :received_message)
  end

  def build_reply_message
    msg = {
      'title' => 'Authentication Complete',
      'subtitle' => 'You are now authenticated',
      'style' => 'large'
    }

    # Use CaseTransformer to convert to camelCase
    AppleMessagesForBusiness::CaseTransformer.to_apple_format(msg, context: :reply_message)
  end

  def default_message_text(provider)
    provider_name = provider.to_s.capitalize
    "Sign in with #{provider_name} to continue"
  end

  def provider_branding(provider)
    case provider.to_s.downcase
    when 'google'
      {
        subtitle: 'Use your Google account',
        image_identifier: 'google_logo'
      }
    when 'linkedin'
      {
        subtitle: 'Use your LinkedIn account',
        image_identifier: 'linkedin_logo'
      }
    when 'facebook'
      {
        subtitle: 'Use your Facebook account',
        image_identifier: 'facebook_logo'
      }
    else
      {
        subtitle: 'Authenticate to continue',
        image_identifier: nil
      }
    end
  end

  def message_type
    'apple_authentication'
  end
end
