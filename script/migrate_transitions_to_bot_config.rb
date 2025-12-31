# Script to migrate state transitions from AcousticHouseBotService to bot_config
# This will populate conversation_flow.states with transitions so the Bot Studio can display connections
#
# Usage: rails runner script/migrate_transitions_to_bot_config.rb [--dry-run] [--bot-id=12]

require 'optparse'

# Parse command line options
options = {
  dry_run: true,
  bot_id: nil
}

OptionParser.new do |opts|
  opts.banner = 'Usage: rails runner script/migrate_transitions_to_bot_config.rb [options]'

  opts.on('--execute', 'Execute the migration (default is dry-run)') do
    options[:dry_run] = false
  end

  opts.on('--bot-id=ID', Integer, 'Migrate specific bot ID') do |id|
    options[:bot_id] = id
  end
end.parse!

puts '=' * 80
puts 'Migrate Transitions to Bot Config'
puts '=' * 80
puts ''
puts "Mode: #{options[:dry_run] ? 'DRY RUN' : 'EXECUTE'}"
puts ''

# Hardcoded state transitions extracted from AcousticHouseBotService
# This maps each state to its transitions based on the service code logic
STATE_TRANSITIONS = {
  # Branch A: Form Flow
  'AHA1' => [{ next_state: 'AHA2', condition: 'default' }],
  'AHA2' => [{ next_state: 'AHA3', condition: 'default' }],
  'AHA3' => [
    { next_state: 'AHB1', condition: 'user selects form', priority: 1 },
    { next_state: 'AHB2', condition: 'user provides name', priority: 2 }
  ],
  'AHB1' => [{ next_state: 'AHB2', condition: 'default' }],
  'AHB2' => [{ next_state: 'AHB3', condition: 'default' }],
  'AHB3' => [{ next_state: 'AHC1', condition: 'default' }],

  # Branch C: Guitar Selection
  'AHC1' => [
    { next_state: 'AHC2', condition: 'user selects guitar', priority: 1 },
    { next_state: 'AHC2', condition: 'default', priority: 2 }
  ],
  'AHC2' => [{ next_state: 'AHD1', condition: 'default' }],

  # Branch D: AR View
  'AHD1' => [
    { next_state: 'AHE1', condition: 'user views AR', priority: 1 },
    { next_state: 'AHE1', condition: 'skip AR', priority: 2 }
  ],

  # Branch E: AR Placement
  'AHE1' => [
    { next_state: 'AHF1', condition: 'user places AR', priority: 1 },
    { next_state: 'AHF1', condition: 'skip placement', priority: 2 }
  ],

  # Branch F: Lesson Scheduling
  'AHF1' => [{ next_state: 'AHG1', condition: 'default' }],
  'AHG1' => [
    { next_state: 'AHH1', condition: 'user schedules lesson', priority: 1 },
    { next_state: 'AHH2', condition: 'skip scheduling', priority: 2 }
  ],

  # Branch H: Summary
  'AHH1' => [{ next_state: 'AHI1', condition: 'default' }],
  'AHH2' => [{ next_state: 'AHI1', condition: 'default' }],
  'AHI1' => [
    { next_state: 'AHJ1', condition: 'user confirms summary', priority: 1 },
    { next_state: 'AHA1', condition: 'restart', priority: 2 }
  ],

  # Branch J: Payment
  'AHJ1' => [
    { next_state: 'AHK1', condition: 'user completes payment', priority: 1 },
    { next_state: 'AHL1', condition: 'skip payment', priority: 2 }
  ],

  # Branch K: Payment Success
  'AHK1' => [{ next_state: 'AHL1', condition: 'default' }],

  # Branch L: Authentication
  'AHL1' => [{ next_state: 'AHM1', condition: 'default' }],
  'AHM1' => [
    { next_state: 'AHN1', condition: 'user authenticates', priority: 1 },
    { next_state: 'AHN2', condition: 'skip authentication', priority: 2 }
  ],

  # Branch N: Menu Selection
  'AHN1' => [{ next_state: 'AHO1', condition: 'default' }],
  'AHN2' => [{ next_state: 'AHO1', condition: 'default' }],
  'AHO1' => [
    { next_state: 'AHA1', condition: 'restart flow', priority: 1 },
    { next_state: 'AHK2', condition: 'end conversation', priority: 2 }
  ],

  # Alternate branches
  'AHE2' => [{ next_state: 'AHF1', condition: 'default' }],
  'AHF2' => [{ next_state: 'AHG1', condition: 'default' }],
  'AHG2' => [{ next_state: 'AHH1', condition: 'default' }],

  # Documents/Rich Link flow
  'AHJ2' => [{ next_state: 'AHJ3', condition: 'default' }],
  'AHJ3' => [{ next_state: 'AHJ4', condition: 'default' }],
  'AHJ4' => [{ next_state: 'AHK0', condition: 'default' }],
  'AHK0' => [{ next_state: 'AHK2', condition: 'default' }],
  'AHK2' => [{ next_state: 'AHK3', condition: 'default' }],
  'AHK3' => [{ next_state: 'AHA1', condition: 'restart' }],

  # Demo modes (loop back to start or main menu)
  'DEMO_MODE' => [{ next_state: 'AHA1', condition: 'restart' }],
  'DEMO_MODE_LARGE_FORM' => [{ next_state: 'AHA1', condition: 'restart' }]
}.freeze

puts "Loaded #{STATE_TRANSITIONS.keys.count} state transition definitions"
puts ''

# Find bots to migrate
bots = if options[:bot_id]
         [AgentBot.find(options[:bot_id])]
       else
         AgentBot.where(bot_type: 'apple_messages_for_business')
       end

puts "Found #{bots.count} bot(s) to migrate"
puts ''

bots.each do |bot|
  puts "Bot: #{bot.name} (ID: #{bot.id})"
  puts '-' * 80

  if bot.bot_config.nil? || bot.bot_config.dig('conversation_flow', 'states').nil?
    puts '  ❌ Skipping - no conversation_flow.states'
    puts ''
    next
  end

  states = bot.bot_config['conversation_flow']['states']
  puts "  States: #{states.keys.count}"

  # Count existing transitions
  existing_transitions = states.count { |_id, s| s.key?('transitions') && s['transitions'].present? }
  puts "  Existing transitions: #{existing_transitions}"
  puts ''

  # Build new states hash with transitions
  updated_states = {}
  transitions_added = 0
  states_unchanged = 0

  states.each do |state_id, state_data|
    # Copy existing state data
    updated_state = state_data.dup

    # Add transitions if we have them in our mapping
    if STATE_TRANSITIONS.key?(state_id)
      transitions = STATE_TRANSITIONS[state_id]
      updated_state['transitions'] = transitions
      transitions_added += 1

      puts "  ✅ #{state_id}: Added #{transitions.length} transition(s)"
      transitions.each do |trans|
        condition = trans[:condition] || '(default)'
        priority = trans[:priority] || 0
        puts "      → #{trans[:next_state]} | #{condition} | Priority: #{priority}"
      end
    else
      states_unchanged += 1
      puts "  ⚠️  #{state_id}: No transitions defined (handler: #{state_data['handler']})"
    end

    updated_states[state_id] = updated_state
  end

  puts ''
  puts '  Summary:'
  puts "    Transitions added: #{transitions_added}"
  puts "    States unchanged: #{states_unchanged}"
  puts ''

  if options[:dry_run]
    puts '  🔍 DRY RUN - No changes saved'
    puts ''
    puts "  Sample updated state (#{updated_states.keys.first}):"
    puts JSON.pretty_generate(updated_states[updated_states.keys.first]).lines.map { |l| "    #{l}" }.join
  else
    # Save updated bot_config
    bot.bot_config['conversation_flow']['states'] = updated_states

    begin
      bot.save!
      puts '  ✅ SUCCESS - Transitions saved to database'
    rescue StandardError => e
      puts "  ❌ ERROR - Failed to save: #{e.message}"
    end
  end

  puts ''
end

puts '=' * 80
puts 'Migration Complete'
puts '=' * 80
puts ''

if options[:dry_run]
  puts 'This was a DRY RUN. To execute the migration, run:'
  puts '  rails runner script/migrate_transitions_to_bot_config.rb --execute'
else
  puts '✅ Transitions have been migrated to bot_config'
  puts ''
  puts 'Next Steps:'
  puts '  1. Refresh the Bot Studio UI to see the connections'
  puts '  2. Verify the flow visually'
  puts '  3. Update any missing transitions manually via the UI'
end
puts ''
