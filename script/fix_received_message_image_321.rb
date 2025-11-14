#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to update template 321's receivedMessage to use a different image identifier
# Problem: receivedMessage uses identifier "4" but shows wrong image
# Solution: Update template to use an identifier that has the correct header image
# Usage: rails runner script/fix_received_message_image_321.rb

puts '=' * 80
puts '🔧 Fixing Guitar List Picker receivedMessage Image'
puts '=' * 80

template = MessageTemplate.find(321)
metadata = template.metadata.deep_dup

# Current receivedMessage configuration
received_msg = metadata.dig('apple_message_content', 'content_attributes', 'received_message')
current_identifier = received_msg['image_identifier']

puts "\n📋 Current receivedMessage configuration:"
puts "   Image identifier: #{current_identifier.inspect}"
puts "   Title: #{received_msg['title']}"
puts "   Subtitle: #{received_msg['subtitle']}"

# Option 1: Use one of the aha19 identifiers which are header/summary images
# From diagnostic: inbox 4 has "aha19_0" through "aha19_13"
# "aha19_0" is typically the header image

new_identifier = 'aha19_0'

puts "\n🔄 Updating to use identifier: #{new_identifier.inspect}"
puts '   (This is typically the header/banner image)'

# Update the template
received_msg['image_identifier'] = new_identifier

# Save
template.update!(metadata: metadata)

puts "\n✅ Template updated successfully!"
puts "\n📊 New receivedMessage configuration:"
puts "   Image identifier: #{received_msg['image_identifier'].inspect}"
puts "   Title: #{received_msg['title']}"

# Verify the image exists
inbox = Inbox.where(account_id: template.account_id, channel_type: 'Channel::AppleMessagesForBusiness').first
image = AppleListPickerImage.find_by(inbox_id: inbox.id, identifier: new_identifier)

if image&.image&.attached?
  puts "\n✅ Image exists in ActiveStorage: #{image.original_name}"
else
  puts "\n⚠️  WARNING: Image identifier '#{new_identifier}' not found in ActiveStorage!"
  puts '   You may need to upload this image or choose a different identifier'
end

puts '=' * 80
