#!/usr/bin/env ruby
# frozen_string_literal: true

# Test bot directly without going through webhook
puts '🧪 Direct Bot Test'
puts '=' * 60

# Find the conversation
conversation_id = ARGV[0]&.to_i || 13

conversation = Conversation.find(conversation_id)
puts "Testing with conversation #{conversation.id}"
puts ''

# Enable bot explicitly
conversation.custom_attributes ||= {}
conversation.custom_attributes['bot_enabled'] = true
conversation.custom_attributes['bot_state'] = 'AHA1'
conversation.save!

puts '✅ Bot enabled and state set to AHA1'
puts ''

# Create a test incoming message
contact = conversation.contact
message = conversation.messages.create!(
  content: 'startover',
  account_id: conversation.account_id,
  inbox_id: conversation.inbox_id,
  message_type: :incoming,
  sender: contact
)

puts "✅ Created test message: #{message.id}"
puts ''

# Trigger the bot directly
puts '🤖 Triggering bot...'
puts ''

bot_service = AppleMessagesForBusiness::AcousticHouseBotService.new(
  conversation,
  message
)

bot_service.process_message

puts ''
puts '=' * 60
puts '✅ Bot processing complete'
puts ''
puts "Check conversation #{conversation.id} for bot responses"
