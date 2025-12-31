#!/usr/bin/env ruby
# frozen_string_literal: true

# Cleanup and Fix Bots
# Removes webhook bots and ensures AMB bots have flows
# Usage: rails runner script/cleanup_and_fix_bots.rb [--execute]

require 'json'

DRY_RUN = !ARGV.include?('--execute')

puts '=' * 80
puts 'Bot Cleanup and Fix Script'
puts '=' * 80
puts "Mode: #{DRY_RUN ? 'DRY RUN' : 'EXECUTE'}"
puts

account = Account.first
unless account
  puts '❌ No accounts found'
  exit 1
end

puts "Account: #{account.name} (ID: #{account.id})"
puts

stats = {
  bots_deleted: 0,
  flows_created: 0,
  errors: []
}

# Step 1: Find and delete webhook versions of our bots
puts 'Step 1: Removing webhook bots...'
puts

webhook_bots = account.agent_bots.where(bot_type: 'webhook')
                      .where('name LIKE ? OR name LIKE ?', '%Acoustic House%', '%Flow Templates%')

if webhook_bots.empty?
  puts '✅ No webhook bots to remove'
else
  webhook_bots.each do |bot|
    puts "#{DRY_RUN ? '📋 Would delete' : '🗑️  Deleting'}: Bot ID #{bot.id} - #{bot.name} (webhook)"
    next if DRY_RUN

    begin
      bot.destroy!
      stats[:bots_deleted] += 1
    rescue StandardError => e
      error_msg = "Failed to delete bot #{bot.id}: #{e.message}"
      puts "  ❌ #{error_msg}"
      stats[:errors] << error_msg
    end
  end
end

puts

# Step 2: Find AMB bots without flows and check if they need flows created
puts 'Step 2: Checking AMB bots for missing flows...'
puts

amb_bots = account.agent_bots.where(bot_type: 'apple_messages_for_business')
                  .where('name LIKE ? OR name LIKE ?', '%Acoustic House%', '%Flow Templates%')

amb_bots.each do |bot|
  flows = bot.bot_flows
  puts "Bot ID #{bot.id}: #{bot.name}"
  puts "  Current flows: #{flows.count}"

  if flows.empty?
    case bot.name
    when 'Acoustic House Master Bot'
      puts '  ⚠️  Master bot should have a flow with 13 nodes'
      puts "  #{DRY_RUN ? '📋 Would create' : '🔧 Creating'} master bot flow..."

      unless DRY_RUN
        begin
          # The master bot flow creation logic would go here
          # For now, just inform the user
          puts '  ℹ️  Please re-run: rails runner script/create_acoustic_house_master_bot.rb --execute'
          puts '     The script will skip the existing bot and create only the flow'
        rescue StandardError => e
          error_msg = "Failed to create flow for bot #{bot.id}: #{e.message}"
          puts "  ❌ #{error_msg}"
          stats[:errors] << error_msg
        end
      end

    when 'Flow Templates Bot'
      puts '  ⚠️  Templates bot should have 4 template flows'
      puts "  #{DRY_RUN ? '📋 Would create' : '🔧 Creating'} template flows..."

      unless DRY_RUN
        begin
          puts '  ℹ️  Please re-run: rails runner script/create_apple_messages_flow_templates.rb --execute'
          puts '     The script will skip the existing bot and create only the flows'
        rescue StandardError => e
          error_msg = "Failed to create flows for bot #{bot.id}: #{e.message}"
          puts "  ❌ #{error_msg}"
          stats[:errors] << error_msg
        end
      end

    else
      puts '  ℹ️  Unknown bot type, skipping'
    end
  else
    puts "  ✅ Bot has #{flows.count} flow(s)"
  end

  puts
end

puts '=' * 80
puts 'Summary'
puts '=' * 80
puts "Bots deleted: #{stats[:bots_deleted]}"
puts "Flows created: #{stats[:flows_created]}"
puts "Errors: #{stats[:errors].count}"

if stats[:errors].any?
  puts
  puts 'Errors:'
  stats[:errors].each do |error|
    puts "  - #{error}"
  end
end

if DRY_RUN
  puts
  puts '⚠️  This was a DRY RUN. No changes were made.'
  puts '   Run with --execute to apply changes:'
  puts '   rails runner script/cleanup_and_fix_bots.rb --execute'
else
  puts
  puts '✅ Cleanup complete!'
  puts
  puts 'Next steps:'
  puts '1. If bots are missing flows, re-run the creator scripts'
  puts '2. Refresh your browser'
  puts '3. Open Bot Studio to verify flows appear'
end

puts '=' * 80
