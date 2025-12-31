#!/usr/bin/env ruby
# Check what handler methods are configured in Flow 5 state nodes

puts '=== Flow 5 State Nodes and Handlers ==='
puts

flow = BotFlow.find(5)
puts "Flow: #{flow.name} (ID: #{flow.id})"
puts

nodes = flow.flow_data['nodes'] || []
state_nodes = nodes.select { |n| n['type'] == 'state' }

puts 'State Nodes:'
state_nodes.each do |node|
  state_id = node.dig('data', 'state_id') || node['id']
  label = node.dig('data', 'label')
  handler = node.dig('data', 'handlerMethod') || node.dig('data', 'handler')
  actions = node.dig('data', 'actions') || []

  puts "\n#{state_id} (#{label}):"
  puts "  Handler: #{handler || 'none'}"
  puts "  Actions: #{actions.length > 0 ? actions.inspect : 'none'}"
  puts "  Is Initial: #{node.dig('data', 'is_initial')}"
end

puts "\n\n=== Intent Nodes and Their Connections ==="
intent_nodes = nodes.select { |n| n['type'] == 'intent' }
edges = flow.flow_data['edges'] || []

intent_nodes.each do |node|
  intent_id = node.dig('data', 'intent_id') || node['id']
  label = node.dig('data', 'label')
  keywords = node.dig('data', 'keywords') || []

  # Find outgoing edge
  outgoing = edges.find { |e| e['source'] == node['id'] }
  target = if outgoing
             target_node = nodes.find { |n| n['id'] == outgoing['target'] }
             target_node ? "#{outgoing['target']} (#{target_node.dig('data', 'label')})" : outgoing['target']
           else
             '❌ NO CONNECTION'
           end

  puts "\n#{intent_id} (#{label}):"
  puts "  Keywords: #{keywords.inspect}"
  puts "  Target: #{target}"
end
