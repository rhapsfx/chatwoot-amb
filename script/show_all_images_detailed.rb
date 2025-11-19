# frozen_string_literal: true

# Show ALL images with details to find menu icons
# Run with: rails runner script/show_all_images_detailed.rb

puts '=' * 80
puts 'ALL Images in Database (Detailed)'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
inbox_id = template.account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').first&.id

all_images = AppleListPickerImage.where(inbox_id: inbox_id).order(:created_at)

puts "Total images: #{all_images.count}"
puts ''

# Group by patterns
groups = {
  'Numeric (0-13)' => all_images.select { |i| i.identifier =~ /^\d+$/ },
  'aha19 series' => all_images.select { |i| i.identifier =~ /^aha19_/ },
  'Guitar images' => all_images.select { |i| i.identifier =~ /^guitar_/ },
  'iPhone images' => all_images.select { |i| i.identifier =~ /^iphone_/ },
  'Timestamp-based' => all_images.select { |i| i.identifier =~ /^\d{13}_/ },
  'Other' => all_images.select do |i|
    i.identifier !~ /^\d+$/ &&
      i.identifier !~ /^aha19_/ &&
      i.identifier !~ /^guitar_/ &&
      i.identifier !~ /^iphone_/ &&
      i.identifier !~ /^\d{13}_/
  end
}

groups.each do |group_name, images|
  next if images.empty?

  puts '=' * 80
  puts group_name.upcase
  puts '=' * 80
  puts ''

  images.each do |img|
    puts "Identifier: '#{img.identifier}'"
    puts "  Original Name: #{img.original_name.inspect}"
    puts "  Description: #{img.description.inspect}" if img.description.present?

    if img.image.attached?
      blob = img.image.blob
      puts "  File: #{blob.filename}"
      puts "  Size: #{blob.byte_size} bytes"
      puts "  Type: #{blob.content_type}"
      puts "  Uploaded: #{blob.created_at}"
    else
      puts '  ⚠️  No file attached'
    end
    puts ''
  end
end

puts '=' * 80
puts 'ANALYSIS'
puts '=' * 80
puts ''

puts 'Expected menu icon filenames from UI screenshots:'
expected = [
  'Messages.png (received message)',
  'list.bullet-512.png (items 1-2)',
  'ARKit-512.png (item 3)',
  'Apple_Pay_Mark.svg (item 4)',
  'Calendar-1024×1024@2x.png (item 5)',
  'Photos_512×512@2x.png (item 6)',
  'Preview_512×512@2x.png (items 7-8)',
  'FaceID@3x.png (item 9)',
  'AppStore-1024.png (item 10)',
  'Wallet-1024.png (item 11)',
  'Maps_512×512@2x.png (item 12)'
]

expected.each do |filename|
  puts "  - #{filename}"
end
puts ''

puts 'Do any of the filenames above match the database images?'
puts ''

# Try to find partial matches
puts 'Checking for partial filename matches...'
menu_keywords = %w[list bullet arkit ar apple pay calendar
                   photos preview faceid face appstore app
                   wallet maps messages]

menu_keywords.each do |keyword|
  matches = all_images.select do |img|
    (img.identifier || '').downcase.include?(keyword) ||
      (img.original_name || '').downcase.include?(keyword) ||
      (img.description || '').downcase.include?(keyword) ||
      (img.image.attached? && (img.image.blob.filename.to_s || '').downcase.include?(keyword))
  end

  next unless matches.any?

  puts ''
  puts "Keyword '#{keyword}' found in:"
  matches.each do |img|
    puts "  - '#{img.identifier}' (#{img.original_name})"
  end
end

puts ''
puts '=' * 80
puts 'CONCLUSION'
puts '=' * 80
puts ''
puts 'If no matches found above, the menu icon images need to be uploaded.'
puts ''
