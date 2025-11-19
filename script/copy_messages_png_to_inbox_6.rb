# frozen_string_literal: true

# Copy messages_png from inbox 4 to inbox 6
# Run with: rails runner script/copy_messages_png_to_inbox_6.rb

puts '=' * 80
puts 'Copy messages_png from Inbox 4 to Inbox 6'
puts '=' * 80
puts ''

source_inbox_id = 4
target_inbox_id = 6

# Find source image
source_image = AppleListPickerImage.find_by(inbox_id: source_inbox_id, identifier: 'messages_png')

unless source_image
  puts "❌ Source image 'messages_png' not found in inbox #{source_inbox_id}"
  exit 1
end

puts "✅ Found source image in inbox #{source_inbox_id}"
puts "   ID: #{source_image.id}"
puts "   Description: #{source_image.description}"
puts "   Has attachment: #{source_image.image.attached?}"
puts ''

unless source_image.image.attached?
  puts '❌ Source image has no attachment!'
  exit 1
end

# Check if target already exists
existing_target = AppleListPickerImage.find_by(inbox_id: target_inbox_id, identifier: 'messages_png')

if existing_target
  if existing_target.image.attached?
    puts "✅ messages_png already exists in inbox #{target_inbox_id} with attachment"
    puts '   Nothing to do!'
    puts ''
    exit 0
  else
    puts "⚠️  messages_png exists in inbox #{target_inbox_id} but has no attachment"
    puts "   Will update it with attachment from inbox #{source_inbox_id}"
    puts ''
  end
end

# Download image data from source
puts '📥 Downloading image data from source...'
image_data = source_image.image.download
blob = source_image.image.blob

puts "   Size: #{blob.byte_size} bytes"
puts "   Content type: #{blob.content_type}"
puts "   Filename: #{blob.filename}"
puts ''

# Create or update target image
target_image = existing_target || AppleListPickerImage.new(
  inbox_id: target_inbox_id,
  account_id: source_image.account_id,
  identifier: 'messages_png'
)

target_image.description = source_image.description
target_image.original_name = source_image.original_name

puts "📤 Attaching image to inbox #{target_inbox_id}..."

target_image.image.attach(
  io: StringIO.new(image_data),
  filename: blob.filename.to_s,
  content_type: blob.content_type
)

target_image.save!

puts "✅ Successfully copied messages_png to inbox #{target_inbox_id}"
puts ''

# Verify
puts '=' * 80
puts 'VERIFICATION'
puts '=' * 80
puts ''

verification = AppleListPickerImage.find_by(inbox_id: target_inbox_id, identifier: 'messages_png')

if verification && verification.image.attached?
  puts "✅ Verified: messages_png now exists in inbox #{target_inbox_id}"
  puts "   ID: #{verification.id}"
  puts "   Description: #{verification.description}"
  puts "   Image attached: #{verification.image.attached?}"
  puts "   Blob size: #{verification.image.blob.byte_size} bytes"
  puts ''
  puts "🎉 Now the bot can send menu from inbox #{target_inbox_id} with all images!"
else
  puts '❌ Verification failed!'
end

puts ''
