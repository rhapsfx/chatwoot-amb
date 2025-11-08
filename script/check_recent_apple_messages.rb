#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to check recent Apple Messages outgoing messages
# Usage: rails runner script/check_recent_apple_messages.rb --inbox-id 6 --limit 10

require 'optparse'

options = { limit: 10 }
OptionParser.new do |opts|
  opts.banner = 'Usage: rails runner script/check_recent_apple_messages.rb [options]'

  opts.on('--inbox-id ID', Integer, 'Inbox ID') do |id|
    options[:inbox_id] = id
  end

  opts.on('--limit N', Integer, 'Number of messages to show (default: 10)') do |n|
    options[:limit] = n
  end

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end
end.parse!

unless options[:inbox_id]
  puts 'Error: --inbox-id is required'
  exit 1
end

inbox = Inbox.find(options[:inbox_id])

puts '=' * 80
puts "📬 Recent Outgoing Messages for: #{inbox.name} (ID: #{inbox.id})"
puts '=' * 80

messages = Message
           .where(inbox: inbox, message_type: :outgoing)
           .order(created_at: :desc)
           .limit(options[:limit])

if messages.empty?
  puts "\n❌ No outgoing messages found"
  exit
end

messages.each_with_index do |msg, idx|
  puts "\n#{idx + 1}. Message ID: #{msg.id}"
  puts "   Created: #{msg.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
  puts "   Conversation: #{msg.conversation_id}"
  puts "   Content Type: #{msg.content_type}"
  puts "   Content: #{msg.content&.truncate(100) || '(no text content)'}"

  if msg.content_attributes.present?
    puts '   Content Attributes:'
    ca = msg.content_attributes

    if ca.is_a?(Hash)
      puts "      Keys: #{ca.keys.inspect}"

      # Check for form-specific attributes
      puts "      ✅ Has pages (#{ca['pages'].length})" if ca['pages']

      puts '      ✅ Has received_message' if ca['received_message']

      # Check content_type
      puts "      content_type: #{ca['content_type']}" if ca['content_type']
    else
      puts "      Type: #{ca.class}"
      puts "      Value: #{ca.inspect.truncate(100)}"
    end
  else
    puts '   ⚠️  No content_attributes'
  end

  # Check if it was sent successfully
  if msg.external_source_ids.present?
    puts "   ✅ External IDs: #{msg.external_source_ids.inspect}"
  else
    puts '   ⚠️  No external source IDs (might not have been sent)'
  end

  # Check status
  puts "   Status: #{msg.status}" if msg.status.present?
end

puts "\n" + ('=' * 80)
puts '💡 TIPS:'
puts '   - Messages without external_source_ids were likely not sent to Apple'
puts '   - Check logs: tail -f log/development.log | grep -i apple'
puts '   - Check Sidekiq for failed jobs: bundle exec sidekiq'
puts '=' * 80
