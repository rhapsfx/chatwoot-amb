# frozen_string_literal: true

# Check most recent list picker message from inbox 6
# Run with: rails runner script/check_inbox_6_payload.rb

puts '=' * 80
puts 'Check Most Recent List Picker from Inbox 6'
puts '=' * 80
puts ''

inbox_6_messages = Message
                   .where(content_type: 'apple_list_picker', inbox_id: 6)
                   .order(created_at: :desc)
                   .limit(5)

if inbox_6_messages.empty?
  puts '❌ No list picker messages found in inbox 6'
  puts ''
  puts "This means the bot hasn't sent the menu from inbox 6 yet."
  puts ''
  puts 'To test:'
  puts '  1. Make sure you have a conversation active in inbox 6 (Eloiza T1)'
  puts "  2. Type 'menu' keyword"
  puts '  3. Run this script again'
  puts ''
  exit 0
end

puts "Found #{inbox_6_messages.count} list picker messages in inbox 6"
puts ''

inbox_6_messages.each_with_index do |msg, i|
  puts '=' * 80
  puts "Message #{i + 1}: ID #{msg.id}"
  puts '=' * 80
  puts ''
  puts "Created: #{msg.created_at}"
  puts "Message Type: #{msg.message_type}"
  puts "Content Type: #{msg.content_type}"
  puts "Has apple_msp_payload: #{msg.apple_msp_payload.present?}"
  puts ''

  if msg.apple_msp_payload.present?
    payload = msg.apple_msp_payload
    interactive_data = payload['interactiveData'] || payload[:interactiveData]

    if interactive_data
      puts "interactiveData keys: #{interactive_data.keys.inspect}"
      puts ''

      # Check for FLAT fields (wrong)
      flat_received_fields = [
        interactive_data['receivedTitle'],
        interactive_data['received_title'],
        interactive_data[:receivedTitle],
        interactive_data[:received_title]
      ].compact

      flat_reply_fields = [
        interactive_data['replyTitle'],
        interactive_data['reply_title'],
        interactive_data[:replyTitle],
        interactive_data[:reply_title]
      ].compact

      if flat_received_fields.any? || flat_reply_fields.any?
        puts '❌ FLAT STRUCTURE DETECTED (WRONG):'
        puts "   receivedTitle: #{interactive_data['receivedTitle'] || interactive_data[:receivedTitle]}"
        puts "   receivedSubtitle: #{interactive_data['receivedSubtitle'] || interactive_data[:receivedSubtitle]}"
        puts "   receivedImageIdentifier: #{interactive_data['receivedImageIdentifier'] || interactive_data[:receivedImageIdentifier]}"
        puts "   receivedStyle: #{interactive_data['receivedStyle'] || interactive_data[:receivedStyle]}"
        puts ''
        puts "   replyTitle: #{interactive_data['replyTitle'] || interactive_data[:replyTitle]}"
        puts "   replySubtitle: #{interactive_data['replySubtitle'] || interactive_data[:replySubtitle]}"
        puts "   replyImageIdentifier: #{interactive_data['replyImageIdentifier'] || interactive_data[:replyImageIdentifier]}"
        puts "   replyStyle: #{interactive_data['replyStyle'] || interactive_data[:replyStyle]}"
        puts ''
      end

      # Check for NESTED objects (correct)
      received_msg = interactive_data['receivedMessage'] || interactive_data[:receivedMessage]
      reply_msg = interactive_data['replyMessage'] || interactive_data[:replyMessage]

      if received_msg
        puts '✅ NESTED receivedMessage (CORRECT):'
        puts received_msg.inspect
        puts ''
      else
        puts '❌ NO receivedMessage object found'
        puts ''
      end

      if reply_msg
        puts '✅ NESTED replyMessage (CORRECT):'
        puts reply_msg.inspect
        puts ''
      else
        puts '❌ NO replyMessage object found'
        puts ''
      end

      # Check images
      data = interactive_data['data'] || interactive_data[:data]
      if data
        images = data['images'] || data[:images]
        if images
          puts "Images in payload: #{images.count}"
          puts "Image identifiers: #{images.map { |img| img['identifier'] || img[:identifier] }.inspect}"
          puts ''

          has_messages_png = images.any? { |img| (img['identifier'] || img[:identifier]) == 'messages_png' }
          if has_messages_png
            puts '✅ messages_png IS in the images array'
          else
            puts '❌ messages_png is NOT in the images array'
          end
        else
          puts '❌ No images array in data'
        end
      else
        puts '❌ No data object in interactiveData'
      end

      puts ''
    else
      puts '❌ No interactiveData in payload'
      puts ''
    end
  else
    puts '❌ No apple_msp_payload saved for this message'
    puts ''
  end

  # Show content_attributes for comparison
  puts 'content_attributes (always flat - this is EXPECTED):'
  ca = msg.content_attributes || {}
  puts "  received_title: #{ca['received_title']}"
  puts "  received_image_identifier: #{ca['received_image_identifier']}"
  puts "  reply_title: #{ca['reply_title']}"
  puts "  images count: #{ca['images']&.count || 0}"
  puts ''
end

puts '=' * 80
puts 'DIAGNOSIS'
puts '=' * 80
puts ''

latest = inbox_6_messages.first

if latest&.apple_msp_payload.present?
  payload = latest.apple_msp_payload
  interactive_data = payload['interactiveData'] || payload[:interactiveData]

  has_nested = (interactive_data['receivedMessage'] || interactive_data[:receivedMessage]).present?
  has_flat = (interactive_data['receivedTitle'] || interactive_data[:receivedTitle]).present?

  if has_nested && !has_flat
    puts '✅ GOOD: Latest message has NESTED structure (correct)'
    puts ''
    puts "If you're seeing flat fields, you might be looking at:"
    puts '  1. content_attributes (expected to be flat)'
    puts '  2. Logs from an older version of the code'
    puts '  3. A different message not from inbox 6'
  elsif has_flat
    puts '❌ BAD: Latest message has FLAT structure (incorrect)'
    puts ''
    puts 'This means SendListPickerService is NOT transforming the fields properly.'
    puts "Need to investigate why build_received_message/build_reply_message aren't being called."
  else
    puts '⚠️  UNCLEAR: No receivedMessage or receivedTitle found'
    puts ''
    puts 'Need to check if the payload was built correctly'
  end
else
  puts '⚠️  No apple_msp_payload to analyze'
  puts ''
  puts "Try typing 'menu' keyword from inbox 6 and run this script again"
end

puts ''
