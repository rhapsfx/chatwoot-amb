#!/usr/bin/env ruby
# frozen_string_literal: true

# Verify Apple Pay configuration for channel 5 (used by Inbox 6: Eloiza T1)

channel = Channel::AppleMessagesForBusiness.find(5)

puts "=" * 80
puts "Channel 5 Apple Pay Configuration"
puts "=" * 80
puts ""
puts "Channel Details:"
puts "  ID: #{channel.id}"
puts "  MSP ID: #{channel.msp_id}"
puts "  Business ID: #{channel.business_id}"
puts ""

# Check Apple Pay settings
apple_pay_settings = channel.payment_settings['apple_pay'] || {}

puts "Apple Pay Configuration:"
puts "  Merchant ID: #{apple_pay_settings['merchant_identifier']}"
puts "  Merchant Domain: #{apple_pay_settings['merchant_domain']}"
puts "  Certificate Present: #{!apple_pay_settings['merchant_identity_certificate'].nil?}"
puts "  Private Key Present: #{!apple_pay_settings['merchant_identity_private_key'].nil?}"
puts "  Test Mode: #{channel.payment_settings['test_mode']}"
puts ""

if apple_pay_settings['merchant_identity_certificate']
  cert_lines = apple_pay_settings['merchant_identity_certificate'].lines.count
  puts "  Certificate: #{cert_lines} lines"
end

if apple_pay_settings['merchant_identity_private_key']
  key_lines = apple_pay_settings['merchant_identity_private_key'].lines.count
  puts "  Private Key: #{key_lines} lines"
end

puts ""

# Find inboxes using this channel
inboxes = Inbox.where(channel_id: 5, channel_type: 'Channel::AppleMessagesForBusiness')

if inboxes.any?
  puts "Inboxes using this channel:"
  inboxes.each do |inbox|
    puts "  - Inbox #{inbox.id}: #{inbox.name}"
  end
else
  puts "⚠️  No inboxes using this channel"
end

puts ""
puts "=" * 80

# Validation
if apple_pay_settings['merchant_identifier'].present? &&
   apple_pay_settings['merchant_identity_certificate'].present? &&
   apple_pay_settings['merchant_identity_private_key'].present?
  puts "✅ Channel 5 is fully configured for Apple Pay!"
else
  puts "❌ Channel 5 is MISSING Apple Pay configuration:"
  puts "   - Merchant ID" unless apple_pay_settings['merchant_identifier'].present?
  puts "   - Certificate" unless apple_pay_settings['merchant_identity_certificate'].present?
  puts "   - Private Key" unless apple_pay_settings['merchant_identity_private_key'].present?
end
