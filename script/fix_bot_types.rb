#!/usr/bin/env ruby
# frozen_string_literal: true

# Fix bot types for template-based system bots
# Updates bot_type from 'webhook' to 'apple_messages_for_business'
# Usage: rails runner script/fix_bot_types.rb

puts '=' * 80
puts 'Fixing Bot Types for Template System Bots'
puts '=' * 80
puts

# Minimal AMB bot_config structure for template bots
def minimal_amb_config(existing_config)
  {
    conversation_flow: {},
    keyword_mappings: {},
    interactive_handlers: {},
    required_templates: []
  }.merge(existing_config || {})
end

# Find and update Acoustic House Master Bot
master_bot = AgentBot.find_by(name: 'Acoustic House Master Bot')
if master_bot
  old_type = master_bot.bot_type
  master_bot.update!(
    bot_type: 'apple_messages_for_business',
    bot_config: minimal_amb_config(master_bot.bot_config)
  )
  puts '✅ Updated: Acoustic House Master Bot'
  puts "   Old type: #{old_type}"
  puts "   New type: #{master_bot.bot_type}"
  puts
else
  puts '⏭️  Acoustic House Master Bot not found'
  puts
end

# Find and update Flow Templates Bot
templates_bot = AgentBot.find_by(name: 'Flow Templates Bot')
if templates_bot
  old_type = templates_bot.bot_type
  templates_bot.update!(
    bot_type: 'apple_messages_for_business',
    bot_config: minimal_amb_config(templates_bot.bot_config)
  )
  puts '✅ Updated: Flow Templates Bot'
  puts "   Old type: #{old_type}"
  puts "   New type: #{templates_bot.bot_type}"
  puts
else
  puts '⏭️  Flow Templates Bot not found'
  puts
end

puts '=' * 80
puts 'Fix Complete!'
puts '=' * 80
puts
puts 'Refresh your browser to see the updated bot types.'
puts '=' * 80
