#!/bin/bash
# Detailed Acoustic House Bot debugging

echo "======================================================================="
echo "🤖 ACOUSTIC HOUSE BOT - DETAILED DEBUG"
echo "======================================================================="
echo ""

echo "Step 1: Check if bot templates are accessible..."

cat > /tmp/check_bot_templates.rb <<'RUBY'
puts "Bot Service Template Check:"
puts "=" * 70

result = AppleMessagesForBusiness::AcousticHouseBotService.verify_templates_exist(1)

puts "All templates present: #{result[:all_present]}"
puts "Found: #{result[:found].join(', ')}"

if result[:missing].any?
  puts "Missing: #{result[:missing].join(', ')}"
end

puts ""
puts "Template Details:"
puts "-" * 70

result[:found].each do |template_name|
  t = MessageTemplate.find_by(account_id: 1, name: template_name)
  if t
    puts "#{template_name}:"
    puts "  ID: #{t.id}"
    puts "  Status: #{t.status}"
    puts "  Content blocks: #{t.content_blocks.count}"
    puts "  Metadata present: #{t.metadata.present?}"
  end
end
RUBY

scp -q /tmp/check_bot_templates.rb root@msp.rhaps.net:/tmp/
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker cp /tmp/check_bot_templates.rb $(docker compose -f docker-compose.production.yml ps -q web):/tmp/'
ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner /tmp/check_bot_templates.rb RAILS_ENV=production' 2>&1 | grep -v "INFO --"

echo ""
echo "Step 2: Check recent bot conversations..."

cat > /tmp/check_bot_conversations.rb <<'RUBY'
puts ""
puts "Recent Bot Conversations:"
puts "=" * 70

# Find Apple Messages for Business channel IDs first
amb_channels = Channel::AppleMessagesForBusiness.all
if amb_channels.empty?
  puts "No Apple Messages for Business channels found"
  exit 0
end

# Get inbox IDs from channels
inbox_ids = Inbox.where(channel_id: amb_channels.pluck(:id), channel_type: 'Channel::AppleMessagesForBusiness').pluck(:id)

if inbox_ids.empty?
  puts "No Apple Messages for Business inboxes found"
  exit 0
end

puts "Found #{inbox_ids.size} AMB inbox(es): #{inbox_ids.join(', ')}"
puts ""

# Get recent conversations
recent_convos = Conversation.where(inbox_id: inbox_ids)
                           .order(created_at: :desc)
                           .limit(5)

if recent_convos.empty?
  puts "No conversations found"
  exit 0
end

recent_convos.each do |convo|
  puts ""
  puts "Conversation ##{convo.id}:"
  puts "  Created: #{convo.created_at}"
  puts "  Status: #{convo.status}"
  puts "  Inbox ID: #{convo.inbox_id}"
  puts "  Messages: #{convo.messages.count}"

  # Show last 5 messages
  puts "  Last messages:"
  convo.messages.order(created_at: :desc).limit(5).reverse.each do |msg|
    sender = msg.incoming? ? "Customer" : "Bot/Agent"
    content_preview = msg.content&.truncate(60) || msg.content_type
    puts "    [#{msg.created_at.strftime('%H:%M:%S')}] #{sender}: #{content_preview}"
  end
end
RUBY

scp -q /tmp/check_bot_conversations.rb root@msp.rhaps.net:/tmp/
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker cp /tmp/check_bot_conversations.rb $(docker compose -f docker-compose.production.yml ps -q web):/tmp/'
ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner /tmp/check_bot_conversations.rb RAILS_ENV=production' 2>&1 | grep -v "INFO --"

echo ""
echo "Step 3: Check for bot-related errors in logs..."

ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs --tail=500 web 2>/dev/null | grep -i "acoustichousebotservice\|bot.*error\|template.*not found" | tail -30' || echo "No bot errors found"

echo ""
echo "======================================================================="
echo "RECOMMENDATIONS"
echo "======================================================================="
echo ""
echo "If bot stops responding:"
echo "  1. Check if conversation is still 'open' status"
echo "  2. Verify bot is enabled for the inbox"
echo "  3. Check if customer messages are being received"
echo "  4. Look for template loading errors"
echo ""
echo "Live monitoring:"
echo "  ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs web -f | grep -i \"bot\|acoustic\"'"
echo ""

rm -f /tmp/check_bot_templates.rb /tmp/check_bot_conversations.rb
