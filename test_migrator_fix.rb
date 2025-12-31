#!/usr/bin/env ruby
# frozen_string_literal: true

# Test that TemplateMigrator preserves received_image_identifier during migration

puts '=' * 80
puts 'Testing TemplateMigrator Fix'
puts '=' * 80
puts

# Create a test template with content_blocks
puts '1. Creating test template with received_image_identifier...'
template = MessageTemplate.create!(
  account_id: Account.first.id,
  name: "Test Migration #{Time.current.to_i}",
  category: 'marketing',
  supported_channels: ['apple_messages_for_business'],
  status: 'active'
)

# Create a list_picker block with received_image_identifier
template.content_blocks.create!(
  block_type: 'list_picker',
  properties: {
    'received_image_identifier' => 'test_image_123',
    'received_title' => 'Test Title',
    'sections' => []
  },
  order_index: 0
)

puts "   ✅ Created template ID: #{template.id}"
puts "   ✅ ContentBlock has received_image_identifier: #{template.content_blocks.first.properties['received_image_identifier']}"
puts

# Run the migrator (should migrate to metadata since complexity = 1)
puts '2. Running TemplateMigrator.migrate_if_needed!...'
migrator = AppleMessagesForBusiness::TemplateMigrator.new(template)
migrator.migrate_if_needed!

# Reload template to see migration results
template.reload

puts '   ✅ Migration completed'
puts "   Storage strategy: #{template.metadata['storage_strategy']}"
puts "   Migrated to: #{template.metadata['migrated_to']}"
puts

# Check if data preserved in metadata
puts '3. Checking if received_image_identifier was preserved...'
metadata_data = template.metadata.dig('apple_message_content', 'content_attributes', 'list_picker')

if metadata_data
  received_id = metadata_data['received_image_identifier']
  puts "   Metadata received_image_identifier: '#{received_id}'"

  if received_id == 'test_image_123'
    puts '   ✅ SUCCESS! Data preserved correctly during migration'
  elsif received_id.blank?
    puts '   ❌ FAILURE! received_image_identifier is empty/missing'
  else
    puts "   ⚠️  WARNING! received_image_identifier changed to: '#{received_id}'"
  end
else
  puts '   ❌ FAILURE! No metadata found'
end
puts

# Check via TemplateFacade (what ReplyBox uses)
puts '4. Testing TemplateFacade.load_data (what ReplyBox sees)...'
facade = AppleMessagesForBusiness::TemplateFacade.new(template)
loaded_data = facade.load_data('list_picker')
loaded_id = loaded_data['received_image_identifier']

puts "   Facade received_image_identifier: '#{loaded_id}'"

if loaded_id == 'test_image_123'
  puts '   ✅ SUCCESS! Facade returns correct value'
elsif loaded_id.blank?
  puts '   ❌ FAILURE! Facade returns empty/missing value'
else
  puts "   ⚠️  WARNING! Facade returns different value: '#{loaded_id}'"
end
puts

# Cleanup
puts '5. Cleaning up test template...'
template.destroy
puts "   ✅ Deleted template #{template.id}"
puts

puts '=' * 80
puts 'Test Complete'
puts '=' * 80
