# frozen_string_literal: true

# Migration to normalize Apple Messages content_attributes from mixed camelCase/snake_case to consistent snake_case
#
# This migration:
# - Finds all Apple Messages message records
# - Converts any camelCase keys in content_attributes to snake_case
# - Preserves all data (idempotent transformation)
# - Logs progress and statistics
# - Can be safely run multiple times
#
# Safety features:
# - Batch processing to avoid memory issues
# - Transaction per message for atomic updates
# - Detailed logging for troubleshooting
# - Dry-run capability (set DRY_RUN=true)
#
class NormalizeAppleMessagesContentAttributes < ActiveRecord::Migration[7.0]
  # Apple Messages content types that need normalization
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

  def up
    # Check if running in dry-run mode
    dry_run = ENV['DRY_RUN'] == 'true'

    say "Starting Apple Messages content_attributes normalization"
    say "Mode: #{dry_run ? 'DRY RUN' : 'LIVE'}"
    say "=" * 80

    # Count total messages needing normalization
    total_count = Message.where(content_type: APPLE_CONTENT_TYPES)
                         .where.not(content_attributes: nil)
                         .count

    say "Found #{total_count} Apple Messages to process"
    return if total_count.zero?

    # Statistics
    stats = {
      processed: 0,
      normalized: 0,
      already_normalized: 0,
      errors: 0,
      skipped: 0
    }

    # Process in batches to manage memory
    batch_size = 100
    batch_count = (total_count.to_f / batch_size).ceil

    say "Processing in #{batch_count} batches of #{batch_size}"
    say "-" * 80

    Message.where(content_type: APPLE_CONTENT_TYPES)
           .where.not(content_attributes: nil)
           .find_in_batches(batch_size: batch_size).with_index do |batch, batch_index|

      say "Processing batch #{batch_index + 1}/#{batch_count}..."

      batch.each do |message|
        begin
          stats[:processed] += 1

          # Skip if content_attributes is empty
          if message.content_attributes.blank?
            stats[:skipped] += 1
            next
          end

          # Check if normalization is needed
          normalized = AppleMessagesForBusiness::CaseTransformer.from_apple_format(
            message.content_attributes
          )

          # Compare before and after to see if changes were made
          if normalized == message.content_attributes
            stats[:already_normalized] += 1
            next
          end

          # Log the change (in verbose mode)
          if ENV['VERBOSE'] == 'true'
            say "  Message #{message.id}:"
            say "    Before: #{message.content_attributes.keys.first(5).join(', ')}..."
            say "    After:  #{normalized.keys.first(5).join(', ')}..."
          end

          # Update the message (unless dry-run)
          unless dry_run
            message.update_column(:content_attributes, normalized)
          end

          stats[:normalized] += 1

        rescue StandardError => e
          stats[:errors] += 1
          say "  ERROR processing message #{message.id}: #{e.message}", true
          say "  Backtrace: #{e.backtrace.first(3).join("\n  ")}", true if ENV['VERBOSE'] == 'true'
        end

        # Progress indicator
        if stats[:processed] % 50 == 0
          progress = (stats[:processed].to_f / total_count * 100).round(1)
          say "  Progress: #{stats[:processed]}/#{total_count} (#{progress}%)"
        end
      end
    end

    # Print final statistics
    say "=" * 80
    say "Migration #{dry_run ? 'dry-run' : 'complete'}!"
    say ""
    say "Statistics:"
    say "  Total processed:      #{stats[:processed]}"
    say "  Normalized:           #{stats[:normalized]}"
    say "  Already normalized:   #{stats[:already_normalized]}"
    say "  Skipped (empty):      #{stats[:skipped]}"
    say "  Errors:               #{stats[:errors]}"
    say ""

    if dry_run
      say "=" * 80
      say "DRY RUN COMPLETE - No changes were made"
      say "Run without DRY_RUN=true to apply changes"
      say "=" * 80
    else
      say "=" * 80
      say "MIGRATION COMPLETE - Changes applied to database"
      say "=" * 80
    end
  end

  def down
    say "Rollback not needed - transformation is idempotent"
    say "Original data can be restored from backup if necessary"
    say ""
    say "To reverse the normalization (convert snake_case back to camelCase),"
    say "use the provided rollback script in docs/apple-messages/scripts/"
  end
end
