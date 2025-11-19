# frozen_string_literal: true

# Script to diagnose and fix template 366 image identifier issues
# Run with: rails runner script/fix_template_366_images.rb

puts '=' * 80
puts 'Template 366 Image Identifier Diagnosis & Fix'
puts '=' * 80
puts ''

# Find template 366
template = MessageTemplate.find_by(id: 366)

unless template
  puts '❌ Template 366 not found!'
  exit 1
end

puts "✅ Found template: #{template.name}"
puts "   Account ID: #{template.account_id}"
puts "   Channels: #{template.supported_channels.inspect}"
puts ''

# Check storage mechanism
if template.content_blocks.any?
  puts "📦 Storage: ContentBlocks (#{template.content_blocks.count} blocks)"
else
  puts '📦 Storage: Metadata JSONB'
end
puts ''

# Use TemplateFacade to read current data
facade = AppleMessagesForBusiness::TemplateFacade.new(template)
data = facade.load_data('list_picker')

puts '=' * 80
puts 'CURRENT DATABASE VALUES'
puts '=' * 80
puts ''

# Show sections and items
sections = data['sections'] || []
puts "Sections: #{sections.length}"
sections.each_with_index do |section, s_idx|
  puts ''
  puts "Section #{s_idx + 1}: #{section['title']}"
  items = section['items'] || []
  items.each_with_index do |item, i_idx|
    image_id = item['image_identifier'] || '(none)'
    puts "  Item #{i_idx + 1}: #{item['title']}"
    puts "    Image ID: #{image_id}"
  end
end

# Show received/reply message images
puts ''
puts 'Received Message:'
puts "  Image ID: #{data['received_image_identifier'] || '(none)'}"
puts ''
puts 'Reply Message:'
puts "  Image ID: #{data['reply_image_identifier'] || '(none)'}"
puts ''

# Define correct image identifier mappings based on user's screenshots
# Mapping item titles to expected image identifiers
EXPECTED_IMAGES = {
  # Items 1-2 use list.bullet-512.png
  '1. Introduction with Intent ID' => 'list_bullet_512_12',
  '2. Send a List Picker' => 'list_bullet_512_12',

  # Item 3 uses ARKit-512.png
  '3. Receive an AR Image' => 'arkit_512',

  # Item 4 uses Apple_Pay_Mark.svg
  '4. Apple Pay' => 'apple_pay_mark_3',

  # Item 5 uses Calendar-1024×1024@2x.png
  '5. Schedule a Guitar Lesson' => 'calendar_1024x1024_2x_2',

  # Item 6 uses Photos_512×512@2x.png
  '6. Fill in a Form' => 'photos_512x512_2x_3',

  # Item 7 uses Preview_512×512@2x.png
  '7. Send an Image' => 'preview_512x512_2x_4',

  # Item 8 uses Preview_512×512@2x.png (duplicate)
  '8. Send Documents' => 'preview_512x512_2x_4',

  # Item 9 uses FaceID@3x.png
  '9. Authentication' => 'faceid_3x_5',

  # Item 10 uses AppStore-1024.png
  '10. iMessage App' => 'appstore_1024_6',

  # Item 11 uses Wallet-1024.png
  '11. Apple Wallet' => 'wallet_1024_7',

  # Item 12 uses Maps_512×512@2x.png
  '12. Rich Link Locator' => 'maps_512x512_2x_8'
}.freeze

# Expected received message image (Messages.png)
EXPECTED_RECEIVED_IMAGE = 'messages_png'

puts '=' * 80
puts 'ANALYZING ISSUES'
puts '=' * 80
puts ''

issues_found = false

# Check each item
sections.each_with_index do |section, _s_idx|
  items = section['items'] || []
  items.each_with_index do |item, _i_idx|
    title = item['title']
    current_image_id = item['image_identifier'] || ''
    expected_image_id = EXPECTED_IMAGES[title]

    next unless expected_image_id && current_image_id != expected_image_id

    issues_found = true
    puts "❌ Item: #{title}"
    puts "   Current:  #{current_image_id.inspect}"
    puts "   Expected: #{expected_image_id}"
    puts ''
  end
end

# Check received message image
current_received = data['received_image_identifier'] || ''
if current_received != EXPECTED_RECEIVED_IMAGE
  issues_found = true
  puts '❌ Received Message Image:'
  puts "   Current:  #{current_received.inspect}"
  puts "   Expected: #{EXPECTED_RECEIVED_IMAGE}"
  puts ''
end

unless issues_found
  puts '✅ No issues found! All image identifiers are correct.'
  exit 0
end

puts '=' * 80
puts 'APPLYING FIXES'
puts '=' * 80
puts ''

# Apply fixes to the data
sections.each do |section|
  items = section['items'] || []
  items.each do |item|
    title = item['title']
    expected_image_id = EXPECTED_IMAGES[title]

    next unless expected_image_id && item['image_identifier'] != expected_image_id

    old_value = item['image_identifier']
    item['image_identifier'] = expected_image_id
    puts "✅ Fixed: #{title}"
    puts "   #{old_value.inspect} → #{expected_image_id}"
  end
end

# Fix received message image
if data['received_image_identifier'] != EXPECTED_RECEIVED_IMAGE
  old_value = data['received_image_identifier']
  data['received_image_identifier'] = EXPECTED_RECEIVED_IMAGE
  puts '✅ Fixed: Received Message Image'
  puts "   #{old_value.inspect} → #{EXPECTED_RECEIVED_IMAGE}"
end

puts ''

# Save the corrected data back to database
puts 'Saving corrected data to database...'

if template.content_blocks.any?
  # ContentBlocks storage
  block = template.content_blocks.find_by(block_type: 'list_picker')
  if block
    block.properties = data
    block.save!
    puts '✅ Saved to ContentBlocks'
  end
else
  # Metadata storage
  template.metadata ||= {}
  template.metadata['apple_message_content'] ||= {}
  template.metadata['apple_message_content']['content_attributes'] = data
  template.save!
  puts '✅ Saved to Metadata JSONB'
end

puts ''
puts '=' * 80
puts 'VERIFICATION'
puts '=' * 80
puts ''

# Reload and verify
template.reload
facade_verify = AppleMessagesForBusiness::TemplateFacade.new(template)
data_verify = facade_verify.load_data('list_picker')

puts 'Verifying fixes...'
sections_verify = data_verify['sections'] || []
all_correct = true

sections_verify.each do |section|
  items = section['items'] || []
  items.each do |item|
    title = item['title']
    current_image_id = item['image_identifier'] || ''
    expected_image_id = EXPECTED_IMAGES[title]

    if expected_image_id && current_image_id != expected_image_id
      all_correct = false
      puts "❌ STILL INCORRECT: #{title} → #{current_image_id.inspect}"
    end
  end
end

if data_verify['received_image_identifier'] != EXPECTED_RECEIVED_IMAGE
  all_correct = false
  puts "❌ STILL INCORRECT: Received Message → #{data_verify['received_image_identifier'].inspect}"
end

if all_correct
  puts '✅ All fixes verified successfully!'
else
  puts '⚠️  Some issues remain after save. Check database permissions or constraints.'
end

puts ''
puts '=' * 80
puts 'COMPLETE'
puts '=' * 80
