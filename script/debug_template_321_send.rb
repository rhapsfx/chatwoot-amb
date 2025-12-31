#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to see what SendListPickerService extracts from template 321

require 'json'

puts "\n" + ('=' * 80)
puts '🔍 Template 321 SendListPickerService Debug'
puts ('=' * 80) + "\n"

# Find template 321
template = MessageTemplate.find_by(id: 321)

unless template
  puts '❌ Template 321 not found'
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

# Simulate what SendListPickerService does
content_blocks.each_with_index do |block, idx|
  next unless block.block_type == 'list_picker'

  puts "Block #{idx + 1}: #{block.block_type}"
  puts ''

  props = block.properties

  puts "Properties keys: #{props.keys.inspect}"
  puts ''

  # This is what SendListPickerService sees as content_attributes
  content_attributes = props

  # Extract image identifiers like SendListPickerService does
  identifiers = Set.new

  # Add header image from received_message
  header_image = content_attributes['received_image_identifier']
  if header_image.present?
    puts "  ✅ Header image found: #{header_image}"
    identifiers << header_image
  else
    puts '  ⚠️  No received_image_identifier found'
  end

  # Add reply image if different from header
  reply_image = content_attributes['reply_image_identifier']
  if reply_image.present? && reply_image != header_image
    puts "  ✅ Reply image found: #{reply_image}"
    identifiers << reply_image
  end

  # Add images from list picker items
  sections = content_attributes['sections']
  if sections.is_a?(Array)
    puts "\n  📋 Processing #{sections.length} sections:"
    sections.each_with_index do |section, section_idx|
      items = section['items']
      next unless items.is_a?(Array)

      puts "    Section #{section_idx + 1}: #{items.length} items"

      items.each_with_index do |item, item_idx|
        # Handle both camelCase and snake_case
        image_id = item['imageIdentifier'] || item['image_identifier']
        if image_id.present?
          puts "      ✅ Item #{item_idx + 1}: #{item['title']} → #{image_id}"
          identifiers << image_id
        else
          puts "      ⚠️  Item #{item_idx + 1}: #{item['title']} → NO IMAGE"
          puts "         Item keys: #{item.keys.inspect}"
        end
      end
    end
  else
    puts '  ⚠️  sections is not an Array'
    if sections.is_a?(String)
      puts "     sections is a String: #{sections}"
    else
      puts "     sections class: #{sections.class}"
    end
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
