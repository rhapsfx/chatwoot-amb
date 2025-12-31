#!/usr/bin/env ruby
# frozen_string_literal: true

# Verify Bot Flow Implementation from Backup JSON
# Usage: ruby script/verify_flow_from_json.rb tmp/flow_5_backup_1766829675.json

require 'json'

if ARGV.empty?
  puts 'Usage: ruby script/verify_flow_from_json.rb <backup_json_file>'
  puts
  puts 'Example:'
  puts '  ruby script/verify_flow_from_json.rb tmp/flow_5_backup_1766829675.json'
  exit 1
end

backup_file = ARGV[0]

unless File.exist?(backup_file)
  puts "❌ ERROR: File not found: #{backup_file}"
  exit 1
end

flow_data = JSON.parse(File.read(backup_file))
nodes = flow_data['nodes'] || []
edges = flow_data['edges'] || []

puts '=' * 100
puts 'BOT FLOW 5 IMPLEMENTATION VERIFICATION REPORT'
puts '=' * 100
puts "Source: #{backup_file}"
puts "Generated: #{Time.now}"
puts '=' * 100
puts

puts '📊 OVERVIEW STATISTICS'
puts '=' * 100
puts "Total Nodes: #{nodes.length}"
puts "Total Edges: #{edges.length}"
puts
puts 'Node Types:'
state_nodes = nodes.select { |n| n['type'] == 'state' }
intent_nodes = nodes.select { |n| n['type'] == 'intent' }
condition_nodes = nodes.select { |n| n['type'] == 'condition' }
puts "  - State nodes: #{state_nodes.length}"
puts "  - Intent nodes: #{intent_nodes.length}"
puts "  - Condition nodes: #{condition_nodes.length}"
puts

# ============================================================================
# VALIDATE REQUIRED STATES
# ============================================================================

puts '=' * 100
puts 'SECTION 1: REQUIRED STATE NODES (30 STATES FROM LEGACY)'
puts '=' * 100
puts

required_states = {
  'state-welcome' => 'AHA1: Welcome state',
  'state-region-process' => 'AHA2: Region selection',
  'state-form-or-name-prompt' => 'AHA3: Form or text name prompt',
  'state-form-response' => 'AHB1: Form response handler',
  'state-text-name-input' => 'AHB1_2: Text name input fallback',
  'state-name-preference' => 'AHB2: Name preference selection',
  'state-guitar-list-prompt' => 'AHB3: Guitar list picker',
  'state-guitar-catcher' => 'AHC1: Guitar selection with retry',
  'state-ar-intro' => 'AHC2: AR introduction',
  'state-ar-question-1' => 'AHC3: AR first question',
  'state-ar-view-catcher' => 'AHD1: AR view catcher',
  'state-ar-place-question' => 'AHE1: AR place question',
  'state-apple-pay-prompt' => 'AHE2: Apple Pay prompt',
  'state-apple-pay-catcher' => 'AHF1: Apple Pay catcher',
  'state-lesson-intro' => 'AHF2: Lesson introduction',
  'state-location-request' => 'AHF3: Location request',
  'state-location-response' => 'AHG1: Location response handler',
  'state-single-store-rich-link' => 'AHG2: Single store (1 store)',
  'state-store-quick-reply' => 'AHG2: Store quick reply (2-5 stores)',
  'state-store-list-picker' => 'AHG2: Store list picker (6+ stores)',
  'state-time-picker' => 'AHH1: Time picker with location',
  'state-continue-prompt' => 'AHH2: Continue prompt',
  'state-rich-link-display' => 'AHI2: Rich link display',
  'state-photo-intro' => 'AHI3: Photo introduction',
  'state-photo-request' => 'AHI4: Photo request',
  'state-documents-intro' => 'AHJ2: Documents intro',
  'state-pdf-document' => 'AHJ3: PDF document',
  'state-learn-more-prompt' => 'AHJ4: Learn more prompt',
  'state-summary-demo' => 'AHK1: Summary list picker',
  'state-complete' => 'AHK2: Final message',
  'state-register-link-reset' => 'AHK3: Register link & reset'
}

found = 0
missing = []

required_states.each do |state_id, description|
  node = state_nodes.find { |n| n['id'] == state_id }
  if node
    found += 1
    puts "  ✅ #{state_id}"
    puts "     #{description}"
    puts "     Label: #{node.dig('data', 'label')}"
    actions = node.dig('data', 'actions') || []
    if actions.any?
      puts "     Actions (#{actions.length}):"
      actions.each do |action|
        puts "       - #{action['type']}: #{action['handler'] || action['text']&.slice(0, 40) || 'configured'}"
      end
    end
    puts
  else
    missing << state_id
    puts "  ❌ MISSING: #{state_id} - #{description}"
  end
end

puts
puts "Summary: #{found}/#{required_states.length} required states"
puts "✅ Present: #{found}" if found > 0
puts "❌ Missing: #{missing.length} (#{missing.join(', ')})" if missing.any?
puts

# ============================================================================
# VALIDATE REQUIRED INTENTS
# ============================================================================

puts '=' * 100
puts 'SECTION 2: REQUIRED INTENT NODES (11 INTENTS)'
puts '=' * 100
puts

required_intents = {
  'intent-start_over' => %w[start restart],
  'intent-menu' => ['menu'],
  'intent-list-picker-demo' => ['list picker', 'guitar'],
  'intent-time-picker-demo' => ['time picker'],
  'intent-form-demo' => ['form'],
  'intent-summary' => ['summary'],
  'intent-apple-pay-demo' => ['apple pay'],
  'intent-ar-demo' => ['ar'],
  'intent-stop' => ['stop'],
  'intent-schedule-lesson' => %w[schedule lesson],
  'intent-skip-payment' => ['skip']
}

found = 0
missing = []

required_intents.each do |intent_id, keywords|
  node = intent_nodes.find { |n| n['id'] == intent_id }
  if node
    found += 1
    configured_keywords = node.dig('data', 'keywords') || []
    puts "  ✅ #{intent_id}"
    puts "     Expected: #{keywords.join(', ')}"
    puts "     Configured: #{configured_keywords.join(', ')}"
    puts
  else
    missing << intent_id
    puts "  ❌ MISSING: #{intent_id}"
  end
end

puts
puts "Summary: #{found}/#{required_intents.length} required intents"
puts "✅ Present: #{found}" if found > 0
puts "❌ Missing: #{missing.length} (#{missing.join(', ')})" if missing.any?
puts

# ============================================================================
# VALIDATE REQUIRED CONDITIONS
# ============================================================================

puts '=' * 100
puts 'SECTION 3: REQUIRED CONDITION NODES (3 CONDITIONS)'
puts '=' * 100
puts

required_conditions = {
  'condition-device-supports-forms' => 'capability_check',
  'condition-store-count-router' => 'count_check',
  'condition-retry-threshold' => 'comparison'
}

found = 0
missing = []

required_conditions.each do |condition_id, type|
  node = condition_nodes.find { |n| n['id'] == condition_id }
  if node
    found += 1
    puts "  ✅ #{condition_id}"
    puts "     Type: #{node.dig('data', 'condition_type')}"
    puts
  else
    missing << condition_id
    puts "  ❌ MISSING: #{condition_id} (#{type})"
  end
end

puts
puts "Summary: #{found}/#{required_conditions.length} required conditions"
puts "✅ Present: #{found}" if found > 0
puts "❌ Missing: #{missing.length} (#{missing.join(', ')})" if missing.any?
puts

# ============================================================================
# VALIDATE CRITICAL EDGES
# ============================================================================

puts '=' * 100
puts 'SECTION 4: CRITICAL FLOW CONNECTIONS'
puts '=' * 100
puts

critical_edges = [
  %w[state-region-process state-form-or-name-prompt],
  %w[state-form-or-name-prompt condition-device-supports-forms],
  %w[condition-device-supports-forms state-form-response],
  %w[condition-device-supports-forms state-text-name-input],
  %w[state-name-preference state-guitar-list-prompt],
  %w[state-guitar-catcher state-ar-intro],
  %w[state-location-response condition-store-count-router],
  %w[condition-store-count-router state-single-store-rich-link],
  %w[condition-store-count-router state-store-quick-reply],
  %w[condition-store-count-router state-store-list-picker],
  %w[state-register-link-reset state-welcome]
]

found = 0
missing = []

critical_edges.each do |from, to|
  edge = edges.find { |e| e['source'] == from && e['target'] == to }
  if edge
    found += 1
    puts "  ✅ #{from} → #{to}"
  else
    missing << "#{from} → #{to}"
    puts "  ❌ MISSING: #{from} → #{to}"
  end
end

puts
puts "Summary: #{found}/#{critical_edges.length} critical edges"
puts "✅ Present: #{found}" if found > 0
puts "❌ Missing: #{missing.length}" if missing.any?
puts

# ============================================================================
# FINAL SUMMARY
# ============================================================================

puts '=' * 100
puts 'FINAL SUMMARY'
puts '=' * 100
puts

total_required = required_states.length + required_intents.length + required_conditions.length
total_found = state_nodes.length + intent_nodes.length + condition_nodes.length
completion = (total_found.to_f / total_required * 100).round(1)

puts "Overall: #{total_found} nodes implemented"
puts "Completion: #{completion}%"
puts
puts 'Details:'
puts "  States: #{state_nodes.length} (required: #{required_states.length})"
puts "  Intents: #{intent_nodes.length} (required: #{required_intents.length})"
puts "  Conditions: #{condition_nodes.length} (required: #{required_conditions.length})"
puts "  Edges: #{edges.length}"
puts

if completion >= 100
  puts '✅ COMPLETE - All required components implemented!'
else
  puts "⚠️  IN PROGRESS - #{100 - completion}% remaining"
end

puts
puts '=' * 100
