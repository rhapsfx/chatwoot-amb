#!/bin/bash
# Test Apple Pay sending directly (bypassing bot)

echo "======================================================================="
echo "🧪 DIRECT APPLE PAY TEST (Conversation 6)"
echo "======================================================================="
echo ""

cat > /tmp/test_applepay_send.rb << 'RUBY'
puts "=" * 70
puts "🧪 Testing Apple Pay Send (Conversation 6, Inbox 11)"
puts "=" * 70
puts ""

# Load conversation 6
conversation = Conversation.find(6)
puts "📨 Conversation ##{conversation.id}"
puts "   Inbox: ##{conversation.inbox_id}"
puts "   Channel: #{conversation.inbox.channel.class.name} ##{conversation.inbox.channel.id}"
puts ""

# Build test payment data
payment_data = {
  'request_identifier' => 'test_' + SecureRandom.hex(8),
  'merchant_name' => 'Acoustic House',
  'currency_code' => 'USD',
  'country_code' => 'US',
  'line_items' => [
    {
      'label' => 'Test Guitar',
      'amount' => '0.01',
      'type' => 'final'
    }
  ],
  'total' => {
    'label' => 'Acoustic House',
    'amount' => '0.01',
    'type' => 'final'
  },
  'received_title' => 'Buy your new Test Guitar',
  'received_subtitle' => 'test payment',
  'received_style' => 'large'
}

puts "💳 Payment data prepared"
puts "   Amount: $0.01"
puts "   Item: Test Guitar"
puts ""

# Create service
puts "📋 Creating SendApplePayService..."
begin
  service = AppleMessagesForBusiness::SendApplePayService.new(
    channel: conversation.inbox.channel,
    destination_id: conversation.contact_inbox.source_id,
    payment_data: payment_data
  )
  puts "   ✅ Service initialized"
rescue => e
  puts "   ❌ Failed to initialize service: #{e.message}"
  puts "      #{e.backtrace.first(3).join("\n      ")}"
  exit 1
end

puts ""
puts "🚀 Calling service.perform..."
puts ""

# Call perform and capture full result
begin
  result = service.perform

  puts "=" * 70
  puts "📊 RESULT"
  puts "=" * 70
  puts ""
  puts "Result class: #{result.class.name}"
  puts "Result: #{result.inspect}"
  puts ""

  if result.is_a?(Hash)
    puts "Hash keys: #{result.keys.inspect}"
    puts "  success: #{result[:success].inspect} (type: #{result[:success].class.name})"
    puts "  error: #{result[:error].inspect}" if result[:error]
    puts "  message_id: #{result[:message_id].inspect}" if result[:message_id]
    puts ""

    if result[:success] == true
      puts "✅ SUCCESS - Apple Pay request sent"
    else
      puts "❌ FAILED"
      puts "   Error: #{result[:error]}" if result[:error]
    end
  else
    puts "⚠️  Unexpected result type (not a Hash)"
  end

rescue => e
  puts "=" * 70
  puts "💥 EXCEPTION"
  puts "=" * 70
  puts ""
  puts "Exception class: #{e.class.name}"
  puts "Message: #{e.message}"
  puts ""
  puts "Backtrace:"
  puts e.backtrace.first(10).map { |line| "  #{line}" }.join("\n")
end

puts ""
puts "=" * 70
RUBY

echo "Copying test script to production..."
scp -q /tmp/test_applepay_send.rb root@msp.rhaps.net:/tmp/

echo "Running test on production server..."
echo ""
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)

docker cp /tmp/test_applepay_send.rb $WEB_CONTAINER:/tmp/
docker exec -e RAILS_ENV=production $WEB_CONTAINER bundle exec rails runner /tmp/test_applepay_send.rb
REMOTE_SCRIPT

rm -f /tmp/test_applepay_send.rb

echo ""
echo "======================================================================="
