# frozen_string_literal: true

# Find images across ALL inboxes to locate the menu icons
# Run with: rails runner script/find_menu_icons_all_inboxes.rb

puts '=' * 80
puts 'Find Menu Icon Images Across All Inboxes'
puts '=' * 80
puts ''

# Search for images with recognizable filenames across all inboxes
target_filenames = [
  'list.bullet-512.png',
  'ARKit-512.png',
  'Apple_Pay_Mark.svg',
  'Calendar-1024×1024@2x.png',
  'Photos_512×512@2x.png',
  'Preview_512×512@2x.png',
  'FaceID@3x.png',
  'AppStore-1024.png',
  'Wallet-1024.png',
  'Maps_512×512@2x.png',
  'Messages.png'
]

puts 'Searching for target filenames across all inboxes...'
puts ''

# Get all AppleListPickerImage records
all_images = AppleListPickerImage.includes(:inbox, image_attachment: :blob).all

puts "Total AppleListPickerImage records: #{all_images.count}"
puts ''

# Group by inbox
by_inbox = all_images.group_by(&:inbox_id)

puts 'Images distributed across inboxes:'
by_inbox.each do |inbox_id, images|
  inbox = images.first.inbox
  puts "  Inbox #{inbox_id} (#{inbox.name}): #{images.count} images"
end
puts ''

puts '=' * 80
puts 'SEARCHING FOR MENU ICON FILENAMES'
puts '=' * 80
puts ''

found_images = {}

all_images.each do |img|
  next unless img.image.attached?

  blob = img.image.blob
  blob_filename = blob.filename.to_s

  # Check if this matches any target filename
  next unless target_filenames.include?(blob_filename)

  found_images[blob_filename] ||= []
  found_images[blob_filename] << {
    inbox_id: img.inbox_id,
    inbox_name: img.inbox.name,
    identifier: img.identifier,
    original_name: img.original_name
  }
end

if found_images.any?
  puts '✅ FOUND MENU ICON IMAGES!'
  puts ''

  found_images.each do |filename, locations|
    puts "Filename: #{filename}"
    locations.each do |loc|
      puts "  Inbox #{loc[:inbox_id]} (#{loc[:inbox_name]})"
      puts "    Identifier: '#{loc[:identifier]}'"
      puts "    Original Name: #{loc[:original_name].inspect}"
    end
    puts ''
  end

  puts '=' * 80
  puts 'SOLUTION'
  puts '=' * 80
  puts ''
  puts 'The menu icon images exist in a different inbox!'
  puts ''
  puts 'Options:'
  puts "1. Copy images from source inbox to inbox 4 (template 366's inbox)"
  puts '2. Use the copy_from API endpoint to copy these images'
  puts ''
else
  puts '❌ None of the target filenames found in any inbox'
  puts ''
  puts 'Showing some sample blob filenames from each inbox:'
  puts ''

  by_inbox.each do |inbox_id, images|
    inbox = images.first.inbox
    puts "Inbox #{inbox_id} (#{inbox.name}):"

    images.select { |i| i.image.attached? }.take(5).each do |img|
      blob_filename = img.image.blob.filename.to_s
      puts "  - '#{img.identifier}' => blob filename: #{blob_filename.inspect}"
    end
    puts ''
  end
end

puts ''
