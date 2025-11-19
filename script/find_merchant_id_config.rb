#!/usr/bin/env ruby
# frozen_string_literal: true

# Find which channels have the merchant ID configured
merchant_id_to_find = 'com.apple.apple-pay-matthieu'

puts "Searching for merchant ID: #{merchant_id_to_find}"
puts '=' * 80
puts ''

Channel::AppleMessagesForBusiness.all.each do |channel|
  full_merchant_id = channel.payment_settings.dig('apple_pay', 'merchant_identifier')

  # Strip team prefix if present
  merchant_id = if full_merchant_id&.include?('.')
                  full_merchant_id.split('.', 2).last
                else
                  full_merchant_id
                end

  # Find inboxes using this channel
  inboxes = Inbox.where(channel_id: channel.id, channel_type: 'Channel::AppleMessagesForBusiness')

  puts "Channel #{channel.id}:"
  puts "  MSP ID: #{channel.msp_id}"
  puts "  Business ID: #{channel.business_id}"
  puts "  Full Merchant ID: #{full_merchant_id}"
  puts "  Stripped Merchant ID: #{merchant_id}"
  puts "  Has certificates: #{!channel.payment_settings.dig('apple_pay', 'merchant_identity_certificate').nil?}"
  puts "  Test mode: #{channel.payment_settings['test_mode']}"

  if inboxes.any?
    puts '  Inboxes using this channel:'
    inboxes.each do |inbox|
      puts "    - Inbox #{inbox.id}: #{inbox.name}"
    end
  else
    puts '  No inboxes using this channel'
  end

  puts "  ✅ MATCHES the merchant ID we're looking for!" if merchant_id == merchant_id_to_find

  puts ''
end
