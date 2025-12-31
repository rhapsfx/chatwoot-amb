#!/usr/bin/env ruby
# frozen_string_literal: true

# Detailed diagnostic to find where the value is lost

puts '=' * 80
puts 'Template 371 DETAILED Diagnostic Report'
puts '=' * 80
puts

template = MessageTemplate.find(371)

puts '1. Check metadata structure:'
puts "   metadata keys: #{template.metadata.keys.inspect}"
puts "   Has apple_message_content: #{template.metadata.key?('apple_message_content')}"
if template.metadata.key?('apple_message_content')
  amc = template.metadata['apple_message_content']
  puts "   apple_message_content keys: #{amc.keys.inspect}"
  if amc.key?('content_attributes')
    ca = amc['content_attributes']
    puts "   content_attributes keys: #{ca.keys.inspect}"
    puts "   content_attributes data: #{ca.inspect[0..200]}"
  else
    puts '   ❌ NO content_attributes in apple_message_content!'
  end
else
  puts '   ❌ NO apple_message_content in metadata!'
end
puts

puts '2. Check content_blocks (actual storage):'
block = template.content_blocks.find_by(block_type: 'list_picker')
if block
  puts '   ✅ ContentBlock exists'
  puts "   Properties has received_image_identifier: #{block.properties.key?('received_image_identifier')}"
  puts "   Value: '#{block.properties['received_image_identifier']}'"
  puts "   Full properties (first 300 chars): #{block.properties.inspect[0..300]}"
else
  puts '   ❌ NO list_picker block found!'
end
puts

puts '3. Test MetadataStrategy directly:'
metadata_strategy = AppleMessagesForBusiness::StorageStrategies::MetadataStrategy.new(template)
metadata_data = metadata_strategy.load_data('list_picker')
puts "   Metadata strategy returned keys: #{metadata_data.keys.inspect}"
puts "   Has received_image_identifier: #{metadata_data.key?('received_image_identifier')}"
puts "   Value: '#{metadata_data['received_image_identifier']}'"
puts "   Data preview: #{metadata_data.inspect[0..200]}"
puts

puts '4. Test ContentBlocksStrategy directly:'
content_blocks_strategy = AppleMessagesForBusiness::StorageStrategies::ContentBlocksStrategy.new(template)
content_blocks_data = content_blocks_strategy.load_data('list_picker')
puts "   ContentBlocks strategy returned keys: #{content_blocks_data.keys.inspect}"
puts "   Has received_image_identifier: #{content_blocks_data.key?('received_image_identifier')}"
puts "   Value: '#{content_blocks_data['received_image_identifier']}'"
puts

puts '5. Check TemplateFacade strategy selection:'
facade = AppleMessagesForBusiness::TemplateFacade.new(template)
puts "   Selected strategy: #{facade.storage_type}"
puts '   Should have used: ContentBlocksStrategy (because data is in content_blocks)'
puts

puts '=' * 80
puts 'CONCLUSION:'
puts "Template 371 has data in content_blocks BUT metadata['storage_strategy'] = 'metadata'"
puts 'This causes TemplateFacade to use MetadataStrategy which reads from wrong location!'
puts '=' * 80
