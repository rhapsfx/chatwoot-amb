#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to enable Acoustic House Bot for all conversations in an inbox
# Usage: rails runner script/enable_bot_for_inbox.rb <inbox_id>

inbox_id = ARGV[0]&.to_i

unless inbox_id
  puts 'Error: inbox_id is required'
  puts 'Usage: rails runner script/enable_bot_for_inbox.rb <inbox_id>'
  exit 1
end

inbox = Inbox.find(inbox_id)

unless inbox.channel_type == 'Channel::AppleMessagesForBusiness'
  puts "❌ Error: Inbox #{inbox_id} is not an Apple Messages inbox"
  puts "   Channel type: #{inbox.channel_type}"
  exit 1
end

puts "Found inbox: #{inbox.name} (ID: #{inbox_id})"
puts "Channel type: #{inbox.channel_type}"
puts ""

# Get all conversations for this inbox
conversations = Conversation.where(inbox_id: inbox_id)

puts "Found #{conversations.count} conversations in this inbox"
puts ""

enabled_count = 0
conversations.find_each do |conversation|
  conversation.custom_attributes ||= {}
  conversation.custom_attributes['bot_enabled'] = true
  conversation.save!
  enabled_count += 1
  puts "  ✅ Enabled bot for conversation #{conversation.id}"
end

puts ""
puts "🎉 Bot enabled for #{enabled_count} conversations in inbox #{inbox_id}"
