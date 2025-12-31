#!/usr/bin/env ruby
# Debug script for list picker multiple_selection issue
#
# Usage:
#   rails runner script/debug_list_picker_multiselect.rb
#
# This script tests the transformation logic in SendListPickerService
# to verify that multiple_selection: true is preserved through the process

puts "\n" + ('=' * 80)
puts 'LIST PICKER MULTIPLE_SELECTION DEBUG SCRIPT'
puts ('=' * 80) + "\n"

# Test data - simulating what comes from the frontend/controller
test_section = {
  'title' => 'Test Section',
  'multiple_selection' => true,  # This is the value we're testing
  'items' => [
    { 'title' => 'Option 1', 'subtitle' => 'First option' },
    { 'title' => 'Option 2', 'subtitle' => 'Second option' }
  ]
}

puts '1. ORIGINAL SECTION (from controller)'
puts "   multiple_selection = #{test_section['multiple_selection'].inspect}"
puts "   Type: #{test_section['multiple_selection'].class}"
puts

# Test the old approach (using ||)
puts '2. OLD APPROACH (using ||)'
old_approach = test_section.merge(
  'order' => test_section['order'] || 0,
  'multiple_selection' => test_section['multiple_selection'] || false
)
puts "   multiple_selection = #{old_approach['multiple_selection'].inspect}"
puts "   Result: #{old_approach['multiple_selection'] == true ? '✅ PRESERVED' : '❌ LOST'}"
puts

# Test the new approach (using fetch)
puts '3. NEW APPROACH (using fetch)'
new_approach = test_section.merge(
  'order' => test_section.fetch('order', 0),
  'multiple_selection' => test_section.fetch('multiple_selection', false)
)
puts "   multiple_selection = #{new_approach['multiple_selection'].inspect}"
puts "   Result: #{new_approach['multiple_selection'] == true ? '✅ PRESERVED' : '❌ LOST'}"
puts

# Test CaseTransformer
puts '4. CASE TRANSFORMER (snake_case → camelCase)'
require_relative '../app/services/apple_messages_for_business/case_transformer'
transformed = AppleMessagesForBusiness::CaseTransformer.to_apple_format(new_approach)
puts "   Full transformed keys: #{transformed.keys.inspect}"
puts "   multipleSelection (symbol) = #{transformed[:multipleSelection].inspect}"
puts "   multipleSelection (string) = #{transformed['multipleSelection'].inspect}"
puts "   Result: #{transformed[:multipleSelection] == true ? '✅ PRESERVED' : '❌ LOST'}"
puts

# Test with false value
puts '5. TEST WITH FALSE VALUE (edge case)'
false_section = test_section.merge('multiple_selection' => false)

old_false = false_section.merge(
  'multiple_selection' => false_section['multiple_selection'] || false
)
new_false = false_section.merge(
  'multiple_selection' => false_section.fetch('multiple_selection', false)
)

puts "   OLD approach: #{old_false['multiple_selection'].inspect} (should be false)"
puts "   NEW approach: #{new_false['multiple_selection'].inspect} (should be false)"
puts "   Both correct: #{old_false['multiple_selection'] == false && new_false['multiple_selection'] == false ? '✅' : '❌'}"
puts

# Test with nil value
puts '6. TEST WITH NIL VALUE (edge case)'
nil_section = test_section.dup
nil_section.delete('multiple_selection')

old_nil = nil_section.merge(
  'multiple_selection' => nil_section['multiple_selection'] || false
)
new_nil = nil_section.merge(
  'multiple_selection' => nil_section.fetch('multiple_selection', false)
)

puts "   OLD approach: #{old_nil['multiple_selection'].inspect} (should be false)"
puts "   NEW approach: #{new_nil['multiple_selection'].inspect} (should be false)"
puts "   Both correct: #{old_nil['multiple_selection'] == false && new_nil['multiple_selection'] == false ? '✅' : '❌'}"
puts

# Summary
puts "\n" + ('=' * 80)
puts 'SUMMARY'
puts('=' * 80)
puts
puts 'The fetch() approach correctly handles:'
puts '  ✅ true values (preserves true)'
puts '  ✅ false values (preserves false)'
puts '  ✅ nil/missing values (uses default false)'
puts
puts 'The || approach incorrectly handles:'
puts '  ⚠️  May treat false as falsy and replace with default'
puts '  (Though in this case, both seem to work for true/false)'
puts
puts 'Recommendation: Use fetch() for clarity and correctness'
puts ('=' * 80) + "\n"
