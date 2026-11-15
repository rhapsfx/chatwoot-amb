#!/usr/bin/env ruby
# frozen_string_literal: true

# Dry-run script for testing content_attributes normalization
#
# This script:
# - Analyzes existing Apple Messages records
# - Shows what changes would be made
# - Validates transformation safety
# - Provides detailed statistics
#
# Usage:
#   rails runner docs/apple-messages/scripts/dry_run_normalization.rb
#   rails runner docs/apple-messages/scripts/dry_run_normalization.rb VERBOSE=true
#

require 'json'

# Helper methods (define first)
def percentage(part, whole)
  return 0 if whole.zero?

  (part.to_f / whole * 100).round(1)
end

def find_changed_fields(original, normalized, prefix = '')
  changed = []

  # Check all keys in both hashes
  all_keys = (original.keys + normalized.keys).uniq

  all_keys.each do |key|
    full_key = prefix.empty? ? key : "#{prefix}.#{key}"

    if original[key] != normalized[key]
      # Check if it's a nested hash
      if original[key].is_a?(Hash) && normalized[key].is_a?(Hash)
        changed.concat(find_changed_fields(original[key], normalized[key], full_key))
      else
        changed << full_key
      end
    end
  end

  changed
end

def collect_all_keys(hash, prefix = '')
  keys = []

  hash.each do |key, value|
    full_key = prefix.empty? ? key : "#{prefix}.#{key}"
    keys << full_key

    if value.is_a?(Hash)
      keys.concat(collect_all_keys(value, full_key))
    elsif value.is_a?(Array)
      value.each_with_index do |item, index|
        keys.concat(collect_all_keys(item, "#{full_key}[#{index}]")) if item.is_a?(Hash)
      end
    end
  end

  keys
end

puts '=' * 80
puts 'Apple Messages Content Attributes Normalization - DRY RUN'
puts '=' * 80
puts ''

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

VERBOSE = ENV['VERBOSE'] == 'true'

# Find all Apple Messages
messages = Message.where(content_type: APPLE_CONTENT_TYPES)
                  .where.not(content_attributes: nil)

total_count = messages.count

puts "Found #{total_count} Apple Messages records"
puts ''

if total_count.zero?
  puts 'No records to process. Exiting.'
  exit 0
end

# Statistics
stats = {
  total: total_count,
  needs_normalization: 0,
  already_normalized: 0,
  empty: 0,
  errors: 0,
  changes_by_type: Hash.new(0),
  affected_fields: Hash.new(0)
}

# Sample records for detailed analysis
samples = []
max_samples = 5

puts 'Analyzing records...'
puts '-' * 80

messages.find_each.with_index do |message, index|
  # Skip empty
  if message.content_attributes.blank?
    stats[:empty] += 1
    next
  end

  # Normalize
  original = message.content_attributes
  normalized = AppleMessagesForBusiness::CaseTransformer.from_apple_format(original)

  # Check if changes needed
  if normalized == original
    stats[:already_normalized] += 1
  else
    stats[:needs_normalization] += 1
    stats[:changes_by_type][message.content_type] += 1

    # Track which fields changed
    changes = find_changed_fields(original, normalized)
    changes.each { |field| stats[:affected_fields][field] += 1 }

    # Collect samples
    if samples.length < max_samples
      samples << {
        id: message.id,
        content_type: message.content_type,
        original: original,
        normalized: normalized,
        changes: changes
      }
    end
  end

  # Progress
  if VERBOSE && (index + 1) % 100 == 0
    progress = ((index + 1).to_f / total_count * 100).round(1)
    puts "  Analyzed #{index + 1}/#{total_count} (#{progress}%)"
  end

rescue StandardError => e
  stats[:errors] += 1
  puts "  ERROR analyzing message #{message.id}: #{e.message}"
  puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}" if VERBOSE
end

puts ''
puts '=' * 80
puts 'DRY RUN RESULTS'
puts '=' * 80
puts ''

# Summary statistics
puts 'Summary:'
puts "  Total records:             #{stats[:total]}"
puts "  Need normalization:        #{stats[:needs_normalization]} (#{percentage(stats[:needs_normalization], stats[:total])}%)"
puts "  Already normalized:        #{stats[:already_normalized]} (#{percentage(stats[:already_normalized], stats[:total])}%)"
puts "  Empty (skipped):           #{stats[:empty]}"
puts "  Errors:                    #{stats[:errors]}"
puts ''

# Changes by content type
if stats[:needs_normalization] > 0
  puts 'Changes by content type:'
  stats[:changes_by_type].sort_by { |_, count| -count }.each do |type, count|
    puts "  #{type.ljust(25)} #{count} records"
  end
  puts ''

  # Most affected fields
  puts 'Most affected fields (top 10):'
  stats[:affected_fields].sort_by { |_, count| -count }.first(10).each do |field, count|
    puts "  #{field.ljust(35)} #{count} occurrences"
  end
  puts ''
end

# Sample changes
if samples.any?
  puts '=' * 80
  puts "SAMPLE CHANGES (first #{samples.length} records)"
  puts '=' * 80
  puts ''

  samples.each_with_index do |sample, index|
    puts "Sample #{index + 1}: Message ##{sample[:id]} (#{sample[:content_type]})"
    puts '-' * 80
    puts "Changed fields: #{sample[:changes].join(', ')}"
    puts ''

    next unless VERBOSE

    puts 'Before:'
    puts JSON.pretty_generate(sample[:original].slice(*sample[:changes]))
    puts ''
    puts 'After:'
    puts JSON.pretty_generate(sample[:normalized].slice(*sample[:changes]))
    puts ''
  end
end

# Safety checks
puts '=' * 80
puts 'SAFETY CHECKS'
puts '=' * 80
puts ''

# Check 1: No data loss
data_loss = false
samples.each do |sample|
  original_keys = collect_all_keys(sample[:original])
  normalized_keys = collect_all_keys(sample[:normalized])

  next unless original_keys.length != normalized_keys.length

  data_loss = true
  puts "⚠️  WARNING: Key count mismatch in message #{sample[:id]}"
  puts "   Original: #{original_keys.length} keys"
  puts "   Normalized: #{normalized_keys.length} keys"
end

if data_loss
  puts ''
  puts '❌ DATA LOSS DETECTED - Review warnings above before proceeding'
else
  puts '✅ No data loss detected'
end
puts ''

# Check 2: Round-trip validation
round_trip_ok = true
samples.first(3).each do |sample|
  # Convert to Apple format and back
  to_apple = AppleMessagesForBusiness::CaseTransformer.to_apple_format(sample[:normalized])
  back_to_internal = AppleMessagesForBusiness::CaseTransformer.from_apple_format(
    to_apple.transform_keys(&:to_s)
  )

  if back_to_internal != sample[:normalized]
    round_trip_ok = false
    puts "⚠️  WARNING: Round-trip transformation failed for message #{sample[:id]}"
  end
end

if round_trip_ok
  puts '✅ Round-trip transformation validated'
else
  puts '❌ ROUND-TRIP VALIDATION FAILED - Review warnings above'
end
puts ''

# Recommendations
puts '=' * 80
puts 'RECOMMENDATIONS'
puts '=' * 80
puts ''

if stats[:needs_normalization] == 0
  puts '✅ All records are already normalized. No migration needed.'
elsif stats[:errors] > 0
  puts '⚠️  Errors detected during analysis. Review errors before migrating.'
  puts '   Run with VERBOSE=true for detailed error information.'
elsif data_loss || !round_trip_ok
  puts '❌ MIGRATION NOT SAFE - Fix issues before proceeding'
else
  puts '✅ Migration appears safe to proceed'
  puts ''
  puts 'Next steps:'
  puts '  1. Review sample changes above'
  puts '  2. Create database backup:'
  puts '     pg_dump chatwoot_development > backup_before_normalization.sql'
  puts '  3. Run migration in staging first:'
  puts '     DRY_RUN=true rails db:migrate'
  puts '  4. Test application thoroughly in staging'
  puts '  5. Run migration in production:'
  puts '     rails db:migrate'
  puts ''
  puts 'Rollback option available if needed:'
  puts '  rails runner docs/apple-messages/scripts/rollback_normalization.rb'
end

puts '=' * 80
