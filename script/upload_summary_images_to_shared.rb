#!/usr/bin/env ruby
# frozen_string_literal: true

# Upload summary images from local directory to SharedAppleImage

puts '=' * 80
puts 'Upload Summary Images to SharedAppleImage'
puts '=' * 80
puts ''

# Check both ARGV and ENV for DRY_RUN parameter
dry_run_from_argv = ARGV.any? { |arg| arg == 'DRY_RUN=false' || arg == '--execute' }
dry_run_from_env = ENV['DRY_RUN'] == 'false'
DRY_RUN = !(dry_run_from_argv || dry_run_from_env)

puts "Mode: #{DRY_RUN ? 'DRY RUN (preview only)' : 'EXECUTE (will upload images)'}"
puts ''

IMAGE_DIR = '/Users/rhaps/LocalGit/chatwoot/_apple/Acoustic-House-Bot-origin/acoustichouse/images'
TARGET_ACCOUNT_ID = 1

# Mapping of template items to image filenames and identifiers
IMAGE_MAPPING = [
  { title: 'Apple Pay', file: 'summary_apple_pay.png', identifier: 'summary_apple_pay' },
  { title: 'Apple Wallet', file: 'summary_apple_wallet.png', identifier: 'summary_apple_wallet' },
  { title: 'AR Experience', file: 'summary_ar_experience.png', identifier: 'summary_ar_experience' },
  { title: 'Authentication', file: 'summary_authentication.png', identifier: 'summary_authentication' },
  { title: 'File Sharing', file: 'summary_file_sharing.png', identifier: 'summary_file_sharing' },
  { title: 'iMessage Apps', file: 'summary_imessage_apps.png', identifier: 'summary_imessage_apps' },
  { title: 'List Picker', file: 'summary_list_picker.png', identifier: 'summary_list_picker' },
  { title: 'Media Sharing', file: 'summary_media_sharing.png', identifier: 'summary_media_sharing' },
  { title: 'QR Code', file: 'summary_qr_code_origination.png', identifier: 'summary_qr_code_origination' },
  { title: 'Quick Type', file: 'summary_quick_type_keyboard.png', identifier: 'summary_quick_type_keyboard' },
  { title: 'Rich Link Locator', file: 'summary_rich_link_locator.png', identifier: 'summary_rich_link_locator' },
  { title: 'Rich Links', file: 'summary_rich_website_links.png', identifier: 'summary_rich_website_links' },
  { title: 'Time Picker', file: 'summary_time_picker.png', identifier: 'summary_time_picker' }
].freeze

puts 'Images to upload:'
IMAGE_MAPPING.each_with_index do |mapping, idx|
  file_path = File.join(IMAGE_DIR, mapping[:file])
  exists = File.exist?(file_path)
  size = exists ? (File.size(file_path) / 1024.0).round(2) : 0
  status = exists ? '✅' : '❌'
  puts "  #{(idx + 1).to_s.rjust(2)}. #{mapping[:title].ljust(25)} #{status} #{size.to_s.rjust(8)} KB - #{mapping[:identifier]}"
end

puts ''
puts '=' * 80
puts 'Uploading to SharedAppleImage'
puts '=' * 80
puts ''

uploaded_count = 0
skipped_count = 0
error_count = 0

IMAGE_MAPPING.each do |mapping|
  file_path = File.join(IMAGE_DIR, mapping[:file])

  unless File.exist?(file_path)
    puts "  ❌ File not found: #{mapping[:file]}"
    error_count += 1
    next
  end

  # Check if already exists
  existing = SharedAppleImage.find_by(account_id: TARGET_ACCOUNT_ID, identifier: mapping[:identifier])

  if existing&.image&.attached?
    puts "  ⏭️  #{mapping[:identifier]} (already exists)"
    skipped_count += 1
    next
  end

  if DRY_RUN
    size = (File.size(file_path) / 1024.0).round(2)
    puts "  [DRY RUN] Would upload: #{mapping[:identifier]} (#{size} KB)"
    uploaded_count += 1
  else
    begin
      # Create or update SharedAppleImage
      shared_image = existing || SharedAppleImage.new(
        account_id: TARGET_ACCOUNT_ID,
        identifier: mapping[:identifier],
        image_type: 'template'
      )

      shared_image.description = "Summary icon: #{mapping[:title]}"
      shared_image.original_name = mapping[:file]
      shared_image.metadata = {
        uploaded_from: 'local_directory',
        source_path: file_path,
        upload_date: Time.current.iso8601,
        upload_script: 'upload_summary_images_to_shared.rb'
      }

      # Attach the image file
      shared_image.image.attach(
        io: File.open(file_path),
        filename: mapping[:file],
        content_type: 'image/png'
      )

      shared_image.save!

      size = (shared_image.image.byte_size / 1024.0).round(2)
      puts "  ✅ Uploaded: #{mapping[:identifier]} (#{size} KB)"
      uploaded_count += 1
    rescue StandardError => e
      puts "  ❌ Error uploading #{mapping[:identifier]}: #{e.message}"
      error_count += 1
    end
  end
end

puts ''
puts '=' * 80
puts 'Summary'
puts '=' * 80
puts "  #{DRY_RUN ? 'Would upload' : 'Uploaded'}: #{uploaded_count}"
puts "  Skipped (already exist): #{skipped_count}"
puts "  Errors: #{error_count}"
puts ''

if DRY_RUN
  puts '🔍 This was a DRY RUN - no changes were made.'
  puts 'To execute, run: rails runner script/upload_summary_images_to_shared.rb DRY_RUN=false'
else
  puts '✅ Upload complete!'
  puts ''
  puts 'Next step: Update template 355 to use these identifiers'
  puts 'Run: rails runner script/update_template_355_with_summary_icons.rb'
end

puts '=' * 80
