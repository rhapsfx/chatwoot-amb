#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to create all Quick Reply templates for Acoustic House Bot
# Usage: rails runner script/create_all_quick_reply_templates.rb

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

# Template definitions
templates = [
  {
    name: 'Region Selection',
    request_id: 'qr_travel',
    summary: 'Before we begin, where are you in the world?',
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
    summary: 'How would you like to be addressed?',
    title: 'Choose Your Name',
    items: [
      { title: 'Use my name', identifier: '0' },
      { title: 'Use stage name', identifier: '1' }
    ]
  },
  {
    name: 'AR View Question',
    request_id: 'qr_view_ar',
    summary: 'Did you see the 3D AR view?',
    title: 'AR View Check',
    items: [
      { title: 'Yes', identifier: '0' },
      { title: 'No', identifier: '1' }
    ]
  },
  {
    name: 'AR Place Question',
    request_id: 'qr_place_ar',
    summary: 'Did you place the AR guitar?',
    title: 'AR Placement Check',
    items: [
      { title: 'Yes', identifier: '0' },
      { title: 'No', identifier: '1' }
    ]
  },
  {
    name: 'Continue Question',
    request_id: 'qr_continue',
    summary: 'Shall we continue?',
    title: 'Continue?',
    items: [
      { title: 'Yes, continue', identifier: '0' },
      { title: 'No, skip', identifier: '1' }
    ]
  },
  {
    name: 'Photo Sharing Question',
    request_id: 'qr_photo',
    summary: 'Will you share a picture?',
    title: 'Share a Photo?',
    items: [
      { title: 'Yes', identifier: '0' },
      { title: 'No', identifier: '1' }
    ]
  },
  {
    name: 'Learn More Question',
    request_id: 'qr_learn_more',
    summary: 'Would you like to learn more?',
    title: 'Learn More About Apple Messages?',
    items: [
      { title: 'Yes', identifier: '0' },
      { title: 'No', identifier: '1' }
    ]
  }
]

created_count = 0
updated_count = 0
error_count = 0

templates.each do |template_def|
  # Check if template already exists
  existing = MessageTemplate.find_by(
    account_id: account.id,
    name: template_def[:name]
  )

  # Build content_attributes
  content_attributes = {
    'summary_text' => template_def[:summary],
    'items' => template_def[:items].map do |item|
      {
        'title' => item[:title],
        'identifier' => item[:identifier]
      }
    end
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
    puts "✅ Updated: #{template_def[:name]} (ID: #{existing.id})"
    updated_count += 1
  else
    # Create new template
    template = MessageTemplate.create!(
      account: account,
      name: template_def[:name],
      category: 'general',
      description: "Quick Reply template for Acoustic House Bot - #{template_def[:summary]}",
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
    puts "✅ Created: #{template_def[:name]} (ID: #{template.id})"
    created_count += 1
  end
rescue StandardError => e
  puts "❌ Error creating #{template_def[:name]}: #{e.message}"
  error_count += 1
end

puts ''
puts '📊 Summary:'
puts "   Created: #{created_count}"
puts "   Updated: #{updated_count}"
puts "   Errors: #{error_count}"
puts ''

if error_count.zero?
  puts '✅ All Quick Reply templates ready!'
  puts ''
  puts '📝 Usage in ReplyBox:'
  templates.each do |t|
    puts "   /#{t[:name].downcase.tr(' ', '-')}"
  end
else
  puts '⚠️  Some templates failed to create. Check errors above.'
end
