# frozen_string_literal: true

# Diagnose template 366 current state and map correct identifiers
# Run with: rails runner script/diagnose_and_map_images.rb

puts '=' * 80
puts 'Template 366 Image Mapping Diagnostic'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
block = template.content_blocks.find_by(block_type: 'list_picker')

puts "Template: #{template.name}"
puts ''

# Get inbox_id for image lookup
inbox_id = template.account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').first&.id

if inbox_id.nil?
  puts '❌ No Apple Messages inbox found for this account'
  exit 1
end

puts "Inbox ID: #{inbox_id}"
puts ''

puts '=' * 80
puts 'CURRENT BROKEN STATE'
puts '=' * 80
puts ''

props = block.properties
sections = props['sections'] || []
section = sections.first
items = section['items'] || []

puts 'Current menu items and their image identifiers:'
items.each_with_index do |item, i|
  identifier = item['image_identifier']
  exists = AppleListPickerImage.exists?(inbox_id: inbox_id, identifier: identifier)
  status = exists ? '✅' : '❌ MISSING'

  puts "#{i + 1}. #{item['title']}"
  puts "   Identifier: #{identifier.inspect}"
  puts "   Status: #{status}"
  puts ''
end

puts 'Received message image:'
received_id = props['received_image_identifier']
exists = AppleListPickerImage.exists?(inbox_id: inbox_id, identifier: received_id)
status = exists ? '✅' : '❌ MISSING'
puts "   Identifier: #{received_id.inspect}"
puts "   Status: #{status}"
puts ''

puts '=' * 80
puts 'AVAILABLE IMAGES (with original filenames)'
puts '=' * 80
puts ''

images = AppleListPickerImage.where(inbox_id: inbox_id).order(:id)
puts "Found #{images.count} image(s) in database:"
puts ''

# Group by original_name pattern to help identify the right images
images.each_with_index do |img, i|
  puts "#{i + 1}. Identifier: '#{img.identifier}'"
  puts "   Original Name: #{img.original_name.inspect}"
  puts "   Description: #{img.description.inspect}" if img.description.present?
  puts ''
end

puts '=' * 80
puts 'SUGGESTED MAPPING (based on original filenames)'
puts '=' * 80
puts ''

# Try to intelligently map based on original filenames
# Menu items from the user's screenshots:
menu_items = [
  { title: 'Introduction with Intent ID', expected_file: 'list.bullet-512.png' },
  { title: 'Send a List Picker', expected_file: 'list.bullet-512.png' },
  { title: 'Receive an AR Image', expected_file: 'ARKit-512.png' },
  { title: 'Apple Pay', expected_file: 'Apple_Pay_Mark.svg' },
  { title: 'Schedule a Guitar Lesson', expected_file: 'Calendar-1024×1024@2x.png' },
  { title: 'Fill in a Form', expected_file: 'Photos_512×512@2x.png' },
  { title: 'Send an Image', expected_file: 'Preview_512×512@2x.png' },
  { title: 'Send Documents', expected_file: 'Preview_512×512@2x.png' },
  { title: 'Authentication', expected_file: 'FaceID@3x.png' },
  { title: 'iMessage App', expected_file: 'AppStore-1024.png' },
  { title: 'Apple Wallet', expected_file: 'Wallet-1024.png' },
  { title: 'Rich Link Locator', expected_file: 'Maps_512×512@2x.png' }
]

received_expected = 'Messages.png'

puts 'Looking for matches between menu items and available images:'
puts ''

menu_items.each do |item|
  puts "#{item[:title]}:"
  puts "  Expected file: #{item[:expected_file]}"

  # Try to find matching image
  matching_images = images.select do |img|
    # Check if original_name contains key parts of expected filename
    original = img.original_name || ''
    expected = item[:expected_file]

    # Normalize for comparison
    original_normalized = original.downcase.gsub(/[^a-z0-9]/, '')
    expected_normalized = expected.downcase.gsub(/[^a-z0-9]/, '')

    # Check for substring match
    original_normalized.include?(expected_normalized.split('x').first) ||
      expected_normalized.include?(original_normalized.split('x').first)
  end

  if matching_images.any?
    puts '  ✅ Possible match(es):'
    matching_images.each do |img|
      puts "     Identifier: '#{img.identifier}' (#{img.original_name})"
    end
  else
    puts '  ❌ No automatic match found'
  end
  puts ''
end

puts 'Received message image:'
puts "  Expected file: #{received_expected}"
matching_received = images.find { |img| (img.original_name || '').downcase.include?('messages') }
if matching_received
  puts "  ✅ Possible match: '#{matching_received.identifier}' (#{matching_received.original_name})"
else
  puts '  ❌ No automatic match found'
end
puts ''

puts '=' * 80
puts 'NEXT STEPS'
puts '=' * 80
puts ''
puts 'Review the available images above and identify the correct identifier for each menu item.'
puts 'Once you know the correct mapping, I can create a script to apply it.'
puts ''
