#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to migrate guitar form images from AppleListPickerImage (inbox-specific)
# to SharedAppleImage (account-wide) so they can be used by templates/bots

puts '=' * 80
puts 'Migrating Guitar Form Images to SharedAppleImage'
puts '=' * 80

# Guitar image identifiers that need to be migrated
GUITAR_IDENTIFIERS = %w[
  guitar_form_gibson
  guitar_form_martin
  guitar_form_prs
  guitar_form_header
].freeze

# Configuration
SOURCE_INBOX_ID = 6
TARGET_ACCOUNT_ID = 1
DRY_RUN = ENV['DRY_RUN'] != 'false' # Default to dry run unless explicitly disabled

puts "\nConfiguration:"
puts "  Source: AppleListPickerImage (inbox_id: #{SOURCE_INBOX_ID})"
puts "  Target: SharedAppleImage (account_id: #{TARGET_ACCOUNT_ID})"
puts "  Mode: #{DRY_RUN ? 'DRY RUN (preview only)' : 'EXECUTE (will make changes)'}"
puts "\n"

# Step 1: Find source images
puts 'Step 1: Finding source images in AppleListPickerImage...'
source_images = AppleListPickerImage.where(
  inbox_id: SOURCE_INBOX_ID,
  identifier: GUITAR_IDENTIFIERS
)

puts "  Found #{source_images.count} images:"
source_images.each do |img|
  puts "    - #{img.identifier} (ID: #{img.id}, has attachment: #{img.image.attached?})"
end

if source_images.count != GUITAR_IDENTIFIERS.count
  missing = GUITAR_IDENTIFIERS - source_images.pluck(:identifier)
  puts "\n  ⚠️  WARNING: Missing #{missing.count} images: #{missing.inspect}"
  puts '  These images may need to be uploaded first.'
end

puts "\n"

# Step 2: Check for existing shared images
puts 'Step 2: Checking for existing SharedAppleImage records...'
existing_shared = SharedAppleImage.where(
  account_id: TARGET_ACCOUNT_ID,
  identifier: GUITAR_IDENTIFIERS
)

if existing_shared.any?
  puts "  Found #{existing_shared.count} existing shared images:"
  existing_shared.each do |img|
    puts "    - #{img.identifier} (ID: #{img.id}, type: #{img.image_type})"
  end
  puts "\n  These will be SKIPPED to avoid duplicates."
else
  puts '  No existing shared images found.'
end

puts "\n"

# Step 3: Migrate images
puts 'Step 3: Migrating images...'
migrated_count = 0
skipped_count = 0
error_count = 0

source_images.each do |source_image|
  identifier = source_image.identifier

  # Skip if already exists in shared
  if existing_shared.any? { |img| img.identifier == identifier }
    puts "  ⏭️  Skipping #{identifier} (already exists in SharedAppleImage)"
    skipped_count += 1
    next
  end

  # Skip if no attachment
  unless source_image.image.attached?
    puts "  ⚠️  Skipping #{identifier} (no attachment)"
    skipped_count += 1
    next
  end

  if DRY_RUN
    puts "  [DRY RUN] Would migrate #{identifier}"
    migrated_count += 1
  else
    begin
      # Create new SharedAppleImage
      shared_image = SharedAppleImage.create!(
        account_id: TARGET_ACCOUNT_ID,
        identifier: identifier,
        image_type: 'template', # Guitar images are template images
        description: source_image.description || "Guitar form image: #{identifier}",
        original_name: source_image.image.filename.to_s,
        metadata: { migrated_from: 'AppleListPickerImage', source_inbox_id: SOURCE_INBOX_ID }
      )

      # Copy the image attachment
      source_image.image.open do |file|
        shared_image.image.attach(
          io: file,
          filename: source_image.image.filename.to_s,
          content_type: source_image.image.content_type
        )
      end

      puts "  ✅ Migrated #{identifier} (new ID: #{shared_image.id})"
      migrated_count += 1
    rescue StandardError => e
      puts "  ❌ Error migrating #{identifier}: #{e.message}"
      error_count += 1
    end
  end
end

puts "\n"

# Step 4: Summary
puts '=' * 80
puts 'Migration Summary'
puts '=' * 80
puts "  Migrated: #{migrated_count}"
puts "  Skipped:  #{skipped_count}"
puts "  Errors:   #{error_count}"
puts "\n"

if DRY_RUN
  puts '🔍 This was a DRY RUN - no changes were made.'
  puts 'To execute the migration, run:'
  puts '  rails runner script/migrate_guitar_images_to_shared.rb DRY_RUN=false'
else
  puts '✅ Migration complete!'

  if migrated_count > 0
    puts "\nVerifying migrated images..."
    SharedAppleImage.where(
      account_id: TARGET_ACCOUNT_ID,
      identifier: GUITAR_IDENTIFIERS
    ).each do |img|
      puts "  ✅ #{img.identifier} - attachment: #{img.image.attached?}, type: #{img.image_type}"
    end
  end
end

puts '=' * 80
