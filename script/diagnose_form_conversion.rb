#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to diagnose form conversion issue
# Usage: rails runner script/diagnose_form_conversion.rb

template = MessageTemplate.find(343)

puts '=' * 80
puts "🔍 Diagnosing Form Conversion: #{template.name} (ID: #{template.id})"
puts '=' * 80

metadata = template.metadata
apple_content = metadata['apple_message_content']
content_attrs = apple_content['content_attributes']

puts "\n1️⃣  Checking pages structure..."
pages = content_attrs['pages']

if pages.blank?
  puts '   ❌ ERROR: No pages found!'
  exit 1
end

puts "   ✅ Pages array has #{pages.length} pages"

puts "\n2️⃣  Analyzing items in each page..."
all_items = []
pages.each_with_index do |page, page_idx|
  puts "\n   Page #{page_idx + 1}: #{page['title']}"
  items = page['items'] || []

  items.each_with_index do |item, item_idx|
    puts "      Item #{item_idx + 1}:"
    puts "         item_type: #{item['item_type']}"
    puts "         title: #{item['title']}"

    all_items << {
      page_index: page_idx,
      item_index: item_idx,
      item_type: item['item_type'],
      title: item['title']
    }

    # Check for picker_type
    puts "         picker_type: #{item['picker_type']}" if item['picker_type'].present?
  end
end

puts "\n3️⃣  Checking which items will be converted..."
supported_types = %w[text textArea email phone singleSelect multiSelect dateTime toggle]
unsupported_items = all_items.reject { |item| supported_types.include?(item[:item_type]) }

if unsupported_items.any?
  puts '   ❌ FOUND UNSUPPORTED ITEM TYPES:'
  unsupported_items.each do |item|
    puts "      Page #{item[:page_index] + 1}, Item #{item[:item_index] + 1}:"
    puts "         Type: #{item[:item_type]} (NOT SUPPORTED)"
    puts "         Title: #{item[:title]}"
  end

  puts "\n   ⚠️  These items will be SKIPPED during conversion!"
  puts "   This is likely causing the 'Form must have at least one page' error."
else
  puts '   ✅ All items use supported types'
end

puts "\n4️⃣  Supported item types in SendMessageService:"
puts '      - text'
puts '      - textArea'
puts '      - email'
puts '      - phone'
puts '      - singleSelect'
puts '      - multiSelect'
puts '      - dateTime'
puts '      - toggle'

puts "\n" + ('=' * 80)
puts '💡 DIAGNOSIS:'
puts '=' * 80

if unsupported_items.any?
  puts '   ❌ PROBLEM FOUND:'
  puts "   The template uses 'picker' item_type, but SendMessageService"
  puts "   doesn't have a handler for it in build_msp_page_from_item method."
  puts
  puts "   When conversion encounters 'picker', it returns nil, which is skipped."
  puts '   If enough items are skipped, pages array becomes empty.'
  puts
  puts '   🔧 SOLUTIONS:'
  puts "   1. Change 'picker' to 'dateTime' in template (quick fix)"
  puts "   2. Add 'picker' handler to SendMessageService (proper fix)"
else
  puts '   ✅ No obvious issues found with item types'
  puts '   The error might be in the conversion logic itself'
end

puts '=' * 80
