#!/usr/bin/env ruby
# frozen_string_literal: true

# Export Bot Flow 18 (Acoustic House Master Bot) complete structure
# Usage: rails runner script/export_bot_flow_18.rb

require 'json'

# Find Bot Flow 18
bot_flow = BotFlow.find_by(id: 18)

unless bot_flow
  puts 'ERROR: Bot Flow 18 not found'
  exit 1
end

puts '=' * 80
puts "BOT FLOW 18: #{bot_flow.name}"
puts '=' * 80
puts "ID: #{bot_flow.id}"
puts "Account: #{bot_flow.account_id}"
puts "Active: #{bot_flow.is_active}"
puts "Published: #{bot_flow.is_published}"
puts "Created: #{bot_flow.created_at}"
puts "Updated: #{bot_flow.updated_at}"
puts "\n"

# Export States
puts '=' * 80
puts "STATES (#{bot_flow.bot_flow_states.count})"
puts '=' * 80

bot_flow.bot_flow_states.order(:position).each do |state|
  puts "\n--- State: #{state.name} (ID: #{state.id}) ---"
  puts "Type: #{state.state_type}"
  puts "Position: #{state.position}"
  puts "Entry Actions: #{state.entry_actions.inspect}"
  puts "Exit Actions: #{state.exit_actions.inspect}"

  if state.config.present?
    puts 'Config:'
    puts JSON.pretty_generate(state.config)
  end
end

# Export Intents
puts "\n\n"
puts '=' * 80
puts "INTENTS (#{bot_flow.bot_flow_intents.count})"
puts '=' * 80

bot_flow.bot_flow_intents.order(:name).each do |intent|
  puts "\n--- Intent: #{intent.name} (ID: #{intent.id}) ---"
  puts "Intent Type: #{intent.intent_type}"
  puts "Keywords: #{intent.keywords.inspect}"
  puts "Patterns: #{intent.patterns.inspect}"

  if intent.config.present?
    puts 'Config:'
    puts JSON.pretty_generate(intent.config)
  end
end

# Export Actions
puts "\n\n"
puts '=' * 80
puts "ACTIONS (#{bot_flow.bot_flow_actions.count})"
puts '=' * 80

bot_flow.bot_flow_actions.order(:name).each do |action|
  puts "\n--- Action: #{action.name} (ID: #{action.id}) ---"
  puts "Action Type: #{action.action_type}"

  if action.config.present?
    puts 'Config:'
    puts JSON.pretty_generate(action.config)
  end
end

# Export Conditions
puts "\n\n"
puts '=' * 80
puts "CONDITIONS (#{bot_flow.bot_flow_conditions.count})"
puts '=' * 80

bot_flow.bot_flow_conditions.order(:name).each do |condition|
  puts "\n--- Condition: #{condition.name} (ID: #{condition.id}) ---"
  puts "Condition Type: #{condition.condition_type}"

  if condition.config.present?
    puts 'Config:'
    puts JSON.pretty_generate(condition.config)
  end
end

# Export Transitions
puts "\n\n"
puts '=' * 80
puts "TRANSITIONS (#{bot_flow.bot_flow_transitions.count})"
puts '=' * 80

bot_flow.bot_flow_transitions.order(:from_state_id, :priority).each do |transition|
  from_state = bot_flow.bot_flow_states.find_by(id: transition.from_state_id)
  to_state = bot_flow.bot_flow_states.find_by(id: transition.to_state_id)

  puts "\n--- Transition (ID: #{transition.id}) ---"
  puts "From: #{from_state&.name || 'N/A'} (#{transition.from_state_id})"
  puts "To: #{to_state&.name || 'N/A'} (#{transition.to_state_id})"
  puts "Priority: #{transition.priority}"
  puts "Trigger Type: #{transition.trigger_type}"
  puts "Intent ID: #{transition.intent_id}" if transition.intent_id
  puts "Condition ID: #{transition.condition_id}" if transition.condition_id

  if transition.config.present?
    puts 'Config:'
    puts JSON.pretty_generate(transition.config)
  end
end

# Export Template Associations
puts "\n\n"
puts '=' * 80
puts 'TEMPLATE ASSOCIATIONS'
puts '=' * 80

# Search for template references in states
bot_flow.bot_flow_states.each do |state|
  next unless state.config.present?

  # Check entry actions
  next unless state.entry_actions.present?

  state.entry_actions.each do |action_id|
    action = bot_flow.bot_flow_actions.find_by(id: action_id)
    next unless action

    if action.action_type == 'send_template' && action.config['template_id']
      template = MessageTemplate.find_by(id: action.config['template_id'])
      puts "State '#{state.name}' → Action '#{action.name}' → Template: #{template&.name || 'NOT FOUND'} (ID: #{action.config['template_id']})"
    end
  end
end

puts "\n\n"
puts '=' * 80
puts 'EXPORT COMPLETE'
puts '=' * 80
