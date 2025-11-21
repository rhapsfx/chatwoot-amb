#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to check template 355's section items and fix image identifiers

puts '=' * 80
puts 'Template 355 Image Identifier Check'
puts '=' * 80
puts ''

template = MessageTemplate.find(355)

puts "Template: #{template.name}"
puts "Storage strategy: #{template.metadata['storage_strategy'] || 'auto-detect'}"
puts ''

# Check metadata storage
if template.metadata['list_picker'].present?
  puts '📋 Found list_picker in metadata:'
  sections = template.metadata['list_picker']['sections'] || []

  sections.each_with_index do |section, s_idx|
    puts "  Section #{s_idx + 1}: #{section['title']}"
    items = section['items'] || []

    items.each_with_index do |item, i_idx|
      image_id = item['image_identifier'] || item['imageIdentifier']
      puts "    Item #{i_idx + 1}: #{item['title']}"
      puts "      image_identifier: #{image_id || 'NONE'}"
    end
  end
end

# Check content_blocks storage
content_blocks = template.content_blocks.where(block_type: 'list_picker')
if content_blocks.any?
  puts ''
  puts '📦 Found content_blocks (list_picker):'

  content_blocks.each do |block|
    sections = block.properties['sections'] || []

    sections.each_with_index do |section, s_idx|
      puts "  Section #{s_idx + 1}: #{section['title']}"
      items = section['items'] || []

      items.each_with_index do |item, i_idx|
        image_id = item['image_identifier'] || item['imageIdentifier']
        puts "    Item #{i_idx + 1}: #{item['title']}"
        puts "      image_identifier: #{image_id || 'NONE'}"
      end
    end
  end
end

puts ''
puts '=' * 80
puts 'Expected Image Identifiers for Template 355 (13 items):'
puts '=' * 80
puts 'Should be: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13'
puts ''
puts 'These identifiers exist in SharedAppleImage and should be used for:'
puts '  Item 1: Apple Pay'
puts '  Item 2: Apple Wallet'
puts '  Item 3: AR Experience'
puts '  Item 4: Authentication'
puts '  Item 5: File Sharing'
puts '  Item 6: iMessage Apps'
puts '  Item 7: List Picker'
puts '  Item 8: Media Sharing'
puts '  Item 9: QR Code'
puts '  Item 10: Quick Type'
puts '  Item 11: Rich Link Locator'
puts '  Item 12: Rich Links'
puts '  Item 13: Time Picker'
puts '=' * 80
