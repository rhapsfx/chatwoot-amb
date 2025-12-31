#!/usr/bin/env ruby
# Phase 2 Migration: Convert handler-based nodes to template-based actions
#
# This moves Bot Studio from Phase 1 (hybrid delegation) to Phase 2 (template-based)
# Removes dependence on AcousticHouseBotService handlers
#
# Usage:
#   rails runner script/migrate_to_template_actions.rb
#   rails runner script/migrate_to_template_actions.rb --dry-run

dry_run = ARGV.include?('--dry-run')

puts '=== Phase 2 Migration: Handlers → Template Actions ==='
puts
puts "Mode: #{dry_run ? 'DRY RUN (no changes will be saved)' : 'LIVE (flow will be updated)'}"
puts

# Load the flow
flow = BotFlow.find(5)
account = flow.agent_bot.account
flow_data = flow.flow_data || {}
nodes = flow_data['nodes'] || []

puts "📊 Flow: #{flow.name} (ID: #{flow.id})"
puts "🏢 Account: #{account.name} (ID: #{account.id})"
puts

# Mapping of handlers to their corresponding templates
HANDLER_TO_TEMPLATE_MAP = {
  'handle_summary' => 'ah_summary',
  'handle_menu' => 'ah_main_menu',
  'handle_list_picker_demo' => 'ah_guitar_list_picker',
  'handle_time_picker_demo' => 'ah_time_picker',
  'handle_form_demo' => 'ah_guitar_info_form'
}.freeze

changes = []

# Process each node that has a handler
nodes.each do |node|
  next unless node['type'] == 'state'

  node_id = node['id']
  handler = node.dig('data', 'handlerMethod') || node.dig('data', 'handler')
  node.dig('data', 'actions') || []

  next unless handler.present?

  # Find template name for this handler
  template_name = HANDLER_TO_TEMPLATE_MAP[handler]

  unless template_name
    puts "⚠️  #{node_id}: Handler '#{handler}' not in template map, skipping"
    next
  end

  # Find the actual template
  template = BotActionTemplate.find_by(
    account: account,
    name: template_name
  )

  unless template
    puts "❌ #{node_id}: Template '#{template_name}' not found in account #{account.id}"
    next
  end

  puts "\n#{node_id} (#{node.dig('data', 'label')}):"
  puts "  Current handler: #{handler}"
  puts "  Template: #{template_name} (ID: #{template.id})"

  # Remove handler and add template action
  node['data']['handlerMethod'] = nil
  node['data']['handler'] = nil
  node['data']['actions'] = [
    {
      'type' => 'execute_template',
      'template_id' => template.id
    }
  ]

  changes << "  ✅ Converted #{node.dig('data', 'label')}: handler → template #{template.id}"
  puts '  ✅ Converted to template action'
end

# Update flow data
flow_data['nodes'] = nodes

# Display summary
puts "\n=== Migration Summary ==="
puts "Nodes converted: #{changes.length}"
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
  puts '🎯 Bot Studio is now Phase 2 compliant:'
  puts '  - Nodes use template actions (not handlers)'
  puts '  - No dependence on AcousticHouseBotService'
  puts '  - Pure visual flow + templates'
  puts
  puts 'Test now:'
  puts "  1. Send 'summary' - should show summary list picker"
  puts "  2. Send 'form' - should show guitar info form"
  puts "  3. Send 'menu' - should show main menu"
  puts
else
  puts '✅ No changes needed - flow already uses template actions!'
end

# Show current node configuration
puts '=== Current Node Configuration ==='
state_nodes = nodes.select { |n| n['type'] == 'state' }

state_nodes.each do |node|
  handler = node.dig('data', 'handlerMethod') || node.dig('data', 'handler')
  actions = node.dig('data', 'actions') || []

  status = if handler.present?
             '❌ Phase 1 (handler-based)'
           elsif actions.any? && actions.first['type'] == 'execute_template'
             '✅ Phase 2 (template-based)'
           elsif actions.any?
             '⚠️  Has actions (unknown type)'
           else
             '⚠️  No handler or actions'
           end

  puts "#{status} - #{node.dig('data', 'label')}"
end
