#!/usr/bin/env ruby
# frozen_string_literal: true

# Fix Migration Script - Correct send_quick_reply Data Structure
# This script updates migrate_bot_flow_to_full_acoustic_house.rb to use
# the correct data structure expected by FlowExecutorService

puts '=' * 80
puts 'Fix Migration Script - send_quick_reply Data Structure'
puts '=' * 80
puts

migration_file = 'script/migrate_bot_flow_to_full_acoustic_house.rb'

unless File.exist?(migration_file)
  puts '❌ ERROR: Migration script not found'
  puts "   Expected: #{migration_file}"
  exit 1
end

puts "✅ Found migration script: #{migration_file}"
puts

# Read the file
content = File.read(migration_file)
original_content = content.dup

# Track changes
changes_made = []

# Fix 1: state-name-preference (lines ~133-140)
old_pattern_1 = <<~RUBY
  {
    'type' => 'send_quick_reply',
    'text' => 'Which name would you like us to use?',
    'options' => [
      { 'title' => 'Real Name', 'identifier' => 'real_name' },
      { 'title' => 'Stage Name', 'identifier' => 'stage_name' }
    ],
    'request_identifier' => 'qr_name'
  }
RUBY

new_pattern_1 = <<~RUBY
  {
    'type' => 'send_quick_reply',
    'title' => 'Which name would you like us to use?',
    'request_id' => 'qr_name',
    'items' => [
      { 'title' => 'Real Name', 'value' => 'real_name' },
      { 'title' => 'Stage Name', 'value' => 'stage_name' }
    ],
    'message' => nil
  }
RUBY

if content.include?(old_pattern_1.strip)
  content.gsub!(old_pattern_1.strip, new_pattern_1.strip)
  changes_made << 'state-name-preference send_quick_reply'
  puts '✅ Fixed: state-name-preference send_quick_reply data structure'
end

# Fix 2: state-ar-question-1 (lines ~222-229)
old_pattern_2 = <<~RUBY
  {
    'type' => 'send_quick_reply',
    'text' => 'Did you get a chance to view it in AR?',
    'options' => [
      { 'title' => 'Yes', 'identifier' => 'yes' },
      { 'title' => 'No', 'identifier' => 'no' }
    ],
    'request_identifier' => 'qr_view_ar'
  }
RUBY

new_pattern_2 = <<~RUBY
  {
    'type' => 'send_quick_reply',
    'title' => 'Did you get a chance to view it in AR?',
    'request_id' => 'qr_view_ar',
    'items' => [
      { 'title' => 'Yes', 'value' => 'yes' },
      { 'title' => 'No', 'value' => 'no' }
    ],
    'message' => nil
  }
RUBY

if content.include?(old_pattern_2.strip)
  content.gsub!(old_pattern_2.strip, new_pattern_2.strip)
  changes_made << 'state-ar-question-1 send_quick_reply'
  puts '✅ Fixed: state-ar-question-1 send_quick_reply data structure'
end

# Fix 3: state-ar-place-question (lines ~268-275)
old_pattern_3 = <<~RUBY
  {
    'type' => 'send_quick_reply',
    'text' => 'Were you able to place it in your room?',
    'options' => [
      { 'title' => 'Yes', 'identifier' => 'yes' },
      { 'title' => 'No', 'identifier' => 'no' }
    ],
    'request_identifier' => 'qr_place_ar'
  }
RUBY

new_pattern_3 = <<~RUBY
  {
    'type' => 'send_quick_reply',
    'title' => 'Were you able to place it in your room?',
    'request_id' => 'qr_place_ar',
    'items' => [
      { 'title' => 'Yes', 'value' => 'yes' },
      { 'title' => 'No', 'value' => 'no' }
    ],
    'message' => nil
  }
RUBY

if content.include?(old_pattern_3.strip)
  content.gsub!(old_pattern_3.strip, new_pattern_3.strip)
  changes_made << 'state-ar-place-question send_quick_reply'
  puts '✅ Fixed: state-ar-place-question send_quick_reply data structure'
end

# Fix 4: state-continue-prompt (lines ~474-481)
old_pattern_4 = <<~RUBY
  {
    'type' => 'send_quick_reply',
    'text' => 'Shall we continue?',
    'options' => [
      { 'title' => 'Yes', 'identifier' => 'yes' },
      { 'title' => 'No', 'identifier' => 'no' }
    ],
    'request_identifier' => 'qr_continue'
  }
RUBY

new_pattern_4 = <<~RUBY
  {
    'type' => 'send_quick_reply',
    'title' => 'Shall we continue?',
    'request_id' => 'qr_continue',
    'items' => [
      { 'title' => 'Yes', 'value' => 'yes' },
      { 'title' => 'No', 'value' => 'no' }
    ],
    'message' => nil
  }
RUBY

if content.include?(old_pattern_4.strip)
  content.gsub!(old_pattern_4.strip, new_pattern_4.strip)
  changes_made << 'state-continue-prompt send_quick_reply'
  puts '✅ Fixed: state-continue-prompt send_quick_reply data structure'
end

# Fix 5: state-photo-request (lines ~540-547)
old_pattern_5 = <<~RUBY
  {
    'type' => 'send_quick_reply',
    'text' => 'Would you like to send a photo?',
    'options' => [
      { 'title' => 'Yes', 'identifier' => 'yes' },
      { 'title' => 'No', 'identifier' => 'no' }
    ],
    'request_identifier' => 'qr_photo'
  }
RUBY

new_pattern_5 = <<~RUBY
  {
    'type' => 'send_quick_reply',
    'title' => 'Would you like to send a photo?',
    'request_id' => 'qr_photo',
    'items' => [
      { 'title' => 'Yes', 'value' => 'yes' },
      { 'title' => 'No', 'value' => 'no' }
    ],
    'message' => nil
  }
RUBY

if content.include?(old_pattern_5.strip)
  content.gsub!(old_pattern_5.strip, new_pattern_5.strip)
  changes_made << 'state-photo-request send_quick_reply'
  puts '✅ Fixed: state-photo-request send_quick_reply data structure'
end

# Fix 6: state-learn-more-prompt (lines ~608-615)
old_pattern_6 = <<~RUBY
  {
    'type' => 'send_quick_reply',
    'text' => 'Would you like to learn more about Apple Messages for Business?',
    'options' => [
      { 'title' => 'Yes', 'identifier' => 'yes' },
      { 'title' => 'No', 'identifier' => 'no' }
    ],
    'request_identifier' => 'qr_learn_more'
  }
RUBY

new_pattern_6 = <<~RUBY
  {
    'type' => 'send_quick_reply',
    'title' => 'Would you like to learn more about Apple Messages for Business?',
    'request_id' => 'qr_learn_more',
    'items' => [
      { 'title' => 'Yes', 'value' => 'yes' },
      { 'title' => 'No', 'value' => 'no' }
    ],
    'message' => nil
  }
RUBY

if content.include?(old_pattern_6.strip)
  content.gsub!(old_pattern_6.strip, new_pattern_6.strip)
  changes_made << 'state-learn-more-prompt send_quick_reply'
  puts '✅ Fixed: state-learn-more-prompt send_quick_reply data structure'
end

puts

if content == original_content
  puts 'ℹ️  No changes needed - migration script already has correct data structure'
  puts
  puts 'Next step: Run the migration'
  puts '   rails runner script/migrate_bot_flow_to_full_acoustic_house.rb'
else
  # Write the updated file
  File.write(migration_file, content)

  puts '📊 Summary:'
  puts "   Changes made: #{changes_made.length}"
  changes_made.each { |change| puts "   - #{change}" }
  puts
  puts '✅ Migration script updated successfully!'
  puts
  puts 'Next step: Run the migration'
  puts '   rails runner script/migrate_bot_flow_to_full_acoustic_house.rb'
end
