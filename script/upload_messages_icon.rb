# frozen_string_literal: true

# DEPRECATED: This script is deprecated as of November 2025
# Use SharedAppleImage model for account-wide images instead
#
# New approach:
#   SharedAppleImage.create!(
#     account_id: 1,
#     identifier: 'messages_png',
#     image_type: 'system',
#     description: 'Messages app icon',
#     image: File.open('path/to/Messages.png')
#   )
#
# Or use the migration scripts:
#   rails runner script/migrate_system_images_to_shared.rb --execute
#
# This script remains for backwards compatibility only.
# Will be removed in: Q2 2026
#
# See: docs/apple-messages/DEPRECATION_TIMELINE.md

# Upload Messages icon to AppleListPickerImage table
# Run with: rails runner script/upload_messages_icon.rb

puts '=' * 80
puts 'Upload Messages Icon to AppleListPickerImage Table'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
inbox_id = 4 # Apple Temp (No branding)

puts "Template: #{template.name}"
puts "Target Inbox: #{inbox_id}"
puts ''

# Check if messages_png already exists
existing = AppleListPickerImage.find_by(inbox_id: inbox_id, identifier: 'messages_png')

if existing
  puts "✅ 'messages_png' already exists in inbox #{inbox_id}"
  puts ''
  exit 0
end

# Check for Messages icon in embedded images or aha19 series
# Option 1: Check embedded images in template
block = template.content_blocks.find_by(block_type: 'list_picker')
props = block.properties
embedded_images = props['images'] || []

messages_img = embedded_images.find { |img| (img['description'] || '').downcase.include?('messages') }

if messages_img
  puts '✅ Found Messages icon in embedded images:'
  puts "   Identifier: #{messages_img['identifier']}"
  puts "   Description: #{messages_img['description']}"
  puts ''

  # Upload this image to AppleListPickerImage table
  puts 'Uploading to AppleListPickerImage table...'

  image_data_b64 = messages_img['preview'] || messages_img['data']
  image_data = Base64.strict_decode64(image_data_b64)

  new_image = AppleListPickerImage.new(
    inbox_id: inbox_id,
    account_id: template.account_id,
    identifier: 'messages_png',
    original_name: 'Messages.png',
    description: 'Messages app icon for received message'
  )

  new_image.image.attach(
    io: StringIO.new(image_data),
    filename: 'Messages.png',
    content_type: 'image/png'
  )

  new_image.save!

  puts "✅ Successfully uploaded Messages icon with identifier 'messages_png'"
  puts ''
else
  # Option 2: Check aha19_0 (Messages icon)
  puts '❌ No Messages icon found in embedded images'
  puts ''
  puts 'Checking aha19_0 (which might be the Messages icon)...'

  aha19_0 = AppleListPickerImage.find_by(inbox_id: inbox_id, identifier: 'aha19_0')

  if aha19_0 && aha19_0.image.attached?
    puts "✅ Found aha19_0, will copy as 'messages_png'"

    image_data = aha19_0.image.download

    new_image = AppleListPickerImage.new(
      inbox_id: inbox_id,
      account_id: template.account_id,
      identifier: 'messages_png',
      original_name: 'Messages.png',
      description: 'Messages app icon for received message'
    )

    new_image.image.attach(
      io: StringIO.new(image_data),
      filename: 'Messages.png',
      content_type: aha19_0.image.content_type
    )

    new_image.save!

    puts "✅ Successfully created 'messages_png' from aha19_0"
    puts ''
  else
    puts '❌ Cannot find Messages icon to upload'
    puts ''
    puts "You'll need to manually upload a Messages.png icon with identifier 'messages_png'"
    exit 1
  end
end

puts '=' * 80
puts 'VERIFICATION'
puts '=' * 80
puts ''

messages_icon = AppleListPickerImage.find_by(inbox_id: inbox_id, identifier: 'messages_png')
if messages_icon
  puts "✅ 'messages_png' now exists in AppleListPickerImage table"
  puts "   ID: #{messages_icon.id}"
  puts "   Description: #{messages_icon.description}"
  puts "   Image attached: #{messages_icon.image.attached?}"
  puts ''
  puts "Next: Restart server and test by typing 'menu' keyword"
else
  puts '❌ Upload failed'
end
puts ''
