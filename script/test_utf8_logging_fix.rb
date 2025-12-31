#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify UTF-8 logging fix
# Run with: bundle exec ruby script/test_utf8_logging_fix.rb

puts 'Testing UTF-8 Logging Fix'
puts '=' * 80

# Test 1: Verify Utf8Logging concern
require_relative '../app/services/apple_messages_for_business/concerns/utf8_logging'

class TestLogger
  include AppleMessagesForBusiness::Concerns::Utf8Logging

  def test_emojis
    log_info '✅ Template executed: welcome_text_1, messages sent: 1'
    log_info '⏱️  Waiting between templates (1.5s delay)'
    log_info '📋 Executing template: welcome_text_2 (Type: send_text_message)'
    log_info '✅ Apple MSP - Stored payload (status: success)'
  end
end

puts "\n1. Testing Utf8Logging concern with emojis:"
puts '-' * 80
test_logger = TestLogger.new
test_logger.test_emojis

puts "\n2. Testing utf8_encode method directly:"
puts '-' * 80
test_logger = TestLogger.new
emoji_string = '✅ Template executed: welcome_text_1, messages sent: 1'
encoded = test_logger.send(:utf8_encode, emoji_string)
puts "Original: #{emoji_string.inspect}"
puts "Encoded:  #{encoded.inspect}"
puts "Encoding: #{encoded.encoding}"

puts "\n3. Testing with hash containing emojis:"
puts '-' * 80
test_hash = {
  status: '✅ success',
  message: '📋 Executing template',
  emoji: '🚀'
}
encoded_hash = test_logger.send(:utf8_encode, test_hash)
puts "Original: #{test_hash.inspect}"
puts "Encoded:  #{encoded_hash.inspect}"

puts "\n✅ All UTF-8 logging tests completed!"
puts '=' * 80
