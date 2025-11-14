#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to verify and fix Acoustic House Bot templates use_cases
# Usage: rails runner script/verify_and_fix_acoustic_house_templates.rb

puts '🔍 Verifying Acoustic House Bot Templates'
puts '=' * 60
puts ''

# Find all Acoustic House Bot templates
templates = MessageTemplate.where("'acoustic_house_bot' = ANY(tags)")

if templates.empty?
  puts '❌ No Acoustic House Bot templates found'
  exit 1
end

puts "📋 Found #{templates.count} templates"
puts ''

templates.each do |template|
  puts "Template: #{template.name} (ID: #{template.id})"
  puts "  Status: #{template.status}"
  puts "  Supported Channels: #{template.supported_channels.inspect}"
  puts "  Use Cases: #{template.use_cases.inspect}"

  if template.use_cases.include?('bot_api_only')
    puts '  ⚠️  HAS bot_api_only restriction - FIXING...'
    template.update!(use_cases: [])
    puts "  ✅ FIXED - use_cases now: #{template.use_cases.inspect}"
  elsif template.use_cases.empty?
    puts '  ✅ OK - No restrictions'
  else
    puts "  ⚠️  Has other use_cases: #{template.use_cases.inspect}"
  end
  puts ''
end

puts '=' * 60
puts '✅ Verification complete!'
puts ''
puts 'All Acoustic House Bot templates should now be accessible via / command'
