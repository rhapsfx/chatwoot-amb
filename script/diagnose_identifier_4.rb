#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to diagnose what image is stored under identifier "4"
# Usage: rails runner script/diagnose_identifier_4.rb

puts '=' * 80
puts '🔍 Diagnosing Identifier "4" in Inbox 4'
puts '=' * 80

inbox_id = 4
identifier = '4'

# Find the image
image = AppleListPickerImage.find_by(inbox_id: inbox_id, identifier: identifier)

if image
  puts "\n✅ Found image with identifier '4':"
  puts "   ID: #{image.id}"
  puts "   Original name: #{image.original_name}"
  puts "   Description: #{image.description}"
  puts "   Image attached: #{image.image.attached? ? '✅' : '❌'}"

  if image.image.attached?
    puts "   Filename: #{image.image.filename}"
    puts "   Content type: #{image.image.content_type}"
    puts "   Size: #{(image.image.byte_size / 1024.0).round(2)} KB"
  end
else
  puts "\n❌ No image found with identifier '4' in inbox #{inbox_id}"
end

puts "\n" + ('=' * 80)
puts '📋 All Images in Inbox 4:'
puts '=' * 80

all_images = AppleListPickerImage.where(inbox_id: inbox_id).order(:identifier)
all_images.each do |img|
  status = img.image.attached? ? '✅' : '❌'
  puts "   #{img.identifier}: #{img.original_name} #{status}"
end

puts "\n" + ('=' * 80)
puts '📋 Template 321 Configuration:'
puts '=' * 80

template = MessageTemplate.find(321)
received_msg = template.metadata.dig('apple_message_content', 'content_attributes', 'received_message')

puts "   receivedMessage.image_identifier: #{received_msg['image_identifier'].inspect}"
puts "   receivedMessage.title: #{received_msg['title']}"

puts '=' * 80
