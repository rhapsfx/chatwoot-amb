#!/bin/bash
# Check bot state at time of error

echo "======================================================================="
echo "🤖 BOT STATE AT TIME OF ERROR"
echo "======================================================================="
echo ""

cat > /tmp/check_bot_state_at_error.rb << 'RUBY'
puts "=" * 70
puts "Bot State Analysis - Conversation 6"
puts "=" * 70
puts ""

conversation = Conversation.find(6)

# Find the error message
error_msg = conversation.messages.where("content LIKE ?", "%encountered an error finding stores%").order(id: :desc).first

if error_msg
  puts "Error message ID: #{error_msg.id}"
  puts "Error time: #{error_msg.created_at.strftime('%Y-%m-%d %H:%M:%S UTC')}"
  puts ""

  # Find the user message that triggered it
  trigger_msg = conversation.messages.where('id < ?', error_msg.id).where(message_type: :incoming).order(id: :desc).first

  if trigger_msg
    puts "Triggering message:"
    puts "  ID: #{trigger_msg.id}"
    puts "  Content: '#{trigger_msg.content}'"
    puts "  Type: #{trigger_msg.content_type}"
    puts "  Time: #{trigger_msg.created_at.strftime('%Y-%m-%d %H:%M:%S UTC')}"
    puts ""

    # Check what the bot state was
    current_state = conversation.custom_attributes['bot_state']
    puts "Current bot state: #{current_state}"
    puts ""

    # Show messages around the error
    puts "Context (5 messages before trigger):"
    context_msgs = conversation.messages.where('id < ?', trigger_msg.id).order(id: :desc).limit(5)
    context_msgs.reverse.each do |msg|
      sender = msg.incoming? ? "Customer" : "Bot"
      content = msg.content || "[#{msg.content_type}]"
      puts "  [#{msg.created_at.strftime('%H:%M:%S')}] #{sender}: #{content.truncate(60)}"
    end
  end
else
  puts "Error message not found in conversation 6"
end

puts ""
puts "=" * 70
RUBY

scp -q /tmp/check_bot_state_at_error.rb root@msp.rhaps.net:/tmp/

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker cp /tmp/check_bot_state_at_error.rb $WEB_CONTAINER:/tmp/
docker exec -e RAILS_ENV=production $WEB_CONTAINER bundle exec rails runner /tmp/check_bot_state_at_error.rb 2>&1 | grep -v "INFO --"
REMOTE_SCRIPT

rm -f /tmp/check_bot_state_at_error.rb

echo ""
echo "======================================================================="
