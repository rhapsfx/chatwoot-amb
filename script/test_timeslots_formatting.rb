#!/usr/bin/env ruby
# Test script for validating timeslot formatting in BotRendererService

# Test 1: Array of Unix timestamps
puts '=== Test 1: Array of Unix timestamps ==='
test_slots_1 = [1_699_564_800, 1_699_568_400, 1_699_572_000]
puts "Input: #{test_slots_1.inspect}"
puts ''

# Test 2: Array of ISO8601 timestamps
puts '=== Test 2: Array of ISO8601 timestamps ==='
test_slots_2 = ['2024-11-09T10:00:00-08:00', '2024-11-09T11:00:00-08:00', '2024-11-09T14:00:00-08:00']
puts "Input: #{test_slots_2.inspect}"
puts ''

# Test 3: Array of hash objects (proper format)
puts '=== Test 3: Array of hash objects ==='
test_slots_3 = [
  { 'identifier' => 'slot1', 'start_time' => 1_699_564_800, 'duration' => 3600 },
  { 'identifier' => 'slot2', 'start_time' => 1_699_568_400, 'duration' => 3600 }
]
puts "Input: #{test_slots_3.inspect}"
puts ''

# Test 4: Empty array
puts '=== Test 4: Empty array ==='
test_slots_4 = []
puts "Input: #{test_slots_4.inspect}"
puts ''

# Now let's actually test with the renderer service
puts "\n=== Testing with actual BotRendererService ==="
puts 'This requires a template with ID 345 to exist in the database.'
puts 'Run this from Rails console to test the full flow:'
puts ''
puts 'template = MessageTemplate.find(345)'
puts 'service = Templates::BotRendererService.new('
puts '  template_id: 345,'
puts '  parameters: {'
puts "    'available_slots' => ["
puts "      '2024-11-09T10:00:00-08:00',"
puts "      '2024-11-09T11:00:00-08:00',"
puts "      '2024-11-09T14:00:00-08:00'"
puts '    ]'
puts '  },'
puts "  channel_type: 'apple_messages_for_business'"
puts ')'
puts 'result = service.render_for_bot'
puts "puts result[:content_attributes]['event']['timeslots'].inspect"
