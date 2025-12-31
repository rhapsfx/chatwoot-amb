#!/usr/bin/env ruby
# frozen_string_literal: true

# Delete Old Webhook Bot
# Removes Bot ID 6 (old "Acoustic House" webhook bot)
# Usage: rails runner script/delete_webhook_bot.rb [--execute]

DRY_RUN = !ARGV.include?('--execute')

puts '=' * 80
puts 'Delete Old Webhook Bot'
puts '=' * 80
puts "Mode: #{DRY_RUN ? 'DRY RUN' : 'EXECUTE'}"
puts

account = Account.find(1) # Acoustic House account
old_bot = AgentBot.find_by(id: 6, account: account)

unless old_bot
  puts '✅ Bot ID 6 not found - already deleted or does not exist'
  exit 0
end

puts "Found: Bot ID #{old_bot.id}"
puts "  Name: #{old_bot.name}"
puts "  Type: #{old_bot.bot_type}"
puts "  Flows: #{old_bot.bot_flows.count}"
puts

if old_bot.bot_type != 'webhook'
  puts "⚠️  Warning: This bot is not a webhook bot (type: #{old_bot.bot_type})"
  puts '   Aborting for safety. Please verify the bot ID.'
  exit 1
end

if DRY_RUN
  puts "📋 Would delete: Bot ID #{old_bot.id} - #{old_bot.name}"
  puts
  puts 'To execute: rails runner script/delete_webhook_bot.rb --execute'
else
  puts '🗑️  Deleting bot...'
  begin
    old_bot.destroy!
    puts '✅ Successfully deleted Bot ID 6'
  rescue StandardError => e
    puts "❌ Error deleting bot: #{e.message}"
    exit 1
  end
end

puts '=' * 80
