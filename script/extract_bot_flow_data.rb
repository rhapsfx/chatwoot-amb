# Script to extract and display bot_config conversation_flow data
# This helps debug why the Bot Studio UI shows nodes but no connections
#
# Usage: rails runner script/extract_bot_flow_data.rb

puts '=' * 80
puts 'Bot Flow Data Extraction Script'
puts '=' * 80
puts ''

# Find all AMB bots
bots = AgentBot.where(bot_type: 'apple_messages_for_business')

if bots.empty?
  puts '❌ No Apple Messages for Business bots found'
  exit 1
end

puts "Found #{bots.count} AMB bot(s)"
puts ''

bots.each_with_index do |bot, index|
  puts "Bot ##{index + 1}"
  puts '-' * 80
  puts "  ID: #{bot.id}"
  puts "  Name: #{bot.name}"
  puts "  Description: #{bot.description}"
  puts ''

  if bot.bot_config.nil?
    puts '  ❌ No bot_config found'
    next
  end

  puts '  ✅ Has bot_config'
  puts "  Bot config keys: #{bot.bot_config.keys.inspect}"
  puts ''

  conversation_flow = bot.bot_config['conversation_flow']

  if conversation_flow.nil?
    puts '  ❌ No conversation_flow in bot_config'
    next
  end

  puts '  ✅ Has conversation_flow'
  puts "  Conversation flow keys: #{conversation_flow.keys.inspect}"
  puts ''

  # Display flow metadata
  puts '  Flow Metadata:'
  puts "    Initial state: #{conversation_flow['initial_state']}"
  puts "    Idle timeout: #{conversation_flow['idle_timeout_minutes']} minutes" if conversation_flow['idle_timeout_minutes']
  puts ''

  # Analyze states
  states = conversation_flow['states']

  if states.nil? || states.empty?
    puts '  ❌ No states found'
    next
  end

  puts "  ✅ Found #{states.keys.count} states"
  puts ''

  # Analyze state structure (first 5 states)
  puts '  Sample States (first 5):'
  puts '  ' + ('-' * 76)

  states.keys.first(5).each do |state_id|
    state = states[state_id]
    puts ''
    puts "  State: #{state_id}"
    puts "    Keys: #{state.keys.inspect}"
    puts "    Name: #{state['name']}"
    puts "    Handler: #{state['handler']}" if state['handler']
    puts "    Description: #{state['description']}" if state['description']

    # Check for transitions/connections
    has_transitions = state.key?('transitions') && state['transitions'].present?
    has_next_state = state.key?('next_state') && state['next_state'].present?

    if has_transitions
      puts "    ✅ Has transitions: #{state['transitions'].length} transition(s)"
      state['transitions'].each_with_index do |trans, idx|
        condition = trans['condition'] || '(default)'
        next_state = trans['next_state'] || '(none)'
        priority = trans['priority'] || 0
        puts "      [#{idx}] → #{next_state} | Condition: #{condition} | Priority: #{priority}"
      end
    elsif has_next_state
      puts "    ✅ Has next_state: #{state['next_state']}"
    else
      puts '    ❌ No transitions or next_state found'
      puts '       This state has no connections to other states!'
    end
  end

  puts ''
  puts '  ' + ('-' * 76)
  puts ''

  # Summary statistics
  states_with_transitions = states.count { |_id, s| s.key?('transitions') && s['transitions'].present? }
  states_with_next_state = states.count { |_id, s| s.key?('next_state') && s['next_state'].present? }
  states_with_no_connections = states.count do |_id, s|
    (!s.key?('transitions') || s['transitions'].blank?) &&
      (!s.key?('next_state') || s['next_state'].blank?)
  end

  puts '  Connection Statistics:'
  puts "    States with 'transitions': #{states_with_transitions}"
  puts "    States with 'next_state': #{states_with_next_state}"
  puts "    States with NO connections: #{states_with_no_connections}"
  puts ''

  if states_with_no_connections > 0
    puts "  ⚠️  WARNING: #{states_with_no_connections} states have no connections!"
    puts '     This is why the Bot Studio shows nodes but no edges.'
    puts ''
  end

  # Full JSON dump of first state for detailed inspection
  puts "  Full JSON of first state (#{states.keys.first}):"
  puts '  ' + ('-' * 76)
  first_state = states[states.keys.first]
  puts JSON.pretty_generate(first_state).lines.map { |line| "  #{line}" }.join
  puts '  ' + ('-' * 76)
  puts ''

  # Check for other potential connection storage
  puts '  Checking for alternative connection storage:'

  if conversation_flow.key?('intents')
    puts "    ✅ Has 'intents': #{conversation_flow['intents']&.length || 0} intent(s)"
  else
    puts "    ❌ No 'intents' key"
  end

  if conversation_flow.key?('actions')
    puts "    ✅ Has 'actions': #{conversation_flow['actions']&.length || 0} action(s)"
  else
    puts "    ❌ No 'actions' key"
  end

  if bot.bot_config.key?('keyword_mappings')
    puts "    ✅ Has 'keyword_mappings' in bot_config"
  else
    puts "    ❌ No 'keyword_mappings' in bot_config"
  end

  if bot.bot_config.key?('interactive_handlers')
    puts "    ✅ Has 'interactive_handlers' in bot_config"
  else
    puts "    ❌ No 'interactive_handlers' in bot_config"
  end

  puts ''
end

puts '=' * 80
puts 'Analysis Complete'
puts '=' * 80
puts ''
puts 'Next Steps:'
puts '  1. Review the connection statistics above'
puts '  2. If states have no connections, we need to add transitions data'
puts '  3. Check the full JSON dump to understand the exact state structure'
puts '  4. Look for alternative connection storage (intents, keyword_mappings, etc.)'
puts ''
