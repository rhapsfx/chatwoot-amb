#!/usr/bin/env ruby
# frozen_string_literal: true

# Filter migration templates to keep only useful, non-duplicate ones
# Usage: ruby scripts/filter_useful_templates.rb [business_name]

require 'json'
require 'digest'

business_name = ARGV[0] || 'acoustic_house'
migration_file = File.join('tmp', 'bot_migration', business_name, 'migration_data_CORE.json')
output_file = File.join('tmp', 'bot_migration', business_name, 'migration_data_FILTERED.json')

unless File.exist?(migration_file)
  puts "Error: Migration file not found: #{migration_file}"
  exit 1
end

data = JSON.parse(File.read(migration_file))
payloads = data['payloads']

puts "🔍 Filtering Templates for: #{business_name}"
puts '=' * 80
puts "Original count: #{payloads.size}"
puts

# Filter logic
filtered = []
seen_signatures = Set.new
stats = {
  empty_text_removed: 0,
  duplicates_removed: 0,
  kept: 0
}

payloads.each do |payload|
  template = payload['template']
  content_type = template['content_type']
  content = template['content'].to_s.strip
  attrs = template['content_attributes'] || {}

  # Rule 1: Skip empty text templates (likely placeholders)
  if content_type == 'text' && content.empty?
    stats[:empty_text_removed] += 1
    next
  end

  # Rule 2: Create signature for duplicate detection
  signature = case content_type
              when /quick_reply/
                # For quick replies, use options as signature
                options = attrs['options'] || []
                titles = options.map { |o| o['title'] }.sort.join('|')
                "qr:#{titles}"
              when /list_picker/
                # For list pickers, use section titles
                sections = attrs['sections'] || []
                section_titles = sections.map { |s| s['title'] }.compact.sort.join('|')
                "lp:#{section_titles}"
              when /form/
                # For forms, use field identifiers
                fields = attrs.dig('receivedMessage', 'fields') ||
                         attrs.dig('received_message', 'fields') || []
                field_ids = fields.map { |f| f['identifier'] }.compact.sort.join('|')
                "form:#{field_ids}"
              when /time_picker/
                # For time pickers, use title
                title = attrs.dig('receivedMessage', 'title') ||
                        attrs.dig('received_message', 'title') || ''
                "tp:#{title}"
              else
                # For text, use content hash
                "text:#{Digest::MD5.hexdigest(content)}"
              end

  # Rule 3: Skip duplicates
  if seen_signatures.include?(signature)
    stats[:duplicates_removed] += 1
    puts "  ⏭️  Skipping duplicate: #{payload['original_file']} (#{content_type})"
    next
  end

  seen_signatures.add(signature)
  filtered << payload
  stats[:kept] += 1
end

puts
puts '=' * 80
puts '📊 Filtering Results:'
puts '=' * 80
puts "  Removed empty text templates: #{stats[:empty_text_removed]}"
puts "  Removed duplicates: #{stats[:duplicates_removed]}"
puts "  ✅ Kept useful templates: #{stats[:kept]}"
puts

# Save filtered data
filtered_data = data.dup
filtered_data['payloads'] = filtered
filtered_data['filtered_at'] = Time.now.strftime('%Y-%m-%dT%H:%M:%S%z')
filtered_data['filter_stats'] = stats

File.write(output_file, JSON.pretty_generate(filtered_data))

puts '💾 Saved filtered templates to:'
puts "  #{output_file}"
puts
puts '🎯 Next Steps:'
puts '  1. Review the filtered file to ensure it looks correct'
puts "  2. Import with: rails runner scripts/import_as_message_templates.rb --account-id 1 --business #{business_name}"
puts '     (The import script will automatically use migration_data_FILTERED.json if it exists)'
