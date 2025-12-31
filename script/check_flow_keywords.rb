#!/usr/bin/env ruby
# Check what keywords should be in the flow based on legacy bot config

puts '=== Checking Flow 5 Keywords vs Legacy Bot Config ==='
puts

flow = BotFlow.find(5)
bot = flow.agent_bot

puts "Bot: #{bot.name}"
puts 'Bot Config Keywords:'
legacy_keywords = bot.bot_config['keyword_mappings'] || {}
legacy_keywords.each do |keyword, handler|
  puts "  '#{keyword}' => #{handler}"
end
puts

puts 'Flow Intent Nodes:'
nodes = flow.flow_data['nodes'] || []
intent_nodes = nodes.select { |n| n['type'] == 'intent' }

intent_nodes.each do |node|
  intent_id = node.dig('data', 'intent_id')
  keywords = node.dig('data', 'keywords') || []

  puts "\nIntent: #{node.dig('data', 'label')}"
  puts "  ID: #{intent_id}"
  puts "  Keywords: #{keywords.inspect}"
  puts "  Scope: #{node.dig('data', 'scope')}"

  # Check if this intent_id matches any legacy keyword mapping
  matching_legacy = legacy_keywords.select { |_k, v| v == intent_id || v.include?(intent_id) }
  puts "  ⚠️  SHOULD HAVE KEYWORDS: #{matching_legacy.keys.inspect}" if matching_legacy.any?
end
