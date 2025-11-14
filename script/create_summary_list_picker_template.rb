# frozen_string_literal: true

# Script to create Summary List Picker template for Acoustic House Bot Phase 4
# Usage: rails runner script/create_summary_list_picker_template.rb

puts 'Creating Summary List Picker template...'

# Find account
account = Account.find_by(name: 'Chatwoot') || Account.first
unless account
  puts '❌ No account found'
  exit 1
end

puts "✓ Found account: #{account.name} (ID: #{account.id})"

# Summary items configuration
SUMMARY_ITEMS = [
  { order: 1, title: '1. Apple Pay', identifier: '1', image: 'summary_apple_pay.png' },
  { order: 2, title: '2. Apple Wallet', identifier: '2', image: 'summary_apple_wallet.png' },
  { order: 3, title: '3. AR Experience', identifier: '3', image: 'summary_ar_experience.png' },
  { order: 4, title: '4. Authentication', identifier: '4', image: 'summary_authentication.png' },
  { order: 5, title: '5. File Sharing', identifier: '6', image: 'summary_file_sharing.png' },
  { order: 6, title: '6. iMessage Apps', identifier: '6', image: 'summary_imessage_apps.png' },
  { order: 7, title: '7. List Picker', identifier: '7', image: 'summary_list_picker.png' },
  { order: 8, title: '8. Media Sharing', identifier: '8', image: 'summary_media_sharing.png' },
  { order: 9, title: '9. QR Code Origination', identifier: '9', image: 'summary_qr_code_origination.png' },
  { order: 10, title: '10. Quick Type Keyboard', identifier: '10', image: 'summary_quick_type_keyboard.png' },
  { order: 11, title: '11. Rich Link Locator', identifier: '11', image: 'summary_rich_link_locator.png' },
  { order: 12, title: '12. Rich Website Links', identifier: '12', image: 'summary_rich_website_links.png' },
  { order: 13, title: '13. Time Picker', identifier: '13', image: 'summary_time_picker.png' }
].freeze

# Base64-encode images from file system
SOURCE_IMAGE_DIR = '/Users/rhaps/LocalGit/chatwoot/_apple/Acoustic-House-Bot-origin/acoustichouse/images'

def encode_image_from_file(filename)
  file_path = File.join(SOURCE_IMAGE_DIR, filename)

  unless File.exist?(file_path)
    puts "  ⚠️  Image not found: #{filename}"
    return nil
  end

  file_data = File.read(file_path)
  {
    base64: Base64.strict_encode64(file_data),
    size: file_data.size
  }
rescue StandardError => e
  puts "  ❌ Error encoding #{filename}: #{e.message}"
  nil
end

puts "\nEncoding summary images as array format (required by template editor)..."
images_data = []
items_data = []

SUMMARY_ITEMS.each_with_index do |item_config, index|
  identifier = index.to_s

  # Encode image
  encoded_result = encode_image_from_file(item_config[:image])
  if encoded_result
    images_data << {
      'identifier' => identifier,
      'description' => '',
      'data' => encoded_result[:base64],
      # Template editor requires these fields to display images
      'preview' => "data:image/png;base64,#{encoded_result[:base64]}",
      'originalName' => item_config[:image],
      'size' => encoded_result[:size]
    }
    puts "  ✓ Encoded image #{identifier}: #{item_config[:image]}"
  else
    puts "  ⚠️  Skipping item #{identifier} (image not found)"
    next
  end

  # Add item
  items_data << {
    'title' => item_config[:title],
    'identifier' => identifier,
    'image_identifier' => identifier,
    'order' => item_config[:order]
  }
end

puts "\n✓ Encoded #{images_data.length} images"
puts "✓ Created #{items_data.length} items"

# Build template content_attributes
content_attributes = {
  'images' => images_data,
  'sections' => [
    {
      'items' => items_data
    }
  ],
  'summary_text' => 'Select a Feature to Learn More',
  'received_title' => 'Feature Sheet',
  'received_subtitle' => 'Key features that you were exposed to.',
  'received_image_identifier' => '0',
  'reply_title' => 'Response',
  'reply_subtitle' => 'Tap this message to view your selection',
  'multiple_selection' => false
}

# Build metadata
metadata = {
  'apple_message_content' => {
    'content_type' => 'apple_list_picker',
    'content_attributes' => content_attributes
  }
}

# Create or update template
template_name = 'Summary List Picker'
template = MessageTemplate.find_or_initialize_by(
  account_id: account.id,
  name: template_name
)

template.assign_attributes(
  category: 'general',
  description: 'Apple Messages features summary with 13 items and images - Phase 4 Summary',
  supported_channels: ['apple_messages_for_business'],
  tags: %w[acoustic_house_bot list_picker summary phase_4],
  metadata: metadata
)

if template.save
  # Create or update content block
  content_block = template.content_blocks.first_or_initialize(block_type: 'list_picker', order_index: 0)
  content_block.properties = content_attributes
  content_block.save!

  puts "\n✅ Template created successfully!"
  puts "   Name: #{template.name}"
  puts "   ID: #{template.id}"
  puts "   Items: #{items_data.length}"
  puts "   Images: #{images_data.length}"
else
  puts "\n❌ Failed to save template:"
  puts template.errors.full_messages.join("\n")
  exit 1
end

puts "\n✓ Summary List Picker template is ready!"
puts "\nTo test:"
puts '  1. Start a conversation with the Acoustic House Bot'
puts '  2. Progress through the flow to reach the summary (AHK1 state)'
puts '  3. The summary list picker with all 13 items should appear'
