#!/usr/bin/env ruby
# Phase 4: Connect intent nodes to state nodes
#
# This script adds missing edges from intent nodes to appropriate state nodes
# and creates new demo state nodes where needed
#
# Usage:
#   rails runner script/connect_intent_nodes.rb
#   rails runner script/connect_intent_nodes.rb --dry-run

dry_run = ARGV.include?('--dry-run')

puts '=== Phase 4: Connecting Intent Nodes to State Nodes ==='
puts
puts "Mode: #{dry_run ? 'DRY RUN (no changes will be saved)' : 'LIVE (flow will be updated)'}"
puts

# Load the flow
flow = BotFlow.find(5)
flow_data = flow.flow_data || {}
nodes = flow_data['nodes'] || []
edges = flow_data['edges'] || []

puts "📊 Flow: #{flow.name} (ID: #{flow.id})"
puts "📍 Current nodes: #{nodes.length}, edges: #{edges.length}"
puts

# Define required connections
# Maps intent node IDs to their target state node IDs
# IMPORTANT: Node IDs use hyphens, not underscores!
INTENT_CONNECTIONS = {
  'intent-menu' => 'state-menu',
  'intent-start_over' => 'state-welcome',
  'intent-time-picker-demo' => 'state-time-picker-demo',  # NOTE: hyphens in node ID
  'intent-form-demo' => 'state-form-demo',                # NOTE: hyphens in node ID
  'intent-summary' => 'state-summary-demo'
  # NOTE: list_picker_demo already has a connection (to condition-check-region)
}.freeze

# Map to existing AHA nodes if available
# This ensures we use existing nodes instead of creating duplicates
EXISTING_NODE_FALLBACKS = {
  'state-menu' => 'state-AHA3',
  'state-welcome' => 'state-AHA1'
}.freeze

# Define new state nodes for demos that don't have existing states
NEW_DEMO_STATES = [
  {
    id: 'state-time-picker-demo',
    label: 'Time Picker Demo',
    handler: 'handle_time_picker_demo',
    position: { x: 800, y: 400 }
  },
  {
    id: 'state-form-demo',
    label: 'Form Demo',
    handler: 'handle_form_demo',
    position: { x: 800, y: 600 }
  },
  {
    id: 'state-summary-demo',
    label: 'Summary Demo',
    handler: 'handle_summary',
    position: { x: 800, y: 800 }
  },
  {
    id: 'state-menu',
    label: 'Menu',
    handler: 'handle_menu',
    position: { x: 800, y: 200 }
  }
].freeze

changes = []
created_nodes = []
created_edges = []

# Step 1: Create missing state nodes
NEW_DEMO_STATES.each do |state_config|
  existing = nodes.find { |n| n['id'] == state_config[:id] }

  if existing
    puts "  ✓ State node already exists: #{state_config[:id]}"
  else
    new_node = {
      'id' => state_config[:id],
      'type' => 'state',
      'position' => state_config[:position],
      'data' => {
        'label' => state_config[:label],
        'state_id' => state_config[:id].gsub('state-', '').upcase,
        'handlerMethod' => state_config[:handler],
        'actions' => []
      }
    }

    nodes << new_node
    created_nodes << state_config[:id]
    changes << "  + Created state node: #{state_config[:label]} (#{state_config[:id]})"
  end
end

# Step 2: Create missing edges
INTENT_CONNECTIONS.each do |intent_id, target_state_id|
  # Check if edge already exists
  existing_edge = edges.find { |e| e['source'] == intent_id }

  if existing_edge
    if existing_edge['target'] == target_state_id
      puts "  ✓ Edge already correct: #{intent_id} → #{target_state_id}"
    else
      puts "  ⚠️  Edge exists but targets different node: #{intent_id} → #{existing_edge['target']}"
      puts "     Expected: #{target_state_id}"
      changes << "  ! Edge mismatch: #{intent_id} currently points to #{existing_edge['target']}, should point to #{target_state_id}"
    end
  else
    # Get the intent node to extract its label
    intent_node = nodes.find { |n| n['id'] == intent_id }
    intent_label = intent_node&.dig('data', 'label') || intent_id

    # Get the target node to extract its label
    target_node = nodes.find { |n| n['id'] == target_state_id }
    target_label = target_node&.dig('data', 'label') || target_state_id

    # Create new edge
    new_edge = {
      'id' => "edge-#{intent_id}-#{target_state_id}",
      'source' => intent_id,
      'target' => target_state_id,
      'type' => 'smoothstep'
    }

    edges << new_edge
    created_edges << new_edge['id']
    changes << "  → Created edge: #{intent_label} → #{target_label}"
  end
end

# Step 3: Fix list_picker_demo connection if it's wrong
list_picker_intent = nodes.find { |n| n['id'] == 'intent-list_picker_demo' }
if list_picker_intent
  existing_edge = edges.find { |e| e['source'] == 'intent-list_picker_demo' }

  if existing_edge && existing_edge['target'] == 'condition-check-region'
    puts "\n  ⚠️  List Picker Demo is connected to 'Check Region' condition"
    puts '     This may be intentional (enters the conversation flow)'
    puts '     Or you may want to create a demo state that just shows the picker'
  end
end

# Update flow data
flow_data['nodes'] = nodes
flow_data['edges'] = edges

# Display summary
puts "\n=== Migration Summary ==="
puts "State nodes created: #{created_nodes.length}"
puts "Edges created: #{created_edges.length}"
puts "Total changes: #{changes.length}"
puts

if changes.any?
  puts 'Changes:'
  changes.each { |change| puts change }
  puts
end

# Save the flow
if dry_run
  puts '🔍 DRY RUN - No changes saved'
  puts '   Run without --dry-run to apply these changes'
  puts
elsif changes.any?
  flow.flow_data = flow_data
  flow.save!

  puts '✅ Flow updated successfully!'
  puts
  puts 'Next steps:'
  puts '  1. Open Bot Studio UI and verify the connections'
  puts "  2. Test keywords: 'menu', 'form', 'time picker', 'summary', 'start'"
  puts '  3. Verify each intent routes to the correct state'
  puts
else
  puts '✅ No changes needed - flow is already configured!'
  puts
end

# Display final state
puts '=== Final Flow Configuration ==='
intent_nodes = nodes.select { |n| n['type'] == 'intent' }

intent_nodes.each do |node|
  node.dig('data', 'intent_id') || node['id']
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

  status = outgoing ? '✅' : '❌'

  puts "#{status} #{label}:"
  puts "   Keywords: #{keywords.first(3).join(', ')}#{keywords.length > 3 ? '...' : ''}"
  puts "   Target: #{target}"
  puts
end
