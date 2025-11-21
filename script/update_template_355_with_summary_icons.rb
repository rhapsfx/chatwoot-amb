#!/usr/bin/env ruby
# frozen_string_literal: true

# Update template 355 to use summary image identifiers

puts '=' * 80
puts 'Update Template 355 with Summary Image Identifiers'
puts '=' * 80
puts ''

# Check both ARGV and ENV for DRY_RUN parameter
dry_run_from_argv = ARGV.any? { |arg| arg == 'DRY_RUN=false' || arg == '--execute' }
dry_run_from_env = ENV['DRY_RUN'] == 'false'
DRY_RUN = !(dry_run_from_argv || dry_run_from_env)

puts "Mode: #{DRY_RUN ? 'DRY RUN (preview only)' : 'EXECUTE (will update template)'}"
puts ''

# Mapping of template items to new identifiers
IDENTIFIER_MAPPING = {
  'Apple Pay' => 'summary_apple_pay',
  'Apple Wallet' => 'summary_apple_wallet',
  'AR Experience' => 'summary_ar_experience',
  'Authentication' => 'summary_authentication',
  'File Sharing' => 'summary_file_sharing',
  'iMessage Apps' => 'summary_imessage_apps',
  'List Picker' => 'summary_list_picker',
  'Media Sharing' => 'summary_media_sharing',
  'QR Code' => 'summary_qr_code_origination',
  'Quick Type' => 'summary_quick_type_keyboard',
  'Rich Link Locator' => 'summary_rich_link_locator',
  'Rich Links' => 'summary_rich_website_links',
  'Time Picker' => 'summary_time_picker'
}.freeze

# Get template 355
template = MessageTemplate.find(355)
puts "Template: #{template.name}"
puts ''

# Get content blocks
block = template.content_blocks.find_by(block_type: 'list_picker')

unless block
  puts '❌ No list_picker block found in template 355'
  exit 1
end

sections = block.properties['sections'] || []

if sections.empty?
  puts '❌ No sections found in template'
  exit 1
end

puts 'Item image identifier updates:'
sections.each do |section|
  items = section['items'] || []
  items.each do |item|
    current_id = item['image_identifier'] || item['imageIdentifier']
    new_id = IDENTIFIER_MAPPING[item['title']]
    if new_id
      puts "  #{item['title'].ljust(25)} #{current_id.to_s.ljust(25)} → #{new_id}"
    else
      puts "  ⚠️  #{item['title']}: No mapping found"
    end
  end
end

puts ''
puts '=' * 80
puts 'Updating Template'
puts '=' * 80
puts ''

updated_count = 0

sections.each do |section|
  items = section['items'] || []

  items.each do |item|
    title = item['title']
    new_identifier = IDENTIFIER_MAPPING[title]

    if new_identifier
      item['image_identifier']
      item['image_identifier'] = new_identifier

      puts "  ✅ #{title}"
      updated_count += 1
    else
      puts "  ⚠️  #{title}: No mapping found, keeping current identifier"
    end
  end
end

unless DRY_RUN
  # Save updated properties
  block.properties = { 'sections' => sections }
  block.save!

  puts ''
  puts '✅ Template updated successfully!'
end

puts ''
puts '=' * 80
puts 'Summary'
puts '=' * 80
puts "  #{DRY_RUN ? 'Would update' : 'Updated'}: #{updated_count} items"
puts ''

if DRY_RUN
  puts '🔍 This was a DRY RUN - no changes were made.'
  puts 'To execute, run: rails runner script/update_template_355_with_summary_icons.rb DRY_RUN=false'
else
  puts '✅ Update complete!'
  puts ''
  puts 'Template 355 now uses summary image identifiers.'
  puts 'Next: Send template 355 and verify correct summary icons appear!'
end

puts '=' * 80
