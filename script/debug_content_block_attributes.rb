#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

# Debug to explore TemplateContentBlock properties structure

template = MessageTemplate.find_by(id: 343)

unless template
  puts '❌ Template 343 not found'
  exit 1
end

puts '=' * 80
puts "Template: #{template.name}"
puts '=' * 80
puts ''

content_blocks = template.content_blocks

if content_blocks.any?
  block = content_blocks.first

  puts "Block Type: #{block.block_type}"
  puts ''

  puts '=' * 80
  puts 'PROPERTIES STRUCTURE:'
  puts '=' * 80
  puts JSON.pretty_generate(block.properties)
  puts ''

  puts '=' * 80
  puts 'IMAGE IDENTIFIER SEARCH:'
  puts '=' * 80

  props = block.properties

  # Check received_message for header image
  if props['received_message']
    puts "\n✅ received_message found:"
    puts "   Keys: #{props['received_message'].keys.inspect}"
    puts "   📷 Header image: #{props['received_message']['image_identifier']}" if props['received_message']['image_identifier']
  end

  # Check pages structure
  if props['pages']
    puts "\n✅ Pages found: #{props['pages'].count} page(s)"
    props['pages'].each_with_index do |page, page_idx|
      puts "\n   Page #{page_idx + 1}:"
      puts "   Keys: #{page.keys.inspect}"

      # Check for images in page
      if page['images']
        puts "   📷 Page images: #{page['images'].count}"
        page['images'].each do |img|
          puts "      - #{img['identifier']}"
        end
      end

      # Check fields for images
      next unless page['fields']

      puts "   Fields: #{page['fields'].count}"
      page['fields'].each_with_index do |field, field_idx|
        puts "      Field #{field_idx + 1}: #{field['field_type']} - #{field['label']}"

        # Check for image_identifier in field itself
        puts "         📷 Field image: #{field['image_identifier']}" if field['image_identifier']

        # Check options for images
        next unless field['options']

        field['options'].each do |opt|
          puts "         📷 Option image: #{opt['image_identifier']}" if opt['image_identifier']
        end
      end
    end
  end
end
