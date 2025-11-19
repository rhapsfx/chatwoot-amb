#!/usr/bin/env ruby
# frozen_string_literal: true

# Check bot status and recent conversations
puts '🔍 Bot Status Check'
puts '=' * 60

# Find AMB inbox
inbox = Inbox.where(channel_type: 'Channel::AppleMessagesForBusiness').first

unless inbox
  puts '❌ No Apple Messages for Business inbox found'
  exit 1
end

puts "✅ Found AMB inbox: #{inbox.name} (ID: #{inbox.id})"
puts ''

# Check AgentBot assignment
bot = inbox.agent_bot
if bot
  puts '🤖 AgentBot Status: ✅ ASSIGNED'
  puts "   Name: #{bot.name}"
  puts "   ID: #{bot.id}"
  puts '   Messages will appear as the bot'
else
  puts '🤖 AgentBot Status: ❌ NOT ASSIGNED'
  puts '   Messages will appear as the current user'
  puts '   💡 Fix it by running: rails runner script/setup_acoustic_house_bot.rb'
end
puts ''

# Find recent conversations
recent_convos = inbox.conversations.order(created_at: :desc).limit(5)

puts "📊 Recent #{recent_convos.count} conversations:"
puts ''

recent_convos.each do |convo|
  custom_attrs = convo.custom_attributes || {}
  bot_enabled = custom_attrs['bot_enabled']
  bot_state = custom_attrs['bot_state']

  puts "Conversation ID: #{convo.id}"
  puts "  Contact: #{convo.contact.name}"
  puts "  Status: #{convo.status}"
  puts "  Bot Enabled: #{bot_enabled.inspect}"
  puts "  Bot State: #{bot_state.inspect}"
  puts "  Last Activity: #{convo.last_activity_at}"
  puts "  Messages Count: #{convo.messages.count}"
  puts ''
end

puts '=' * 60
puts ''
puts '💡 To enable bot for a conversation:'
puts '   rails runner script/manage_acoustic_house_bot.rb enable CONVERSATION_ID'
