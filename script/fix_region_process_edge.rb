#!/usr/bin/env ruby
# frozen_string_literal: true

# Fix Bot Flow 5 - Correct the edge from state-region-process
# Usage: rails runner script/fix_region_process_edge.rb

puts '=' * 80
puts 'Bot Flow 5 Edge Connection Fix'
puts '=' * 80
puts

# Find the flow
flow = BotFlow.find_by(id: 5)

unless flow
  puts '❌ ERROR: Bot Flow 5 not found'
  exit 1
end

puts "✅ Found flow: #{flow.name}"
puts

# Initialize flow_data if nil
flow.flow_data ||= { 'nodes' => [], 'edges' => [] }
nodes = flow.flow_data['nodes'] || []
edges = flow.flow_data['edges'] || []

puts '🔍 Current state:'
puts "   Total nodes: #{nodes.length}"
puts "   Total edges: #{edges.length}"
puts

# Find and remove the incorrect edge
incorrect_edge = edges.find { |e| e['source'] == 'state-region-process' && e['target'] == 'state-menu' }

if incorrect_edge
  puts '❌ Found incorrect edge: state-region-process → state-menu'
  edges.delete(incorrect_edge)
  puts '✅ Removed incorrect edge'
else
  puts 'ℹ️  No incorrect edge found (already fixed?)'
end

# Ensure the correct edge exists
correct_edge = edges.find { |e| e['source'] == 'state-region-process' && e['target'] == 'state-form-or-name-prompt' }

if correct_edge
  puts '✅ Correct edge already exists'
else
  puts '➕ Adding correct edge: state-region-process → state-form-or-name-prompt'

  # Find the nodes to get their positions for edge rendering
  source_node = nodes.find { |n| n['id'] == 'state-region-process' }
  target_node = nodes.find { |n| n['id'] == 'state-form-or-name-prompt' }

  if source_node && target_node
    edges << {
      'id' => 'edge-region-to-form-prompt',
      'source' => 'state-region-process',
      'target' => 'state-form-or-name-prompt',
      'type' => 'smoothstep',
      'label' => 'After Region Selection',
      'data' => {},
      'events' => {}
    }
    puts '✅ Added correct edge'
  else
    puts '❌ ERROR: Could not find source or target node'
    puts "   state-region-process exists: #{source_node.present?}"
    puts "   state-form-or-name-prompt exists: #{target_node.present?}"
  end
end

puts

# Also verify intent-region edge
region_intent_edge = edges.find { |e| e['source'] == 'intent-region' && e['target'] == 'state-region-process' }

if region_intent_edge
  puts '✅ Region intent properly connects to state-region-process'
else
  puts '⚠️  WARNING: No edge from intent-region to state-region-process'
  puts '   This may cause region selection to not trigger properly'
end

puts

# Update flow data
flow.flow_data = {
  'nodes' => nodes,
  'edges' => edges
}

# Save the flow
puts '💾 Saving updated flow...'
if flow.save
  puts '✅ Flow saved successfully!'
  puts
  puts '📊 Final Statistics:'
  puts "   Total nodes: #{nodes.length}"
  puts "   Total edges: #{edges.length}"
  puts
  puts '✅ Edge correction complete!'
  puts
  puts 'Next steps:'
  puts '1. Re-save the flow in Bot Studio UI to ensure it reloads'
  puts '2. Test the region selection flow'
  puts '3. Verify it now goes to form/name prompt instead of menu'
else
  puts '❌ ERROR: Failed to save flow'
  puts flow.errors.full_messages.join("\n")
  exit 1
end
