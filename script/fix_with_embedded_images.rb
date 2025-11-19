# frozen_string_literal: true

# Map embedded images to correct menu items
# Run with: rails runner script/fix_with_embedded_images.rb

puts '=' * 80
puts 'Fix Template 366 Using Embedded Images'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
block = template.content_blocks.find_by(block_type: 'list_picker')

props = block.properties
embedded_images = props['images'] || []
sections = props['sections'] || []
section = sections.first
items = section['items'] || []

puts "Template: #{template.name}"
puts ''

# Create lookup map: description -> identifier
image_lookup = {}
embedded_images.each do |img|
  desc = img['description']
  identifier = img['identifier']
  image_lookup[desc] = identifier
end

puts '=' * 80
puts 'EMBEDDED IMAGES LOOKUP'
puts '=' * 80
puts ''
image_lookup.each do |desc, id|
  puts "'#{desc}' => '#{id}'"
end
puts ''

# Correct mapping based on expected icons
CORRECT_MAPPING = {
  'Introduction with Intent ID' => 'list.bullet-512.png',
  'Send a List Picker' => 'list.bullet-512.png',
  'Receive an AR Image' => 'ARKit-512.png',
  'Apple Pay' => 'Apple_Pay_Mark.svg',
  'Schedule a Guitar Lesson' => 'Calendar-1024x1024@2x.png',
  'Fill in a Form' => 'Photos_512x512@2x.png',
  'Send an Image' => 'Preview_512x512@2x.png',
  'Send Documents' => 'Preview_512x512@2x.png',
  'Authentication' => 'FaceID@3x.png',
  'iMessage App' => 'AppStore-1024.png',
  'Apple Wallet' => 'Wallet-1024.png',
  'Rich Link Locator' => 'Maps_512x512@2x.png'
}.freeze

RECEIVED_IMAGE = 'Messages.png'

puts '=' * 80
puts 'CURRENT STATE'
puts '=' * 80
puts ''

puts 'Current menu items:'
items.each_with_index do |item, i|
  current_id = item['image_identifier']
  expected_desc = CORRECT_MAPPING[item['title']]
  correct_id = image_lookup[expected_desc]

  status = current_id == correct_id ? '✅' : '❌'

  puts "#{status} #{i + 1}. #{item['title']}"
  puts "   Current: #{current_id.inspect}"
  puts "   Expected: #{correct_id.inspect} (#{expected_desc})"
  puts ''
end

puts 'Received message:'
current_received = props['received_image_identifier']
correct_received = image_lookup[RECEIVED_IMAGE]
status = current_received == correct_received ? '✅' : '❌'
puts "#{status} Current: #{current_received.inspect}"
puts "   Expected: #{correct_received.inspect} (#{RECEIVED_IMAGE})"
puts ''

puts '=' * 80
puts 'APPLYING FIX'
puts '=' * 80
puts ''

# Fix each menu item
fixed_count = 0
items.each do |item|
  title = item['title']
  expected_desc = CORRECT_MAPPING[title]
  correct_id = image_lookup[expected_desc]

  if correct_id && item['image_identifier'] != correct_id
    old_id = item['image_identifier']
    item['image_identifier'] = correct_id
    fixed_count += 1
    puts "✅ Fixed: #{title}"
    puts "   #{old_id.inspect} → #{correct_id.inspect}"
  elsif !correct_id
    puts "⚠️  #{title}: No embedded image found for '#{expected_desc}'"
  end
end

puts ''

# Fix received message
if correct_received
  if props['received_image_identifier'] != correct_received
    old_received = props['received_image_identifier']
    props['received_image_identifier'] = correct_received
    puts '✅ Fixed received_image_identifier'
    puts "   #{old_received.inspect} → #{correct_received.inspect}"
  end
else
  puts "⚠️  No embedded image found for '#{RECEIVED_IMAGE}'"
end

puts ''
puts "Fixed #{fixed_count} menu item(s)"
puts ''

# Save
block.properties = props
block.save!
puts '✅ Saved to database'
puts ''

puts '=' * 80
puts 'VERIFICATION'
puts '=' * 80
puts ''

block.reload
props = block.properties
sections = props['sections'] || []
section = sections.first
items = section['items'] || []

puts 'Menu items after fix:'
items.each_with_index do |item, i|
  puts "  #{i + 1}. #{item['title']}: #{item['image_identifier'].inspect}"
end
puts ''

puts "Received image: #{props['received_image_identifier'].inspect}"
puts ''

all_correct = items.all? do |item|
  expected_desc = CORRECT_MAPPING[item['title']]
  correct_id = image_lookup[expected_desc]
  item['image_identifier'] == correct_id
end && props['received_image_identifier'] == correct_received

if all_correct
  puts '✅ All identifiers are now correct!'
else
  puts '⚠️  Some identifiers still incorrect'
end

puts ''
puts '=' * 80
puts 'COMPLETE'
puts '=' * 80
puts ''
puts "Restart the server and test by typing 'menu' keyword."
puts ''
