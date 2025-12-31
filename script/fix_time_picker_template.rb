#!/usr/bin/env ruby
# Fix time picker template - remove invalid keys from stored template data

# Step 1: Find the BotActionTemplate for time picker
bot_template = BotActionTemplate.find(8)

puts '=== Bot Template (ID: 8) ===='
puts "Name: #{bot_template.name}"
puts "Type: #{bot_template.template_type}"
puts "Parameters: #{bot_template.parameters.inspect}"
puts

# Step 2: Get the MessageTemplate ID from parameters
message_template_id = bot_template.parameters['template_id']

if message_template_id.nil?
  puts '❌ No template_id found in BotActionTemplate parameters'
  exit 1
end

puts "References MessageTemplate ID: #{message_template_id}"
puts

# Step 3: Load the MessageTemplate
message_template = MessageTemplate.find(message_template_id)

puts "=== MessageTemplate (ID: #{message_template_id}) ===="
puts "Name: #{message_template.name}"
puts "Supported channels: #{message_template.supported_channels.inspect}"
puts

# Step 4: Check metadata structure
if message_template.metadata.present? && message_template.metadata['apple_message_content'].present?
  puts 'Found metadata with apple_message_content'
  content = message_template.metadata['apple_message_content']
  content_attrs = content['content_attributes'] || {}

  puts "Current content_attributes keys: #{content_attrs.keys.inspect}"

  invalid_keys = content_attrs.keys & %w[images location_data]
  if invalid_keys.any?
    puts "❌ Found invalid keys in metadata: #{invalid_keys.inspect}"
    content_attrs.delete('images')
    content_attrs.delete('location_data')
    content['content_attributes'] = content_attrs
    message_template.metadata['apple_message_content'] = content
    message_template.save!
    puts '✅ Removed from metadata'
  end
end

# Step 5: Check content_blocks structure
if message_template.content_blocks.any?
  puts "Found #{message_template.content_blocks.count} content blocks"

  message_template.content_blocks.each do |block|
    puts "  Block type: #{block.block_type}"
    next unless block.properties.present?

    puts "  Properties keys: #{block.properties.keys.inspect}"

    invalid_keys = block.properties.keys & %w[images location_data]
    next unless invalid_keys.any?

    puts "  ❌ Found invalid keys in block: #{invalid_keys.inspect}"
    block.properties.delete('images')
    block.properties.delete('location_data')
    block.save!
    puts '  ✅ Removed from block'
  end
end

puts
puts '✅ Template fixed!'
puts
puts 'Test now:'
puts '  1. Restart dev server: ./script/dev-server.sh restart'
puts "  2. Send 'time picker' keyword"
