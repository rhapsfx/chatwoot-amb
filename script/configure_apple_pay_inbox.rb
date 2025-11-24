#!/usr/bin/env ruby
# frozen_string_literal: true

# Configure Apple Pay for a specific inbox
#
# Usage:
#   rails runner script/configure_apple_pay_inbox.rb INBOX_ID CERT_PATH KEY_PATH MERCHANT_ID MERCHANT_DOMAIN
#
# Example:
#   rails runner script/configure_apple_pay_inbox.rb 5 \
#     config/certs/apple_pay_cert.pem \
#     config/certs/apple_pay_key.pem \
#     com.apple.apple-pay-matthieu \
#     liquid-m3-pro.tail367da4.ts.net
#
# Or use environment variables:
#   export APPLE_PAY_CERT_PATH=config/certs/apple_pay_cert.pem
#   export APPLE_PAY_KEY_PATH=config/certs/apple_pay_key.pem
#   export APPLE_PAY_MERCHANT_ID=com.apple.apple-pay-matthieu
#   export APPLE_PAY_MERCHANT_DOMAIN=liquid-m3-pro.tail367da4.ts.net
#   rails runner script/configure_apple_pay_inbox.rb 5
#

# Parse arguments
inbox_id = ARGV[0] || ENV.fetch('INBOX_ID', nil)
cert_path = ARGV[1] || ENV.fetch('APPLE_PAY_CERT_PATH', nil)
key_path = ARGV[2] || ENV.fetch('APPLE_PAY_KEY_PATH', nil)
merchant_id = ARGV[3] || ENV.fetch('APPLE_PAY_MERCHANT_ID', nil)
merchant_domain = ARGV[4] || ENV.fetch('APPLE_PAY_MERCHANT_DOMAIN', nil)

# Validate inputs
if inbox_id.blank?
  puts '❌ Error: Inbox ID is required'
  puts 'Usage: rails runner script/configure_apple_pay_inbox.rb INBOX_ID [CERT_PATH] [KEY_PATH] [MERCHANT_ID] [MERCHANT_DOMAIN]'
  exit 1
end

# Find inbox
inbox = Inbox.find_by(id: inbox_id)
unless inbox
  puts "❌ Error: Inbox #{inbox_id} not found"
  exit 1
end

unless inbox.channel.is_a?(Channel::AppleMessagesForBusiness)
  puts "❌ Error: Inbox #{inbox_id} is not an Apple Messages for Business channel"
  puts "   Channel type: #{inbox.channel.class.name}"
  exit 1
end

channel = inbox.channel
puts "✅ Found inbox #{inbox_id}: #{inbox.name}"
puts "   Channel ID: #{channel.id}"
puts "   Channel type: #{channel.class.name}"
puts

# Load certificate and key if paths provided
certificate = nil
private_key = nil

if cert_path.present?
  if File.exist?(cert_path)
    certificate = File.read(cert_path)
    puts "✅ Loaded certificate from: #{cert_path}"
  else
    puts "⚠️  Certificate file not found: #{cert_path}"
  end
end

if key_path.present?
  if File.exist?(key_path)
    private_key = File.read(key_path)
    puts "✅ Loaded private key from: #{key_path}"
  else
    puts "⚠️  Private key file not found: #{key_path}"
  end
end

# Show current configuration
puts
puts '📋 Current Apple Pay Configuration:'
current_config = channel.payment_settings&.dig('apple_pay') || {}
puts "   Merchant ID: #{current_config['merchant_identifier'] || '(not set)'}"
puts "   Merchant Domain: #{current_config['merchant_domain'] || '(not set)'}"
puts "   Certificate: #{current_config['merchant_identity_certificate'].present? ? '✅ Set' : '❌ Not set'}"
puts "   Private Key: #{current_config['merchant_identity_private_key'].present? ? '✅ Set' : '❌ Not set'}"
puts

# Build new configuration
channel.payment_settings ||= {}
channel.payment_settings['apple_pay'] ||= {}

# Update fields only if new values provided
if merchant_id.present?
  channel.payment_settings['apple_pay']['merchant_identifier'] = merchant_id
  puts "✏️  Setting merchant identifier: #{merchant_id}"
end

if merchant_domain.present?
  channel.payment_settings['apple_pay']['merchant_domain'] = merchant_domain
  puts "✏️  Setting merchant domain: #{merchant_domain}"
end

if certificate.present?
  channel.payment_settings['apple_pay']['merchant_identity_certificate'] = certificate
  puts '✏️  Setting merchant identity certificate'
end

if private_key.present?
  channel.payment_settings['apple_pay']['merchant_identity_private_key'] = private_key
  puts '✏️  Setting merchant identity private key'
end

# Save changes
if channel.changed?
  channel.save!
  puts
  puts '✅ Apple Pay configuration saved successfully!'
  puts

  # Show updated configuration
  puts '📋 Updated Apple Pay Configuration:'
  updated_config = channel.payment_settings['apple_pay']
  puts "   Merchant ID: #{updated_config['merchant_identifier'] || '(not set)'}"
  puts "   Merchant Domain: #{updated_config['merchant_domain'] || '(not set)'}"
  puts "   Certificate: #{updated_config['merchant_identity_certificate'].present? ? '✅ Set' : '❌ Not set'}"
  puts "   Private Key: #{updated_config['merchant_identity_private_key'].present? ? '✅ Set' : '❌ Not set'}"
  puts

  # Validate configuration
  puts '🔍 Validating configuration...'
  errors = []
  errors << '❌ Missing merchant identifier' if updated_config['merchant_identifier'].blank?
  errors << '❌ Missing merchant domain' if updated_config['merchant_domain'].blank?
  errors << '❌ Missing merchant certificate' if updated_config['merchant_identity_certificate'].blank?
  errors << '❌ Missing merchant private key' if updated_config['merchant_identity_private_key'].blank?

  if errors.any?
    puts
    puts '⚠️  Configuration incomplete:'
    errors.each { |error| puts "   #{error}" }
    puts
    puts 'Run the script again with missing parameters to complete the configuration.'
  else
    puts '✅ All required fields are configured!'
    puts
    puts "🎉 Apple Pay is now ready for inbox #{inbox_id}"
    puts '   Test it by running the Acoustic House Bot and selecting a guitar.'
  end
else
  puts
  puts '📝 No changes made (all values already set or no new values provided)'
  puts
  puts 'To update configuration, provide new values as arguments or environment variables.'
end
