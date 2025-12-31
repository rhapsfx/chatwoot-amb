#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify template 343 render API returns images

require 'json'

puts "\n" + ('=' * 80)
puts '🧪 Testing Template 343 Render API'
puts ('=' * 80) + "\n"

# Find template 343
template = MessageTemplate.find_by(id: 343)

unless template
  puts '❌ Template 343 not found'
  exit 1
end

puts "✅ Found template: #{template.name}"
puts ''

# Check if this is a bot template (metadata) or content_blocks template
if template.metadata.present? && template.metadata['apple_message_content'].present?
  puts '📦 This is a BOT template (uses metadata)'
  puts '   → Will use render_from_metadata path'
else
  puts '📦 This is a CONTENT_BLOCKS template (uses content_blocks)'
  puts '   → Will use adapter path'
end
puts ''

# Render the template
puts '🔄 Rendering template...'
puts ''

begin
  service = Templates::BotRendererService.new(
    template_id: template.id,
    parameters: {},
    channel_type: 'apple_messages_for_business'
  )

  result = service.render_for_bot

  puts '✅ Render successful!'
  puts ''

  puts('=' * 80)
  puts 'Content Attributes:'
  puts('=' * 80)
  puts JSON.pretty_generate(result[:content_attributes])
  puts ''

  # Check for images
  images = result[:content_attributes]['images'] || result[:content_attributes][:images]

  puts('=' * 80)
  puts "📊 Images Array: #{images&.length || 0} images"
  puts('=' * 80)

  if images.present?
    images.each_with_index do |img, idx|
      puts "  #{idx + 1}. #{img['identifier']}"
      puts "     data: #{img['data'] ? "#{img['data'].length} chars (base64)" : 'MISSING'}"
      puts "     description: #{img['description'] || 'none'}"
    end
  else
    puts '  ⚠️  NO IMAGES FOUND!'
  end
  puts ''

  # Check pages for imageIdentifier fields
  pages = result[:content_attributes]['pages'] || result[:content_attributes][:pages]

  if pages.present?
    puts('=' * 80)
    puts "📄 Pages: #{pages.length} pages"
    puts('=' * 80)

    pages.each_with_index do |page, page_idx|
      items = page['items'] || []
      next unless items.any?

      puts "  Page #{page_idx + 1}: #{items.length} items"

      items.each_with_index do |item, item_idx|
        next unless %w[singleSelect multiSelect].include?(item['item_type'])

        puts "    Item #{item_idx + 1}: #{item['item_type']} - #{item['title']}"

        options = item['options'] || []
        options.each_with_index do |option, opt_idx|
          image_id = option['imageIdentifier'] || option['image_identifier']
          if image_id.present?
            puts "      Option #{opt_idx + 1}: #{option['title']} → ✅ #{image_id}"
          else
            puts "      Option #{opt_idx + 1}: #{option['title']} → ❌ NO IMAGE"
          end
        end
      end
    end
    puts ''
  end

  puts('=' * 80)
  puts 'Test Result:'
  puts('=' * 80)

  if images.present? && images.all? { |img| img['data'].present? }
    puts '✅ SUCCESS: All images loaded with base64 data!'
  elsif images.present?
    puts '⚠️  PARTIAL: Images array exists but some missing data'
  else
    puts '❌ FAILURE: No images loaded'
  end
  puts ''

rescue StandardError => e
  puts "❌ Render failed: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end
