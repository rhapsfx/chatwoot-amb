#!/usr/bin/env ruby
# Quick fix: Add Welcome → Region edge and simplify demo handlers
#
# Usage:
#   rails runner script/quick_fix_welcome_flow.rb

puts '=== Quick Fix: Welcome Flow ==='
puts

flow = BotFlow.find(5)
flow_data = flow.flow_data || {}
nodes = flow_data['nodes'] || []
edges = flow_data['edges'] || []

changes = []

# Fix 1: Add Welcome → Region edge
welcome_node = nodes.find { |n| n['id'] == 'state-welcome' }
region_node = nodes.find { |n| n['id'] == 'state-region-process' }

if welcome_node && region_node
  existing_edge = edges.find { |e| e['source'] == 'state-welcome' && e['target'] == 'state-region-process' }

  if existing_edge
    puts '✅ Welcome → Region edge already exists'
  else
    new_edge = {
      'id' => 'edge-welcome-region',
      'source' => 'state-welcome',
      'target' => 'state-region-process',
      'type' => 'smoothstep'
    }
    edges << new_edge
    changes << '✅ Added edge: Welcome → Process Region (handles auto-continuation)'
  end
else
  puts '❌ Could not find welcome or region nodes'
end

# Fix 2: Simplify demo handlers by using template actions
demo_simplifications = [
  {
    node_id: 'state-form-demo',
    handler: 'handle_form_demo',
    template_name: 'ah_guitar_info_form',
    label: 'Form Demo'
  },
  {
    node_id: 'state-summary-demo',
    handler: 'handle_summary',
    template_name: 'ah_summary',
    label: 'Summary Demo'
  }
]

demo_simplifications.each do |config|
  node = nodes.find { |n| n['id'] == config[:node_id] }
  next unless node

  # Find the template
  template = BotActionTemplate.find_by(name: config[:template_name])

  if template
    # Remove handler, add template action
    node['data']['handlerMethod'] = nil
    node['data']['handler'] = nil
    node['data']['actions'] = [
      { 'type' => 'execute_template', 'template_id' => template.id }
    ]

    changes << "✅ Simplified #{config[:label]}: Removed handler, using template #{template.id}"
  else
    puts "⚠️  Template '#{config[:template_name]}' not found for #{config[:label]}"
  end
end

# Update flow
flow_data['nodes'] = nodes
flow_data['edges'] = edges

if changes.any?
  flow.flow_data = flow_data
  flow.save!

  puts "\n=== Changes Applied ==="
  changes.each { |c| puts c }
  puts
  puts '✅ Flow updated successfully!'
  puts
  puts 'Test now:'
  puts "  1. Send 'start' - should show welcome + region selection"
  puts "  2. Send 'form' - should show form demo"
  puts "  3. Send 'summary' - should show summary"
else
  puts '✅ No changes needed!'
end
