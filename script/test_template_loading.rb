#!/usr/bin/env ruby
# frozen_string_literal: true

# Test Template Loading Logic
# Diagnoses issues with the /flows/templates endpoint
# Usage: rails runner script/test_template_loading.rb

puts '=' * 80
puts 'Template Loading Diagnostic'
puts '=' * 80
puts

# Get first account (assuming account_id=1 from user's error message)
account = Account.first
unless account
  puts '❌ No accounts found in database'
  exit 1
end

puts "Testing with Account: #{account.name} (ID: #{account.id})"
puts

# Step 1: Find template bots using the actual query from the controller
puts 'Step 1: Finding template bots...'
puts "Query: bot_config ->> 'is_template_bot' = 'true'"

begin
  template_bots = account.agent_bots.where("bot_config ->> 'is_template_bot' = ?", 'true')
  puts "✅ Found #{template_bots.count} template bot(s)"

  template_bots.each do |bot|
    puts "   - #{bot.name} (ID: #{bot.id})"
    puts "     bot_type: #{bot.bot_type}"
    puts "     bot_config: #{bot.bot_config.inspect}"
  end
rescue StandardError => e
  puts "❌ Error finding template bots: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end

puts

# Step 2: Find template flows using the actual query from the controller
puts 'Step 2: Finding template flows...'
puts "Query: metadata ->> 'is_template' = 'true'"

if template_bots.empty?
  puts '⚠️  No template bots found - cannot search for flows'
  puts
  puts 'Expected template bots:'
  puts '  - Flow Templates Bot'
  puts '  - Acoustic House Master Bot (if created)'
  puts
  puts 'Run these scripts to create them:'
  puts '  rails runner script/create_apple_messages_flow_templates.rb --account-id=1 --execute'
  puts '  rails runner script/create_acoustic_house_master_bot.rb --account-id=1 --execute'
  exit 0
end

begin
  template_flows = BotFlow.where(agent_bot: template_bots)
                          .where("metadata ->> 'is_template' = ?", 'true')
                          .order(created_at: :desc)

  puts "✅ Found #{template_flows.count} template flow(s)"

  template_flows.each do |flow|
    puts "   - #{flow.name} (ID: #{flow.id})"
    puts "     Agent Bot: #{flow.agent_bot.name}"
    puts "     Metadata: #{flow.metadata.inspect}"
    puts "     Flow Data Keys: #{flow.flow_data&.keys&.join(', ')}"

    # Test the manual calculations used in the endpoint
    node_count = flow.flow_data&.dig('nodes')&.size || 0
    edge_count = flow.flow_data&.dig('edges')&.size || 0
    puts "     Nodes: #{node_count}, Edges: #{edge_count}"
    puts
  end
rescue StandardError => e
  puts "❌ Error finding template flows: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end

# Step 3: Test the exact JSON transformation used in the endpoint
puts
puts 'Step 3: Testing JSON transformation...'

begin
  templates_json = template_flows.map do |flow|
    {
      id: flow.id,
      name: flow.name,
      description: flow.description,
      metadata: flow.metadata,
      flow_data: flow.flow_data,
      created_at: flow.created_at,
      updated_at: flow.updated_at,
      node_count: flow.flow_data&.dig('nodes')&.size || 0,
      edge_count: flow.flow_data&.dig('edges')&.size || 0
    }
  end

  puts "✅ Successfully transformed #{templates_json.size} flow(s) to JSON format"

  # Show sample of first template
  if templates_json.any?
    puts
    puts 'Sample template JSON (first template):'
    sample = templates_json.first
    puts "  ID: #{sample[:id]}"
    puts "  Name: #{sample[:name]}"
    puts "  Description: #{sample[:description]}"
    puts "  Node Count: #{sample[:node_count]}"
    puts "  Edge Count: #{sample[:edge_count]}"
    puts "  Metadata Category: #{sample[:metadata]&.dig('category')}"
    puts "  Flow Data Keys: #{sample[:flow_data]&.keys&.join(', ')}"
  end
rescue StandardError => e
  puts "❌ Error transforming to JSON: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end

puts
puts '=' * 80
puts '✅ All diagnostic checks passed!'
puts '=' * 80
puts
puts 'The template loading logic should work correctly.'
puts 'If the API endpoint is still returning 500 errors, check:'
puts '  1. Rails development logs: tail -f log/development.log'
puts '  2. Restart the development server: ./script/dev-server.sh restart'
puts '  3. Check browser console for the actual error response'
puts '=' * 80
