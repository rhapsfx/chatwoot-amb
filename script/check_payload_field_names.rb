# frozen_string_literal: true

# Script to check what field names are actually stored in apple_msp_payload
# AND what gets returned via the API
# Usage: rails runner script/check_payload_field_names.rb

puts "\n=== Checking apple_msp_payload field names ==="
puts '=' * 80

# Find recent Quick Reply messages
messages = Message.where(content_type: 'apple_quick_reply')
                  .where.not(apple_msp_payload: nil)
                  .order(created_at: :desc)
                  .limit(3)

if messages.empty?
  puts "\n❌ No Quick Reply messages with apple_msp_payload found"
  exit
end

messages.each do |msg|
  puts "\n" + ('-' * 80)
  puts "Message ID: #{msg.id}"
  puts "Content Type: #{msg.content_type}"
  puts "Created: #{msg.created_at}"

  # Check raw database value
  raw_payload = msg.apple_msp_payload

  if raw_payload && raw_payload['payload']
    interactive_data = raw_payload['payload']['interactiveData']
    if interactive_data && interactive_data['data']
      data_keys = interactive_data['data'].keys
      puts "\n📊 RAW DATABASE - Data object keys: #{data_keys.inspect}"

      # Check specifically for quick-reply variations
      has_hyphen = data_keys.include?('quick-reply')
      has_camel = data_keys.include?('quickReply')

      puts "\nQuick Reply field check (DATABASE):"
      puts "  - Has 'quick-reply' (hyphen): #{has_hyphen}"
      puts "  - Has 'quickReply' (camelCase): #{has_camel}"

      if has_hyphen
        puts "\n✅ DATABASE: Stored with HYPHEN format (correct for Apple)"
      elsif has_camel
        puts "\n❌ DATABASE: Stored with CAMELCASE format (wrong for Apple)"
      else
        puts "\n⚠️  DATABASE: No quick reply field found"
      end

      # Show sample Quick Reply structure
      if has_hyphen
        qr_data = interactive_data['data']['quick-reply']
        puts "\nSample 'quick-reply' structure (first 2 items):"
        puts JSON.pretty_generate(qr_data.slice('summaryText', 'items'))
      elsif has_camel
        qr_data = interactive_data['data']['quickReply']
        puts "\nSample 'quickReply' structure (first 2 items):"
        puts JSON.pretty_generate(qr_data.slice('summaryText', 'items'))
      end
    end
  end

  # Now check what the API returns (simulating jbuilder)
  puts "\n" + ('-' * 40)
  puts '📡 API REPRESENTATION (via jbuilder):'

  # This simulates what the frontend receives
  api_json = {
    appleMspPayload: raw_payload
  }.to_json

  parsed = JSON.parse(api_json)
  next unless parsed['appleMspPayload'] && parsed['appleMspPayload']['payload']

  api_data_keys = parsed.dig('appleMspPayload', 'payload', 'interactiveData', 'data')&.keys
  puts "API - Data object keys: #{api_data_keys.inspect}"

  api_has_hyphen = api_data_keys&.include?('quick-reply')
  api_has_camel = api_data_keys&.include?('quickReply')

  puts "\nQuick Reply field check (API):"
  puts "  - Has 'quick-reply' (hyphen): #{api_has_hyphen}"
  puts "  - Has 'quickReply' (camelCase): #{api_has_camel}"

  if api_has_hyphen
    puts "\n✅ API: Returns HYPHEN format (correct)"
  elsif api_has_camel
    puts "\n❌ API: Returns CAMELCASE format (problem!)"
  else
    puts "\n⚠️  API: No quick reply field found"
  end
end

puts "\n" + ('=' * 80)
puts "Script complete\n\n"
