#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple verification script for AMB Bot Studio implementation
# Usage: rails runner script/verify_amb_bot_setup.rb

puts '=' * 80
puts 'AMB Bot Studio - Quick Verification'
puts '=' * 80
puts

# 1. Check database tables
puts '1. Database Tables:'
tables = {
  'agent_bot_versions' => 'Version history table',
  'agent_bot_inboxes' => 'Inbox associations table (enhanced)',
  'agent_bots' => 'Main bot configuration table'
}

tables.each do |table, desc|
  if ActiveRecord::Base.connection.table_exists?(table)
    puts "   ✅ #{table} - #{desc}"
  else
    puts "   ❌ #{table} - MISSING"
  end
end
puts

# 2. Check column additions
puts '2. New Columns:'
columns_to_check = {
  agent_bot_inboxes: %w[priority config_overrides version_id notes],
  agent_bots: %w[bot_config bot_type]
}

columns_to_check.each do |table, columns|
  columns.each do |col|
    if ActiveRecord::Base.connection.column_exists?(table, col)
      puts "   ✅ #{table}.#{col}"
    else
      puts "   ❌ #{table}.#{col} - MISSING"
    end
  end
end
puts

# 3. Check models
puts '3. Models & Associations:'
checks = [
  ['AgentBotVersion exists', -> { AgentBotVersion }],
  ['AgentBot.bot_versions association', -> { AgentBot.reflect_on_association(:bot_versions) }],
  ['AgentBotInbox.version association', -> { AgentBotInbox.reflect_on_association(:version) }],
  ['AgentBot AMB enum value', -> { AgentBot.bot_types['apple_messages_for_business'] }]
]

checks.each do |name, check|
  result = check.call
  if result
    puts "   ✅ #{name}"
  else
    puts "   ⚠️  #{name} - exists but nil"
  end
rescue StandardError => e
  puts "   ❌ #{name} - #{e.message}"
end
puts

# 4. Check rake tasks file
puts '4. Rake Tasks File:'
rake_file = Rails.root.join('lib/tasks/amb_bot.rake')
if File.exist?(rake_file)
  puts '   ✅ lib/tasks/amb_bot.rake exists'
  tasks_count = File.read(rake_file).scan('task :').count
  puts "   ℹ️  Found #{tasks_count} task definitions"
else
  puts '   ❌ lib/tasks/amb_bot.rake - MISSING'
end
puts

# 5. Check API controllers
puts '5. API Controllers:'
controllers = {
  'api/v1/accounts/agent_bots/versions_controller.rb' => 'Version management',
  'api/v1/accounts/agent_bots/inboxes_controller.rb' => 'Inbox management'
}

controllers.each do |path, desc|
  full_path = Rails.root.join('app/controllers', path)
  if File.exist?(full_path)
    puts "   ✅ #{path} - #{desc}"
  else
    puts "   ❌ #{path} - MISSING"
  end
end
puts

# 6. Check Vue components
puts '6. Frontend Components:'
components = {
  'routes/dashboard/settings/agentBots/components/AgentBotModal.vue' => 'Bot creation/edit modal',
  'routes/dashboard/settings/agentBots/components/BotVersionHistoryDialog.vue' => 'Version history',
  'routes/dashboard/settings/agentBots/components/BotInboxManagerDialog.vue' => 'Inbox manager',
  'routes/dashboard/settings/agentBots/Index.vue' => 'Bot list view'
}

components.each do |path, desc|
  full_path = Rails.root.join('app/javascript/dashboard', path)
  if File.exist?(full_path)
    puts "   ✅ #{desc}"
  else
    puts "   ❌ #{desc} - MISSING"
  end
end
puts

# 7. Summary
puts '=' * 80
puts 'Summary'
puts '=' * 80
puts
puts 'If all checks above show ✅, the AMB Bot Studio is ready to use!'
puts
puts 'Next steps:'
puts '  1. Restart your Rails server (if running)'
puts '  2. Visit Settings → Agent Bots'
puts '  3. Click "Add Bot" and select "Apple Messages Bot"'
puts '  4. Paste bot configuration and test'
puts
puts 'Documentation: docs/apple-messages/implementation/ACOUSTIC_HOUSE_BOT_UI_IMPLEMENTATION_COMPLETE.md'
puts '=' * 80
