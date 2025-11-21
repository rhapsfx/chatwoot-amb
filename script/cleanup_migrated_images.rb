#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to remove inbox-specific images that have been migrated to SharedAppleImage
# This prevents the three-tier fallback from finding old inbox images instead of new shared images

puts '=' * 80
puts 'Cleanup: Remove Inbox-Specific Images After Migration'
puts '=' * 80

# Configuration
TARGET_ACCOUNT_ID = 1
DRY_RUN = ENV['DRY_RUN'] != 'false' # Default to dry run unless explicitly disabled

# Check both ARGV and ENV for DRY_RUN parameter
dry_run_from_argv = ARGV.any? { |arg| arg == 'DRY_RUN=false' || arg == '--execute' }
dry_run_from_env = ENV['DRY_RUN'] == 'false'
DRY_RUN = !(dry_run_from_argv || dry_run_from_env)

puts "\nConfiguration:"
puts "  Target: Remove AppleListPickerImage duplicates (account_id: #{TARGET_ACCOUNT_ID})"
puts "  Mode: #{DRY_RUN ? 'DRY RUN (preview only)' : 'EXECUTE (will DELETE records)'}"
puts "\n"

# Step 1: Find all shared images
puts 'Step 1: Loading SharedAppleImage records...'
shared_images = SharedAppleImage.where(account_id: TARGET_ACCOUNT_ID)
shared_identifiers = shared_images.pluck(:identifier)

puts "  Found #{shared_images.count} shared images"
puts "  Identifiers: #{shared_identifiers.sort.join(', ')}"
puts "\n"

# Step 2: Find inbox-specific images with matching identifiers
puts 'Step 2: Finding inbox-specific duplicates...'
inbox_duplicates = AppleListPickerImage
                   .where(identifier: shared_identifiers)
                   .includes(image_attachment: :blob)

# Group by inbox
duplicates_by_inbox = inbox_duplicates.group_by(&:inbox_id)

puts "  Found #{inbox_duplicates.count} inbox-specific images that are duplicates of shared images"
puts "\n"

duplicates_by_inbox.each do |inbox_id, images|
  puts "  Inbox #{inbox_id}: #{images.count} duplicate images"
  images.each do |img|
    puts "    - #{img.identifier} (ID: #{img.id}, has attachment: #{img.image.attached?})"
  end
end

if inbox_duplicates.empty?
  puts "\n  ✅ No duplicates found - cleanup not needed!"
  puts '=' * 80
  exit 0
end

puts "\n"

# Step 3: Remove duplicates
puts 'Step 3: Removing inbox-specific duplicates...'
deleted_count = 0
error_count = 0

inbox_duplicates.each do |duplicate|
  identifier = duplicate.identifier
  inbox_id = duplicate.inbox_id

  if DRY_RUN
    puts "  [DRY RUN] Would delete: #{identifier} (ID: #{duplicate.id}, inbox: #{inbox_id})"
    deleted_count += 1
  else
    begin
      # Purge the image attachment first
      duplicate.image.purge if duplicate.image.attached?

      # Delete the record
      duplicate.destroy!

      puts "  ✅ Deleted: #{identifier} (ID: #{duplicate.id}, inbox: #{inbox_id})"
      deleted_count += 1
    rescue StandardError => e
      puts "  ❌ Error deleting #{identifier}: #{e.message}"
      error_count += 1
    end
  end
end

puts "\n"

# Step 4: Summary
puts '=' * 80
puts 'Cleanup Summary'
puts '=' * 80
puts "  Shared images: #{shared_images.count}"
puts "  #{DRY_RUN ? 'Would delete' : 'Deleted'}: #{deleted_count}"
puts "  Errors: #{error_count}"
puts "\n"

if DRY_RUN
  puts '🔍 This was a DRY RUN - no changes were made.'
  puts 'To execute the cleanup, run either:'
  puts '  rails runner script/cleanup_migrated_images.rb DRY_RUN=false'
  puts '  OR'
  puts '  DRY_RUN=false rails runner script/cleanup_migrated_images.rb'
  puts '  OR'
  puts '  rails runner script/cleanup_migrated_images.rb --execute'
else
  puts '✅ Cleanup complete!'

  if deleted_count > 0
    puts "\n⚠️  IMPORTANT: The three-tier image fallback will now work correctly:"
    puts '  1. Inbox-specific images (AppleListPickerImage) - no longer has duplicates'
    puts '  2. Account-wide shared (SharedAppleImage) - will be used for migrated images ✅'
    puts '  3. Embedded images - fallback if not found'
    puts "\nTemplates will now use SharedAppleImage for identifiers: #{shared_identifiers.sort.join(', ')}"
  end
end

puts '=' * 80
