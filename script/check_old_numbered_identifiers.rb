#!/usr/bin/env ruby
# frozen_string_literal: true

# Check if old numbered identifiers 1-13 still exist in SharedAppleImage

puts '=' * 80
puts 'Check Old Numbered Identifiers (1-13) in SharedAppleImage'
puts '=' * 80
puts ''

old_identifiers = %w[1 2 3 4 5 6 7 8 9 10 11 12 13]

old_images = SharedAppleImage.where(account_id: 1, identifier: old_identifiers)
                             .includes(image_attachment: :blob)

puts "Found #{old_images.count} SharedAppleImage records with identifiers 1-13"

if old_images.any?
  puts ''
  puts '❌ PROBLEM FOUND: Old numbered identifiers still exist!'
  puts ''

  old_images.order(:identifier).each do |img|
    if img.image.attached?
      size_kb = (img.image.byte_size / 1024.0).round(2)
      puts "  #{img.identifier}: #{size_kb} KB - #{img.description}"
    else
      puts "  #{img.identifier}: No attachment"
    end
  end

  puts ''
  puts 'These old identifiers have GUITAR images attached!'
  puts "Even though template was updated to use 'summary_*' identifiers,"
  puts "something might still be referencing the old '1', '2', '3' identifiers."
  puts ''
  puts 'Solution: Delete or rename these old SharedAppleImage records'
else
  puts ''
  puts '✅ No old numbered identifiers found in SharedAppleImage'
  puts '   This is correct - template should use summary_ identifiers'
end

puts ''
puts '=' * 80
puts 'Checking Template 355 Current State'
puts '=' * 80
puts ''

template = MessageTemplate.find(355)
block = template.content_blocks.find_by(block_type: 'list_picker')

if block
  sections = block.properties['sections'] || []
  puts 'Template 355 items currently use these identifiers:'
  sections.each do |section|
    items = section['items'] || []
    items.first(3).each do |item|
      puts "  #{item['title']}: #{item['image_identifier']}"
    end
  end
else
  puts '❌ No list_picker block found'
end

puts '=' * 80
