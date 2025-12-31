#!/bin/bash
# Check most recent messages in conversation 6

echo "======================================================================="
echo "🔍 CONVERSATION 6 - MOST RECENT MESSAGES"
echo "======================================================================="
echo ""

cat > /tmp/check_recent_messages.rb << 'RUBY'
puts "=" * 70
puts "📨 Conversation 6 - Most Recent Messages (newest first)"
puts "=" * 70
puts ""

conversation = Conversation.find(6)
puts "Conversation ##{conversation.id} - Inbox ##{conversation.inbox_id}"
puts "Total messages: #{conversation.messages.count}"
puts "Bot state: #{conversation.custom_attributes['bot_state']}"
puts ""

# Get last 30 messages, newest first
messages = conversation.messages.order(created_at: :desc).limit(30)

puts "Last 30 messages (newest first):"
puts "-" * 70
messages.each do |msg|
  sender = msg.incoming? ? "👤 Customer" : "🤖 Bot/Agent"
  timestamp = msg.created_at.strftime('%m/%d %H:%M:%S')

  if msg.content_type == 'input_location'
    puts "[#{timestamp}] #{sender}: 📍 Location: #{msg.content}"
  elsif msg.content.present?
    # Show full content for error messages
    if msg.content.include?('error') || msg.content.include?('encountered')
      puts "[#{timestamp}] #{sender}: #{msg.content}"
    else
      content = msg.content.truncate(100)
      puts "[#{timestamp}] #{sender}: #{content}"
    end
  else
    puts "[#{timestamp}] #{sender}: [#{msg.content_type}]"
  end
end

puts ""
puts "=" * 70
RUBY

scp -q /tmp/check_recent_messages.rb root@msp.rhaps.net:/tmp/

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker cp /tmp/check_recent_messages.rb $WEB_CONTAINER:/tmp/
docker exec -e RAILS_ENV=production $WEB_CONTAINER bundle exec rails runner /tmp/check_recent_messages.rb
REMOTE_SCRIPT

rm -f /tmp/check_recent_messages.rb

echo ""
echo "======================================================================="
