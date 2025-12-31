#!/usr/bin/env ruby
# frozen_string_literal: true

# Manual test script for FlowValidatorService
# Usage: rails runner script/test_flow_validator.rb

require_relative '../config/environment'

puts '=== Flow Validator Service Manual Test ==='
puts

# Find or create test data
account = Account.first
unless account
  puts '❌ No accounts found. Please create an account first.'
  exit 1
end

agent_bot = account.agent_bots.first
unless agent_bot
  puts '❌ No agent bots found. Creating one...'
  agent_bot = account.agent_bots.create!(
    name: 'Test Bot',
    description: 'Bot for testing flow validator'
  )
  puts "✅ Created agent bot: #{agent_bot.name}"
end

puts "Using account: #{account.name} (ID: #{account.id})"
puts "Using agent bot: #{agent_bot.name} (ID: #{agent_bot.id})"
puts

# Test 1: Valid simple flow
puts '=== Test 1: Valid Simple Flow ==='
valid_flow_data = {
  'nodes' => [
    { 'id' => 'start_1', 'type' => 'start', 'data' => { 'label' => 'Start' } },
    { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1', 'label' => 'Welcome' } },
    { 'id' => 'end_1', 'type' => 'end', 'data' => { 'label' => 'End' } }
  ],
  'edges' => [
    { 'id' => 'e1', 'source' => 'start_1', 'target' => 'state_1' },
    { 'id' => 'e2', 'source' => 'state_1', 'target' => 'end_1' }
  ]
}

flow1 = agent_bot.bot_flows.create!(
  name: 'Valid Simple Flow',
  flow_data: valid_flow_data
)

validator1 = AppleMessagesForBusiness::FlowValidatorService.new(flow1)
result1 = validator1.validate

puts "Valid: #{result1[:valid]}"
puts "Errors: #{result1[:errors].length}"
puts "Warnings: #{result1[:warnings].length}"
if result1[:errors].any?
  puts 'Error details:'
  result1[:errors].each { |e| puts "  - #{e}" }
end
puts

# Test 2: Flow with errors (missing state_id)
puts '=== Test 2: Flow with Missing State ID ==='
invalid_flow_data = {
  'nodes' => [
    { 'id' => 'state_1', 'type' => 'state', 'data' => { 'label' => 'Welcome' } }
  ],
  'edges' => []
}

flow2 = agent_bot.bot_flows.create!(
  name: 'Invalid Flow - Missing State ID',
  flow_data: invalid_flow_data
)

validator2 = AppleMessagesForBusiness::FlowValidatorService.new(flow2)
result2 = validator2.validate

puts "Valid: #{result2[:valid]}"
puts "Errors: #{result2[:errors].length}"
if result2[:errors].any?
  puts 'Error details:'
  result2[:errors].each do |e|
    puts "  - Type: #{e[:type]}"
    puts "    Node: #{e[:node_id]}"
    puts "    Message: #{e[:message]}"
  end
end
puts

# Test 3: Flow with circular reference
puts '=== Test 3: Flow with Circular Reference ==='
circular_flow_data = {
  'nodes' => [
    { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } },
    { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2' } },
    { 'id' => 'state_3', 'type' => 'state', 'data' => { 'state_id' => 'AHA3' } }
  ],
  'edges' => [
    { 'id' => 'e1', 'source' => 'state_1', 'target' => 'state_2' },
    { 'id' => 'e2', 'source' => 'state_2', 'target' => 'state_3' },
    { 'id' => 'e3', 'source' => 'state_3', 'target' => 'state_1' }
  ]
}

flow3 = agent_bot.bot_flows.create!(
  name: 'Invalid Flow - Circular Reference',
  flow_data: circular_flow_data
)

validator3 = AppleMessagesForBusiness::FlowValidatorService.new(flow3)
result3 = validator3.validate

puts "Valid: #{result3[:valid]}"
puts "Errors: #{result3[:errors].length}"
if result3[:errors].any?
  puts 'Error details:'
  result3[:errors].each do |e|
    puts "  - Type: #{e[:type]}"
    puts "    Message: #{e[:message]}"
  end
end
puts

# Test 4: Flow with non-existent template
puts '=== Test 4: Flow with Non-Existent Template ==='
template_flow_data = {
  'nodes' => [
    { 'id' => 'template_1', 'type' => 'template', 'data' => { 'template_name' => 'nonexistent_template' } },
    { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
  ],
  'edges' => []
}

flow4 = agent_bot.bot_flows.create!(
  name: 'Invalid Flow - Non-Existent Template',
  flow_data: template_flow_data
)

validator4 = AppleMessagesForBusiness::FlowValidatorService.new(flow4)
result4 = validator4.validate

puts "Valid: #{result4[:valid]}"
puts "Errors: #{result4[:errors].length}"
if result4[:errors].any?
  puts 'Error details:'
  result4[:errors].each do |e|
    puts "  - Type: #{e[:type]}"
    puts "    Node: #{e[:node_id]}"
    puts "    Template: #{e[:template_name]}"
    puts "    Message: #{e[:message]}"
  end
end
puts

# Cleanup
puts '=== Cleanup ==='
[flow1, flow2, flow3, flow4].each do |flow|
  flow.destroy
  puts "Deleted flow: #{flow.name}"
end

puts
puts '✅ All tests completed!'
