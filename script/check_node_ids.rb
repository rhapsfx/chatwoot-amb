#!/usr/bin/env ruby
# Quick check: What are the actual node IDs?

flow = BotFlow.find(5)
nodes = flow.flow_data['nodes'] || []

puts '=== State Node IDs ==='
nodes.select { |n| n['type'] == 'state' }.each do |node|
  state_id = node.dig('data', 'state_id')
  label = node.dig('data', 'label')
  puts "Node ID: #{node['id'].ljust(30)} | state_id: #{state_id} | label: #{label}"
end
