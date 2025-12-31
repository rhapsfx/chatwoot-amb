#!/bin/bash
# Search ALL conversations for the Maps error message

echo "======================================================================="
echo "🔍 SEARCHING ALL CONVERSATIONS FOR MAPS ERROR"
echo "======================================================================="
echo ""

cat > /tmp/search_all_convos.rb << 'RUBY'
puts "Searching for 'encountered an error finding stores' in all conversations..."
puts ""

# Search all messages in the last 24 hours
messages = Message.where('created_at > ?', 24.hours.ago)
                  .where("content LIKE ?", "%encountered an error finding stores%")
                  .order(created_at: :desc)

puts "Found #{messages.count} message(s) with this error:"
puts "=" * 70

messages.each do |msg|
  conv = msg.conversation
  puts ""
  puts "📨 Conversation ##{conv.id} - Inbox ##{conv.inbox_id}"
  puts "   Time: #{msg.created_at.strftime('%Y-%m-%d %H:%M:%S UTC')}"
  puts "   Message: #{msg.content}"

  # Show the user message that triggered it
  prev_msg = conv.messages.where('id < ?', msg.id).where(message_type: :incoming).order(id: :desc).first
  if prev_msg
    puts "   User sent: #{prev_msg.content || "[#{prev_msg.content_type}]"}"
  end
end

if messages.empty?
  puts "(No messages found with this error in last 24 hours)"
  puts ""
  puts "Checking for 'unable to locate' messages instead..."

  unable_msgs = Message.where('created_at > ?', 24.hours.ago)
                       .where("content LIKE ?", "%unable to locate%")
                       .order(created_at: :desc)
                       .limit(5)

  if unable_msgs.any?
    puts "Found #{unable_msgs.count} 'unable to locate' message(s):"
    unable_msgs.each do |msg|
      puts "  - Conversation ##{msg.conversation_id}: #{msg.created_at.strftime('%H:%M:%S')} - #{msg.content[0..80]}"
    end
  end
end

puts ""
puts "=" * 70
RUBY

scp -q /tmp/search_all_convos.rb root@msp.rhaps.net:/tmp/

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker cp /tmp/search_all_convos.rb $WEB_CONTAINER:/tmp/
docker exec -e RAILS_ENV=production $WEB_CONTAINER bundle exec rails runner /tmp/search_all_convos.rb 2>&1 | grep -v "INFO --"
REMOTE_SCRIPT

rm -f /tmp/search_all_convos.rb

echo ""
echo "======================================================================="
