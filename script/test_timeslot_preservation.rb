#!/usr/bin/env ruby
# Test script for timeslot preservation logic
# Run with: ruby test_timeslot_preservation.rb

require_relative 'config/environment'

puts '='*80
puts 'Testing Timeslot Preservation Logic'
puts '='*80
puts

# Find or create a test template with default timeslots
template = MessageTemplate.find_or_create_by!(
  account_id: Account.first.id,
  name: 'Test Time Picker - Preservation Logic',
  category: 'scheduling',
  supported_channels: ['apple_messages_for_business']
) do |t|
  t.metadata = {
    apple_message_content: {
      content_type: 'apple_time_picker',
      content: 'Select a time',
      content_attributes: {
        event: {
          identifier: SecureRandom.uuid,
          title: 'Template Title',
          timeslots: [
            {
              identifier: 'template_slot_1',
              start_time: (1.day.from_now).to_i,
              duration: 3600
            },
            {
              identifier: 'template_slot_2',
              start_time: (1.day.from_now + 2.hours).to_i,
              duration: 3600
            }
          ]
        }
      }
    }
  }
  t.status = 'active'
end

puts "Using template: #{template.name} (ID: #{template.id})"
puts "Template has #{template.metadata.dig('apple_message_content', 'content_attributes', 'event', 'timeslots').length} default timeslots"
puts

# Test 1: available_slots should override template slots
puts 'Test 1: available_slots Override'
puts '-'*80
api_slots = [
  (2.hours.from_now).iso8601,
  (4.hours.from_now).iso8601,
  (6.hours.from_now).iso8601
]

service = Templates::BotRendererService.new(
  template_id: template.id,
  parameters: { available_slots: api_slots },
  channel_type: 'apple_messages_for_business'
)
result = service.render_for_bot
result_timeslots = result[:content_attributes].dig('event', 'timeslots')

puts "Input: available_slots with #{api_slots.length} slots"
puts "Result: #{result_timeslots.length} timeslots"
if result_timeslots.length == 3 && result_timeslots.first['identifier'] == 'slot_0'
  puts '✅ PASS: available_slots correctly override template'
else
  puts "❌ FAIL: Expected 3 slots with identifier 'slot_0'"
  puts "Got: #{result_timeslots.inspect}"
end
puts

# Test 2: Preserve template slots when updating other event fields
puts 'Test 2: Preserve Template Slots When Updating Other Fields'
puts '-'*80
service = Templates::BotRendererService.new(
  template_id: template.id,
  parameters: { event: { title: 'New Title', timezone_offset: -480 } },
  channel_type: 'apple_messages_for_business'
)
result = service.render_for_bot
result_timeslots = result[:content_attributes].dig('event', 'timeslots')
result_title = result[:content_attributes].dig('event', 'title')

puts "Input: event with title='New Title' (no timeslots)"
puts "Result: #{result_timeslots.length} timeslots, title='#{result_title}'"
if result_timeslots.length == 2 &&
   result_timeslots.first['identifier'] == 'template_slot_1' &&
   result_title == 'New Title'
  puts '✅ PASS: Template timeslots preserved, title updated'
else
  puts '❌ FAIL: Expected 2 template slots + new title'
  puts "Got: #{result_timeslots.inspect}"
end
puts

# Test 3: Empty timeslots array should not clear template slots
puts 'Test 3: Empty Timeslots Array Should Not Clear Template'
puts '-'*80
service = Templates::BotRendererService.new(
  template_id: template.id,
  parameters: { event: { title: 'New Title', timeslots: [] } },
  channel_type: 'apple_messages_for_business'
)
result = service.render_for_bot
result_timeslots = result[:content_attributes].dig('event', 'timeslots')
result_title = result[:content_attributes].dig('event', 'title')

puts "Input: event with title='New Title' and timeslots=[]"
puts "Result: #{result_timeslots.length} timeslots, title='#{result_title}'"
if result_timeslots.length == 2 &&
   result_timeslots.first['identifier'] == 'template_slot_1' &&
   result_title == 'New Title'
  puts '✅ PASS: Template timeslots preserved despite empty array'
else
  puts '❌ FAIL: Expected 2 template slots + new title'
  puts "Got: #{result_timeslots.inspect}"
end
puts

# Test 4: Non-empty parameter timeslots should override template
puts 'Test 4: Non-Empty Parameter Timeslots Override Template'
puts '-'*80
param_slots = [
  { identifier: 'param_slot_1', start_time: (10.hours.from_now).to_i, duration: 1800 },
  { identifier: 'param_slot_2', start_time: (12.hours.from_now).to_i, duration: 1800 },
  { identifier: 'param_slot_3', start_time: (14.hours.from_now).to_i, duration: 1800 }
]

service = Templates::BotRendererService.new(
  template_id: template.id,
  parameters: { event: { timeslots: param_slots } },
  channel_type: 'apple_messages_for_business'
)
result = service.render_for_bot
result_timeslots = result[:content_attributes].dig('event', 'timeslots')

puts 'Input: event with 3 custom timeslots'
puts "Result: #{result_timeslots.length} timeslots"
if result_timeslots.length == 3 && result_timeslots.first['identifier'] == 'param_slot_1'
  puts '✅ PASS: Parameter timeslots correctly override template'
else
  puts "❌ FAIL: Expected 3 param slots with identifier 'param_slot_1'"
  puts "Got: #{result_timeslots.inspect}"
end
puts

# Test 5: No parameters should use template defaults
puts 'Test 5: No Parameters Uses Template Defaults'
puts '-'*80
service = Templates::BotRendererService.new(
  template_id: template.id,
  parameters: {},
  channel_type: 'apple_messages_for_business'
)
result = service.render_for_bot
result_timeslots = result[:content_attributes].dig('event', 'timeslots')
result_title = result[:content_attributes].dig('event', 'title')

puts 'Input: Empty parameters'
puts "Result: #{result_timeslots.length} timeslots, title='#{result_title}'"
if result_timeslots.length == 2 &&
   result_timeslots.first['identifier'] == 'template_slot_1' &&
   result_title == 'Template Title'
  puts '✅ PASS: All template defaults used'
else
  puts '❌ FAIL: Expected 2 template slots with template title'
  puts "Got: #{result_timeslots.inspect}"
end
puts

puts '='*80
puts 'All tests complete!'
puts '='*80
puts
puts "Template ID for manual testing: #{template.id}"
puts
puts 'Clean up test template? (y/n): '
response = STDIN.gets.chomp.downcase
if response == 'y'
  template.destroy
  puts '✓ Test template deleted'
else
  puts 'Test template kept for manual testing'
end
