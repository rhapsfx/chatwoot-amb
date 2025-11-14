#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to create the Guitar Information Collection Form with STAGE NAME field
# This version FIXES the missing stage_name field from the original Python bot
# Usage: rails runner script/create_guitar_info_form_with_stage_name.rb --account-id 1 --inbox-id 6
#
# CRITICAL FIX: Adds stage_name field at index [5] to match original Python bot behavior
#
# Field order (matching original AH.py):
#   - Index [4]: customer_name (text)
#   - Index [5]: stage_name (text, optional) ← ADDED
#   - Index [6]: customer_email (email) ← MOVED from index 5

require 'optparse'
require 'base64'

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: rails runner script/create_guitar_info_form_with_stage_name.rb [options]'

  opts.on('--account-id ID', Integer, 'Account ID (required)') do |id|
    options[:account_id] = id
  end

  opts.on('--inbox-id ID', Integer, 'Inbox ID (required - must be Apple Messages inbox)') do |id|
    options[:inbox_id] = id
  end

  opts.on('--template-id ID', Integer, 'Template ID to update (optional - will create new if not provided)') do |id|
    options[:template_id] = id
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

puts 'Creating/Updating Guitar Information Form with STAGE NAME field'
puts "Account: #{account.name} (ID: #{account.id})"
puts "Inbox: #{inbox.name} (ID: #{inbox.id})"

# Image directory
image_dir = Rails.root.join('tmp/guitar_form_images')

unless Dir.exist?(image_dir)
  puts "Error: Image directory not found: #{image_dir}"
  puts 'Please create the directory and add guitar images'
  exit 1
end

# Image mapping: identifier => filename
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

  # Check if image already exists in database
  existing_image = AppleListPickerImage.find_by(inbox: inbox, identifier: "guitar_form_#{identifier}")
  if existing_image
    uploaded_images[identifier] = {
      id: existing_image.id,
      filename: filename
    }
    puts "  ♻️  Found existing #{filename} → ID: #{existing_image.id} (identifier: guitar_form_#{identifier})"
    next
  end

  # Create AppleListPickerImage record
  image = AppleListPickerImage.new(
    account: account,
    inbox: inbox,
    identifier: "guitar_form_#{identifier}",
    original_name: filename
  )

  # Attach the image file using ActiveStorage
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
    puts "  ✅ Uploaded #{filename} → ID: #{image.id} (identifier: guitar_form_#{identifier})"
  else
    puts "  ❌ Failed to upload #{filename}: #{image.errors.full_messages.join(', ')}"
  end
end

puts "\nStep 2: Creating template with STAGE NAME field..."

# Build content_attributes with CORRECT field order
content_attributes = {
  'title' => 'Guitar Information Form',
  'description' => 'Please fill out your guitar details',
  'show_summary' => true,
  'received_message' => {
    'title' => 'Guitar Information',
    'subtitle' => 'Tap to provide your guitar details',
    'style' => 'small',
    'image_identifier' => 'guitar_form_header'
  },
  'reply_message' => {
    'title' => 'Thank You!',
    'subtitle' => 'Your information has been submitted',
    'style' => 'small',
    'image_identifier' => 'guitar_form_header'
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
              'imageIdentifier' => 'guitar_form_gibson'
            },
            {
              'id' => 'martin',
              'title' => 'Martin DC28E Dreadnought',
              'value' => 'Martin DC28E Dreadnought',
              'imageIdentifier' => 'guitar_form_martin'
            },
            {
              'id' => 'prs',
              'title' => 'Paul Reed Smith Custom',
              'value' => 'Paul Reed Smith Custom',
              'imageIdentifier' => 'guitar_form_prs'
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
          'item_id' => 'customer_name',           # Index 4
          'item_type' => 'text',
          'keyboard_type' => 'default',           # Standard text keyboard
          'title' => 'Full Name',
          'placeholder' => 'John Doe',
          'required' => true
        },
        {
          'item_id' => 'stage_name',              # Index 5 - CRITICAL: This was MISSING
          'item_type' => 'text',
          'keyboard_type' => 'default',           # Standard text keyboard
          'title' => 'Stage Name (Optional)',
          'placeholder' => 'Your artist/stage name',
          'description' => 'If you perform or have a stage name, enter it here',
          'required' => false                     # Optional field
        },
        {
          'item_id' => 'customer_email',          # Index 6 (moved from 5)
          'item_type' => 'email',
          'keyboard_type' => 'emailAddress',      # Email keyboard with @ and .com
          'title' => 'Email Address',
          'placeholder' => 'john@example.com',
          'required' => true
        },
        {
          'item_id' => 'customer_phone',          # Index 7 - Added for complete contact info
          'item_type' => 'text',
          'keyboard_type' => 'phonePad',          # Phone number keyboard
          'title' => 'Phone Number (Optional)',
          'placeholder' => '+1 (555) 123-4567',
          'description' => 'We may contact you about your guitar',
          'required' => false
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
          'keyboard_type' => 'default',           # Alphanumeric for serial numbers
          'title' => 'Serial Number',
          'placeholder' => 'SN123456',
          'description' => 'Found on the back of the headstock',
          'required' => false
        },
        {
          'item_id' => 'guitar_year',             # Added: Year of manufacture
          'item_type' => 'text',
          'keyboard_type' => 'numberPad',         # Numeric keyboard for year
          'title' => 'Year of Manufacture (Optional)',
          'placeholder' => '2020',
          'description' => 'Approximate year is fine',
          'required' => false
        },
        {
          'item_id' => 'purchase_date',
          'item_type' => 'picker',
          'picker_type' => 'date',
          'title' => 'Purchase Date',
          'description' => 'When did you purchase this guitar?',
          'required' => false
        },
        {
          'item_id' => 'purchase_price',          # Added: Purchase price
          'item_type' => 'text',
          'keyboard_type' => 'decimalPad',        # Decimal number keyboard for price
          'title' => 'Purchase Price (Optional)',
          'placeholder' => '2999.99',
          'description' => 'Amount paid in USD',
          'required' => false
        }
      ]
    }
  ]
}

# Create or update the template
if options[:template_id]
  template = MessageTemplate.find(options[:template_id])
  puts "  ♻️  Updating existing template ID: #{template.id}"

  template.update!(
    metadata: {
      'apple_message_content' => {
        'content' => 'Guitar Information Form',
        'content_type' => 'apple_form',
        'content_attributes' => content_attributes
      }
    }
  )

  # Update content block
  template.content_blocks.first&.update!(properties: content_attributes)
  puts "  ✅ Updated template: #{template.name} (ID: #{template.id})"
else
  template = MessageTemplate.create!(
    account: account,
    name: 'Guitar Information Form (with Stage Name)',
    category: 'general',
    description: 'Collect guitar information with optional stage name field - Compatible with original Python bot',
    supported_channels: ['apple_messages_for_business'],
    use_cases: ['bot_api_only'],
    tags: %w[guitar information form stage_name corrected],
    metadata: {
      'apple_message_content' => {
        'content' => 'Guitar Information Form',
        'content_type' => 'apple_form',
        'content_attributes' => content_attributes
      }
    }
  )

  puts "  ✅ Created template: #{template.name} (ID: #{template.id})"

  # Create content block
  template.content_blocks.create!(
    block_type: 'form',
    properties: content_attributes,
    order_index: 0
  )

  puts '  ✅ Created content block'
end

puts "\n✨ Success! Guitar Information Form with STAGE NAME field"
puts "\n📋 Template Details:"
puts "  ID: #{template.id}"
puts "  Name: #{template.name}"
puts "  Category: #{template.category}"
puts "  Tags: #{template.tags.join(', ')}"
puts "  Images: #{uploaded_images.size} uploaded"

puts "\n📄 Form Pages (CORRECT field order with proper keyboard types):"
puts '  - Page 1: Guitar Model Selection (singleSelect with images)'
puts '  - Page 2: Customer Information'
puts '    • customer_name (index 4) - required ✅ [default keyboard]'
puts '    • stage_name (index 5) - optional ✅ FIXED [default keyboard]'
puts '    • customer_email (index 6) - required ✅ [emailAddress keyboard]'
puts '    • customer_phone (index 7) - optional ✅ [phonePad keyboard]'
puts '  - Page 3: Guitar Details'
puts '    • serial_number - optional [default keyboard]'
puts '    • guitar_year - optional [numberPad keyboard]'
puts '    • purchase_date - optional [date picker]'
puts '    • purchase_price - optional [decimalPad keyboard]'

puts "\n🔧 Critical Fixes Applied:"
puts '  ✅ Added stage_name field at index [5]'
puts '  ✅ Moved customer_email to index [6]'
puts '  ✅ Matches original Python bot field expectations'
puts '  ✅ Added proper keyboard types per Apple Messages specs:'
puts '     - emailAddress: Email field with @ and .com'
puts '     - phonePad: Phone number keyboard'
puts '     - numberPad: Numeric keyboard for year'
puts '     - decimalPad: Decimal number keyboard for price'
puts '     - default: Standard keyboard for text fields'

puts "\n🎯 Bot Workflow (now fully functional):"
puts '  1. User fills form (name + optional stage_name + email)'
puts '  2. If stage_name provided:'
puts '     → Ask "How would you like to be addressed?"'
puts '     → Quick reply: "Use my name" or "Use stage name"'
puts '     → Store selected_name in conversation attributes'
puts '  3. Use selected_name in personalized messages'

puts "\n🚀 Ready to use with n8n bot workflow!"
puts "   Template ID: #{template.id}"
puts '   Use in n8n Bot API or Chatwoot ReplyBox'
