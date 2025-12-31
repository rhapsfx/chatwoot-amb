# frozen_string_literal: true

# Test the jbuilder fix for apple_msp_payload
# This simulates what jbuilder will output with the new template
# Usage: rails runner script/test_jbuilder_fix.rb

puts "\n=== Testing Jbuilder Fix for apple_msp_payload ==="
puts '=' * 80

# Find recent Quick Reply message
msg = Message.find_by(id: 7114)

if msg.nil?
  puts "\n❌ Message 7114 not found, finding most recent..."
  msg = Message.where(content_type: 'apple_quick_reply')
               .where.not(apple_msp_payload: nil)
               .order(created_at: :desc)
               .first
end

if msg.nil?
  puts "\n❌ No Quick Reply messages found"
  exit
end

puts "\nMessage ID: #{msg.id}"
puts "Content Type: #{msg.content_type}"

# BEFORE FIX: Regular jbuilder (camelizes everything)
require 'jbuilder'

puts "\n" + ('-' * 80)
puts 'BEFORE FIX (old jbuilder template):'
puts '-' * 80

old_json = Jbuilder.encode do |json|
  json.appleMspPayload msg.apple_msp_payload
end

parsed_old = JSON.parse(old_json)
old_data_keys = parsed_old.dig('appleMspPayload', 'payload', 'interactiveData', 'data')&.keys

puts "Data keys: #{old_data_keys.inspect}"
puts "Has 'quick-reply': #{old_data_keys&.include?('quick-reply') ? '✅' : '❌'}"
puts "Has 'quickReply': #{old_data_keys&.include?('quickReply') ? '⚠️  YES (problem)' : '✅ NO'}"

# AFTER FIX: Using json.merge! (preserves keys)
puts "\n" + ('-' * 80)
puts 'AFTER FIX (new jbuilder template with json.merge!):'
puts '-' * 80

new_json = Jbuilder.encode do |json|
  if msg.apple_msp_payload.present?
    json.set! :appleMspPayload do
      json.merge! msg.apple_msp_payload
    end
  end
end

parsed_new = JSON.parse(new_json)
new_data_keys = parsed_new.dig('appleMspPayload', 'payload', 'interactiveData', 'data')&.keys

puts "Data keys: #{new_data_keys.inspect}"
puts "Has 'quick-reply': #{new_data_keys&.include?('quick-reply') ? '✅ YES (correct!)' : '❌'}"
puts "Has 'quickReply': #{new_data_keys&.include?('quickReply') ? '❌ YES (problem)' : '✅ NO'}"

# Show the actual Quick Reply structure
if new_data_keys&.include?('quick-reply')
  puts "\n✅ SUCCESS! The 'quick-reply' key is preserved!"
  qr_data = parsed_new.dig('appleMspPayload', 'payload', 'interactiveData', 'data', 'quick-reply')
  puts "\nQuick Reply structure (ready to copy/paste):"
  puts JSON.pretty_generate(qr_data)
elsif new_data_keys&.include?('quickReply')
  puts "\n❌ FAILED: Still showing camelCase 'quickReply'"
else
  puts "\n⚠️  Unexpected: No quick-reply field found"
end

puts "\n" + ('=' * 80)
puts "Test complete\n\n"
