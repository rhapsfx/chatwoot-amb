#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to remove bot_api_only restriction from Acoustic House Bot templates
# This allows templates to be accessible via / command in ReplyBox
# Usage: rails runner script/fix_template_use_cases.rb

puts '🔧 Fixing Template Use Cases - Remove Bot API Restriction'
puts '=' * 60
puts ''

# Find all Acoustic House Bot templates
templates = MessageTemplate.where("'acoustic_house_bot' = ANY(tags)")

if templates.empty?
  puts '❌ No Acoustic House Bot templates found'
  exit 1
end

puts "📋 Found #{templates.count} templates to fix"
puts ''

fixed_count = 0
already_ok_count = 0
error_count = 0

templates.each do |template|
  if template.use_cases.nil? || template.use_cases.empty?
    puts "  ✅ Already OK: #{template.name} (ID: #{template.id}) - No use_cases restriction"
    already_ok_count += 1
  elsif template.use_cases.include?('bot_api_only')
    # Remove the bot_api_only restriction
    template.update!(use_cases: [])
    puts "  🔧 Fixed: #{template.name} (ID: #{template.id}) - Removed bot_api_only restriction"
    fixed_count += 1
  else
    puts "  ⚠️  Unknown: #{template.name} (ID: #{template.id}) - Has use_cases: #{template.use_cases.inspect}"
    already_ok_count += 1
  end
rescue StandardError => e
  puts "  ❌ Error: #{template.name} (ID: #{template.id}) - #{e.message}"
  error_count += 1
end

puts ''
puts '=' * 60
puts '📊 SUMMARY'
puts '=' * 60
puts "🔧 Fixed: #{fixed_count}"
puts "✅ Already OK: #{already_ok_count}"
puts "❌ Errors: #{error_count}"
puts ''

if error_count.zero?
  puts '🎉 SUCCESS! All templates are now accessible via / command in ReplyBox'
  puts ''
  puts '📝 Templates you can now use in ReplyBox:'
  templates.each do |t|
    slug = t.name.downcase.gsub(/\s+/, '-').gsub(/[^a-z0-9\-]/, '')
    puts "   /#{slug}"
  end
else
  puts '⚠️  Some templates had errors. Check above for details.'
end
