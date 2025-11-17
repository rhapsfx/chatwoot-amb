#!/usr/bin/env ruby
# frozen_string_literal: true

# Find which channel inbox 6 is using
inbox = Inbox.find(6)

puts "Inbox 6 details:"
puts "  Name: #{inbox.name}"
puts "  Channel Type: #{inbox.channel_type}"
puts "  Channel ID: #{inbox.channel_id}"
puts ""

if inbox.channel_type == 'Channel::AppleMessagesForBusiness'
  channel = Channel::AppleMessagesForBusiness.find(inbox.channel_id)
  puts "Channel #{channel.id} details:"
  puts "  MSP ID: #{channel.msp_id}"
  puts "  Business ID: #{channel.business_id}"
  puts ""

  # Check if certificates are configured
  cert_present = !channel.payment_settings.dig('apple_pay', 'merchant_identity_certificate').nil?
  key_present = !channel.payment_settings.dig('apple_pay', 'merchant_identity_private_key').nil?

  puts "Apple Pay configuration:"
  puts "  Certificate present: #{cert_present}"
  puts "  Private key present: #{key_present}"
  puts "  Merchant ID: #{channel.payment_settings.dig('apple_pay', 'merchant_identifier')}"
  puts "  Test mode: #{channel.payment_settings['test_mode']}"
end
