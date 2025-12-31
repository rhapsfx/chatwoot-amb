#!/usr/bin/env ruby
# frozen_string_literal: true

# Master Implementation Script for Flow #5
# Executes all necessary steps to implement full Acoustic House bot

puts '=' * 80
puts 'Flow #5 Full Implementation - Master Script'
puts '=' * 80
puts

puts 'This script will:'
puts '1. Fix migration script data structure'
puts '2. Run migration to add all 29 missing nodes'
puts '3. Fix handler names'
puts '4. Activate the flow'
puts '5. Verify implementation'
puts

puts 'Press ENTER to continue or Ctrl+C to cancel'
gets

# Step 1: Fix Migration Script
puts
puts '=' * 80
puts 'Step 1: Fix Migration Script send_quick_reply Data Structure'
puts '=' * 80
puts

system('ruby script/fix_migration_quick_reply_data.rb')

unless $?.success?
  puts
  puts '❌ ERROR: Failed to fix migration script'
  exit 1
end

# Step 2: Run Migration
puts
puts '=' * 80
puts 'Step 2: Run Migration Script'
puts '=' * 80
puts

system('rails runner script/migrate_bot_flow_to_full_acoustic_house.rb')

unless $?.success?
  puts
  puts '❌ ERROR: Migration failed'
  exit 1
end

# Step 3: Fix Handler Names
puts
puts '=' * 80
puts 'Step 3: Fix Handler Names'
puts '=' * 80
puts

system('rails runner script/fix_flow_handler_names.rb')

unless $?.success?
  puts
  puts '❌ ERROR: Failed to fix handler names'
  exit 1
end

# Step 4: Activate Flow
puts
puts '=' * 80
puts 'Step 4: Activate Flow #5'
puts '=' * 80
puts

system('rails runner script/activate_master_bot_flow.rb')

unless $?.success?
  puts
  puts '❌ ERROR: Failed to activate flow'
  exit 1
end

# Step 5: Verify Implementation
puts
puts '=' * 80
puts 'Step 5: Verification'
puts '=' * 80
puts

system('ruby tmp/check_flow_migration.rb')

puts
puts '=' * 80
puts '✅ Implementation Complete!'
puts '=' * 80
puts

puts 'Next Steps:'
puts '1. Restart Rails server: ./script/dev-server.sh restart'
puts '2. Test the bot flow end-to-end'
puts '3. Monitor logs for: [Bot] 🚀 Using FlowExecutorService for visual bot flow'
puts '4. Verify no auto-transition issues'
puts '5. Check that bot waits for user input at each state'
puts

puts 'Testing Checklist:'
puts '□ Send "startover" to bot'
puts '□ Verify welcome message appears'
puts '□ Select region (interactive or text "americas")'
puts '□ Verify name collection prompt'
puts '□ Complete form or enter name as text'
puts '□ Select name preference'
puts '□ Select guitar from list picker'
puts '□ View AR file'
puts '□ Answer AR questions'
puts '□ Complete Apple Pay (demo)'
puts '□ Enter location (zipcode + city)'
puts '□ Select store'
puts '□ Select time slot'
puts '□ Upload photo (optional)'
puts '□ Complete flow'
puts

puts 'If issues occur:'
puts '- Check logs in log/development.log'
puts '- Look for [FlowExecutor] warnings'
puts '- Verify send_quick_reply actions have correct data'
puts '- Check that Flow #5 is active and published'
puts
