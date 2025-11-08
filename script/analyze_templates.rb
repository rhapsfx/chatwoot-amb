#!/usr/bin/env ruby
# frozen_string_literal: true

# Analyze migration templates to see which are worth importing
# Usage: ruby scripts/analyze_templates.rb [business_name]

require 'json'

business_name = ARGV[0] || 'acoustic_house'
migration_file = File.join('tmp', 'bot_migration', business_name, 'migration_data_CORE.json')

unless File.exist?(migration_file)
  puts "Error: Migration file not found: #{migration_file}"
  exit 1
end

data = JSON.parse(File.read(migration_file))
payloads = data['payloads']

puts '=' * 80
puts "Template Analysis for: #{business_name}"
puts '=' * 80
puts

# Overall stats
total = payloads.size
empty_content = payloads.count { |p| p['template']['content'].to_s.strip.empty? }
has_attrs = payloads.count { |p| p['template']['content_attributes'].present? }

puts '📊 Overall Statistics:'
puts "  Total templates: #{total}"
puts "  Empty content: #{empty_content} (#{(empty_content * 100.0 / total).round(1)}%)"
puts "  With content_attributes: #{has_attrs} (#{(has_attrs * 100.0 / total).round(1)}%)"
puts

# By content type
by_type = payloads.group_by { |p| p['template']['content_type'] }

puts '📋 Breakdown by Content Type:'
puts
by_type.each do |type, templates|
  empty = templates.count { |t| t['template']['content'].to_s.strip.empty? }
  with_attrs = templates.count { |t| t['template']['content_attributes'].present? }

  puts "  #{type}:"
  puts "    Total: #{templates.size}"
  puts "    Empty content: #{empty}"
  puts "    With attributes: #{with_attrs}"

  # Show useful vs useless
  if type.include?('list_picker') || type.include?('time_picker') || type.include?('form')
    useful = with_attrs
    puts "    ✅ Useful: #{useful} (interactive templates with attributes)"
  elsif type == 'text'
    useful = templates.size - empty
    puts "    ✅ Useful: #{useful} (text templates with content)"
  else
    useful = templates.size - empty + with_attrs
    puts "    ✅ Useful: #{useful}"
  end
  puts
end

# Show examples of empty templates
puts '🔍 Sample Empty Text Templates (first 5):'
empty_text = payloads.select { |p| p['template']['content_type'] == 'text' && p['template']['content'].to_s.strip.empty? }
empty_text.first(5).each do |payload|
  template = payload['template']
  attrs = template['content_attributes']

  puts "  • #{payload['original_file']}"
  puts "    Name: #{template['name']}"
  puts "    Has dynamic config: #{!attrs.dig('dynamic').nil?}"
  puts "    Has request_id: #{!attrs.dig('request_identifier').nil?}"
  puts
end

# Recommendation
puts '=' * 80
puts '💡 Recommendations:'
puts '=' * 80

interactive_useful = by_type.select { |k, _| k.include?('list_picker') || k.include?('time_picker') || k.include?('form') }
                            .sum do |_, templates|
  templates.count do |t|
    t['template']['content_attributes'].present?
  end
end

text_useful = by_type['text']&.count { |t| !t['template']['content'].to_s.strip.empty? } || 0

puts '✅ Worth importing:'
puts "  - #{interactive_useful} interactive templates (list pickers, time pickers, forms)"
puts "  - #{text_useful} text templates with meaningful content"
puts "  Total: #{interactive_useful + text_useful} templates"
puts

puts '❌ Skip importing:'
puts "  - #{empty_content - (payloads.size - interactive_useful - text_useful)} empty text templates"
puts '  (These appear to be placeholders or dynamic templates)'
puts

puts '🎯 Next Steps:'
puts '  1. Filter migration data to only include useful templates'
puts "  2. Run: ruby scripts/filter_useful_templates.rb #{business_name}"
puts "  3. Then import: rails runner scripts/import_as_message_templates.rb --account-id 1 --business #{business_name}"
