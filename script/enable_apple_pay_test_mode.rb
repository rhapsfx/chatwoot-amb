#!/usr/bin/env ruby
# Enable Apple Pay test mode for AMB channel

channel = Channel::AppleMessagesForBusiness.first

if channel
  puts "Channel: #{channel.name}"
  puts "MSP ID: #{channel.msp_id}"

  # Enable test mode
  channel.payment_settings = (channel.payment_settings || {}).merge({ 'test_mode' => true })
  channel.save!

  puts '✅ Test mode enabled!'
  puts "Payment settings: #{channel.payment_settings.inspect}"
else
  puts '❌ No Apple Messages for Business channel found'
end
