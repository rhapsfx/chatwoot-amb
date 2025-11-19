# frozen_string_literal: true

# Examine the actual attached image files for numeric identifiers
# Run with: rails runner script/examine_numeric_images.rb

puts '=' * 80
puts 'Examine Numeric Image Identifiers'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
inbox_id = template.account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').first&.id

numeric_images = AppleListPickerImage.where(inbox_id: inbox_id)
                                     .where("identifier ~ '^[0-9]+$'")
                                     .order(Arel.sql('CAST(identifier AS INTEGER)'))

puts "Found #{numeric_images.count} numeric image identifiers"
puts ''

numeric_images.each do |img|
  puts "Identifier: '#{img.identifier}'"
  puts "  Original Name: #{img.original_name.inspect}"
  puts "  Description: #{img.description.inspect}"

  if img.image.attached?
    blob = img.image.blob
    puts '  Attached File:'
    puts "    Filename: #{blob.filename}"
    puts "    Content Type: #{blob.content_type}"
    puts "    Size: #{blob.byte_size} bytes"
    puts "    Created: #{blob.created_at}"
  else
    puts '  ⚠️  No image attached!'
  end

  puts ''
end

puts '=' * 80
puts 'KNOWN NON-NUMERIC IMAGES FOR REFERENCE'
puts '=' * 80
puts ''

# Show known images that might give us clues
known_images = AppleListPickerImage.where(inbox_id: inbox_id)
                                   .where.not("identifier ~ '^[0-9]+$'")
                                   .where.not("identifier LIKE 'aha19_%'")
                                   .where.not("identifier LIKE 'guitar_%'")
                                   .where.not("identifier LIKE 'iphone_%'")
                                   .where.not("identifier LIKE '%_png'")
                                   .order(:id)

if known_images.any?
  puts 'Other images (non-numeric, non-aha19, non-guitar):'
  known_images.each do |img|
    puts "  '#{img.identifier}' => #{img.original_name.inspect}"
    puts "    File: #{img.image.blob.filename}" if img.image.attached?
  end
  puts ''
end

puts '=' * 80
puts 'NEXT STEPS'
puts '=' * 80
puts ''
puts 'Based on the filenames above, can you identify which images these are?'
puts 'Or, we could try a different approach:'
puts ''
puts '1. Check the upload order - were these uploaded in the same order as the menu?'
puts '2. Look at creation timestamps to see upload sequence'
puts '3. Download and view the actual image files to identify them'
puts ''
