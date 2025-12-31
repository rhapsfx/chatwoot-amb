#!/usr/bin/env ruby
# Test if Rails store accessor transforms keys during save/load cycle

require_relative '../config/environment'

puts "\n" + ('=' * 80)
puts 'RAILS STORE ACCESSOR TRANSFORMATION TEST'
puts ('=' * 80) + "\n"

# Find the most recent list picker message to use as a template
template_message = Message.where(content_type: 'apple_list_picker').last

if template_message
  puts "Found template message ID: #{template_message.id}"
  puts "Template content_attributes keys: #{template_message.content_attributes.keys.inspect}"
  if template_message.content_attributes['sections']&.first
    puts "Template section keys: #{template_message.content_attributes['sections'].first.keys.inspect}"
  end
  puts
end

# Create a test message with snake_case content_attributes
conversation = Conversation.first
user = User.first

if conversation && user
  puts 'Creating test message with SNAKE_CASE content_attributes...'

  test_attributes = {
    'sections' => [
      {
        'title' => 'Test Section',
        'multiple_selection' => true,  # SNAKE_CASE
        'items' => [
          {
            'title' => 'Option 1',
            'subtitle' => 'Description 1',
            'identifier' => 'test_1',
            'style' => 'icon'
          }
        ]
      }
    ]
  }

  puts "BEFORE save - First section keys: #{test_attributes['sections'].first.keys.inspect}"
  puts "BEFORE save - multiple_selection: #{test_attributes['sections'].first['multiple_selection'].inspect}"
  puts "BEFORE save - multipleSelection: #{test_attributes['sections'].first['multipleSelection'].inspect}"
  puts

  message = Message.new(
    account_id: conversation.account_id,
    inbox_id: conversation.inbox_id,
    conversation_id: conversation.id,
    sender: user,
    message_type: :outgoing,
    content_type: :apple_list_picker,
    content: 'Test list picker',
    content_attributes: test_attributes
  )

  puts 'AFTER Message.new, BEFORE save:'
  puts "  content_attributes class: #{message.content_attributes.class}"
  puts "  First section keys: #{message.content_attributes['sections'].first.keys.inspect}"
  puts "  multiple_selection: #{message.content_attributes['sections'].first['multiple_selection'].inspect}"
  puts "  multipleSelection: #{message.content_attributes['sections'].first['multipleSelection'].inspect}"
  puts

  # Save the message
  message.save!
  puts "Message saved with ID: #{message.id}"
  puts

  # Check content_attributes BEFORE reload
  puts 'IMMEDIATELY after save (before reload):'
  puts "  First section keys: #{message.content_attributes['sections'].first.keys.inspect}"
  puts "  multiple_selection: #{message.content_attributes['sections'].first['multiple_selection'].inspect}"
  puts "  multipleSelection: #{message.content_attributes['sections'].first['multipleSelection'].inspect}"
  puts

  # Reload from database
  message.reload

  puts 'AFTER reload from database:'
  puts "  content_attributes class: #{message.content_attributes.class}"
  puts "  First section keys: #{message.content_attributes['sections'].first.keys.inspect}"
  puts "  multiple_selection: #{message.content_attributes['sections'].first['multiple_selection'].inspect}"
  puts "  multipleSelection: #{message.content_attributes['sections'].first['multipleSelection'].inspect}"
  puts

  # Check raw database value
  raw_value = Message.connection.select_value(
    "SELECT content_attributes FROM messages WHERE id = #{message.id}"
  )
  puts 'RAW database value:'
  puts raw_value
  puts

  # Parse raw value to see what's actually stored
  parsed_raw = JSON.parse(raw_value)
  if parsed_raw['sections']&.first
    puts "Parsed raw - First section keys: #{parsed_raw['sections'].first.keys.inspect}"
    puts "Parsed raw - multiple_selection: #{parsed_raw['sections'].first['multiple_selection'].inspect}"
    puts "Parsed raw - multipleSelection: #{parsed_raw['sections'].first['multipleSelection'].inspect}"
  end
  puts

  # Cleanup
  message.destroy
  puts 'Test message deleted.'

else
  puts 'ERROR: Could not find conversation and user for testing'
end

puts('=' * 80)
puts 'TEST COMPLETE'
puts ('=' * 80) + "\n"
