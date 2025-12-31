#!/usr/bin/env ruby
# Phase 5: Fix handler chaining by converting to explicit edges
#
# This script analyzes the current flow and compares it against handler chains
# in AcousticHouseBotService, then creates explicit edges to replicate the
# automatic flow continuations that happen in handler methods.
#
# Usage:
#   rails runner script/fix_handler_chaining.rb
#   rails runner script/fix_handler_chaining.rb --dry-run

dry_run = ARGV.include?('--dry-run')

puts '=== Phase 5: Converting Handler Chains to Explicit Edges ==='
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

# Define handler chains that need to be converted to edges
# Format: [source_state_id, target_state_id, description]
HANDLER_CHAINS = [
  # Main conversation flow
  ['state-welcome', 'state-region-process', 'Welcome automatically prompts for region']

  # These would require new state nodes for intermediate steps:
  # handle_region_selection → handle_form_or_name_prompt (needs state node)
  # handle_guitar_selection → handle_ar_introduction (needs state node)
  # handle_ar_introduction → handle_ar_first_question (needs state node)
  # handle_apple_pay_response → handle_lesson_introduction (needs state node)
  # handle_lesson_introduction → handle_location_request (needs state node)
  # handle_time_picker_response → handle_continue_prompt (needs state node)
  # handle_summary → handle_final_message (needs state node)
].freeze

changes = []
created_edges = []
issues = []

# Step 1: Analyze current state nodes and their handlers
puts '=== Current State Nodes ==='
state_nodes = nodes.select { |n| n['type'] == 'state' }

state_nodes.each do |node|
  node.dig('data', 'state_id')
  label = node.dig('data', 'label')
  handler = node.dig('data', 'handlerMethod') || node.dig('data', 'handler')

  # Check if this node has outgoing edges
  outgoing_edges = edges.select { |e| e['source'] == node['id'] }

  puts "#{node['id']} (#{label}):"
  puts "  Handler: #{handler || 'none'}"
  puts "  Outgoing edges: #{outgoing_edges.length}"

  if handler.present? && outgoing_edges.empty?
    # Check if this handler has chains
    service_file = File.read('app/services/apple_messages_for_business/acoustic_house_bot_service.rb')
    method_start = service_file.index(/def #{handler}/)

    if method_start
      rest_of_file = service_file[method_start..]
      next_method = rest_of_file.index(/\n\s*def /, 10)
      method_end = next_method ? method_start + next_method : service_file.length
      method_body = service_file[method_start...method_end]

      called_handlers = method_body.scan(/\b(handle_\w+)(?:\(|\s|$)/).flatten.uniq
      called_handlers.delete(handler)

      if called_handlers.any?
        issues << "  ⚠️  #{node['id']} handler calls: #{called_handlers.join(', ')} but has no outgoing edges"
        puts "  ⚠️  Calls handlers: #{called_handlers.join(', ')}"
      end
    end
  end

  puts
end

if issues.any?
  puts "\n=== Issues Found ==="
  issues.each { |issue| puts issue }
  puts
end

# Step 2: Create missing edges for known chains
HANDLER_CHAINS.each do |source_id, target_id, description|
  source_node = nodes.find { |n| n['id'] == source_id }
  target_node = nodes.find { |n| n['id'] == target_id }

  unless source_node && target_node
    puts "⚠️  Skipping chain: #{source_id} → #{target_id}"
    puts "   Source exists: #{source_node.present?}, Target exists: #{target_node.present?}"
    next
  end

  # Check if edge already exists
  existing_edge = edges.find { |e| e['source'] == source_id && e['target'] == target_id }

  if existing_edge
    puts "✅ Edge already exists: #{source_id} → #{target_id}"
  else
    new_edge = {
      'id' => "edge-#{source_id}-#{target_id}",
      'source' => source_id,
      'target' => target_id,
      'type' => 'smoothstep'
    }

    edges << new_edge
    created_edges << new_edge['id']
    changes << "→ Created edge: #{source_node.dig('data', 'label')} → #{target_node.dig('data', 'label')}"
    changes << "   Reason: #{description}"
  end
end

# Step 3: Consider removing handlers that only send templates
# If a handler only sends templates and has metadata, we can remove it
# and use actions instead (more efficient)

puts "\n=== Handlers That Could Be Simplified ==="
state_nodes.each do |node|
  handler = node.dig('data', 'handlerMethod') || node.dig('data', 'handler')
  actions = node.dig('data', 'actions') || []

  next unless handler.present?

  # Check if handler has metadata with templates
  metadata = AppleMessagesForBusiness::AcousticHouseBotService.handler_methods_metadata[handler.to_sym]

  next unless metadata

  templates = metadata.dig(:dependencies, :templates) || []

  next unless templates.any? && actions.empty?

  puts "#{node['id']} (#{node.dig('data', 'label')}):"
  puts "  Handler: #{handler}"
  puts "  Handler uses templates: #{templates.inspect}"
  puts '  💡 Could be simplified by using actions instead of handler'
  puts
end

# Update flow data
flow_data['nodes'] = nodes
flow_data['edges'] = edges

# Display summary
puts "\n=== Migration Summary ==="
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
  puts "  1. Test the 'start' keyword - should now show region selection"
  puts '  2. Review other handler chains and add more edges as needed'
  puts '  3. Consider simplifying handlers that only send templates'
  puts
else
  puts '✅ No changes needed - flow already has necessary edges!'
  puts
end

puts '=== Recommendations ==='
puts
puts 'The following handler chains still need state nodes created:'
puts '  • handle_form_or_name_prompt (after region selection)'
puts '  • handle_ar_introduction (after guitar selection)'
puts '  • handle_apple_pay_response flow'
puts '  • handle_lesson_introduction flow'
puts '  • handle_continue_prompt (after time picker)'
puts
puts 'To fully replicate the legacy bot behavior, you would need to:'
puts '  1. Create state nodes for each handler in the conversation flow'
puts '  2. Add edges connecting them in the correct order'
puts '  3. Configure each state with its handler method or template actions'
puts
puts 'Alternative approach:'
puts '  - Keep using handlers via Priority 4 (direct service call)'
puts '  - This preserves all automatic chaining behavior'
puts '  - But loses the visual representation in Bot Studio'
