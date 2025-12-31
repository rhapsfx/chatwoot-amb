# frozen_string_literal: true

# Debug why messages_png is not in the payload
# Run with: rails runner script/debug_messages_png.rb

puts '=' * 80
puts 'Debug messages_png Image Issue'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
inbox_id = 4

puts "Template: #{template.name}"
puts "Inbox: #{inbox_id}"
puts ''

# Check if messages_png exists in AppleListPickerImage table
puts '=' * 80
puts 'CHECK 1: Does messages_png exist in AppleListPickerImage table?'
puts '=' * 80
puts ''

messages_img = AppleListPickerImage.find_by(inbox_id: inbox_id, identifier: 'messages_png')

if messages_img
  puts "✅ Found 'messages_png' in database"
  puts "   ID: #{messages_img.id}"
  puts "   Identifier: #{messages_img.identifier}"
  puts "   Description: #{messages_img.description}"
  puts "   Original Name: #{messages_img.original_name}"
  puts "   Image attached? #{messages_img.image.attached?}"

  if messages_img.image.attached?
    blob = messages_img.image.blob
    puts "   Blob filename: #{blob.filename}"
    puts "   Blob size: #{blob.byte_size} bytes"
    puts "   Content type: #{blob.content_type}"
  end
else
  puts "❌ 'messages_png' NOT FOUND in AppleListPickerImage table"
  puts ''
  puts 'You need to upload it first!'
  puts 'Run: rails runner script/upload_messages_icon.rb'
  puts ''
  exit 1
end

puts ''

# Check template configuration
puts '=' * 80
puts 'CHECK 2: Template configuration'
puts '=' * 80
puts ''

block = template.content_blocks.find_by(block_type: 'list_picker')
props = block.properties

puts "received_image_identifier: #{props['received_image_identifier'].inspect}"
puts ''

# Check what the service would extract
puts '=' * 80
puts 'CHECK 3: What identifiers would SendListPickerService extract?'
puts '=' * 80
puts ''

identifiers = Set.new

# Add header image from received_message
header_image = props['received_image_identifier']
identifiers << header_image if header_image.present?

# Add reply image if different from header
reply_image = props['reply_image_identifier']
identifiers << reply_image if reply_image.present? && reply_image != header_image

# Add images from list picker items
sections = props['sections']
if sections.is_a?(Array)
  sections.each do |section|
    items = section['items']
    next unless items.is_a?(Array)

    items.each do |item|
      image_id = item['imageIdentifier'] || item['image_identifier']
      identifiers << image_id if image_id.present?
    end
  end
end

puts "Identifiers to fetch: #{identifiers.to_a.inspect}"
puts ''

# Check which ones exist in AppleListPickerImage
puts '=' * 80
puts 'CHECK 4: Which identifiers exist in AppleListPickerImage?'
puts '=' * 80
puts ''

existing_images = AppleListPickerImage
                  .where(inbox_id: inbox_id, identifier: identifiers.to_a)
                  .includes(image_attachment: :blob)

puts "Found #{existing_images.count} images in AppleListPickerImage table:"
existing_images.each do |img|
  status = img.image.attached? ? '✅' : '❌ NO ATTACHMENT'
  puts "  #{status} '#{img.identifier}'"
end
puts ''

missing = identifiers.to_a - existing_images.map(&:identifier)
if missing.any?
  puts '❌ Missing images in AppleListPickerImage table:'
  missing.each { |id| puts "   - #{id}" }
else
  puts '✅ All identifiers found in AppleListPickerImage table'
end

puts ''

# Check embedded images
puts '=' * 80
puts 'CHECK 5: Embedded images in template'
puts '=' * 80
puts ''

embedded = props['images'] || []
puts "Template has #{embedded.count} embedded images"

if embedded.any?
  puts ''
  puts 'Embedded image identifiers:'
  embedded.each do |img|
    puts "  - #{img['identifier']}"
  end
end

puts ''

# The key insight
puts '=' * 80
puts 'DIAGNOSIS'
puts '=' * 80
puts ''

if messages_img && messages_img.image.attached?
  puts '✅ messages_png exists in AppleListPickerImage table with attachment'
  puts ''
  puts 'The service SHOULD fetch it and include it in the images array.'
  puts ''
  puts "If it's still not appearing in the payload, check:"
  puts '1. Did you restart the server after uploading?'
  puts "2. Check Rails logs for: 'Looking for images with identifiers:'"
  puts "3. Check Rails logs for: 'Found X images in ActiveStorage'"
  puts ''
  puts "The log should show 'messages_png' in the identifiers list."
else
  puts "❌ messages_png either doesn't exist or has no attachment"
  puts ''
  puts 'Solution: Run the upload script'
  puts '  rails runner script/upload_messages_icon.rb'
end

puts ''
