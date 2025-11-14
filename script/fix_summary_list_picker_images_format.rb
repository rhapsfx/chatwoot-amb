#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to convert Summary List Picker images from object to array format
# This fixes the template editor so it can display the images properly
# Usage: rails runner script/fix_summary_list_picker_images_format.rb

puts '🔧 Fixing Summary List Picker Images Format'
puts '=' * 60
puts ''

template = MessageTemplate.find_by(name: 'Summary List Picker')

unless template
  puts '❌ Summary List Picker template not found'
  exit 1
end

puts "Found template: #{template.name} (ID: #{template.id})"
puts ''

# Check current format
metadata = template.metadata || {}
apple_content = metadata['apple_message_content'] || {}
content_attrs = apple_content['content_attributes'] || {}
images = content_attrs['images']

puts "Current images format: #{images.class}"
puts "Images keys/count: #{images.is_a?(Hash) ? images.keys.join(', ') : images&.length}"
puts ''

if images.is_a?(Array)
  puts '✅ Images already in array format - nothing to fix'
  exit 0
end

unless images.is_a?(Hash)
  puts '❌ Images field is not a Hash or Array - unexpected format'
  exit 1
end

puts '🔄 Converting images from object to array format...'
puts ''

# Convert object to array
images_array = images.map do |identifier, data|
  {
    'identifier' => identifier.to_s,
    'description' => '',
    'data' => data,
    # Template editor requires these fields to display images
    'preview' => "data:image/png;base64,#{data}",
    'originalName' => "image_#{identifier}",
    'size' => (data.length * 3 / 4) # Approximate size from base64
  }
end

puts "✅ Converted #{images_array.length} images to array format"
puts ''

# Update metadata
content_attrs['images'] = images_array
apple_content['content_attributes'] = content_attrs
metadata['apple_message_content'] = apple_content

template.update!(metadata: metadata)

puts '✅ Updated template metadata'
puts ''

# Also update content_blocks if present
if template.content_blocks.any?
  content_block = template.content_blocks.first
  block_props = content_block.properties || {}

  if block_props['images'].is_a?(Hash)
    puts '🔄 Converting content_block images...'

    block_images_array = block_props['images'].map do |identifier, data|
      {
        'identifier' => identifier.to_s,
        'description' => '',
        'data' => data,
        # Template editor requires these fields to display images
        'preview' => "data:image/png;base64,#{data}",
        'originalName' => "image_#{identifier}",
        'size' => (data.length * 3 / 4) # Approximate size from base64
      }
    end

    block_props['images'] = block_images_array
    content_block.update!(properties: block_props)

    puts "✅ Updated content_block with #{block_images_array.length} images"
  else
    puts '✅ Content_block images already in correct format'
  end
end

puts ''
puts '=' * 60
puts '🎉 SUCCESS! Template images format fixed'
puts '=' * 60
puts ''
puts '📝 Next steps:'
puts '  1. Refresh the template editor page'
puts '  2. Click the List Picker block settings button'
puts '  3. The block should now unfold and show all 13 images'
puts ''
