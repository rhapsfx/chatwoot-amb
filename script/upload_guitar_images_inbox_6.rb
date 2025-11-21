#!/usr/bin/env ruby
# frozen_string_literal: true

# DEPRECATED: This script is deprecated as of November 2025
# Use SharedAppleImage model for account-wide images instead
#
# New approach:
#   SharedAppleImage.create!(
#     account_id: 1,
#     identifier: 'guitar_stratocaster',
#     image_type: 'template',
#     description: 'Fender American Elite Stratocaster',
#     image: File.open('_apple/Acoustic-House-Bot-origin/acoustichouse/images/Strat.jpg')
#   )
#
# Or use the migration scripts:
#   rails runner script/migrate_branding_images_to_shared.rb --execute
#
# This script remains for backwards compatibility only.
# Will be removed in: Q2 2026
#
# See: docs/apple-messages/DEPRECATION_TIMELINE.md

# Script to upload all guitar images to inbox 6 specifically
# Usage: rails runner script/upload_guitar_images_inbox_6.rb

puts '=' * 80
puts '🎸 Uploading Guitar Images to Inbox 6'
puts '=' * 80

# Use inbox 6 explicitly (Eloiza T1)
inbox_id = 6
inbox = Inbox.find(inbox_id)

puts "\n✅ Using inbox: #{inbox.name} (ID: #{inbox.id})"
account_id = inbox.account_id

# Define guitar images with their identifiers and file paths
guitar_images = [
  {
    identifier: 'guitar_stratocaster',
    file_path: '_apple/Acoustic-House-Bot-origin/acoustichouse/images/Strat.jpg',
    original_name: 'Fender American Elite Stratocaster',
    description: 'Fender American Elite Stratocaster'
  },
  {
    identifier: 'guitar_lespaul',
    file_path: '_apple/Acoustic-House-Bot-origin/acoustichouse/images/GibsonLesPaul.png',
    original_name: 'Gibson Les Paul Standard',
    description: 'Gibson Les Paul Standard'
  },
  {
    identifier: 'guitar_gibson_es335',
    file_path: '_apple/Acoustic-House-Bot-origin/acoustichouse/images/Es135.jpg',
    original_name: 'Gibson ES-335',
    description: 'Gibson ES-335'
  },
  {
    identifier: 'guitar_martin_dreadnought',
    file_path: '_apple/Acoustic-House-Bot-origin/acoustichouse/images/MartinDC28EDreadnought.png',
    original_name: 'Martin DC28E Dreadnought',
    description: 'Martin DC28E Dreadnought'
  },
  {
    identifier: 'guitar_prs_custom24',
    file_path: '_apple/Acoustic-House-Bot-origin/acoustichouse/images/PRS.png',
    original_name: 'PRS Custom 24',
    description: 'PRS Custom 24'
  },
  {
    identifier: 'guitar_taylor',
    file_path: '_apple/Acoustic-House-Bot-origin/acoustichouse/images/Yamaha.jpg',
    original_name: 'Taylor 814ce',
    description: 'Taylor 814ce'
  }
]

puts "\n📋 Will upload #{guitar_images.length} guitar images to inbox #{inbox_id}"

uploaded_count = 0
skipped_count = 0
error_count = 0

guitar_images.each do |img_config|
  puts "\n" + ('=' * 60)
  puts "Processing: #{img_config[:identifier]}"
  puts '=' * 60

  file_path = Rails.root.join(img_config[:file_path])

  unless File.exist?(file_path)
    puts "⚠️  File not found: #{file_path}"
    error_count += 1
    next
  end

  # Check if image already exists
  existing = AppleListPickerImage.find_by(inbox_id: inbox_id, identifier: img_config[:identifier])
  if existing
    puts "⚠️  Image already exists (ID: #{existing.id})"
    puts '   Deleting old image and re-uploading...'
    existing.destroy!
  end

  begin
    # Read image file
    puts "📥 Reading file: #{File.basename(file_path)}"
    image_data = File.binread(file_path)
    puts "   Size: #{(image_data.bytesize / 1024.0).round(2)} KB"

    # Determine content type from file extension
    content_type = case File.extname(file_path).downcase
                   when '.jpg', '.jpeg'
                     'image/jpeg'
                   when '.png'
                     'image/png'
                   else
                     'image/jpeg'
                   end

    # Create AppleListPickerImage record
    puts '📤 Creating database record...'
    picker_image = AppleListPickerImage.new(
      account_id: account_id,
      inbox_id: inbox_id,
      identifier: img_config[:identifier],
      original_name: img_config[:original_name],
      description: img_config[:description]
    )

    # Attach image
    picker_image.image.attach(
      io: StringIO.new(image_data),
      filename: File.basename(file_path),
      content_type: content_type
    )

    picker_image.save!

    puts "✅ Successfully uploaded: #{img_config[:identifier]}"
    puts "   Image ID: #{picker_image.id}"
    puts "   Attached: #{picker_image.image.attached? ? '✅' : '❌'}"
    uploaded_count += 1
  rescue StandardError => e
    puts "❌ Error uploading #{img_config[:identifier]}: #{e.message}"
    puts e.backtrace.first(3)
    error_count += 1
  end
end

puts "\n" + ('=' * 80)
puts '📊 UPLOAD SUMMARY'
puts '=' * 80
puts "✅ Uploaded: #{uploaded_count}"
puts "⏭️  Skipped: #{skipped_count}"
puts "❌ Errors: #{error_count}"

# Verify all images
puts "\n🔍 Verification:"
identifiers = guitar_images.map { |img| img[:identifier] }
verification = AppleListPickerImage.where(inbox_id: inbox_id, identifier: identifiers)
puts "   Found #{verification.count}/#{identifiers.length} guitar images in inbox #{inbox_id}"

verification.each do |img|
  status = img.image.attached? ? '✅' : '❌'
  puts "   - #{img.identifier}: #{status}"
end

# Show all images in inbox 6
puts "\n📋 All images currently in inbox #{inbox_id}:"
all_images = AppleListPickerImage.where(inbox_id: inbox_id).order(:identifier)
puts "   Total: #{all_images.count}"
guitar_related = all_images.select { |img| img.identifier.start_with?('guitar_') }
puts "   Guitar images: #{guitar_related.count}"
guitar_related.each do |img|
  puts "      - #{img.identifier}"
end

if verification.count == identifiers.length
  puts "\n🎉 All guitar images successfully uploaded to inbox #{inbox_id}!"
  puts "\n💡 Next step:"
  puts '   1. Restart Rails server'
  puts "   2. Type 'Apple Pay' in the conversation"
  puts '   3. Guitar images should now appear in payment bubbles!'
else
  puts "\n⚠️  Some guitar images are still missing"
end

puts '=' * 80
