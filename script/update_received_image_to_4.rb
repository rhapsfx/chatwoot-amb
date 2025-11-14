#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to update template 321 receivedMessage to use identifier "4"
# Usage: rails runner script/update_received_image_to_4.rb

puts '=' * 80
puts '🔧 Updating Guitar List Picker receivedMessage to use identifier "4"'
puts '=' * 80

template = MessageTemplate.find(321)
metadata = template.metadata.deep_dup

# Update receivedMessage to use identifier "4"
received_msg = metadata.dig('apple_message_content', 'content_attributes', 'received_message')
old_identifier = received_msg['image_identifier']
new_identifier = '4'

puts "\n📋 Changing receivedMessage image_identifier:"
puts "   From: #{old_identifier.inspect}"
puts "   To: #{new_identifier.inspect}"

received_msg['image_identifier'] = new_identifier

# Save
template.update!(metadata: metadata)

puts "\n✅ Template updated successfully!"
puts '=' * 80
