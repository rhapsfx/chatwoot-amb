#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify image extraction from migration files
# Usage: ruby scripts/test_image_extraction.rb

require 'json'

business_name = 'acoustic_house'
migration_file = File.join('tmp', 'bot_migration', business_name, 'migration_data_FILTERED.json')

unless File.exist?(migration_file)
  puts "Error: Migration file not found: #{migration_file}"
  exit 1
end

data = JSON.parse(File.read(migration_file))

puts '🧪 Testing Image Extraction'
puts '=' * 80
puts "Business: #{business_name}"
puts "Templates: #{data['payloads'].size}"
puts

# Test image extraction logic
data['payloads'].each do |payload|
  template_data = payload['template']
  content_type = template_data['content_type']
  content_attrs = template_data['content_attributes'] || {}

  # Detect actual type
  if content_type == 'text' && !content_attrs.empty?
    content_type = 'apple_list_picker' if content_attrs['list_picker']
    content_type = 'apple_time_picker' if content_attrs['time_picker']
  end

  # Only check list_picker and time_picker
  next unless /list_picker|time_picker/.match?(content_type)

  name = payload['original_file']

  # Extract images using the same logic as import script
  images_data = payload.dig('original_payload', 'data', 'images') || []
  images_array = images_data.map do |img|
    base64_data = img['data']
    {
      'identifier' => img['identifier'],
      'data' => base64_data,
      'preview' => base64_data ? "data:image/png;base64,#{base64_data}" : nil,
      'description' => "Migrated image #{img['identifier']}",
      'originalName' => "image_#{img['identifier']}.png",
      'size' => base64_data ? (base64_data.length * 0.75).to_i : 0
    }.compact
  end.compact

  puts "📄 #{name} (#{content_type})"
  puts "   Images found: #{images_array.size}"

  if images_array.any?
    images_array.each do |img|
      data_preview = img['data'] ? "#{img['data'][0..20]}..." : 'nil'
      preview_preview = img['preview'] ? "#{img['preview'][0..40]}..." : 'nil'
      puts "   - ID: #{img['identifier']}"
      puts "     Name: #{img['originalName']}"
      puts "     Size: #{img['size']} bytes"
      puts "     Data: #{data_preview}"
      puts "     Preview: #{preview_preview}"
      puts
    end
  else
    puts '   ⚠️  No images extracted'
  end
  puts
end

puts '=' * 80
puts '✨ Test complete!'
