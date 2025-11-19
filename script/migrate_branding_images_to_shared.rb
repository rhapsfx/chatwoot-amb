#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to migrate branding images to SharedAppleImage table
# Part of Image Architecture Long-Term Plan - Phase 3
#
# Usage:
#   rails runner script/migrate_branding_images_to_shared.rb                      # Dry run for all accounts
#   rails runner script/migrate_branding_images_to_shared.rb --execute --account=1  # Execute for account 1
#   rails runner script/migrate_branding_images_to_shared.rb --execute --all-accounts  # Execute for all accounts

require 'optparse'

# Configuration: Define which identifiers are branding images
BRANDING_IMAGES = {
  'apple_store_logo' => {
    description: 'Apple Store logo for store selection list picker'
  },
  'time_picker_lesson' => {
    description: 'Time Picker image for lesson scheduling'
  },
  'company_logo' => {
    description: 'Company branding logo'
  },
  'store_icon' => {
    description: 'Store location icon'
  }
  # Add more branding images as discovered during audit
}.freeze

# Parse command-line arguments
options = {
  dry_run: true,
  account_id: nil,
  all_accounts: false
}

OptionParser.new do |opts|
  opts.banner = 'Usage: rails runner script/migrate_branding_images_to_shared.rb [options]'

  opts.on('--execute', 'Execute migration (default: dry run)') do
    options[:dry_run] = false
  end

  opts.on('--account=ID', Integer, 'Migrate for specific account ID') do |id|
    options[:account_id] = id
  end

  opts.on('--all-accounts', 'Migrate for all accounts') do
    options[:all_accounts] = true
  end

  opts.on('-h', '--help', 'Display this help') do
    puts opts
    exit
  end
end.parse!

# Validate options
if !options[:dry_run] && !options[:account_id] && !options[:all_accounts]
  puts '❌ Error: When using --execute, you must specify either --account=ID or --all-accounts'
  puts ''
  puts 'Examples:'
  puts '  rails runner script/migrate_branding_images_to_shared.rb                      # Dry run'
  puts '  rails runner script/migrate_branding_images_to_shared.rb --execute --account=1  # Execute for account 1'
  puts '  rails runner script/migrate_branding_images_to_shared.rb --execute --all-accounts  # Execute all'
  exit 1
end

# Determine which accounts to process
if options[:account_id]
  account_ids = [options[:account_id]]
elsif options[:all_accounts]
  account_ids = Account.pluck(:id)
else
  # Dry run: show all accounts with Apple Messages inboxes
  account_ids = Account
                .joins(inboxes: :channel)
                .where(inboxes: { channel_type: 'Channel::AppleMessagesForBusiness' })
                .distinct
                .pluck(:id)
end

# Header
puts '=' * 80
puts 'Branding Images Migration to SharedAppleImage'
puts '=' * 80
puts ''
puts "Mode: #{options[:dry_run] ? 'DRY RUN (no changes will be made)' : 'EXECUTE'}"
puts "Accounts: #{account_ids.join(', ')}"
puts "Branding images to migrate: #{BRANDING_IMAGES.keys.join(', ')}"
puts ''

# Confirmation for execute mode
if !options[:dry_run]
  puts '⚠️  WARNING: This will create SharedAppleImage records for branding images.'
  puts '   Original AppleListPickerImage records will be kept.'
  puts ''
  print 'Are you sure you want to proceed? [y/N]: '
  response = $stdin.gets.chomp.downcase
  unless response == 'y' || response == 'yes'
    puts 'Migration cancelled.'
    exit 0
  end
  puts ''
end

# Statistics
stats = {
  total_accounts: account_ids.count,
  migrated: 0,
  skipped: 0,
  not_found: 0,
  errors: 0
}

# Process each account
account_ids.each do |account_id|
  puts '=' * 80
  puts "Account #{account_id}"
  puts '=' * 80
  puts ''

  account = Account.find_by(id: account_id)
  unless account
    puts "  ❌ Account #{account_id} not found - skipping"
    puts ''
    next
  end

  # Get all inboxes for this account
  inboxes = account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness')

  if inboxes.empty?
    puts '  ⏭️  No Apple Messages inboxes found - skipping'
    puts ''
    next
  end

  puts "  Found #{inboxes.count} Apple Messages inbox(es)"
  puts ''

  # Process each branding image identifier
  BRANDING_IMAGES.each do |identifier, config|
    puts "  Processing '#{identifier}'..."

    # Check if already migrated to SharedAppleImage
    existing_shared = SharedAppleImage.find_by(
      account_id: account_id,
      identifier: identifier
    )

    if existing_shared&.image&.attached?
      puts "    ✅ Already exists in SharedAppleImage - skipping"
      stats[:skipped] += 1
      next
    end

    # Find source image across all inboxes for this account
    # Prefer most recent image with attachment
    source_image = AppleListPickerImage
                   .where(account_id: account_id, identifier: identifier)
                   .where.not(inbox_id: nil)
                   .includes(image_attachment: :blob)
                   .order(created_at: :desc)
                   .find { |img| img.image.attached? }

    unless source_image
      puts "    ⏭️  Not found in any inbox - skipping"
      stats[:not_found] += 1
      next
    end

    puts "    📸 Found source in inbox #{source_image.inbox_id}"
    puts "       Created: #{source_image.created_at.strftime('%Y-%m-%d %H:%M')}"
    puts "       Size: #{source_image.image.blob.byte_size} bytes"
    puts "       Original name: #{source_image.original_name}"

    if options[:dry_run]
      puts '    🔍 [DRY RUN] Would create SharedAppleImage with:'
      puts "       - account_id: #{account_id}"
      puts "       - identifier: #{identifier}"
      puts "       - image_type: branding"
      puts "       - description: #{config[:description]}"
      puts "       - original_name: #{source_image.original_name}"
      stats[:migrated] += 1
    else
      begin
        # Download image data
        image_data = source_image.image.download
        blob = source_image.image.blob

        # Create SharedAppleImage
        shared_image = existing_shared || SharedAppleImage.new(
          account_id: account_id,
          identifier: identifier,
          image_type: 'branding'
        )

        shared_image.description = config[:description]
        shared_image.original_name = source_image.original_name

        # Attach image using StringIO
        shared_image.image.attach(
          io: StringIO.new(image_data),
          filename: blob.filename.to_s,
          content_type: blob.content_type
        )

        shared_image.save!

        puts "    ✅ Successfully migrated to SharedAppleImage (ID: #{shared_image.id})"
        stats[:migrated] += 1
      rescue StandardError => e
        puts "    ❌ Error: #{e.message}"
        puts "       #{e.backtrace.first}"
        stats[:errors] += 1
      end
    end

    puts ''
  end

  puts ''
end

# Summary
puts '=' * 80
puts 'Migration Summary'
puts '=' * 80
puts ''
puts "Mode: #{options[:dry_run] ? 'DRY RUN' : 'EXECUTED'}"
puts ''
puts "Accounts processed: #{stats[:total_accounts]}"
puts "Images migrated: #{stats[:migrated]}"
puts "Already existed (skipped): #{stats[:skipped]}"
puts "Not found in any inbox: #{stats[:not_found]}"
puts "Errors: #{stats[:errors]}"
puts ''

if options[:dry_run]
  puts '💡 This was a dry run. No changes were made.'
  puts '   To execute migration, run with --execute flag:'
  puts ''
  if account_ids.count == 1
    puts "   rails runner script/migrate_branding_images_to_shared.rb --execute --account=#{account_ids.first}"
  else
    puts '   rails runner script/migrate_branding_images_to_shared.rb --execute --all-accounts'
  end
  puts ''
end

# Verification (only in execute mode)
if !options[:dry_run] && stats[:migrated] > 0
  puts '=' * 80
  puts 'Verification'
  puts '=' * 80
  puts ''

  account_ids.each do |account_id|
    puts "Account #{account_id}:"

    BRANDING_IMAGES.keys.each do |identifier|
      shared = SharedAppleImage.find_by(account_id: account_id, identifier: identifier)

      if shared&.image&.attached?
        puts "  ✅ #{identifier} (branding) - SharedAppleImage ID: #{shared.id}"
      else
        puts "  ❌ #{identifier} - Not found in SharedAppleImage"
      end
    end

    puts ''
  end

  puts '=' * 80
  puts 'Next Steps'
  puts '=' * 80
  puts ''
  puts '1. Verify images in admin UI or Rails console'
  puts '2. Update services to use ImageFetchService for automatic fallback'
  puts '3. Test list picker, time picker, and forms with shared images'
  puts '4. Consider adding more branding images to BRANDING_IMAGES config'
  puts ''
  puts 'See: docs/apple-messages/IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md'
  puts ''
end

puts '✨ Migration complete!'
puts ''
