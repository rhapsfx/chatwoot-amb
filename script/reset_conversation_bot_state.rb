#!/usr/bin/env ruby
# Reset bot state for a conversation to match the flow's initial state
#
# Usage:
#   rails runner script/reset_conversation_bot_state.rb <conversation_id> [new_state]
#
# If new_state is not provided, automatically detects initial state from the flow

conversation_id = ARGV[0]&.to_i
new_state = ARGV[1] # Optional - will auto-detect if not provided

unless conversation_id
  puts 'Usage: rails runner script/reset_conversation_bot_state.rb <conversation_id> [new_state]'
  puts 'Example: rails runner script/reset_conversation_bot_state.rb 15'
  puts 'Example: rails runner script/reset_conversation_bot_state.rb 15 state-welcome'
  puts ''
  puts 'If new_state is not provided, it will be automatically detected from the flow.'
  exit 1
end

conversation = Conversation.find_by(id: conversation_id)

unless conversation
  puts "❌ Conversation #{conversation_id} not found"
  exit 1
end

puts "📋 Conversation ID: #{conversation.id}"
puts "📬 Inbox: #{conversation.inbox.name}"
puts "👤 Contact: #{conversation.contact.name}"

# Auto-detect initial state from flow if not provided
if new_state.nil?
  puts "\n🔍 Auto-detecting initial state from flow..."

  # Get the active flow for this conversation's inbox
  bot_inbox = conversation.inbox.agent_bot_inboxes
                          .active
                          .joins(:agent_bot)
                          .where(agent_bots: { bot_type: 'apple_messages_for_business' })
                          .order(priority: :asc)
                          .first

  unless bot_inbox&.agent_bot
    puts '❌ No active AMB bot found for this inbox'
    exit 1
  end

  active_flow = bot_inbox.agent_bot.bot_flows.active.published.first

  unless active_flow
    puts "❌ No active published flow found for bot: #{bot_inbox.agent_bot.name}"
    exit 1
  end

  puts "   Flow: #{active_flow.name} (ID: #{active_flow.id})"

  # Use same logic as FlowExecutorService to find initial state
  flow_data = active_flow.flow_data || {}
  nodes = flow_data['nodes'] || []

  # Look for node marked as initial
  initial_node = nodes.find { |n| n['type'] == 'state' && n.dig('data', 'is_initial') == true }

  if initial_node
    new_state = initial_node.dig('data', 'state_id') || initial_node['id']
    puts "   ✅ Found initial node: #{initial_node['id']} (#{initial_node.dig('data', 'label')})"
  else
    # Filter out test nodes
    non_test_nodes = nodes.reject { |n| n['id']&.to_s&.downcase&.include?('test') }

    # Fallback: first non-test state node
    first_state = non_test_nodes.find { |n| n['type'] == 'state' }

    if first_state
      new_state = first_state.dig('data', 'state_id') || first_state['id']
      puts "   ⚠️  No node marked as initial, using first state: #{first_state['id']} (#{first_state.dig('data', 'label')})"
    else
      puts '   ❌ No state nodes found in flow!'
      exit 1
    end
  end

  puts "   Detected state: #{new_state}"
end

attrs = conversation.additional_attributes || {}
bot_session = attrs['bot_session'] || {}
old_state = bot_session['current_state']

puts "\n🔄 Updating bot state:"
puts "  From: #{old_state || 'nil'}"
puts "  To: #{new_state}"

bot_session['current_state'] = new_state
bot_session['message_count'] = 0
bot_session['last_update'] = Time.current.iso8601
attrs['bot_session'] = bot_session

conversation.additional_attributes = attrs
conversation.save!

puts "\n✅ Bot state updated successfully"
puts "\n💡 Now send a message to the conversation to trigger the bot"
