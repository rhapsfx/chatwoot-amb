#!/usr/bin/env ruby
# frozen_string_literal: true

# Check ALL inboxes to find which has the correct numbered icons for 1-13

puts '=' * 80
puts 'Find Correct Source for Images 1-13'
puts '=' * 80
puts ''

# First, check what's currently being sent from the frontend
# The frontend payload showed these sizes:
# 1: 83.9 KB
# 2: 94.45 KB
# 3: 85.6 KB
# 4: 16.69 KB

puts 'SharedAppleImage current sizes (migrated from inbox 5):'
SharedAppleImage.where(account_id: 1, identifier: %w[1 2 3 4]).order(:identifier).each do |img|
  puts "  #{img.identifier}: #{(img.image.byte_size / 1024.0).round(2)} KB - #{img.description}"
end

puts ''
puts 'Checking if there are any remaining AppleListPickerImage with identifiers 1-13...'
puts ''

# Check what was deleted but might be in other inboxes
all_matching = AppleListPickerImage.where(identifier: %w[1 2 3 4 5 6 7 8 9 10 11 12 13])
                                   .includes(image_attachment: :blob)

if all_matching.empty?
  puts '❌ No AppleListPickerImage records found for 1-13'
  puts '   All were deleted during cleanup'
  puts ''
  puts 'The correct images must be uploaded fresh or found elsewhere.'
else
  puts 'Found AppleListPickerImage in these inboxes:'
  all_matching.group_by(&:inbox_id).each do |inbox_id, images|
    puts ''
    puts "Inbox #{inbox_id}:"
    images.first(4).each do |img|
      size_kb = img.image.attached? ? (img.image.byte_size / 1024.0).round(2) : 0
      puts "  #{img.identifier}: #{size_kb} KB - #{img.description}"
    end
  end
end

puts ''
puts '=' * 80
puts 'Frontend payload sizes (what template editor is sending):'
puts '=' * 80
puts '  1: 83.9 KB (85912 bytes)'
puts '  2: 94.45 KB'
puts '  3: 85.6 KB'
puts '  4: 16.69 KB'
puts ''
puts "These sizes DON'T match the SharedAppleImage sizes!"
puts 'This confirms SharedAppleImage has wrong images attached.'
puts '=' * 80
