# Script to extract keyword_mappings and interactive_handlers
# These likely contain the state transition logic
#
# Usage: rails runner script/extract_connection_data.rb

puts '=' * 80
puts 'Bot Connection Data Extraction Script'
puts '=' * 80
puts ''

# Find the first AMB bot
bot = AgentBot.where(bot_type: 'apple_messages_for_business').first

if bot.nil?
  puts '❌ No AMB bot found'
  exit 1
end

puts "Analyzing Bot: #{bot.name} (ID: #{bot.id})"
puts '=' * 80
puts ''

# 1. Keyword Mappings Analysis
puts '1. KEYWORD MAPPINGS'
puts '-' * 80

if bot.bot_config['keyword_mappings'].present?
  keyword_mappings = bot.bot_config['keyword_mappings']
  puts '✅ Found keyword_mappings'
  puts ''
  puts 'Structure:'
  puts JSON.pretty_generate(keyword_mappings).lines.first(50).map { |line| "  #{line}" }.join

  puts "  ... (truncated, #{keyword_mappings.length} total lines)" if keyword_mappings.length > 50
  puts ''

  # Analyze structure
  if keyword_mappings.is_a?(Hash)
    puts "Type: Hash with #{keyword_mappings.keys.count} keys"
    puts "Keys: #{keyword_mappings.keys.first(10).inspect}"
    puts ''

    # Show first mapping in detail
    first_key = keyword_mappings.keys.first
    if first_key
      puts "Sample mapping (#{first_key}):"
      puts JSON.pretty_generate(keyword_mappings[first_key]).lines.map { |line| "    #{line}" }.join
    end
  elsif keyword_mappings.is_a?(Array)
    puts "Type: Array with #{keyword_mappings.length} items"
    puts ''
    puts 'First item:'
    puts JSON.pretty_generate(keyword_mappings.first).lines.map { |line| "    #{line}" }.join
  end
else
  puts '❌ No keyword_mappings found'
end

puts ''
puts ''

# 2. Interactive Handlers Analysis
puts '2. INTERACTIVE HANDLERS'
puts '-' * 80

if bot.bot_config['interactive_handlers'].present?
  interactive_handlers = bot.bot_config['interactive_handlers']
  puts '✅ Found interactive_handlers'
  puts ''
  puts 'Structure:'
  puts JSON.pretty_generate(interactive_handlers).lines.first(50).map { |line| "  #{line}" }.join

  puts "  ... (truncated, #{interactive_handlers.length} total lines)" if interactive_handlers.length > 50
  puts ''

  # Analyze structure
  if interactive_handlers.is_a?(Hash)
    puts "Type: Hash with #{interactive_handlers.keys.count} keys"
    puts "Keys: #{interactive_handlers.keys.first(10).inspect}"
    puts ''

    # Show first handler in detail
    first_key = interactive_handlers.keys.first
    if first_key
      puts "Sample handler (#{first_key}):"
      puts JSON.pretty_generate(interactive_handlers[first_key]).lines.map { |line| "    #{line}" }.join
    end
  elsif interactive_handlers.is_a?(Array)
    puts "Type: Array with #{interactive_handlers.length} items"
    puts ''
    puts 'First item:'
    puts JSON.pretty_generate(interactive_handlers.first).lines.map { |line| "    #{line}" }.join
  end
else
  puts '❌ No interactive_handlers found'
end

puts ''
puts ''

# 3. Try to map handlers to states
puts '3. HANDLER TO STATE MAPPING'
puts '-' * 80

states = bot.bot_config.dig('conversation_flow', 'states') || {}
handler_to_state = {}

states.each do |state_id, state_data|
  handler_name = state_data['handler']
  handler_to_state[handler_name] = state_id if handler_name
end

puts "Found #{handler_to_state.count} handler-to-state mappings:"
puts ''

handler_to_state.first(10).each do |handler, state_id|
  puts "  #{handler.ljust(35)} → #{state_id}"
end

puts "  ... (#{handler_to_state.count - 10} more)" if handler_to_state.count > 10

puts ''
puts ''

# 4. Analysis: Can we derive transitions?
puts '4. TRANSITION DERIVATION ANALYSIS'
puts '-' * 80

if bot.bot_config['interactive_handlers'].present?
  puts 'Checking if interactive_handlers contain transition logic...'
  puts ''

  # Look for patterns that might indicate transitions
  interactive_handlers = bot.bot_config['interactive_handlers']

  if interactive_handlers.is_a?(Hash)
    # Check if handlers reference state IDs
    handlers_with_state_refs = []

    interactive_handlers.each do |handler_key, handler_data|
      handler_str = handler_data.to_s

      # Check if this handler mentions any state IDs
      state_refs = states.keys.select { |state_id| handler_str.include?(state_id) }

      next unless state_refs.any?

      handlers_with_state_refs << {
        handler: handler_key,
        references: state_refs
      }
    end

    if handlers_with_state_refs.any?
      puts "✅ Found #{handlers_with_state_refs.count} handlers that reference state IDs:"
      puts ''

      handlers_with_state_refs.first(10).each do |item|
        puts "  #{item[:handler]}:"
        puts "    References: #{item[:references].join(', ')}"
      end

      puts "  ... (#{handlers_with_state_refs.count - 10} more)" if handlers_with_state_refs.count > 10
    else
      puts '❌ No handlers found that directly reference state IDs'
    end
  end
end

puts ''
puts '=' * 80
puts 'RECOMMENDATIONS'
puts '=' * 80
puts ''

puts 'Based on the analysis:'
puts ''
puts '1. States only contain: name, handler, description'
puts '2. Transitions are NOT stored in conversation_flow.states'
puts '3. Connection logic is likely in:'
puts '   - keyword_mappings (for text-based transitions)'
puts '   - interactive_handlers (for button/picker-based transitions)'
puts ''
puts 'Next Steps:'
puts '1. Parse interactive_handlers to extract state transitions'
puts '2. Parse keyword_mappings if it contains state routing'
puts "3. Build a migration script to add 'transitions' to each state"
puts '4. This will populate the visual Bot Studio with connections'
puts ''
