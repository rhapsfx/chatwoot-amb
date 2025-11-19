#!/usr/bin/env ruby
# frozen_string_literal: true

# Migrate system images from AppleListPickerImage to SharedAppleImage
# Part of Phase 3: Migration Utilities (IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md)
#
# This script migrates system-wide images (messages_png, calendar icons, etc.)
# from inbox-specific AppleListPickerImage table to account-wide SharedAppleImage table.
#
# USAGE:
#   rails runner script/migrate_system_images_to_shared.rb              # Dry run (preview)
#   rails runner script/migrate_system_images_to_shared.rb --execute    # Actual migration

require_relative '../config/environment'
require 'stringio'

# System images configuration
# Maps identifier to type and description
SYSTEM_IMAGES = {
  'messages_png' => {
    type: 'system',
    description: 'Messages app icon for received message'
  },
  'apple_store_logo' => {
    type: 'branding',
    description: 'Apple Store logo'
  },
  'calendar_icon' => {
    type: 'system',
    description: 'Calendar icon for time picker'
  },
  'time_picker_icon' => {
    type: 'system',
    description: 'Time picker icon'
  }
}.freeze

class SystemImageMigrator
  attr_reader :dry_run, :stats

  def initialize(dry_run: true)
    @dry_run = dry_run
    @stats = {
      total: 0,
      migrated: 0,
      skipped: 0,
      failed: 0,
      errors: []
    }
  end

  def run
    print_header
    confirm_execution unless dry_run

    SYSTEM_IMAGES.each do |identifier, config|
      @stats[:total] += 1
      migrate_image(identifier, config)
    end

    print_summary
  end

  private

  def print_header
    puts '=' * 80
    puts 'System Images Migration to SharedAppleImage'
    puts '=' * 80
    puts ''
    puts "Mode: #{dry_run ? 'DRY RUN (Preview Only)' : 'EXECUTE (Actual Migration)'}"
    puts ''
    puts 'This script will migrate the following system images:'
    SYSTEM_IMAGES.each do |identifier, config|
      puts "  - #{identifier} (#{config[:type]}): #{config[:description]}"
    end
    puts ''
  end

  def confirm_execution
    puts 'WARNING: This will migrate images from AppleListPickerImage to SharedAppleImage.'
    puts 'Original images will be kept for backward compatibility.'
    puts ''
    print 'Type "yes" to confirm: '
    confirmation = STDIN.gets.chomp

    unless confirmation.downcase == 'yes'
      puts 'Migration cancelled.'
      exit 0
    end
    puts ''
  end

  def migrate_image(identifier, config)
    puts "Processing: #{identifier}..."

    # Find all accounts that have this image
    accounts_with_image = find_accounts_with_image(identifier)

    if accounts_with_image.empty?
      handle_no_source(identifier)
      return
    end

    # Migrate for each account
    accounts_with_image.each do |account_id|
      migrate_for_account(identifier, config, account_id)
    end
  end

  def find_accounts_with_image(identifier)
    AppleListPickerImage
      .where(identifier: identifier)
      .distinct
      .pluck(:account_id)
  rescue StandardError => e
    log_error(identifier, "Error finding accounts: #{e.message}")
    []
  end

  def migrate_for_account(identifier, config, account_id)
    # Check if already exists in SharedAppleImage
    existing_shared = SharedAppleImage.find_by(
      account_id: account_id,
      identifier: identifier
    )

    if existing_shared
      handle_already_exists(identifier, account_id)
      return
    end

    # Find source image (prefer one with attachment)
    source_image = find_source_image(identifier, account_id)

    unless source_image
      handle_no_attachment(identifier, account_id)
      return
    end

    # Perform migration
    if dry_run
      handle_dry_run_migration(identifier, config, account_id, source_image)
    else
      perform_actual_migration(identifier, config, account_id, source_image)
    end
  end

  def find_source_image(identifier, account_id)
    AppleListPickerImage
      .where(identifier: identifier, account_id: account_id)
      .includes(image_attachment: :blob)
      .find { |img| img.image.attached? }
  rescue StandardError => e
    log_error(identifier, "Error finding source image: #{e.message}")
    nil
  end

  def handle_no_source(identifier)
    puts "  #{emoji(:skip)} Skipped #{identifier} (no source image found in any inbox)"
    @stats[:skipped] += 1
  end

  def handle_already_exists(identifier, account_id)
    puts "  #{emoji(:skip)} Skipped #{identifier} for account #{account_id} (already exists in SharedAppleImage)"
    @stats[:skipped] += 1
  end

  def handle_no_attachment(identifier, account_id)
    puts "  #{emoji(:warning)} Failed #{identifier} for account #{account_id} (no attachment found)"
    @stats[:failed] += 1
    log_error(identifier, "No attachment found for account #{account_id}")
  end

  def handle_dry_run_migration(identifier, config, account_id, source_image)
    puts "  #{emoji(:preview)} Would migrate #{identifier} for account #{account_id} (#{config[:type]})"
    puts "      Source: AppleListPickerImage ID #{source_image.id} from inbox #{source_image.inbox_id}"
    puts "      Image: #{source_image.original_name || 'unknown'} (#{source_image.image.byte_size} bytes)"
    @stats[:migrated] += 1
  end

  def perform_actual_migration(identifier, config, account_id, source_image)
    ActiveRecord::Base.transaction do
      # Create SharedAppleImage with blob attachment
      shared_image = SharedAppleImage.new(
        account_id: account_id,
        identifier: identifier,
        image_type: config[:type],
        description: config[:description],
        original_name: source_image.original_name,
        metadata: {
          migrated_from_inbox_id: source_image.inbox_id,
          migrated_from_picker_image_id: source_image.id,
          migrated_at: Time.current.iso8601,
          original_description: source_image.description
        }
      )

      # Attach the same blob (no duplication needed)
      shared_image.image.attach(source_image.image.blob)

      if shared_image.save
        puts "  #{emoji(:success)} Migrated #{identifier} for account #{account_id} (#{config[:type]})"
        puts "      Created SharedAppleImage ID #{shared_image.id}"
        @stats[:migrated] += 1
      else
        error_msg = shared_image.errors.full_messages.join(', ')
        puts "  #{emoji(:error)} Failed #{identifier} for account #{account_id}: #{error_msg}"
        @stats[:failed] += 1
        log_error(identifier, "Validation failed for account #{account_id}: #{error_msg}")
        raise ActiveRecord::Rollback
      end
    end
  rescue StandardError => e
    puts "  #{emoji(:error)} Failed #{identifier} for account #{account_id}: #{e.message}"
    @stats[:failed] += 1
    log_error(identifier, "Exception for account #{account_id}: #{e.message}")
  end

  def log_error(identifier, message)
    @stats[:errors] << { identifier: identifier, message: message }
  end

  def print_summary
    puts ''
    puts '=' * 80
    puts 'Migration Summary'
    puts '=' * 80
    puts ''
    puts "Mode: #{dry_run ? 'DRY RUN' : 'EXECUTE'}"
    puts "Total images processed: #{@stats[:total]}"
    puts "#{emoji(:success)} Successfully migrated: #{@stats[:migrated]}"
    puts "#{emoji(:skip)} Skipped (already exist): #{@stats[:skipped]}"
    puts "#{emoji(:error)} Failed: #{@stats[:failed]}"
    puts ''

    if @stats[:errors].any?
      puts 'Errors:'
      @stats[:errors].each do |error|
        puts "  - #{error[:identifier]}: #{error[:message]}"
      end
      puts ''
    end

    if dry_run
      puts 'This was a DRY RUN. No changes were made.'
      puts 'Run with --execute flag to perform actual migration:'
      puts '  rails runner script/migrate_system_images_to_shared.rb --execute'
      puts ''
    else
      puts 'Migration complete!'
      puts ''
      puts 'Next steps:'
      puts '1. Verify migration with: rails runner "SharedAppleImage.all.each { |i| puts i.inspect }"'
      puts '2. Test image fetching with ImageFetchService'
      puts '3. Original AppleListPickerImage records are kept for backward compatibility'
      puts ''
    end
  end

  def emoji(type)
    case type
    when :success
      '✅'
    when :skip
      '⏭️'
    when :error
      '❌'
    when :warning
      '⚠️'
    when :preview
      '🔍'
    else
      '•'
    end
  end
end

# Parse command line arguments
dry_run = !ARGV.include?('--execute')

# Run migration
migrator = SystemImageMigrator.new(dry_run: dry_run)
migrator.run
