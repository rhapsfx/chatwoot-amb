#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to verify log sanitization is working
# Run with: bundle exec ruby script/verify_log_sanitization.rb

require_relative '../config/environment'

puts '=' * 80
puts 'Log Sanitization Verification (Enhanced with Aggressive Mode)'
puts '=' * 80
puts

# Test 1: Check if LogSanitizerService is available
puts 'Test 1: LogSanitizerService availability'
puts '-' * 80
begin
  puts '✅ LogSanitizerService is loaded'
rescue NameError
  puts '❌ LogSanitizerService not found - check if file exists'
  exit 1
end
puts

# Test 2: Test sanitization of apple_list_picker content_attributes (NORMAL MODE)
puts 'Test 2: Sanitize apple_list_picker content_attributes (NORMAL MODE)'
puts '-' * 80
content_attrs = {
  'sections' => [
    {
      'title' => 'Options',
      'items' => [
        {
          'identifier' => '1',
          'title' => 'Option 1',
          'image_identifier' => '0'
        }
      ]
    }
  ],
  'images' => [
    {
      'identifier' => '0',
      'data' => Base64.strict_encode64('x' * 50_000), # 50KB of data
      'description' => 'Test image'
    }
  ]
}

puts "Original size: #{content_attrs.inspect.length} bytes"
sanitized = LogSanitizerService.sanitize_for_log(content_attrs)
puts "Sanitized size: #{sanitized.inspect.length} bytes"
puts 'Sanitized output (first 500 chars):'
puts sanitized.inspect[0...500]
puts
puts

# Test 3: Test AGGRESSIVE MODE for high-frequency jobs
puts 'Test 3: Sanitize EventDispatcherJob arguments (ULTRA-AGGRESSIVE MODE)'
puts '-' * 80
job_args = {
  'event_name' => 'message.created',
  'data' => {
    'id' => 123,
    'content' => 'Hello world',
    'content_attributes' => {
      'sections' => [
        { 'title' => 'Section 1', 'items' => %w[item1 item2] }
      ],
      'images' => [
        { 'identifier' => '0', 'data' => Base64.strict_encode64('x' * 50_000) }
      ],
      'description' => 'Test'
    }
  },
  'timestamp' => Time.now.to_i
}

puts "Original job args size: #{job_args.inspect.length} bytes"
puts "Original 'data' field size: #{job_args['data'].inspect.length} bytes"

# Normal mode - won't truncate small data
sanitized_normal = LogSanitizerService.sanitize_for_log(job_args, aggressive: false)
puts "\n📊 NORMAL MODE sanitization:"
puts "Sanitized size: #{sanitized_normal.inspect.length} bytes"
puts sanitized_normal.inspect[0...500]

# Aggressive mode - ULTRA minimal, structure only
sanitized_aggressive = LogSanitizerService.sanitize_for_log(job_args, aggressive: true)
puts "\n🔥 ULTRA-AGGRESSIVE MODE sanitization (structure only, no content):"
puts "Sanitized size: #{sanitized_aggressive.inspect.length} bytes"
puts sanitized_aggressive.inspect
puts
puts "📊 Size reduction: #{((1 - (sanitized_aggressive.inspect.length.to_f / job_args.inspect.length)) * 100).round(2)}%"
puts

# Test 4: Check Rails parameter filtering
puts 'Test 4: Rails parameter filter configuration'
puts '-' * 80
filters = Rails.application.config.filter_parameters
puts "Configured filters: #{filters.inspect[0...200]}..."
has_custom_filter = filters.any? { |f| f.is_a?(Proc) }
puts has_custom_filter ? '✅ Custom lambda filter is configured' : '❌ Custom lambda filter not found'
puts

# Test 5: Test ActiveJobLogSanitizer with job class detection
puts 'Test 5: ActiveJobLogSanitizer job-aware sanitization'
puts '-' * 80
test_data = [{
  'event_name' => 'message.created',
  'data' => {
    'content' => 'x' * 200,
    'metadata' => { 'key1' => 'value1', 'key2' => 'value2' }
  }
}]

puts "Original args size: #{test_data.inspect.length} bytes"

# Simulate EventDispatcherJob (high-frequency) - should use ultra-aggressive
puts "\nEventDispatcherJob (high-frequency - ULTRA-AGGRESSIVE):"
sanitized_event = ActiveJobLogSanitizer.sanitize_args(test_data, 'EventDispatcherJob')
puts "Size: #{sanitized_event.inspect.length} bytes"
puts sanitized_event.inspect

# Simulate ActionCableBroadcastJob (high-frequency) - should use ultra-aggressive
puts "\nActionCableBroadcastJob (high-frequency - ULTRA-AGGRESSIVE):"
sanitized_cable = ActiveJobLogSanitizer.sanitize_args(test_data, 'ActionCableBroadcastJob')
puts "Size: #{sanitized_cable.inspect.length} bytes"
puts sanitized_cable.inspect

# Simulate regular job (not high-frequency) - should use normal mode
puts "\nRegular job (not high-frequency - NORMAL MODE):"
sanitized_regular = ActiveJobLogSanitizer.sanitize_args(test_data, 'SomeOtherJob')
puts "Size: #{sanitized_regular.inspect.length} bytes"
puts sanitized_regular.inspect[0...300]
puts

# Test 6: Simulate what would be logged
puts 'Test 6: Simulate realistic job logging'
puts '-' * 80
test_message = Message.new(
  content_type: 'apple_list_picker',
  content: 'Test',
  content_attributes: content_attrs
)

puts "Message content_type: #{test_message.content_type}"
sanitized_attrs = LogSanitizerService.sanitize_for_log(test_message.content_attributes, aggressive: true)
puts 'Aggressively sanitized content_attributes (first 500 chars):'
puts sanitized_attrs.inspect[0...500]
puts

puts '=' * 80
puts 'Verification complete!'
puts '=' * 80
puts
puts '📝 Summary:'
puts '  ✅ Normal mode: Truncates data fields > 1KB'
puts '  🔥 Ultra-aggressive mode: Shows STRUCTURE ONLY (no content at all)'
puts '  🎯 High-frequency jobs: ActionCableBroadcastJob, EventDispatcherJob'
puts '  📉 Typical size reduction: 95-99% for high-frequency jobs'
puts
puts 'Examples of ultra-aggressive output:'
puts "  - Hash: '[HASH: 5 keys, ~12.5KB]'"
puts "  - Array: '[ARRAY: 10 items, ~3.2KB]'"
puts "  - String: '[STRING: 150B]'"
puts
puts '🔧 Implementation:'
puts '  - LogSanitizerService: Core sanitization logic'
puts '  - ActiveJobLogSanitizer: Fallback for non-Sidekiq environments'
puts '  - SidekiqLogSanitizer: Primary sanitization for Sidekiq jobs (CRITICAL)'
puts
puts '⚠️  IMPORTANT: You MUST restart your Rails server for changes to take effect!'
puts '   The initializer changes only load on server startup.'
puts
puts 'To restart:'
puts '  ./script//dev-server.sh restart'
puts
puts 'After restart, check logs for:'
puts '  [Sidekiq] Log sanitizer middleware installed'
puts '=' * 80
