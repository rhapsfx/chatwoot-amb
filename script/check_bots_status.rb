#!/usr/bin/env ruby
# frozen_string_literal: true

# Check Bots Status
# Shows all bots and their flows
# Usage: rails runner script/check_bots_status.rb

puts '=' * 80
puts 'Current Bots Status'
puts '=' * 80
puts

account = Account.first
unless account
  puts '❌ No accounts found'
  exit 1
end

puts "Account: #{account.name} (ID: #{account.id})"
puts

# Find all bots with "Acoustic House" or "Flow Templates" in the name
relevant_bots = account.agent_bots.where('name LIKE ? OR name LIKE ?', '%Acoustic House%', '%Flow Templates%')

puts "Found #{relevant_bots.count} relevant bot(s):"
puts

relevant_bots.each do |bot|
  puts "Bot ID #{bot.id}: #{bot.name}"
  puts "  Type: #{bot.bot_type}"
  puts "  Config keys: #{bot.bot_config&.keys&.join(', ')}"
  puts "  is_template_bot: #{bot.bot_config&.dig('is_template_bot')}"

  # Check for associated flows
  flows = bot.bot_flows
  puts "  Flows: #{flows.count}"

  flows.each do |flow|
    nodes = flow.flow_data&.dig('nodes')&.size || 0
    edges = flow.flow_data&.dig('edges')&.size || 0
    puts "    - Flow ID #{flow.id}: #{flow.name}"
    puts "      Nodes: #{nodes}, Edges: #{edges}"
    puts "      is_template: #{flow.metadata&.dig('is_template')}"
  end

  puts
end

puts '=' * 80
puts 'Diagnosis:'
puts '=' * 80

# Find webhook bots that should be AMB
webhook_bots = relevant_bots.where(bot_type: 'webhook')
if webhook_bots.any?
  puts "❌ Found #{webhook_bots.count} bot(s) with incorrect 'webhook' type:"
  webhook_bots.each do |bot|
    puts "   - Bot ID #{bot.id}: #{bot.name}"
  end
  puts
  puts "Fix: Run 'rails runner script/fix_bot_types.rb'"
end

# Find bots without flows
bots_without_flows = relevant_bots.select { |bot| bot.bot_flows.empty? }
if bots_without_flows.any?
  puts "⚠️  Found #{bots_without_flows.count} bot(s) without flows:"
  bots_without_flows.each do |bot|
    puts "   - Bot ID #{bot.id}: #{bot.name}"
  end
  puts
  puts 'This means the flow creation failed when the bot was created.'
  puts 'You may need to delete these bots and recreate them.'
end

# Check for duplicate bots
bot_names = relevant_bots.pluck(:name)
duplicates = bot_names.select { |name| bot_names.count(name) > 1 }.uniq
if duplicates.any?
  puts '⚠️  Found duplicate bot names:'
  duplicates.each do |name|
    dupe_bots = relevant_bots.where(name: name)
    puts "   - '#{name}' exists #{dupe_bots.count} times:"
    dupe_bots.each do |bot|
      puts "     Bot ID #{bot.id}: #{bot.bot_type} (#{bot.bot_flows.count} flows)"
    end
  end
  puts
  puts 'Recommendation: Delete the webhook version(s) and keep the AMB version(s)'
end

puts '=' * 80
