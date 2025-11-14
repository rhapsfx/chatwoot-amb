#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to remove bot_api_only restriction from ALL templates in the account
# Usage: rails runner script/remove_all_bot_api_only_restrictions.rb

puts '🔧 Removing bot_api_only Restriction from ALL Templates'
puts '=' * 60
puts ''

account = Account.first
all_templates = account.message_templates

bot_only_templates = all_templates.select { |t| t.use_cases.include?('bot_api_only') }

if bot_only_templates.empty?
  puts '✅ No templates have bot_api_only restriction'
  exit 0
end

puts "Found #{bot_only_templates.count} templates with bot_api_only restriction"
puts ''

fixed_count = 0
error_count = 0

bot_only_templates.each do |template|
  # Remove bot_api_only from use_cases
  new_use_cases = template.use_cases.reject { |uc| uc == 'bot_api_only' }
  template.update!(use_cases: new_use_cases)

  puts "  ✅ Fixed: #{template.name} (ID: #{template.id})"
  fixed_count += 1
rescue StandardError => e
  puts "  ❌ Error: #{template.name} (ID: #{template.id}) - #{e.message}"
  error_count += 1
end

puts ''
puts '=' * 60
puts "✅ Fixed: #{fixed_count}"
puts "❌ Errors: #{error_count}"
puts ''

if error_count.zero?
  puts '🎉 SUCCESS! All templates are now accessible via / command'
else
  puts '⚠️  Some templates had errors. Check above for details.'
end
