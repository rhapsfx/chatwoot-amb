#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to create a CORRECTED Guitar Information Collection Form in Chatwoot
# This version uses the correct structure expected by SendMessageService
# Usage: rails runner script/create_guitar_info_form_corrected.rb --account-id 1 --inbox-id 6
#
# FIXES APPLIED (learned through debugging):
#
# 1. CONTENT FIELD (BotRendererService requirement)
#    - Added 'content' field to apple_message_content (line 221)
#    - BotRendererService.render_from_metadata (line 92) requires this field
#    - Without it: "Message has no content or attachments" error
#
# 2. CONTENT TYPE DETECTION (BotRendererService requirement)
#    - Structure uses pages at root level (not wrapped in 'form' key)
#    - BotRendererService.detect_content_type_from_attributes (line 220) detects this
#    - Returns 'apple_form' content_type → triggers send_interactive_message
#
# 3. VALIDATION COMPLIANCE (ContentAttributeValidator requirement)
#    - Added 'title' and 'description' at root level of content_attributes (lines 114-115)
#    - Added 'show_summary' to ALLOWED_APPLE_FORM_KEYS (line 31)
#    - Fields inside received_message/reply_message (NOT at root)
#    - Structure matches ALLOWED_APPLE_FORM_KEYS validation
#
# 4. ITEM TYPE SUPPORT (SendMessageService requirement)
#    - Uses 'picker' item_type with 'picker_type: date' (line 196-197)
#    - SendMessageService.build_msp_page_from_item now supports 'picker' (line 501)
#    - Converts to Apple MSP datePicker format
#
# 5. PAGES STRUCTURE (SendMessageService conversion requirement)
#    - Each page has 'items' array with proper item_type
#    - convert_form_builder_pages_to_msp (line 393) iterates through items
#    - Each item becomes a separate MSP page
#    - Supported types: text, textArea, email, phone, singleSelect, multiSelect, dateTime, picker, toggle, stepper

require 'optparse'
require 'base64'

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: rails runner script/create_guitar_info_form_corrected.rb [options]'

  opts.on('--account-id ID', Integer, 'Account ID (required)') do |id|
    options[:account_id] = id
  end

  opts.on('--inbox-id ID', Integer, 'Inbox ID (required - must be Apple Messages inbox)') do |id|
    options[:inbox_id] = id
  end

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end
end.parse!

unless options[:account_id] && options[:inbox_id]
  puts 'Error: Both --account-id and --inbox-id are required'
  exit 1
end

account = Account.find(options[:account_id])
inbox = account.inboxes.find(options[:inbox_id])

unless inbox.channel_type == 'Channel::AppleMessagesForBusiness'
  puts "Error: Inbox #{inbox.id} is not an Apple Messages inbox (type: #{inbox.channel_type})"
  exit 1
end

puts "Creating Guitar Information Form template for account: #{account.name} (ID: #{account.id})"
puts "Using inbox: #{inbox.name} (ID: #{inbox.id})"

# Image directory
image_dir = Rails.root.join('tmp/guitar_form_images')

unless Dir.exist?(image_dir)
  puts "Error: Image directory not found: #{image_dir}"
  puts 'Please run: ./script/setup_guitar_form_images.sh'
  exit 1
end

# Image mapping
image_files = {
  'gibson' => 'gibson_les_paul.png',
  'martin' => 'martin_dreadnought.png',
  'prs' => 'paul_reed_smith.png',
  'header' => 'guitar_collection_header.png'
}

puts "\nStep 1: Uploading images to Chatwoot..."
uploaded_images = {}

image_files.each do |identifier, filename|
  file_path = image_dir.join(filename)

  unless File.exist?(file_path)
    puts "  ⚠️  Warning: Image file not found: #{filename} - skipping"
    next
  end

  # Check if image already exists
  existing_image = AppleListPickerImage.find_by(inbox: inbox, identifier: "guitar_form_#{identifier}")
  if existing_image
    uploaded_images[identifier] = {
      id: existing_image.id,
      filename: filename
    }
    puts "  ♻️  Found existing #{filename} → ID: #{existing_image.id}"
    next
  end

  # Create AppleListPickerImage record
  image = AppleListPickerImage.new(
    account: account,
    inbox: inbox,
    identifier: "guitar_form_#{identifier}",
    original_name: filename
  )

  image.image.attach(
    io: File.open(file_path),
    filename: filename,
    content_type: 'image/png'
  )

  if image.save
    uploaded_images[identifier] = {
      id: image.id,
      filename: filename
    }
    puts "  ✅ Uploaded #{filename} → ID: #{image.id}"
  else
    puts "  ❌ Failed to upload #{filename}: #{image.errors.full_messages.join(', ')}"
  end
end

puts "\nStep 2: Creating message template with CORRECT structure..."

# Build content_attributes following SendMessageService's expected format
# IMPORTANT: Root-level structure must match ALLOWED_APPLE_FORM_KEYS validation
content_attributes = {
  'title' => 'Guitar Information Form',                    # Required at root level
  'description' => 'Please fill out your guitar details',   # Required at root level
  'show_summary' => true,                                   # Show summary before submission
  'received_message' => {
    'title' => 'Guitar Information',
    'subtitle' => 'Tap to provide your guitar details',
    'style' => 'small',
    'image_identifier' => uploaded_images['header']&.[](:id)&.to_s
  },
  'reply_message' => {
    'title' => 'Thank You!',
    'subtitle' => 'Your information has been submitted',
    'style' => 'small',
    'image_identifier' => uploaded_images['header']&.[](:id)&.to_s
  },
  'pages' => [
    {
      'page_id' => 'guitar_select',
      'title' => 'Select Guitar',
      'description' => 'Choose your guitar model',
      'items' => [
        {
          'item_id' => 'guitar_model',
          'item_type' => 'singleSelect',
          'title' => 'Guitar Model',
          'description' => 'Select your guitar',
          'required' => true,
          'options' => [
            {
              'id' => 'gibson',
              'title' => 'Gibson Les Paul R8',
              'value' => 'Gibson Les Paul R8',
              'imageIdentifier' => uploaded_images['gibson']&.[](:id)&.to_s
            },
            {
              'id' => 'martin',
              'title' => 'Martin DC28E Dreadnought',
              'value' => 'Martin DC28E Dreadnought',
              'imageIdentifier' => uploaded_images['martin']&.[](:id)&.to_s
            },
            {
              'id' => 'prs',
              'title' => 'Paul Reed Smith Custom',
              'value' => 'Paul Reed Smith Custom',
              'imageIdentifier' => uploaded_images['prs']&.[](:id)&.to_s
            }
          ]
        }
      ]
    },
    {
      'page_id' => 'customer_info',
      'title' => 'Your Information',
      'description' => 'Tell us about yourself',
      'items' => [
        {
          'item_id' => 'customer_name',
          'item_type' => 'text',
          'title' => 'Full Name',
          'placeholder' => 'John Doe',
          'required' => true
        },
        {
          'item_id' => 'customer_email',
          'item_type' => 'email',
          'title' => 'Email Address',
          'placeholder' => 'john@example.com',
          'required' => true
        }
      ]
    },
    {
      'page_id' => 'guitar_details',
      'title' => 'Guitar Details',
      'description' => 'Additional information',
      'items' => [
        {
          'item_id' => 'serial_number',
          'item_type' => 'text',
          'title' => 'Serial Number',
          'placeholder' => 'SN123456',
          'required' => false
        },
        {
          'item_id' => 'purchase_date',
          'item_type' => 'picker',
          'picker_type' => 'date',
          'title' => 'Purchase Date',
          'description' => 'When did you purchase this guitar?',
          'required' => false
        }
      ]
    }
  ]
}

# Create the template
template = MessageTemplate.create!(
  account: account,
  name: 'Guitar Information Form (Corrected)',
  category: 'general',
  description: 'Collect guitar information using Apple Messages Forms - Compatible with SendMessageService',
  supported_channels: ['apple_messages_for_business'],
  use_cases: ['bot_api_only'],
  tags: %w[guitar information form corrected],
  metadata: {
    'apple_message_content' => {
      'content' => 'Guitar Information Form',              # CRITICAL: Required for BotRendererService
      'content_type' => 'apple_form',
      'content_attributes' => content_attributes
    }
  }
)

puts "  ✅ Created template: #{template.name} (ID: #{template.id})"

# Create content block for Chatwoot UI
template.content_blocks.create!(
  block_type: 'form',
  properties: content_attributes,
  order_index: 0
)

puts '  ✅ Created content block'

puts "\n✨ Success! Corrected template created with ALL fixes applied"
puts "\n📋 Template Details:"
puts "  ID: #{template.id}"
puts "  Name: #{template.name}"
puts "  Category: #{template.category}"
puts "  Tags: #{template.tags.join(', ')}"
puts "  Images: #{uploaded_images.size} uploaded"
puts "\n🏗️  Structure (SendMessageService compatible):"
puts '  ✅ content field in apple_message_content'
puts '  ✅ title & description at root level'
puts '  ✅ show_summary enabled'
puts '  ✅ received_message & reply_message properly nested'
puts '  ✅ pages array with items'
puts "\n📄 Form Pages:"
puts '  - Page 1: Guitar Model Selection (singleSelect with images)'
puts '  - Page 2: Customer Name (text) & Email (email)'
puts '  - Page 3: Serial Number (text) & Purchase Date (picker/date)'
puts "\n🔧 Fixes Applied:"
puts '  1. Content field for BotRendererService ✅'
puts '  2. Correct content_type detection ✅'
puts '  3. Validation-compliant structure ✅'
puts '  4. Picker item_type support ✅'
puts '  5. Proper pages → items conversion ✅'
puts "\n🚀 Ready to use!"
puts "   Template ID: #{template.id}"
puts '   Use in n8n Bot API or Chatwoot ReplyBox'
puts "\n💡 Converted MSP Pages (what Apple will receive):"
puts '   1. Guitar Model (select page)'
puts '   2. Full Name (input page)'
puts '   3. Email Address (input page)'
puts '   4. Serial Number (input page)'
puts '   5. Purchase Date (datePicker page)'
