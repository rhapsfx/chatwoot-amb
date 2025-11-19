# frozen_string_literal: true

# Show ALL images in inbox 5 with their blob filenames
# Run with: rails runner script/show_inbox_5_images.rb

puts '=' * 80
puts 'All Images in Inbox 5 (Rhaps AMB)'
puts '=' * 80
puts ''

inbox_5_images = AppleListPickerImage.where(inbox_id: 5)
                                     .includes(image_attachment: :blob)
                                     .order(:created_at)

puts "Total images: #{inbox_5_images.count}"
puts ''

# Show images with actual filenames (not just numbers)
images_with_filenames = inbox_5_images.select do |img|
  next false unless img.image.attached?

  blob_filename = img.image.blob.filename.to_s
  # Filter out pure numeric or identifier-style names
  blob_filename !~ /^\d+$/ && blob_filename !~ /^[a-z0-9_]+\d+$/
end

puts "Images with actual descriptive filenames (#{images_with_filenames.count}):"
puts ''

images_with_filenames.each do |img|
  blob_filename = img.image.blob.filename.to_s
  puts "Identifier: '#{img.identifier}'"
  puts "  Blob filename: #{blob_filename.inspect}"
  puts "  Original name: #{img.original_name.inspect}"
  puts "  Size: #{img.image.blob.byte_size} bytes"
  puts ''
end

# Also check for form.png specifically since we saw it
form_image = inbox_5_images.find { |i| i.image.attached? && i.image.blob.filename.to_s == 'form.png' }
if form_image
  puts '=' * 80
  puts "Found 'form.png'!"
  puts '=' * 80
  puts ''
  puts "This might be a clue - if inbox 5 has 'form.png' as actual filename,"
  puts 'then maybe the menu icon images ARE there with proper filenames too?'
  puts ''
end

puts '=' * 80
puts 'ALL INBOX 5 IMAGES (sorted by creation date)'
puts '=' * 80
puts ''

inbox_5_images.each do |img|
  next unless img.image.attached?

  blob = img.image.blob
  puts "Identifier: '#{img.identifier}'"
  puts "  Blob filename: #{blob.filename.to_s.inspect}"
  puts "  Original name: #{img.original_name.inspect}"
  puts "  Content type: #{blob.content_type}"
  puts "  Size: #{blob.byte_size} bytes (#{(blob.byte_size / 1024.0).round(2)} KB)"
  puts "  Created: #{blob.created_at}"
  puts ''
end
