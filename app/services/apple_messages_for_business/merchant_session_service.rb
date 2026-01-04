class AppleMessagesForBusiness::MerchantSessionService
  def initialize(channel)
    @channel = channel
  end

  def create_session
    # NOTE: Always create real merchant sessions (even in test mode)
    # Test mode is for payment processing, not merchant session creation
    # To send Apple Pay to device, we need valid merchant session from Apple

    validate_merchant_configuration
    return { error: 'Merchant configuration invalid' } unless merchant_configured?

    begin
      session_data = request_merchant_session

      {
        success: true,
        session_data: session_data,
        expires_at: 5.minutes.from_now,
        merchant_identifier: merchant_identifier,
        test_mode: test_mode_enabled?  # Pass test mode flag to payment service
      }
    rescue StandardError => e
      {
        error: "Merchant session creation failed: #{e.message}"
      }
    end
  end

  def validate_session(session_id)
    stored_session = get_stored_session(session_id)
    return { valid: false, error: 'Session not found' } unless stored_session

    if Time.current > Time.parse(stored_session['expires_at'])
      { valid: false, error: 'Session expired' }
    else
      { valid: true, session: stored_session }
    end
  end

  def renew_session(session_id)
    # Renew an existing merchant session
    old_session = get_stored_session(session_id)
    return { error: 'Session not found' } unless old_session

    # Create a new session
    new_session = create_session
    return new_session if new_session[:error]

    # Store the renewed session
    store_session(session_id, new_session[:session_data])

    new_session
  end

  private

  def merchant_configured?
    merchant_certificate.present? &&
      merchant_identifier.present? &&
      merchant_domain.present?
  end

  def validate_merchant_configuration
    errors = []

    errors << 'Missing merchant certificate' unless merchant_certificate.present?
    errors << 'Missing merchant identifier' unless merchant_identifier.present?
    errors << 'Missing merchant domain' unless merchant_domain.present?

    if errors.any?
      Rails.logger.error "Apple Pay merchant configuration errors: #{errors.join(', ')}"
      false
    else
      true
    end
  end

  def request_merchant_session
    # For Apple Messages for Business, the payload MUST include:
    # - merchantIdentifier: SHA256 hash of merchant ID (in hex)
    # - domainName: Base domain WITHOUT https:// prefix (REQUIRED for Messages for Business)
    # - displayName: Merchant name
    # - initiative: "messaging" for Messages for Business
    # - initiativeContext: Payment gateway URL WITH https:// prefix

    # Get domain name without https:// prefix (CRITICAL for Messages for Business)
    domain = merchant_domain # e.g., "macbook-pro-14-perso.tail367da4.ts.net"

    # Payment gateway URL with https:// prefix
    # This is the endpoint that will receive payment authorization callbacks
    payment_gateway_url = "https://#{domain}/api/v1/accounts/#{@channel.account_id}/apple_pay/payment_gateway"

    # Create the merchant session request for Messages for Business
    # Per Apple documentation: domainName field is REQUIRED for Messages for Business
    # If omitted, token will only work for Apple Pay on Web, not Messages for Business
    session_request = {
      merchantIdentifier: merchant_identifier,
      displayName: @channel.name,
      domainName: domain,  # REQUIRED: domain without https:// prefix
      initiative: 'messaging',
      initiativeContext: payment_gateway_url  # REQUIRED: payment gateway with https:// prefix
    }

    Rails.logger.info '[Apple Pay] Making merchant session request for Messages for Business'
    Rails.logger.info "[Apple Pay] Domain Name: #{domain}"
    Rails.logger.info "[Apple Pay] Payment Gateway URL: #{payment_gateway_url}"
    Rails.logger.info "[Apple Pay] Merchant ID: #{merchant_identifier}"

    # Make request to Apple Pay with mTLS (mutual TLS)
    # For Messages for Business, use /paymentSession endpoint (not /startSession)
    response = HTTParty.post(
      'https://apple-pay-gateway.apple.com/paymentservices/paymentSession',
      body: session_request.to_json,
      headers: {
        'Content-Type' => 'application/json'
      },
      pem: merchant_certificate + "\n" + merchant_private_key,
      timeout: 30
    )

    Rails.logger.info "[Apple Pay] Apple response code: #{response.code}"

    raise "Apple Pay API error: #{response.code} - #{response.body}" unless response.success?

    session_data = JSON.parse(response.body)
    store_session(SecureRandom.hex(16), session_data)
    session_data
  end

  def sign_merchant_session_request(session_request)
    # Load merchant certificate and private key
    cert = OpenSSL::X509::Certificate.new(merchant_certificate)
    private_key = OpenSSL::PKey::RSA.new(merchant_private_key)

    # Create PKCS#7 signed data
    data = session_request.to_json
    signed_data = OpenSSL::PKCS7.sign(cert, private_key, data, [], OpenSSL::PKCS7::BINARY)

    # Convert to DER format
    signed_data.to_der
  end

  def store_session(session_id, session_data)
    # Store session in Redis for quick access
    session_key = "apple_pay_session:#{@channel.id}:#{session_id}"

    $alfred.with do |redis|
      redis.setex(
        session_key,
        300, # 5 minutes
        {
          session_data: session_data,
          created_at: Time.current.iso8601,
          expires_at: 5.minutes.from_now.iso8601,
          channel_id: @channel.id
        }.to_json
      )
    end

    session_id
  end

  def get_stored_session(session_id)
    session_key = "apple_pay_session:#{@channel.id}:#{session_id}"

    session_json = $alfred.with do |redis|
      redis.get(session_key)
    end

    return nil unless session_json

    JSON.parse(session_json)
  rescue JSON::ParserError
    nil
  end

  def merchant_certificate
    @channel.payment_settings.dig('apple_pay', 'merchant_identity_certificate') ||
      @channel.merchant_certificates ||
      ENV.fetch('APPLE_PAY_MERCHANT_CERTIFICATE', nil)
  end

  def merchant_private_key
    @channel.payment_settings.dig('apple_pay', 'merchant_identity_private_key') ||
      @channel.payment_settings.dig('apple_pay', 'private_key') ||
      ENV.fetch('APPLE_PAY_MERCHANT_PRIVATE_KEY', nil)
  end

  def merchant_identifier
    full_identifier = @channel.payment_settings.dig('apple_pay', 'merchant_identifier') ||
                      ENV.fetch('APPLE_PAY_MERCHANT_IDENTIFIER', nil)

    # For Messages for Business, use only the merchant ID portion without team prefix
    # Format: MS58PRCFSS.com.apple.apple-pay-matthieu → com.apple.apple-pay-matthieu
    if full_identifier&.include?('.')
      full_identifier.split('.', 2).last
    else
      full_identifier
    end
  end

  def merchant_domain
    @channel.payment_settings.dig('merchantDomain') ||
      @channel.payment_settings.dig('apple_pay', 'merchant_domain') ||
      ENV['APPLE_PAY_MERCHANT_DOMAIN'] ||
      ENV['BASE_URL']&.gsub(%r{^https?://}, '')
  end

  def test_mode_enabled?
    test_mode_from_channel = @channel.payment_settings&.dig('test_mode')
    test_mode_from_env = ENV.fetch('APPLE_PAY_TEST_MODE', nil)

    Rails.logger.info "[Apple Pay] Test mode check - Channel payment_settings: #{@channel.payment_settings.inspect}"
    Rails.logger.info "[Apple Pay] Test mode check - test_mode value: #{test_mode_from_channel.inspect}"
    Rails.logger.info "[Apple Pay] Test mode check - ENV APPLE_PAY_TEST_MODE: #{test_mode_from_env.inspect}"

    result = test_mode_from_channel == true || test_mode_from_env == 'true'
    Rails.logger.info "[Apple Pay] Test mode enabled? #{result}"

    result
  end

  def create_test_session
    Rails.logger.info '[Apple Pay] Test mode enabled - creating mock merchant session'

    # Use consistent test merchant identifier
    test_merchant_id = 'merchant.com.example.chatwoot.test'
    Rails.logger.info "[Apple Pay] Test session using merchant ID: #{test_merchant_id}"

    # Create a mock merchant session for testing
    test_session_data = {
      'epochTimestamp' => (Time.current.to_i * 1000),
      'expiresAt' => (5.minutes.from_now.to_i * 1000),
      'merchantSessionIdentifier' => "TEST_SESSION_#{SecureRandom.hex(16)}",
      'nonce' => SecureRandom.hex(32),
      'merchantIdentifier' => test_merchant_id,
      'domainName' => merchant_domain || 'localhost',
      'displayName' => @channel.name || 'Test Merchant',
      'signature' => 'TEST_SIGNATURE',
      'operationalAnalyticsIdentifier' => "TEST_#{SecureRandom.hex(8)}",
      'retries' => 0,
      'pspId' => 'TEST_PSP'
    }

    {
      success: true,
      session_data: test_session_data,
      expires_at: 5.minutes.from_now,
      merchant_identifier: test_session_data['merchantIdentifier'],
      test_mode: true
    }
  end
end
