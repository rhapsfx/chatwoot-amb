bot = AgentBot.where(bot_type: 'apple_messages_for_business').first
if bot
  puts 'Bot found:'
  puts "  ID: #{bot.id}"
  puts "  Name: #{bot.name}"
  puts "  Has bot_config: #{!bot.bot_config.nil?}"
  puts "  Has conversation_flow: #{bot.bot_config&.dig('conversation_flow').present?}"

  if bot.bot_config&.dig('conversation_flow')
    cf = bot.bot_config['conversation_flow']
    puts ''
    puts 'Conversation Flow Structure:'
    puts "  Keys: #{cf.keys.inspect}"
    puts "  Initial state: #{cf['initial_state'].inspect}"
    puts "  Number of states: #{cf['states']&.keys&.count || 0}"

    if cf['states']
      puts ''
      puts 'First 3 states:'
      cf['states'].keys.first(3).each do |state_id|
        state = cf['states'][state_id]
        puts "  #{state_id}:"
        puts "    Keys: #{state.keys.inspect}"
        puts "    Name: #{state['name']}"
        puts "    Handler: #{state['handler']}"
        puts "    Has transitions: #{state.key?('transitions')}"
        puts "    Has next_state: #{state.key?('next_state')}"
        puts ''
      end
    end
  end
else
  puts 'No AMB bot found'
end
