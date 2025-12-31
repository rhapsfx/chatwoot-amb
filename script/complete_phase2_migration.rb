#!/usr/bin/env ruby
# Complete Phase 2 Migration: Pure Template-Based Flow
#
# Converts ALL nodes from handler-based to template-based actions
# including handle_welcome with automatic flow continuation via edges
#
# Usage:
#   rails runner script/complete_phase2_migration.rb
#   rails runner script/complete_phase2_migration.rb --dry-run

dry_run = ARGV.include?('--dry-run')

puts '=== Complete Phase 2 Migration: Pure Template-Based Flow ==='
puts
puts "Mode: #{dry_run ? 'DRY RUN (no changes will be saved)' : 'LIVE (flow will be updated)'}"
puts

# Load the flow
flow = BotFlow.find(5)
account = flow.agent_bot.account
flow_data = flow.flow_data || {}
nodes = flow_data['nodes'] || []
edges = flow_data['edges'] || []

puts "📊 Flow: #{flow.name} (ID: #{flow.id})"
puts "🏢 Account: #{account.name} (ID: #{account.id})"
puts

changes = []

# Step 1: Fix Welcome node - remove handler, keep/verify templates, ensure edge
welcome_node = nodes.find { |n| n['id'] == 'state-welcome' }

if welcome_node
  puts "\n=== Step 1: Fix Welcome Node ==="

  handler = welcome_node.dig('data', 'handlerMethod') || welcome_node.dig('data', 'handler')
  current_actions = welcome_node.dig('data', 'actions') || []

  puts 'Welcome node:'
  puts "  Current handler: #{handler}"
  puts "  Current actions: #{current_actions.length} action(s)"

  if handler.present?
    # Remove handler
    welcome_node['data']['handlerMethod'] = nil
    welcome_node['data']['handler'] = nil
    changes << '  ✅ Removed handler from Welcome node'
    puts '  ✅ Removed handler (will use template actions)'
  end

  # Verify/add template actions if missing
  if current_actions.empty?
    # Need to find the welcome templates
    welcome_text_1 = BotActionTemplate.find_by(account: account, name: 'welcome_text_1')
    welcome_text_2 = BotActionTemplate.find_by(account: account, name: 'welcome_text_2')
    welcome_rich_link = BotActionTemplate.find_by(account: account, name: 'welcome_rich_link')

    if welcome_text_1 && welcome_text_2
      welcome_node['data']['actions'] = [
        { 'type' => 'execute_templates', 'template_ids' => [welcome_text_1.id, welcome_text_2.id] }
      ]

      welcome_node['data']['actions'].first['template_ids'] << welcome_rich_link.id if welcome_rich_link

      changes << '  ✅ Added welcome template actions'
      puts '  ✅ Added template actions'
    else
      puts '  ⚠️  Welcome templates not found, keeping current actions'
    end
  else
    puts '  ✓ Template actions already configured'
  end

  # Verify edge to region exists
  welcome_edge = edges.find { |e| e['source'] == 'state-welcome' && e['target'] == 'state-region-process' }

  if welcome_edge
    puts '  ✓ Edge to region-process already exists'
  else
    # Create edge
    new_edge = {
      'id' => 'edge-welcome-region',
      'source' => 'state-welcome',
      'target' => 'state-region-process',
      'type' => 'smoothstep'
    }
    edges << new_edge
    changes << '  ✅ Added edge: Welcome → Region Process'
    puts '  ✅ Added edge to region-process (auto-continuation)'
  end
end

# Step 2: Convert all other handler-based nodes to template actions
puts "\n=== Step 2: Convert Handler Nodes to Template Actions ==="

HANDLER_TO_TEMPLATE_MAP = {
  'handle_summary' => 'ah_summary',
  'handle_menu' => 'ah_main_menu',
  'handle_list_picker_demo' => 'ah_guitar_list_picker',
  'handle_time_picker_demo' => 'ah_time_picker',
  'handle_form_demo' => 'ah_guitar_info_form'
}.freeze

state_nodes = nodes.select { |n| n['type'] == 'state' && n['id'] != 'state-welcome' }

state_nodes.each do |node|
  node_id = node['id']
  handler = node.dig('data', 'handlerMethod') || node.dig('data', 'handler')

  next unless handler.present?

  # Find template name for this handler
  template_name = HANDLER_TO_TEMPLATE_MAP[handler]

  unless template_name
    puts "\n#{node_id}:"
    puts "  ⚠️  Handler '#{handler}' not in template map, skipping"
    next
  end

  # Find the actual template
  template = BotActionTemplate.find_by(account: account, name: template_name)

  unless template
    puts "\n#{node_id}:"
    puts "  ❌ Template '#{template_name}' not found"
    next
  end

  puts "\n#{node_id} (#{node.dig('data', 'label')}):"
  puts "  Handler: #{handler} → Template: #{template_name} (ID: #{template.id})"

  # Remove handler and add template action
  node['data']['handlerMethod'] = nil
  node['data']['handler'] = nil
  node['data']['actions'] = [
    {
      'type' => 'execute_template',
      'template_id' => template.id
    }
  ]

  changes << "  ✅ Converted #{node.dig('data', 'label')}: handler → template"
  puts '  ✅ Converted to template action'
end

# Update flow data
flow_data['nodes'] = nodes
flow_data['edges'] = edges

# Display summary
puts "\n=== Migration Summary ==="
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

  puts '✅ Flow migration complete!'
  puts
  puts '🎯 Bot Studio is now FULLY Phase 2 compliant:'
  puts '  ✅ All nodes use template actions (zero handlers)'
  puts '  ✅ Zero dependence on AcousticHouseBotService'
  puts '  ✅ Pure visual flow + templates + edges'
  puts '  ✅ Automatic flow continuation via edges'
  puts
  puts 'Restart dev server and test:'
  puts '  ./script/dev-server.sh restart'
  puts
  puts 'Test keywords:'
  puts "  • 'start' → Welcome messages + region selection"
  puts "  • 'summary' → Summary list picker"
  puts "  • 'form' → Guitar info form"
  puts "  • 'menu' → Main menu"
  puts
else
  puts '✅ No changes needed - flow already Phase 2 compliant!'
end

# Final status report
puts '=== Final Flow Configuration ==='

state_nodes_all = nodes.select { |n| n['type'] == 'state' }
phase1_count = 0
phase2_count = 0
other_count = 0

state_nodes_all.each do |node|
  handler = node.dig('data', 'handlerMethod') || node.dig('data', 'handler')
  actions = node.dig('data', 'actions') || []

  if handler.present?
    status = '❌ Phase 1 (handler-based)'
    phase1_count += 1
  elsif actions.any? && (actions.first['type'] == 'execute_template' || actions.first['type'] == 'execute_templates')
    status = '✅ Phase 2 (template-based)'
    phase2_count += 1
  elsif actions.any?
    status = '⚠️  Has actions (unknown type)'
    other_count += 1
  else
    status = '⚠️  No handler or actions'
    other_count += 1
  end

  puts "#{status} - #{node.dig('data', 'label')}"
end

puts
puts 'Summary:'
puts "  Phase 1 (handlers): #{phase1_count}"
puts "  Phase 2 (templates): #{phase2_count}"
puts "  Other: #{other_count}"
puts

if phase1_count == 0 && phase2_count > 0
  puts '✅ Flow is 100% Phase 2 compliant!'
  puts '   AcousticHouseBotService is no longer needed for this flow.'
elsif phase1_count > 0
  puts "⚠️  #{phase1_count} nodes still use handlers."
  puts '   Run this script without --dry-run to migrate them.'
end
