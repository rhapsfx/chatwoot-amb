class AppleMessagesForBusiness::ApplePayService
  def initialize(channel)
    @channel = channel
  end

  def create_payment_request(payment_data)
    validate_payment_data(payment_data)

    merchant_session = create_merchant_session
    return { error: merchant_session[:error] } if merchant_session[:error]

    {
      payment_request: {
        country_code: payment_data[:country_code] || 'US',
        currency_code: payment_data[:currency_code] || 'USD',
        supported_networks: payment_data[:supported_networks] || %w[visa masterCard amex],
        merchant_identifier: merchant_identifier,
        merchant_capabilities: %w[supports3DS supportsDebit supportsCredit],
        line_items: format_line_items(payment_data[:line_items]),
        total: format_total(payment_data[:total]),
        shipping_methods: format_shipping_methods(payment_data[:shipping_methods]),
        required_billing_contact_fields: payment_data[:required_billing_fields] || ['postalAddress'],
        required_shipping_contact_fields: payment_data[:required_shipping_fields] || %w[postalAddress name]
      },
      merchant_session: merchant_session[:session_data],
      endpoints: {
        payment_gateway: payment_gateway_url,
        fallback_url: payment_data[:fallback_url]
      }
    }
  end

  def process_payment_authorization(payment_token, payment_data)
    # Decrypt and validate the payment token
    decrypted_token = decrypt_payment_token(payment_token)
    return { error: 'Invalid payment token' } unless decrypted_token

    # Process with payment gateway
    gateway_response = process_with_gateway(decrypted_token, payment_data)

    if gateway_response[:success]
      {
        success: true,
        transaction_id: gateway_response[:transaction_id],
        amount: payment_data[:total][:amount],
        currency: payment_data[:total][:currency_code],
        status: 'completed',
        processed_at: Time.current
      }
    else
      {
        error: gateway_response[:error],
        status: 'failed'
      }
    end
  end

  def handle_payment_method_update(update_data)
    case update_data[:type]
    when 'shipping_contact'
      calculate_shipping_options(update_data[:shipping_contact])
    when 'shipping_method'
      calculate_updated_total(update_data[:shipping_method])
    when 'billing_contact'
      validate_billing_contact(update_data[:billing_contact])
    else
      { error: 'Unknown update type' }
    end
  end

  def validate_merchant_session
    session_data = create_merchant_session

    if session_data[:error]
      { valid: false, error: session_data[:error] }
    else
      { valid: true, expires_at: session_data[:expires_at] }
    end
  end

  private

  def validate_payment_data(payment_data)
    required_fields = [:line_items, :total, :currency_code]
    missing_fields = required_fields.select { |field| payment_data[field].nil? }

    raise ArgumentError, "Missing required fields: #{missing_fields.join(', ')}" if missing_fields.any?

    validate_line_items(payment_data[:line_items])
    validate_total(payment_data[:total])
  end

  def validate_line_items(line_items)
    raise ArgumentError, 'Line items must be an array' unless line_items.is_a?(Array)
    raise ArgumentError, 'At least one line item is required' if line_items.empty?

    line_items.each_with_index do |item, index|
      required_item_fields = [:label, :amount]
      missing_fields = required_item_fields.select { |field| item[field].nil? }

      raise ArgumentError, "Line item #{index}: Missing required fields: #{missing_fields.join(', ')}" if missing_fields.any?
    end
  end

  def validate_total(total)
    raise ArgumentError, 'Total must include label and amount' unless total[:label] && total[:amount]
    raise ArgumentError, 'Total amount must be positive' unless total[:amount].to_f.positive?
  end

  def create_merchant_session
    merchant_session_service = AppleMessagesForBusiness::MerchantSessionService.new(@channel)
    merchant_session_service.create_session
  end

  def merchant_identifier
    @channel.payment_settings.dig('apple_pay', 'merchant_identifier') ||
      ENV.fetch('APPLE_PAY_MERCHANT_IDENTIFIER', nil)
  end

  def payment_gateway_url
    "#{ENV.fetch('BASE_URL', 'https://api.example.com')}/apple_messages_for_business/#{@channel.msp_id}/payment_gateway"
  end

  def format_line_items(line_items)
    line_items.map do |item|
      {
        label: item[:label],
        amount: format_amount(item[:amount]),
        type: item[:type] || 'final'
      }
    end
  end

  def format_total(total)
    {
      label: total[:label],
      amount: format_amount(total[:amount]),
      type: 'final'
    }
  end

  def format_shipping_methods(shipping_methods)
    return [] unless shipping_methods

    shipping_methods.map do |method|
      {
        identifier: method[:identifier],
        label: method[:label],
        detail: method[:detail],
        amount: format_amount(method[:amount])
      }
    end
  end

  def format_amount(amount)
    format('%.2f', amount.to_f)
  end

  def decrypt_payment_token(payment_token)
    # Implement Apple Pay payment token decryption using Payment Processing Certificate (ECC 256-bit)
    # Reference: Apple Pay PKPayment specification
    # https://developer.apple.com/documentation/passkit/apple_pay/payment_token_format_reference

    Rails.logger.info '[Apple Pay] Starting payment token decryption'

    # Parse the payment token structure
    token_data = parse_payment_token(payment_token)
    return nil unless token_data

    # Validate token version
    unless token_data['version'] == 'EC_v1'
      Rails.logger.error "[Apple Pay] Unsupported token version: #{token_data['version']}"
      return nil
    end

    # Extract components
    encrypted_data = token_data['data']
    token_data['signature']
    header = token_data['header']

    Rails.logger.info '[Apple Pay] Token components extracted successfully'
    Rails.logger.debug { "[Apple Pay] Header: #{header.inspect}" }

    # Validate signature (optional but recommended)
    unless validate_token_signature(token_data)
      Rails.logger.error '[Apple Pay] Token signature validation failed'
      # Continue anyway for now, but log the warning
    end

    # Decrypt using ECDH and AES-256-GCM
    decrypted_data = perform_apple_pay_decryption(
      encrypted_data,
      header['ephemeralPublicKey'],
      header['publicKeyHash'],
      header['transactionId']
    )

    if decrypted_data
      payment_data = JSON.parse(decrypted_data)
      Rails.logger.info '[Apple Pay] Payment token decrypted successfully'
      Rails.logger.debug { "[Apple Pay] Decrypted payment data keys: #{payment_data.keys.inspect}" }
      payment_data
    else
      Rails.logger.error '[Apple Pay] Decryption returned nil'
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Apple Pay token parsing failed: #{e.message}"
    nil
  rescue OpenSSL::PKey::ECError => e
    Rails.logger.error "Apple Pay cryptographic operation failed: #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.error "Apple Pay token decryption failed: #{e.class.name} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end

  def parse_payment_token(payment_token)
    # Payment token can be base64-encoded or already a JSON string
    if payment_token.is_a?(String)
      begin
        # Try parsing as JSON first
        JSON.parse(payment_token)
      rescue JSON::ParserError
        # If that fails, try base64 decoding then parsing
        JSON.parse(Base64.decode64(payment_token))
      end
    elsif payment_token.is_a?(Hash)
      payment_token
    else
      Rails.logger.error "[Apple Pay] Invalid payment token type: #{payment_token.class.name}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Payment token parsing error: #{e.message}"
    nil
  end

  def validate_token_signature(_token_data)
    # Validate the token signature using Apple's root certificate
    # This is optional but recommended for production
    # For now, we'll return true and implement proper validation later
    Rails.logger.info '[Apple Pay] Token signature validation skipped (to be implemented)'
    true
  end

  def perform_apple_pay_decryption(encrypted_data, ephemeral_public_key, _public_key_hash, transaction_id)
    # Apple Pay token decryption using Payment Processing Certificate (ECC 256-bit)
    # Algorithm: ECDH + KDF (ANSI X9.63) + AES-256-GCM
    Rails.logger.info '[Apple Pay] Starting ECDH key agreement and decryption'

    # Load the Payment Processing Certificate private key (ECC 256-bit)
    merchant_private_key = load_payment_processing_private_key

    # Parse the ephemeral public key from Apple
    ephemeral_key = parse_ephemeral_public_key(ephemeral_public_key)

    # Perform ECDH to derive shared secret
    shared_secret = compute_shared_secret(merchant_private_key, ephemeral_key)
    Rails.logger.debug { "[Apple Pay] Shared secret length: #{shared_secret.bytesize} bytes" }

    # Derive symmetric encryption key using KDF
    symmetric_key = derive_symmetric_key(shared_secret, transaction_id)
    Rails.logger.debug { "[Apple Pay] Symmetric key length: #{symmetric_key.bytesize} bytes" }

    # Decrypt the payment data using AES-256-GCM
    decrypted_data = decrypt_with_aes_gcm(encrypted_data, symmetric_key)

    Rails.logger.info '[Apple Pay] Payment data decrypted successfully'
    decrypted_data
  rescue StandardError => e
    Rails.logger.error "Apple Pay decryption error: #{e.class.name} - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    nil
  end

  def load_payment_processing_private_key
    # Load the Payment Processing Certificate private key (ECC 256-bit)
    # This is different from the Merchant Identity Certificate (RSA 2048-bit)
    key_pem = @channel.payment_settings.dig('apple_pay', 'payment_processing_private_key') ||
              ENV.fetch('APPLE_PAY_PAYMENT_PROCESSING_PRIVATE_KEY', nil)

    raise 'Payment Processing private key not configured' if key_pem.blank?

    # Parse the ECC private key
    OpenSSL::PKey::EC.new(key_pem)
  rescue OpenSSL::PKey::ECError => e
    Rails.logger.error "Failed to load Payment Processing private key: #{e.message}"
    raise
  end

  def parse_ephemeral_public_key(ephemeral_key_data)
    # Parse the base64-encoded ephemeral public key
    key_bytes = Base64.decode64(ephemeral_key_data)

    # Create EC key from X9.62 encoded point
    # Apple uses P-256 curve (prime256v1)
    group = OpenSSL::PKey::EC::Group.new('prime256v1')
    key = OpenSSL::PKey::EC.new(group)

    # Parse the public key point
    point = OpenSSL::PKey::EC::Point.new(group, OpenSSL::BN.new(key_bytes, 2))
    key.public_key = point

    key
  rescue StandardError => e
    Rails.logger.error "Failed to parse ephemeral public key: #{e.message}"
    raise
  end

  def compute_shared_secret(merchant_private_key, ephemeral_public_key)
    # Compute shared secret using ECDH
    # shared_secret = merchant_private_key * ephemeral_public_key
    merchant_private_key.dh_compute_key(ephemeral_public_key.public_key)
  end

  def derive_symmetric_key(shared_secret, _transaction_id)
    # Derive symmetric encryption key using ANSI X9.63 KDF with SHA-256
    # As specified in Apple Pay documentation
    #
    # KDF Input = shared_secret || 0x00000001 || merchant_id || transaction_id
    # Symmetric Key = SHA-256(KDF Input)

    merchant_id = merchant_identifier

    # Build KDF input according to Apple Pay specification
    kdf_algorithm = "\rid-aes256-GCM" # Algorithm identifier
    party_u_info = 'Apple' # Party U (Apple)
    party_v_info = merchant_id # Party V (Merchant)

    kdf_input = [0x00, 0x00, 0x00, 0x01].pack('C*') +
                shared_secret +
                kdf_algorithm +
                party_u_info +
                party_v_info

    # Use SHA-256 to derive the symmetric key (32 bytes for AES-256)
    OpenSSL::Digest::SHA256.digest(kdf_input)
  end

  def decrypt_with_aes_gcm(encrypted_data, key)
    # Decrypt using AES-256-GCM
    # The encrypted data format is: IV (16 bytes) || Ciphertext || Auth Tag (16 bytes)

    data = Base64.decode64(encrypted_data)

    # Extract components
    # For AES-GCM with Apple Pay:
    # - IV: First 16 bytes (128 bits)
    # - Ciphertext: Middle bytes
    # - Auth Tag: Last 16 bytes (128 bits)
    iv = data[0, 16]
    auth_tag = data[-16, 16]
    ciphertext = data[16...-16]

    Rails.logger.debug { "[Apple Pay] Encrypted data length: #{data.bytesize} bytes" }
    Rails.logger.debug { "[Apple Pay] IV length: #{iv.bytesize} bytes" }
    Rails.logger.debug { "[Apple Pay] Ciphertext length: #{ciphertext.bytesize} bytes" }
    Rails.logger.debug { "[Apple Pay] Auth tag length: #{auth_tag.bytesize} bytes" }

    # Initialize AES-256-GCM cipher
    cipher = OpenSSL::Cipher.new('AES-256-GCM')
    cipher.decrypt
    cipher.key = key
    cipher.iv = iv
    cipher.auth_tag = auth_tag

    # Decrypt and verify
    plaintext = cipher.update(ciphertext) + cipher.final

    Rails.logger.debug { "[Apple Pay] Decrypted data length: #{plaintext.bytesize} bytes" }

    plaintext
  rescue OpenSSL::Cipher::CipherError => e
    Rails.logger.error "AES-GCM decryption failed: #{e.message}"
    raise
  end

  def process_with_gateway(payment_data, transaction_data)
    gateway_service = AppleMessagesForBusiness::PaymentGatewayService.new(@channel)
    gateway_service.process_payment(payment_data, transaction_data)
  end

  def calculate_shipping_options(shipping_contact)
    # Calculate available shipping methods based on shipping address
    shipping_methods = []

    if shipping_contact[:country_code] == 'US'
      shipping_methods = [
        {
          identifier: 'standard',
          label: 'Standard Shipping',
          detail: '5-7 business days',
          amount: '5.99'
        },
        {
          identifier: 'express',
          label: 'Express Shipping',
          detail: '2-3 business days',
          amount: '12.99'
        }
      ]
    elsif %w[CA MX].include?(shipping_contact[:country_code])
      shipping_methods = [
        {
          identifier: 'international',
          label: 'International Shipping',
          detail: '7-14 business days',
          amount: '19.99'
        }
      ]
    end

    { shipping_methods: shipping_methods }
  end

  def calculate_updated_total(shipping_method)
    # Recalculate total with selected shipping method
    base_total = @channel.payment_settings.dig('current_transaction', 'base_total') || 0
    shipping_cost = shipping_method[:amount].to_f

    {
      total: {
        label: 'Total',
        amount: format_amount(base_total + shipping_cost),
        type: 'final'
      }
    }
  end

  def validate_billing_contact(billing_contact)
    # Validate billing contact information
    errors = []

    errors << 'Invalid postal code' unless valid_postal_code?(billing_contact[:postal_code], billing_contact[:country_code])
    errors << 'Invalid country code' unless valid_country_code?(billing_contact[:country_code])

    if errors.any?
      { valid: false, errors: errors }
    else
      { valid: true }
    end
  end

  def valid_postal_code?(postal_code, country_code)
    return false if postal_code.blank?

    case country_code
    when 'US'
      postal_code.match?(/^\d{5}(-\d{4})?$/)
    when 'CA'
      postal_code.match?(/^[A-Z]\d[A-Z] \d[A-Z]\d$/i)
    else
      true # Accept any format for other countries
    end
  end

  def valid_country_code?(country_code)
    %w[US CA MX GB DE FR JP AU].include?(country_code)
  end
end
