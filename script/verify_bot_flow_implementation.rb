#!/usr/bin/env ruby
# frozen_string_literal: true

# Verify Bot Flow 5 Implementation Against Legacy Requirements
# Usage: rails runner script/verify_bot_flow_implementation.rb > tmp/flow_verification_report.txt
#
# This script validates that all required nodes, edges, and configurations
# from the legacy AcousticHouseBotService are properly implemented in Bot Studio.

require 'json'

puts '=' * 100
puts 'BOT FLOW 5 IMPLEMENTATION VERIFICATION REPORT'
puts '=' * 100
puts "Generated: #{Time.current}"
puts '=' * 100
puts

# Find the flow
flow = BotFlow.find_by(id: 5)

unless flow
  puts '❌ ERROR: Bot Flow 5 not found'
  exit 1
end

puts "✅ Flow Found: #{flow.name}"
puts "   Agent Bot: #{flow.agent_bot.name} (ID: #{flow.agent_bot_id})"
puts "   Published: #{flow.is_published}"
puts "   Active: #{flow.is_active}"
puts "   Created: #{flow.created_at}"
puts "   Updated: #{flow.updated_at}"
puts

# Extract flow data
nodes = flow.flow_data['nodes'] || []
edges = flow.flow_data['edges'] || []

puts '📊 OVERVIEW STATISTICS'
puts '=' * 100
puts "Total Nodes: #{nodes.length}"
puts "Total Edges: #{edges.length}"
puts
puts 'Node Types:'
puts "  - State nodes: #{nodes.count { |n| n['type'] == 'state' }}"
puts "  - Intent nodes: #{nodes.count { |n| n['type'] == 'intent' }}"
puts "  - Condition nodes: #{nodes.count { |n| n['type'] == 'condition' }}"
puts

# ============================================================================
# SECTION 1: VALIDATE REQUIRED STATES (30+ states from legacy)
# ============================================================================

puts
puts '=' * 100
puts 'SECTION 1: REQUIRED STATE NODES VALIDATION'
puts '=' * 100
puts

# Define all required states from legacy service
required_states = {
  # Phase A: Welcome & Region
  'state-welcome' => { phase: 'A', legacy_state: 'AHA1', description: 'Welcome state' },
  'state-region-process' => { phase: 'A', legacy_state: 'AHA2', description: 'Region selection' },
  'state-form-or-name-prompt' => { phase: 'A', legacy_state: 'AHA3', description: 'Form or text name prompt' },

  # Phase B: Name Collection
  'state-form-response' => { phase: 'B', legacy_state: 'AHB1', description: 'Form response handler' },
  'state-text-name-input' => { phase: 'B', legacy_state: 'AHB1_2', description: 'Text name input fallback' },
  'state-name-preference' => { phase: 'B', legacy_state: 'AHB2', description: 'Name preference selection' },
  'state-guitar-list-prompt' => { phase: 'B', legacy_state: 'AHB3', description: 'Guitar list picker' },

  # Phase C: Guitar Selection & AR
  'state-guitar-catcher' => { phase: 'C', legacy_state: 'AHC1', description: 'Guitar selection with retry' },
  'state-ar-intro' => { phase: 'C', legacy_state: 'AHC2', description: 'AR introduction' },
  'state-ar-question-1' => { phase: 'C', legacy_state: 'AHC3', description: 'AR first question' },

  # Phase D-E: AR Interaction & Apple Pay
  'state-ar-view-catcher' => { phase: 'D', legacy_state: 'AHD1', description: 'AR view catcher' },
  'state-ar-place-question' => { phase: 'E', legacy_state: 'AHE1', description: 'AR place question' },
  'state-apple-pay-prompt' => { phase: 'E', legacy_state: 'AHE2', description: 'Apple Pay prompt' },

  # Phase F: Payment & Lesson
  'state-apple-pay-catcher' => { phase: 'F', legacy_state: 'AHF1', description: 'Apple Pay catcher' },
  'state-lesson-intro' => { phase: 'F', legacy_state: 'AHF2', description: 'Lesson introduction' },
  'state-location-request' => { phase: 'F', legacy_state: 'AHF3', description: 'Location request' },

  # Phase G: Location & Store Selection
  'state-location-response' => { phase: 'G', legacy_state: 'AHG1', description: 'Location response handler' },
  'state-single-store-rich-link' => { phase: 'G', legacy_state: 'AHG2', description: 'Single store (1 store)' },
  'state-store-quick-reply' => { phase: 'G', legacy_state: 'AHG2', description: 'Store quick reply (2-5 stores)' },
  'state-store-list-picker' => { phase: 'G', legacy_state: 'AHG2', description: 'Store list picker (6+ stores)' },

  # Phase H: Time Picker
  'state-time-picker' => { phase: 'H', legacy_state: 'AHH1', description: 'Time picker with location' },
  'state-continue-prompt' => { phase: 'H', legacy_state: 'AHH2', description: 'Continue prompt' },

  # Phase I: Rich Links & Photos
  'state-rich-link-display' => { phase: 'I', legacy_state: 'AHI2', description: 'Rich link display' },
  'state-photo-intro' => { phase: 'I', legacy_state: 'AHI3', description: 'Photo introduction' },
  'state-photo-request' => { phase: 'I', legacy_state: 'AHI4', description: 'Photo request' },

  # Phase J: Documents & Learn More
  'state-documents-intro' => { phase: 'J', legacy_state: 'AHJ2', description: 'Documents intro' },
  'state-pdf-document' => { phase: 'J', legacy_state: 'AHJ3', description: 'PDF document' },
  'state-learn-more-prompt' => { phase: 'J', legacy_state: 'AHJ4', description: 'Learn more prompt' },

  # Phase K: Summary & Completion
  'state-summary-demo' => { phase: 'K', legacy_state: 'AHK1', description: 'Summary list picker' },
  'state-complete' => { phase: 'K', legacy_state: 'AHK2', description: 'Final message' },
  'state-register-link-reset' => { phase: 'K', legacy_state: 'AHK3', description: 'Register link & reset' }
}

state_nodes = nodes.select { |n| n['type'] == 'state' }

puts "Required States: #{required_states.length}"
puts "Implemented States: #{state_nodes.length}"
puts

# Validate each required state
missing_states = []
found_states = []

required_states.each do |state_id, info|
  node = state_nodes.find { |n| n['id'] == state_id }
  if node
    found_states << state_id
    puts "  ✅ #{state_id}"
    puts "     Phase: #{info[:phase]} | Legacy: #{info[:legacy_state]} | #{info[:description]}"
    puts "     Label: #{node.dig('data', 'label')}"

    actions = node.dig('data', 'actions') || []
    if actions.any?
      puts "     Actions: #{actions.length}"
      actions.each do |action|
        puts "       - #{action['type']}: #{action['handler'] || action['text']&.truncate(50) || 'configured'}"
      end
    else
      puts '     ⚠️  WARNING: No actions configured'
    end
    puts
  else
    missing_states << state_id
    puts "  ❌ MISSING: #{state_id} (#{info[:legacy_state]}: #{info[:description]})"
  end
end

puts
puts "Summary: #{found_states.length}/#{required_states.length} required states implemented"
if missing_states.any?
  puts "❌ Missing #{missing_states.length} states:"
  missing_states.each { |s| puts "   - #{s}" }
else
  puts '✅ All required states present!'
end

# ============================================================================
# SECTION 2: VALIDATE REQUIRED INTENTS
# ============================================================================

puts
puts '=' * 100
puts 'SECTION 2: REQUIRED INTENT NODES VALIDATION'
puts '=' * 100
puts

required_intents = {
  'intent-start_over' => { keywords: ['start', 'startover', 'start over', 'restart', 'begin', 'reset'] },
  'intent-menu' => { keywords: ['menu'] },
  'intent-list-picker-demo' => { keywords: ['list picker', 'listpicker', 'guitar', 'guitars'] },
  'intent-time-picker-demo' => { keywords: ['time picker', 'timepicker'] },
  'intent-form-demo' => { keywords: ['form', 'help me decide'] },
  'intent-summary' => { keywords: ['summary'] },
  'intent-apple-pay-demo' => { keywords: ['apple pay', 'payment', 'pay'] },
  'intent-ar-demo' => { keywords: ['ar', 'augmented reality'] },
  'intent-stop' => { keywords: ['stop'] },
  'intent-schedule-lesson' => { keywords: %w[schedule lesson appointment time] },
  'intent-skip-payment' => { keywords: ['skip'] }
}

intent_nodes = nodes.select { |n| n['type'] == 'intent' }

puts "Required Intents: #{required_intents.length}"
puts "Implemented Intents: #{intent_nodes.length}"
puts

missing_intents = []
found_intents = []

required_intents.each do |intent_id, info|
  node = intent_nodes.find { |n| n['id'] == intent_id }
  if node
    found_intents << intent_id
    configured_keywords = node.dig('data', 'keywords') || []
    puts "  ✅ #{intent_id}"
    puts "     Expected keywords: #{info[:keywords].join(', ')}"
    puts "     Configured keywords: #{configured_keywords.join(', ')}"

    puts '     ⚠️  WARNING: No keywords configured' if configured_keywords.empty?
    puts
  else
    missing_intents << intent_id
    puts "  ❌ MISSING: #{intent_id}"
  end
end

puts
puts "Summary: #{found_intents.length}/#{required_intents.length} required intents implemented"
if missing_intents.any?
  puts "❌ Missing #{missing_intents.length} intents:"
  missing_intents.each { |i| puts "   - #{i}" }
else
  puts '✅ All required intents present!'
end

# ============================================================================
# SECTION 3: VALIDATE REQUIRED CONDITIONS
# ============================================================================

puts
puts '=' * 100
puts 'SECTION 3: REQUIRED CONDITION NODES VALIDATION'
puts '=' * 100
puts

required_conditions = {
  'condition-device-supports-forms' => {
    description: 'Check device capability (FORM)',
    condition_type: 'capability_check'
  },
  'condition-store-count-router' => {
    description: 'Route by store count (1 / 2-5 / 6+)',
    condition_type: 'count_check'
  },
  'condition-retry-threshold' => {
    description: 'Check retry threshold (>= 5)',
    condition_type: 'comparison'
  }
}

condition_nodes = nodes.select { |n| n['type'] == 'condition' }

puts "Required Conditions: #{required_conditions.length}"
puts "Implemented Conditions: #{condition_nodes.length}"
puts

missing_conditions = []
found_conditions = []

required_conditions.each do |condition_id, info|
  node = condition_nodes.find { |n| n['id'] == condition_id }
  if node
    found_conditions << condition_id
    puts "  ✅ #{condition_id}"
    puts "     Description: #{info[:description]}"
    puts "     Expected type: #{info[:condition_type]}"
    puts "     Configured type: #{node.dig('data', 'condition_type')}"
    puts
  else
    missing_conditions << condition_id
    puts "  ❌ MISSING: #{condition_id} (#{info[:description]})"
  end
end

puts
puts "Summary: #{found_conditions.length}/#{required_conditions.length} required conditions implemented"
if missing_conditions.any?
  puts "❌ Missing #{missing_conditions.length} conditions:"
  missing_conditions.each { |c| puts "   - #{c}" }
else
  puts '✅ All required conditions present!'
end

# ============================================================================
# SECTION 4: VALIDATE CRITICAL EDGES (CONNECTIONS)
# ============================================================================

puts
puts '=' * 100
puts 'SECTION 4: CRITICAL FLOW CONNECTIONS VALIDATION'
puts '=' * 100
puts

# Define critical flow connections
critical_edges = [
  # Main flow
  { from: 'state-region-process', to: 'state-form-or-name-prompt', label: 'After region selection' },
  { from: 'state-form-or-name-prompt', to: 'condition-device-supports-forms', label: 'Check device capability' },
  { from: 'condition-device-supports-forms', to: 'state-form-response', label: 'Device supports forms' },
  { from: 'condition-device-supports-forms', to: 'state-text-name-input', label: 'No form support' },
  { from: 'state-form-response', to: 'state-name-preference', label: 'Form submitted' },
  { from: 'state-text-name-input', to: 'state-name-preference', label: 'Name entered' },
  { from: 'state-name-preference', to: 'state-guitar-list-prompt', label: 'Name preference selected' },
  { from: 'state-guitar-list-prompt', to: 'state-guitar-catcher', label: 'Waiting for guitar selection' },
  { from: 'state-guitar-catcher', to: 'state-ar-intro', label: 'Guitar selected' },
  { from: 'state-ar-intro', to: 'state-ar-question-1', label: 'AR file sent' },
  { from: 'state-location-response', to: 'condition-store-count-router', label: 'Location geocoded' },
  { from: 'condition-store-count-router', to: 'state-single-store-rich-link', label: '1 store found' },
  { from: 'condition-store-count-router', to: 'state-store-quick-reply', label: '2-5 stores found' },
  { from: 'condition-store-count-router', to: 'state-store-list-picker', label: '6+ stores found' },
  { from: 'state-single-store-rich-link', to: 'state-time-picker', label: 'Store auto-selected' },
  { from: 'state-store-quick-reply', to: 'state-time-picker', label: 'Store selected' },
  { from: 'state-store-list-picker', to: 'state-time-picker', label: 'Store selected' },
  { from: 'state-register-link-reset', to: 'state-welcome', label: 'Flow reset to start' }
]

puts "Critical Edges: #{critical_edges.length}"
puts "Total Edges: #{edges.length}"
puts

missing_edges = []
found_edges = []

critical_edges.each do |edge_def|
  edge = edges.find { |e| e['source'] == edge_def[:from] && e['target'] == edge_def[:to] }
  if edge
    found_edges << edge_def
    puts "  ✅ #{edge_def[:from]} → #{edge_def[:to]}"
    puts "     Purpose: #{edge_def[:label]}"
    puts
  else
    missing_edges << edge_def
    puts "  ❌ MISSING: #{edge_def[:from]} → #{edge_def[:to]}"
    puts "     Purpose: #{edge_def[:label]}"
    puts
  end
end

puts
puts "Summary: #{found_edges.length}/#{critical_edges.length} critical edges implemented"
if missing_edges.any?
  puts "❌ Missing #{missing_edges.length} critical edges:"
  missing_edges.each { |e| puts "   - #{e[:from]} → #{e[:to]} (#{e[:label]})" }
else
  puts '✅ All critical edges present!'
end

# ============================================================================
# SECTION 5: BACKEND SERVICES VALIDATION
# ============================================================================

puts
puts '=' * 100
puts 'SECTION 5: BACKEND SERVICES VALIDATION'
puts '=' * 100
puts

# Check if required services exist
backend_services = {
  'FlowExecutorService' => 'app/services/apple_messages_for_business/flow_executor_service.rb',
  'FormParserService' => 'app/services/apple_messages_for_business/form_parser_service.rb',
  'TemplateExecutorService' => 'app/services/apple_messages_for_business/template_executor_service.rb',
  'AppleMapsService' => 'app/services/apple_messages_for_business/apple_maps_service.rb'
}

backend_services.each do |service_name, file_path|
  if File.exist?(file_path)
    puts "  ✅ #{service_name}"
    puts "     Path: #{file_path}"

    # Check for key methods
    content = File.read(file_path)

    case service_name
    when 'FlowExecutorService'
      methods = ['increment_retry_count', 'conversation_timed_out?', 'execute_custom_code_action',
                 'evaluate_capability_condition', 'handle_attachment', 'execute_oauth_action']
      methods.each do |method|
        if content.include?("def #{method}")
          puts "       ✅ Method: #{method}"
        else
          puts "       ❌ Missing method: #{method}"
        end
      end

    when 'FormParserService'
      methods = %w[extract_customer_name extract_stage_name extract_address]
      methods.each do |method|
        if content.include?("def #{method}")
          puts "       ✅ Method: #{method}"
        else
          puts "       ❌ Missing method: #{method}"
        end
      end

    when 'TemplateExecutorService'
      methods = %w[execute_dynamic_template build_store_list_picker build_time_picker]
      methods.each do |method|
        if content.include?("def #{method}")
          puts "       ✅ Method: #{method}"
        else
          puts "       ❌ Missing method: #{method}"
        end
      end

    when 'AppleMapsService'
      methods = %w[geocode search_nearby]
      methods.each do |method|
        if content.include?("def #{method}")
          puts "       ✅ Method: #{method}"
        else
          puts "       ❌ Missing method: #{method}"
        end
      end
    end

    puts
  else
    puts "  ❌ MISSING: #{service_name}"
    puts "     Expected path: #{file_path}"
    puts
  end
end

# ============================================================================
# SECTION 6: I18N VALIDATION
# ============================================================================

puts
puts '=' * 100
puts 'SECTION 6: I18N STRINGS VALIDATION'
puts '=' * 100
puts

i18n_file = 'config/locales/en.yml'
if File.exist?(i18n_file)
  puts "  ✅ I18n file exists: #{i18n_file}"

  content = File.read(i18n_file)

  required_keys = [
    'messages.activity.bot_flow.fallback_response',
    'messages.activity.bot_flow.oauth.provider_not_enabled',
    'messages.activity.bot_flow.oauth.sign_in_prompt',
    'messages.activity.bot_flow.oauth.unavailable',
    'messages.activity.bot_flow.attachment.photo_received',
    'messages.activity.bot_flow.template.select_store',
    'messages.activity.bot_flow.template.schedule_lesson'
  ]

  puts '  Checking required i18n keys:'
  required_keys.each do |key|
    # Simple check - look for the leaf key
    leaf_key = key.split('.').last
    if content.include?("#{leaf_key}:")
      puts "    ✅ #{key}"
    else
      puts "    ❌ MISSING: #{key}"
    end
  end
else
  puts "  ❌ I18n file not found: #{i18n_file}"
end

puts

# ============================================================================
# SECTION 7: FINAL SUMMARY
# ============================================================================

puts
puts '=' * 100
puts 'FINAL IMPLEMENTATION SUMMARY'
puts '=' * 100
puts

total_required = required_states.length + required_intents.length + required_conditions.length
total_implemented = found_states.length + found_intents.length + found_conditions.length
completion_percentage = (total_implemented.to_f / total_required * 100).round(1)

puts "Overall Completion: #{total_implemented}/#{total_required} components (#{completion_percentage}%)"
puts
puts 'Breakdown:'
puts "  States: #{found_states.length}/#{required_states.length}"
puts "  Intents: #{found_intents.length}/#{required_intents.length}"
puts "  Conditions: #{found_conditions.length}/#{required_conditions.length}"
puts "  Critical Edges: #{found_edges.length}/#{critical_edges.length}"
puts

if missing_states.any? || missing_intents.any? || missing_conditions.any? || missing_edges.any?
  puts '❌ INCOMPLETE - Missing components detected'
  puts
  puts 'Action Required:'
  puts '  1. Review missing components above'
  puts '  2. Re-run migration script if needed'
  puts '  3. Manually add missing nodes/edges in Bot Studio UI'
else
  puts '✅ COMPLETE - All required components implemented!'
  puts
  puts 'Ready for Testing:'
  puts '  1. Verify flow in Bot Studio UI'
  puts '  2. Test complete conversation flow'
  puts '  3. Verify retry logic, timeouts, and error handling'
  puts '  4. Test with real Apple Messages for Business'
end

puts
puts '=' * 100
puts 'END OF VERIFICATION REPORT'
puts '=' * 100
