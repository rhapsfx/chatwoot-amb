#!/usr/bin/env ruby
# frozen_string_literal: true

# Rollback script for content_attributes normalization
#
# This script reverses the normalization by converting snake_case back to camelCase
# WARNING: Only use this if you need to rollback the migration
#
# Usage:
#   rails runner docs/apple-messages/scripts/rollback_normalization.rb
#   rails runner docs/apple-messages/scripts/rollback_normalization.rb DRY_RUN=true
#

require 'json'

puts "=" * 80
puts "Apple Messages Content Attributes Normalization - ROLLBACK"
puts "=" * 80
puts ""

# Check if running in dry-run mode
dry_run = ENV['DRY_RUN'] == 'true'

puts "Mode: #{dry_run ? 'DRY RUN' : 'LIVE ROLLBACK'}"
puts ""

if !dry_run
  puts "⚠️  WARNING: This will convert all content_attributes back to camelCase"
  puts ""
  puts "Are you sure you want to proceed? (Type 'yes' to continue)"

  # In script mode, check environment variable for confirmation
  confirmation = ENV['CONFIRM_ROLLBACK']

  unless confirmation == 'yes'
    puts ""
    puts "❌ Rollback cancelled"
    puts "   To proceed, set CONFIRM_ROLLBACK=yes"
    exit 1
  end
end

puts "-" * 80

# Configuration
APPLE_CONTENT_TYPES = %w[
  apple_list_picker
  apple_time_picker
  apple_quick_reply
  apple_form
  apple_custom_app
  apple_rich_link
  apple_pay
  apple_authentication
].freeze

# Find all Apple Messages
total_count = Message.where(content_type: APPLE_CONTENT_TYPES)
                     .where.not(content_attributes: nil)
                     .count

puts "Found #{total_count} Apple Messages records to rollback"
puts ""

if total_count.zero?
  puts "No records to process. Exiting."
  exit 0
end

# Statistics
stats = {
  processed: 0,
  rolled_back: 0,
  already_camelcase: 0,
  errors: 0,
  skipped: 0
}

# Process in batches
batch_size = 100
batch_count = (total_count.to_f / batch_size).ceil

puts "Processing in #{batch_count} batches of #{batch_size}"
puts "-" * 80

Message.where(content_type: APPLE_CONTENT_TYPES)
       .where.not(content_attributes: nil)
       .find_in_batches(batch_size: batch_size).with_index do |batch, batch_index|

  puts "Processing batch #{batch_index + 1}/#{batch_count}..."

  batch.each do |message|
    begin
      stats[:processed] += 1

      # Skip if content_attributes is empty
      if message.content_attributes.blank?
        stats[:skipped] += 1
        next
      end

      # Convert snake_case to camelCase
      original = message.content_attributes
      camelized = convert_to_camelcase(original)

      # Check if changes needed
      if camelized == original
        stats[:already_camelcase] += 1
        next
      end

      # Log the change (in verbose mode)
      if ENV['VERBOSE'] == 'true'
        puts "  Message #{message.id}:"
        puts "    Before: #{original.keys.first(5).join(', ')}..."
        puts "    After:  #{camelized.keys.first(5).join(', ')}..."
      end

      # Update the message (unless dry-run)
      unless dry_run
        message.update_column(:content_attributes, camelized)
      end

      stats[:rolled_back] += 1

    rescue StandardError => e
      stats[:errors] += 1
      puts "  ERROR processing message #{message.id}: #{e.message}", true
      puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}" if ENV['VERBOSE'] == 'true'
    end

    # Progress indicator
    if stats[:processed] % 50 == 0
      progress = (stats[:processed].to_f / total_count * 100).round(1)
      puts "  Progress: #{stats[:processed]}/#{total_count} (#{progress}%)"
    end
  end
end

# Print final statistics
puts "=" * 80
puts "Rollback #{dry_run ? 'dry-run' : 'complete'}!"
puts ""
puts "Statistics:"
puts "  Total processed:        #{stats[:processed]}"
puts "  Rolled back:            #{stats[:rolled_back]}"
puts "  Already camelCase:      #{stats[:already_camelcase]}"
puts "  Skipped (empty):        #{stats[:skipped]}"
puts "  Errors:                 #{stats[:errors]}"
puts ""

if dry_run
  puts "=" * 80
  puts "DRY RUN COMPLETE - No changes were made"
  puts "Run without DRY_RUN=true to apply rollback"
  puts "=" * 80
else
  puts "=" * 80
  puts "ROLLBACK COMPLETE - Content attributes converted back to camelCase"
  puts ""
  puts "⚠️  WARNING: Services expect snake_case internally"
  puts "   You may need to revert code changes as well"
  puts "=" * 80
end

# Helper method to convert snake_case to camelCase
def convert_to_camelcase(hash)
  return hash unless hash.is_a?(Hash)

  camelized = {}

  hash.each do |key, value|
    # Convert key to camelCase
    camel_key = if key.to_s.include?('_')
                  parts = key.to_s.split('_')
                  parts[0] + parts[1..].map(&:capitalize).join
                else
                  key.to_s
                end

    # Recursively convert value
    camelized[camel_key] = case value
                           when Hash
                             convert_to_camelcase(value)
                           when Array
                             value.map { |item| item.is_a?(Hash) ? convert_to_camelcase(item) : item }
                           else
                             value
                           end
  end

  camelized
end
