#!/bin/bash
# Get absolute last messages - no time filtering

echo "======================================================================="
echo "🔍 LAST 40 MESSAGES - Conversation 6 (No time filter)"
echo "======================================================================="
echo ""

cat > /tmp/last_messages.rb << 'RUBY'
conversation = Conversation.find(6)

puts "Conversation #6 - Total messages: #{conversation.messages.count}"
puts "Bot state: #{conversation.custom_attributes['bot_state']}"
puts ""
puts "Last 40 messages (newest first):"
puts "=" * 70

# Get last 40 messages, ordered by ID desc (most recent first)
messages = conversation.messages.order(id: :desc).limit(40)

messages.each do |msg|
  sender = msg.incoming? ? "👤 Customer" : "🤖 Bot"
  time = msg.created_at.strftime('%H:%M:%S')

  if msg.content.present?
    # Show full content for important messages
    if msg.content.length < 100 || msg.content.include?('error') || msg.content.include?('encountered') || msg.content.include?('unavailable')
      puts "[#{time}] #{sender}: #{msg.content}"
    else
      puts "[#{time}] #{sender}: #{msg.content[0..100]}..."
    end
  else
    puts "[#{time}] #{sender}: [#{msg.content_type}]"
  end
end

puts ""
puts "=" * 70
RUBY

scp -q /tmp/last_messages.rb root@msp.rhaps.net:/tmp/

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker cp /tmp/last_messages.rb $WEB_CONTAINER:/tmp/
docker exec -e RAILS_ENV=production $WEB_CONTAINER bundle exec rails runner /tmp/last_messages.rb 2>&1 | grep -v "INFO --"
REMOTE_SCRIPT

rm -f /tmp/last_messages.rb

echo ""
echo "======================================================================="
