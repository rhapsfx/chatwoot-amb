#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to copy missing image identifier "0" from inbox 5 to inbox 4
# Usage: rails runner script/copy_missing_guitar_image.rb

puts '=' * 80
puts '📋 Copying Guitar Image "0" from Inbox 5 to Inbox 4'
puts '=' * 80

source_inbox_id = 5  # Rhaps AMB - has all images
target_inbox_id = 4  # Apple Temp - missing "0"
identifier = '0'

# Find source image
source_image = AppleListPickerImage.find_by(inbox_id: source_inbox_id, identifier: identifier)

unless source_image&.image&.attached?
  puts "❌ Source image not found in inbox #{source_inbox_id}"
  exit 1
end

puts "\n✅ Found source image:"
puts "   Inbox: #{source_image.inbox.name} (ID: #{source_image.inbox_id})"
puts "   Identifier: #{source_image.identifier}"
puts "   Original name: #{source_image.original_name}"
puts "   Description: #{source_image.description}"

# Check if target already exists
existing_target = AppleListPickerImage.find_by(inbox_id: target_inbox_id, identifier: identifier)
if existing_target
  puts "\n⚠️  Image already exists in target inbox, removing old one..."
  existing_target.destroy!
end

# Get target inbox
target_inbox = Inbox.find(target_inbox_id)
account = target_inbox.account

puts "\n🔄 Creating copy in inbox: #{target_inbox.name} (ID: #{target_inbox_id})"

# Download source image data first
puts '📥 Downloading source image...'
image_data = source_image.image.download

# Create new image record (without saving yet)
new_image = AppleListPickerImage.new(
  account_id: account.id,
  inbox_id: target_inbox_id,
  identifier: identifier,
  original_name: source_image.original_name,
  description: source_image.description
)

# Attach image before saving (required for validation)
puts '📤 Attaching image...'
new_image.image.attach(
  io: StringIO.new(image_data),
  filename: source_image.image.filename.to_s,
  content_type: source_image.image.content_type
)

# Now save with image attached
puts '💾 Saving record...'
new_image.save!

puts "\n✅ SUCCESS!"
puts "   Created AppleListPickerImage ID: #{new_image.id}"
puts "   Inbox: #{new_image.inbox.name} (ID: #{new_image.inbox_id})"
puts "   Identifier: #{new_image.identifier}"
puts "   Image attached: #{new_image.image.attached? ? '✅' : '❌'}"

# Verify
puts "\n🔍 Verification:"
verification = AppleListPickerImage.where(inbox_id: target_inbox_id, identifier: %w[0 1 2 3 4])
puts "   Inbox #{target_inbox_id} now has #{verification.count}/5 required images"
puts "   Identifiers: #{verification.pluck(:identifier).sort.inspect}"

if verification.count == 5
  puts "\n🎉 All guitar images now available in inbox #{target_inbox_id}!"
else
  puts "\n⚠️  Still missing some images"
end

puts '=' * 80
