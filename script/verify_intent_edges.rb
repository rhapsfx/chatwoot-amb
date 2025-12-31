#!/usr/bin/env ruby
# Verify actual intent node IDs and their edges

flow = BotFlow.find(5)
nodes = flow.flow_data['nodes'] || []
edges = flow.flow_data['edges'] || []

puts '=== Intent Nodes (Actual IDs) ==='
intent_nodes = nodes.select { |n| n['type'] == 'intent' }

intent_nodes.each do |node|
  puts "\nNode ID (actual): #{node['id']}"
  puts "  data.intent_id: #{node.dig('data', 'intent_id')}"
  puts "  Label: #{node.dig('data', 'label')}"
  puts "  Keywords: #{node.dig('data', 'keywords')&.first(2)&.join(', ')}"

  # Find edge with this node as source
  edge = edges.find { |e| e['source'] == node['id'] }
  if edge
    target_node = nodes.find { |n| n['id'] == edge['target'] }
    puts "  ✅ Edge found: #{edge['id']}"
    puts "     Target: #{edge['target']} (#{target_node&.dig('data', 'label')})"
  else
    puts '  ❌ No edge found'
  end
end
