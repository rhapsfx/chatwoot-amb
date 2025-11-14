#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to diagnose template 355 images format
# Usage: rails runner script/diagnose_template_images.rb

puts '🔍 Diagnosing Template 355 Images Format'
puts '=' * 60
puts ''

template = MessageTemplate.find(355)

puts "Template: #{template.name} (ID: #{template.id})"
puts ''

# Check metadata
metadata = template.metadata || {}
apple_content = metadata['apple_message_content'] || {}
content_attrs = apple_content['content_attributes'] || {}
images = content_attrs['images']

puts '📊 Metadata images:'
puts "  Class: #{images.class}"
puts "  Count: #{images.is_a?(Array) ? images.length : 'N/A (not array)'}"

if images.is_a?(Array) && images.length > 0
  puts ''
  puts '  First image structure:'
  first_image = images.first
  puts "    Keys: #{first_image.keys.join(', ')}"
  puts "    Has 'data': #{first_image.key?('data')}"
  puts "    Has 'preview': #{first_image.key?('preview')}"
  puts "    Has 'identifier': #{first_image.key?('identifier')}"

  puts "    Data length: #{first_image['data'].length} chars" if first_image['data']

  if first_image['preview']
    puts "    Preview length: #{first_image['preview'].length} chars"
    puts "    Preview starts with: #{first_image['preview'][0..50]}"
  end
end

puts ''
puts '📊 Content Block images:'

if template.content_blocks.any?
  content_block = template.content_blocks.first
  block_props = content_block.properties || {}
  block_images = block_props['images']

  puts "  Class: #{block_images.class}"
  puts "  Count: #{block_images.is_a?(Array) ? block_images.length : 'N/A (not array)'}"

  if block_images.is_a?(Array) && block_images.length > 0
    puts ''
    puts '  First image structure:'
    first_image = block_images.first
    puts "    Keys: #{first_image.keys.join(', ')}"
    puts "    Has 'data': #{first_image.key?('data')}"
    puts "    Has 'preview': #{first_image.key?('preview')}"
    puts "    Has 'identifier': #{first_image.key?('identifier')}"

    puts "    Data length: #{first_image['data'].length} chars" if first_image['data']

    if first_image['preview']
      puts "    Preview length: #{first_image['preview'].length} chars"
      puts "    Preview starts with: #{first_image['preview'][0..50]}"
    end
  end
else
  puts '  No content blocks found'
end

puts ''
puts '=' * 60
