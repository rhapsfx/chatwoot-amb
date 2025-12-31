#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to test and demonstrate log sanitization
# Run with: bundle exec ruby script/test_log_sanitization.rb

require_relative '../config/environment'

puts '=' * 80
puts 'Log Sanitization Demo'
puts '=' * 80
puts

# Example 1: Small data (not sanitized)
puts 'Example 1: Small data (< 1KB)'
puts '-' * 80
small_data = { name: 'test', description: 'A short description' }
sanitized = LogSanitizerService.sanitize_for_log(small_data)
puts "Original: #{small_data.inspect}"
puts "Sanitized: #{sanitized.inspect}"
puts 'Result: No change (data is small)'
puts

# Example 2: Large base64 image data
puts 'Example 2: Large base64 image data'
puts '-' * 80
large_image = Base64.strict_encode64('x' * 50_000)
image_data = {
  identifier: '0',
  filename: 'test.jpg',
  image_data: large_image,
  description: 'Test image'
}
sanitized = LogSanitizerService.sanitize_for_log(image_data)
puts "Original size: #{image_data[:image_data].length} bytes (#{(image_data[:image_data].length / 1024.0).round(2)} KB)"
puts "Sanitized: #{sanitized.inspect}"
puts "Sanitized size: #{sanitized[:image_data].length} bytes"
puts

# Example 3: Nested data with multiple large fields
puts 'Example 3: Nested data structure'
puts '-' * 80
nested_data = {
  user: {
    name: 'John Doe',
    avatar_data: Base64.strict_encode64('y' * 10_000)
  },
  attachments: [
    { filename: 'doc1.pdf', content: 'z' * 5000 },
    { filename: 'doc2.txt', content: 'Small content' }
  ]
}
sanitized = LogSanitizerService.sanitize_for_log(nested_data)
puts "Original avatar size: #{nested_data[:user][:avatar_data].length} bytes"
puts "Original doc1 size: #{nested_data[:attachments][0][:content].length} bytes"
puts "Sanitized: #{sanitized.inspect}"
puts

# Example 4: Simulating Rails parameter logging
puts 'Example 4: Simulating Rails parameter logging'
puts '-' * 80
params = ActionController::Parameters.new({
                                            inbox_id: 123,
                                            identifier: '0',
                                            image_data: Base64.strict_encode64('image' * 10_000),
                                            filename: 'upload.jpg',
                                            description: 'User uploaded image'
                                          })

puts 'Before sanitization (would bloat logs):'
puts "Params size: #{params.to_unsafe_h.inspect.length} bytes"
puts

sanitized_params = LogSanitizerService.sanitize_for_log(params.to_unsafe_h)
puts 'After sanitization:'
puts "Sanitized params: #{sanitized_params.inspect}"
puts "Sanitized size: #{sanitized_params.inspect.length} bytes"
puts

# Example 5: Performance test
puts 'Example 5: Performance test'
puts '-' * 80
require 'benchmark'

large_params = {
  data1: Base64.strict_encode64('x' * 100_000),
  data2: Base64.strict_encode64('y' * 100_000),
  data3: Base64.strict_encode64('z' * 100_000),
  metadata: { name: 'test', id: 123 }
}

time = Benchmark.measure do
  1000.times { LogSanitizerService.sanitize_for_log(large_params) }
end

puts "Sanitized 1000 times in #{(time.real * 1000).round(2)}ms"
puts "Average: #{(time.real).round(5)}ms per sanitization"
puts

puts '=' * 80
puts 'Demo complete!'
puts '=' * 80
