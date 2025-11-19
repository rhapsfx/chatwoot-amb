# frozen_string_literal: true

# Final fix for remaining issues
# Run with: rails runner script/final_fix_template_366.rb

puts '=' * 80
puts 'Final Fix for Template 366 Remaining Issues'
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
puts 'FIXING REMAINING ISSUES'
puts '=' * 80
puts ''

# Issue 1: Apple Wallet has trailing space in title
item_11 = items[10] # 0-indexed
if item_11
  puts "Item 11: #{item_11['title'].inspect}"
  if item_11['title'].strip == 'Apple Wallet'
    # Fix the title to remove trailing space
    puts '  ⚠️  Title has trailing space, fixing...'
    item_11['title'] = 'Apple Wallet'

    # Also fix the identifier
    correct_id = image_lookup['Wallet-1024.png']
    if correct_id && item_11['image_identifier'] != correct_id
      old_id = item_11['image_identifier']
      item_11['image_identifier'] = correct_id
      puts "  ✅ Fixed identifier: #{old_id.inspect} → #{correct_id.inspect}"
    end
  end
end
puts ''

# Issue 2: Received message - "messages_png" is from AppleListPickerImage table, not embedded
# We should keep it as is since it references the shared image table
puts 'Received message image:'
puts "  Current: #{props['received_image_identifier'].inspect}"
puts '  This references AppleListPickerImage table (inbox 4), which is correct.'
puts '  The embedded images array is for menu items only.'
puts ''

# Check if all menu items now have valid identifiers
puts '=' * 80
puts 'VERIFICATION'
puts '=' * 80
puts ''

all_valid = true
items.each_with_index do |item, i|
  identifier = item['image_identifier']

  # Check if this identifier exists in embedded images
  exists = embedded_images.any? { |img| img['identifier'] == identifier }

  status = exists ? '✅' : '❌'

  if exists
    # Find the image
    img = embedded_images.find { |im| im['identifier'] == identifier }
    puts "✅ Item #{i + 1}: #{item['title']}"
    puts "   Identifier: #{identifier.inspect}"
    puts "   Image: #{img['description']}"
  else
    all_valid = false
    puts "#{status} Item #{i + 1}: #{item['title']}"
    puts "   Identifier: #{identifier.inspect}"
    puts '   Not found in embedded images!'
  end
  puts ''
end

# Save
block.properties = props
block.save!
puts '✅ Saved to database'
puts ''

if all_valid
  puts '=' * 80
  puts 'SUCCESS! All menu items have valid embedded image identifiers'
  puts '=' * 80
  puts ''
  puts "Received message uses 'messages_png' from AppleListPickerImage table."
  puts ''
  puts "Next: Restart server and test by typing 'menu' keyword"
else
  puts '=' * 80
  puts '⚠️  Some items still have issues'
  puts '=' * 80
end
puts ''
