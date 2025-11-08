#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to debug Apple Messages form sending
# Usage: rails runner script/debug_apple_form_send.rb --template-id 343 --conversation-id <ID>

require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: rails runner script/debug_apple_form_send.rb [options]'

  opts.on('--template-id ID', Integer, 'Template ID') do |id|
    options[:template_id] = id
  end

  opts.on('--conversation-id ID', Integer, 'Conversation ID (to test sending)') do |id|
    options[:conversation_id] = id
  end

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end
end.parse!

unless options[:template_id]
  puts 'Error: --template-id is required'
  exit 1
end

template = MessageTemplate.find(options[:template_id])

puts '=' * 80
puts "📋 Template Analysis: #{template.name} (ID: #{template.id})"
puts '=' * 80

# Check basic template info
puts "\n1️⃣  BASIC INFO:"
puts "   Channels: #{template.supported_channels.join(', ')}"
puts "   Use Cases: #{template.use_cases.join(', ')}"
puts "   Category: #{template.category}"
puts "   Tags: #{template.tags.join(', ')}"

# Check metadata structure
puts "\n2️⃣  METADATA STRUCTURE:"
metadata = template.metadata
puts "   Keys: #{metadata.keys.inspect}"

if metadata['apple_message_content']
  amc = metadata['apple_message_content']
  puts '   ✅ apple_message_content present'
  puts "      content_type: #{amc['content_type']}"

  if amc['content_attributes']
    ca = amc['content_attributes']
    puts '      ✅ content_attributes present'
    puts "         Keys: #{ca.keys.inspect}"

    if ca['pages']
      puts "         ✅ pages present (#{ca['pages'].length} pages)"
      ca['pages'].each_with_index do |page, idx|
        puts "            Page #{idx + 1}: #{page['page_id'] || 'NO ID'}"
        puts "               Items: #{page['items']&.length || 0}"
        page['items']&.each do |item|
          puts "               - #{item['item_id']}: #{item['item_type']}"
        end
      end
    else
      puts '         ❌ NO PAGES FOUND'
    end

    if ca['received_message']
      rm = ca['received_message']
      puts '         ✅ received_message:'
      puts "            title: #{rm['title']}"
      puts "            image_identifier: #{rm['image_identifier']}"
    else
      puts '         ⚠️  No received_message'
    end
  else
    puts '      ❌ NO content_attributes'
  end
else
  puts '   ❌ NO apple_message_content'
end

# Check content blocks
puts "\n3️⃣  CONTENT BLOCKS:"
blocks = template.content_blocks
if blocks.any?
  puts "   Found #{blocks.count} block(s)"
  blocks.each do |block|
    puts "   - Type: #{block.block_type}"
    puts "     Properties keys: #{block.properties.keys.inspect}"
  end
else
  puts '   ⚠️  No content blocks'
end

# Test rendering if conversation provided
if options[:conversation_id]
  puts "\n4️⃣  TESTING SEND:"

  conversation = Conversation.find(options[:conversation_id])
  puts "   Conversation: #{conversation.id}"
  puts "   Inbox: #{conversation.inbox.name} (#{conversation.inbox.channel_type})"

  unless conversation.inbox.channel_type == 'Channel::AppleMessagesForBusiness'
    puts '   ❌ ERROR: Inbox is not Apple Messages for Business'
    exit 1
  end

  begin
    # Try to render the message
    content_block = blocks.first
    if content_block
      rendered = content_block.render_for_channel('apple_messages_for_business', {})
      puts '   ✅ Rendered successfully'
      puts "      Type: #{rendered[:type]}"
      puts "      Properties keys: #{rendered[:properties]&.keys&.inspect}"

      # Check if we can build the actual MSP payload
      puts "\n   🔍 Checking SendMessageService structure:"
      content_attrs = rendered[:properties]

      if content_attrs['pages']
        puts "      ✅ Pages found: #{content_attrs['pages'].length}"
        content_attrs['pages'].each_with_index do |page, idx|
          puts "         Page #{idx + 1}:"
          puts "            page_id: #{page['page_id']}"
          puts "            items: #{page['items']&.length || 0}"
        end
      else
        puts '      ❌ NO PAGES in rendered output'
      end

      # Try to actually send
      puts "\n   📤 Attempting to send message..."

      message = conversation.messages.create!(
        account: conversation.account,
        inbox: conversation.inbox,
        sender: conversation.inbox.members.first,
        message_type: :outgoing,
        content_type: :input_select,
        content_attributes: content_attrs
      )

      puts "      ✅ Message created: #{message.id}"
      puts "      Content type: #{message.content_type}"
      puts "      Content attributes keys: #{message.content_attributes.keys.inspect}"

    else
      puts '   ❌ No content block to render'
    end

  rescue StandardError => e
    puts "   ❌ ERROR: #{e.message}"
    puts "      #{e.backtrace.first(3).join("\n      ")}"
  end
end

puts "\n" + ('=' * 80)
puts '💡 RECOMMENDATIONS:'

if metadata.dig('apple_message_content', 'content_attributes', 'pages').nil?
  puts "   ⚠️  Template is missing 'pages' in content_attributes"
  puts "      Run: rails runner script/fix_guitar_form_content_block.rb --template-id #{template.id}"
end

if blocks.empty?
  puts '   ⚠️  Template has no content blocks'
  puts "      Run: rails runner script/fix_guitar_form_content_block.rb --template-id #{template.id}"
end

puts "   ⚠️  content_type should be 'apple_form'" if metadata['apple_message_content']['content_type'] != 'apple_form'

puts '=' * 80
