#!/usr/bin/env ruby
# frozen_string_literal: true

# Diagnostic script to investigate template 371 missing received_image_identifier issue

puts '=' * 80
puts 'Template 371 Diagnostic Report'
puts '=' * 80
puts

template = MessageTemplate.find(371)

puts '1. Template Basic Info:'
puts "   ID: #{template.id}"
puts "   Name: #{template.name}"
puts "   Storage Strategy: #{template.metadata['storage_strategy']}"
puts

puts '2. Content Blocks:'
template.content_blocks.each do |block|
  puts "   Block Type: #{block.block_type}"
  puts "   Properties Keys: #{block.properties.keys.inspect}"
  puts "   Has received_image_identifier: #{block.properties.key?('received_image_identifier')}"
  puts "   Has receivedImageIdentifier: #{block.properties.key?('receivedImageIdentifier')}"

  if block.properties.key?('received_image_identifier')
    puts "   ✅ received_image_identifier value: #{block.properties['received_image_identifier']}"
  elsif block.properties.key?('receivedImageIdentifier')
    puts "   ⚠️  receivedImageIdentifier value (camelCase): #{block.properties['receivedImageIdentifier']}"
  else
    puts '   ❌ Field NOT found in properties!'
  end
  puts
end

puts '3. Testing TemplateFacade.load_data:'
facade = AppleMessagesForBusiness::TemplateFacade.new(template)
loaded_data = facade.load_data('list_picker')
puts "   Loaded Data Keys: #{loaded_data.keys.inspect}"
puts "   Has received_image_identifier: #{loaded_data.key?('received_image_identifier')}"

if loaded_data.key?('received_image_identifier')
  puts "   ✅ received_image_identifier value: #{loaded_data['received_image_identifier']}"
else
  puts '   ❌ Field MISSING after load_data!'
end
puts

puts '4. Testing CaseTransformer.normalize_content_attributes:'
block = template.content_blocks.find_by(block_type: 'list_picker')
if block
  raw_properties = block.properties
  normalized = AppleMessagesForBusiness::CaseTransformer.normalize_content_attributes(raw_properties)

  puts "   Raw properties has field: #{raw_properties.key?('received_image_identifier') || raw_properties.key?('receivedImageIdentifier')}"
  puts "   Normalized has field: #{normalized.key?('received_image_identifier')}"

  if raw_properties.key?('received_image_identifier') && !normalized.key?('received_image_identifier')
    puts '   ❌ FIELD LOST DURING NORMALIZATION!'
    puts "   Raw keys: #{raw_properties.keys.inspect}"
    puts "   Normalized keys: #{normalized.keys.inspect}"
  end
end
puts

puts '5. Testing build_content (what ReplyBox sees):'
content = template.build_content
content_attrs = content[:content_attributes] || content['content_attributes'] || {}
puts "   Content Attrs Keys: #{content_attrs.keys.inspect}"
puts "   Has received_image_identifier: #{content_attrs.key?('received_image_identifier')}"

if content_attrs.key?('received_image_identifier')
  puts "   ✅ received_image_identifier value: #{content_attrs['received_image_identifier']}"
else
  puts '   ❌ FIELD MISSING in build_content output!'
end
puts

puts '=' * 80
puts 'End of Diagnostic Report'
puts '=' * 80
