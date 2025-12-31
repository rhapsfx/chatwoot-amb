#!/usr/bin/env ruby
# frozen_string_literal: true

# Migrate Bot Flow 5 (Acoustic House Master Bot) to full legacy feature parity
# Usage: rails runner script/migrate_bot_flow_to_full_acoustic_house.rb
#
# This script adds all missing states, intents, and conditions to replicate
# the full AcousticHouseBotService functionality in Bot Studio.

puts '=' * 80
puts 'Bot Flow 5 Migration to Full Acoustic House Feature Parity'
puts '=' * 80
puts

# Find the flow
flow = BotFlow.find_by(id: 5)

unless flow
  puts '❌ ERROR: Bot Flow 5 not found'
  exit 1
end

puts "✅ Found flow: #{flow.name}"
puts "   Agent Bot: #{flow.agent_bot.name}"
puts "   Current nodes: #{flow.flow_data['nodes']&.length || 0}"
puts "   Current edges: #{flow.flow_data['edges']&.length || 0}"
puts

# Backup current flow data
backup_file = "tmp/flow_5_backup_#{Time.current.to_i}.json"
File.write(backup_file, JSON.pretty_generate(flow.flow_data))
puts "✅ Backup created: #{backup_file}"
puts

# Initialize flow_data if nil
flow.flow_data ||= { 'nodes' => [], 'edges' => [] }
nodes = flow.flow_data['nodes'] || []
edges = flow.flow_data['edges'] || []

# Helper to generate unique node ID
def generate_node_id(type, name)
  "#{type}-#{name.parameterize}"
end

# Helper to find node by ID
def find_node(nodes, id)
  nodes.find { |n| n['id'] == id }
end

# Current max positions for layout
current_states = nodes.select { |n| n['type'] == 'state' }
max_y = current_states.map { |n| n['position']['y'] }.max || 0
start_y = max_y + 300 # Start new nodes below existing ones

puts '📝 Adding missing state nodes...'
puts

# ============================================================================
# PHASE A: WELCOME & REGION (AHA1-AHA3)
# ============================================================================

# AHA3: Form or Name Prompt (after region selection)
unless find_node(nodes, 'state-form-or-name-prompt')
  nodes << {
    'id' => 'state-form-or-name-prompt',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y },
    'data' => {
      'label' => 'Form or Name Prompt (AHA3)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'handle_form_or_name_prompt'
        }
      ]
    }
  }
  puts '  ✅ Added: state-form-or-name-prompt (AHA3)'
end

# ============================================================================
# PHASE B: NAME COLLECTION (AHB1-AHB3)
# ============================================================================

# AHB1: Form Response Handler
unless find_node(nodes, 'state-form-response')
  nodes << {
    'id' => 'state-form-response',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 200 },
    'data' => {
      'label' => 'Form Response Handler (AHB1)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'handle_form_response'
        }
      ]
    }
  }
  puts '  ✅ Added: state-form-response (AHB1)'
end

# AHB1_2: Text Name Input (fallback)
unless find_node(nodes, 'state-text-name-input')
  nodes << {
    'id' => 'state-text-name-input',
    'type' => 'state',
    'position' => { 'x' => 500, 'y' => start_y + 200 },
    'data' => {
      'label' => 'Text Name Input (AHB1_2)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'handle_text_name_input'
        }
      ]
    }
  }
  puts '  ✅ Added: state-text-name-input (AHB1_2)'
end

# AHB2: Name Preference Selection
unless find_node(nodes, 'state-name-preference')
  nodes << {
    'id' => 'state-name-preference',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 400 },
    'data' => {
      'label' => 'Name Preference (AHB2)',
      'actions' => [
        {
          'type' => 'send_quick_reply',
          'title' => 'Which name would you like us to use?',
          'request_id' => 'qr_name',
          'items' => [
            { 'title' => 'Real Name', 'value' => 'real_name' },
            { 'title' => 'Stage Name', 'value' => 'stage_name' }
          ],
          'message' => nil
        }
      ]
    }
  }
  puts '  ✅ Added: state-name-preference (AHB2)'
end

# AHB3: Guitar List Prompt
unless find_node(nodes, 'state-guitar-list-prompt')
  nodes << {
    'id' => 'state-guitar-list-prompt',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 600 },
    'data' => {
      'label' => 'Guitar List Prompt (AHB3)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'send_guitar_list_picker'
        }
      ]
    }
  }
  puts '  ✅ Added: state-guitar-list-prompt (AHB3)'
end

# ============================================================================
# PHASE C: GUITAR SELECTION & AR (AHC1-AHC3)
# ============================================================================

# AHC1: Guitar Selection Catcher (with retry logic)
unless find_node(nodes, 'state-guitar-catcher')
  nodes << {
    'id' => 'state-guitar-catcher',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 800 },
    'data' => {
      'label' => 'Guitar Catcher (AHC1)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'handle_guitar_retry_logic'
        }
      ]
    }
  }
  puts '  ✅ Added: state-guitar-catcher (AHC1)'
end

# AHC2: AR Introduction
unless find_node(nodes, 'state-ar-intro')
  nodes << {
    'id' => 'state-ar-intro',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 1000 },
    'data' => {
      'label' => 'AR Introduction (AHC2)',
      'actions' => [
        {
          'type' => 'send_text_message',
          'text' => 'Just in. We have this cool Stratocaster. Check it out in AR!'
        },
        {
          'type' => 'execute_custom_code',
          'handler' => 'send_ar_file'
        }
      ]
    }
  }
  puts '  ✅ Added: state-ar-intro (AHC2)'
end

# AHC3: AR First Question
unless find_node(nodes, 'state-ar-question-1')
  nodes << {
    'id' => 'state-ar-question-1',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 1200 },
    'data' => {
      'label' => 'AR Question 1 (AHC3)',
      'actions' => [
        {
          'type' => 'send_quick_reply',
          'title' => 'Did you get a chance to view it in AR?',
          'request_id' => 'qr_view_ar',
          'items' => [
            { 'title' => 'Yes', 'value' => 'yes' },
            { 'title' => 'No', 'value' => 'no' }
          ],
          'message' => nil
        }
      ]
    }
  }
  puts '  ✅ Added: state-ar-question-1 (AHC3)'
end

# ============================================================================
# PHASE D-E: AR INTERACTION & APPLE PAY (AHD1, AHE1-AHE2)
# ============================================================================

# AHD1: AR View Catcher
unless find_node(nodes, 'state-ar-view-catcher')
  nodes << {
    'id' => 'state-ar-view-catcher',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 1400 },
    'data' => {
      'label' => 'AR View Catcher (AHD1)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'handle_ar_view_retry'
        }
      ]
    }
  }
  puts '  ✅ Added: state-ar-view-catcher (AHD1)'
end

# AHE1: AR Place Question
unless find_node(nodes, 'state-ar-place-question')
  nodes << {
    'id' => 'state-ar-place-question',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 1600 },
    'data' => {
      'label' => 'AR Place Question (AHE1)',
      'actions' => [
        {
          'type' => 'send_quick_reply',
          'title' => 'Were you able to place it in your room?',
          'request_id' => 'qr_place_ar',
          'items' => [
            { 'title' => 'Yes', 'value' => 'yes' },
            { 'title' => 'No', 'value' => 'no' }
          ],
          'message' => nil
        }
      ]
    }
  }
  puts '  ✅ Added: state-ar-place-question (AHE1)'
end

# AHE2: Apple Pay Prompt
unless find_node(nodes, 'state-apple-pay-prompt')
  nodes << {
    'id' => 'state-apple-pay-prompt',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 1800 },
    'data' => {
      'label' => 'Apple Pay Prompt (AHE2)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'send_apple_pay_request'
        }
      ]
    }
  }
  puts '  ✅ Added: state-apple-pay-prompt (AHE2)'
end

# ============================================================================
# PHASE F: PAYMENT & LESSON INTRO (AHF1-AHF3)
# ============================================================================

# AHF1: Apple Pay Catcher
unless find_node(nodes, 'state-apple-pay-catcher')
  nodes << {
    'id' => 'state-apple-pay-catcher',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 2000 },
    'data' => {
      'label' => 'Apple Pay Catcher (AHF1)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'handle_apple_pay_retry'
        }
      ]
    }
  }
  puts '  ✅ Added: state-apple-pay-catcher (AHF1)'
end

# AHF2: Lesson Introduction
unless find_node(nodes, 'state-lesson-intro')
  nodes << {
    'id' => 'state-lesson-intro',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 2200 },
    'data' => {
      'label' => 'Lesson Introduction (AHF2)',
      'actions' => [
        {
          'type' => 'send_text_message',
          'text' => 'Great! We also offer guitar lessons. Would you like to schedule one?'
        }
      ]
    }
  }
  puts '  ✅ Added: state-lesson-intro (AHF2)'
end

# AHF3: Location Request
unless find_node(nodes, 'state-location-request')
  nodes << {
    'id' => 'state-location-request',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 2400 },
    'data' => {
      'label' => 'Location Request (AHF3)',
      'actions' => [
        {
          'type' => 'send_text_message',
          'text' => 'We can find the closest location for you, just message us your zipcode and city.'
        }
      ]
    }
  }
  puts '  ✅ Added: state-location-request (AHF3)'
end

# ============================================================================
# PHASE G: LOCATION & STORE SELECTION (AHG1-AHG2)
# ============================================================================

# AHG1: Location Response Handler
unless find_node(nodes, 'state-location-response')
  nodes << {
    'id' => 'state-location-response',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 2600 },
    'data' => {
      'label' => 'Location Response (AHG1)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'handle_location_geocoding'
        }
      ]
    }
  }
  puts '  ✅ Added: state-location-response (AHG1)'
end

# Store selection states (routed by condition)
unless find_node(nodes, 'state-single-store-rich-link')
  nodes << {
    'id' => 'state-single-store-rich-link',
    'type' => 'state',
    'position' => { 'x' => 0, 'y' => start_y + 2800 },
    'data' => {
      'label' => 'Single Store (Rich Link)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'send_single_store_rich_link'
        }
      ]
    }
  }
  puts '  ✅ Added: state-single-store-rich-link'
end

unless find_node(nodes, 'state-store-quick-reply')
  nodes << {
    'id' => 'state-store-quick-reply',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 2800 },
    'data' => {
      'label' => 'Store Quick Reply (2-5)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'send_store_quick_reply'
        }
      ]
    }
  }
  puts '  ✅ Added: state-store-quick-reply'
end

unless find_node(nodes, 'state-store-list-picker')
  nodes << {
    'id' => 'state-store-list-picker',
    'type' => 'state',
    'position' => { 'x' => 400, 'y' => start_y + 2800 },
    'data' => {
      'label' => 'Store List Picker (6+)',
      'actions' => [
        {
          'type' => 'execute_dynamic_template',
          'handler' => 'build_store_list_picker'
        }
      ]
    }
  }
  puts '  ✅ Added: state-store-list-picker'
end

# ============================================================================
# PHASE H: TIME PICKER (AHH1-AHH2)
# ============================================================================

# AHH1: Time Picker with dynamic location
unless find_node(nodes, 'state-time-picker')
  nodes << {
    'id' => 'state-time-picker',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 3000 },
    'data' => {
      'label' => 'Time Picker (AHH1)',
      'actions' => [
        {
          'type' => 'execute_dynamic_template',
          'handler' => 'build_time_picker'
        }
      ]
    }
  }
  puts '  ✅ Added: state-time-picker (AHH1)'
end

# AHH2: Continue Prompt
unless find_node(nodes, 'state-continue-prompt')
  nodes << {
    'id' => 'state-continue-prompt',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 3200 },
    'data' => {
      'label' => 'Continue Prompt (AHH2)',
      'actions' => [
        {
          'type' => 'send_quick_reply',
          'title' => 'Shall we continue?',
          'request_id' => 'qr_continue',
          'items' => [
            { 'title' => 'Yes', 'value' => 'yes' },
            { 'title' => 'No', 'value' => 'no' }
          ],
          'message' => nil
        }
      ]
    }
  }
  puts '  ✅ Added: state-continue-prompt (AHH2)'
end

# ============================================================================
# PHASE I: RICH LINKS & PHOTOS (AHI1-AHI4)
# ============================================================================

# AHI2: Rich Link Display
unless find_node(nodes, 'state-rich-link-display')
  nodes << {
    'id' => 'state-rich-link-display',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 3400 },
    'data' => {
      'label' => 'Rich Link Display (AHI2)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'send_rich_link'
        }
      ]
    }
  }
  puts '  ✅ Added: state-rich-link-display (AHI2)'
end

# AHI3: Photo Introduction
unless find_node(nodes, 'state-photo-intro')
  nodes << {
    'id' => 'state-photo-intro',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 3600 },
    'data' => {
      'label' => 'Photo Introduction (AHI3)',
      'actions' => [
        {
          'type' => 'send_text_message',
          'text' => 'You can also send us a photo of your setup if you like!'
        }
      ]
    }
  }
  puts '  ✅ Added: state-photo-intro (AHI3)'
end

# AHI4: Photo Request (with attachment handler)
unless find_node(nodes, 'state-photo-request')
  nodes << {
    'id' => 'state-photo-request',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 3800 },
    'data' => {
      'label' => 'Photo Request (AHI4)',
      'actions' => [
        {
          'type' => 'send_quick_reply',
          'title' => 'Would you like to send a photo?',
          'request_id' => 'qr_photo',
          'items' => [
            { 'title' => 'Yes', 'value' => 'yes' },
            { 'title' => 'No', 'value' => 'no' }
          ],
          'message' => nil
        }
      ],
      'attachment_handler' => 'handle_photo_upload',
      'attachment_next_state' => 'state-documents-intro'
    }
  }
  puts '  ✅ Added: state-photo-request (AHI4)'
end

# ============================================================================
# PHASE J: DOCUMENTS & LEARN MORE (AHJ1-AHJ4)
# ============================================================================

# AHJ2: Documents Intro
unless find_node(nodes, 'state-documents-intro')
  nodes << {
    'id' => 'state-documents-intro',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 4000 },
    'data' => {
      'label' => 'Documents Intro (AHJ2)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'send_numbers_document'
        }
      ]
    }
  }
  puts '  ✅ Added: state-documents-intro (AHJ2)'
end

# AHJ3: PDF Document
unless find_node(nodes, 'state-pdf-document')
  nodes << {
    'id' => 'state-pdf-document',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 4200 },
    'data' => {
      'label' => 'PDF Document (AHJ3)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'send_pdf_document'
        }
      ]
    }
  }
  puts '  ✅ Added: state-pdf-document (AHJ3)'
end

# AHJ4: Learn More Prompt
unless find_node(nodes, 'state-learn-more-prompt')
  nodes << {
    'id' => 'state-learn-more-prompt',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 4400 },
    'data' => {
      'label' => 'Learn More Prompt (AHJ4)',
      'actions' => [
        {
          'type' => 'send_quick_reply',
          'title' => 'Would you like to learn more about Apple Messages for Business?',
          'request_id' => 'qr_learn_more',
          'items' => [
            { 'title' => 'Yes', 'value' => 'yes' },
            { 'title' => 'No', 'value' => 'no' }
          ],
          'message' => nil
        }
      ]
    }
  }
  puts '  ✅ Added: state-learn-more-prompt (AHJ4)'
end

# ============================================================================
# PHASE K: SUMMARY & COMPLETION (AHK1-AHK3)
# ============================================================================

# AHK1: Summary List Picker (already exists as state-summary-demo)
# AHK2: Final Message (already exists as state-complete)

# AHK3: Register Rich Link + Reset
unless find_node(nodes, 'state-register-link-reset')
  nodes << {
    'id' => 'state-register-link-reset',
    'type' => 'state',
    'position' => { 'x' => 200, 'y' => start_y + 4600 },
    'data' => {
      'label' => 'Register Link & Reset (AHK3)',
      'actions' => [
        {
          'type' => 'execute_custom_code',
          'handler' => 'send_register_rich_link_and_reset'
        }
      ]
    }
  }
  puts '  ✅ Added: state-register-link-reset (AHK3)'
end

puts
puts '📝 Adding missing condition nodes...'
puts

# Condition: Device Supports Forms
unless find_node(nodes, 'condition-device-supports-forms')
  nodes << {
    'id' => 'condition-device-supports-forms',
    'type' => 'condition',
    'position' => { 'x' => 350, 'y' => start_y + 100 },
    'data' => {
      'label' => 'Check Device Capability',
      'condition_type' => 'capability_check',
      'capability' => 'FORM'
    }
  }
  puts '  ✅ Added: condition-device-supports-forms'
end

# Condition: Store Count Router
unless find_node(nodes, 'condition-store-count-router')
  nodes << {
    'id' => 'condition-store-count-router',
    'type' => 'condition',
    'position' => { 'x' => 200, 'y' => start_y + 2700 },
    'data' => {
      'label' => 'Route by Store Count',
      'condition_type' => 'count_check',
      'variable' => 'available_stores'
    }
  }
  puts '  ✅ Added: condition-store-count-router'
end

# Condition: Retry Threshold
unless find_node(nodes, 'condition-retry-threshold')
  nodes << {
    'id' => 'condition-retry-threshold',
    'type' => 'condition',
    'position' => { 'x' => 350, 'y' => start_y + 900 },
    'data' => {
      'label' => 'Check Retry Count',
      'condition_type' => 'comparison',
      'variable' => 'retry_count',
      'operator' => '>=',
      'value' => 5
    }
  }
  puts '  ✅ Added: condition-retry-threshold'
end

puts
puts '📝 Adding missing intent nodes...'
puts

# Intent: Apple Pay Demo
unless find_node(nodes, 'intent-apple-pay-demo')
  nodes << {
    'id' => 'intent-apple-pay-demo',
    'type' => 'intent',
    'position' => { 'x' => 700, 'y' => start_y + 1800 },
    'data' => {
      'label' => 'Apple Pay Demo',
      'keywords' => ['apple pay', 'payment', 'pay']
    }
  }
  puts '  ✅ Added: intent-apple-pay-demo'
end

# Intent: AR Demo
unless find_node(nodes, 'intent-ar-demo')
  nodes << {
    'id' => 'intent-ar-demo',
    'type' => 'intent',
    'position' => { 'x' => 700, 'y' => start_y + 1000 },
    'data' => {
      'label' => 'AR Demo',
      'keywords' => ['ar', 'augmented reality']
    }
  }
  puts '  ✅ Added: intent-ar-demo'
end

# Intent: Stop
unless find_node(nodes, 'intent-stop')
  nodes << {
    'id' => 'intent-stop',
    'type' => 'intent',
    'position' => { 'x' => 700, 'y' => start_y + 4800 },
    'data' => {
      'label' => 'Stop',
      'keywords' => ['stop']
    }
  }
  puts '  ✅ Added: intent-stop'
end

# Intent: Schedule Lesson
unless find_node(nodes, 'intent-schedule-lesson')
  nodes << {
    'id' => 'intent-schedule-lesson',
    'type' => 'intent',
    'position' => { 'x' => 700, 'y' => start_y + 2400 },
    'data' => {
      'label' => 'Schedule Lesson',
      'keywords' => %w[schedule lesson appointment time]
    }
  }
  puts '  ✅ Added: intent-schedule-lesson'
end

# Intent: Skip Payment
unless find_node(nodes, 'intent-skip-payment')
  nodes << {
    'id' => 'intent-skip-payment',
    'type' => 'intent',
    'position' => { 'x' => 700, 'y' => start_y + 2100 },
    'data' => {
      'label' => 'Skip Payment',
      'keywords' => ['skip']
    }
  }
  puts '  ✅ Added: intent-skip-payment'
end

puts
puts '📝 Adding critical edges (connections)...'
puts

# Helper to add edge if not exists
def add_edge(edges, source, target, label = nil)
  edge_id = "#{source}-#{target}"
  return if edges.any? { |e| e['id'] == edge_id }

  edge = {
    'id' => edge_id,
    'source' => source,
    'target' => target,
    'type' => 'smoothstep'
  }
  edge['label'] = label if label

  edges << edge
  edge_id
end

# Main flow connections
add_edge(edges, 'state-region-process', 'state-form-or-name-prompt', 'After Region')
add_edge(edges, 'state-form-or-name-prompt', 'condition-device-supports-forms', 'Check Device')
add_edge(edges, 'condition-device-supports-forms', 'state-form-response', 'Supports Form')
add_edge(edges, 'condition-device-supports-forms', 'state-text-name-input', 'No Form Support')
add_edge(edges, 'state-form-response', 'state-name-preference', 'Form Submitted')
add_edge(edges, 'state-text-name-input', 'state-name-preference', 'Name Entered')
add_edge(edges, 'state-name-preference', 'state-guitar-list-prompt', 'Name Selected')
add_edge(edges, 'state-guitar-list-prompt', 'state-guitar-catcher', 'Waiting for Selection')
add_edge(edges, 'state-guitar-catcher', 'state-ar-intro', 'Guitar Selected')
add_edge(edges, 'state-ar-intro', 'state-ar-question-1', 'AR File Sent')
add_edge(edges, 'state-ar-question-1', 'state-ar-view-catcher', 'Waiting for Response')
add_edge(edges, 'state-ar-view-catcher', 'state-ar-place-question', 'Viewed AR')
add_edge(edges, 'state-ar-place-question', 'state-apple-pay-prompt', 'Placed AR')
add_edge(edges, 'state-apple-pay-prompt', 'state-apple-pay-catcher', 'Waiting for Payment')
add_edge(edges, 'state-apple-pay-catcher', 'state-lesson-intro', 'Payment Processed')
add_edge(edges, 'state-lesson-intro', 'state-location-request', 'Lesson Accepted')
add_edge(edges, 'state-location-request', 'state-location-response', 'Location Received')
add_edge(edges, 'state-location-response', 'condition-store-count-router', 'Geocoded')
add_edge(edges, 'condition-store-count-router', 'state-single-store-rich-link', '1 Store')
add_edge(edges, 'condition-store-count-router', 'state-store-quick-reply', '2-5 Stores')
add_edge(edges, 'condition-store-count-router', 'state-store-list-picker', '6+ Stores')
add_edge(edges, 'state-single-store-rich-link', 'state-time-picker', 'Store Selected')
add_edge(edges, 'state-store-quick-reply', 'state-time-picker', 'Store Selected')
add_edge(edges, 'state-store-list-picker', 'state-time-picker', 'Store Selected')
add_edge(edges, 'state-time-picker', 'state-continue-prompt', 'Time Selected')
add_edge(edges, 'state-continue-prompt', 'state-rich-link-display', 'Yes')
add_edge(edges, 'state-rich-link-display', 'state-photo-intro', 'Link Shown')
add_edge(edges, 'state-photo-intro', 'state-photo-request', 'Photo Intro Sent')
add_edge(edges, 'state-photo-request', 'state-documents-intro', 'Photo Handled')
add_edge(edges, 'state-documents-intro', 'state-pdf-document', 'Numbers Sent')
add_edge(edges, 'state-pdf-document', 'state-learn-more-prompt', 'PDF Sent')
add_edge(edges, 'state-learn-more-prompt', 'state-summary-demo', 'Learn More Answered')
add_edge(edges, 'state-summary-demo', 'state-complete', 'Summary Shown')
add_edge(edges, 'state-complete', 'state-register-link-reset', 'Complete')
add_edge(edges, 'state-register-link-reset', 'state-welcome', 'Reset to Start')

# Intent connections
add_edge(edges, 'intent-apple-pay-demo', 'state-apple-pay-prompt', 'Demo')
add_edge(edges, 'intent-ar-demo', 'state-ar-intro', 'Demo')
add_edge(edges, 'intent-schedule-lesson', 'state-location-request', 'Direct to Lesson')
add_edge(edges, 'intent-skip-payment', 'state-lesson-intro', 'Skip Payment')

puts "  ✅ Added #{edges.length - (flow.flow_data['edges']&.length || 0)} new edges"

# Update flow data
flow.flow_data = {
  'nodes' => nodes,
  'edges' => edges
}

# Save the flow
puts
puts '💾 Saving updated flow...'
if flow.save
  puts '✅ Flow saved successfully!'
  puts
  puts '📊 Final Statistics:'
  puts "   Total nodes: #{nodes.length}"
  puts "   Total edges: #{edges.length}"
  puts "   - State nodes: #{nodes.count { |n| n['type'] == 'state' }}"
  puts "   - Intent nodes: #{nodes.count { |n| n['type'] == 'intent' }}"
  puts "   - Condition nodes: #{nodes.count { |n| n['type'] == 'condition' }}"
  puts
  puts '✅ Migration complete!'
  puts
  puts 'Next steps:'
  puts '1. Open Bot Studio UI and verify the flow'
  puts '2. Adjust node positions visually if needed'
  puts '3. Test the complete flow end-to-end'
  puts "4. Backup file saved at: #{backup_file}"
else
  puts '❌ ERROR: Failed to save flow'
  puts flow.errors.full_messages.join("\n")
  exit 1
end
