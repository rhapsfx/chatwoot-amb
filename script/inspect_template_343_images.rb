#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to inspect template 343 images
# Usage: rails runner script/inspect_template_343_images.rb

template = MessageTemplate.find(343)

puts '=' * 80
puts "🔍 Inspecting Template: #{template.name} (ID: #{template.id})"
puts '=' * 80

metadata = template.metadata
apple_content = metadata['apple_message_content']
content_attrs = apple_content['content_attributes']

puts "\n1️⃣  Checking pages for image identifiers..."
pages = content_attrs['pages'] || []

pages.each_with_index do |page, page_idx|
  puts "\n   Page #{page_idx + 1}: #{page['title']}"
  items = page['items'] || []

  items.each_with_index do |item, item_idx|
    puts "      Item #{item_idx + 1}: #{item['title']} (#{item['item_type']})"

    next unless item['item_type'] == 'singleSelect' || item['item_type'] == 'multiSelect'

    options = item['options'] || []
    puts "         Options: #{options.length}"

    options.each_with_index do |option, opt_idx|
      image_id = option['imageIdentifier']
      puts "            #{opt_idx + 1}. #{option['title']}"
      puts "               imageIdentifier: #{image_id || '(MISSING)'}"
    end
  end
end

puts "\n2️⃣  Checking if images exist in database..."
# Collect all image identifiers
image_identifiers = []
pages.each do |page|
  items = page['items'] || []
  items.each do |item|
    next unless item['item_type'] == 'singleSelect' || item['item_type'] == 'multiSelect'

    options = item['options'] || []
    options.each do |option|
      image_identifiers << option['imageIdentifier'] if option['imageIdentifier'].present?
    end
  end
end

puts "   Found #{image_identifiers.length} image identifier(s): #{image_identifiers.inspect}"

if image_identifiers.any?
  puts "\n3️⃣  Looking up images in AppleListPickerImage table..."

  inbox = template.account.inboxes.find_by(channel_type: 'Channel::AppleMessagesForBusiness')
  puts "   Using inbox: #{inbox&.name} (ID: #{inbox&.id})"

  images = AppleListPickerImage.where(identifier: image_identifiers)

  puts "\n   Database lookup results:"
  puts "   Total images found: #{images.count}"

  images.each do |img|
    puts "\n      Image ID: #{img.id}"
    puts "         identifier: #{img.identifier}"
    puts "         inbox_id: #{img.inbox_id}"
    puts "         account_id: #{img.account_id}"
    puts "         original_name: #{img.original_name}"
    puts "         has attachment: #{img.image.attached? ? '✅ YES' : '❌ NO'}"

    if img.image.attached?
      puts "         attachment size: #{img.image.blob.byte_size} bytes"
      puts "         content_type: #{img.image.blob.content_type}"
    end
  end

  # Check for missing images
  found_identifiers = images.map(&:identifier)
  missing_identifiers = image_identifiers - found_identifiers

  if missing_identifiers.any?
    puts "\n   ⚠️  WARNING: Missing images for identifiers: #{missing_identifiers.inspect}"
  else
    puts "\n   ✅ All image identifiers found in database"
  end
else
  puts '   ℹ️  No image identifiers found in template'
end

puts "\n4️⃣  Checking received/reply message images..."
received_msg = content_attrs['received_message'] || {}
reply_msg = content_attrs['reply_message'] || {}

puts "   Received message image: #{received_msg['image_identifier'] || '(none)'}"
puts "   Reply message image: #{reply_msg['image_identifier'] || '(none)'}"

if received_msg['image_identifier'].present?
  received_img = AppleListPickerImage.find_by(identifier: received_msg['image_identifier'])
  puts "      Received image in DB: #{received_img ? '✅ YES' : '❌ NO'}"
end

if reply_msg['image_identifier'].present?
  reply_img = AppleListPickerImage.find_by(identifier: reply_msg['image_identifier'])
  puts "      Reply image in DB: #{reply_img ? '✅ YES' : '❌ NO'}"
end

puts "\n" + ('=' * 80)
puts '💡 SUMMARY:'
puts '=' * 80

if image_identifiers.empty?
  puts '   ❌ PROBLEM: Template has NO image identifiers in options!'
  puts '   The template structure is missing imageIdentifier fields.'
  puts '   You need to recreate the template with the corrected script.'
else
  images_count = AppleListPickerImage.where(identifier: image_identifiers).count
  if images_count == image_identifiers.length
    puts "   ✅ All #{images_count} image(s) properly configured"
  else
    puts "   ⚠️  Only #{images_count}/#{image_identifiers.length} image(s) found in database"
    puts '   Missing images need to be uploaded'
  end
end

puts '=' * 80
