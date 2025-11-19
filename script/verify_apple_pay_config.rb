#!/usr/bin/env ruby
# frozen_string_literal: true

channel = Channel::AppleMessagesForBusiness.find(3)

puts '📊 Apple Pay Configuration Status:'
puts ''
puts "Certificate present: #{!channel.payment_settings.dig('apple_pay', 'merchant_identity_certificate').nil?}"
puts "Private key present: #{!channel.payment_settings.dig('apple_pay', 'merchant_identity_private_key').nil?}"
puts "Merchant ID: #{channel.payment_settings.dig('apple_pay', 'merchant_identifier')}"
puts "Merchant domain: #{channel.payment_settings.dig('apple_pay', 'merchant_domain')}"
puts "Test mode: #{channel.payment_settings['test_mode']}"

if channel.payment_settings.dig('apple_pay', 'merchant_identity_certificate')
  cert_lines = channel.payment_settings.dig('apple_pay', 'merchant_identity_certificate').lines.count
  puts "Certificate size: #{cert_lines} lines"
end

if channel.payment_settings.dig('apple_pay', 'merchant_identity_private_key')
  key_lines = channel.payment_settings.dig('apple_pay', 'merchant_identity_private_key').lines.count
  puts "Private key size: #{key_lines} lines"
end
