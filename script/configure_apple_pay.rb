#!/usr/bin/env ruby
# frozen_string_literal: true

# Configure Apple Pay settings in Chatwoot channel
# Run this after generating certificates

# Load Rails environment
require_relative 'config/environment'

puts '🔧 Configuring Apple Pay for Acoustic House...'
puts ''

# Read certificate and private key
cert_path = 'certs/apple_pay/apple_pay_cert.pem'
key_path = 'certs/apple_pay/apple_pay_private.key'

unless File.exist?(cert_path)
  puts "❌ Error: Certificate not found at #{cert_path}"
  puts '   Please run ./convert_apple_pay_cert.sh first'
  exit 1
end

unless File.exist?(key_path)
  puts "❌ Error: Private key not found at #{key_path}"
  puts '   Please run ./generate_apple_pay_csr.sh first'
  exit 1
end

cert_content = File.read(cert_path)
key_content = File.read(key_path)

# Find the Apple Messages for Business channel
channel = Channel::AppleMessagesForBusiness.first

unless channel
  puts '❌ Error: No Apple Messages for Business channel found'
  exit 1
end

puts "📱 Channel: #{channel.name}"
puts "🆔 Channel ID: #{channel.id}"
puts ''

# Configure Apple Pay settings
payment_settings = channel.payment_settings || {}
payment_settings['merchantDomain'] = 'liquid-m3-pro.tail367da4.ts.net'
payment_settings['merchantIdentifier'] = 'MS58PRCFSS.com.apple.apple-pay-matthieu'
payment_settings['applePayEnabled'] = true
payment_settings['countryCode'] = 'US'
payment_settings['currencyCode'] = 'USD'

# Store certificate and private key
payment_settings['apple_pay'] ||= {}
payment_settings['apple_pay']['merchant_identifier'] = 'MS58PRCFSS.com.apple.apple-pay-matthieu'
payment_settings['apple_pay']['merchant_certificate'] = cert_content
payment_settings['apple_pay']['merchant_private_key'] = key_content
payment_settings['apple_pay']['merchant_display_name'] = 'Acoustic House'
payment_settings['apple_pay']['supported_networks'] = %w[visa masterCard amex discover]
payment_settings['apple_pay']['merchant_capabilities'] = %w[supports3DS supportsDebit supportsCredit]

# Disable test mode (use real Apple Pay)
payment_settings['test_mode'] = false

channel.payment_settings = payment_settings
channel.save!

puts '✅ Apple Pay configured successfully!'
puts ''
puts '📋 Configuration:'
puts '   Merchant ID: MS58PRCFSS.com.apple.apple-pay-matthieu'
puts '   Domain: liquid-m3-pro.tail367da4.ts.net'
puts '   Display Name: Acoustic House'
puts '   Test Mode: Disabled (using real Apple Pay)'
puts ''
puts '🚀 Ready to send Apple Pay requests!'
puts ''
puts '⚠️  IMPORTANT: Make sure Tailscale Funnel is enabled:'
puts '   tailscale funnel 3000'
puts ''
