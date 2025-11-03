#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'config/environment'

puts '🔧 Configuring Apple Pay certificates...'

# Read certificates
merchant_identity_cert = File.read('certs/apple_pay/apple_pay_cert.pem')
merchant_identity_key = File.read('certs/apple_pay/apple_pay_private.key')
payment_processing_cert = File.read('certs/apple_pay/payment_processing_cert.pem')
payment_processing_key = File.read('certs/apple_pay/payment_processing_private_v2.key')

# Get channel
channel = Channel::AppleMessagesForBusiness.first

# Build complete configuration
payment_settings = {
  'merchantDomain' => 'liquid-m3-pro.tail367da4.ts.net',
  'merchantIdentifier' => 'MS58PRCFSS.com.apple.apple-pay-matthieu',
  'applePayEnabled' => true,
  'countryCode' => 'US',
  'currencyCode' => 'USD',
  'supportedNetworks' => %w[visa masterCard amex],
  'merchantCapabilities' => %w[supports3DS supportsDebit supportsCredit],
  'test_mode' => false,
  'apple_pay' => {
    'merchant_identifier' => 'MS58PRCFSS.com.apple.apple-pay-matthieu',
    'merchant_display_name' => 'Acoustic House',
    'merchant_identity_certificate' => merchant_identity_cert,
    'merchant_identity_private_key' => merchant_identity_key,
    'payment_processing_certificate' => payment_processing_cert,
    'payment_processing_private_key' => payment_processing_key,
    'supported_networks' => %w[visa masterCard amex discover],
    'merchant_capabilities' => %w[supports3DS supportsDebit supportsCredit]
  }
}

channel.payment_settings = payment_settings
channel.save!

puts '✅ Configuration saved!'
puts "   Merchant ID: #{payment_settings['apple_pay']['merchant_identifier']}"
puts "   Test mode: #{payment_settings['test_mode']}"
puts "   Has identity cert: #{payment_settings['apple_pay']['merchant_identity_certificate'].present?}"
puts "   Has processing cert: #{payment_settings['apple_pay']['payment_processing_certificate'].present?}"
