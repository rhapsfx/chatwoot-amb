#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script for bot issues
# Usage: rails runner script/debug_bot.rb [conversation_id]

conversation_id = ARGV[0]&.to_i

unless conversation_id
  puts 'Usage: rails runner script/debug_bot.rb <conversation_id>'
  exit 1
end

conversation = Conversation.find(conversation_id)

puts "🔍 Bot Debug Info for Conversation #{conversation_id}"
puts ''
puts '📱 Conversation Details'
puts "  ID: #{conversation.id}"
puts "  Inbox: #{conversation.inbox.name} (#{conversation.inbox.id})"
puts "  Channel Type: #{conversation.inbox.channel_type}"
puts "  Contact: #{conversation.contact.name} (#{conversation.contact.id})"
puts "  Status: #{conversation.status}"
puts ''

attrs = conversation.custom_attributes || {}
puts '🤖 Bot Configuration'
puts "  Enabled: #{attrs.fetch('bot_enabled', true)}"
puts "  State: #{attrs['bot_state'] || 'AHA1 (default)'}"
puts "  Last Updated: #{attrs['bot_state_updated_at'] || 'Never'}"
puts "  Retry Count: #{attrs['retry_count'] || 0}"
puts ''

puts '📝 User Data'
puts "  Region: #{attrs['region'] || 'Not set'}"
puts "  Customer Name: #{attrs['customer_name'] || 'Not set'}"
puts "  Stage Name: #{attrs['stage_name'] || 'Not set'}"
puts "  Selected Guitar: #{attrs['selected_guitar'] || 'Not set'}"
puts ''

puts '💬 Recent Messages (last 5)'
conversation.messages.order(created_at: :desc).limit(5).each do |msg|
  direction = msg.incoming? ? '←' : '→'
  sender = msg.incoming? ? 'User' : 'Bot'
  puts "  #{direction} #{sender}: #{msg.content.truncate(50)} (#{msg.created_at.strftime('%H:%M:%S')})"
end
puts ''

puts '🔧 Actions Available'
puts '  1. Reset bot state:'
puts "     rails runner script/manage_acoustic_house_bot.rb reset #{conversation_id}"
puts ''
puts '  2. Manually trigger bot with test message:'
puts "     rails runner script/debug_bot.rb #{conversation_id} trigger"
puts ''
puts '  3. View live logs:'
puts "     tail -f log/development.log | grep '[Bot]'"
puts ''

# If 'trigger' argument provided, manually trigger the bot
if ARGV[1] == 'trigger'
  puts '🚀 Manually triggering bot...'

  # Create a test incoming message
  message = Messages::MessageBuilder.new(
    conversation.contact,
    conversation,
    {
      content: 'test trigger',
      message_type: :incoming
    }
  ).perform

  puts "  Created test message: #{message.id}"

  # Manually trigger the bot service
  bot_service = AppleMessagesForBusiness::AcousticHouseBotService.new(
    conversation,
    message
  )

  puts '  Calling process_message...'
  bot_service.process_message

  puts '  ✅ Bot triggered!'
  puts ''
  puts '  Check messages:'
  conversation.messages.order(created_at: :desc).limit(3).each do |msg|
    direction = msg.incoming? ? '←' : '→'
    sender = msg.incoming? ? 'User' : 'Bot'
    puts "    #{direction} #{sender}: #{msg.content.truncate(50)}"
  end
end
