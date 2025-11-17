#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to configure Apple Pay certificates for a channel
# Usage: rails runner script/configure_apple_pay_certificates.rb

puts "=" * 80
puts "Apple Pay Certificate Configuration Script"
puts "=" * 80
puts ""

# Certificate file paths
cert_path = Rails.root.join('certs', 'apple_pay', 'apple_pay_cert.pem')
key_path = Rails.root.join('certs', 'apple_pay', 'apple_pay_private.key')

# Check files exist
unless File.exist?(cert_path)
  puts "❌ ERROR: Certificate file not found: #{cert_path}"
  exit 1
end

unless File.exist?(key_path)
  puts "❌ ERROR: Private key file not found: #{key_path}"
  exit 1
end

puts "✅ Found certificate: #{cert_path}"
puts "✅ Found private key: #{key_path}"
puts ""

# Read certificate and private key
certificate = File.read(cert_path)
private_key = File.read(key_path)

puts "📋 Certificate size: #{certificate.length} bytes"
puts "📋 Private key size: #{private_key.length} bytes"
puts ""

# Find the channel
# You can specify the channel ID as an argument, or it will use the first one
channel_id = ARGV[0]

if channel_id
  channel = Channel::AppleMessagesForBusiness.find_by(id: channel_id)
  unless channel
    puts "❌ ERROR: Channel not found with ID: #{channel_id}"
    exit 1
  end
else
  # Use the first available channel
  channel = Channel::AppleMessagesForBusiness.first
  unless channel
    puts "❌ ERROR: No Apple Messages for Business channels found"
    exit 1
  end
end

puts "✅ Found channel ID: #{channel.id}"
puts ""

# Backup existing payment_settings
backup = channel.payment_settings&.deep_dup || {}
puts "💾 Backed up existing payment_settings"
puts ""

# Initialize payment_settings if needed
channel.payment_settings ||= {}
channel.payment_settings['apple_pay'] ||= {}

# Configure certificates
puts "📝 Configuring Apple Pay certificates..."
channel.payment_settings['apple_pay']['merchant_identity_certificate'] = certificate
channel.payment_settings['apple_pay']['merchant_identity_private_key'] = private_key

# Ensure other required settings are present
channel.payment_settings['apple_pay']['merchant_identifier'] ||= ENV['APPLE_PAY_MERCHANT_IDENTIFIER'] || 'MS58PRCFSS.com.apple.apple-pay-matthieu'
channel.payment_settings['apple_pay']['merchant_domain'] ||= ENV['APPLE_PAY_MERCHANT_DOMAIN'] || 'liquid-m3-pro.tail367da4.ts.net'

# Enable test mode by default
channel.payment_settings['test_mode'] = true

puts "   ✓ Merchant identity certificate configured"
puts "   ✓ Merchant identity private key configured"
puts "   ✓ Merchant identifier: #{channel.payment_settings['apple_pay']['merchant_identifier']}"
puts "   ✓ Merchant domain: #{channel.payment_settings['apple_pay']['merchant_domain']}"
puts "   ✓ Test mode: enabled"
puts ""

# Save the channel
if channel.save
  puts "✅ Successfully saved channel configuration!"
  puts ""
  puts "🎉 Apple Pay is now configured and ready to use"
  puts ""
  puts "📊 Configuration Summary:"
  puts "   - Channel ID: #{channel.id}"
  puts "   - Certificate: #{certificate.lines.first.strip} (#{certificate.lines.count} lines)"
  puts "   - Private Key: #{private_key.lines.first.strip} (#{private_key.lines.count} lines)"
  puts "   - Test Mode: #{channel.payment_settings['test_mode'] ? 'enabled' : 'disabled'}"
  puts ""
  puts "🧪 Test Mode Behavior:"
  puts "   - Real merchant session created with Apple"
  puts "   - Real Apple Pay request sent to device"
  puts "   - Payment gateway simulates success (no actual charge)"
  puts ""
  puts "Next steps:"
  puts "   1. Restart your dev server: ./dev-server.sh restart"
  puts "   2. Send 'apple pay' keyword to the bot"
  puts "   3. You should see Apple Pay sheet on your device!"
else
  puts "❌ ERROR: Failed to save channel"
  puts "   Errors: #{channel.errors.full_messages.join(', ')}"
  puts ""
  puts "🔙 Restoring backup..."
  channel.payment_settings = backup
  channel.save
  puts "   Backup restored"
  exit 1
end

puts "=" * 80
