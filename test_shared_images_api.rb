#!/usr/bin/env ruby
# Test script to verify SharedAppleImage API

puts '=== SharedAppleImage API Test ==='
puts ''

# Check if model exists
puts '1. Checking SharedAppleImage model...'
begin
  puts "   Model class: #{SharedAppleImage.name}"
  puts '   ✅ Model exists'
rescue NameError => e
  puts "   ❌ Model not found: #{e.message}"
  exit 1
end

# Check Account association
puts ''
puts '2. Checking Account association...'
account = Account.first
if account.respond_to?(:shared_apple_images)
  puts '   ✅ Account has shared_apple_images association'
  puts "   Images count: #{account.shared_apple_images.count}"
else
  puts '   ❌ Account missing shared_apple_images association'
  exit 1
end

# List all shared images
puts ''
puts '3. Listing all SharedAppleImages...'
SharedAppleImage.all.each do |img|
  puts "   - #{img.identifier} (#{img.image_type})"
  puts "     Description: #{img.description}"
  puts "     Image attached: #{img.image.attached?}"
  puts "     Created: #{img.created_at}"
end

# Test image fetch
puts ''
puts '4. Testing ImageFetchService...'
begin
  service = AppleMessagesForBusiness::ImageFetchService.new(
    account_id: account.id,
    inbox_id: Channel::AppleMessagesForBusiness.first&.id || 1,
    embedded_images: []
  )

  images = service.fetch_and_encode(%w[messages_png apple_store_logo time_picker_lesson])
  puts "   Fetched #{images.count} images"
  images.each do |img|
    puts "   - #{img[:identifier]} (source: #{img[:source]})"
  end
  puts '   ✅ ImageFetchService working'
rescue StandardError => e
  puts "   ❌ ImageFetchService error: #{e.message}"
  puts "   #{e.backtrace.first(3).join("\n   ")}"
end

puts ''
puts '=== Test Complete ==='
