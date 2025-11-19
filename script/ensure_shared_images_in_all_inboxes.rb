# frozen_string_literal: true

# Ensure shared images (like messages_png) exist in ALL active Apple Messages inboxes
# Run with: rails runner script/ensure_shared_images_in_all_inboxes.rb

puts '=' * 80
puts 'Ensure Shared Images in All Apple Messages Inboxes'
puts '=' * 80
puts ''

# Define shared image identifiers that should exist in ALL inboxes
SHARED_IMAGE_IDENTIFIERS = %w[
  messages_png
].freeze

puts "Shared images to replicate: #{SHARED_IMAGE_IDENTIFIERS.inspect}"
puts ''

# Get all active Apple Messages inboxes
amb_channels = Channel::AppleMessagesForBusiness.all
inbox_ids = amb_channels.map { |c| c.inbox.id }

puts "Active Apple Messages inboxes: #{inbox_ids.inspect}"
inbox_ids.each do |inbox_id|
  inbox = Inbox.find(inbox_id)
  puts "  - Inbox #{inbox_id}: #{inbox.name}"
end
puts ''

puts '=' * 80
puts 'Processing Shared Images'
puts '=' * 80
puts ''

SHARED_IMAGE_IDENTIFIERS.each do |identifier|
  puts "Processing '#{identifier}'..."
  puts ''

  # Find ALL instances of this image across all inboxes
  all_instances = AppleListPickerImage.where(identifier: identifier)

  if all_instances.empty?
    puts "  ❌ '#{identifier}' not found in ANY inbox - skipping"
    puts '     You need to upload this image first!'
    puts ''
    next
  end

  # Find a source image (prefer one with attachment)
  source_image = all_instances.find { |img| img.image.attached? }

  unless source_image
    puts "  ❌ '#{identifier}' exists but no instance has an attachment - skipping"
    puts ''
    next
  end

  puts "  ✅ Found source in inbox #{source_image.inbox_id}"

  # Download image data once
  image_data = source_image.image.download
  blob = source_image.image.blob

  puts "     Size: #{blob.byte_size} bytes"
  puts "     Content type: #{blob.content_type}"
  puts ''

  # Copy to all inboxes that don't have it
  inbox_ids.each do |target_inbox_id|
    existing = AppleListPickerImage.find_by(inbox_id: target_inbox_id, identifier: identifier)

    if existing && existing.image.attached?
      puts "  ✅ Inbox #{target_inbox_id}: already has '#{identifier}' - skipping"
      next
    end

    if existing && !existing.image.attached?
      puts "  ⚠️  Inbox #{target_inbox_id}: has record but no attachment - updating"
      target_image = existing
    else
      puts "  📤 Inbox #{target_inbox_id}: creating new '#{identifier}'"
      target_image = AppleListPickerImage.new(
        inbox_id: target_inbox_id,
        account_id: source_image.account_id,
        identifier: identifier
      )
    end

    target_image.description = source_image.description
    target_image.original_name = source_image.original_name

    target_image.image.attach(
      io: StringIO.new(image_data),
      filename: blob.filename.to_s,
      content_type: blob.content_type
    )

    target_image.save!

    puts "     ✅ Successfully copied to inbox #{target_inbox_id}"
  end

  puts ''
end

puts '=' * 80
puts 'VERIFICATION'
puts '=' * 80
puts ''

SHARED_IMAGE_IDENTIFIERS.each do |identifier|
  puts "Checking '#{identifier}':"

  inbox_ids.each do |inbox_id|
    img = AppleListPickerImage.find_by(inbox_id: inbox_id, identifier: identifier)
    if img && img.image.attached?
      puts "  ✅ Inbox #{inbox_id}: present with attachment"
    elsif img
      puts "  ❌ Inbox #{inbox_id}: present but NO attachment"
    else
      puts "  ❌ Inbox #{inbox_id}: NOT present"
    end
  end

  puts ''
end

puts '=' * 80
puts 'SUMMARY'
puts '=' * 80
puts ''

all_good = SHARED_IMAGE_IDENTIFIERS.all? do |identifier|
  inbox_ids.all? do |inbox_id|
    img = AppleListPickerImage.find_by(inbox_id: inbox_id, identifier: identifier)
    img && img.image.attached?
  end
end

if all_good
  puts '🎉 SUCCESS! All shared images exist in all inboxes with attachments'
  puts ''
  puts 'The bot can now send messages with shared images from ANY inbox!'
else
  puts '⚠️  Some shared images are still missing in some inboxes'
  puts ''
  puts 'Check the verification output above for details'
end

puts ''
