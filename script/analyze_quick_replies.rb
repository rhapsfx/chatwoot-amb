#!/usr/bin/env ruby
# frozen_string_literal: true

# Count quick reply messages in conversation
conversation_id = ARGV[0]&.to_i || 13

conversation = Conversation.find(conversation_id)
puts "Conversation #{conversation.id} message analysis:"
puts ''

quick_replies = conversation.messages.where(content_type: 'apple_quick_reply').order(created_at: :desc)

puts "Total quick reply messages: #{quick_replies.count}"
puts ''

quick_replies.first(10).each do |msg|
  puts "Message ID: #{msg.id}"
  puts "  Created: #{msg.created_at}"
  puts "  Content: #{msg.content}"
  puts "  Source ID: #{msg.source_id || 'pending'}"
  puts "  Request ID from payload: #{msg.apple_msp_payload&.dig('interactiveData', 'data', 'requestIdentifier')}"
  puts ''
end
