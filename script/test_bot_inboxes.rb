# frozen_string_literal: true

# Test script to check bot inbox assignments API response
# Usage: rails runner script/test_bot_inboxes.rb

bot_id = 12

puts '=' * 80
puts 'Testing Bot Inbox Assignments API Response'
puts '=' * 80
puts

bot = AgentBot.find(bot_id)

puts 'Bot Details:'
puts "  ID: #{bot.id}"
puts "  Name: #{bot.name}"
puts "  Type: #{bot.bot_type}"
puts "  Account ID: #{bot.account_id}"
puts

puts "Inbox Assignments Count: #{bot.agent_bot_inboxes.count}"
puts

puts 'API Response Structure (what the frontend receives):'
puts '-' * 80

response = {
  bot_inboxes: bot.agent_bot_inboxes
                  .includes(:inbox, :version)
                  .ordered_by_priority
                  .as_json(
                    include: {
                      inbox: { only: [:id, :name, :channel_type] },
                      version: { only: [:id, :version_tag] }
                    }
                  )
}

puts JSON.pretty_generate(response)
puts

puts '=' * 80
puts 'Test Complete'
puts '=' * 80
