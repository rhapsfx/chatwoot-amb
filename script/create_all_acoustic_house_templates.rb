#!/usr/bin/env ruby
# frozen_string_literal: true

# Master script to create ALL templates for Acoustic House Bot
# Usage: rails runner script/create_all_acoustic_house_templates.rb

puts '🎸 Acoustic House Bot - Template Creation'
puts '=' * 60
puts ''

# Find the account and inbox
account = Account.first
inbox = account.inboxes.find_by(channel_type: 'Channel::AppleMessagesForBusiness')

unless inbox
  puts '❌ Error: No Apple Messages for Business inbox found'
  exit 1
end

puts "📱 Found AMB inbox: #{inbox.name} (ID: #{inbox.id})"
puts "🏢 Account: #{account.name} (ID: #{account.id})"
puts ''

total_created = 0
total_updated = 0
total_errors = 0

# ============================================================
# PART 1: QUICK REPLY TEMPLATES (7 templates)
# ============================================================

puts '📋 Part 1: Creating Quick Reply Templates...'
puts ''

quick_reply_templates = [
  {
    name: 'Region Selection',
    request_id: 'qr_travel',
    title: 'Select Your Region',
    items: [
      { title: 'Americas', identifier: '0' },
      { title: 'EMEA', identifier: '1' },
      { title: 'APAC', identifier: '2' }
    ]
  },
  {
    name: 'Name Selection',
    request_id: 'qr_name',
    title: 'Choose Your Name',
    items: [
      { title: 'Use my name', identifier: '0' },
      { title: 'Use stage name', identifier: '1' }
    ]
  },
  {
    name: 'AR View Question',
    request_id: 'qr_view_ar',
    title: 'AR View Check',
    items: [
      { title: 'Yes', identifier: '0' },
      { title: 'No', identifier: '1' }
    ]
  },
  {
    name: 'AR Place Question',
    request_id: 'qr_place_ar',
    title: 'AR Placement Check',
    items: [
      { title: 'Yes', identifier: '0' },
      { title: 'No', identifier: '1' }
    ]
  },
  {
    name: 'Continue Question',
    request_id: 'qr_continue',
    title: 'Continue?',
    items: [
      { title: 'Yes, continue', identifier: '0' },
      { title: 'No, skip', identifier: '1' }
    ]
  },
  {
    name: 'Photo Sharing Question',
    request_id: 'qr_photo',
    title: 'Share a Photo?',
    items: [
      { title: 'Yes', identifier: '0' },
      { title: 'No', identifier: '1' }
    ]
  },
  {
    name: 'Learn More Question',
    request_id: 'qr_learn_more',
    title: 'Learn More?',
    items: [
      { title: 'Yes', identifier: '0' },
      { title: 'No', identifier: '1' }
    ]
  }
]

quick_reply_templates.each do |template_def|
  existing = MessageTemplate.find_by(
    account_id: account.id,
    name: template_def[:name]
  )

  content_attributes = {
    'summary_text' => template_def[:title],
    'items' => template_def[:items].map do |item|
      {
        'title' => item[:title],
        'identifier' => item[:identifier]
      }
    end,
    'received_title' => template_def[:title],
    'received_subtitle' => 'Tap to make your selection',
    'received_style' => 'icon',
    'reply_title' => 'Selected',
    'reply_subtitle' => 'Your choice has been recorded',
    'reply_style' => 'icon'
  }

  if existing
    # Update existing template
    existing.update!(
      metadata: {
        'apple_message_content' => {
          'content' => template_def[:name],
          'content_type' => 'apple_quick_reply',
          'content_attributes' => content_attributes
        }
      }
    )
    # Update content block if it exists
    existing.content_blocks.first&.update!(properties: content_attributes)
    puts "  ✅ Updated: #{template_def[:name]} (ID: #{existing.id})"
    total_updated += 1
  else
    # Create new template
    template = MessageTemplate.create!(
      account: account,
      name: template_def[:name],
      category: 'general',
      description: "Quick Reply template for Acoustic House Bot - #{template_def[:title]}",
      supported_channels: ['apple_messages_for_business'],
      tags: ['acoustic_house_bot', 'quick_reply', template_def[:request_id]],
      metadata: {
        'apple_message_content' => {
          'content' => template_def[:name],
          'content_type' => 'apple_quick_reply',
          'content_attributes' => content_attributes
        }
      }
    )
    # Create content block
    template.content_blocks.create!(
      block_type: 'quick_reply',
      properties: content_attributes,
      order_index: 0
    )
    puts "  ✅ Created: #{template_def[:name]} (ID: #{template.id})"
    total_created += 1
  end
rescue StandardError => e
  puts "  ❌ Error: #{template_def[:name]} - #{e.message}"
  total_errors += 1
end

puts ''
puts "Quick Replies: #{quick_reply_templates.count} templates processed"
puts ''

# ============================================================
# PART 2: SUMMARY LIST PICKER (1 template)
# ============================================================

puts '📋 Part 2: Creating Summary List Picker...'
puts ''

# Image paths from Python project
image_dir = '/Users/rhaps/LocalGit/chatwoot/_apple/Acoustic-House-Bot-origin/acoustichouse/images'

summary_items = [
  { id: '1', title: 'Apple Pay', subtitle: 'Secure payments', image: 'summary_apple_pay.png' },
  { id: '2', title: 'Apple Wallet', subtitle: 'Store passes', image: 'summary_apple_wallet.png' },
  { id: '3', title: 'AR Experience', subtitle: '3D visualization', image: 'summary_ar_experience.png' },
  { id: '4', title: 'Authentication', subtitle: 'Secure login', image: 'summary_authentication.png' },
  { id: '5', title: 'File Sharing', subtitle: 'Documents & media', image: 'summary_file_sharing.png' },
  { id: '6', title: 'iMessage Apps', subtitle: 'Custom experiences', image: 'summary_imessage_apps.png' },
  { id: '7', title: 'List Picker', subtitle: 'Interactive lists', image: 'summary_list_picker.png' },
  { id: '8', title: 'Media Sharing', subtitle: 'Photos & videos', image: 'summary_media_sharing.png' },
  { id: '9', title: 'QR Code', subtitle: 'Quick origination', image: 'summary_qr_code_origination.png' },
  { id: '10', title: 'Quick Type', subtitle: 'Keyboard suggestions', image: 'summary_quick_type_keyboard.png' },
  { id: '11', title: 'Rich Link Locator', subtitle: 'Map integration', image: 'summary_rich_link_locator.png' },
  { id: '12', title: 'Rich Links', subtitle: 'Beautiful previews', image: 'summary_rich_website_links.png' },
  { id: '13', title: 'Time Picker', subtitle: 'Schedule appointments', image: 'summary_time_picker.png' }
]

begin
  # Encode images as array format (required by template editor)
  encoded_images_array = []
  summary_items.each do |item|
    image_path = File.join(image_dir, item[:image])
    if File.exist?(image_path)
      image_data = File.binread(image_path)
      base64_data = Base64.strict_encode64(image_data)
      encoded_images_array << {
        'identifier' => item[:id],
        'description' => '',
        'data' => base64_data,
        # Template editor requires these fields to display images
        'preview' => "data:image/png;base64,#{base64_data}",
        'originalName' => item[:image],
        'size' => image_data.size
      }
      puts "  📷 Encoded: #{item[:image]}"
    else
      puts "  ⚠️  Image not found: #{image_path}"
    end
  end

  # Build content_attributes (for metadata and content_blocks)
  content_attributes = {
    'images' => encoded_images_array,
    'sections' => [
      {
        'title' => 'Apple Messages Features',
        'multiple_selection' => false,
        'items' => summary_items.map do |item|
          {
            'title' => item[:title],
            'subtitle' => item[:subtitle],
            'identifier' => item[:id],
            'image_identifier' => item[:id]
          }
        end
      }
    ],
    'received_title' => 'Feature Sheet',
    'received_subtitle' => 'Key features that you were exposed to.',
    'received_image_identifier' => '1',
    'received_style' => 'icon',
    'reply_title' => 'Response',
    'reply_subtitle' => 'Tap this message to view your selection',
    'reply_style' => 'icon'
  }

  existing = MessageTemplate.find_by(
    account_id: account.id,
    name: 'Summary List Picker'
  )

  if existing
    # Update existing template
    existing.update!(
      metadata: {
        'apple_message_content' => {
          'content' => 'Summary List Picker',
          'content_type' => 'apple_list_picker',
          'content_attributes' => content_attributes
        }
      }
    )
    # Update content block if it exists
    existing.content_blocks.first&.update!(properties: content_attributes)
    puts "  ✅ Updated: Summary List Picker (ID: #{existing.id})"
    total_updated += 1
  else
    # Create new template
    template = MessageTemplate.create!(
      account: account,
      name: 'Summary List Picker',
      category: 'general',
      description: 'Apple Messages features summary with 13 items and images',
      supported_channels: ['apple_messages_for_business'],
      tags: %w[acoustic_house_bot list_picker summary lp_summary_0319],
      metadata: {
        'apple_message_content' => {
          'content' => 'Summary List Picker',
          'content_type' => 'apple_list_picker',
          'content_attributes' => content_attributes
        }
      }
    )
    # Create content block
    template.content_blocks.create!(
      block_type: 'list_picker',
      properties: content_attributes,
      order_index: 0
    )
    puts "  ✅ Created: Summary List Picker (ID: #{template.id})"
    total_created += 1
  end
rescue StandardError => e
  puts "  ❌ Error: Summary List Picker - #{e.message}"
  total_errors += 1
end

# ============================================================
# SUMMARY
# ============================================================

puts ''
puts '=' * 60
puts '📊 FINAL SUMMARY'
puts '=' * 60
puts "✅ Created: #{total_created}"
puts "♻️  Updated: #{total_updated}"
puts "❌ Errors: #{total_errors}"
puts ''

if total_errors.zero?
  puts '🎉 SUCCESS! All templates ready for Acoustic House Bot'
  puts ''
  puts '📝 Templates you can use in ReplyBox:'
  puts '   /region-selection'
  puts '   /name-selection'
  puts '   /ar-view-question'
  puts '   /ar-place-question'
  puts '   /continue-question'
  puts '   /photo-sharing-question'
  puts '   /learn-more-question'
  puts '   /summary-list-picker'
  puts ''
  puts '🚀 Next Steps:'
  puts '   1. Test bot manually via iPhone Messages app'
  puts '   2. Follow testing guide: docs/apple-messages/PHASE_4_TESTING_GUIDE.md'
  puts '   3. Create Guitar List Picker template (see Phase 1 docs)'
  puts '   4. Create Help Me Decide form template (see Phase 1 docs)'
else
  puts '⚠️  Some templates failed. Check errors above.'
end
