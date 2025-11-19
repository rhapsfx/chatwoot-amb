# frozen_string_literal: true

# Check ActiveStorage blob metadata for original filenames
# Run with: rails runner script/check_blob_metadata.rb

puts '=' * 80
puts 'Check ActiveStorage Blob Metadata'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
inbox_id = template.account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').first&.id

numeric_images = AppleListPickerImage.where(inbox_id: inbox_id)
                                     .where("identifier ~ '^[0-9]+$'")
                                     .order(Arel.sql('CAST(identifier AS INTEGER)'))

puts 'Checking blob metadata for numeric identifiers:'
puts ''

filename_to_identifier = {}

numeric_images.each do |img|
  puts "Identifier: '#{img.identifier}'"
  puts "  original_name field: #{img.original_name.inspect}"

  if img.image.attached?
    blob = img.image.blob

    puts '  Blob attributes:'
    puts "    filename: #{blob.filename.to_s.inspect}"
    puts "    content_type: #{blob.content_type.inspect}"
    puts "    byte_size: #{blob.byte_size}"
    puts "    key: #{blob.key.inspect}"

    # Check blob metadata
    puts "    metadata: #{blob.metadata.inspect}" if blob.metadata.present?

    # The filename method returns a ActiveStorage::Filename object
    actual_filename = blob.filename.to_s

    # Try to find original filename in blob metadata
    original_filename = blob.metadata['original_filename'] if blob.metadata.present?

    if original_filename
      puts "  ✅ Found original filename in metadata: #{original_filename.inspect}"
      filename_to_identifier[original_filename] = img.identifier
    else
      # Use the blob filename
      filename_to_identifier[actual_filename] = img.identifier
    end
  else
    puts '  ⚠️  No file attached'
  end
  puts ''
end

puts '=' * 80
puts 'FILENAME TO IDENTIFIER MAP'
puts '=' * 80
puts ''

filename_to_identifier.each do |filename, identifier|
  puts "'#{filename}' => '#{identifier}'"
end

puts ''
