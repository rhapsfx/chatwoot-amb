# frozen_string_literal: true

# Test fetch_and_encode_images logic
# Run with: rails runner script/test_fetch_images.rb

puts '=' * 80
puts 'Test fetch_and_encode_images Logic'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
inbox_id = 4

block = template.content_blocks.find_by(block_type: 'list_picker')
content_attributes = block.properties

# Extract identifiers (same logic as service)
identifiers = Set.new

header_image = content_attributes['received_image_identifier']
identifiers << header_image if header_image.present?

reply_image = content_attributes['reply_image_identifier']
identifiers << reply_image if reply_image.present? && reply_image != header_image

sections = content_attributes['sections']
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

# Simulate fetch_and_encode_images
puts '=' * 80
puts 'STEP 1: Fetch from AppleListPickerImage table'
puts '=' * 80
puts ''

picker_images = AppleListPickerImage
                .where(inbox_id: inbox_id, identifier: identifiers.to_a)
                .includes(image_attachment: :blob)

puts "Found #{picker_images.count} images in AppleListPickerImage table"

db_images_by_id = {}
picker_images.each do |picker_image|
  if picker_image.image.attached?
    puts "  ✅ #{picker_image.identifier} (has attachment)"
    db_images_by_id[picker_image.identifier] = {
      identifier: picker_image.identifier,
      description: picker_image.description
    }
  else
    puts "  ❌ #{picker_image.identifier} (no attachment)"
  end
end

puts ''

# Get embedded images
puts '=' * 80
puts 'STEP 2: Get embedded images from template'
puts '=' * 80
puts ''

embedded_images = content_attributes['images'] || []
embedded_images_by_id = {}

puts "Found #{embedded_images.count} embedded images"

embedded_images.each do |img|
  has_data = img['data'].present?
  has_identifier = img['identifier'].present?

  if has_identifier && has_data
    embedded_images_by_id[img['identifier']] = {
      identifier: img['identifier'],
      description: img['description']
    }
    puts "  ✅ #{img['identifier']} (has data)"
  else
    status = []
    status << 'no identifier' unless has_identifier
    status << 'no data' unless has_data
    puts "  ❌ #{img['identifier'] || '(unnamed)'} (#{status.join(', ')})"
  end
end

puts ''

# Combine
puts '=' * 80
puts 'STEP 3: Combine images from both sources'
puts '=' * 80
puts ''

result = []
identifiers.each do |identifier|
  if db_images_by_id[identifier]
    result << db_images_by_id[identifier]
    puts "✅ #{identifier} - from database"
  elsif embedded_images_by_id[identifier]
    result << embedded_images_by_id[identifier]
    puts "✅ #{identifier} - from embedded"
  else
    puts "❌ #{identifier} - NOT FOUND"
  end
end

puts ''
puts '=' * 80
puts 'RESULT'
puts '=' * 80
puts ''

puts "Total images that would be sent: #{result.count}"
puts ''

result.each_with_index do |img, i|
  puts "#{i + 1}. #{img[:identifier]} - #{img[:description]}"
end

puts ''

if result.any? { |img| img[:identifier] == 'messages_png' }
  puts '✅ messages_png IS in the result'
else
  puts '❌ messages_png is NOT in the result'
end

puts ''
