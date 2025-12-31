#!/bin/bash
# Get LIVE most recent messages with timestamp verification

echo "======================================================================="
echo "🔍 LIVE MESSAGE CHECK - Conversation 6"
echo "======================================================================="
echo ""

cat > /tmp/live_messages.rb << 'RUBY'
puts "=" * 70
puts "📨 LIVE Messages Check - Conversation 6"
puts "=" * 70
puts ""

# Force reload without cache
conversation = Conversation.find(6)
conversation.reload

now = Time.current
puts "Current server time: #{now.strftime('%Y-%m-%d %H:%M:%S %Z')}"
puts "Conversation ##{conversation.id}"
puts "Total messages in DB: #{conversation.messages.count}"
puts "Bot state: #{conversation.custom_attributes['bot_state']}"
puts ""

# Get messages from last 2 hours
two_hours_ago = 2.hours.ago
recent_messages = conversation.messages
                              .where('created_at > ?', two_hours_ago)
                              .order(created_at: :desc)
                              .limit(50)

puts "Messages from last 2 hours (#{two_hours_ago.strftime('%H:%M:%S')} - now):"
puts "Found: #{recent_messages.count} messages"
puts "-" * 70

if recent_messages.empty?
  puts "(No messages in last 2 hours)"
else
  recent_messages.each do |msg|
    sender = msg.incoming? ? "👤 Customer" : "🤖 Bot"
    timestamp = msg.created_at.strftime('%m/%d %H:%M:%S')
    age = ((now - msg.created_at) / 60).round(1)

    if msg.content.present?
      # Show full content for error messages
      if msg.content.include?('error') || msg.content.include?('encountered') || msg.content.include?('unable')
        puts "[#{timestamp}] (#{age}m ago) #{sender}:"
        puts "  ⚠️  #{msg.content}"
      else
        content = msg.content.length > 80 ? "#{msg.content[0..80]}..." : msg.content
        puts "[#{timestamp}] (#{age}m ago) #{sender}: #{content}"
      end
    else
      puts "[#{timestamp}] (#{age}m ago) #{sender}: [#{msg.content_type}]"
    end
  end
end

puts ""
puts "=" * 70

# Also check the absolute last message in the entire conversation
last_msg = conversation.messages.order(created_at: :desc).first
if last_msg
  age = ((now - last_msg.created_at) / 60).round(1)
  puts ""
  puts "📌 Absolute last message (#{age} minutes ago):"
  puts "   #{last_msg.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
  puts "   #{last_msg.incoming? ? 'Customer' : 'Bot'}: #{last_msg.content || "[#{last_msg.content_type}]"}"
end

puts ""
puts "=" * 70
RUBY

scp -q /tmp/live_messages.rb root@msp.rhaps.net:/tmp/

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker cp /tmp/live_messages.rb $WEB_CONTAINER:/tmp/
docker exec -e RAILS_ENV=production $WEB_CONTAINER bundle exec rails runner /tmp/live_messages.rb 2>&1
REMOTE_SCRIPT

rm -f /tmp/live_messages.rb

echo ""
echo "======================================================================="
