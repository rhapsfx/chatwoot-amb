#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to upload Apple Store logo to all Apple Messages for Business inboxes
# This adds the 'apple_store_logo' image identifier used in store selection list picker

require_relative '../config/environment'
require 'stringio'

def upload_apple_store_logo
  # Path to the Apple logo image
  image_path = Rails.root.join('_apple/Acoustic-House-Bot-origin/acoustichouse/images/apple.jpg')

  unless File.exist?(image_path)
    puts "❌ Error: Image file not found at #{image_path}"
    exit 1
  end

  puts "📸 Found apple.jpg (#{File.size(image_path)} bytes)"

  # Find all Apple Messages for Business inboxes
  # Use polymorphic columns directly instead of joins
  inboxes = Inbox.where(channel_type: 'Channel::AppleMessagesForBusiness')

  if inboxes.empty?
    puts '⚠️  No Apple Messages for Business inboxes found'
    exit 0
  end

  puts "📥 Found #{inboxes.count} Apple Messages inbox(es)"

  inboxes.each do |inbox|
    puts "\n🔄 Processing inbox: #{inbox.name} (ID: #{inbox.id})"

    # Check if image already exists
    existing_image = AppleListPickerImage.find_by(
      inbox_id: inbox.id,
      identifier: 'apple_store_logo'
    )

    if existing_image
      puts "  ℹ️  Image 'apple_store_logo' already exists, skipping..."
      next
    end

    # Create new AppleListPickerImage record
    picker_image = AppleListPickerImage.new(
      inbox_id: inbox.id,
      account_id: inbox.account_id,
      identifier: 'apple_store_logo',
      description: 'Apple Store logo for store selection list picker',
      original_name: 'apple.jpg'
    )

    # Attach the image file using StringIO to avoid file handle issues
    image_data = File.binread(image_path)
    picker_image.image.attach(
      io: StringIO.new(image_data),
      filename: 'apple.jpg',
      content_type: 'image/jpeg'
    )

    if picker_image.save
      puts "  ✅ Successfully uploaded apple_store_logo to inbox #{inbox.id}"
    else
      puts "  ❌ Failed to upload: #{picker_image.errors.full_messages.join(', ')}"
    end
  end

  puts "\n✨ Upload complete!"
end

# Run the script
upload_apple_store_logo
