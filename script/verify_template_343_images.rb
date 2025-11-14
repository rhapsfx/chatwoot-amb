#!/usr/bin/env ruby
# frozen_string_literal: true

# Template 343 (Guitar Form) Image Verification Script
# Verifies that all required images are available in all AMB inboxes

puts "\n" + ('=' * 80)
puts '🎸 Template 343 (Guitar Form) - Image Verification'
puts ('=' * 80) + "\n"

# Find template 343
template = MessageTemplate.find_by(id: 343)

unless template
  puts '❌ Template 343 not found'
  exit 1
end

puts "✅ Found template: #{template.name}"
puts "   ID: #{template.id}"
puts "   Category: #{template.category}"
puts ''

# Extract image identifiers from content blocks
content_blocks = template.content_blocks || []

if content_blocks.empty?
  puts '⚠️  No content blocks found in template'
  exit 1
end

puts '📋 Content Blocks Analysis:'
puts '-' * 80

all_identifiers = Set.new

content_blocks.each_with_index do |block, idx|
  block_type = block['block_type'] || block['blockType']
  block_config = block['block_config'] || block['blockConfig'] || {}

  puts "\nBlock #{idx + 1}: #{block_type}"

  # Extract images from form configuration
  next unless block_type == 'form'

  # Check for header image
  received_msg = block_config['received_message'] || block_config['receivedMessage'] || {}
  header_image = received_msg['image_identifier'] || received_msg['imageIdentifier']

  if header_image.present?
    puts "  📷 Header image: #{header_image}"
    all_identifiers << header_image
  end

  # Check for images in form section
  form_section = block_config['form'] || {}
  form_images = form_section['images'] || []

  if form_images.any?
    puts "  📷 Form images (#{form_images.count}):"
    form_images.each do |img|
      identifier = img['identifier']
      puts "     - #{identifier}"
      all_identifiers << identifier if identifier.present?
    end
  end

  # Check for images in field options
  fields = form_section['fields'] || []
  fields.each do |field|
    field_type = field['field_type'] || field['fieldType']

    next unless %w[single_choice multiple_choice].include?(field_type)

    options = field['options'] || []
    options.each do |opt|
      image_id = opt['image_identifier'] || opt['imageIdentifier']
      if image_id.present?
        puts "  📷 Field option image: #{image_id}"
        all_identifiers << image_id
      end
    end
  end
end

puts "\n" + ('=' * 80)
puts "📊 Summary: Found #{all_identifiers.count} unique image identifiers"
puts '=' * 80
puts ''

if all_identifiers.empty?
  puts '⚠️  No image identifiers found in template'
  exit 0
end

puts 'Image Identifiers:'
all_identifiers.each do |identifier|
  puts "  • #{identifier}"
end
puts ''

# Get all AMB inboxes
account = Account.find(template.account_id)
amb_inboxes = Inbox.where(
  account_id: account.id,
  channel_type: 'Channel::AppleMessagesForBusiness'
)

puts "🔍 Checking images across #{amb_inboxes.count} AMB inbox(es):"
puts '-' * 80
puts ''

missing_by_inbox = {}
available_by_inbox = {}

amb_inboxes.each do |inbox|
  puts "Inbox: #{inbox.name} (ID: #{inbox.id})"

  # Check which identifiers are available in this inbox
  available = AppleListPickerImage.where(
    inbox_id: inbox.id,
    identifier: all_identifiers.to_a
  ).pluck(:identifier)

  missing = all_identifiers.to_a - available

  available_by_inbox[inbox.id] = available

  if missing.empty?
    puts "  ✅ All #{all_identifiers.count} images available"
  else
    puts "  ⚠️  Missing #{missing.count}/#{all_identifiers.count} images:"
    missing.each { |id| puts "     - #{id}" }
    missing_by_inbox[inbox.id] = missing
  end

  puts "  Available: #{available.count} images"
  puts ''
end

# Find source inbox (inbox with most images)
source_inbox_id = available_by_inbox.max_by { |_id, images| images.count }&.first

if source_inbox_id
  source_inbox = amb_inboxes.find { |i| i.id == source_inbox_id }
  puts "📍 Source inbox (has most images): #{source_inbox.name} (ID: #{source_inbox_id})"
  puts "   Has #{available_by_inbox[source_inbox_id].count}/#{all_identifiers.count} images"
  puts ''
end

# Summary and recommendations
puts '=' * 80
puts '📊 Verification Summary'
puts '=' * 80
puts ''

if missing_by_inbox.empty?
  puts '✅ ALL INBOXES HAVE ALL REQUIRED IMAGES!'
  puts ''
  puts 'Template 343 is ready to use across all AMB inboxes.'
else
  puts '⚠️  SOME INBOXES ARE MISSING IMAGES'
  puts ''

  missing_by_inbox.each do |inbox_id, missing_ids|
    inbox = amb_inboxes.find { |i| i.id == inbox_id }
    puts "Inbox: #{inbox.name} (ID: #{inbox_id})"
    puts "Missing: #{missing_ids.join(', ')}"
    puts ''
  end

  if source_inbox_id
    puts '💡 Recommended Actions:'
    puts ''

    missing_by_inbox.each do |target_id, missing_ids|
      next if target_id == source_inbox_id

      target_inbox = amb_inboxes.find { |i| i.id == target_id }
      available_in_source = available_by_inbox[source_inbox_id]
      can_copy = missing_ids & available_in_source

      next unless can_copy.any?

      puts "Copy from #{source_inbox.name} (#{source_inbox_id}) → #{target_inbox.name} (#{target_id}):"
      puts "  Identifiers: #{can_copy.inspect}"
      puts ''
      puts '  Rails command:'
      puts "  rails runner \"AppleListPickerImage.where(inbox_id: #{source_inbox_id}, identifier: #{can_copy.inspect}).find_each do |img|"
      puts '    new_img = img.dup'
      puts "    new_img.inbox_id = #{target_id}"
      puts '    new_img.image.attach(img.image.blob)'
      puts '    new_img.save!'
      puts "  end; puts 'Copied #{can_copy.count} images'\""
      puts ''
    end

    # Check if source inbox is also missing images
    if missing_by_inbox[source_inbox_id].present?
      puts "⚠️  Source inbox (#{source_inbox.name}) is also missing images:"
      puts "   #{missing_by_inbox[source_inbox_id].inspect}"
      puts ''
      puts '   These images need to be uploaded manually via the UI or API.'
      puts ''
    end
  else
    puts '⚠️  No source inbox found with complete images.'
    puts '   All images need to be uploaded manually.'
  end
end

puts '=' * 80
puts ''
