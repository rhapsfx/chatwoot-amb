#!/usr/bin/env ruby

# Comprehensive List Picker IDR Flow Test
# Tests the complete flow from sending list picker with images to receiving IDR response

require_relative 'config/environment'

puts '🔍 Testing List Picker IDR Flow'
puts '=' * 80

# Find the test channel
channel = Channel::AppleMessagesForBusiness.first
unless channel
  puts '❌ No Apple Messages channel found. Please create one first.'
  exit 1
end

puts "✅ Found channel: ID=#{channel.id}, MSP ID=#{channel.msp_id}"

# Create test conversation and message for list picker with images
account = channel.inbox.account
contact = account.contacts.first || account.contacts.create!(
  name: 'Test Contact',
  email: 'test@example.com'
)

conversation = channel.inbox.conversations.create!(
  account: account,
  contact: contact,
  contact_inbox: contact.contact_inboxes.find_by(inbox: channel.inbox)
)

puts "✅ Test conversation created: ID=#{conversation.id}"

# Create a list picker message with images
message_content = {
  'sections' => [
    {
      'title' => 'Choose a product',
      'multiple_selection' => false,
      'order' => 0,
      'items' => [
        {
          'identifier' => 'item-1',
          'title' => 'Product 1',
          'subtitle' => 'Description 1',
          'imageIdentifier' => 'img-1',
          'order' => 0,
          'style' => 'icon'
        },
        {
          'identifier' => 'item-2',
          'title' => 'Product 2',
          'subtitle' => 'Description 2',
          'imageIdentifier' => 'img-2',
          'order' => 1,
          'style' => 'icon'
        }
      ]
    }
  ],
  'images' => [
    {
      'identifier' => 'img-1',
      'data' => Base64.strict_encode64('fake-image-data-1' * 100),
      'description' => 'Product 1 image'
    },
    {
      'identifier' => 'img-2',
      'data' => Base64.strict_encode64('fake-image-data-2' * 100),
      'description' => 'Product 2 image'
    }
  ],
  'received_title' => 'Please select a product',
  'received_subtitle' => 'Choose one from the list'
}

message = conversation.messages.create!(
  account: account,
  inbox: channel.inbox,
  message_type: :outgoing,
  content: 'List Picker with Images',
  content_type: 'apple_list_picker',
  content_attributes: message_content,
  sender: account.users.first
)

puts "✅ List picker message created: ID=#{message.id}"

# Test the service layer
puts "\n" + ('=' * 80)
puts '📤 Testing SendListPickerService'
puts '=' * 80

service = AppleMessagesForBusiness::SendListPickerService.new(
  channel: channel,
  destination_id: 'test-destination-id',
  message: message
)

# Test build_list_picker_data (child class override)
puts "\n🔍 Testing build_list_picker_data (child class override)..."
list_picker_data = service.send(:build_list_picker_data)
puts "Sections: #{list_picker_data[:sections].length}"
puts "First section title: #{list_picker_data[:sections].first['title']}"
puts "First section items: #{list_picker_data[:sections].first['items']&.length}"

if list_picker_data[:sections].first['items']&.any?
  first_item = list_picker_data[:sections].first['items'].first
  puts "\n📋 First item details:"
  puts "  Keys: #{first_item.keys.inspect}"
  puts "  Identifier: #{first_item['identifier']}"
  puts "  Title: #{first_item['title']}"
  puts "  Has imageIdentifier: #{first_item['imageIdentifier'].present?}"
  puts "  ImageIdentifier value: #{first_item['imageIdentifier']}"

  if first_item['imageIdentifier'].present?
    puts '✅ imageIdentifier is present in transformed item'
  else
    puts '❌ imageIdentifier is MISSING in transformed item'
    puts "   Original item from content_attributes: #{message_content['sections'].first['items'].first.inspect}"
  end
end

# Test build_interactive_data (parent class method that calls child override)
puts "\n🔍 Testing build_interactive_data..."
interactive_data = service.send(:build_interactive_data)
puts "Interactive data keys: #{interactive_data.keys.inspect}"
puts "Has images array: #{interactive_data[:data][:images].present?}"
puts "Number of images: #{interactive_data[:data][:images]&.length}"

# Test build_apple_msp_payload
puts "\n🔍 Testing build_apple_msp_payload..."
payload = service.send(:build_apple_msp_payload, SecureRandom.uuid)
puts "Payload keys: #{payload.keys.inspect}"
puts "Payload type: #{payload[:type]}"

# Check if IDR would be requested
payload_size = payload.to_json.bytesize
puts "\n📏 Payload size: #{payload_size} bytes"

should_request = service.send(:should_request_idr?, payload)
puts "Should request IDR: #{should_request}"

if should_request
  puts '✅ IDR will be requested (payload is large or has images)'
else
  puts '⚠️  IDR will NOT be requested'
end

# Inspect the final listPicker structure
if payload[:interactiveData] && payload[:interactiveData][:data] && payload[:interactiveData][:data][:listPicker]
  puts "\n🔍 Final listPicker structure in payload:"
  list_picker = payload[:interactiveData][:data][:listPicker]

  if list_picker[:sections]&.any?
    first_section = list_picker[:sections].first
    puts "  First section keys: #{first_section.keys.inspect}"

    if first_section['items']&.any?
      first_item = first_section['items'].first
      puts "  First item keys: #{first_item.keys.inspect}"
      puts "  First item has imageIdentifier: #{first_item.key?('imageIdentifier')}"
      puts "  First item imageIdentifier value: #{first_item['imageIdentifier']}"

      if first_item['imageIdentifier'].present?
        puts '✅ imageIdentifier is present in final payload'
      else
        puts '❌ imageIdentifier is MISSING in final payload'
      end
    end
  end

  # Check images array
  if payload[:interactiveData][:data][:images]&.any?
    puts "\n  Images in payload: #{payload[:interactiveData][:data][:images].length}"
    first_image = payload[:interactiveData][:data][:images].first
    puts "  First image identifier: #{first_image[:identifier]}"
    puts "  First image has data: #{first_image[:data].present?}"
  else
    puts "\n  ❌ No images array in payload"
  end
end

# Test the incoming message service (IDR response handling)
puts "\n" + ('=' * 80)
puts '📥 Testing IncomingMessageService (IDR Response Handling)'
puts '=' * 80

# Simulate an IDR response
idr_response_params = {
  'id' => SecureRandom.uuid,
  'type' => 'interactive',
  'sourceId' => 'test-user-id',
  'interactiveDataRef' => {
    'bid' => 'com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension',
    'owner' => 'test-owner',
    'url' => 'https://cvws.icloud-content.com/test-url',
    'size' => '5000',
    'signature' => 'test-signature',
    'dataRefSig' => 'test-decryption-key'
  }
}

puts 'Simulated IDR response params:'
puts "  Has ID: #{idr_response_params['id'].present?}"
puts "  Type: #{idr_response_params['type']}"
puts "  Has interactiveDataRef: #{idr_response_params['interactiveDataRef'].present?}"
puts "  IDR URL: #{idr_response_params['interactiveDataRef']['url']}"

incoming_service = AppleMessagesForBusiness::IncomingMessageService.new(
  inbox: channel.inbox,
  params: idr_response_params,
  headers: { source_id: 'test-user-id' }
)

# Test IDR detection
is_valid = incoming_service.send(:valid_message?)
is_interactive = incoming_service.send(:interactive_message?)

puts "\nIncoming message validation:"
puts "  Is valid message: #{is_valid}"
puts "  Is interactive message: #{is_interactive}"

if is_valid && is_interactive
  puts '✅ IDR response will be processed'
else
  puts '❌ IDR response will NOT be processed'
end

# Summary
puts "\n" + ('=' * 80)
puts '📊 TEST SUMMARY'
puts '=' * 80

issues = []

# Check 1: imageIdentifier in transformed data
if list_picker_data[:sections].first['items']&.first&.key?('imageIdentifier')
  puts '✅ imageIdentifier present in build_list_picker_data output'
else
  puts '❌ imageIdentifier MISSING in build_list_picker_data output'
  issues << 'imageIdentifier not being transformed correctly in child class override'
end

# Check 2: imageIdentifier in final payload
if payload[:interactiveData][:data][:listPicker][:sections].first['items'].first.key?('imageIdentifier')
  puts '✅ imageIdentifier present in final Apple MSP payload'
else
  puts '❌ imageIdentifier MISSING in final Apple MSP payload'
  issues << 'imageIdentifier being lost between child class and final payload'
end

# Check 3: Images array
if payload[:interactiveData][:data][:images]&.any?
  puts '✅ Images array present in payload'
else
  puts '❌ Images array MISSING in payload'
  issues << 'Images not being included in payload'
end

# Check 4: IDR request
if should_request
  puts '✅ IDR will be requested for this payload'
else
  puts '⚠️  IDR will NOT be requested (may be OK if payload is small)'
end

# Check 5: IDR response handling
if is_valid && is_interactive
  puts '✅ IDR responses will be detected and processed'
else
  puts '❌ IDR responses may not be processed correctly'
  issues << 'IDR response detection not working'
end

if issues.empty?
  puts "\n🎉 All checks passed! List Picker IDR flow looks good."
else
  puts "\n⚠️  Issues found:"
  issues.each_with_index do |issue, index|
    puts "  #{index + 1}. #{issue}"
  end
end

puts "\n" + ('=' * 80)
puts 'Done! You can now test sending an actual list picker with images through the UI.'
puts "Monitor the logs for '[AMB Send]' and '[AMB IncomingMessage]' entries."
puts '=' * 80
