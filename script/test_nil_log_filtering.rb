#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify nil log filtering works correctly
# Run with: bundle exec ruby script/test_nil_log_filtering.rb

puts '=' * 80
puts 'Testing Nil Log Filtering'
puts '=' * 80
puts

# Test 1: Direct nil logging
puts '1. Testing Rails.logger.info(nil)...'
Rails.logger.info(nil)
puts '   ✓ Should NOT appear in logs'
puts

# Test 2: String "nil" logging
puts '2. Testing Rails.logger.info("nil")...'
Rails.logger.info('nil')
puts '   ✓ Should NOT appear in logs'
puts

# Test 3: Normal message
puts '3. Testing Rails.logger.info("Normal message")...'
Rails.logger.info('Normal message')
puts '   ✓ Should appear in logs as: Normal message'
puts

# Test 4: Block returning nil
puts '4. Testing Rails.logger.info { nil }...'
Rails.logger.info { nil }
puts '   ✓ Should NOT appear in logs'
puts

# Test 5: Block returning "nil" string
puts '5. Testing Rails.logger.info { "nil" }...'
Rails.logger.info { 'nil' }
puts '   ✓ Should NOT appear in logs'
puts

# Test 6: Message with nil in it
puts '6. Testing Rails.logger.info("Value is nil")...'
Rails.logger.info('Value is nil')
puts '   ✓ Should appear in logs (contains "nil" but is not just "nil")'
puts

# Test 7: Job argument suppression
puts '7. Testing ActionCableBroadcastJob logging...'
Rails.logger.info('Enqueued ActionCableBroadcastJob with arguments: [huge data here]')
puts '   ✓ Should appear as: ...with arguments: [SUPPRESSED]'
puts

puts '=' * 80
puts 'Test Complete!'
puts '=' * 80
puts
puts 'Check log/development.log for results.'
puts 'You should see:'
puts '  - "Normal message" logged'
puts '  - "Value is nil" logged'
puts '  - ActionCableBroadcastJob with [SUPPRESSED]'
puts '  - NO standalone "nil" entries'
