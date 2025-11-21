#!/usr/bin/env ruby
# frozen_string_literal: true

# Check and fix the first 3 summary images that have wrong attachments

puts '=' * 80
puts 'Fix Summary Images 1-3 (Apple Pay, Wallet, AR)'
puts '=' * 80
puts ''

# Check both ARGV and ENV for DRY_RUN parameter
dry_run_from_argv = ARGV.any? { |arg| arg == 'DRY_RUN=false' || arg == '--execute' }
dry_run_from_env = ENV['DRY_RUN'] == 'false'
DRY_RUN = !(dry_run_from_argv || dry_run_from_env)

puts "Mode: #{DRY_RUN ? 'DRY RUN (preview only)' : 'EXECUTE (will re-upload)'}"
puts ''

IMAGE_DIR = '/Users/rhaps/LocalGit/chatwoot/_apple/Acoustic-House-Bot-origin/acoustichouse/images'
TARGET_IDENTIFIERS = %w[summary_apple_pay summary_apple_wallet summary_ar_experience]
TARGET_FILES = {
  'summary_apple_pay' => 'summary_apple_pay.png',
  'summary_apple_wallet' => 'summary_apple_wallet.png',
  'summary_ar_experience' => 'summary_ar_experience.png'
}

puts 'Checking current attachments in SharedAppleImage:'
TARGET_IDENTIFIERS.each do |identifier|
  img = SharedAppleImage.find_by(account_id: 1, identifier: identifier)
  if img&.image&.attached?
    size_kb = (img.image.byte_size / 1024.0).round(2)
    puts "  #{identifier}:"
    puts "    Current size: #{size_kb} KB"
    puts "    Filename: #{img.image.filename}"
  else
    puts "  #{identifier}: NOT FOUND"
  end
end

puts ''
puts 'Expected file sizes:'
TARGET_FILES.each do |identifier, filename|
  file_path = File.join(IMAGE_DIR, filename)
  if File.exist?(file_path)
    size_kb = (File.size(file_path) / 1024.0).round(2)
    puts "  #{identifier}: #{size_kb} KB"
  else
    puts "  #{identifier}: FILE NOT FOUND"
  end
end

puts ''
puts '=' * 80
puts 'Re-uploading Images'
puts '=' * 80
puts ''

updated_count = 0

TARGET_FILES.each do |identifier, filename|
  file_path = File.join(IMAGE_DIR, filename)

  unless File.exist?(file_path)
    puts "  ❌ File not found: #{filename}"
    next
  end

  img = SharedAppleImage.find_by(account_id: 1, identifier: identifier)

  unless img
    puts "  ❌ SharedAppleImage not found: #{identifier}"
    next
  end

  if DRY_RUN
    old_size = img.image.byte_size if img.image.attached?
    new_size = File.size(file_path)
    puts "  [DRY RUN] Would update #{identifier}:"
    puts "    Old: #{(old_size / 1024.0).round(2)} KB"
    puts "    New: #{(new_size / 1024.0).round(2)} KB"
    updated_count += 1
  else
    begin
      # Purge old attachment
      img.image.purge if img.image.attached?

      # Attach new image
      img.image.attach(
        io: File.open(file_path),
        filename: filename,
        content_type: 'image/png'
      )

      # Update metadata
      img.metadata = (img.metadata || {}).merge(
        're_uploaded' => true,
        're_upload_date' => Time.current.iso8601,
        're_upload_reason' => 'wrong_image_attached'
      )

      img.save!

      size_kb = (img.image.byte_size / 1024.0).round(2)
      puts "  ✅ Re-uploaded #{identifier}: #{size_kb} KB"
      updated_count += 1
    rescue StandardError => e
      puts "  ❌ Error: #{e.message}"
    end
  end
end

puts ''
puts '=' * 80
puts 'Summary'
puts '=' * 80
puts "  #{DRY_RUN ? 'Would update' : 'Updated'}: #{updated_count}"
puts ''

if DRY_RUN
  puts '🔍 This was a DRY RUN - no changes were made.'
  puts 'To execute, run: rails runner script/fix_summary_images_1_3.rb DRY_RUN=false'
else
  puts '✅ Fix complete!'
  puts ''
  puts 'Restart dev server and test template 355.'
end

puts '=' * 80
