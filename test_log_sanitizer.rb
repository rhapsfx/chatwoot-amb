#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for LogSanitizer improvements
# Run with: ruby test_log_sanitizer.rb

require_relative 'app/services/apple_messages_for_business/log_sanitizer'

# Test data with various base64 scenarios
test_data = {
  # Regular base64 PNG image
  regular_image: {
    identifier: 'logo_png',
    data: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==' * 100
  },

  # Data URL format
  data_url_image: {
    profile_pic: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlbaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD3+iiigD//' * 50
  },

  # Multiple images in array
  images_array: [
    { image_id: 'img1', data: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==' * 100 },
    { image_id: 'img2',
      data: '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/' * 75 }
  ],

  # Nested structure like Apple Messages payloads
  interactive_data: {
    bid: 'com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension',
    data: {
      version: '1.0',
      listPicker: {
        sections: [
          {
            title: 'Products',
            items: [
              {
                title: 'Product 1',
                identifier: 'prod_1',
                imageIdentifier: 'product_image',
                style: 'default'
              }
            ]
          }
        ],
        images: [
          {
            identifier: 'product_image',
            data: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==' * 150
          }
        ]
      }
    },
    receivedMessage: {
      title: 'Browse our products',
      style: 'icon',
      imageIdentifier: 'messages_png'
    },
    images: [
      {
        identifier: 'messages_png',
        data: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==' * 80
      }
    ]
  },

  # Regular strings (should not be sanitized)
  regular_data: {
    title: 'Test Message',
    description: 'This is a regular string',
    url: 'https://example.com/path?param=value',
    metadata: {
      key1: 'value1',
      key2: 'value2'
    }
  }
}

puts '=' * 80
puts 'LogSanitizer Test Suite'
puts '=' * 80
puts

# Test 1: Compact format (default)
puts '1. COMPACT FORMAT (default) - shows just size'
puts '-' * 80
test_data.each do |test_name, data|
  puts "\nTest: #{test_name}"
  sanitized = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(data, format: :compact)
  puts JSON.pretty_generate(sanitized)
end

puts "\n\n"
puts '=' * 80
puts

# Test 2: Preview format - shows size + preview
puts '2. PREVIEW FORMAT - shows size + first 20 chars'
puts '-' * 80
test_data.each do |test_name, data|
  puts "\nTest: #{test_name}"
  sanitized = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(data, format: :preview, preview_length: 20)
  puts JSON.pretty_generate(sanitized)
end

puts "\n\n"
puts '=' * 80
puts

# Test 3: Detailed format - shows size, format, identifier
puts '3. DETAILED FORMAT - shows size, image type, identifier'
puts '-' * 80
test_data.each do |test_name, data|
  puts "\nTest: #{test_name}"
  sanitized = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(data, format: :detailed)
  puts JSON.pretty_generate(sanitized)
end

puts "\n\n"
puts '=' * 80
puts

# Test 4: contains_base64? helper
puts '4. CONTAINS_BASE64? HELPER - detect if data has base64'
puts '-' * 80
test_data.each do |test_name, data|
  has_base64 = AppleMessagesForBusiness::LogSanitizer.contains_base64?(data)
  puts "#{test_name}: #{has_base64 ? 'YES ✅' : 'NO ❌'}"
end

puts "\n\n"
puts '=' * 80
puts

# Test 5: base64_summary helper
puts '5. BASE64_SUMMARY HELPER - statistics about base64 content'
puts '-' * 80
test_data.each do |test_name, data|
  next if test_name == :regular_data # Skip regular data as it has no images

  summary = AppleMessagesForBusiness::LogSanitizer.base64_summary(data)
  puts "\n#{test_name}:"
  puts "  Total images: #{summary[:count]}"
  puts "  Total size: #{summary[:total_kb]}KB"
  summary[:images].each_with_index do |img, idx|
    puts "  - Image #{idx + 1}: #{img[:format] || 'unknown'} format, #{img[:size_kb]}KB, key: #{img[:key]}"
  end
end

puts "\n\n"
puts '=' * 80
puts 'Test Complete!'
puts '=' * 80
