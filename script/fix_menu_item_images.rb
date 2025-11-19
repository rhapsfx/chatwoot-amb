# frozen_string_literal: true

# Fix template 366 item image identifiers to match UI configuration
# Run with: rails runner script/fix_menu_item_images.rb

puts '=' * 80
puts 'Fix Template 366 Menu Item Images'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
block = template.content_blocks.find_by(block_type: 'list_picker')

puts "Template: #{template.name}"
puts ''

# Correct image identifier mappings based on user's screenshots
# Map item titles to their correct image identifiers
CORRECT_IMAGES = {
  'Introduction with Intent ID' => 'list_bullet_512_12',      # Items 1-2: list.bullet-512.png
  'Send a List Picker' => 'list_bullet_512_12',
  'Receive an AR Image' => 'arkit_512',                        # Item 3: ARKit-512.png
  'Apple Pay' => 'apple_pay_mark_3',                           # Item 4: Apple_Pay_Mark.svg
  'Schedule a Guitar Lesson' => 'calendar_1024x1024_2x_2',    # Item 5: Calendar-1024×1024@2x.png
  'Fill in a Form' => 'photos_512x512_2x_3',                  # Item 6: Photos_512×512@2x.png
  'Send an Image' => 'preview_512x512_2x_4',                  # Item 7: Preview_512×512@2x.png
  'Send Documents' => 'preview_512x512_2x_4',                 # Item 8: Preview_512×512@2x.png (duplicate)
  'Authentication' => 'faceid_3x_5',                           # Item 9: FaceID@3x.png
  'iMessage App' => 'appstore_1024_6',                         # Item 10: AppStore-1024.png
  'Apple Wallet' => 'wallet_1024_7',                           # Item 11: Wallet-1024.png
  'Rich Link Locator' => 'maps_512x512_2x_8'                   # Item 12: Maps_512×512@2x.png
}.freeze

puts '=' * 80
puts 'CURRENT STATE'
puts '=' * 80
puts ''

props = block.properties
sections = props['sections'] || []
section = sections.first
items = section['items'] || []

items.each_with_index do |item, i|
  current_img = item['image_identifier'] || '(none)'
  expected_img = CORRECT_IMAGES[item['title']]
  status = current_img == expected_img ? '✅' : '❌'

  puts "#{status} Item #{i + 1}: #{item['title']}"
  puts "   Current:  #{current_img.inspect}"
  puts "   Expected: #{expected_img.inspect}" if expected_img
  puts ''
end

puts '=' * 80
puts 'APPLYING FIXES'
puts '=' * 80
puts ''

fixed_count = 0
items.each do |item|
  title = item['title']
  current_img = item['image_identifier'] || ''
  expected_img = CORRECT_IMAGES[title]

  next unless expected_img && current_img != expected_img

  item['image_identifier'] = expected_img
  fixed_count += 1
  puts "✅ Fixed: #{title}"
  puts "   #{current_img.inspect} → #{expected_img.inspect}"
end

puts ''
puts "Fixed #{fixed_count} item(s)"
puts ''

# Save the updated properties
block.properties = props
block.save!
puts '✅ Saved changes to ContentBlock'
puts ''

puts '=' * 80
puts 'VERIFICATION'
puts '=' * 80
puts ''

# Reload and verify
block.reload
template.reload

facade = AppleMessagesForBusiness::TemplateFacade.new(template)
data = facade.load_data('list_picker')

sections_verify = data['sections'] || []
section_verify = sections_verify.first
items_verify = section_verify['items'] || []

all_correct = true
items_verify.each_with_index do |item, i|
  current_img = item['image_identifier'] || '(none)'
  expected_img = CORRECT_IMAGES[item['title']]

  next unless expected_img && current_img != expected_img

  all_correct = false
  puts "❌ STILL WRONG: Item #{i + 1}: #{item['title']}"
  puts "   Current: #{current_img.inspect}"
  puts "   Expected: #{expected_img.inspect}"
end

if all_correct
  puts '✅ All item image identifiers are now CORRECT!'
  puts ''
  puts 'Summary:'
  items_verify.each_with_index do |item, i|
    puts "  #{i + 1}. #{item['title']}: #{item['image_identifier']}"
  end
else
  puts '⚠️  Some items still have incorrect image identifiers'
end

puts ''
puts '=' * 80
puts 'COMPLETE'
puts '=' * 80
