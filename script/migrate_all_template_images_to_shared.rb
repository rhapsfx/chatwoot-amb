#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive script to migrate ALL template images from AppleListPickerImage (inbox-specific)
# to SharedAppleImage (account-wide) to enable full retirement of inbox-specific image system

puts '=' * 80
puts 'Comprehensive Template Images Migration to SharedAppleImage'
puts '=' * 80

# Configuration
TARGET_ACCOUNT_ID = 1

# Check both ARGV and ENV for DRY_RUN parameter
# Usage: rails runner script/migrate_all_template_images_to_shared.rb DRY_RUN=false
#    OR: DRY_RUN=false rails runner script/migrate_all_template_images_to_shared.rb
dry_run_from_argv = ARGV.any? { |arg| arg == 'DRY_RUN=false' || arg == '--execute' }
dry_run_from_env = ENV['DRY_RUN'] == 'false'
DRY_RUN = !(dry_run_from_argv || dry_run_from_env) # Default to dry run unless explicitly disabled

puts "\nConfiguration:"
puts "  Target: SharedAppleImage (account_id: #{TARGET_ACCOUNT_ID})"
puts "  Mode: #{DRY_RUN ? 'DRY RUN (preview only)' : 'EXECUTE (will make changes)'}"
puts "\n"

# Define image categories with their identifiers and types
IMAGE_CATEGORIES = {
  system: {
    description: 'Apple System & App Icons',
    image_type: 'system',
    identifiers: %w[
      list_bullet_512_12 apple_pay_mark_3 apple_pay_mark_15 calendar_1024x1024_2x_2
      photos_512x512_2x_14 preview_512x512_2x_9 faceid_3x_13 appstore_1024_6
      wallet_1024_4 maps_512x512_2x_1 keyboard_1024_8 safari_1024x1024_2x_7
      safari_1024x1024_2x_10 codescanner_1024_11 arkit_512_5 form_16
      messages_1024_15 message_circle_18 form_circle_17 shopping_circle_22
      calendar_circle_19 image_circle_25 doc_circle_24 auth_circle_23
      app_circle_27 wallet_circle_20 map_circle_21 calendar_1
    ]
  },
  navigation: {
    description: 'AHA19 Menu & Navigation Icons',
    image_type: 'template',
    identifiers: %w[
      aha19_0 aha19_1 aha19_2 aha19_3 aha19_4 aha19_5 aha19_6 aha19_7
      aha19_8 aha19_10 aha19_11 aha19_12 aha19_13
    ]
  },
  generic: {
    description: 'Generic Numbered Template Images',
    image_type: 'template',
    identifiers: %w[0 1 2 3 4 5 6 7 8 9 10 11 12 13]
  },
  products: {
    description: 'iPhone Product Catalog Images',
    image_type: 'branding',
    identifiers: %w[
      iphone_16__drr03yfz644m_large_2x_3 iphone_16__drr03yfz644m_large_2x_4
      iphone_16e__dar81seif0cy_large_2x_3 iphone_17__ck7zzemcw37m_large_2x_1
      iphone_17__ck7zzemcw37m_large_2x_2 iphone_17pro__0s6piftg70ym_large_2x_1
      iphone_17pro__0s6piftg70ym_large_2x_4 iphone_air__f0t56fef3oey_large_2x_2
    ]
  },
  guitars: {
    description: 'Guitar Product Images',
    image_type: 'branding',
    identifiers: %w[
      guitar_lespaul guitar_stratocaster guitar_gibson_es335
      guitar_martin_dreadnought guitar_prs_custom24 guitar_taylor
    ]
  }
}.freeze

# Collect all unique identifiers
ALL_IDENTIFIERS = IMAGE_CATEGORIES.values.flat_map { |cat| cat[:identifiers] }.uniq

puts 'Image Categories:'
IMAGE_CATEGORIES.each do |key, cat|
  puts "  #{key.to_s.capitalize.ljust(15)} #{cat[:identifiers].count.to_s.rjust(3)} images - #{cat[:description]}"
end
puts "  #{'Total'.ljust(15)} #{ALL_IDENTIFIERS.count.to_s.rjust(3)} unique images"
puts "\n"

# Step 1: Find source images across ALL inboxes
puts 'Step 1: Finding source images in AppleListPickerImage...'
source_images = AppleListPickerImage
                .where(identifier: ALL_IDENTIFIERS)
                .includes(image_attachment: :blob)

# Group by identifier to handle duplicates across inboxes
images_by_identifier = source_images.group_by(&:identifier)

puts "  Found #{images_by_identifier.keys.count} unique images across #{source_images.pluck(:inbox_id).uniq.count} inboxes:"
images_by_identifier.each do |identifier, images|
  inbox_ids = images.map(&:inbox_id).compact.uniq
  has_attachment = images.any? { |img| img.image.attached? }
  puts "    - #{identifier} (#{inbox_ids.count} inbox(es): #{inbox_ids.join(', ')}, has attachment: #{has_attachment})"
end

missing = ALL_IDENTIFIERS - images_by_identifier.keys
if missing.any?
  puts "\n  ⚠️  WARNING: Missing #{missing.count} images that are not in any inbox:"
  missing.each { |id| puts "    - #{id}" }
end

puts "\n"

# Step 2: Check for existing shared images
puts 'Step 2: Checking for existing SharedAppleImage records...'
existing_shared = SharedAppleImage.where(
  account_id: TARGET_ACCOUNT_ID,
  identifier: ALL_IDENTIFIERS
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

# Step 3: Migrate images by category
puts 'Step 3: Migrating images by category...'
migrated_count = 0
skipped_count = 0
error_count = 0

IMAGE_CATEGORIES.each do |category_key, category|
  puts "\n  Category: #{category[:description]} (#{category[:identifiers].count} images)"
  puts '  ' + ('-' * 76)

  category[:identifiers].each do |identifier|
    # Skip if already exists in shared
    if existing_shared.any? { |img| img.identifier == identifier }
      puts "    ⏭️  #{identifier} (already in SharedAppleImage)"
      skipped_count += 1
      next
    end

    # Find source image (prefer first inbox that has it with attachment)
    source_candidates = images_by_identifier[identifier] || []
    source_image = source_candidates.find { |img| img.image.attached? }

    unless source_image
      puts "    ⚠️  #{identifier} (no attachment available)"
      skipped_count += 1
      next
    end

    if DRY_RUN
      puts "    [DRY RUN] Would migrate #{identifier} from inbox #{source_image.inbox_id}"
      migrated_count += 1
    else
      begin
        # Create new SharedAppleImage
        shared_image = SharedAppleImage.create!(
          account_id: TARGET_ACCOUNT_ID,
          identifier: identifier,
          image_type: category[:image_type],
          description: source_image.description || "#{category[:description]}: #{identifier}",
          original_name: source_image.image.filename.to_s,
          metadata: {
            migrated_from: 'AppleListPickerImage',
            source_inbox_id: source_image.inbox_id,
            migration_date: Time.current.iso8601,
            migration_script: 'migrate_all_template_images_to_shared.rb',
            category: category_key.to_s
          }
        )

        # Copy the image attachment
        source_image.image.open do |file|
          shared_image.image.attach(
            io: file,
            filename: source_image.image.filename.to_s,
            content_type: source_image.image.content_type
          )
        end

        puts "    ✅ #{identifier} (from inbox #{source_image.inbox_id})"
        migrated_count += 1
      rescue StandardError => e
        puts "    ❌ #{identifier}: #{e.message}"
        error_count += 1
      end
    end
  end
end

puts "\n"

# Step 4: Summary by category
puts '=' * 80
puts 'Migration Summary by Category'
puts '=' * 80

IMAGE_CATEGORIES.each do |_category_key, category|
  category_ids = category[:identifiers]
  migrated = category_ids.count { |id| images_by_identifier[id] && !existing_shared.any? { |img| img.identifier == id } }
  already_shared = category_ids.count { |id| existing_shared.any? { |img| img.identifier == id } }
  missing = category_ids.count { |id| images_by_identifier[id].nil? }

  puts "\n#{category[:description]}:"
  puts "  Type: #{category[:image_type]}"
  puts "  Total: #{category_ids.count}"
  puts "  #{DRY_RUN ? 'Would migrate' : 'Migrated'}: #{migrated}"
  puts "  Already shared: #{already_shared}"
  puts "  Missing from inbox: #{missing}"
end

puts "\n" + ('=' * 80)
puts 'Overall Summary'
puts '=' * 80
puts "  #{DRY_RUN ? 'Would migrate' : 'Migrated'}: #{migrated_count}"
puts "  Skipped:  #{skipped_count}"
puts "  Errors:   #{error_count}"
puts "\n"

if DRY_RUN
  puts '🔍 This was a DRY RUN - no changes were made.'
  puts 'To execute the migration, run either:'
  puts '  rails runner script/migrate_all_template_images_to_shared.rb DRY_RUN=false'
  puts '  OR'
  puts '  DRY_RUN=false rails runner script/migrate_all_template_images_to_shared.rb'
  puts '  OR'
  puts '  rails runner script/migrate_all_template_images_to_shared.rb --execute'
else
  puts '✅ Migration complete!'

  if migrated_count > 0
    puts "\nVerifying migrated images by category..."
    IMAGE_CATEGORIES.each do |_category_key, category|
      category_images = SharedAppleImage.where(
        account_id: TARGET_ACCOUNT_ID,
        identifier: category[:identifiers]
      )

      next unless category_images.any?

      puts "\n#{category[:description]} (#{category_images.count} images):"
      category_images.each do |img|
        puts "  ✅ #{img.identifier} - attachment: #{img.image.attached?}, type: #{img.image_type}"
      end
    end

    puts "\n" + ('=' * 80)
    puts 'Next Steps:'
    puts '=' * 80
    puts '1. Test templates using the render API to verify images load correctly'
    puts '2. Monitor bot sends to ensure SharedAppleImage fallback works'
    puts '3. After successful verification, consider deprecating AppleListPickerImage for new uploads'
    puts '4. Update documentation to recommend SharedAppleImage for all new images'
  end
end

puts '=' * 80
