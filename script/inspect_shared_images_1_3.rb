#!/usr/bin/env ruby
# frozen_string_literal: true

# Inspect what's actually stored in SharedAppleImage for identifiers 1, 2, 3

puts '=' * 80
puts 'SharedAppleImage 1-3 Inspection'
puts '=' * 80
puts ''

shared = SharedAppleImage.where(account_id: 1, identifier: %w[1 2 3]).order(:identifier)

shared.each do |img|
  puts "Identifier: #{img.identifier}"
  puts "  Description: #{img.description}"
  puts "  Type: #{img.image_type}"
  puts "  Has attachment: #{img.image.attached?}"

  if img.image.attached?
    puts "  Filename: #{img.image.filename}"
    puts "  Content type: #{img.image.content_type}"
    puts "  Size: #{img.image.byte_size} bytes"

    # Check metadata for migration info
    if img.metadata.present?
      puts '  Metadata:'
      puts "    Source inbox: #{img.metadata['source_inbox_id']}"
      puts "    Migrated from: #{img.metadata['migrated_from']}"
      puts "    Migration date: #{img.metadata['migration_date']}"
    end
  end

  puts ''
end

puts '=' * 80
puts 'Checking AppleListPickerImage (inbox-specific) for comparison'
puts '=' * 80
puts ''

inbox_images = AppleListPickerImage.where(identifier: %w[1 2 3]).includes(image_attachment: :blob)

if inbox_images.any?
  puts '⚠️  Found inbox-specific images that should have been deleted:'
  inbox_images.each do |img|
    puts "  Inbox #{img.inbox_id}: #{img.identifier}"
    puts "    Description: #{img.description}"
    puts "    Filename: #{img.image.filename}" if img.image.attached?
  end
else
  puts '✅ No inbox-specific images found (correctly cleaned up)'
end

puts ''
puts '=' * 80
