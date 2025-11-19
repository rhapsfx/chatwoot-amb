#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to set up the Acoustic House Bot as an AgentBot in Chatwoot
# Usage: rails runner script/setup_acoustic_house_bot.rb

puts '=' * 80
puts '🤖 Setting up Acoustic House Bot'
puts '=' * 80

# Find the Apple Messages for Business inbox
inbox = Inbox.find_by(channel_type: 'Channel::AppleMessagesForBusiness')

unless inbox
  puts '❌ No Apple Messages for Business inbox found'
  exit 1
end

puts "\n✅ Found inbox: #{inbox.name} (ID: #{inbox.id})"
account = Account.find(inbox.account_id)
puts "   Account: #{account.name} (ID: #{account.id})"

# Check if an AgentBot already exists
existing_bot = inbox.agent_bot

if existing_bot
  puts "\n⚠️  AgentBot already assigned to this inbox:"
  puts "   Name: #{existing_bot.name}"
  puts "   ID: #{existing_bot.id}"
  puts "   Description: #{existing_bot.description}"

  print "\n❓ Do you want to update this bot? (y/n): "
  response = gets.chomp.downcase

  if response != 'y'
    puts "\n✋ Keeping existing bot configuration"
    exit 0
  end

  bot = existing_bot
else
  puts "\n📝 Creating new AgentBot..."

  # Create new AgentBot
  bot = AgentBot.new(
    account: account,
    name: 'Acoustic House Bot',
    description: 'Virtual assistant for the Acoustic House guitar shopping experience'
  )
end

# Update bot properties
bot.name = 'Acoustic House Bot'
bot.description = 'Virtual assistant for the Acoustic House guitar shopping experience. Helps customers select guitars, schedule lessons, and explore payment options through Apple Messages for Business.'
bot.outgoing_url = nil # Bot logic is handled internally by AcousticHouseBotService

if bot.save
  puts "\n✅ AgentBot saved successfully"
  puts "   Name: #{bot.name}"
  puts "   ID: #{bot.id}"

  # Assign bot to inbox if not already assigned
  if inbox.agent_bot == bot
    puts "\n✅ AgentBot already assigned to inbox"
  else
    inbox.agent_bot = bot
    if inbox.save
      puts "\n✅ AgentBot assigned to inbox"
    else
      puts "\n❌ Failed to assign bot to inbox: #{inbox.errors.full_messages.join(', ')}"
      exit 1
    end
  end

  puts "\n" + ('=' * 80)
  puts '🎉 SUCCESS!'
  puts '=' * 80
  puts "\nThe Acoustic House Bot is now configured as the sender for all messages."
  puts "Messages will display with the bot's identity instead of showing as the current user."
  puts "\n💡 Next steps:"
  puts "   1. Restart your Rails server if it's running"
  puts "   2. Send a message in the conversation (e.g., type 'menu')"
  puts '   3. Bot messages should now appear with the bot icon/identity'
  puts '=' * 80
else
  puts "\n❌ Failed to save AgentBot: #{bot.errors.full_messages.join(', ')}"
  exit 1
end
