#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to sync identifier "4" from inbox 5 to inbox 4
# This is the receivedMessage header image
# Usage: rails runner script/sync_identifier_4.rb

puts '=' * 80
puts '🔄 Syncing Identifier "4" from Inbox 5 to Inbox 4'
puts '=' * 80

source_inbox_id = 5  # Rhaps AMB - has correct images
target_inbox_id = 4  # Apple Temp - needs correct header image
identifier = '4'

# Find source image
source_image = AppleListPickerImage.find_by(inbox_id: source_inbox_id, identifier: identifier)

unless source_image&.image&.attached?
  puts "❌ Source image '4' not found in inbox #{source_inbox_id}"
  exit 1
end

puts "\n✅ Found source image in inbox #{source_inbox_id}:"
puts "   Original name: #{source_image.original_name}"
puts "   Description: #{source_image.description}"
puts "   Size: #{(source_image.image.byte_size / 1024.0).round(2)} KB"

# Remove existing image in target inbox
existing_target = AppleListPickerImage.find_by(inbox_id: target_inbox_id, identifier: identifier)
if existing_target
  puts "\n🗑️  Removing old image '4' from inbox #{target_inbox_id}..."
  existing_target.destroy!
end

# Get target inbox
target_inbox = Inbox.find(target_inbox_id)
account = target_inbox.account

puts "\n📥 Downloading source image..."
image_data = source_image.image.download

puts "📤 Creating new image in inbox #{target_inbox_id}..."
new_image = AppleListPickerImage.new(
  account_id: account.id,
  inbox_id: target_inbox_id,
  identifier: identifier,
  original_name: source_image.original_name,
  description: source_image.description
)

# Attach image
new_image.image.attach(
  io: StringIO.new(image_data),
  filename: source_image.image.filename.to_s,
  content_type: source_image.image.content_type
)

new_image.save!

puts "\n✅ SUCCESS! Identifier '4' synced to inbox #{target_inbox_id}"
puts "   New image ID: #{new_image.id}"
puts "   Image attached: #{new_image.image.attached? ? '✅' : '❌'}"
puts "   Size: #{(new_image.image.byte_size / 1024.0).round(2)} KB"

puts "\n" + ('=' * 80)
puts '💡 Next step: Test the bot by typing "listpicker" to see the correct header'
puts '=' * 80
