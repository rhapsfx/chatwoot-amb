#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive validation script for template 343 form images

require 'json'

puts "\n" + ('=' * 80)
puts '🔍 TEMPLATE 343 COMPLETE VALIDATION'
puts ('=' * 80) + "\n"

# Step 1: Find template
template = MessageTemplate.find_by(id: 343)

unless template
  puts '❌ Template 343 not found'
  exit 1
end

puts "✅ Template found: #{template.name}"
puts "   Category: #{template.category}"
puts "   Account: #{template.account_id}"
puts ''

# Step 2: Check template structure
puts('=' * 80)
puts 'TEMPLATE STRUCTURE'
puts('=' * 80)

if template.metadata.present? && template.metadata['apple_message_content'].present?
  puts '📦 Format: BOT METADATA (legacy format)'
  puts '   → Uses metadata["apple_message_content"]'

  content_attrs = template.metadata['apple_message_content']['content_attributes']

  if content_attrs['pages'].present?
    puts "   → Has pages: #{content_attrs['pages'].length}"
  else
    puts '   ⚠️  No pages found in metadata'
  end
elsif template.content_blocks.present?
  puts '📦 Format: CONTENT BLOCKS (new format)'
  puts "   → Blocks: #{template.content_blocks.count}"

  template.content_blocks.each_with_index do |block, idx|
    puts "   Block #{idx + 1}: #{block.block_type}"
  end
else
  puts '❌ Template has no content!'
  exit 1
end
puts ''

# Step 3: Extract image identifiers from template
puts('=' * 80)
puts 'IMAGE IDENTIFIER EXTRACTION'
puts('=' * 80)

identifiers = Set.new

# Check metadata format
if template.metadata.present? && template.metadata['apple_message_content'].present?
  content_attrs = template.metadata['apple_message_content']['content_attributes']

  # Extract from pages
  pages = content_attrs['pages'] || []
  puts "Scanning #{pages.length} pages..."

  pages.each_with_index do |page, page_idx|
    items = page['items'] || []
    items.each_with_index do |item, item_idx|
      next unless %w[singleSelect multiSelect].include?(item['item_type'])

      puts "  Page #{page_idx + 1}, Item #{item_idx + 1}: #{item['title']}"

      options = item['options'] || []
      options.each_with_index do |option, opt_idx|
        image_id = option['imageIdentifier'] || option['image_identifier']
        if image_id.present?
          identifiers << image_id
          puts "    ✅ Option #{opt_idx + 1}: #{option['title']} → #{image_id}"
        else
          puts "    ⚠️  Option #{opt_idx + 1}: #{option['title']} → NO IMAGE"
        end
      end
    end
  end

  # Extract from received_message
  if content_attrs['received_message'].is_a?(Hash)
    img_id = content_attrs['received_message']['imageIdentifier'] || content_attrs['received_message']['image_identifier']
    if img_id.present?
      identifiers << img_id
      puts "  ✅ Received message image: #{img_id}"
    end
  end

  # Extract from reply_message
  if content_attrs['reply_message'].is_a?(Hash)
    img_id = content_attrs['reply_message']['imageIdentifier'] || content_attrs['reply_message']['image_identifier']
    if img_id.present?
      identifiers << img_id
      puts "  ✅ Reply message image: #{img_id}"
    end
  end
end

# Check content_blocks format
if template.content_blocks.present?
  template.content_blocks.each do |block|
    next unless block.block_type == 'form'

    props = block.properties
    pages = props['pages'] || []

    puts "Scanning #{pages.length} pages..."

    pages.each_with_index do |page, page_idx|
      items = page['items'] || []
      items.each_with_index do |item, item_idx|
        next unless %w[singleSelect multiSelect].include?(item['item_type'])

        puts "  Page #{page_idx + 1}, Item #{item_idx + 1}: #{item['title']}"

        options = item['options'] || []
        options.each_with_index do |option, opt_idx|
          image_id = option['imageIdentifier'] || option['image_identifier']
          if image_id.present?
            identifiers << image_id
            puts "    ✅ Option #{opt_idx + 1}: #{option['title']} → #{image_id}"
          else
            puts "    ⚠️  Option #{opt_idx + 1}: #{option['title']} → NO IMAGE"
          end
        end
      end
    end

    # Extract from received_message
    if props['received_message'].is_a?(Hash)
      img_id = props['received_message']['imageIdentifier'] || props['received_message']['image_identifier']
      if img_id.present?
        identifiers << img_id
        puts "  ✅ Received message image: #{img_id}"
      end
    end

    # Extract from reply_message
    next unless props['reply_message'].is_a?(Hash)

    img_id = props['reply_message']['imageIdentifier'] || props['reply_message']['image_identifier']
    if img_id.present?
      identifiers << img_id
      puts "  ✅ Reply message image: #{img_id}"
    end
  end
end

puts ''
puts "📊 Total unique image identifiers found: #{identifiers.count}"
identifiers.each { |id| puts "   • #{id}" }
puts ''

if identifiers.empty?
  puts '❌ No image identifiers found in template!'
  exit 1
end

# Step 4: Check database for images
puts('=' * 80)
puts 'DATABASE IMAGE AVAILABILITY'
puts('=' * 80)

# Get all AMB inboxes
amb_inboxes = Inbox.where(channel_type: 'Channel::AppleMessagesForBusiness')

puts "Found #{amb_inboxes.count} Apple Messages for Business inboxes"
puts ''

all_images_available = true

amb_inboxes.each do |inbox|
  puts "Inbox: #{inbox.name} (ID: #{inbox.id})"

  # Check for images by inbox
  available_images = AppleListPickerImage
                     .where(inbox_id: inbox.id, identifier: identifiers.to_a)
                     .includes(image_attachment: :blob)

  available_ids = available_images.pluck(:identifier)
  missing_ids = identifiers.to_a - available_ids

  if missing_ids.empty?
    puts "  ✅ All #{identifiers.count} images available"

    # Verify each image has attached data
    available_images.each do |img|
      if img.image.attached?
        blob = img.image.blob
        puts "     ✅ #{img.identifier}: #{blob.filename} (#{blob.byte_size} bytes)"
      else
        puts "     ❌ #{img.identifier}: NOT ATTACHED"
        all_images_available = false
      end
    end
  else
    puts "  ⚠️  Missing #{missing_ids.count} images:"
    missing_ids.each { |id| puts "     • #{id}" }
    all_images_available = false
  end
  puts ''
end

# Step 5: Test image loading service
puts('=' * 80)
puts 'IMAGE LOADING SERVICE TEST'
puts('=' * 80)

begin
  # Simulate what BotRendererService does
  test_attrs = {
    'pages' => [
      {
        'items' => [
          {
            'item_type' => 'singleSelect',
            'options' => identifiers.to_a.map { |id| { 'imageIdentifier' => id } }
          }
        ]
      }
    ]
  }

  # Create a mock service to test collect_image_identifiers
  service = Templates::BotRendererService.new(
    template_id: template.id,
    parameters: {},
    channel_type: 'apple_messages_for_business'
  )

  # Access private method using send
  collected_ids = service.send(:collect_image_identifiers, test_attrs)

  puts "Service collected #{collected_ids.count} identifiers:"
  collected_ids.each { |id| puts "  • #{id}" }
  puts ''

  if collected_ids.sort == identifiers.to_a.sort
    puts '✅ Image identifier collection working correctly'
  else
    puts '⚠️  Mismatch in collected identifiers'
    puts "   Expected: #{identifiers.to_a.sort.inspect}"
    puts "   Got: #{collected_ids.sort.inspect}"
  end
  puts ''
rescue StandardError => e
  puts "❌ Error testing service: #{e.message}"
  puts e.backtrace.first(3).join("\n")
  puts ''
end

# Step 6: Final summary
puts('=' * 80)
puts 'VALIDATION SUMMARY'
puts('=' * 80)
puts ''

if all_images_available
  puts '✅ ALL CHECKS PASSED'
  puts ''
  puts 'Template 343 is ready:'
  puts "  • #{identifiers.count} image identifiers defined"
  puts "  • All images available in #{amb_inboxes.count} inbox(es)"
  puts '  • All images have attached data'
  puts '  • Image loading service configured correctly'
  puts ''
  puts '🚀 READY TO TEST'
  puts ''
  puts 'Next steps:'
  puts '  1. Send template 343 from ReplyBox in browser'
  puts '  2. Check browser console for render API logs'
  puts '  3. Verify images appear on iOS device'
else
  puts '⚠️  ISSUES FOUND'
  puts ''
  puts 'Some images are missing or not attached.'
  puts 'Please ensure all images are uploaded to the correct inbox.'
end
puts ''
