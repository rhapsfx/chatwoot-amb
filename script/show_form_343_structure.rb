#\!/usr/bin/env ruby
# frozen_string_literal: true

# Show full structure of template 343 to debug form image identifiers

require 'json'

template = MessageTemplate.find_by(id: 343)

unless template
  puts '❌ Template 343 not found'
  exit 1
end

puts "\n" + ('=' * 80)
puts 'Template 343 Full Structure'
puts ('=' * 80) + "\n"

puts "Name: #{template.name}"
puts "Category: #{template.category}"
puts ''

puts "Content Blocks: #{template.content_blocks.count}"
puts ''

template.content_blocks.each_with_index do |block, idx|
  puts "Block #{idx + 1}:"
  puts "  block_type: #{block.block_type}"
  puts "  properties keys: #{block.properties.keys.inspect}"
  puts ''

  # For form blocks, show pages structure
  next unless block.block_type == 'form'

  pages = block.properties['pages'] || []
  puts "  Pages: #{pages.length}"

  pages.each_with_index do |page, page_idx|
    puts "\n  Page #{page_idx + 1}:"
    puts "    page_id: #{page['page_id']}"
    items = page['items'] || []
    puts "    items: #{items.length}"

    items.each_with_index do |item, item_idx|
      puts "\n    Item #{item_idx + 1}:"
      puts "      item_type: #{item['item_type']}"
      puts "      title: #{item['title']}"

      next unless item['item_type'] == 'singleSelect' || item['item_type'] == 'multiSelect'

      options = item['options'] || []
      puts "      options: #{options.length}"

      options.each_with_index do |option, opt_idx|
        puts "\n      Option #{opt_idx + 1}:"
        puts "        title: #{option['title']}"
        puts "        value: #{option['value']}"
        puts "        keys: #{option.keys.inspect}"
        # Check for image identifier in both formats
        if option['imageIdentifier']
          puts "        imageIdentifier: #{option['imageIdentifier']}"
        elsif option['image_identifier']
          puts "        image_identifier: #{option['image_identifier']}"
        else
          puts '        ⚠️  NO IMAGE IDENTIFIER'
        end
      end
    end
  end
end

puts "\n" + ('=' * 80)
