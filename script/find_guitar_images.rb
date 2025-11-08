#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to find all guitar form images in database
# Usage: rails runner script/find_guitar_images.rb

puts '=' * 80
puts '🔍 Searching for Guitar Form Images'
puts '=' * 80

# Find images with guitar-related identifiers or names
guitar_images = AppleListPickerImage.where('identifier LIKE ? OR identifier LIKE ? OR original_name LIKE ?',
                                           'guitar%', '%gibson%', '%guitar%')
                                    .or(AppleListPickerImage.where('original_name LIKE ? OR original_name LIKE ? OR original_name LIKE ?',
                                                                   '%gibson%', '%martin%', '%paul_reed%'))

puts "\n1️⃣  Found #{guitar_images.count} guitar-related image(s):"

guitar_images.each do |img|
  puts "\n   Image ID: #{img.id}"
  puts "      identifier: #{img.identifier}"
  puts "      inbox_id: #{img.inbox_id}"
  puts "      account_id: #{img.account_id}"
  puts "      original_name: #{img.original_name}"
  puts "      has attachment: #{img.image.attached? ? '✅' : '❌'}"

  puts "      inbox: #{img.inbox.name} (ID: #{img.inbox.id})" if img.inbox
end

puts "\n2️⃣  All AppleListPickerImage records:"
all_images = AppleListPickerImage.all
puts "   Total: #{all_images.count}"

all_images.each do |img|
  puts "\n   Image ID: #{img.id}"
  puts "      identifier: #{img.identifier}"
  puts "      inbox_id: #{img.inbox_id}"
  puts "      original_name: #{img.original_name}"
  puts "      has attachment: #{img.image.attached? ? '✅' : '❌'}"
end

puts "\n3️⃣  Template 343 info:"
template = MessageTemplate.find(343)
puts "   Template inbox associations: #{template.supported_channels.inspect}"
puts "   Template account: #{template.account.name} (ID: #{template.account_id})"

puts "\n4️⃣  Apple Messages inboxes in account:"
inboxes = Inbox.where(account_id: template.account_id, channel_type: 'Channel::AppleMessagesForBusiness')
puts "   Found #{inboxes.count} Apple Messages inbox(es):"

inboxes.each do |inbox|
  puts "\n   Inbox: #{inbox.name} (ID: #{inbox.id})"
  images_in_inbox = AppleListPickerImage.where(inbox_id: inbox.id).count
  puts "      Images: #{images_in_inbox}"
end

puts "\n" + ('=' * 80)
puts '💡 ACTION NEEDED:'
puts '=' * 80
puts "The images (56, 57, 58, 59) don't exist in the database."
puts 'You need to run the image upload script for the CORRECT inbox.'
puts "\nOptions:"
puts '1. Delete template 343 and recreate with correct inbox using:'
puts "   rails runner script/create_guitar_info_form_corrected.rb --account-id #{template.account_id} --inbox-id <CORRECT_INBOX_ID>"
puts "\n2. Or upload images to the correct inbox manually"
puts '=' * 80
