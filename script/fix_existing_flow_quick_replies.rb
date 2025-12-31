#!/usr/bin/env ruby
# frozen_string_literal: true

# Update existing Flow #5 with corrected send_quick_reply data
# This script fixes the action data structure for nodes that already exist

puts '=' * 80
puts 'Flow #5 - Fix Existing send_quick_reply Actions'
puts '=' * 80
puts

flow = BotFlow.find_by(id: 5)

unless flow
  puts '❌ ERROR: Bot Flow 5 not found'
  exit 1
end

puts "✅ Found flow: #{flow.name}"
puts

# Backup
backup_file = "tmp/flow_5_backup_pre_fix_#{Time.current.to_i}.json"
File.write(backup_file, JSON.pretty_generate(flow.flow_data))
puts "✅ Backup created: #{backup_file}"
puts

nodes = flow.flow_data['nodes'] || []
fixed_count = 0

puts '🔧 Fixing send_quick_reply actions...'
puts

# States with send_quick_reply actions that need fixing
states_to_fix = %w[
  state-name-preference
  state-ar-question-1
  state-ar-place-question
  state-continue-prompt
  state-photo-request
  state-learn-more-prompt
]

states_to_fix.each do |state_id|
  node = nodes.find { |n| n['id'] == state_id }
  next unless node

  actions = node.dig('data', 'actions') || []
  actions.each do |action|
    next unless action['type'] == 'send_quick_reply'

    # Check if it has old format
    next unless action['text'] && action['options'] && action['request_identifier']

    puts "  🔧 Fixing: #{state_id}"

    # Convert to new format
    action['title'] = action.delete('text')
    action['request_id'] = action.delete('request_identifier')

    # Convert options to items with value instead of identifier
    old_options = action.delete('options')
    action['items'] = old_options.map do |opt|
      {
        'title' => opt['title'],
        'value' => opt['identifier'] || opt['value']
      }
    end

    action['message'] = nil

    fixed_count += 1
    puts '     ✅ Fixed send_quick_reply data structure'
  end
end

puts
puts "📊 Summary: Fixed #{fixed_count} send_quick_reply actions"
puts

if fixed_count > 0
  # Save the flow
  flow.flow_data = {
    'nodes' => nodes,
    'edges' => flow.flow_data['edges']
  }

  puts '💾 Saving updated flow...'
  if flow.save
    puts '✅ Flow saved successfully!'
    puts
    puts '🎉 All send_quick_reply actions fixed!'
    puts
    puts 'Next steps:'
    puts '1. Restart Rails server: ./script/dev-server.sh restart'
    puts '2. Test the bot flow'
    puts '3. Bot should now wait for user input at each quick reply'
  else
    puts '❌ ERROR: Failed to save flow'
    puts flow.errors.full_messages.join("\n")
    exit 1
  end
else
  puts 'ℹ️  No fixes needed - all actions already have correct structure'
end
