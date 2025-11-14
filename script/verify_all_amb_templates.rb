#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive AMB Template Image Verification
# Verifies ALL list_picker, time_picker, and form templates across all AMB inboxes

puts "\n" + ('=' * 80)
puts '🔍 Comprehensive AMB Template Image Verification'
puts ('=' * 80) + "\n"

# Get all AMB inboxes
amb_inboxes = Inbox.where(channel_type: 'Channel::AppleMessagesForBusiness')

puts "📊 Found #{amb_inboxes.count} AMB inbox(es)"
puts ''

# Get all templates with AMB content blocks
# AMB type is determined by block_type in content_blocks, not template.category
amb_templates = MessageTemplate.includes(:content_blocks).where.not(account_id: nil).select do |template|
  template.content_blocks.any? { |block| %w[list_picker time_picker form].include?(block.block_type) }
end

# Group by block type for statistics
list_pickers = amb_templates.select { |t| t.content_blocks.any? { |b| b.block_type == 'list_picker' } }
time_pickers = amb_templates.select { |t| t.content_blocks.any? { |b| b.block_type == 'time_picker' } }
forms = amb_templates.select { |t| t.content_blocks.any? { |b| b.block_type == 'form' } }

puts "📋 Found #{amb_templates.count} AMB templates:"
puts "  - List Pickers: #{list_pickers.count}"
puts "  - Time Pickers: #{time_pickers.count}"
puts "  - Forms: #{forms.count}"
puts "\n" + ('=' * 80) + "\n"

# Track all image identifiers needed across all templates
all_identifiers_global = Set.new
template_identifiers = {}
template_issues = {}

# Analyze each template
amb_templates.each do |template|
  puts "Template: #{template.name} (ID: #{template.id})"

  # Determine template type from content blocks
  block_types = template.content_blocks.map(&:block_type).uniq
  puts "  Block types: #{block_types.join(', ')}"

  content_blocks = template.content_blocks || []

  if content_blocks.empty?
    puts '  ⚠️  No content blocks'
    puts ''
    next
  end

  identifiers = Set.new

  content_blocks.each do |block|
    props = block.properties

    case block.block_type
    when 'list_picker'
      # Check sections for image_identifier
      sections = props['sections']
      # Handle both array and non-array sections
      if sections.is_a?(Array)
        sections.each do |section|
          items = section['items']
          next unless items.is_a?(Array)

          items.each do |item|
            # Handle both camelCase and snake_case
            image_id = item['imageIdentifier'] || item['image_identifier']
            identifiers << image_id if image_id.present?
          end
        end
      end

    when 'time_picker'
      # Check received_message and reply_message
      if props['received_message'].is_a?(Hash)
        image_id = props['received_message']['image_identifier']
        identifiers << image_id if image_id.present?
      end

      if props['reply_message'].is_a?(Hash)
        image_id = props['reply_message']['image_identifier']
        identifiers << image_id if image_id.present?
      end

    when 'form'
      # Check received_message
      if props['received_message'].is_a?(Hash)
        image_id = props['received_message']['image_identifier']
        identifiers << image_id if image_id.present?
      end

      # Check reply_message
      if props['reply_message'].is_a?(Hash)
        image_id = props['reply_message']['image_identifier']
        identifiers << image_id if image_id.present?
      end

      # Check form items with options
      pages = props['pages']
      if pages.is_a?(Array)
        pages.each do |page|
          items = page['items']
          next unless items.is_a?(Array)

          items.each do |item|
            next unless %w[singleSelect multiSelect].include?(item['item_type'])

            options = item['options']
            next unless options.is_a?(Array)

            options.each do |option|
              image_id = option['imageIdentifier'] || option['image_identifier']
              identifiers << image_id if image_id.present?
            end
          end
        end
      end
    end
  end

  if identifiers.empty?
    puts '  ℹ️  No images used'
  else
    puts "  📷 Images needed: #{identifiers.count}"
    identifiers.each { |id| puts "     - #{id}" }

    template_identifiers[template.id] = identifiers.to_a
    all_identifiers_global.merge(identifiers)
  end

  puts ''
end

puts('=' * 80)
puts '📊 Global Summary'
puts('=' * 80)
puts "  Total unique images across all templates: #{all_identifiers_global.count}"
puts ''

if all_identifiers_global.empty?
  puts '  No images used in any templates'
  exit 0
end

puts 'Global Image Identifiers:'
all_identifiers_global.sort.each { |id| puts "  • #{id}" }
puts ''

# Check image availability across all inboxes
puts('=' * 80)
puts '🔍 Image Availability Across AMB Inboxes'
puts('=' * 80)
puts ''

missing_by_inbox = {}
available_by_inbox = {}
all_available = []

amb_inboxes.each do |inbox|
  puts "Inbox: #{inbox.name} (ID: #{inbox.id})"

  # Check which identifiers are available in this inbox
  available = AppleListPickerImage.where(
    inbox_id: inbox.id,
    identifier: all_identifiers_global.to_a
  ).pluck(:identifier)

  missing = all_identifiers_global.to_a - available

  available_by_inbox[inbox.id] = available

  if missing.empty?
    puts "  ✅ All #{all_identifiers_global.count} images available"
    all_available << inbox.id
  else
    puts "  ⚠️  Missing #{missing.count}/#{all_identifiers_global.count} images:"
    missing.each { |id| puts "     - #{id}" }
    missing_by_inbox[inbox.id] = missing
  end

  puts "  Available: #{available.count} images"
  puts ''
end

# Find source inbox (inbox with most images)
source_inbox_id = available_by_inbox.max_by { |_id, images| images.count }&.first

# Per-template analysis
puts('=' * 80)
puts '📋 Per-Template Image Availability'
puts('=' * 80)
puts ''

template_identifiers.each do |template_id, identifiers|
  template = amb_templates.find { |t| t.id == template_id }
  block_types = template.content_blocks.map(&:block_type).uniq

  puts "Template: #{template.name} (ID: #{template_id})"
  puts "  Block types: #{block_types.join(', ')}"
  puts "  Images needed: #{identifiers.count}"

  # Check each inbox for this template's images
  amb_inboxes.each do |inbox|
    available = available_by_inbox[inbox.id] & identifiers
    missing = identifiers - available

    if missing.empty?
      puts "  ✅ #{inbox.name} (#{inbox.id}): All #{identifiers.count} images available"
    else
      puts "  ⚠️  #{inbox.name} (#{inbox.id}): Missing #{missing.count}/#{identifiers.count} images"
      template_issues[template_id] ||= {}
      template_issues[template_id][inbox.id] = missing
    end
  end

  puts ''
end

# Summary and recommendations
puts('=' * 80)
puts '📊 Verification Summary & Recommendations'
puts('=' * 80)
puts ''

if missing_by_inbox.empty?
  puts '✅ ALL INBOXES HAVE ALL REQUIRED IMAGES!'
  puts ''
  puts 'All AMB templates are ready to use across all inboxes.'
  puts ''
else
  puts '⚠️  SOME INBOXES ARE MISSING IMAGES'
  puts ''

  if source_inbox_id
    source_inbox = amb_inboxes.find { |i| i.id == source_inbox_id }
    puts "📍 Source inbox (has most images): #{source_inbox.name} (ID: #{source_inbox_id})"
    puts "   Has #{available_by_inbox[source_inbox_id].count}/#{all_identifiers_global.count} images"
    puts ''

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

# Template-specific issues
if template_issues.any?
  puts('=' * 80)
  puts '⚠️  Templates with Image Issues'
  puts('=' * 80)
  puts ''

  template_issues.each do |template_id, inbox_issues|
    template = amb_templates.find { |t| t.id == template_id }
    puts "Template: #{template.name} (ID: #{template_id})"

    inbox_issues.each do |inbox_id, missing|
      inbox = amb_inboxes.find { |i| i.id == inbox_id }
      puts "  ⚠️  #{inbox.name} (#{inbox_id}) missing: #{missing.join(', ')}"
    end

    puts ''
  end
end

puts('=' * 80)
puts ''
