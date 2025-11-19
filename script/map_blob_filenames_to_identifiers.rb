# frozen_string_literal: true

# Map blob filenames to numeric identifiers
# Run with: rails runner script/map_blob_filenames_to_identifiers.rb

puts '=' * 80
puts 'Map Blob Filenames to Numeric Identifiers'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
inbox_id = template.account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').first&.id

numeric_images = AppleListPickerImage.where(inbox_id: inbox_id)
                                     .where("identifier ~ '^[0-9]+$'")
                                     .order(Arel.sql('CAST(identifier AS INTEGER)'))

puts 'Mapping numeric identifiers to actual blob filenames:'
puts ''

# Create a mapping hash
filename_to_identifier = {}

numeric_images.each do |img|
  if img.image.attached?
    blob = img.image.blob
    actual_filename = blob.filename.to_s

    puts "Identifier: '#{img.identifier}' => Filename: #{actual_filename.inspect}"
    filename_to_identifier[actual_filename] = img.identifier
  else
    puts "Identifier: '#{img.identifier}' => No attached file"
  end
end

puts ''
puts '=' * 80
puts 'REVERSE LOOKUP: Find identifiers for menu icons'
puts '=' * 80
puts ''

# Menu items from UI screenshots
menu_items = {
  'Introduction with Intent ID' => 'list.bullet-512.png',
  'Send a List Picker' => 'list.bullet-512.png',
  'Receive an AR Image' => 'ARKit-512.png',
  'Apple Pay' => 'Apple_Pay_Mark.svg',
  'Schedule a Guitar Lesson' => 'Calendar-1024×1024@2x.png',
  'Fill in a Form' => 'Photos_512×512@2x.png',
  'Send an Image' => 'Preview_512×512@2x.png',
  'Send Documents' => 'Preview_512×512@2x.png',
  'Authentication' => 'FaceID@3x.png',
  'iMessage App' => 'AppStore-1024.png',
  'Apple Wallet' => 'Wallet-1024.png',
  'Rich Link Locator' => 'Maps_512×512@2x.png'
}

received_message_filename = 'Messages.png'

puts 'Menu item mappings:'
puts ''

found_mapping = {}
menu_items.each do |title, filename|
  identifier = filename_to_identifier[filename]
  if identifier
    found_mapping[title] = identifier
    puts "✅ #{title}"
    puts "   Filename: #{filename}"
    puts "   Identifier: '#{identifier}'"
  else
    puts "❌ #{title}"
    puts "   Filename: #{filename}"
    puts '   Identifier: NOT FOUND'
  end
  puts ''
end

puts 'Received message:'
received_identifier = filename_to_identifier[received_message_filename]
if received_identifier
  puts "✅ Filename: #{received_message_filename}"
  puts "   Identifier: '#{received_identifier}'"
else
  puts "❌ Filename: #{received_message_filename}"
  puts '   Identifier: NOT FOUND'
end
puts ''

if found_mapping.keys.count == menu_items.keys.count && received_identifier
  puts '=' * 80
  puts 'SUCCESS! All mappings found'
  puts '=' * 80
  puts ''
  puts 'Ready to generate fix script with correct identifiers.'
else
  puts '=' * 80
  puts 'SOME MAPPINGS MISSING'
  puts '=' * 80
  puts ''
  puts "Found #{found_mapping.keys.count}/#{menu_items.keys.count} menu items"
  puts "Received message: #{received_identifier ? 'Found' : 'Missing'}"
end
puts ''
