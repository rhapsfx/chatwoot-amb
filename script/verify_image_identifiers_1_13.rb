#!/usr/bin/env ruby
# frozen_string_literal: true

# Check what images exist for identifiers 1-13 in both storage tiers

puts '=' * 80
puts 'Image Identifiers 1-13 Verification'
puts '=' * 80
puts ''

IDENTIFIERS = %w[1 2 3 4 5 6 7 8 9 10 11 12 13]

# Check SharedAppleImage
puts '📦 SharedAppleImage (account-wide):'
puts '-' * 80

shared = SharedAppleImage.where(account_id: 1, identifier: IDENTIFIERS)
if shared.any?
  shared.order(:identifier).each do |img|
    puts "  #{img.identifier.to_s.ljust(3)} - #{img.description.to_s[0..60]}"
    puts "       Type: #{img.image_type}, Has attachment: #{img.image.attached?}"
  end
else
  puts '  ❌ No shared images found for identifiers 1-13'
end

puts ''
puts '📦 AppleListPickerImage (inbox-specific):'
puts '-' * 80

inbox_images = AppleListPickerImage.where(identifier: IDENTIFIERS).includes(image_attachment: :blob)
if inbox_images.any?
  inbox_images.group_by(&:inbox_id).each do |inbox_id, images|
    puts "  Inbox #{inbox_id}:"
    images.each do |img|
      puts "    #{img.identifier.to_s.ljust(3)} - #{img.description.to_s[0..60]}"
      puts "         Has attachment: #{img.image.attached?}"
    end
  end
else
  puts '  ✅ No inbox-specific images found for identifiers 1-13'
  puts '  (This is expected after cleanup - should use SharedAppleImage)'
end

puts ''
puts '=' * 80
puts 'ImageFetchService Three-Tier Fallback Test'
puts '=' * 80
puts ''
puts 'Testing what ImageFetchService would return for inbox 6...'

service = AppleMessagesForBusiness::ImageFetchService.new(
  account_id: 1,
  inbox_id: 6,
  embedded_images: []
)

result = service.fetch_and_encode(%w[1 2 3])

puts ''
puts "Fetched #{result.length} images:"
result.each do |img|
  puts "  #{img[:identifier]} - Source: #{img[:source]}, Description: #{img[:description]&.to_s&.[](0..40)}"
end

puts ''
puts '=' * 80
