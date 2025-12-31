#!/usr/bin/env ruby
# Migrate legacy handler keywords to Bot Studio visual flow
#
# This script implements Phase 3 of the Bot Studio migration:
# - Reads keywords from AcousticHouseBotService handler_methods_metadata
# - Maps them to corresponding intent nodes in the visual flow
# - Updates intent node keywords and scope
# - Saves the updated flow
#
# Usage:
#   rails runner script/migrate_keywords_to_flow.rb
#   rails runner script/migrate_keywords_to_flow.rb --dry-run

dry_run = ARGV.include?('--dry-run')

puts '=== Phase 3: Migrating Handler Keywords to Visual Flow ==='
puts
puts "Mode: #{dry_run ? 'DRY RUN (no changes will be saved)' : 'LIVE (flow will be updated)'}"
puts

# Load the flow
flow = BotFlow.find(5)
bot = flow.agent_bot

puts "📊 Flow: #{flow.name} (ID: #{flow.id})"
puts "🤖 Bot: #{bot.name} (ID: #{bot.id})"
puts

# Get handler metadata from the service
metadata = AppleMessagesForBusiness::AcousticHouseBotService.handler_methods_metadata

# Handler name to intent_id mappings
# These map the legacy handler names to the visual flow intent node intent_ids
HANDLER_TO_INTENT_MAP = {
  handle_menu: 'menu',
  handle_start_over: 'start_over',
  handle_list_picker_demo: 'list_picker_demo',
  handle_time_picker_demo: 'time_picker_demo',
  handle_form_demo: 'form_demo',
  handle_summary: 'summary',
  handle_region_selection: 'select_region'
}.freeze

# Load current flow data
flow_data = flow.flow_data || {}
nodes = flow_data['nodes'] || []
intent_nodes = nodes.select { |n| n['type'] == 'intent' }

puts "🎯 Found #{intent_nodes.length} intent nodes in flow"
puts

# Track changes
changes = []
new_intents = []

# Process each handler with keywords
metadata.each do |handler_name, handler_data|
  next unless handler_data[:handler_type] == :keyword

  keywords = handler_data.dig(:triggers, :keywords) || []
  next if keywords.empty?

  # Get the corresponding intent_id
  intent_id = HANDLER_TO_INTENT_MAP[handler_name]

  # Default to handler name without 'handle_' prefix if no mapping exists
  intent_id ||= handler_name.to_s.gsub('handle_', '')

  # Find existing intent node
  intent_node = intent_nodes.find { |n| n.dig('data', 'intent_id') == intent_id }

  if intent_node
    # Update existing node with keywords
    old_keywords = intent_node.dig('data', 'keywords') || []

    if old_keywords.sort == keywords.sort
      puts "  ✓ #{handler_data[:display_name]}: Already has correct keywords"
    else
      # Update keywords
      intent_node['data']['keywords'] = keywords
      intent_node['data']['scope'] = 'global' # All keyword handlers are global
      intent_node['data']['exact_match'] = false
      intent_node['data']['case_sensitive'] = false

      changes << "  ↻ #{handler_data[:display_name]}: #{old_keywords.inspect} → #{keywords.inspect}"
    end
  else
    # Create new intent node
    puts "  + Creating new intent: #{handler_data[:display_name]} (#{intent_id})"

    new_node = {
      'id' => "intent-#{intent_id}",
      'type' => 'intent',
      'position' => { 'x' => 100, 'y' => 500 + (new_intents.length * 200) },
      'data' => {
        'label' => handler_data[:display_name],
        'intent_id' => intent_id,
        'keywords' => keywords,
        'scope' => 'global', # All keyword handlers are global
        'exact_match' => false,
        'case_sensitive' => false,
        'actions' => [],
        'description' => handler_data[:description]
      }
    }

    new_intents << new_node
    changes << "  + New intent: #{handler_data[:display_name]} (#{keywords.length} keywords)"
  end
end

# Add new intent nodes to the flow
if new_intents.any?
  puts
  puts "📝 Creating #{new_intents.length} new intent nodes:"
  new_intents.each do |node|
    puts "  + #{node['data']['label']} (#{node['data']['keywords'].length} keywords)"
  end

  nodes.concat(new_intents)
  flow_data['nodes'] = nodes
end

# Display summary
puts
puts '=== Migration Summary ==='
puts "Total changes: #{changes.length}"
puts "New intent nodes: #{new_intents.length}"
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
elsif changes.any? || new_intents.any?
  flow.flow_data = flow_data
  flow.save!

  puts '✅ Flow updated successfully!'
  puts
  puts 'Next steps:'
  puts '  1. Open Bot Studio UI and verify the changes'
  puts "  2. Test the bot with keyword inputs: 'menu', 'guitar', 'form', etc."
  puts '  3. Ensure all intents are properly connected in the flow'
  puts
else
  puts '✅ No changes needed - flow is already up to date!'
  puts
end

# Display current flow state
puts '=== Current Flow Intent Nodes ==='
intent_nodes = nodes.select { |n| n['type'] == 'intent' }
intent_nodes.each do |node|
  keywords = node.dig('data', 'keywords') || []
  scope = node.dig('data', 'scope') || 'global'
  puts "  #{node['data']['label']}:"
  puts "    - ID: #{node['data']['intent_id']}"
  puts "    - Scope: #{scope}"
  puts "    - Keywords: #{keywords.inspect}"
  puts
end
