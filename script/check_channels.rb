#!/usr/bin/env ruby
require_relative 'config/environment'

puts '🔍 Checking all Apple Messages channels...'
puts ''

channels = Channel::AppleMessagesForBusiness.all
puts "Found #{channels.count} channel(s)"
puts ''

channels.each_with_index do |channel, idx|
  puts "Channel ##{idx + 1}:"
  puts "  ID: #{channel.id}"
  puts "  Name: #{channel.name}"
  puts "  payment_settings keys: #{channel.payment_settings&.keys&.inspect}"
  puts "  Has apple_pay?: #{channel.payment_settings&.key?('apple_pay')}"
  puts "  apple_pay keys: #{channel.payment_settings['apple_pay']&.keys&.inspect}" if channel.payment_settings&.key?('apple_pay')
  puts "  test_mode: #{channel.payment_settings&.dig('test_mode')}"
  puts ''
end
