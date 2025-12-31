# frozen_string_literal: true

# Check the specific recent message we know has apple_msp_payload
# Usage: rails runner script/check_recent_payload.rb

puts "\n=== Checking Recent Quick Reply Payload (Message 7114) ==="
puts '=' * 80

# Check the specific message from logs
msg = Message.find_by(id: 7114)

if msg.nil?
  puts "\n❌ Message 7114 not found"

  # Try to find ANY recent message with apple_msp_payload
  puts "\nSearching for most recent message with apple_msp_payload..."
  recent = Message.where.not(apple_msp_payload: nil).order(created_at: :desc).limit(5)

  if recent.empty?
    puts '❌ No messages with apple_msp_payload found'
    exit
  end

  puts "\nFound #{recent.count} recent messages with apple_msp_payload:"
  recent.each do |m|
    puts "  - Message #{m.id} (#{m.content_type}) - #{m.created_at}"
  end

  msg = recent.first
  puts "\nUsing Message #{msg.id} for analysis..."
end

puts "\n" + ('-' * 80)
puts "Message ID: #{msg.id}"
puts "Content Type: #{msg.content_type}"
puts "Created: #{msg.created_at}"

# Check raw database value
raw_payload = msg.apple_msp_payload

if raw_payload.nil?
  puts "\n❌ apple_msp_payload is nil for this message"
  exit
end

puts "\n📦 Full payload structure:"
puts JSON.pretty_generate(raw_payload)

puts "\n" + ('-' * 80)

if raw_payload['payload']
  puts "\n✅ Has 'payload' key"

  if raw_payload['payload']['interactiveData']
    puts "✅ Has 'interactiveData' key"

    if raw_payload['payload']['interactiveData']['data']
      puts "✅ Has 'data' key"

      data_obj = raw_payload['payload']['interactiveData']['data']
      data_keys = data_obj.keys

      puts "\n📊 RAW DATABASE - Data object keys:"
      puts data_keys.inspect

      # Check specifically for quick-reply variations
      has_hyphen = data_keys.include?('quick-reply')
      has_camel = data_keys.include?('quickReply')

      puts "\n🔍 Quick Reply field check (DATABASE):"
      puts "  - Has 'quick-reply' (hyphen): #{has_hyphen ? '✅ YES' : '❌ NO'}"
      puts "  - Has 'quickReply' (camelCase): #{has_camel ? '⚠️  YES' : '✅ NO'}"

      if has_hyphen
        puts "\n✅ DATABASE: Stored with HYPHEN format (correct for Apple)"
        qr_data = data_obj['quick-reply']
        puts "\nQuick Reply structure:"
        puts JSON.pretty_generate(qr_data)
      elsif has_camel
        puts "\n❌ DATABASE: Stored with CAMELCASE format (wrong for Apple)"
        qr_data = data_obj['quickReply']
        puts "\nQuick Reply structure:"
        puts JSON.pretty_generate(qr_data)
      else
        puts "\n⚠️  DATABASE: No quick-reply or quickReply field found"
        puts "Available fields: #{data_keys.inspect}"
      end
    else
      puts "❌ No 'data' key in interactiveData"
    end
  else
    puts "❌ No 'interactiveData' key in payload"
  end
else
  puts "❌ No 'payload' key in apple_msp_payload"
end

puts "\n" + ('=' * 80)
puts "Script complete\n\n"
