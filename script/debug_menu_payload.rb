# frozen_string_literal: true

# Debug the menu list picker payload format
# Run with: rails runner script/debug_menu_payload.rb

puts '=' * 80
puts 'Debug Menu List Picker Payload Format'
puts '=' * 80
puts ''

# Find template 366
template = MessageTemplate.find_by(id: 366)

unless template
  puts '❌ Template 366 not found'
  exit 1
end

puts "Template: #{template.name}"
puts "Account: #{template.account_id}"
puts ''

# Use TemplateFacade to load data
facade = AppleMessagesForBusiness::TemplateFacade.new(template)
data = facade.load_data('list_picker')

puts '=' * 80
puts 'Data from TemplateFacade (snake_case)'
puts '=' * 80
puts ''

puts "received_title: #{data['received_title'].inspect}"
puts "received_subtitle: #{data['received_subtitle'].inspect}"
puts "received_image_identifier: #{data['received_image_identifier'].inspect}"
puts "received_style: #{data['received_style'].inspect}"
puts ''

puts "reply_title: #{data['reply_title'].inspect}"
puts "reply_subtitle: #{data['reply_subtitle'].inspect}"
puts "reply_image_identifier: #{data['reply_image_identifier'].inspect}"
puts "reply_style: #{data['reply_style'].inspect}"
puts ''

puts '=' * 80
puts 'What build_received_message should return'
puts '=' * 80
puts ''

# Simulate what SendListPickerService.build_received_message does
received_msg = {
  'title' => data['received_title'] || 'Please select an option',
  'subtitle' => data['received_subtitle'],
  'image_identifier' => data['received_image_identifier'],
  'style' => data['received_style'] || 'small'
}

puts 'Before CaseTransformer:'
puts received_msg.inspect
puts ''

# Transform to Apple format
transformed = AppleMessagesForBusiness::CaseTransformer.to_apple_format(received_msg, context: :received_message)

puts 'After CaseTransformer (with :received_message context):'
puts transformed.inspect
puts ''

puts '=' * 80
puts 'What build_reply_message should return'
puts '=' * 80
puts ''

reply_msg = {
  'title' => data['reply_title'] || 'Selected: ${item.title}',
  'subtitle' => data['reply_subtitle'],
  'image_identifier' => data['reply_image_identifier'],
  'style' => data['reply_style'] || 'icon'
}

puts 'Before CaseTransformer:'
puts reply_msg.inspect
puts ''

transformed_reply = AppleMessagesForBusiness::CaseTransformer.to_apple_format(reply_msg, context: :reply_message)

puts 'After CaseTransformer (with :reply_message context):'
puts transformed_reply.inspect
puts ''

puts '=' * 80
puts 'Expected Payload Structure'
puts '=' * 80
puts ''

puts 'The interactiveData should have:'
puts '  - data.listPicker (sections)'
puts "  - receivedMessage: #{transformed.inspect}"
puts "  - replyMessage: #{transformed_reply.inspect}"
puts '  - data.images (array of base64 images)'
puts ''

puts '=' * 80
puts 'Check: Does SendMessageService call these methods?'
puts '=' * 80
puts ''

puts 'Looking at send_message_service.rb:176-182:'
puts ''
puts "  when 'apple_list_picker'"
puts '    base_data[:data][:listPicker] = build_list_picker_data'
puts '    base_data[:receivedMessage] = build_received_message  ← Should create nested object'
puts '    base_data[:replyMessage] = build_reply_message        ← Should create nested object'
puts ''

puts "If your payload has flat fields like 'receivedTitle' instead of nested 'receivedMessage',"
puts 'it means:'
puts '  A. build_received_message/build_reply_message are NOT being called'
puts '  B. OR the bot is bypassing SendListPickerService somehow'
puts "  C. OR you're looking at content_attributes, not the actual MSP payload"
puts ''

puts '=' * 80
puts 'Next Step: Check Actual Message'
puts '=' * 80
puts ''

# Find most recent list picker message
recent_message = Message
                 .where(content_type: 'apple_list_picker')
                 .where.not(apple_msp_payload: nil)
                 .order(created_at: :desc)
                 .first

if recent_message
  puts '✅ Found recent list picker message:'
  puts "   ID: #{recent_message.id}"
  puts "   Created: #{recent_message.created_at}"
  puts "   Inbox: #{recent_message.inbox_id}"
  puts ''

  payload = recent_message.apple_msp_payload
  interactive_data = payload['interactiveData'] || payload[:interactiveData]

  if interactive_data
    puts 'interactiveData structure:'
    puts "  - has receivedMessage? #{interactive_data['receivedMessage'].present? || interactive_data[:receivedMessage].present?}"
    puts "  - has replyMessage? #{interactive_data['replyMessage'].present? || interactive_data[:replyMessage].present?}"
    puts "  - has data? #{interactive_data['data'].present? || interactive_data[:data].present?}"
    puts ''

    if interactive_data['receivedMessage'] || interactive_data[:receivedMessage]
      puts '✅ receivedMessage is NESTED (correct):'
      puts (interactive_data['receivedMessage'] || interactive_data[:receivedMessage]).inspect
    elsif recent_message.content_attributes['received_title']
      puts '❌ receivedMessage is FLAT (wrong) - still in content_attributes:'
      puts "   received_title: #{recent_message.content_attributes['received_title']}"
      puts "   received_subtitle: #{recent_message.content_attributes['received_subtitle']}"
    end
    puts ''

    if interactive_data['replyMessage'] || interactive_data[:replyMessage]
      puts '✅ replyMessage is NESTED (correct):'
      puts (interactive_data['replyMessage'] || interactive_data[:replyMessage]).inspect
    elsif recent_message.content_attributes['reply_title']
      puts '❌ replyMessage is FLAT (wrong) - still in content_attributes:'
      puts "   reply_title: #{recent_message.content_attributes['reply_title']}"
      puts "   reply_subtitle: #{recent_message.content_attributes['reply_subtitle']}"
    end
  else
    puts '❌ No interactiveData found in payload'
  end
else
  puts '❌ No recent list picker messages found'
  puts ''
  puts "Send a test message by typing 'menu' keyword, then run this script again"
end

puts ''
