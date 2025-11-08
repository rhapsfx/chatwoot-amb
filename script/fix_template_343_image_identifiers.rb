#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to fix template 343 image identifiers
# Usage: rails runner script/fix_template_343_image_identifiers.rb

template = MessageTemplate.find(343)

puts '=' * 80
puts '🔧 Fixing Template 343 Image Identifiers'
puts '=' * 80

metadata = template.metadata
apple_content = metadata['apple_message_content']
content_attrs = apple_content['content_attributes']

puts "\n1️⃣  Current image identifiers:"
pages = content_attrs['pages']
pages[0]['items'][0]['options'].each do |option|
  puts "   #{option['title']}: #{option['imageIdentifier']}"
end

puts "\n2️⃣  Updating to correct string identifiers..."

# Fix the guitar selection options
guitar_page = pages[0]
guitar_item = guitar_page['items'][0]

guitar_item['options'][0]['imageIdentifier'] = 'guitar_form_gibson'
guitar_item['options'][1]['imageIdentifier'] = 'guitar_form_martin'
guitar_item['options'][2]['imageIdentifier'] = 'guitar_form_prs'

puts '   ✅ Updated guitar options'

# Fix received and reply message images
content_attrs['received_message']['image_identifier'] = 'guitar_form_header'
content_attrs['reply_message']['image_identifier'] = 'guitar_form_header'

puts '   ✅ Updated received/reply message images'

# Save the template
apple_content['content_attributes'] = content_attrs
metadata['apple_message_content'] = apple_content
template.update!(metadata: metadata)

# Update content block too
content_block = template.content_blocks.find_by(block_type: 'form')
if content_block
  content_block.update!(properties: content_attrs)
  puts '   ✅ Updated content block'
end

puts "\n3️⃣  New image identifiers:"
pages[0]['items'][0]['options'].each do |option|
  puts "   #{option['title']}: #{option['imageIdentifier']}"
end

puts "\n4️⃣  Verifying images exist in database..."
image_identifiers = %w[guitar_form_gibson guitar_form_martin guitar_form_prs guitar_form_header]

images = AppleListPickerImage.where(identifier: image_identifiers, inbox_id: 6)
puts "   Found #{images.count}/#{image_identifiers.length} images in inbox 6"

images.each do |img|
  puts "      ✅ #{img.identifier} (ID: #{img.id}, attachment: #{img.image.attached? ? 'YES' : 'NO'})"
end

puts "\n" + ('=' * 80)
puts '✨ Template 343 Fixed!'
puts '=' * 80
puts 'Now restart Rails and test sending the form from n8n.'
puts 'The guitar images should display correctly.'
puts '=' * 80
