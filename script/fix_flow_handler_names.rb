#!/usr/bin/env ruby
# frozen_string_literal: true

# Fix Bot Flow 5 - Correct handler names in flow nodes
# Usage: rails runner script/fix_flow_handler_names.rb

puts '=' * 80
puts 'Bot Flow 5 Handler Name Correction'
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

puts '🔍 Searching for nodes with incorrect handler names...'
puts

# Track changes
changes_made = []

# Fix handler names in nodes
nodes.each do |node|
  next unless node['type'] == 'state'
  next unless node['data'] && node['data']['actions']

  node['data']['actions'].each do |action|
    next unless action['type'] == 'execute_custom_code'

    old_handler = action['handler']
    new_handler = nil

    case old_handler
    when 'handle_apple_pay_retry'
      new_handler = 'handle_apple_pay_catcher'
    when 'handle_ar_view_retry'
      new_handler = 'handle_ar_view_catcher'
    when 'handle_guitar_retry_logic'
      new_handler = 'handle_guitar_list_catcher'
    when 'send_apple_pay_request'
      new_handler = 'handle_send_apple_pay_request'
    when 'handle_location_geocoding'
      # This handler might not exist - check what it should actually be
      puts "⚠️  WARNING: Found 'handle_location_geocoding' in node #{node['id']}"
      puts "   This handler needs review - might need to be 'handle_location_response'"
    end

    next unless new_handler

    action['handler'] = new_handler
    changes_made << {
      node: node['id'],
      label: node['data']['label'],
      old: old_handler,
      new: new_handler
    }
    puts "✅ #{node['id']} (#{node['data']['label']}): #{old_handler} → #{new_handler}"
  end
end

puts
puts "📊 Summary: #{changes_made.length} handler names corrected"
puts

if changes_made.any?
  changes_made.each do |change|
    puts "  • #{change[:label]}: #{change[:old]} → #{change[:new]}"
  end
  puts

  # Save the flow
  flow.flow_data = {
    'nodes' => nodes,
    'edges' => flow.flow_data['edges']
  }

  puts '💾 Saving updated flow...'
  if flow.save
    puts '✅ Flow saved successfully!'
    puts
    puts '📋 Changes Applied:'
    puts "   - Fixed #{changes_made.length} incorrect handler names"
    puts
    puts '🔄 Next Steps:'
    puts '1. Restart the Rails server to pick up changes'
    puts '2. Test the bot flow end-to-end'
    puts '3. Verify all handlers are now called correctly'
  else
    puts '❌ ERROR: Failed to save flow'
    puts flow.errors.full_messages.join("\n")
    exit 1
  end
else
  puts 'ℹ️  No handler name corrections needed'
end
