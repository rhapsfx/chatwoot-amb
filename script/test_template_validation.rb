#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify template import will pass validation
# Usage: ruby scripts/test_template_validation.rb [business_name]

require 'json'

business_name = ARGV[0] || 'acoustic_house'
migration_file = File.join('tmp', 'bot_migration', business_name, 'migration_data_FILTERED.json')

unless File.exist?(migration_file)
  puts "Error: Migration file not found: #{migration_file}"
  puts "Run: ruby scripts/filter_useful_templates.rb #{business_name}"
  exit 1
end

data = JSON.parse(File.read(migration_file))

puts '🧪 Testing Template Validation'
puts '=' * 80
puts "Business: #{business_name}"
puts "Templates to test: #{data['payloads'].size}"
puts

# Simulate the build_block_properties method
def flatten_messages(content_attrs)
  received_msg = content_attrs['received_message'] || content_attrs['receivedMessage'] || {}
  reply_msg = content_attrs['reply_message'] || content_attrs['replyMessage'] || {}

  {
    'received_title' => received_msg['title'],
    'received_subtitle' => received_msg['subtitle'],
    'received_image_identifier' => received_msg['image_identifier'] || received_msg['imageIdentifier'],
    'received_style' => received_msg['style'],
    'reply_title' => reply_msg['title'],
    'reply_subtitle' => reply_msg['subtitle'],
    'reply_image_identifier' => reply_msg['image_identifier'] || reply_msg['imageIdentifier'],
    'reply_style' => reply_msg['style']
  }.compact
end

results = { pass: 0, fail: 0, warnings: [] }

data['payloads'].each do |payload|
  template_data = payload['template']
  content_type = template_data['content_type']
  content_attrs = template_data['content_attributes'] || {}

  # Detect actual type
  if content_type == 'text' && !content_attrs.empty?
    content_type = 'apple_list_picker' if content_attrs['list_picker']
    content_type = 'apple_time_picker' if content_attrs['time_picker']
    content_type = 'apple_form' if content_attrs.dig('dynamic', 'template') == 'formSelect'
    content_type = 'apple_quick_reply' if content_attrs['options']
  end

  name = payload['original_file']
  errors = []

  case content_type
  when /list_picker/
    list_picker_data = content_attrs['list_picker'] || {}
    sections = list_picker_data['sections'] || []

    errors << 'Missing sections' if sections.empty?
    errors << 'Missing receivedMessage' unless content_attrs['received_message'] || content_attrs['receivedMessage']

  when /time_picker/
    time_picker_data = content_attrs['time_picker'] || {}
    timeslots = time_picker_data['timeslots'] || time_picker_data.dig('event', 'timeslots') || []

    errors << 'Missing timeslots' if timeslots.empty?
    errors << 'Missing receivedMessage' unless content_attrs['received_message'] || content_attrs['receivedMessage']

  when /form/
    dynamic_config = content_attrs['dynamic'] || {}
    dynamic_page = dynamic_config['page'] || {}
    dynamic_data = dynamic_config['data'] || {}

    has_pages = (dynamic_data['pages'].present?) ||
                (dynamic_page['sections'].present?)
    has_fields = (dynamic_page['fields'].present?) ||
                 (content_attrs['fields'].present?)

    errors << "Missing required 'pages' or 'fields'" unless has_pages || has_fields
    errors << 'Missing title (required with pages)' if has_pages && dynamic_page['title'].to_s.empty? && dynamic_data.dig('splash',
                                                                                                                          'splashtext').to_s.empty?

  when /quick_reply/
    quick_reply_data = content_attrs['quick_reply'] || content_attrs['quick-reply'] || {}
    items = quick_reply_data['items'] || content_attrs['options'] || content_attrs['items'] || []
    summary = quick_reply_data['summary_text'] || content_attrs['title'] || content_attrs['summary_text']

    errors << 'Missing items/options' if items.empty?
    errors << 'Missing summary_text/title' if summary.to_s.empty?
  end

  if errors.empty?
    results[:pass] += 1
    puts "  ✅ #{name} (#{content_type})"
  else
    results[:fail] += 1
    puts "  ❌ #{name} (#{content_type})"
    errors.each { |e| puts "     - #{e}" }
    results[:warnings] << "#{name}: #{errors.join(', ')}"
  end
end

puts
puts '=' * 80
puts '📊 Validation Test Results'
puts '=' * 80
puts "  ✅ Will pass: #{results[:pass]}"
puts "  ❌ Will fail: #{results[:fail]}"
puts

if results[:fail] > 0
  puts '⚠️  WARNINGS:'
  results[:warnings].each { |w| puts "  - #{w}" }
  puts
  puts '❌ Import will have validation errors!'
else
  puts '✨ All templates should import successfully!'
end
