#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to diagnose list picker multiple_selection storage issue

puts '=== List Picker Multiple Selection Diagnostic ==='
puts

# Find list picker templates
templates = MessageTemplate.where("'apple_messages_for_business' = ANY(supported_channels)")
                           .where.not(metadata: nil)

list_picker_templates = templates.select do |t|
  content = t.metadata&.dig('apple_message_content', 'content_attributes')
  content && (content['sections'].present? || content['list_picker'].present?)
end

puts "Found #{list_picker_templates.count} list picker templates"
puts

list_picker_templates.each do |template|
  puts '─' * 80
  puts "Template ID: #{template.id}"
  puts "Template Name: #{template.name}"
  puts

  content_attrs = template.metadata&.dig('apple_message_content', 'content_attributes')

  # Check if it's in flat format or nested format
  if content_attrs['sections'].present?
    puts '✓ Storage Format: FLAT (new format)'
    sections = content_attrs['sections']
  elsif content_attrs['list_picker'].present?
    puts '✓ Storage Format: NESTED (old format)'
    sections = content_attrs['list_picker']['sections']
  else
    puts '⚠ ERROR: No sections found!'
    next
  end

  puts "Number of sections: #{sections.length}"
  puts

  sections.each_with_index do |section, idx|
    puts "  Section #{idx + 1}: #{section['title']}"

    # Check for multiple_selection in both formats
    ms_snake = section['multiple_selection']
    ms_camel = section['multipleSelection']

    puts "    ├─ multiple_selection (snake_case): #{ms_snake.inspect}"
    puts "    ├─ multipleSelection (camelCase): #{ms_camel.inspect}"

    if ms_snake.present?
      puts "    └─ ✓ Value found in snake_case: #{ms_snake}"
    elsif ms_camel.present?
      puts "    └─ ⚠ Value found in camelCase (should be snake_case): #{ms_camel}"
    else
      puts '    └─ ✗ No multiple_selection value found (defaulting to false)'
    end
    puts
  end

  puts
end

puts '=== End of Diagnostic ==='
