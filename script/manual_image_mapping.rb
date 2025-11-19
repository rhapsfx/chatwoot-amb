# frozen_string_literal: true

# Manual mapping guide for template 366 menu items
# Run with: rails runner script/manual_image_mapping.rb

puts '=' * 80
puts 'Template 366 Manual Image Mapping Guide'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
block = template.content_blocks.find_by(block_type: 'list_picker')
inbox_id = template.account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').first&.id

puts 'INSTRUCTIONS:'
puts "The template needs to be mapped to numeric identifiers '0' through '13'."
puts "You'll need to check the Chatwoot UI to see which number corresponds to which icon."
puts ''
puts '=' * 80
puts 'MENU ITEMS THAT NEED MAPPING'
puts '=' * 80
puts ''

props = block.properties
sections = props['sections'] || []
section = sections.first
section['items'] || []

puts 'Based on your UI screenshots, these are the menu items and their expected icons:'
puts ''

expected_mapping = {
  1 => { title: 'Introduction with Intent ID', icon: 'list.bullet-512.png (list icon)' },
  2 => { title: 'Send a List Picker', icon: 'list.bullet-512.png (list icon)' },
  3 => { title: 'Receive an AR Image', icon: 'ARKit-512.png (AR icon)' },
  4 => { title: 'Apple Pay', icon: 'Apple_Pay_Mark.svg (Apple Pay logo)' },
  5 => { title: 'Schedule a Guitar Lesson', icon: 'Calendar-1024×1024@2x.png (calendar icon)' },
  6 => { title: 'Fill in a Form', icon: 'Photos_512×512@2x.png (photos icon)' },
  7 => { title: 'Send an Image', icon: 'Preview_512×512@2x.png (preview icon)' },
  8 => { title: 'Send Documents', icon: 'Preview_512×512@2x.png (preview icon)' },
  9 => { title: 'Authentication', icon: 'FaceID@3x.png (Face ID icon)' },
  10 => { title: 'iMessage App', icon: 'AppStore-1024.png (App Store icon)' },
  11 => { title: 'Apple Wallet', icon: 'Wallet-1024.png (Wallet icon)' },
  12 => { title: 'Rich Link Locator', icon: 'Maps_512×512@2x.png (Maps icon)' }
}

expected_mapping.each do |num, info|
  puts "Item #{num}: #{info[:title]}"
  puts "   Expected icon: #{info[:icon]}"
  puts "   Needs identifier: ??? (you'll need to find which number '0'-'13' has this icon)"
  puts ''
end

puts 'Received message:'
puts '   Expected icon: Messages.png (Messages app icon)'
puts "   Needs identifier: ??? (you'll need to find which number '0'-'13' has this icon)"
puts ''

puts '=' * 80
puts 'AVAILABLE NUMERIC IDENTIFIERS'
puts '=' * 80
puts ''

numeric_images = AppleListPickerImage.where(inbox_id: inbox_id)
                                     .where("identifier ~ '^[0-9]+$'")
                                     .order(Arel.sql('CAST(identifier AS INTEGER)'))

puts 'These are the numeric image identifiers available:'
numeric_images.each do |img|
  puts "  Identifier: '#{img.identifier}'"
end
puts ''

puts '=' * 80
puts 'HOW TO FIND THE MAPPING'
puts '=' * 80
puts ''
puts '1. Go to Chatwoot UI → Inbox 4 → Apple List Picker Images section'
puts '2. For each numeric identifier above, check what icon it displays'
puts '3. Create a mapping file showing which identifier goes with which menu item'
puts ''
puts 'Example mapping format:'
puts "  '0' => 'Messages.png (for received message)'"
puts "  '1' => 'list.bullet-512.png'"
puts "  '2' => 'ARKit-512.png'"
puts '  etc...'
puts ''
puts '=' * 80
puts 'ALTERNATIVE: Check original template state'
puts '=' * 80
puts ''
puts 'If you know what the identifiers were BEFORE the fix broke it,'
puts 'we can restore to that state.'
puts ''
puts 'Check the template in the UI - do the image selectors show which'
puts 'numeric identifier was originally selected for each item?'
puts ''
