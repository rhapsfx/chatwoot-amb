#\!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify log sanitization for Custom Apple Messages payload with base64 data

puts 'Testing log sanitization for Custom Apple Messages payload...'
puts '=' * 80

# Simulate the log sanitizer from active_job_log_sanitizer.rb
module LogSanitizer
  def self.sanitize(message)
    return message unless message.is_a?(String)

    # Pattern 2: Parameters with base64 data (more aggressive)
    if message.include?('Parameters:') || message.include?('"data"=>') || message.include?('Custom Apple Messages payload')
      # First, handle already filtered base64 with preview - clean it up
      # This must come BEFORE the general base64 truncation to preserve the marker
      message = message.gsub(/\[BASE64 DATA FILTERED - [\d.]+ [KMG]B - preview: [^\]]+\]/, '[BASE64 DATA FILTERED]')
      message = message.gsub(/("data"=>")\[BASE64 DATA FILTERED[^\]]+\]"/, '\1[BASE64 DATA FILTERED]"')

      # Then remove long base64 strings (anything that looks like base64 data > 100 chars)
      # Skip if already marked as [BASE64 DATA FILTERED]
      message = message.gsub(/("data"=>"(?!\[BASE64 DATA FILTERED\])[^"]{100,}")/, '"data"=>"[BASE64 TRUNCATED]"')

      # Also handle the preview field with base64
      message = message.gsub(%r{("preview"=>"data:image/[^;]+;base64,[^"]{50,}")}, '"preview"=>"[BASE64 IMAGE]"')

      # For Custom Apple Messages payload specifically, aggressively filter content_attributes
      if message.include?('Custom Apple Messages payload')
        # Replace entire content_attributes hash with summary when it's too large
        message = message.gsub(/"content_attributes"=>\{[^}]{500,}\}/, '"content_attributes"=>{...TRUNCATED...}')
      end
    end

    message
  end
end

# Test cases
test_cases = [
  {
    name: 'Custom Apple Messages payload with large base64 data',
    input: 'Parameters: {"content"=>"Custom Apple Messages payload", "content_attributes"=>{"data"=>"iVBORw0KGgoAAAANSUhEUgAABAAAAAQACAMAAABIw9uxAAAABGdBTUEAALGPC' + ('x' * 2000) + '", "other"=>"value"}}',
    should_contain: ['[BASE64 TRUNCATED]', 'Custom Apple Messages payload'],
    should_not_contain: ['iVBORw0K' + ('x' * 100)]
  },
  {
    name: 'Already filtered base64 with long preview',
    input: 'Parameters: {"data"=>"[BASE64 DATA FILTERED - 499.32 KB - preview: iVBORw0KGgoAAAANSUhEUgAABAAAAAQACAMAAABIw9uxAAAABGdBTUEAALGPC...]"}',
    should_contain: ['[BASE64 DATA FILTERED]'],
    should_not_contain: ['preview: iVBORw0K']
  },
  {
    name: 'Custom payload with huge content_attributes',
    input: 'Parameters: {"content"=>"Custom Apple Messages payload", "content_attributes"=>{"field1"=>"value1", ' + ('"field2"=>"value2", ' * 100) + '"data"=>"' + ('A' * 5000) + '"}}',
    should_contain: ['{...TRUNCATED...}'],
    should_not_contain: nil
  },
  {
    name: 'Preview image with base64',
    input: 'Parameters: {"preview"=>"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAABAAAAAQACAMAAABIw9uxAAAABGdBTUEAALGPC' + ('x' * 1000) + '"}',
    should_contain: ['[BASE64 IMAGE]'],
    should_not_contain: ['iVBORw0KGgoAAAA']
  },
  {
    name: 'Mixed: Custom payload with already filtered data',
    input: 'Parameters: {"content"=>"Custom Apple Messages payload", "private"=>"[FILTERED]", "content_attributes"=>{"data"=>"[BASE64 DATA FILTERED - 499.32 KB - preview: iVBORw0K...]", "other"=>"value"}}',
    should_contain: ['[BASE64 DATA FILTERED]', 'Custom Apple Messages payload'],
    should_not_contain: ['499.32 KB', 'preview: iVBORw0K']
  },
  {
    name: 'Non-Custom payload with base64 data (should preserve detail)',
    input: 'Parameters: {"content"=>"Regular message", "data"=>"iVBORw0KGgoAAAANSUhEUgAABAAAAAQACAMAAABIw9uxAAAABGdBTUEAALGPC' + ('x' * 500) + '"}',
    should_contain: ['[BASE64 TRUNCATED]', 'Regular message'],
    should_not_contain: ['iVBORw0K' + ('x' * 100)]
  }
]

# Run tests
passed = 0
failed = 0

test_cases.each_with_index do |test, index|
  puts "\nTest #{index + 1}: #{test[:name]}"
  puts '-' * 80

  result = LogSanitizer.sanitize(test[:input])

  puts "Input length: #{test[:input].length} chars"
  puts "Output length: #{result.length} chars"
  reduction = ((1 - (result.length.to_f / test[:input].length)) * 100).round(1)
  puts "Reduction: #{reduction}%" if reduction > 0
  puts "\nOutput:"
  puts result

  # Verify expectations
  test_passed = true

  test[:should_contain]&.each do |expected|
    unless result.include?(expected)
      puts "\n❌ FAIL: Should contain '#{expected}'"
      test_passed = false
    end
  end

  test[:should_not_contain]&.each do |unexpected|
    if result.include?(unexpected)
      puts "\n❌ FAIL: Should NOT contain '#{unexpected}'"
      test_passed = false
    end
  end

  if test_passed
    puts "\n✅ PASS"
    passed += 1
  else
    failed += 1
  end
end

puts "\n" + ('=' * 80)
puts "Test Results: #{passed} passed, #{failed} failed out of #{test_cases.length} tests"
puts '=' * 80

exit(failed > 0 ? 1 : 0)
