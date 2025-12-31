#!/bin/bash
# Check conversation 6 messages to see what triggered the Maps error

echo "======================================================================="
echo "🔍 CHECKING CONVERSATION 6 MESSAGES"
echo "======================================================================="
echo ""

cat > /tmp/check_conversation_messages.rb << 'RUBY'
puts "=" * 70
puts "📨 Conversation 6 - Recent Messages"
puts "=" * 70
puts ""

conversation = Conversation.find(6)
puts "Conversation ##{conversation.id} - Inbox ##{conversation.inbox_id}"
puts "Total messages: #{conversation.messages.count}"
puts ""

# Get last 20 messages
messages = conversation.messages.order(created_at: :desc).limit(20).reverse

puts "Last 20 messages:"
puts "-" * 70
messages.each do |msg|
  sender = msg.incoming? ? "Customer" : "Bot/Agent"
  timestamp = msg.created_at.strftime('%H:%M:%S')

  if msg.content_type == 'input_location'
    puts "[#{timestamp}] #{sender}: 📍 Location: #{msg.content}"
  elsif msg.content.present?
    content = msg.content.truncate(80)
    puts "[#{timestamp}] #{sender}: #{content}"
  else
    puts "[#{timestamp}] #{sender}: [#{msg.content_type}]"
  end
end

puts ""
puts "=" * 70

# Check for the error message
error_msg = messages.find { |m| m.content&.include?('encountered an error finding stores') }
if error_msg
  puts ""
  puts "⚠️  Found error message at: #{error_msg.created_at.strftime('%Y-%m-%d %H:%M:%S UTC')}"

  # Find the preceding customer message
  preceding_msgs = messages.select { |m| m.created_at < error_msg.created_at && m.incoming? }.last(3)

  if preceding_msgs.any?
    puts ""
    puts "User sent before error:"
    preceding_msgs.each do |m|
      puts "  - #{m.content_type}: #{m.content}"
    end
  end
end
RUBY

scp -q /tmp/check_conversation_messages.rb root@msp.rhaps.net:/tmp/

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker cp /tmp/check_conversation_messages.rb $WEB_CONTAINER:/tmp/
docker exec -e RAILS_ENV=production $WEB_CONTAINER bundle exec rails runner /tmp/check_conversation_messages.rb
REMOTE_SCRIPT

rm -f /tmp/check_conversation_messages.rb

echo ""
echo "======================================================================="
