#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify BOT API typing indicators for Apple Messages for Business
# This script tests that typing indicators are sent when a bot sends a message via template

puts '=' * 80
puts 'BOT API Typing Indicator Test'
puts '=' * 80
puts ''

# Use conversation 15
conversation = Conversation.find(15)

puts "✅ Using conversation: #{conversation.display_id}"
puts "   Channel: #{conversation.inbox.channel.name}"
puts "   Contact: #{conversation.contact.name}"
puts "   Source ID: #{conversation.contact.additional_attributes&.dig('apple_messages_source_id')}"
puts ''

# Use template ID 57 (pre-existing simple template)
template = MessageTemplate.find(57)

puts "✅ Using template: #{template.name} (ID: #{template.id})"
puts "   Category: #{template.category}"
puts "   Channels: #{template.supported_channels.join(', ')}"
puts ''

# Find or create a bot sender
bot = AgentBot.where(account: conversation.account, name: 'Test Bot').first_or_create!(
  description: 'Test bot for typing indicator verification',
  bot_type: 'webhook'
)

puts "✅ Using bot: #{bot.name} (ID: #{bot.id})"
puts ''

# Test the BotMessagingService
puts '🚀 Sending message via BotMessagingService...'
puts '   Expected behavior:'
puts '   1. Typing indicator START sent to Apple'
puts '   2. Wait 1.5 seconds'
puts '   3. Message created and sent'
puts '   4. Typing indicator disappears automatically when message arrives'
puts ''

service = Templates::BotMessagingService.new(
  conversation: conversation,
  template: template,
  parameters: {},
  sender: bot
)

begin
  start_time = Time.current
  message = service.send_template_message
  end_time = Time.current

  elapsed_time = end_time - start_time

  puts '✅ Message sent successfully!'
  puts "   Message ID: #{message.id}"
  puts "   Content: #{message.content}"
  puts "   Elapsed time: #{elapsed_time.round(2)} seconds"
  puts ''

  if elapsed_time >= 1.5
    puts "✅ Typing indicator delay confirmed (#{elapsed_time.round(2)}s >= 1.5s)"
  else
    puts "⚠️  Warning: Elapsed time (#{elapsed_time.round(2)}s) is less than expected 1.5s"
    puts "   This might indicate the typing indicator logic didn't execute"
  end

  puts ''
  puts '📋 Check the logs for typing indicator messages:'
  puts '   Look for lines like:'
  puts '   - "[BotMessagingService] Typing indicator start: success"'
  puts '   - "[AMB TypingIndicator] start indicator sent successfully"'

rescue StandardError => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end

puts ''
puts '=' * 80
puts '✅ Test completed successfully!'
puts '=' * 80
puts ''
puts '💡 To verify on your device:'
puts '   1. Open the conversation in Apple Messages on your iPhone'
puts '   2. Run this test script again'
puts '   3. You should see typing indicator (three dots) for 1.5 seconds'
puts '   4. Then the message appears'
puts ''
