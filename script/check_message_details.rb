#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to check message 1701 details
# Usage: rails runner script/check_message_details.rb --message-id 1701

require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: rails runner script/check_message_details.rb --message-id <ID>'

  opts.on('--message-id ID', Integer, 'Message ID') do |id|
    options[:message_id] = id
  end
end.parse!

unless options[:message_id]
  puts 'Error: --message-id is required'
  puts 'Get the latest message ID from your n8n workflow response'
  exit 1
end

message = Message.find(options[:message_id])

puts '=' * 80
puts "📬 Message Details: #{message.id}"
puts '=' * 80

puts "\n1️⃣  BASIC INFO:"
puts "   Content: #{message.content&.truncate(100) || '(empty)'}"
puts "   Content Type: #{message.content_type}"
puts "   Message Type: #{message.message_type}"
puts "   Status: #{message.status}"
puts "   Created: #{message.created_at}"

puts "\n2️⃣  CONTENT ATTRIBUTES:"
if message.content_attributes.present?
  ca = message.content_attributes
  puts "   Keys: #{ca.keys.inspect}"

  if ca['pages']
    puts "   ✅ Has pages (#{ca['pages'].length})"
  else
    puts '   ❌ NO PAGES'
  end

  if ca['received_message']
    puts '   ✅ Has received_message'
  else
    puts '   ⚠️  No received_message'
  end

  puts "   Title: #{ca['title']}" if ca['title']
else
  puts '   ⚠️  No content_attributes'
end

puts "\n3️⃣  EXTERNAL SOURCE IDS:"
if message.external_source_ids.present?
  puts "   #{message.external_source_ids.inspect}"
else
  puts '   ⚠️  None (message not sent to Apple)'
end

puts "\n4️⃣  APPLE MSP PAYLOAD:"
if message.apple_msp_payload.present?
  payload = message.apple_msp_payload
  puts "   Type: #{payload['type']}"
  puts "   Has body: #{payload['body'].present?}"
  puts "   Has interactiveData: #{payload['interactiveData'].present?}"

  if payload['interactiveData']
    puts "\n   📝 Interactive Data:"
    id = payload['interactiveData']
    puts "      BID: #{id['bid']}"
    puts "      Has data: #{id['data'].present?}"

    if id['data'] && id['data']['dynamic']
      dyn = id['data']['dynamic']
      puts "      Template: #{dyn['template']}"
      puts "      Version: #{dyn['version']}"
      puts "      Pages: #{dyn.dig('data', 'pages')&.length || 0}"
    end
  end
else
  puts '   ⚠️  No payload stored'
end

puts "\n5️⃣  ADDITIONAL ATTRIBUTES:"
if message.additional_attributes.present?
  aa = message.additional_attributes
  puts "   Template ID: #{aa['template_id']}"
  puts "   Template Name: #{aa['template_name']}"
end

puts "\n" + ('=' * 80)
puts '🔍 DIAGNOSIS:'

if message.content_type != 'apple_form'
  puts "   ❌ PROBLEM: content_type is '#{message.content_type}', should be 'apple_form'"
  puts '   This causes SendMessageService to use send_text_message instead of send_interactive_message'
end

if message.content.blank?
  puts '   ❌ PROBLEM: content is empty'
  puts "   This causes 'Message has no content or attachments' error"
end

if message.content_attributes.blank? || message.content_attributes['pages'].blank?
  puts '   ❌ PROBLEM: Missing pages in content_attributes'
  puts '   Form cannot be built without page structure'
end

if message.apple_msp_payload && message.apple_msp_payload['type'] == 'text'
  puts '   ❌ CONFIRMED: Message was sent as plain text, not interactive'
  puts "   Root cause: content_type was not 'apple_form' when message was created"
end

puts '=' * 80
