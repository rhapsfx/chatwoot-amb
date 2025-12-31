#!/usr/bin/env ruby
# Test script to verify CaseTransformer correctly handles nested sections array
#
# Usage:
#   rails runner script/test_case_transformer_sections.rb

require_relative '../app/services/apple_messages_for_business/case_transformer'

puts "\n" + ('=' * 80)
puts 'CASE TRANSFORMER NESTED SECTIONS TEST'
puts ('=' * 80) + "\n"

# Simulate exactly what the frontend would send
# This is the camelCase format that arrives from frontend
frontend_data = {
  'sections' => [
    {
      'title' => 'Options',
      'multipleSelection' => true,  # camelCase from frontend
      'items' => [
        { 'title' => 'Option 1', 'subtitle' => 'First option' },
        { 'title' => 'Option 2', 'subtitle' => 'Second option' }
      ]
    }
  ],
  'receivedTitle' => 'Please select',
  'replyTitle' => 'Selection Made'
}

puts '1. FRONTEND DATA (camelCase)'
puts "   sections: #{frontend_data['sections'].inspect}"
puts "   First section keys: #{frontend_data['sections'].first.keys.inspect}"
puts "   multipleSelection: #{frontend_data['sections'].first['multipleSelection'].inspect}"
puts

# Test the CaseTransformer.from_apple_format (what controller calls)
puts '2. CALLING CaseTransformer.from_apple_format'
normalized = AppleMessagesForBusiness::CaseTransformer.from_apple_format(frontend_data)
puts "   Result class: #{normalized.class}"
puts "   Top-level keys: #{normalized.keys.inspect}"
puts

# Check the sections array
puts '3. NORMALIZED SECTIONS ARRAY'
if normalized['sections']
  puts '   sections exists: ✅'
  puts "   sections class: #{normalized['sections'].class}"
  puts "   sections length: #{normalized['sections'].length}"

  first_section = normalized['sections'].first
  puts "\n   First section:"
  puts "     Class: #{first_section.class}"
  puts "     Keys: #{first_section.keys.inspect}"
  puts "     multipleSelection (string): #{first_section['multipleSelection'].inspect}"
  puts "     multipleSelection (symbol): #{first_section[:multipleSelection].inspect}"
  puts "     multiple_selection (string): #{first_section['multiple_selection'].inspect}"
  puts "     multiple_selection (symbol): #{first_section[:multiple_selection].inspect}"
else
  puts '   sections missing: ❌'
end
puts

# Verify the transformation worked
puts '4. VERIFICATION'
if normalized['sections']&.first && normalized['sections'].first['multiple_selection'] == true
  puts '   ✅ SUCCESS: multipleSelection correctly transformed to multiple_selection'
  puts '   ✅ Value preserved: true'
elsif normalized['sections']&.first && normalized['sections'].first['multipleSelection'] == true
  puts '   ❌ FAILED: Key was NOT transformed (still camelCase)'
  puts "   ❌ This explains why service sees nil - it's checking wrong key"
else
  puts '   ❌ FAILED: Value lost or sections missing'
end
puts

# Test the reverse transformation (to_apple_format)
puts '5. REVERSE TRANSFORMATION (snake_case → camelCase)'
reversed = AppleMessagesForBusiness::CaseTransformer.to_apple_format(normalized)
puts "   First section keys: #{reversed[:sections].first.keys.inspect}"
puts "   multipleSelection (symbol): #{reversed[:sections].first[:multipleSelection].inspect}"
puts "   multiple_selection (symbol): #{reversed[:sections].first[:multiple_selection].inspect}"
if reversed[:sections].first[:multipleSelection] == true
  puts '   ✅ SUCCESS: Correctly transformed back to camelCase'
else
  puts "   ❌ FAILED: Reverse transformation didn't work"
end
puts

puts('=' * 80)
puts 'TEST COMPLETE'
puts ('=' * 80) + "\n"
