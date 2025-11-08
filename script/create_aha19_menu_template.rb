#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to create the AHA19 Main Menu template in Chatwoot
# Usage: rails runner script/create_aha19_menu_template.rb --account-id 1 --inbox-id 2

require 'optparse'
require 'base64'

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: rails runner script/create_aha19_menu_template.rb [options]'

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

puts "Creating AHA19 menu template for account: #{account.name} (ID: #{account.id})"
puts "Using inbox: #{inbox.name} (ID: #{inbox.id})"

# Image directory
image_dir = Rails.root.join('tmp/lp_menu_0319_images')

unless Dir.exist?(image_dir)
  puts "Error: Image directory not found: #{image_dir}"
  puts 'Please run the image extraction first'
  exit 1
end

# Image mapping: identifier => filename
image_files = {
  '0' => 'header_image.png',
  '1' => 'summary_apple_pay.png',
  '2' => 'summary_list_picker.png',
  '3' => 'summary_ar_experience.png',
  '4' => 'summary_apple_pay.png',
  '5' => 'summary_time_picker.png',
  '6' => 'summary_file_sharing.png',
  '7' => 'summary_media_sharing.png',
  '8' => 'summary_file_sharing.png',
  '10' => 'summary_authentication.png',
  '11' => 'summary_imessage_apps.png',
  '12' => 'summary_apple_wallet.png',
  '13' => 'summary_rich_link_locator.png'
}

puts "\nStep 1: Uploading images to Chatwoot..."
uploaded_images = {}

image_files.each do |identifier, filename|
  file_path = image_dir.join(filename)

  unless File.exist?(file_path)
    puts "  ⚠️  Warning: Image file not found: #{filename}"
    next
  end

  # Check if we already uploaded this file (for reused images in this run)
  if uploaded_images.values.any? { |img| img[:filename] == filename }
    existing = uploaded_images.find { |_k, v| v[:filename] == filename }
    uploaded_images[identifier] = existing[1]
    puts "  ♻️  Reusing #{filename} for identifier #{identifier}"
    next
  end

  # Check if image already exists in database
  existing_image = AppleListPickerImage.find_by(inbox: inbox, identifier: "aha19_#{identifier}")
  if existing_image
    uploaded_images[identifier] = {
      id: existing_image.id,
      filename: filename
    }
    puts "  ♻️  Found existing #{filename} → ID: #{existing_image.id} (identifier: aha19_#{identifier})"
    next
  end

  # Create AppleListPickerImage record
  image = AppleListPickerImage.new(
    account: account,
    inbox: inbox,
    identifier: "aha19_#{identifier}",
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
    puts "  ✅ Uploaded #{filename} → ID: #{image.id} (identifier: aha19_#{identifier})"
  else
    puts "  ❌ Failed to upload #{filename}: #{image.errors.full_messages.join(', ')}"
  end
end

puts "\nStep 2: Creating message template..."

# Build content_attributes
content_attributes = {
  'received_message' => {
    'title' => 'Apple Messages for Business: Table of Contents',
    'subtitle' => 'Please tap on your selection',
    'style' => 'small',
    'image_identifier' => uploaded_images['0'][:id].to_s
  },
  'reply_message' => {
    'title' => 'Response',
    'subtitle' => 'Tap this message to view your selection',
    'style' => 'small'
  },
  'sections' => [
    {
      'multiple_selection' => false,
      'items' => [
        {
          'title' => '1. Introduction with Intent ID',
          'identifier' => '1',
          'image_identifier' => uploaded_images['1'][:id].to_s,
          'style' => 'icon',
          'order' => 1
        },
        {
          'title' => '2. Send a List Picker',
          'identifier' => '2',
          'image_identifier' => uploaded_images['2'][:id].to_s,
          'style' => 'icon',
          'order' => 2
        },
        {
          'title' => '3. Receive an AR Image',
          'identifier' => '3',
          'image_identifier' => uploaded_images['3'][:id].to_s,
          'style' => 'icon',
          'order' => 3
        },
        {
          'title' => '4. Apple Pay',
          'identifier' => '4',
          'image_identifier' => uploaded_images['4'][:id].to_s,
          'style' => 'icon',
          'order' => 4
        },
        {
          'title' => '5. Schedule a Guitar Lesson',
          'identifier' => '5',
          'image_identifier' => uploaded_images['5'][:id].to_s,
          'style' => 'icon',
          'order' => 5
        },
        {
          'title' => '6. Fill in a Form',
          'identifier' => '6',
          'image_identifier' => uploaded_images['6'][:id].to_s,
          'style' => 'icon',
          'order' => 6
        },
        {
          'title' => '7. Send an Image',
          'identifier' => '7',
          'image_identifier' => uploaded_images['7'][:id].to_s,
          'style' => 'icon',
          'order' => 7
        },
        {
          'title' => '8. Send Documents',
          'identifier' => '8',
          'image_identifier' => uploaded_images['8'][:id].to_s,
          'style' => 'icon',
          'order' => 8
        },
        {
          'title' => '9. Authentication',
          'identifier' => '10',
          'image_identifier' => uploaded_images['10'][:id].to_s,
          'style' => 'icon',
          'order' => 10
        },
        {
          'title' => '10. iMessage App',
          'identifier' => '11',
          'image_identifier' => uploaded_images['11'][:id].to_s,
          'style' => 'icon',
          'order' => 11
        },
        {
          'title' => '11. Apple Wallet',
          'identifier' => '12',
          'image_identifier' => uploaded_images['12'][:id].to_s,
          'style' => 'icon',
          'order' => 12
        },
        {
          'title' => '12. Rich Link Locator',
          'identifier' => '13',
          'image_identifier' => uploaded_images['13'][:id].to_s,
          'style' => 'icon',
          'order' => 13
        }
      ]
    }
  ]
}

# Create the template
template = MessageTemplate.create!(
  account: account,
  name: 'AHA19 - Main Menu (Table of Contents)',
  category: 'general',
  description: 'Main menu for Acoustic House Bot - Table of Contents with 12 demo features',
  supported_channels: ['apple_messages_for_business'],
  use_cases: ['bot_api_only'],
  tags: %w[acoustic_house menu demo],
  metadata: {
    'apple_message_content' => {
      'content_type' => 'apple_list_picker',
      'content_attributes' => content_attributes
    }
  }
)

puts "  ✅ Created template: #{template.name} (ID: #{template.id})"

# Create content block for Chatwoot UI
template.content_blocks.create!(
  block_type: 'list_picker',
  properties: content_attributes,
  order_index: 0
)

puts '  ✅ Created content block for Chatwoot UI'

puts "\n✨ Success! Template created successfully"
puts "\nTemplate Details:"
puts "  ID: #{template.id}"
puts "  Name: #{template.name}"
puts "  Category: #{template.category}"
puts "  Supported Channels: #{template.supported_channels.join(', ')}"
puts "  Use Cases: #{template.use_cases.join(', ')}"
puts "  Tags: #{template.tags.join(', ')}"
puts "  Images Uploaded: #{uploaded_images.size}"
puts "\nYou can now use this template via Bot API with template ID: #{template.id}"
puts "Or search for it by name: 'AHA19'"
