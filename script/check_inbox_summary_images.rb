#!/usr/bin/env ruby
# frozen_string_literal: true

# Check for inbox-specific images with summary_ identifiers

puts '=' * 80
puts 'Check for Inbox-Specific Summary Images'
puts '=' * 80
puts ''

summary_identifiers = %w[
  summary_apple_pay
  summary_apple_wallet
  summary_ar_experience
  summary_authentication
  summary_file_sharing
  summary_imessage_apps
  summary_list_picker
  summary_media_sharing
  summary_qr_code_origination
  summary_quick_type_keyboard
  summary_rich_link_locator
  summary_rich_website_links
  summary_time_picker
]

inbox_images = AppleListPickerImage.where(identifier: summary_identifiers)
                                   .includes(image_attachment: :blob)

puts "Found #{inbox_images.count} inbox-specific images with summary_ identifiers"

if inbox_images.any?
  puts ''
  puts '❌ PROBLEM FOUND: Inbox-specific duplicates exist!'
  puts ''

  inbox_images.group_by(&:inbox_id).each do |inbox_id, images|
    puts "Inbox #{inbox_id}:"
    images.each do |img|
      size_kb = img.image.attached? ? (img.image.byte_size / 1024.0).round(2) : 0
      puts "  #{img.identifier}: #{size_kb} KB - #{img.description}"
    end
    puts ''
  end

  puts 'These inbox-specific images are blocking SharedAppleImage!'
  puts 'ImageFetchService finds tier-1 (inbox) before tier-2 (shared).'
  puts ''
  puts 'Solution: Delete these inbox-specific duplicates'
else
  puts ''
  puts '✅ No inbox-specific images found for summary_ identifiers'
  puts '   This is correct - should only use SharedAppleImage'
end

puts '=' * 80
