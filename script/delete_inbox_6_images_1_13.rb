#!/usr/bin/env ruby
# frozen_string_literal: true

# Delete inbox-specific images 1-13 from inbox 6
# These were re-created by SendListPickerService before the fix

puts '=' * 80
puts 'Delete Inbox 6 Images 1-13 (Re-created After Cleanup)'
puts '=' * 80
puts ''

TARGET_IDENTIFIERS = %w[1 2 3 4 5 6 7 8 9 10 11 12 13]
TARGET_INBOX = 6

# Check both ARGV and ENV for DRY_RUN parameter
dry_run_from_argv = ARGV.any? { |arg| arg == 'DRY_RUN=false' || arg == '--execute' }
dry_run_from_env = ENV['DRY_RUN'] == 'false'
DRY_RUN = !(dry_run_from_argv || dry_run_from_env)

puts 'Configuration:'
puts "  Target: AppleListPickerImage inbox #{TARGET_INBOX}, identifiers 1-13"
puts "  Mode: #{DRY_RUN ? 'DRY RUN (preview only)' : 'EXECUTE (will DELETE records)'}"
puts ''

# Find images to delete
images_to_delete = AppleListPickerImage
                   .where(inbox_id: TARGET_INBOX, identifier: TARGET_IDENTIFIERS)
                   .includes(image_attachment: :blob)

puts "Found #{images_to_delete.count} images to delete:"
images_to_delete.each do |img|
  puts "  - #{img.identifier} (ID: #{img.id})"
end

if images_to_delete.empty?
  puts ''
  puts '✅ No images to delete - cleanup already complete!'
  puts '=' * 80
  exit 0
end

puts ''
puts 'Deleting images...'
deleted_count = 0
error_count = 0

images_to_delete.each do |img|
  if DRY_RUN
    puts "  [DRY RUN] Would delete: #{img.identifier}"
    deleted_count += 1
  else
    begin
      # Purge attachment first
      img.image.purge if img.image.attached?

      # Delete record
      img.destroy!

      puts "  ✅ Deleted: #{img.identifier}"
      deleted_count += 1
    rescue StandardError => e
      puts "  ❌ Error deleting #{img.identifier}: #{e.message}"
      error_count += 1
    end
  end
end

puts ''
puts '=' * 80
puts 'Summary'
puts '=' * 80
puts "  #{DRY_RUN ? 'Would delete' : 'Deleted'}: #{deleted_count}"
puts "  Errors: #{error_count}"
puts ''

if DRY_RUN
  puts '🔍 This was a DRY RUN - no changes were made.'
  puts 'To execute, run: rails runner script/delete_inbox_6_images_1_13.rb DRY_RUN=false'
else
  puts '✅ Cleanup complete!'
  puts ''
  puts 'Now when sending template 355:'
  puts '  1. SendListPickerService will check SharedAppleImage first'
  puts '  2. Find images 1-13 in SharedAppleImage'
  puts '  3. Skip creating inbox-specific duplicates'
  puts '  4. ImageFetchService will use tier-2 (SharedAppleImage) ✅'
end

puts '=' * 80
