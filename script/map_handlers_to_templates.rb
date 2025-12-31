#!/usr/bin/env ruby
# Phase 2 Migration: Map handlers to actual BotActionTemplate records
#
# Uses existing BotActionTemplate records that match the handler functionality
#
# Usage:
#   rails runner script/map_handlers_to_templates.rb

puts '=== Phase 2 Migration: Handler → Template Mapping ==='
puts

flow = BotFlow.find(5)
account = flow.agent_bot.account
flow_data = flow.flow_data || {}
nodes = flow_data['nodes'] || []

changes = []

# Handler to BotActionTemplate mapping based on actual templates in database
HANDLER_TEMPLATE_MAPPING = {
  'handle_form_demo' => {
    templates: [
      { id: 9, name: 'handle_form_demo_form_demo_intro' },     # Intro text
      { id: 10, name: 'handle_form_demo_form_demo_form' }      # The form
    ]
  },
  'handle_time_picker_demo' => {
    templates: [
      { id: 7, name: 'handle_time_picker_demo_time_picker_demo_intro' },   # Intro text
      { id: 8, name: 'handle_time_picker_demo_time_picker_demo_picker' }   # Time picker
    ]
  },
  'handle_summary' => {
    # For summary, we need to check if there's a BotActionTemplate or use completion_text
    # Legacy MessageTemplate 355 'ah_summary' exists but needs to be in BotActionTemplate format
    templates: [
      { id: 51, name: 'completion_text' }  # Use completion text as placeholder
    ],
    note: 'Using completion_text as placeholder - ah_summary needs migration'
  }
}.freeze

puts "Processing demo handler nodes...\n"

HANDLER_TEMPLATE_MAPPING.each do |handler_name, config|
  # Find the node with this handler
  node = nodes.find do |n|
    n['type'] == 'state' &&
      (n.dig('data', 'handlerMethod') == handler_name || n.dig('data', 'handler') == handler_name)
  end

  next unless node

  puts "\n#{node['id']} (#{node.dig('data', 'label')}):"
  puts "  Handler: #{handler_name}"

  puts "  ⚠️  #{config[:note]}" if config[:note]

  # Verify templates exist
  template_ids = config[:templates].map { |t| t[:id] }
  templates_exist = BotActionTemplate.where(id: template_ids, account: account).count == template_ids.length

  unless templates_exist
    puts '  ❌ Not all templates found, skipping'
    next
  end

  puts "  Templates: #{config[:templates].map { |t| "#{t[:name]} (#{t[:id]})" }.join(', ')}"

  # Remove handler and add template actions
  node['data']['handlerMethod'] = nil
  node['data']['handler'] = nil

  node['data']['actions'] = if template_ids.length == 1
                              # Single template
                              [
                                {
                                  'type' => 'execute_template',
                                  'template_id' => template_ids.first
                                }
                              ]
                            else
                              # Multiple templates
                              [
                                {
                                  'type' => 'execute_templates',
                                  'template_ids' => template_ids
                                }
                              ]
                            end

  changes << "✅ #{node.dig('data', 'label')}: Converted to template actions"
  puts '  ✅ Converted to template action(s)'
end

# Update flow data
flow_data['nodes'] = nodes

puts "\n=== Migration Summary ==="
puts "Nodes converted: #{changes.length}"

if changes.any?
  puts "\nChanges:"
  changes.each { |change| puts "  #{change}" }

  # Save the flow
  flow.flow_data = flow_data
  flow.save!

  puts "\n✅ Flow updated successfully!"
  puts
  puts 'Restart dev server and test:'
  puts '  ./script/dev-server.sh restart'
  puts
  puts 'Test keywords:'
  puts "  • 'form' → Guitar info form"
  puts "  • 'time picker' → Time picker demo"
  puts "  • 'summary' → Completion text (placeholder)"
  puts
  puts "⚠️  Note: 'summary' uses completion_text as placeholder."
  puts "   To fix, migrate legacy MessageTemplate 355 'ah_summary' to BotActionTemplate"
else
  puts "\n✅ No changes needed!"
end

# Final status
puts "\n=== Final Status ==="

state_nodes = nodes.select { |n| n['type'] == 'state' }
phase1_count = 0
phase2_count = 0

state_nodes.each do |node|
  handler = node.dig('data', 'handlerMethod') || node.dig('data', 'handler')
  actions = node.dig('data', 'actions') || []

  if handler.present?
    status = '❌ Phase 1'
    phase1_count += 1
  elsif actions.any?
    status = '✅ Phase 2'
    phase2_count += 1
  else
    status = '⚠️  Empty'
  end

  puts "#{status} - #{node.dig('data', 'label')}"
end

puts
puts "Phase 1 (handlers): #{phase1_count}"
puts "Phase 2 (templates): #{phase2_count}"

if phase1_count == 0
  puts "\n🎉 Flow is 100% Phase 2 compliant!"
  puts '   Zero dependence on AcousticHouseBotService handlers.'
end
