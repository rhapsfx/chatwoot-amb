#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to copy all guitar list picker images from inbox 5 to inbox 4
# This ensures all identifiers have the correct images
# Usage: rails runner script/sync_all_guitar_images.rb

puts '=' * 80
puts '🔄 Syncing All Guitar Images from Inbox 5 to Inbox 4'
puts '=' * 80

source_inbox_id = 5  # Rhaps AMB - has correct images
target_inbox_id = 4  # Apple Temp - has wrong images
identifiers_to_sync = %w[0 1 2 3 aha19_0]

puts "\n📋 Identifiers to sync: #{identifiers_to_sync.inspect}"

target_inbox = Inbox.find(target_inbox_id)
account = target_inbox.account

identifiers_to_sync.each do |identifier|
  puts "\n" + ('=' * 60)
  puts "Processing identifier: #{identifier.inspect}"
  puts '=' * 60

  # Find source image
  source_image = AppleListPickerImage.find_by(inbox_id: source_inbox_id, identifier: identifier)

  unless source_image&.image&.attached?
    puts "⚠️  Source image not found in inbox #{source_inbox_id}, skipping"
    next
  end

  puts '✅ Found source image:'
  puts "   Original name: #{source_image.original_name}"
  puts "   Description: #{source_image.description}"

  # Remove existing image in target inbox if it exists
  existing_target = AppleListPickerImage.find_by(inbox_id: target_inbox_id, identifier: identifier)
  if existing_target
    puts '🗑️  Removing old image from target inbox...'
    existing_target.destroy!
  end

  # Download source image data
  puts '📥 Downloading source image...'
  image_data = source_image.image.download
  puts "   Size: #{(image_data.bytesize / 1024.0).round(2)} KB"

  # Create new image record
  puts '📤 Creating new image in target inbox...'
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

  puts "✅ Successfully synced identifier #{identifier.inspect}"
  puts "   New image ID: #{new_image.id}"
  puts "   Image attached: #{new_image.image.attached? ? '✅' : '❌'}"
end

puts "\n" + ('=' * 80)
puts '✅ SYNC COMPLETE'
puts '=' * 80

# Verify all images
puts "\n🔍 Verification:"
verification = AppleListPickerImage.where(inbox_id: target_inbox_id, identifier: identifiers_to_sync)
puts "   Inbox #{target_inbox_id} now has #{verification.count}/#{identifiers_to_sync.length} synced images"
puts "   Identifiers: #{verification.pluck(:identifier).sort.inspect}"

verification.each do |img|
  status = img.image.attached? ? '✅' : '❌'
  puts "   - #{img.identifier}: #{img.original_name} #{status}"
end

if verification.count == identifiers_to_sync.length
  puts "\n🎉 All guitar images successfully synced to inbox #{target_inbox_id}!"
  puts "\n💡 Next step: Test the bot by typing 'listpicker' or 'guitar'"
else
  puts "\n⚠️  Some images are still missing"
end

puts '=' * 80
