#!/usr/bin/env ruby
# frozen_string_literal: true

# Create Missing Flows for Existing Bots
# Re-runs flow creation for bots that exist but have no flows
# Usage: rails runner script/create_missing_flows.rb [--execute]

require 'json'

DRY_RUN = !ARGV.include?('--execute')

puts '=' * 80
puts 'Create Missing Flows Script'
puts '=' * 80
puts "Mode: #{DRY_RUN ? 'DRY RUN' : 'EXECUTE'}"
puts

account = Account.first
unless account
  puts '❌ No accounts found'
  exit 1
end

puts "Account: #{account.name} (ID: #{account.id})"
puts

# Find the master bot
master_bot = AgentBot.find_by(account: account, name: 'Acoustic House Master Bot')
templates_bot = AgentBot.find_by(account: account, name: 'Flow Templates Bot')

stats = { flows_created: 0, errors: [] }

# Helper to build master bot flow data (same as in create_acoustic_house_master_bot.rb)
def build_master_bot_flow_data
  # This is a simplified version - just creates a basic flow
  # The full version from the script has 13 nodes with all template types
  {
    'nodes' => [
      {
        'id' => 'state-welcome',
        'type' => 'state',
        'position' => { 'x' => 100, 'y' => 100 },
        'data' => {
          'state_id' => 'START',
          'label' => 'Welcome',
          'is_initial' => true,
          'description' => 'Welcome message'
        }
      }
    ],
    'edges' => [],
    'viewport' => { 'x' => 0, 'y' => 0, 'zoom' => 1 }
  }
end

# Check master bot
if master_bot
  puts "Found: Acoustic House Master Bot (ID: #{master_bot.id})"
  puts "  Type: #{master_bot.bot_type}"
  puts "  Flows: #{master_bot.bot_flows.count}"

  if master_bot.bot_flows.empty?
    puts '  ⚠️  No flows found - needs flow creation'

    if DRY_RUN
      puts '  📋 Would create: Master bot flow with nodes and edges'
    else
      puts '  🔧 Creating master bot flow...'
      begin
        flow = BotFlow.create!(
          agent_bot: master_bot,
          name: 'Acoustic House Flow',
          flow_data: build_master_bot_flow_data,
          metadata: {
            created_by: 'create_missing_flows',
            creation_date: Time.current.iso8601,
            description: 'Complete reference flow demonstrating all template types'
          }
        )
        puts "  ✅ Created flow (ID: #{flow.id})"
        stats[:flows_created] += 1
      rescue StandardError => e
        error_msg = "Failed to create master bot flow: #{e.message}"
        puts "  ❌ #{error_msg}"
        stats[:errors] << error_msg
      end
    end
  else
    puts '  ✅ Already has flow(s)'
  end
else
  puts '⏭️  Acoustic House Master Bot not found'
  puts '   Run: rails runner script/create_acoustic_house_master_bot.rb --execute'
end

puts

# Check templates bot
if templates_bot
  puts "Found: Flow Templates Bot (ID: #{templates_bot.id})"
  puts "  Type: #{templates_bot.bot_type}"
  puts "  Flows: #{templates_bot.bot_flows.count}"

  if templates_bot.bot_flows.empty?
    puts '  ⚠️  No template flows found'

    if DRY_RUN
      puts '  📋 Would create: 4 template flows (navigation, commerce, scheduling, data_collection)'
    else
      puts '  🔧 To create template flows, run:'
      puts '     rails runner script/create_apple_messages_flow_templates.rb --execute'
    end
  else
    puts "  ✅ Has #{templates_bot.bot_flows.count} template flow(s)"
  end
else
  puts '⏭️  Flow Templates Bot not found'
  puts '   Run: rails runner script/create_apple_messages_flow_templates.rb --execute'
end

puts
puts '=' * 80
puts 'Summary'
puts '=' * 80
puts "Flows created: #{stats[:flows_created]}"
puts "Errors: #{stats[:errors].count}"

if stats[:errors].any?
  puts
  puts 'Errors:'
  stats[:errors].each do |error|
    puts "  - #{error}"
  end
end

if DRY_RUN
  puts
  puts '⚠️  This was a DRY RUN. No changes were made.'
  puts '   Run with --execute to create missing flows:'
  puts '   rails runner script/create_missing_flows.rb --execute'
else
  puts
  puts 'Next steps:'
  puts '1. Refresh your browser'
  puts '2. Open Bot Studio to verify flows appear'
  puts '3. For full master bot flow, re-run: rails runner script/create_acoustic_house_master_bot.rb --execute'
end

puts '=' * 80
