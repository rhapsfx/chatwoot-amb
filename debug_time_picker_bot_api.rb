#!/usr/bin/env ruby
# Debug script for time picker bot API delivery issue
# Run with: ruby debug_time_picker_bot_api.rb

require_relative 'config/environment'

puts '='*80
puts 'Time Picker Bot API - Delivery Debug Script'
puts '='*80
puts

# Step 1: Find a time picker template
puts 'Step 1: Finding time picker template...'
template = MessageTemplate.where("metadata->>'apple_message_content' IS NOT NULL")
                          .where("metadata->'apple_message_content'->'content_attributes'->'event' IS NOT NULL")
                          .first

if template.nil?
  puts '❌ No time picker template found'
  puts 'Creating test template...'

  # You can create a test template here or use an existing template ID
  puts 'Please provide a template ID with time picker: '
  template_id = STDIN.gets.chomp.to_i
  template = MessageTemplate.find(template_id) if template_id > 0
end

if template.nil?
  puts '❌ Cannot proceed without a template'
  exit 1
end

puts "✅ Found template: #{template.name} (ID: #{template.id})"
puts

# Step 2: Test BotRendererService with available_slots
puts 'Step 2: Testing BotRendererService...'
puts '-'*80

test_slots = [
  (1.hour.from_now).iso8601,
  (2.hours.from_now).iso8601,
  (3.hours.from_now).iso8601
]

puts 'Input available_slots:'
puts JSON.pretty_generate(test_slots)
puts

begin
  renderer = Templates::BotRendererService.new(
    template_id: template.id,
    parameters: { 'available_slots' => test_slots },
    channel_type: 'apple_messages_for_business'
  )

  rendered = renderer.render_for_bot

  puts '✅ Renderer succeeded'
  puts "Content type: #{rendered[:content_type]}"
  puts
  puts 'Event data:'
  puts JSON.pretty_generate(rendered[:content_attributes]['event'] || {})
  puts

  event_timeslots = rendered[:content_attributes].dig('event', 'timeslots')
  if event_timeslots.nil? || event_timeslots.empty?
    puts '❌ ERROR: No timeslots in rendered output!'
    puts 'Full content_attributes:'
    puts JSON.pretty_generate(rendered[:content_attributes])
    exit 1
  else
    puts "✅ Timeslots present in rendered output: #{event_timeslots.length} slots"
    puts 'First timeslot:'
    puts JSON.pretty_generate(event_timeslots.first)
  end
rescue StandardError => e
  puts "❌ Renderer failed: #{e.message}"
  puts e.backtrace.join("\n")
  exit 1
end

puts

# Step 3: Find a test conversation
puts 'Step 3: Finding test conversation...'
puts '-'*80

conversation = Conversation.joins(:inbox)
                           .where("inboxes.channel_type = 'Channel::AppleMessagesForBusiness'")
                           .order(created_at: :desc)
                           .first

if conversation.nil?
  puts '❌ No Apple Messages conversation found'
  puts 'Please provide a conversation ID: '
  conv_id = STDIN.gets.chomp.to_i
  conversation = Conversation.find(conv_id) if conv_id > 0
end

if conversation.nil?
  puts '❌ Cannot proceed without a conversation'
  exit 1
end

puts "✅ Found conversation: #{conversation.display_id} (Inbox: #{conversation.inbox.name})"
puts

# Step 4: Create message via BotMessagingService
puts 'Step 4: Creating message via BotMessagingService...'
puts '-'*80

# Find or create a bot sender
sender = AgentBot.find_or_create_by!(account: conversation.account, name: 'Debug Bot') do |bot|
  bot.description = 'Bot for debugging time picker'
  bot.bot_type = 'webhook'
end

begin
  bot_service = Templates::BotMessagingService.new(
    conversation: conversation,
    template: template,
    parameters: { 'available_slots' => test_slots },
    sender: sender
  )

  message = bot_service.send_template_message

  puts "✅ Message created: ID #{message.id}"
  puts "Content type: #{message.content_type}"
  puts "Message type: #{message.message_type}"
  puts "Status: #{message.status}"
  puts

  puts 'Message content_attributes:'
  puts JSON.pretty_generate(message.content_attributes)
  puts

  # Check timeslots in database
  db_timeslots = message.content_attributes.dig('event', 'timeslots')
  if db_timeslots.nil? || db_timeslots.empty?
    puts '❌ ERROR: No timeslots in database!'
    puts 'This means the issue is in how content_attributes are saved'
  else
    puts "✅ Timeslots in database: #{db_timeslots.length} slots"
    puts 'First timeslot in DB:'
    puts JSON.pretty_generate(db_timeslots.first)
  end

rescue StandardError => e
  puts "❌ BotMessagingService failed: #{e.message}"
  puts e.backtrace.join("\n")
  exit 1
end

puts

# Step 5: Test SendTimePickerService manually
puts 'Step 5: Testing SendTimePickerService...'
puts '-'*80

begin
  channel = conversation.inbox.channel
  destination_id = conversation.contact.additional_attributes['apple_messages_source_id']&.sub(/^urn:biz:/, '')

  if destination_id.nil?
    puts '❌ No destination_id found for contact'
    puts "Contact additional_attributes: #{conversation.contact.additional_attributes.inspect}"
  else
    puts "Destination ID: #{destination_id}"

    time_picker_service = AppleMessagesForBusiness::SendTimePickerService.new(
      channel: channel,
      destination_id: destination_id,
      message: message
    )

    # Build the interactive data to see what would be sent
    interactive_data = time_picker_service.build_interactive_data

    puts 'Interactive data structure:'
    puts JSON.pretty_generate(interactive_data)
    puts

    event_data = interactive_data.dig(:data, :event)
    if event_data && event_data['timeslots']
      puts "✅ Event data has timeslots: #{event_data['timeslots'].length} slots"
      puts 'First timeslot after transformation:'
      puts JSON.pretty_generate(event_data['timeslots'].first)
    else
      puts '❌ ERROR: No timeslots in interactive data!'
      puts "Event data: #{event_data.inspect}"
    end

    # Try to send (this will actually deliver the message)
    puts
    puts 'Would you like to attempt sending this message to Apple MSP? (y/n): '
    response = STDIN.gets.chomp.downcase

    if response == 'y'
      puts 'Attempting to send...'
      result = time_picker_service.perform

      if result[:success]
        puts '✅ Message sent successfully!'
        puts "Message ID: #{result[:message_id]}"
      else
        puts "❌ Send failed: #{result[:error]}"
      end
    else
      puts 'Skipped sending'
    end
  end

rescue StandardError => e
  puts "❌ SendTimePickerService failed: #{e.message}"
  puts e.backtrace.join("\n")
end

puts
puts '='*80
puts 'Debug script complete'
puts '='*80
