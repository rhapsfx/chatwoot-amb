# frozen_string_literal: true

# Rollback template 366 to working state and apply correct fix
# Run with: rails runner script/rollback_and_fix_correctly.rb

puts '=' * 80
puts 'Rollback and Fix Template 366 with CORRECT Identifiers'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
block = template.content_blocks.find_by(block_type: 'list_picker')

puts "Template: #{template.name}"
puts ''

# Based on the available images, these are the CORRECT mappings
# Using the aha19_* series which are the summary icons
CORRECT_MENU_IMAGES = {
  'Introduction with Intent ID' => 'aha19_2',    # summary_list_picker.png (items 1-2 use list picker icon)
  'Send a List Picker' => 'aha19_2',             # summary_list_picker.png
  'Receive an AR Image' => 'aha19_3',            # summary_ar_experience.png
  'Apple Pay' => 'aha19_1',                      # summary_apple_pay.png (or aha19_4, both are apple pay)
  'Schedule a Guitar Lesson' => 'aha19_5',       # summary_time_picker.png
  'Fill in a Form' => 'aha19_6',                 # summary_file_sharing.png (form icon)
  'Send an Image' => 'aha19_7',                  # summary_media_sharing.png
  'Send Documents' => 'aha19_6',                 # summary_file_sharing.png (or aha19_8, both file sharing)
  'Authentication' => 'aha19_10',                # summary_authentication.png
  'iMessage App' => 'aha19_11',                  # summary_imessage_apps.png
  'Apple Wallet' => 'aha19_12',                  # summary_apple_wallet.png
  'Rich Link Locator' => 'aha19_13'              # summary_rich_link_locator.png
}.freeze

# Received message should use aha19_0 (Messages icon)
CORRECT_RECEIVED_IMAGE = 'aha19_0'

puts '=' * 80
puts 'CURRENT STATE (After Bad Fix)'
puts '=' * 80
puts ''

props = block.properties
sections = props['sections'] || []
section = sections.first
items = section['items'] || []

puts 'Current item image identifiers:'
items.each_with_index do |item, i|
  puts "  #{i + 1}. #{item['title']}: #{item['image_identifier'].inspect}"
end
puts ''
puts "Current received_image_identifier: #{props['received_image_identifier'].inspect}"
puts ''

puts '=' * 80
puts 'APPLYING CORRECT FIX'
puts '=' * 80
puts ''

# Fix received message image
if props['received_image_identifier'] != CORRECT_RECEIVED_IMAGE
  old_value = props['received_image_identifier']
  props['received_image_identifier'] = CORRECT_RECEIVED_IMAGE
  puts '✅ Fixed received_image_identifier:'
  puts "   #{old_value.inspect} → #{CORRECT_RECEIVED_IMAGE.inspect}"
  puts ''
end

# Fix each item's image
fixed_count = 0
items.each do |item|
  title = item['title']
  current_img = item['image_identifier'] || ''
  correct_img = CORRECT_MENU_IMAGES[title]

  next unless correct_img && current_img != correct_img

  item['image_identifier'] = correct_img
  fixed_count += 1
  puts "✅ Fixed: #{title}"
  puts "   #{current_img.inspect} → #{correct_img.inspect}"
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

puts "Received message image: #{data['received_image_identifier'].inspect}"
puts ''

sections_verify = data['sections'] || []
section_verify = sections_verify.first
items_verify = section_verify['items'] || []

puts 'All menu items:'
items_verify.each_with_index do |item, i|
  identifier = item['image_identifier']
  puts "  #{i + 1}. #{item['title']}"
  puts "      Image: #{identifier.inspect}"
end

puts ''

# Check if all identifiers exist
puts 'Checking image availability:'
all_identifiers = items_verify.map { |i| i['image_identifier'] }.compact + [data['received_image_identifier']].compact
existing_identifiers = AppleListPickerImage.where(inbox_id: 4, identifier: all_identifiers).pluck(:identifier)
missing = all_identifiers - existing_identifiers

if missing.any?
  puts '⚠️  Missing images in database:'
  missing.each { |id| puts "   - #{id}" }
else
  puts '✅ All image identifiers exist in the database!'
end

puts ''
puts '=' * 80
puts 'COMPLETE'
puts '=' * 80
puts ''
puts "Next step: Restart server and test by typing 'menu' keyword"
