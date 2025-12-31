# Check bot 12 configuration
bot = AgentBot.find(12)
puts "Bot ID: #{bot.id}"
puts "Bot Name: #{bot.name}"
puts "Bot Type: #{bot.bot_type}"
puts "Has bot_config: #{!bot.bot_config.nil?}"

if bot.bot_config
  puts "\nBot Config Keys: #{bot.bot_config.keys.inspect}"

  if bot.bot_config['conversation_flow']
    states = bot.bot_config.dig('conversation_flow', 'states') || {}
    puts "\nConversation Flow States: #{states.keys.inspect}"
  end

  if bot.bot_config['keyword_mappings']
    demo = bot.bot_config.dig('keyword_mappings', 'demo_keywords') || {}
    flow = bot.bot_config.dig('keyword_mappings', 'flow_control_keywords') || {}
    puts "\nDemo Keywords: #{demo.keys.inspect}"
    puts "Flow Control Keywords: #{flow.keys.inspect}"
  end
else
  puts "\n⚠️ Bot has NO bot_config!"
end

# Check for existing flows
flows = bot.bot_flows
puts "\nExisting Flows: #{flows.count}"
flows.each do |flow|
  puts "  - Flow ##{flow.id}: #{flow.name} (#{flow.node_count} nodes)"
end
