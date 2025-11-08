#!/usr/bin/env ruby
# Diagnostic script for Apple Messages for Business webhook issues

require_relative '../config/environment'

puts '=' * 80
puts 'Apple Messages for Business Diagnostic Report'
puts '=' * 80
puts

# 1. Check Chatwoot Configuration
puts '1. CHATWOOT CONFIGURATION'
puts '-' * 80
puts "Environment: #{Rails.env}"
puts "Base URL: #{ENV.fetch('FRONTEND_URL', 'Not set')}"
puts "Installation Name: #{ENV.fetch('INSTALLATION_NAME', 'Not set')}"
puts

# 2. Check Channels
puts '2. CONFIGURED CHANNELS'
puts '-' * 80
channels = Channel::AppleMessagesForBusiness.all
if channels.empty?
  puts '❌ No Apple Messages channels found!'
else
  channels.each do |channel|
    puts "\nChannel ID: #{channel.id}"
    puts "  Business ID: #{channel.business_id}"
    puts "  MSP ID: #{channel.msp_id}"
    puts "  Webhook URL: #{channel.webhook_url}"
    puts "  Account ID: #{channel.account_id}"
    puts "  Inbox ID: #{channel.inbox&.id}"
    puts "  Inbox Name: #{channel.inbox&.name}"
    puts "  Created: #{channel.created_at}"
    puts "  Updated: #{channel.updated_at}"
  end
end
puts

# 3. Check Recent Messages
puts '3. RECENT MESSAGES (Last 24 hours)'
puts '-' * 80
channels.each do |channel|
  inbox = channel.inbox
  next unless inbox

  recent_messages = Message.where(inbox_id: inbox.id)
                           .where('created_at > ?', 24.hours.ago)
                           .order(created_at: :desc)
                           .limit(5)

  puts "\nInbox: #{inbox.name} (ID: #{inbox.id})"
  if recent_messages.empty?
    puts '  ❌ No messages in last 24 hours'
  else
    recent_messages.each do |msg|
      puts "  - #{msg.created_at}: #{msg.message_type} from #{msg.sender&.name || 'Unknown'}"
    end
  end
end
puts

# 4. Check Webhook Logs
puts '4. RECENT WEBHOOK ACTIVITY (Last 100 log lines)'
puts '-' * 80
log_file = Rails.root.join('log', "#{Rails.env}.log")
if File.exist?(log_file)
  webhook_logs = `tail -n 100 #{log_file} | grep "AMB Webhook"`.split("\n")
  if webhook_logs.empty?
    puts '❌ No webhook activity found in recent logs'
    puts '   This suggests Apple is not sending webhooks to this server'
  else
    puts "✅ Found #{webhook_logs.count} webhook log entries:"
    webhook_logs.last(10).each { |log| puts "  #{log}" }
  end
else
  puts "❌ Log file not found: #{log_file}"
end
puts

# 5. Test Webhook Endpoint
puts '5. WEBHOOK ENDPOINT TEST'
puts '-' * 80
base_url = ENV.fetch('FRONTEND_URL', 'http://localhost:10750')
webhook_url = "#{base_url}/webhooks/apple_messages_for_business"
puts "Testing: #{webhook_url}"

require 'net/http'
require 'uri'

begin
  uri = URI.parse(webhook_url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')
  http.open_timeout = 5
  http.read_timeout = 5

  request = Net::HTTP::Post.new(uri.path)
  request['Content-Type'] = 'application/json'
  request.body = '{"test": "ping"}'

  response = http.request(request)
  puts '✅ Endpoint is accessible'
  puts "   Status: #{response.code} #{response.message}"
  puts '   Expected: 400 Bad Request (missing destination-id header)'
rescue StandardError => e
  puts "❌ Endpoint test failed: #{e.message}"
end
puts

# 6. Recommendations
puts '6. TROUBLESHOOTING RECOMMENDATIONS'
puts '-' * 80

if channels.empty?
  puts '❌ No channels configured - create an Apple Messages channel first'
elsif webhook_logs.empty?
  puts '❌ No webhook activity detected. Possible causes:'
  puts '   1. Apple Business Register webhook URL is incorrect'
  puts "   2. Business ID in Apple Business Register doesn't match any channel"
  puts '   3. Apple Business Chat is not active for this business'
  puts '   4. Messages are not being sent to the correct business'
  puts
  puts '   Action items:'
  puts "   - Verify webhook URL in Apple Business Register: #{webhook_url}"
  puts '   - Verify Business ID in Apple Business Register matches one of:'
  channels.each { |c| puts "     * #{c.business_id} (Channel #{c.id})" }
  puts '   - Send a test message from your Apple device'
  puts '   - Check Apple Business Register for any error messages'
else
  puts '✅ Webhook activity detected - check specific error messages above'
end

puts
puts '=' * 80
puts 'Diagnostic Complete'
puts '=' * 80
