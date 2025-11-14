#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to fix image identifier mismatch in Guitar List Picker template 321
# Problem: Template uses identifiers ["0", "1", "2", "3"] but ActiveStorage only has ["1", "2", "3", "4"]
# Solution: Remap template to use existing identifiers
# Usage: rails runner script/fix_guitar_list_picker_321_images.rb

puts '=' * 80
puts '🔧 Fixing Guitar List Picker Template 321 Image Identifiers'
puts '=' * 80

template = MessageTemplate.find(321)
puts "\n📋 Template: #{template.name} (ID: #{template.id})"

# Get current template structure
metadata = template.metadata.deep_dup
template_attrs = metadata['apple_message_content']['content_attributes']
list_picker_data = template_attrs['list_picker']
sections = list_picker_data['sections']
received_message = template_attrs['received_message']
reply_message = template_attrs['reply_message']

puts "\n🔍 Current State:"
puts "   Sections: #{sections.count}"

# Collect current image identifiers
current_item_ids = sections.flat_map do |section|
  (section['items'] || []).map { |item| item['image_identifier'] }
end.compact.uniq

puts "   Current item image identifiers: #{current_item_ids.inspect}"
puts "   Current receivedMessage image: #{received_message['image_identifier'].inspect}"
puts "   Current replyMessage image: #{reply_message['image_identifier'].inspect}"

# Check what exists in ActiveStorage
inbox = Inbox.where(account_id: template.account_id, channel_type: 'Channel::AppleMessagesForBusiness').first
existing_images = AppleListPickerImage.where(inbox_id: inbox.id)
existing_ids = existing_images.pluck(:identifier)

puts "\n💾 ActiveStorage has: #{existing_ids.inspect}"

# Define mapping from old identifiers to new identifiers
# If template uses ["0", "1", "2", "3"] and ActiveStorage has ["1", "2", "3", "4"]
# We need to remap "0" → "1" (duplicate first guitar image)
# OR better: check which identifier is actually missing and adjust accordingly

missing_ids = current_item_ids - existing_ids
puts "\n⚠️  Missing identifiers: #{missing_ids.inspect}"

if missing_ids.empty?
  puts '✅ No missing identifiers - all template images exist in ActiveStorage'
  exit 0
end

# Since "0" is missing, let's remap it to "1" (use first guitar's image twice)
# Or you can choose a different strategy
identifier_mapping = {
  '0' => '1'  # Map missing "0" to existing "1"
}

puts "\n🔄 Applying Mapping:"
puts "   #{identifier_mapping.inspect}"

# Update sections
sections.each do |section|
  section['items'].each do |item|
    old_id = item['image_identifier']
    next unless identifier_mapping.key?(old_id)

    new_id = identifier_mapping[old_id]
    puts "   Remapping item '#{item['title']}': #{old_id.inspect} → #{new_id.inspect}"
    item['image_identifier'] = new_id
  end
end

# Update receivedMessage if needed
if identifier_mapping.key?(received_message['image_identifier'])
  old_id = received_message['image_identifier']
  new_id = identifier_mapping[old_id]
  puts "   Remapping receivedMessage: #{old_id.inspect} → #{new_id.inspect}"
  received_message['image_identifier'] = new_id
end

# Update replyMessage if needed
if identifier_mapping.key?(reply_message['image_identifier'])
  old_id = reply_message['image_identifier']
  new_id = identifier_mapping[old_id]
  puts "   Remapping replyMessage: #{old_id.inspect} → #{new_id.inspect}"
  reply_message['image_identifier'] = new_id
end

# Save updated template
puts "\n💾 Saving updated template..."
template.update!(metadata: metadata)

puts "\n✅ Template updated successfully!"

# Verify new state
new_item_ids = sections.flat_map do |section|
  (section['items'] || []).map { |item| item['image_identifier'] }
end.compact.uniq

puts "\n📊 New State:"
puts "   New item image identifiers: #{new_item_ids.inspect}"
puts "   New receivedMessage image: #{received_message['image_identifier'].inspect}"
puts "   New replyMessage image: #{reply_message['image_identifier'].inspect}"

all_new_ids = (new_item_ids + [received_message['image_identifier'], reply_message['image_identifier']]).compact.uniq
missing_after_fix = all_new_ids - existing_ids

if missing_after_fix.empty?
  puts "\n✅ SUCCESS: All template identifiers now exist in ActiveStorage!"
else
  puts "\n⚠️  Still missing: #{missing_after_fix.inspect}"
  puts '   You may need to adjust the mapping or upload missing images'
end

puts '=' * 80
