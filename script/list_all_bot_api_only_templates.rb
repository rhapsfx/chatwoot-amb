#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to list ALL templates with bot_api_only restriction
# Usage: rails runner script/list_all_bot_api_only_templates.rb

puts '🔍 Listing All Templates with bot_api_only Restriction'
puts '=' * 60
puts ''

account = Account.first
all_templates = account.message_templates

puts "Total templates in account: #{all_templates.count}"
puts ''

bot_only_templates = all_templates.select { |t| t.use_cases.include?('bot_api_only') }

if bot_only_templates.empty?
  puts '✅ No templates have bot_api_only restriction'
else
  puts "⚠️  Found #{bot_only_templates.count} templates with bot_api_only restriction:"
  puts ''

  bot_only_templates.each do |template|
    puts "  • #{template.name} (ID: #{template.id})"
    puts "    Status: #{template.status}"
    puts "    Channels: #{template.supported_channels.inspect}"
    puts "    Tags: #{template.tags.inspect}"
    puts ''
  end

  puts '=' * 60
  puts 'To remove bot_api_only restriction from ALL templates, run:'
  puts '  rails runner script/remove_all_bot_api_only_restrictions.rb'
end
