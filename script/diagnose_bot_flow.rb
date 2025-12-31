#!/usr/bin/env ruby
# Diagnostic script to check flow and conversation state

puts '=== Flow 5 Diagnostic ==='
puts

flow = BotFlow.find(5)
puts "📊 Flow: #{flow.name}"
puts "   ID: #{flow.id}"
puts "   Bot ID: #{flow.agent_bot_id}"
puts "   Active: #{flow.is_active}"
puts "   Published: #{flow.is_published}"
puts "   Metadata: #{flow.metadata.inspect}"
puts "   Initial State (from metadata): #{flow.metadata&.dig('initial_state').inspect}"
puts "   Initial State (from flow_data): #{flow.flow_data&.dig('initialState').inspect}"
puts

nodes = flow.flow_data&.dig('nodes') || []
puts '🎯 State Nodes in Flow:'
state_nodes = nodes.select { |n| n['type'] == 'state' }
state_nodes.each do |node|
  puts "   - ID: #{node['id']}, Label: #{node.dig('data', 'label')}, Handler: #{node.dig('data', 'handlerMethod')}"
end
puts

puts '🎭 Intent Nodes in Flow:'
intent_nodes = nodes.select { |n| n['type'] == 'intent' }
intent_nodes.each do |node|
  keywords = node.dig('data', 'keywords') || []
  puts "   - ID: #{node['id']}, Label: #{node.dig('data', 'label')}, Keywords: #{keywords.inspect}"
end
puts

puts '=== Conversation 15 Diagnostic ==='
puts

conversation = Conversation.find(15)
custom_attrs = conversation.custom_attributes || {}
additional_attrs = conversation.additional_attributes || {}
bot_session = additional_attrs['bot_session'] || {}

puts "💬 Conversation: #{conversation.id}"
puts "   Status: #{conversation.status}"
puts '   Custom Attributes (deprecated):'
puts "     bot_state: #{custom_attrs['bot_state'].inspect}"
puts "     bot_enabled: #{custom_attrs['bot_enabled'].inspect}"
puts '   Additional Attributes (current):'
puts "     bot_session.current_state: #{bot_session['current_state'].inspect}"
puts "     bot_session.message_count: #{bot_session['message_count'].inspect}"
puts "     bot_session.last_update: #{bot_session['last_update'].inspect}"
puts "     bot_session.flow_id: #{bot_session['flow_id'].inspect}"
puts
