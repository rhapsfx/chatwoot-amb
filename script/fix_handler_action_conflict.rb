#!/usr/bin/env ruby
# Fix: Remove template actions from nodes that have handlers with chaining
# These handlers send messages internally and shouldn't have template actions

puts '=== Fixing Nodes with Handlers ==='
puts

flow = BotFlow.find(5)
flow_data = flow.flow_data || {}
nodes = flow_data['nodes'] || []

changes = []

# Nodes that have handlers with internal logic - should NOT have template actions
nodes_to_fix = [
  { id: 'state-welcome', handler: 'handle_welcome', reason: 'Handler sends messages and calls handle_region_prompt' },
  { id: 'state-summary-demo', handler: 'handle_summary', reason: 'Handler sends messages and calls handle_final_message' }
]

nodes_to_fix.each do |config|
  node = nodes.find { |n| n['id'] == config[:id] }
  next unless node

  handler = node.dig('data', 'handlerMethod') || node.dig('data', 'handler')
  actions = node.dig('data', 'actions') || []

  puts "#{config[:id]}:"
  puts "  Current handler: #{handler}"
  puts "  Current actions: #{actions.length} action(s)"
  puts "  Reason: #{config[:reason]}"

  if handler.present? && actions.any?
    # Remove actions - handler will handle everything
    node['data']['actions'] = []
    changes << "✅ Removed #{actions.length} actions from #{config[:id]} (handler will handle it)"
    puts '  ✅ Removed actions'
  elsif handler.blank? && actions.empty?
    # Add the handler if missing
    node['data']['handlerMethod'] = config[:handler]
    node['data']['handler'] = config[:handler]
    changes << "✅ Added handler #{config[:handler]} to #{config[:id]}"
    puts '  ✅ Added handler'
  else
    puts '  ✓ Already correct'
  end

  puts
end

if changes.any?
  flow.flow_data = flow_data
  flow.save!

  puts '=== Changes Applied ==='
  changes.each { |c| puts c }
  puts
  puts '✅ Flow updated!'
  puts
  puts 'Now restart dev server and test:'
  puts '  ./script/dev-server.sh restart'
  puts "  Then send 'start' or 'summary'"
else
  puts '✅ No changes needed - nodes already configured correctly'
end
