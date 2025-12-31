#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to dump template 343's full structure

require 'json'

puts "\n" + ('=' * 80)
puts '🔍 Template 343 Structure Debug'
puts ('=' * 80) + "\n"

template = MessageTemplate.find_by(id: 343)

unless template
  puts '❌ Template 343 not found'
  exit 1
end

puts "✅ Found template: #{template.name}"
puts "   ID: #{template.id}"
puts "   Category: #{template.category}"
puts ''

puts '📋 Full Content Blocks Structure:'
puts '-' * 80
puts ''

content_blocks = template.content_blocks || []

if content_blocks.empty?
  puts '⚠️  No content blocks found'
  exit 1
end

content_blocks.each_with_index do |block, idx|
  puts "\nBlock #{idx + 1}:"
  puts "  Class: #{block.class.name}"
  puts "  Block Type: #{block.block_type}"
  puts "  Block Config class: #{block.block_config.class.name}"
  puts ''
  puts '  Full Block Config:'
  puts JSON.pretty_generate(block.block_config)
end

puts ''
puts '=' * 80
puts '📊 Detailed Analysis'
puts '=' * 80

content_blocks.each_with_index do |block, idx|
  puts "\nBlock #{idx + 1}: #{block.block_type}"

  next unless block.block_type == 'form'

  config = block.block_config

  # Check for form section
  if config['form']
    form = config['form']
    puts '  ✅ Form section found'
    puts "     Keys: #{form.keys.inspect}"

    if form['images']
      puts "     Images array: #{form['images'].count} images"
      form['images'].each_with_index do |img, i|
        puts "       Image #{i + 1}: #{img['identifier']}"
      end
    else
      puts '     ⚠️  No images array in form'
    end

    if form['fields']
      puts "     Fields array: #{form['fields'].count} fields"
      form['fields'].each_with_index do |field, i|
        puts "       Field #{i + 1}: #{field['field_type']} - #{field['label']}"
        next unless field['options']

        field['options'].each do |opt|
          puts "         Option image: #{opt['image_identifier']}" if opt['image_identifier']
        end
      end
    end
  else
    puts "  ⚠️  No 'form' key in config"
  end

  # Check for received_message
  received = config['received_message'] || config['receivedMessage']
  if received
    puts '  ✅ Received message found'
    puts "     Keys: #{received.keys.inspect}"
    puts "     Header image: #{received['image_identifier']}" if received['image_identifier']
  else
    puts '  ⚠️  No received_message'
  end
end

puts ''
