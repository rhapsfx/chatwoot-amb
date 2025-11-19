#!/usr/bin/env ruby
# frozen_string_literal: true

# Monitoring script to verify normalization results
#
# This script:
# - Checks if all Apple Messages content_attributes are properly normalized
# - Identifies any remaining mixed-case issues
# - Validates data integrity
# - Provides health metrics
#
# Usage:
#   rails runner docs/apple-messages/scripts/verify_normalization.rb
#   rails runner docs/apple-messages/scripts/verify_normalization.rb DETAILED=true
#

require 'json'

# Helper methods (define first)
def find_camelcase_keys(hash, prefix = '')
  keys = []

  hash.each do |key, value|
    string_key = key.to_s
    full_key = prefix.empty? ? string_key : "#{prefix}.#{string_key}"

    # Check if key is camelCase (has lowercase followed by uppercase)
    keys << full_key if string_key.match?(/[a-z][A-Z]/)

    # Recurse into nested structures
    if value.is_a?(Hash)
      keys.concat(find_camelcase_keys(value, full_key))
    elsif value.is_a?(Array)
      value.each_with_index do |item, index|
        keys.concat(find_camelcase_keys(item, "#{full_key}[#{index}]")) if item.is_a?(Hash)
      end
    end
  end

  keys
end

def find_snake_case_keys(hash, prefix = '')
  keys = []

  hash.each do |key, value|
    string_key = key.to_s
    full_key = prefix.empty? ? string_key : "#{prefix}.#{string_key}"

    # Check if key is snake_case (has underscore)
    keys << full_key if string_key.include?('_')

    # Recurse into nested structures
    if value.is_a?(Hash)
      keys.concat(find_snake_case_keys(value, full_key))
    elsif value.is_a?(Array)
      value.each_with_index do |item, index|
        keys.concat(find_snake_case_keys(item, "#{full_key}[#{index}]")) if item.is_a?(Hash)
      end
    end
  end

  keys
end

puts '=' * 80
puts 'Apple Messages Content Attributes Normalization - VERIFICATION'
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

DETAILED = ENV['DETAILED'] == 'true'

# Find all Apple Messages
messages = Message.where(content_type: APPLE_CONTENT_TYPES)
                  .where.not(content_attributes: nil)

total_count = messages.count

puts "Found #{total_count} Apple Messages records"
puts ''

if total_count.zero?
  puts '✅ No Apple Messages records found'
  exit 0
end

# Statistics
stats = {
  total: total_count,
  fully_normalized: 0,
  has_camelcase: 0,
  has_snake_case: 0,
  mixed_case: 0,
  by_content_type: Hash.new { |h, k| h[k] = { total: 0, normalized: 0, mixed: 0 } },
  camelcase_fields: Hash.new(0),
  issues: []
}

puts 'Analyzing records...'
puts '-' * 80

messages.find_each.with_index do |message, index|
  attrs = message.content_attributes

  # Skip empty
  next if attrs.blank?

  # Track by content type
  stats[:by_content_type][message.content_type][:total] += 1

  # Check for camelCase keys
  camelcase_keys = find_camelcase_keys(attrs)
  snake_case_keys = find_snake_case_keys(attrs)

  if camelcase_keys.empty?
    # Fully normalized (all snake_case)
    stats[:fully_normalized] += 1
    stats[:by_content_type][message.content_type][:normalized] += 1
  elsif snake_case_keys.empty?
    # All camelCase (not normalized)
    stats[:has_camelcase] += 1
    stats[:by_content_type][message.content_type][:mixed] += 1

    camelcase_keys.each { |key| stats[:camelcase_fields][key] += 1 }

    stats[:issues] << {
      id: message.id,
      type: message.content_type,
      problem: 'Not normalized (all camelCase)',
      fields: camelcase_keys
    }
  else
    # Mixed case (problem!)
    stats[:mixed_case] += 1
    stats[:by_content_type][message.content_type][:mixed] += 1

    camelcase_keys.each { |key| stats[:camelcase_fields][key] += 1 }

    stats[:issues] << {
      id: message.id,
      type: message.content_type,
      problem: 'Mixed casing',
      camelcase_fields: camelcase_keys,
      snake_case_fields: snake_case_keys
    }
  end

  # Progress
  if DETAILED && (index + 1) % 100 == 0
    progress = ((index + 1).to_f / total_count * 100).round(1)
    puts "  Analyzed #{index + 1}/#{total_count} (#{progress}%)"
  end

rescue StandardError => e
  puts "  ERROR analyzing message #{message.id}: #{e.message}"
end

puts ''
puts '=' * 80
puts 'VERIFICATION RESULTS'
puts '=' * 80
puts ''

# Overall health
normalized_percentage = (stats[:fully_normalized].to_f / stats[:total] * 100).round(1)

puts 'Overall Health:'
puts "  Total records:           #{stats[:total]}"
puts "  Fully normalized:        #{stats[:fully_normalized]} (#{normalized_percentage}%)"
puts "  Has camelCase:           #{stats[:has_camelcase]}"
puts "  Mixed case (problem):    #{stats[:mixed_case]}"
puts ''

# Health status
if stats[:fully_normalized] == stats[:total]
  puts '✅ EXCELLENT: All records are properly normalized'
elsif normalized_percentage >= 95
  puts "✅ GOOD: #{normalized_percentage}% normalized (#{stats[:total] - stats[:fully_normalized]} records need attention)"
elsif normalized_percentage >= 80
  puts "⚠️  WARNING: Only #{normalized_percentage}% normalized (#{stats[:total] - stats[:fully_normalized]} records need attention)"
else
  puts "❌ CRITICAL: Only #{normalized_percentage}% normalized (migration may have failed)"
end
puts ''

# By content type
if stats[:by_content_type].any?
  puts 'By Content Type:'
  puts '-' * 80
  stats[:by_content_type].sort_by { |type, _| type }.each do |type, data|
    normalized_pct = (data[:normalized].to_f / data[:total] * 100).round(1)
    status = normalized_pct == 100.0 ? '✅' : '⚠️ '

    puts "  #{status} #{type.ljust(25)} #{data[:normalized]}/#{data[:total]} normalized (#{normalized_pct}%)"
  end
  puts ''
end

# Most common camelCase fields still present
if stats[:camelcase_fields].any?
  puts 'Most Common camelCase Fields Still Present:'
  puts '-' * 80
  stats[:camelcase_fields].sort_by { |_, count| -count }.first(10).each do |field, count|
    puts "  #{field.ljust(35)} #{count} occurrences"
  end
  puts ''
end

# Sample issues
if stats[:issues].any?
  puts '=' * 80
  puts 'ISSUES FOUND (first 10)'
  puts '=' * 80
  puts ''

  stats[:issues].first(10).each_with_index do |issue, index|
    puts "Issue #{index + 1}: Message ##{issue[:id]} (#{issue[:type]})"
    puts "  Problem: #{issue[:problem]}"

    if issue[:fields]
      puts "  camelCase fields: #{issue[:fields].first(5).join(', ')}"
      puts "                    (#{issue[:fields].length} total)" if issue[:fields].length > 5
    end

    puts "  camelCase: #{issue[:camelcase_fields].join(', ')}" if issue[:camelcase_fields]

    puts "  snake_case: #{issue[:snake_case_fields].first(5).join(', ')}" if issue[:snake_case_fields]

    puts ''
  end

  if stats[:issues].length > 10
    puts "... and #{stats[:issues].length - 10} more issues"
    puts ''
  end
end

# Recommendations
puts '=' * 80
puts 'RECOMMENDATIONS'
puts '=' * 80
puts ''

if stats[:fully_normalized] == stats[:total]
  puts '✅ All records are properly normalized. No action needed.'
  puts ''
  puts 'Services can now safely remove defensive dual-checks.'
elsif stats[:has_camelcase] > 0 || stats[:mixed_case] > 0
  puts '⚠️  Some records are not properly normalized'
  puts ''
  puts 'Recommended actions:'
  puts '  1. Check if migration was run:'
  puts '     rails db:migrate:status | grep normalize_apple'
  puts ''
  puts '  2. If migration was run, re-run it:'
  puts '     rails db:migrate:redo VERSION=20251026114341'
  puts ''
  puts '  3. If issues persist, investigate specific records:'
  puts "     Message.find(#{stats[:issues].first[:id]}).content_attributes"
  puts ''
  puts '  4. For manual fix, use:'
  puts '     msg = Message.find(ID)'
  puts '     msg.content_attributes = AppleMessagesForBusiness::CaseTransformer.from_apple_format(msg.content_attributes)'
  puts '     msg.save!'
end

puts '=' * 80

# Data integrity checks
if DETAILED
  puts ''
  puts '=' * 80
  puts 'DATA INTEGRITY CHECKS'
  puts '=' * 80
  puts ''

  # Sample random messages and verify transformation reversibility
  sample_size = [10, stats[:fully_normalized]].min
  sample_messages = Message.where(content_type: APPLE_CONTENT_TYPES)
                           .where.not(content_attributes: nil)
                           .limit(sample_size)

  integrity_ok = true

  sample_messages.each do |message|
    # Try round-trip transformation
    original = message.content_attributes
    to_apple = AppleMessagesForBusiness::CaseTransformer.to_apple_format(original)
    back = AppleMessagesForBusiness::CaseTransformer.from_apple_format(to_apple.transform_keys(&:to_s))

    if back != original
      integrity_ok = false
      puts "⚠️  Message #{message.id}: Round-trip transformation failed"
    end
  end

  if integrity_ok
    puts "✅ Round-trip transformation validated on #{sample_size} samples"
  else
    puts '❌ Some round-trip transformations failed - review above'
  end
  puts ''
end
