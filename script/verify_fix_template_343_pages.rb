#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to verify and fix template 343 pages structure
# Usage: rails runner script/verify_fix_template_343_pages.rb

template = MessageTemplate.find(343)

puts '=' * 80
puts "🔍 Verifying Pages Structure: #{template.name} (ID: #{template.id})"
puts '=' * 80

metadata = template.metadata
apple_content = metadata['apple_message_content']
content_attrs = apple_content['content_attributes']

puts "\n1️⃣  Checking pages array..."
pages = content_attrs['pages']

if pages.blank?
  puts '   ❌ ERROR: No pages found!'
  exit 1
end

unless pages.is_a?(Array)
  puts "   ❌ ERROR: pages is not an array (#{pages.class})"
  exit 1
end

puts "   ✅ pages is an array with #{pages.length} pages"

puts "\n2️⃣  Checking each page structure..."
pages.each_with_index do |page, idx|
  puts "\n   Page #{idx + 1}:"
  puts "      page_id: #{page['page_id'] || '(missing)'}"
  puts "      title: #{page['title'] || '(missing)'}"
  puts "      description: #{page['description'] || '(none)'}"

  items = page['items']
  if items.blank?
    puts '      ❌ items: MISSING!'
  elsif !items.is_a?(Array)
    puts "      ❌ items: not an array (#{items.class})"
  else
    puts "      ✅ items: #{items.length} items"
    items.each_with_index do |item, item_idx|
      puts "         Item #{item_idx + 1}:"
      puts "            item_id: #{item['item_id'] || '(missing)'}"
      puts "            item_type: #{item['item_type'] || '(missing)'}"
      puts "            title: #{item['title'] || '(missing)'}"

      # Check for options if singleSelect/multiSelect
      next unless %w[singleSelect multiSelect].include?(item['item_type'])

      options = item['options']
      if options.blank?
        puts "            ❌ options: MISSING (required for #{item['item_type']})"
      elsif !options.is_a?(Array)
        puts '            ❌ options: not an array'
      else
        puts "            ✅ options: #{options.length} options"
      end
    end
  end
end

puts "\n3️⃣  Checking SendMessageService conversion..."
# Simulate what convert_form_builder_pages_to_msp does
all_page_items = []
pages.each_with_index do |page, page_index|
  page_id = page['page_id'] || page_index.to_s
  items = page['items'] || []

  items.each_with_index do |item, item_index|
    all_page_items << {
      page_id: "#{page_id}_#{item_index}",
      item: item,
      page: page
    }
  end
end

if all_page_items.empty?
  puts '   ❌ ERROR: No page items collected!'
  puts "   This means pages don't have valid items arrays"
  puts "\n   🔧 Attempting to fix pages structure..."

  # Check if pages structure needs fixing
  needs_fix = false
  pages.each do |page|
    if page['items'].blank? || !page['items'].is_a?(Array)
      needs_fix = true
      break
    end
  end

  if needs_fix
    puts '   ⚠️  Pages need fixing - please check template structure manually'
    puts '   Expected structure:'
    puts '   pages: ['
    puts '     {'
    puts "       page_id: 'guitar_select',"
    puts "       title: 'Select Guitar',"
    puts '       items: ['
    puts "         { item_id: 'guitar_model', item_type: 'singleSelect', ... }"
    puts '       ]'
    puts '     }'
    puts '   ]'
  end
else
  puts "   ✅ Conversion will produce #{all_page_items.length} MSP pages"
  puts "\n   MSP Page IDs:"
  all_page_items.each do |pi|
    puts "      - #{pi[:page_id]} (#{pi[:item]['item_type']})"
  end
end

puts "\n" + ('=' * 80)
puts '💡 DIAGNOSIS:'

if all_page_items.empty?
  puts "   ❌ Pages have no items - this causes 'Form must have at least one page' error"
  puts '   ✅ SOLUTION: Recreate template with correct structure using:'
  puts '      rails runner script/create_guitar_info_form_corrected.rb --account-id 1 --inbox-id 6'
else
  puts '   ✅ Pages structure looks good!'
  puts '   If still failing, check:'
  puts '   1. Remove show_summary from content_attributes (if still causing issues)'
  puts "   2. Ensure 'content' field is set in apple_message_content"
  puts '   3. Check logs for other validation errors'
end

puts '=' * 80
