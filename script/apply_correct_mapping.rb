# frozen_string_literal: true

# Apply correct image identifier mapping to template 366
# Run with: rails runner script/apply_correct_mapping.rb

puts '=' * 80
puts 'Apply Correct Image Mapping to Template 366'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
block = template.content_blocks.find_by(block_type: 'list_picker')

# TODO: Fill in the correct numeric identifiers below
# Check the Chatwoot UI to see which number ('0'-'13') corresponds to which icon

CORRECT_MAPPING = {
  # Menu items - map title to correct numeric identifier
  'Introduction with Intent ID' => '???',     # Which number has the list.bullet icon?
  'Send a List Picker' => '???',              # Which number has the list.bullet icon?
  'Receive an AR Image' => '???',             # Which number has the ARKit icon?
  'Apple Pay' => '???',                        # Which number has the Apple Pay logo?
  'Schedule a Guitar Lesson' => '???',        # Which number has the calendar icon?
  'Fill in a Form' => '???',                   # Which number has the photos icon?
  'Send an Image' => '???',                    # Which number has the preview icon?
  'Send Documents' => '???',                   # Which number has the preview icon?
  'Authentication' => '???',                   # Which number has the Face ID icon?
  'iMessage App' => '???',                     # Which number has the App Store icon?
  'Apple Wallet' => '???',                     # Which number has the Wallet icon?
  'Rich Link Locator' => '???'                 # Which number has the Maps icon?
}.freeze

CORRECT_RECEIVED_IMAGE = '???'  # Which number has the Messages.png icon?

# Validation
if CORRECT_MAPPING.values.any? { |v| v == '???' } || CORRECT_RECEIVED_IMAGE == '???'
  puts '❌ ERROR: You need to fill in the correct identifiers first!'
  puts ''
  puts "Edit this script and replace '???' with the actual numeric identifiers."
  puts 'Check the Chatwoot UI to find which number corresponds to which icon.'
  puts ''
  exit 1
end

puts '=' * 80
puts 'APPLYING MAPPING'
puts '=' * 80
puts ''

props = block.properties
sections = props['sections'] || []
section = sections.first
items = section['items'] || []

# Fix received message image
old_received = props['received_image_identifier']
props['received_image_identifier'] = CORRECT_RECEIVED_IMAGE
puts "✅ Received message image: #{old_received.inspect} → #{CORRECT_RECEIVED_IMAGE.inspect}"
puts ''

# Fix each menu item
fixed_count = 0
items.each do |item|
  title = item['title']
  old_id = item['image_identifier']
  correct_id = CORRECT_MAPPING[title]

  next unless correct_id && old_id != correct_id

  item['image_identifier'] = correct_id
  fixed_count += 1
  puts "✅ #{title}: #{old_id.inspect} → #{correct_id.inspect}"
end

puts ''
puts "Fixed #{fixed_count} item(s)"
puts ''

# Save
block.properties = props
block.save!
puts '✅ Saved to database'
puts ''

# Verify
block.reload
facade = AppleMessagesForBusiness::TemplateFacade.new(template)
data = facade.load_data('list_picker')

puts '=' * 80
puts 'VERIFICATION'
puts '=' * 80
puts ''

puts "Received image: #{data['received_image_identifier'].inspect}"
puts ''

sections_verify = data['sections'] || []
section_verify = sections_verify.first
items_verify = section_verify['items'] || []

puts 'Menu items:'
items_verify.each_with_index do |item, i|
  puts "  #{i + 1}. #{item['title']}: #{item['image_identifier'].inspect}"
end
puts ''

# Check if all identifiers exist
inbox_id = template.account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').first&.id
all_identifiers = items_verify.map { |i| i['image_identifier'] }.compact + [data['received_image_identifier']].compact
existing = AppleListPickerImage.where(inbox_id: inbox_id, identifier: all_identifiers).pluck(:identifier)
missing = all_identifiers - existing

if missing.any?
  puts '⚠️  Missing images:'
  missing.each { |id| puts "   - #{id}" }
else
  puts '✅ All images exist in database!'
end
puts ''
