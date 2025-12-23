#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to audit Apple Messages image usage and identify migration candidates
# Run: rails runner script/audit_image_usage.rb

puts '=' * 80
puts 'Apple Messages Image Usage Audit'
puts '=' * 80
puts ''

# System image patterns (should be shared across all inboxes)
SYSTEM_IMAGE_PATTERNS = [
  /^messages_png$/,
  /^calendar_/,
  /^time_picker_/
].freeze

# Branding image patterns (company-specific, shared across inboxes)
BRANDING_IMAGE_PATTERNS = [
  /^apple_store_logo$/,
  /^company_logo$/,
  /^brand_/
].freeze

# Categorize an identifier
def categorize_identifier(identifier)
  return :system if SYSTEM_IMAGE_PATTERNS.any? { |pattern| identifier.match?(pattern) }
  return :branding if BRANDING_IMAGE_PATTERNS.any? { |pattern| identifier.match?(pattern) }

  :inbox_specific
end

# Calculate blob size in bytes
def blob_size(image_record)
  return 0 unless image_record&.image&.attached?

  image_record.image.blob.byte_size
rescue StandardError
  0
end

# Format bytes to human-readable
def format_bytes(bytes)
  return '0 B' if bytes.zero?

  units = %w[B KB MB GB]
  exponent = (Math.log(bytes) / Math.log(1024)).floor
  value = bytes / (1024.0**exponent)

  format('%.2f %s', value, units[exponent])
end

begin
  # Basic counts
  total_images = AppleListPickerImage.count
  shared_images = SharedAppleImage.count
  total_accounts = AppleListPickerImage.distinct.count(:account_id)
  total_inboxes = AppleListPickerImage.distinct.count(:inbox_id)

  puts 'Overview:'
  puts "  Total AppleListPickerImage records: #{total_images}"
  puts "  Total SharedAppleImage records: #{shared_images}"
  puts "  Total accounts with images: #{total_accounts}"
  puts "  Total inboxes with images: #{total_inboxes}"
  puts ''

  # Analyze by identifier
  puts 'Analyzing image identifiers...'
  puts ''

  # Group by identifier and count inboxes
  identifier_stats = AppleListPickerImage
                     .select('identifier, COUNT(DISTINCT inbox_id) as inbox_count, COUNT(*) as record_count')
                     .group(:identifier)
                     .order('inbox_count DESC, identifier')
                     .map do |stat|
    {
      identifier: stat.identifier,
      inbox_count: stat.inbox_count,
      record_count: stat.record_count,
      category: categorize_identifier(stat.identifier)
    }
  end

  # Categorize results
  system_candidates = identifier_stats.select { |s| s[:category] == :system }
  branding_candidates = identifier_stats.select { |s| s[:category] == :branding }
  inbox_specific = identifier_stats.select { |s| s[:category] == :inbox_specific }

  # Images that appear in multiple inboxes (duplication candidates)
  duplicates = identifier_stats.select { |s| s[:inbox_count] > 1 }

  # System Images
  puts '🔧 System Images (candidates for SharedAppleImage - type: system):'
  puts '-' * 80
  if system_candidates.any?
    system_candidates.each do |stat|
      status = stat[:inbox_count] > 1 ? '⚠️  DUPLICATE' : '✅ UNIQUE'
      puts format('  %-40s | Inboxes: %2d | Records: %2d | %s',
                  stat[:identifier],
                  stat[:inbox_count],
                  stat[:record_count],
                  status)
    end
    puts "  Total system images: #{system_candidates.size}"
  else
    puts '  No system images found.'
  end
  puts ''

  # Branding Images
  puts '🎨 Branding Images (candidates for SharedAppleImage - type: branding):'
  puts '-' * 80
  if branding_candidates.any?
    branding_candidates.each do |stat|
      status = stat[:inbox_count] > 1 ? '⚠️  DUPLICATE' : '✅ UNIQUE'
      puts format('  %-40s | Inboxes: %2d | Records: %2d | %s',
                  stat[:identifier],
                  stat[:inbox_count],
                  stat[:record_count],
                  status)
    end
    puts "  Total branding images: #{branding_candidates.size}"
  else
    puts '  No branding images found.'
  end
  puts ''

  # Inbox-Specific Images
  puts '📥 Inbox-Specific Images (remain in AppleListPickerImage):'
  puts '-' * 80
  if inbox_specific.any?
    # Show only duplicates for inbox-specific (potential issues)
    inbox_duplicates = inbox_specific.select { |s| s[:inbox_count] > 1 }

    if inbox_duplicates.any?
      puts '  ⚠️  Inbox-specific images appearing in multiple inboxes:'
      inbox_duplicates.each do |stat|
        puts format('    %-38s | Inboxes: %2d | Records: %2d',
                    stat[:identifier],
                    stat[:inbox_count],
                    stat[:record_count])
      end
      puts ''
    end

    unique_inbox_specific = inbox_specific.select { |s| s[:inbox_count] == 1 }
    puts "  ✅ Unique inbox-specific images: #{unique_inbox_specific.size}"
    puts "  ⚠️  Duplicated inbox-specific images: #{inbox_duplicates.size}"
    puts "  Total inbox-specific images: #{inbox_specific.size}"
  else
    puts '  No inbox-specific images found.'
  end
  puts ''

  # Duplicate Analysis
  puts '🔍 Duplication Analysis:'
  puts '-' * 80
  puts "  Total unique identifiers: #{identifier_stats.size}"
  puts "  Identifiers in multiple inboxes: #{duplicates.size}"
  puts "  Identifiers in single inbox: #{identifier_stats.size - duplicates.size}"
  puts ''

  if duplicates.any?
    puts '  Top duplicates (by inbox count):'
    duplicates.first(10).each do |stat|
      category_label = stat[:category].to_s.upcase.ljust(15)
      puts format('    %-40s | %s | Inboxes: %2d',
                  stat[:identifier],
                  category_label,
                  stat[:inbox_count])
    end
  end
  puts ''

  # Storage Analysis
  puts '💾 Storage Analysis:'
  puts '-' * 80

  # Calculate actual storage used
  total_storage = 0
  duplicate_storage = 0
  attachment_count = 0

  AppleListPickerImage.includes(image_attachment: :blob).find_each do |image|
    size = blob_size(image)
    next if size.zero?

    attachment_count += 1
    total_storage += size

    # Check if this identifier is duplicated
    stat = identifier_stats.find { |s| s[:identifier] == image.identifier }
    duplicate_storage += size if stat && stat[:inbox_count] > 1
  end

  puts "  Total images with attachments: #{attachment_count}"
  puts "  Total storage used: #{format_bytes(total_storage)}"
  puts "  Storage in duplicated images: #{format_bytes(duplicate_storage)}"

  if duplicate_storage.positive? && total_storage.positive?
    savings_percent = (duplicate_storage.to_f / total_storage * 100).round(1)
    puts "  Potential savings: #{format_bytes(duplicate_storage)} (#{savings_percent}%)"
  end
  puts ''

  # Unused Images
  puts '🗑️  Unused Image Analysis:'
  puts '-' * 80

  # Images without attachments
  images_without_attachments = AppleListPickerImage.left_joins(:image_attachment)
                                                   .where(active_storage_attachments: { id: nil })
                                                   .count

  puts "  Images without attachments: #{images_without_attachments}"

  puts '  ⚠️  These records should be cleaned up.' if images_without_attachments.positive?
  puts ''

  # Migration Recommendations
  puts '📋 Migration Recommendations:'
  puts '=' * 80

  migration_candidates = system_candidates + branding_candidates

  if migration_candidates.any?
    puts ''
    puts 'The following images should be migrated to SharedAppleImage:'
    puts ''

    # System images
    if system_candidates.any?
      puts '  System Images (image_type: "system"):'
      system_candidates.each do |stat|
        puts "    - #{stat[:identifier]} (appears in #{stat[:inbox_count]} inbox(es))"
      end
      puts ''
    end

    # Branding images
    if branding_candidates.any?
      puts '  Branding Images (image_type: "branding"):'
      branding_candidates.each do |stat|
        puts "    - #{stat[:identifier]} (appears in #{stat[:inbox_count]} inbox(es))"
      end
      puts ''
    end

    puts "Total migration candidates: #{migration_candidates.size}"
    puts ''
    puts 'Next Steps:'
    puts '  1. Review the migration candidates above'
    puts '  2. Run: rails runner script/migrate_system_images_to_shared.rb'
    puts '  3. Verify migration with: rails runner script/verify_shared_images.rb'
  else
    puts '  No migration candidates found.'
    puts '  All images appear to be inbox-specific or already migrated.'
  end

  puts ''
  puts '=' * 80
  puts 'Audit Complete'
  puts '=' * 80

rescue StandardError => e
  puts ''
  puts '❌ Error during audit:'
  puts "   #{e.class}: #{e.message}"
  puts ''
  puts 'Backtrace:'
  puts e.backtrace.first(10).map { |line| "   #{line}" }.join("\n")
  exit 1
end
