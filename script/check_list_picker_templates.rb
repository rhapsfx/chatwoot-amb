#!/usr/bin/env ruby
# frozen_string_literal: true

# Check how list picker templates are stored in database

puts '=== Checking List Picker Templates ==='
puts

# Find all templates with list picker content
templates = MessageTemplate.where("metadata -> 'apple_message_content' -> 'content_attributes' -> 'list_picker' IS NOT NULL")
                           .or(MessageTemplate.where("metadata -> 'apple_message_content' -> 'content_attributes' -> 'sections' IS NOT NULL"))

puts "Found #{templates.count} list picker templates"
puts

templates.each do |template|
  puts '─' * 80
  puts "Template ID: #{template.id}"
  puts "Name: #{template.name}"
  puts

  content_attrs = template.metadata&.dig('apple_message_content', 'content_attributes') || {}

  # Check format
  if content_attrs['sections'].present?
    puts '✓ Storage Format: FLAT (sections at top level)'
    sections = content_attrs['sections']
  elsif content_attrs['list_picker'].present?
    puts '✓ Storage Format: NESTED (sections in list_picker)'
    sections = content_attrs.dig('list_picker', 'sections')
  else
    puts '⚠️ ERROR: No sections found!'
    next
  end

  puts "Sections count: #{sections.length}"
  puts

  sections.each_with_index do |section, idx|
    puts "  Section #{idx + 1}: #{section['title']}"

    # Check for both camelCase and snake_case
    has_camel = section.key?('multipleSelection')
    has_snake = section.key?('multiple_selection')

    camel_value = section['multipleSelection']
    snake_value = section['multiple_selection']

    puts "    ├─ Has 'multipleSelection' (camelCase): #{has_camel ? "YES (value: #{camel_value.inspect})" : 'NO'}"
    puts "    ├─ Has 'multiple_selection' (snake_case): #{has_snake ? "YES (value: #{snake_value.inspect})" : 'NO'}"

    if has_camel && !has_snake
      puts '    └─ ❌ ISSUE: Only camelCase exists (not normalized)'
    elsif !has_camel && has_snake
      puts '    └─ ✅ CORRECT: Only snake_case exists (properly normalized)'
    elsif has_camel && has_snake
      puts '    └─ ⚠️ WARNING: Both cases exist (data inconsistency)'
    else
      puts '    └─ ❌ ERROR: Neither case exists (missing field)'
    end
    puts
  end
  puts
end

puts '=== End of Check ==='
