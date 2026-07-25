# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
# Service for building and sending Apple Pay interactive messages to Apple MSP
#
# This service creates Apple Pay payment requests and sends them via Apple Messages for Business.
# It follows the same patterns as other AMB services (SendListPickerService, SendTimePickerService)
# and uses CaseTransformer for all case conversions.
#
# Usage:
#   service = AppleMessagesForBusiness::SendApplePayService.new(
#     channel: channel,
#     destination_id: 'user_opaque_id',
#     payment_data: {
#       'merchant_name' => 'Demo Store',
#       'currency_code' => 'USD',
#       'country_code' => 'US',
#       'line_items' => [...],
#       'total' => { ... },
#       'received_title' => 'Complete your payment',
#       'received_subtitle' => 'Pay with Apple Pay'
#     }
#   )
#
#   result = service.perform
#   # => { success: true, message_id: '...' } or { success: false, error: '...' }
#
class AppleMessagesForBusiness::SendApplePayService < AppleMessagesForBusiness::SendMessageService
  # Override parent's initialize to accept payment_data instead of message
  # rubocop:disable Lint/MissingSuper
  def initialize(channel:, destination_id:, payment_data:)
    # NOTE: We don't call super because parent expects a 'message' parameter
    # which we don't have. We initialize the required instance variables manually.
    @channel = channel
    @destination_id = destination_id
    @payment_data = payment_data
    @message = nil # No message object for direct payment requests
  end
  # rubocop:enable Lint/MissingSuper

  def perform
    # Validate payment data structure
    validation_result = validate_payment_data
    return validation_result unless validation_result[:valid]

    # Create merchant session first (required for Apple Pay)
    merchant_session_result = create_merchant_session
    return { success: false, error: merchant_session_result[:error] } if merchant_session_result[:error]

    # Build and send the Apple Pay message
    send_apple_pay_message(merchant_session_result)
  rescue StandardError => e
    Rails.logger.error "[AMB ApplePay] Failed to send Apple Pay request: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, error: "Apple Pay request failed: #{e.message}" }
  end

  private

  # Validate that payment_data has all required fields
  # rubocop:disable Metrics/CyclomaticComplexity
  def validate_payment_data
    errors = []

    # Required fields
    errors << 'Missing merchant_name' if @payment_data['merchant_name'].blank?
    errors << 'Missing currency_code' if @payment_data['currency_code'].blank?
    errors << 'Missing country_code' if @payment_data['country_code'].blank?

    line_items_valid = @payment_data['line_items'].is_a?(Array) && @payment_data['line_items'].any?
    errors << 'Missing line_items' unless line_items_valid

    errors << 'Missing total' unless @payment_data['total'].is_a?(Hash)

    if errors.any?
      Rails.logger.error "[AMB ApplePay] Validation errors: #{errors.join(', ')}"
      return { valid: false, errors: errors }
    end

    { valid: true }
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  # Create merchant session using MerchantSessionService
  def create_merchant_session
    Rails.logger.info '[AMB ApplePay] Creating merchant session...'

    merchant_service = AppleMessagesForBusiness::MerchantSessionService.new(@channel)
    result = merchant_service.create_session

    if result[:error]
      Rails.logger.error "[AMB ApplePay] Merchant session creation failed: #{result[:error]}"
      return { error: result[:error] }
    end

    Rails.logger.info "[AMB ApplePay] Merchant session created successfully (expires: #{result[:expires_at]})"
    result
  rescue StandardError => e
    Rails.logger.error "[AMB ApplePay] Merchant session creation exception: #{e.message}"
    { error: "Merchant session failed: #{e.message}" }
  end

  # Send the Apple Pay message to Apple MSP
  def send_apple_pay_message(merchant_session_result)
    message_id = SecureRandom.uuid

    # Build the complete payload with REAL merchant session
    # Note: Test mode affects payment gateway processing, not Apple MSP sending
    # We always send the payment request to device so user can interact
    payload = build_apple_msp_payload(message_id, merchant_session_result)

    # Send to Apple MSP gateway
    response = send_to_apple_gateway(payload, message_id)

    if response.success?
      Rails.logger.info "[AMB ApplePay] Successfully sent Apple Pay request to device (message_id: #{message_id})"
      Rails.logger.info '[AMB ApplePay] Test mode: Payment gateway will simulate success when user completes payment' if test_mode_enabled?
      { success: true, message_id: message_id }
    else
      Rails.logger.error "[AMB ApplePay] Apple MSP returned error: HTTP #{response.code} - #{response.body}"
      { success: false, error: "HTTP #{response.code}: #{response.body}" }
    end
  end

  # Build the complete Apple MSP payload for Apple Pay
  # Matches Python reference: 14_send_apple_pay_request.py
  def build_apple_msp_payload(message_id, merchant_session_result)
    {
      v: 1,
      id: message_id,
      sourceId: @channel.business_id,
      destinationId: @destination_id,
      type: 'interactive',
      interactiveData: build_interactive_data(merchant_session_result)
    }
  end

  # Build the interactiveData structure for Apple Pay
  # This overrides the parent method to create payment-specific structure
  def build_interactive_data(merchant_session_result)
    # Store the full merchant session result for use in build_apple_pay_config
    @merchant_session_result = merchant_session_result

    # Build base structure with snake_case (will be transformed later)
    payment_structure = {
      'payment_request' => build_payment_request(merchant_session_result[:session_data]),
      'merchant_session' => merchant_session_result[:session_data],
      'endpoints' => {
        'payment_gateway_url' => payment_gateway_url
      }
    }

    # Transform payment structure to Apple format (snake_case → camelCase)
    # NOTE: CaseTransformer returns SYMBOL keys, not string keys
    payment_data = AppleMessagesForBusiness::CaseTransformer.to_apple_format(payment_structure)

    default_bid = 'com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension'

    # Fetch and encode images if image identifiers are provided
    images = fetch_images

    request_identifier = @payment_data['request_identifier'] || SecureRandom.uuid

    # Persist the authoritative transaction total server-side so the payment
    # gateway callback can verify the amount it's asked to charge instead of
    # trusting whatever total the client device sends back.
    AppleMessagesForBusiness::ApplePayService.store_authoritative_total(
      channel_id: @channel.id,
      request_identifier: request_identifier,
      amount: format_amount(@payment_data['total']['amount']),
      currency_code: @payment_data['currency_code']
    )

    # Build data object with payment and images
    data_object = {
      requestIdentifier: request_identifier,
      mspVersion: '1.0',
      payment: payment_data
    }

    # CRITICAL: Images must be INSIDE the data object, not at top level
    # This matches Apple's reference implementation in 16_send_rich_apple_pay_request.py
    data_object[:images] = images if images.any?

    {
      receivedMessage: build_received_message,
      replyMessage: build_reply_message,
      bid: @channel.imessage_extension_bid || default_bid,
      data: data_object
    }
  end

  # Build the paymentRequest structure according to Apple Pay specification
  def build_payment_request(_merchant_session_data = nil)
    # Per Apple's reference implementation (14_send_apple_pay_request.py):
    # merchantIdentifier, supportedNetworks, merchantCapabilities go inside paymentRequest.applePay
    request = {
      'line_items' => build_line_items,
      'total' => build_total,
      'apple_pay' => build_apple_pay_config,
      'merchant_name' => @payment_data['merchant_name'],
      'country_code' => @payment_data['country_code'],
      'currency_code' => @payment_data['currency_code']
    }

    # Optional fields - add if present
    request['required_billing_contact_fields'] = @payment_data['required_billing_contact_fields'] if @payment_data['required_billing_contact_fields']
    if @payment_data['required_shipping_contact_fields']
      request['required_shipping_contact_fields'] =
        @payment_data['required_shipping_contact_fields']
    end

    request
  end

  def build_apple_pay_config
    apple_pay_settings = (@channel.payment_settings || {})['apple_pay'] || {}
    {
      'merchant_identifier' => merchant_identifier_string,
      'supported_networks' => apple_pay_settings['supported_networks'] || default_supported_networks,
      'merchant_capabilities' => apple_pay_settings['merchant_capabilities'] || default_merchant_capabilities
    }
  end

  # Build line items array
  def build_line_items
    items = @payment_data['line_items'] || []

    items.map do |item|
      {
        'label' => item['label'] || 'Item',
        'amount' => format_amount(item['amount']),
        'type' => item['type'] || 'final'
      }
    end
  end

  # Build total object
  def build_total
    total = @payment_data['total']

    {
      'label' => total['label'] || @payment_data['merchant_name'] || 'Total',
      'amount' => format_amount(total['amount']),
      'type' => total['type'] || 'final'
    }
  end

  # Get the string merchant identifier (used in paymentRequest)
  def merchant_identifier_string
    @channel.payment_settings.dig('apple_pay', 'merchant_identifier') ||
      @channel.payment_settings['merchantIdentifier'] ||
      ENV.fetch('APPLE_PAY_MERCHANT_IDENTIFIER', nil)
  end

  # Build receivedMessage (message bubble shown before payment)
  def build_received_message
    default_subtitle = build_default_subtitle

    received_msg = {
      'title' => @payment_data['received_title'] || 'Complete Payment',
      'subtitle' => @payment_data['received_subtitle'] || default_subtitle,
      'style' => @payment_data['received_style'] || 'icon'
    }

    # Add image if provided
    received_msg['image_identifier'] = @payment_data['received_image_identifier'] if @payment_data['received_image_identifier']

    # Transform to Apple format with received_message context
    AppleMessagesForBusiness::CaseTransformer.to_apple_format(received_msg, context: :received_message)
  end

  # Build replyMessage (message bubble shown after payment response)
  def build_reply_message
    reply_msg = {
      'title' => @payment_data['reply_title'] || 'Payment Complete',
      'subtitle' => @payment_data['reply_subtitle'] || 'Thank you for your purchase',
      'style' => @payment_data['reply_style'] || 'icon'
    }

    # Add image if provided, otherwise use received image as fallback
    reply_image_id = @payment_data['reply_image_identifier'] || @payment_data['received_image_identifier']
    reply_msg['image_identifier'] = reply_image_id if reply_image_id

    # Transform to Apple format with reply_message context
    AppleMessagesForBusiness::CaseTransformer.to_apple_format(reply_msg, context: :reply_message)
  end

  # Fetch and encode images from AppleListPickerImage model
  # Returns array of base64-encoded images for the interactive message
  def fetch_images
    identifiers = [
      @payment_data['received_image_identifier'],
      @payment_data['reply_image_identifier']
    ].compact.uniq

    return [] if identifiers.empty?

    # Use ImageFetchService for three-tier fallback:
    # Tier 1: inbox-specific (AppleListPickerImage)
    # Tier 2: account-wide shared (SharedAppleImage) — guitar images live here
    # Tier 3: embedded (none for Apple Pay)
    AppleMessagesForBusiness::ImageFetchService.new(
      account_id: @channel.inbox&.account_id,
      inbox_id: @channel.inbox&.id,
      embedded_images: []
    ).fetch_and_encode(identifiers)
  end

  # Construct payment gateway URL
  # This is where Apple Pay will POST the payment token
  def payment_gateway_url
    # CRITICAL: This MUST match the initiativeContext used in the merchant session request
    # Otherwise Apple will reject with "payment gateway url mismatch"
    payment_settings = @channel.payment_settings || {}
    domain = payment_settings['merchantDomain'] ||
             payment_settings.dig('apple_pay', 'merchant_domain') ||
             ENV['APPLE_PAY_MERCHANT_DOMAIN'] ||
             ENV['BASE_URL']&.gsub(%r{^https?://}, '')

    "https://#{domain}/api/v1/accounts/#{@channel.account_id}/apple_pay/payment_gateway"
  end

  # Format amount as string with 2 decimal places
  def format_amount(amount)
    return '0.00' if amount.blank?

    # Handle various input formats
    case amount
    when String
      # Already formatted
      amount
    when Numeric
      format('%.2f', amount)
    else
      '0.00'
    end
  end

  # Default supported payment networks
  def default_supported_networks
    %w[
      visa
      masterCard
      amex
      discover
      chinaUnionPay
      interac
      privateLabel
    ]
  end

  # Default merchant capabilities
  def default_merchant_capabilities
    %w[
      supports3DS
      supportsDebit
      supportsCredit
      supportsEMV
    ]
  end

  # Build default subtitle with total amount
  def build_default_subtitle
    total_label = @payment_data['total']['label']
    total_amount = format_amount(@payment_data['total']['amount'])
    "Total: #{total_label} #{total_amount}"
  end

  # Check if test mode is enabled (via channel settings or environment variable)
  def test_mode_enabled?
    test_mode_from_channel = @channel.payment_settings&.dig('test_mode')
    test_mode_from_env = ENV.fetch('APPLE_PAY_TEST_MODE', nil)

    test_mode_from_channel == true || test_mode_from_env == 'true'
  end

  # Override parent method to access payment_data
  def content_attributes
    @payment_data
  end
end
# rubocop:enable Metrics/ClassLength
