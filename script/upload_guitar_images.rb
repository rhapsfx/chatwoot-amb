#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to upload all guitar images to AppleListPickerImage table
# Usage: rails runner script/upload_guitar_images.rb

puts '=' * 80
puts '🎸 Uploading Guitar Images to Database'
puts '=' * 80

# Get the inbox (assume first AMB inbox in account 1)
inbox = Inbox.find_by(channel_type: 'Channel::AppleMessagesForBusiness')

unless inbox
  puts '❌ No Apple Messages for Business inbox found'
  exit 1
end

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

puts "\n📋 Will upload #{guitar_images.length} guitar images"

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
  existing = AppleListPickerImage.find_by(inbox_id: inbox.id, identifier: img_config[:identifier])
  if existing
    puts "⏭️  Image already exists (ID: #{existing.id}), skipping"
    skipped_count += 1
    next
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
      inbox_id: inbox.id,
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
verification = AppleListPickerImage.where(inbox_id: inbox.id, identifier: identifiers)
puts "   Found #{verification.count}/#{identifiers.length} guitar images in database"

verification.each do |img|
  status = img.image.attached? ? '✅' : '❌'
  puts "   - #{img.identifier}: #{status}"
end

if verification.count == identifiers.length
  puts "\n🎉 All guitar images successfully uploaded!"
  puts "\n💡 Next step: Test Apple Pay by typing 'Apple Pay' in the conversation"
  puts '   The payment bubble should now display guitar images!'
else
  puts "\n⚠️  Some guitar images are still missing"
end

puts '=' * 80
