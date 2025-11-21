#!/usr/bin/env ruby
# frozen_string_literal: true

# DEPRECATED: This script is deprecated as of November 2025
# Use SharedAppleImage model for account-wide images instead
#
# New approach:
#   SharedAppleImage.create!(
#     account_id: 1,
#     identifier: 'time_picker_lesson',
#     image_type: 'template',
#     description: 'Time Picker - Guitar Lesson Scheduling',
#     image: File.open('_apple/Acoustic-House-Bot-origin/acoustichouse/images/time_picker.png')
#   )
#
# Or use the migration scripts:
#   rails runner script/migrate_branding_images_to_shared.rb --execute
#
# This script remains for backwards compatibility only.
# Will be removed in: Q2 2026
#
# See: docs/apple-messages/DEPRECATION_TIMELINE.md

# Script to upload time_picker.png to ActiveStorage for Apple Messages for Business
# Usage: rails runner script/upload_time_picker_image.rb

require 'base64'
require 'stringio'

IMAGE_PATH = '/Users/rhaps/LocalGit/chatwoot/_apple/Acoustic-House-Bot-origin/acoustichouse/images/time_picker.png'
IMAGE_IDENTIFIER = 'time_picker_lesson'

puts '🖼️  Uploading time_picker.png to ActiveStorage...'
puts '=' * 80

# Check if file exists
unless File.exist?(IMAGE_PATH)
  puts "❌ Error: Image file not found at #{IMAGE_PATH}"
  exit 1
end

# Get all Apple Messages for Business inboxes
channels = Channel::AppleMessagesForBusiness.all

if channels.empty?
  puts '❌ Error: No Apple Messages for Business channels found'
  exit 1
end

puts "📱 Found #{channels.count} Apple Messages for Business channel(s)"
puts

success_count = 0
skip_count = 0
error_count = 0

channels.each do |channel|
  inbox = channel.inbox
  puts "Processing inbox: #{inbox.name} (ID: #{inbox.id})"

  # Check if image already exists for this inbox
  existing = AppleListPickerImage.find_by(
    inbox_id: inbox.id,
    identifier: IMAGE_IDENTIFIER
  )

  if existing&.image&.attached?
    puts '  ⏭️  Image already exists for this inbox - skipping'
    skip_count += 1
    next
  end

  begin
    # Read and encode image
    image_data = File.binread(IMAGE_PATH)
    file_size = (image_data.size / 1024.0).round(2)

    # Create or update AppleListPickerImage record
    picker_image = existing || AppleListPickerImage.new(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      identifier: IMAGE_IDENTIFIER
    )

    picker_image.description = 'Time Picker - Guitar Lesson Scheduling'
    picker_image.original_name = 'time_picker.png'

    # Attach to ActiveStorage using StringIO to avoid file handle issues
    picker_image.image.attach(
      io: StringIO.new(image_data),
      filename: 'time_picker.png',
      content_type: 'image/png'
    )

    picker_image.save!

    puts "  ✅ Successfully uploaded (#{file_size} KB)"
    success_count += 1
  rescue StandardError => e
    puts "  ❌ Error: #{e.message}"
    error_count += 1
  end

  puts
end

puts '=' * 80
puts '📊 Upload Summary:'
puts "  ✅ Uploaded: #{success_count}"
puts "  ⏭️  Skipped (already exists): #{skip_count}"
puts "  ❌ Errors: #{error_count}"
puts
puts "🎉 Done! Image identifier: '#{IMAGE_IDENTIFIER}'"
puts '   This identifier can now be used in send_lesson_time_picker method'
