#!/usr/bin/env ruby

puts '🔧 Generating CORRECTED Apple Messages for Business JSON Payloads'
puts '=' * 65

# Find the test messages we created
messages = Message.where(content_type: %w[apple_quick_reply apple_list_picker apple_time_picker])
                  .order(:id)
                  .last(3)

if messages.empty?
  puts '❌ No Apple Messages found. Run test_identifier_generation.rb first.'
  exit 1
end

output_file = 'corrected_apple_messages_payloads.json'
payloads = {}

messages.each do |message|
  puts "\n📱 Processing #{message.content_type.humanize} (ID: #{message.id})"

  # Generate the CORRECT Apple MSP format
  case message.content_type
  when 'apple_quick_reply'
    # Correct Apple MSP Quick Reply format
    payload = {
      'v' => 1,
      'id' => "#{SecureRandom.uuid}",
      'sourceId' => 'business-chat-account',
      'destinationId' => 'tel:+1234567890',
      'type' => 'interactive',
      'interactiveData' => {
        'bid' => 'com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension',
        'data' => {
          'version' => '1.0',
          'requestIdentifier' => SecureRandom.uuid,
          'quick-reply' => {
            'summaryText' => message.content_attributes['summary_text'],
            'items' => message.content_attributes['items'].map do |item|
              {
                'identifier' => item['identifier'],
                'title' => item['title']
              }
            end
          }
        },
        'useLiveLayout' => true
      }
    }

  when 'apple_list_picker'
    # Correct Apple MSP List Picker format
    payload = {
      'v' => 1,
      'id' => "#{SecureRandom.uuid}",
      'sourceId' => 'business-chat-account',
      'destinationId' => 'tel:+1234567890',
      'type' => 'interactive',
      'interactiveData' => {
        'bid' => 'com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension',
        'data' => {
          'version' => '1.0',
          'requestIdentifier' => SecureRandom.uuid,
          'listPicker' => {
            'sections' => message.content_attributes['sections'].map do |section|
              {
                'title' => section['title'],
                'multipleSelection' => section['multiple_selection'] || false,
                'items' => section['items'].map do |item|
                  {
                    'identifier' => item['identifier'],
                    'title' => item['title'],
                    'subtitle' => item['subtitle']
                  }
                end
              }
            end
          }
        },
        'receivedMessage' => {
          'title' => message.content_attributes['received_title'] || message.content,
          'subtitle' => message.content_attributes['received_subtitle'] || '',
          'style' => 'icon'
        },
        'replyMessage' => {
          'title' => 'Selected',
          'subtitle' => 'Your selection',
          'style' => 'icon'
        },
        'useLiveLayout' => true
      }
    }

  when 'apple_time_picker'
    # Correct Apple MSP Time Picker format
    payload = {
      'v' => 1,
      'id' => "#{SecureRandom.uuid}",
      'sourceId' => 'business-chat-account',
      'destinationId' => 'tel:+1234567890',
      'type' => 'interactive',
      'interactiveData' => {
        'bid' => 'com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension',
        'data' => {
          'version' => '1.0',
          'requestIdentifier' => SecureRandom.uuid,
          'timePicker' => {
            'event' => {
              'title' => message.content_attributes['event']['title'],
              'description' => message.content_attributes['event']['description'],
              'timezoneOffset' => message.content_attributes['timezone_offset'] || 0,
              'timeslots' => message.content_attributes['timeslots'].map do |slot|
                {
                  'identifier' => slot['identifier'],
                  'startTime' => slot['startTime'],
                  'duration' => slot['duration'] || 60
                }
              end
            }
          }
        },
        'receivedMessage' => {
          'title' => message.content_attributes['event']['title'],
          'subtitle' => message.content_attributes['event']['description'],
          'style' => 'icon'
        },
        'replyMessage' => {
          'title' => 'Appointment Scheduled',
          'subtitle' => 'Your appointment time',
          'style' => 'icon'
        },
        'useLiveLayout' => true
      }
    }
  end

  payloads[message.content_type] = {
    message_id: message.id,
    content_type: message.content_type,
    content: message.content,
    chatwoot_format: message.content_attributes,
    correct_apple_msp_payload: payload
  }

  puts "✅ Generated CORRECTED payload for #{message.content_type}"
end

# Write to JSON file
File.write(output_file, JSON.pretty_generate(payloads))

puts "\n📄 CORRECTED JSON payloads written to: #{output_file}"
puts "\n🔍 Comparison Summary:"
puts '-' * 50

payloads.each do |type, data|
  puts "\n#{type.upcase}:"
  puts "  Message ID: #{data[:message_id]}"
  puts "  ❌ WRONG: Our original format used 'interactive_type' and 'interactive_data'"
  puts "  ✅ CORRECT: Apple MSP uses 'interactiveData.data.#{type.sub('apple_', '')}'"

  case type
  when 'apple_quick_reply'
    puts '  ✅ Structure: interactiveData.data.quick-reply.summaryText + items[]'
  when 'apple_list_picker'
    puts '  ✅ Structure: interactiveData.data.listPicker.sections[] + receivedMessage + replyMessage'
  when 'apple_time_picker'
    puts '  ✅ Structure: interactiveData.data.timePicker.event + receivedMessage + replyMessage'
  end
end

puts "\n📋 Key Differences Found:"
puts '-' * 30
puts '❌ WRONG FORMAT (what we had):'
puts "   • type: 'interactive'"
puts "   • interactive_type: 'quick_reply'"
puts '   • interactive_data: { ... }'
puts ''
puts '✅ CORRECT APPLE MSP FORMAT:'
puts '   • v: 1'
puts "   • type: 'interactive'"
puts "   • interactiveData.bid: 'com.apple.messages.MSMessageExtensionBalloonPlugin:...'"
puts "   • interactiveData.data.version: '1.0'"
puts "   • interactiveData.data.requestIdentifier: 'uuid'"
puts '   • interactiveData.data.quick-reply: { ... } (for quick reply)'
puts '   • interactiveData.data.listPicker: { ... } (for list picker)'
puts '   • interactiveData.data.timePicker: { ... } (for time picker)'
puts '   • interactiveData.receivedMessage: { ... }'
puts '   • interactiveData.replyMessage: { ... }'
puts '   • interactiveData.useLiveLayout: true'

puts "\n🚨 CRITICAL ISSUE IDENTIFIED:"
puts "   Our JSON structure does NOT match Apple's MSP specification!"
puts '   We need to update our services to generate the correct format.'

puts "\n💡 Next Steps:"
puts '   1. Update SendMessageService classes to use correct Apple MSP format'
puts '   2. Fix content_attributes structure to match Apple requirements'
puts '   3. Add receivedMessage and replyMessage dictionaries'
puts '   4. Test with corrected payloads'
