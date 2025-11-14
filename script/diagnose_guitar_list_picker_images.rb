#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to diagnose image identifier mismatches for Guitar List Picker template 321
# Usage: rails runner script/diagnose_guitar_list_picker_images.rb

puts '=' * 80
puts '🔍 Diagnosing Guitar List Picker Template 321 Images'
puts '=' * 80

template = MessageTemplate.find(321)
puts "\n📋 Template Info:"
puts "   Name: #{template.name}"
puts "   Account: #{template.account.name} (ID: #{template.account_id})"

# Extract image identifiers from template
template_attrs = template.metadata.dig('apple_message_content', 'content_attributes') || {}
list_picker_data = template_attrs['list_picker'] || {}
sections = list_picker_data['sections'] || []
received_message = template_attrs['received_message'] || {}
reply_message = template_attrs['reply_message'] || {}

puts "\n🎸 Template Image Identifiers:"

# Collect item image identifiers
item_image_ids = sections.flat_map do |section|
  (section['items'] || []).map { |item| item['image_identifier'] }
end.compact

puts "   Item images: #{item_image_ids.inspect}"
puts "   receivedMessage image: #{received_message['image_identifier'].inspect}"
puts "   replyMessage image: #{reply_message['image_identifier'].inspect}"

all_template_ids = (item_image_ids + [received_message['image_identifier'], reply_message['image_identifier']]).compact.uniq
puts "   ALL template identifiers: #{all_template_ids.inspect}"

# Map items to their images
puts "\n🎯 Item → Image Mapping:"
sections.each_with_index do |section, s_idx|
  puts "   Section #{s_idx}: #{section['title']}"
  section['items'].each_with_index do |item, i_idx|
    puts "      Item #{i_idx}: #{item['title']} → image_identifier: #{item['image_identifier'].inspect}"
  end
end

# Check what exists in ActiveStorage
puts "\n💾 ActiveStorage Status:"
inboxes = Inbox.where(account_id: template.account_id, channel_type: 'Channel::AppleMessagesForBusiness')
puts "   Found #{inboxes.count} Apple Messages inbox(es):"

inboxes.each do |inbox|
  puts "\n   📥 Inbox: #{inbox.name} (ID: #{inbox.id})"

  # Find all images for this inbox
  all_images = AppleListPickerImage.where(inbox_id: inbox.id)
  puts "      Total images: #{all_images.count}"

  all_images.each do |img|
    has_attachment = img.image.attached? ? '✅' : '❌'
    puts "      - identifier: #{img.identifier.inspect}, name: #{img.original_name}, attached: #{has_attachment}"
  end

  # Check for missing identifiers
  existing_ids = all_images.pluck(:identifier)
  missing_ids = all_template_ids - existing_ids
  extra_ids = existing_ids - all_template_ids

  puts "\n      ⚠️  Missing identifiers: #{missing_ids.inspect}" if missing_ids.any?
  puts "      ℹ️  Extra identifiers (not in template): #{extra_ids.inspect}" if extra_ids.any?
end

puts "\n" + ('=' * 80)
puts '💡 DIAGNOSIS:'
puts '=' * 80

missing_ids = all_template_ids - AppleListPickerImage.where(
  inbox_id: inboxes.pluck(:id),
  identifier: all_template_ids
).pluck(:identifier)

if missing_ids.any?
  puts "❌ PROBLEM: Template expects identifiers #{all_template_ids.inspect}"
  puts "   but #{missing_ids.inspect} are missing from ActiveStorage"
  puts "\n   SOLUTION OPTIONS:"
  puts '   1. Update template to use only existing identifiers'
  puts '   2. Create AppleListPickerImage records for missing identifiers'
  puts '   3. Upload missing images to ActiveStorage'
else
  puts '✅ All template image identifiers exist in ActiveStorage'
end

puts '=' * 80
