#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to see what FormService extracts from template 343

require 'json'

puts "\n" + ('=' * 80)
puts '🔍 Template 343 FormService Debug'
puts ('=' * 80) + "\n"

# Find template 343
template = MessageTemplate.find_by(id: 343)

unless template
  puts '❌ Template 343 not found'
  exit 1
end

puts "✅ Found template: #{template.name}"
puts ''

# Get the content_blocks
content_blocks = template.content_blocks || []

if content_blocks.empty?
  puts '⚠️  No content blocks'
  exit 1
end

puts "📋 Content Blocks: #{content_blocks.count}"
puts ''

# Simulate what FormService does
content_blocks.each_with_index do |block, idx|
  next unless block.block_type == 'form'

  puts "Block #{idx + 1}: #{block.block_type}"
  puts ''

  props = block.properties

  puts "Properties keys: #{props.keys.inspect}"
  puts ''

  # This is what FormService sees as form_config
  form_config = props

  puts 'Form config structure:'
  puts "  title: #{form_config['title']}"
  puts "  received_message: #{form_config['received_message'].present?}"
  puts "  reply_message: #{form_config['reply_message'].present?}"
  puts "  pages: #{form_config['pages']&.length || 0}"
  puts ''

  # Extract image identifiers like FormService does
  identifiers = Set.new

  # Add header image from received_message
  if form_config['received_message'].is_a?(Hash)
    header_image = form_config['received_message']['image_identifier']
    if header_image.present?
      puts "  ✅ Header image found: #{header_image}"
      identifiers << header_image
    else
      puts '  ⚠️  No header image in received_message'
      puts "     received_message keys: #{form_config['received_message'].keys.inspect}"
    end
  else
    puts "  ⚠️  received_message is not a Hash: #{form_config['received_message'].class}"
  end

  # Add reply image if different from header
  if form_config['reply_message'].is_a?(Hash)
    reply_image = form_config['reply_message']['image_identifier']
    if reply_image.present?
      puts "  ✅ Reply image found: #{reply_image}"
      identifiers << reply_image
    end
  end

  # Add images from form option items
  pages = form_config['pages']
  if pages.is_a?(Array)
    puts "\n  📄 Processing #{pages.length} pages:"
    pages.each_with_index do |page, page_idx|
      items = page['items']
      next unless items.is_a?(Array)

      puts "    Page #{page_idx + 1}: #{items.length} items"

      items.each_with_index do |item, item_idx|
        next unless %w[singleSelect multiSelect].include?(item['item_type'])

        puts "      Item #{item_idx + 1}: #{item['item_type']} - #{item['title']}"

        options = item['options']
        if options.is_a?(Array)
          puts "        #{options.length} options:"
          options.each_with_index do |option, opt_idx|
            image_id = option['imageIdentifier'] || option['image_identifier']
            if image_id.present?
              puts "          ✅ Option #{opt_idx + 1}: #{option['title']} → #{image_id}"
              identifiers << image_id
            else
              puts "          ⚠️  Option #{opt_idx + 1}: #{option['title']} → NO IMAGE"
              puts "             Option keys: #{option.keys.inspect}"
            end
          end
        else
          puts "        ⚠️  Options is not an Array: #{options.class}"
        end
      end
    end
  else
    puts "  ⚠️  pages is not an Array: #{pages.class}"
  end

  puts ''
  puts('=' * 80)
  puts "📊 Extracted Image Identifiers: #{identifiers.count}"
  puts('=' * 80)

  if identifiers.any?
    identifiers.each { |id| puts "  • #{id}" }
  else
    puts '  ⚠️  NO IMAGE IDENTIFIERS FOUND!'
  end

  puts ''

  # Check if these images exist in database
  puts('=' * 80)
  puts '🔍 Database Check'
  puts('=' * 80)
  puts ''

  # Get all AMB inboxes
  amb_inboxes = Inbox.where(channel_type: 'Channel::AppleMessagesForBusiness')

  amb_inboxes.each do |inbox|
    available = AppleListPickerImage.where(
      inbox_id: inbox.id,
      identifier: identifiers.to_a
    ).pluck(:identifier)

    puts "Inbox: #{inbox.name} (ID: #{inbox.id})"
    if available.count == identifiers.count
      puts "  ✅ All #{identifiers.count} images available"
    else
      missing = identifiers.to_a - available
      puts "  ⚠️  Missing #{missing.count} images: #{missing.inspect}"
    end
    puts ''
  end
end
