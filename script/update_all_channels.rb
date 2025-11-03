#!/usr/bin/env ruby
require_relative 'config/environment'

puts '🔧 Updating ALL Apple Messages channels with certificates...'

# Read certificates
merchant_identity_cert = File.read('certs/apple_pay/apple_pay_cert.pem')
merchant_identity_key = File.read('certs/apple_pay/apple_pay_private.key')
payment_processing_cert = File.read('certs/apple_pay/payment_processing_cert.pem')
payment_processing_key = File.read('certs/apple_pay/payment_processing_private_v2.key')

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

# Update ALL channels
Channel::AppleMessagesForBusiness.all.each do |channel|
  puts "Updating Channel ##{channel.id}..."
  channel.payment_settings = payment_settings
  channel.save!
  puts '  ✅ Updated'
end

puts ''
puts '✅ All channels configured!'
puts "   Total channels updated: #{Channel::AppleMessagesForBusiness.count}"
