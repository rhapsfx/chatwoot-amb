#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to manage Acoustic House Bot settings
# Usage: rails runner script/manage_acoustic_house_bot.rb [command] [conversation_id]
#
# Commands:
#   enable [conversation_id]    - Enable bot for conversation
#   disable [conversation_id]   - Disable bot for conversation
#   reset [conversation_id]     - Reset bot state to welcome
#   status [conversation_id]    - Show bot status
#   enable-all [account_id]     - Enable bot for all AMB conversations
#   disable-all [account_id]    - Disable bot for all AMB conversations

require 'optparse'

def enable_bot(conversation_id)
  conversation = Conversation.find(conversation_id)

  unless conversation.inbox.channel_type == 'Channel::AppleMessagesForBusiness'
    puts "❌ Error: Conversation #{conversation_id} is not an Apple Messages conversation"
    exit 1
  end

  conversation.custom_attributes ||= {}
  conversation.custom_attributes['bot_enabled'] = true
  conversation.save!

  puts "✅ Bot enabled for conversation #{conversation_id}"
  show_status(conversation)
end

def disable_bot(conversation_id)
  conversation = Conversation.find(conversation_id)
  conversation.custom_attributes ||= {}
  conversation.custom_attributes['bot_enabled'] = false
  conversation.save!

  puts "✅ Bot disabled for conversation #{conversation_id}"
  show_status(conversation)
end

def reset_bot(conversation_id)
  conversation = Conversation.find(conversation_id)
  conversation.custom_attributes ||= {}
  conversation.custom_attributes['bot_state'] = 'AHA1'
  conversation.custom_attributes['bot_state_updated_at'] = Time.current.iso8601
  conversation.custom_attributes['retry_count'] = 0
  conversation.save!

  puts "✅ Bot reset to welcome state for conversation #{conversation_id}"
  show_status(conversation)
end

def show_status(conversation)
  attrs = conversation.custom_attributes || {}

  puts "\n📊 Bot Status"
  puts "  Conversation ID: #{conversation.id}"
  puts "  Channel: #{conversation.inbox.channel_type}"
  puts "  Bot Enabled: #{attrs.fetch('bot_enabled', true)}"
  puts "  Bot State: #{attrs['bot_state'] || 'AHA1 (default)'}"
  puts "  Last Updated: #{attrs['bot_state_updated_at'] || 'Never'}"
  puts "  Retry Count: #{attrs['retry_count'] || 0}"
  puts "\n📝 User Data"
  puts "  Region: #{attrs['region'] || 'Not set'}"
  puts "  Customer Name: #{attrs['customer_name'] || 'Not set'}"
  puts "  Stage Name: #{attrs['stage_name'] || 'Not set'}"
  puts "  Selected Guitar: #{attrs['selected_guitar'] || 'Not set'}"
end

def enable_all_bots(account_id)
  account = Account.find(account_id)

  # Find all Apple Messages inboxes for this account
  amb_inboxes = account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness')

  puts "Found #{amb_inboxes.count} Apple Messages inboxes"

  # Get all conversations for these inboxes
  conversations = Conversation.where(inbox_id: amb_inboxes.pluck(:id))

  puts "Found #{conversations.count} conversations"

  enabled_count = 0
  conversations.find_each do |conversation|
    conversation.custom_attributes ||= {}
    conversation.custom_attributes['bot_enabled'] = true
    conversation.save!
    enabled_count += 1
  end

  puts "✅ Bot enabled for #{enabled_count} conversations in account #{account_id}"
end

def disable_all_bots(account_id)
  account = Account.find(account_id)

  # Find all Apple Messages inboxes for this account
  amb_inboxes = account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness')

  puts "Found #{amb_inboxes.count} Apple Messages inboxes"

  # Get all conversations for these inboxes
  conversations = Conversation.where(inbox_id: amb_inboxes.pluck(:id))

  puts "Found #{conversations.count} conversations"

  disabled_count = 0
  conversations.find_each do |conversation|
    conversation.custom_attributes ||= {}
    conversation.custom_attributes['bot_enabled'] = false
    conversation.save!
    disabled_count += 1
  end

  puts "✅ Bot disabled for #{disabled_count} conversations in account #{account_id}"
end

# Parse command line arguments
command = ARGV[0]
id = ARGV[1]&.to_i

case command
when 'enable'
  unless id
    puts 'Error: conversation_id is required'
    puts 'Usage: rails runner script/manage_acoustic_house_bot.rb enable <conversation_id>'
    exit 1
  end
  enable_bot(id)
when 'disable'
  unless id
    puts 'Error: conversation_id is required'
    puts 'Usage: rails runner script/manage_acoustic_house_bot.rb disable <conversation_id>'
    exit 1
  end
  disable_bot(id)
when 'reset'
  unless id
    puts 'Error: conversation_id is required'
    puts 'Usage: rails runner script/manage_acoustic_house_bot.rb reset <conversation_id>'
    exit 1
  end
  reset_bot(id)
when 'status'
  unless id
    puts 'Error: conversation_id is required'
    puts 'Usage: rails runner script/manage_acoustic_house_bot.rb status <conversation_id>'
    exit 1
  end
  conversation = Conversation.find(id)
  show_status(conversation)
when 'enable-all'
  unless id
    puts 'Error: account_id is required'
    puts 'Usage: rails runner script/manage_acoustic_house_bot.rb enable-all <account_id>'
    exit 1
  end
  enable_all_bots(id)
when 'disable-all'
  unless id
    puts 'Error: account_id is required'
    puts 'Usage: rails runner script/manage_acoustic_house_bot.rb disable-all <account_id>'
    exit 1
  end
  disable_all_bots(id)
else
  puts 'Acoustic House Bot Manager'
  puts ''
  puts 'Usage: rails runner script/manage_acoustic_house_bot.rb [command] [id]'
  puts ''
  puts 'Commands:'
  puts '  enable [conversation_id]    - Enable bot for conversation'
  puts '  disable [conversation_id]   - Disable bot for conversation'
  puts '  reset [conversation_id]     - Reset bot state to welcome'
  puts '  status [conversation_id]    - Show bot status'
  puts '  enable-all [account_id]     - Enable bot for all AMB conversations'
  puts '  disable-all [account_id]    - Disable bot for all AMB conversations'
  puts ''
  puts 'Examples:'
  puts '  rails runner script/manage_acoustic_house_bot.rb enable 123'
  puts '  rails runner script/manage_acoustic_house_bot.rb status 123'
  puts '  rails runner script/manage_acoustic_house_bot.rb reset 123'
  puts '  rails runner script/manage_acoustic_house_bot.rb enable-all 1'
  exit 1
end
