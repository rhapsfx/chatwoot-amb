#!/usr/bin/env ruby
# frozen_string_literal: true

# Audit script to identify template images that may need migration to SharedAppleImage

puts '=' * 80
puts 'Template & Image Migration Audit'
puts '=' * 80

ACCOUNT_ID = 1

# Step 1: Identify all inbox-specific images
puts "\nStep 1: Inbox-Specific Images (AppleListPickerImage)"
puts '-' * 80
inbox_images = AppleListPickerImage.where.not(inbox_id: nil).includes(image_attachment: :blob)
puts "Total inbox-specific images: #{inbox_images.count}"

# Group by inbox
inbox_images.group_by(&:inbox_id).each do |inbox_id, images|
  puts "\nInbox #{inbox_id}: #{images.count} images"
  images.each do |img|
    puts "  - #{img.identifier} (#{img.image.attached? ? 'has attachment' : 'NO ATTACHMENT'})"
  end
end

# Step 2: Identify all shared images
puts "\n" + ('=' * 80)
puts 'Step 2: Shared Images (SharedAppleImage)'
puts '-' * 80
shared_images = SharedAppleImage.where(account_id: ACCOUNT_ID).includes(image_attachment: :blob)
puts "Total shared images: #{shared_images.count}"

shared_images.group_by(&:image_type).each do |type, images|
  puts "\nType '#{type}': #{images.count} images"
  images.each do |img|
    puts "  - #{img.identifier} (#{img.image.attached? ? 'has attachment' : 'NO ATTACHMENT'})"
  end
end

# Step 3: Find templates with image references
puts "\n" + ('=' * 80)
puts 'Step 3: Templates Using Images'
puts '-' * 80

templates = MessageTemplate.where(account_id: ACCOUNT_ID).where('? = ANY(supported_channels)', 'apple_messages_for_business')
puts "Total Apple Messages templates: #{templates.count}"

templates_with_images = []
templates.each do |template|
  image_identifiers = []

  # Check metadata
  if template.metadata.present?
    metadata_str = template.metadata.to_json
    if metadata_str.include?('image_identifier') || metadata_str.include?('imageIdentifier')
      # Extract identifiers using regex
      identifiers_from_metadata = metadata_str.scan(/"image_identifier":\s*"([^"]+)"/).flatten
      identifiers_from_metadata += metadata_str.scan(/"imageIdentifier":\s*"([^"]+)"/).flatten
      image_identifiers.concat(identifiers_from_metadata)
    end
  end

  # Check content_blocks
  template.content_blocks.each do |block|
    next unless block.properties.present?

    block_str = block.properties.to_json
    next unless block_str.include?('image_identifier') || block_str.include?('imageIdentifier')

    identifiers_from_block = block_str.scan(/"image_identifier":\s*"([^"]+)"/).flatten
    identifiers_from_block += block_str.scan(/"imageIdentifier":\s*"([^"]+)"/).flatten
    image_identifiers.concat(identifiers_from_block)
  end

  next unless image_identifiers.any?

  templates_with_images << {
    template: template,
    identifiers: image_identifiers.uniq
  }
end

puts "\nTemplates with image references: #{templates_with_images.count}"
templates_with_images.each do |data|
  template = data[:template]
  identifiers = data[:identifiers]
  puts "\n  Template ##{template.id}: #{template.name}"
  puts "  Block type: #{template.content_blocks.first&.block_type || 'metadata'}"
  puts "  Image identifiers (#{identifiers.count}):"
  identifiers.each do |id|
    puts "    - #{id}"
  end
end

# Step 4: Check which template images are missing from SharedAppleImage
puts "\n" + ('=' * 80)
puts 'Step 4: Migration Recommendations'
puts '-' * 80

shared_identifiers = shared_images.pluck(:identifier)
inbox_identifiers = inbox_images.pluck(:identifier)

templates_with_images.each do |data|
  template = data[:template]
  identifiers = data[:identifiers]

  missing_from_shared = identifiers - shared_identifiers
  available_in_inbox = identifiers & inbox_identifiers

  if missing_from_shared.any?
    puts "\n⚠️  Template ##{template.id} (#{template.name})"
    puts "  Missing from SharedAppleImage: #{missing_from_shared.count} identifiers"
    missing_from_shared.each do |id|
      if available_in_inbox.include?(id)
        puts "    ✅ #{id} (available in inbox, CAN migrate)"
      else
        puts "    ❌ #{id} (NOT in inbox, CANNOT migrate - needs upload)"
      end
    end

    if available_in_inbox.any?
      puts "\n  💡 RECOMMENDATION: Migrate #{available_in_inbox.count} images to SharedAppleImage"
      puts "     Identifiers: #{available_in_inbox.inspect}"
    end
  else
    puts "\n✅ Template ##{template.id} (#{template.name}) - All images available in SharedAppleImage"
  end
end

# Step 5: Summary
puts "\n" + ('=' * 80)
puts 'Summary'
puts '=' * 80
puts "Inbox-specific images: #{inbox_images.count}"
puts "Shared images: #{shared_images.count}"
puts "Templates with images: #{templates_with_images.count}"

needs_migration = templates_with_images.select do |data|
  identifiers = data[:identifiers]
  missing = identifiers - shared_identifiers
  available = missing & inbox_identifiers
  available.any?
end

puts "\nTemplates needing migration: #{needs_migration.count}"
if needs_migration.any?
  puts "\nNext steps:"
  puts '1. Review the recommendations above'
  puts '2. Create migration scripts for each template (similar to migrate_guitar_images_to_shared.rb)'
  puts '3. Run migrations to copy images to SharedAppleImage'
end

puts "\n" + ('=' * 80)
