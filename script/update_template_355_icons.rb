#!/usr/bin/env ruby
# frozen_string_literal: true

# Update template 355 to use feature-specific icons instead of generic numbers

puts '=' * 80
puts 'Update Template 355 to Use Feature-Specific Icons'
puts '=' * 80
puts ''

# Check both ARGV and ENV for DRY_RUN parameter
dry_run_from_argv = ARGV.any? { |arg| arg == 'DRY_RUN=false' || arg == '--execute' }
dry_run_from_env = ENV['DRY_RUN'] == 'false'
DRY_RUN = !(dry_run_from_argv || dry_run_from_env)

puts "Mode: #{DRY_RUN ? 'DRY RUN (preview only)' : 'EXECUTE (will update template)'}"
puts ''

# Mapping of items to correct icon identifiers
ICON_MAPPING = {
  'Apple Pay' => 'apple_pay_mark_3',
  'Apple Wallet' => 'wallet_circle_20',
  'AR Experience' => 'arkit_512_5',
  'Authentication' => 'auth_circle_23',
  'File Sharing' => 'doc_circle_24',
  'iMessage Apps' => 'app_circle_27',
  'List Picker' => 'list_bullet_512_12',
  'Media Sharing' => 'image_circle_25',
  'QR Code' => 'codescanner_1024_11',
  'Quick Type' => 'keyboard_1024_8',
  'Rich Link Locator' => 'map_circle_21',
  'Rich Links' => 'safari_1024x1024_2x_7',
  'Time Picker' => 'calendar_circle_19'
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

puts 'Current item image identifiers:'
sections.each_with_index do |section, _s_idx|
  items = section['items'] || []
  items.each_with_index do |item, _i_idx|
    current_id = item['image_identifier'] || item['imageIdentifier']
    new_id = ICON_MAPPING[item['title']]
    status = new_id ? '→' : '⚠️'
    puts "  #{item['title'].ljust(25)} #{current_id.to_s.ljust(20)} #{status} #{new_id || 'NO MAPPING'}"
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
    new_identifier = ICON_MAPPING[title]

    if new_identifier
      old_identifier = item['image_identifier']
      item['image_identifier'] = new_identifier

      puts "  ✅ #{title}: #{old_identifier} → #{new_identifier}"
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
  puts 'To execute, run: rails runner script/update_template_355_icons.rb DRY_RUN=false'
else
  puts '✅ Update complete!'
  puts ''
  puts 'Template 355 now uses feature-specific icons:'
  ICON_MAPPING.each do |title, icon|
    puts "  - #{title.ljust(25)} → #{icon}"
  end
  puts ''
  puts 'Next: Send template 355 and verify correct icons appear!'
end

puts '=' * 80
