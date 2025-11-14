#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to add 'preview' field to existing List Picker images
# The template editor needs the 'preview' field to display images
# Usage: rails runner script/add_preview_to_list_picker_images.rb

puts '🔧 Adding Preview Field to List Picker Images'
puts '=' * 60
puts ''

template = MessageTemplate.find_by(name: 'Summary List Picker')

unless template
  puts '❌ Summary List Picker template not found'
  exit 1
end

puts "Found template: #{template.name} (ID: #{template.id})"
puts ''

# Check metadata
metadata = template.metadata || {}
apple_content = metadata['apple_message_content'] || {}
content_attrs = apple_content['content_attributes'] || {}
images = content_attrs['images']

puts "Current images format: #{images.class}"
puts "Images count: #{images&.length}"
puts ''

unless images.is_a?(Array)
  puts '❌ Images field is not an Array - unexpected format'
  exit 1
end

# Check if images already have preview field
first_image = images.first
if first_image && first_image['preview']
  puts '✅ Images already have preview field - nothing to fix'
  exit 0
end

puts '🔄 Adding preview field to images...'
puts ''

# Add preview field to each image
images.each do |image|
  next unless image['data'] && !image['preview']

  # Add preview field with full data URL
  image['preview'] = "data:image/png;base64,#{image['data']}"

  # Also add optional fields to match the editor's expectations
  image['originalName'] ||= image['description'] || 'Image'
  image['size'] ||= (image['data'].length * 3 / 4) # Approximate size from base64
end

# Update metadata
content_attrs['images'] = images
apple_content['content_attributes'] = content_attrs
metadata['apple_message_content'] = apple_content

template.update!(metadata: metadata)

puts "✅ Added preview field to #{images.length} images in metadata"
puts ''

# Also update content_blocks if present
if template.content_blocks.any?
  content_block = template.content_blocks.first
  block_props = content_block.properties || {}
  block_images = block_props['images']

  if block_images.is_a?(Array)
    puts '🔄 Adding preview field to content_block images...'

    block_images.each do |image|
      next unless image['data'] && !image['preview']

      # Add preview field with full data URL
      image['preview'] = "data:image/png;base64,#{image['data']}"

      # Also add optional fields to match the editor's expectations
      image['originalName'] ||= image['description'] || 'Image'
      image['size'] ||= (image['data'].length * 3 / 4) # Approximate size from base64
    end

    block_props['images'] = block_images
    content_block.update!(properties: block_props)

    puts "✅ Added preview field to #{block_images.length} images in content_block"
  end
end

puts ''
puts '=' * 60
puts '🎉 SUCCESS! Preview field added to all images'
puts '=' * 60
puts ''
puts '📝 Next steps:'
puts '  1. Refresh the template editor page'
puts '  2. Click the List Picker block settings button'
puts '  3. The images should now display properly'
puts ''
