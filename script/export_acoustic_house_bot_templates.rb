#!/usr/bin/env ruby
# frozen_string_literal: true

# Acoustic House Bot Template Export Script
#
# Exports all templates required by AcousticHouseBotService for deployment
# to remote server. Uses auto-detected template IDs from REQUIRED_TEMPLATES constant.
#
# Usage:
#   rails runner script/export_acoustic_house_bot_templates.rb [ACCOUNT_ID] [OUTPUT_FILE]
#   rails runner script/export_acoustic_house_bot_templates.rb 1 /tmp/bot_templates.json
#
# Output includes:
#   - MessageTemplate records
#   - ContentBlock records (if using content blocks storage)
#   - SharedAppleImage records (referenced by templates)
#   - AppleListPickerImage records (inbox-specific overrides)
#
# Exit codes:
#   0 - Export successful
#   1 - Export failed (missing templates or other error)

require 'json'
require 'base64'

class AcousticHouseBotTemplateExporter
  def initialize(account_id, output_file)
    @account_id = account_id
    @output_file = output_file
    @export_data = {
      metadata: {},
      templates: [],
      content_blocks: [],
      shared_images: [],
      picker_images: []
    }
  end

  def export
    puts '📦 Acoustic House Bot Template Export'
    puts '=' * 70
    puts ''

    # Step 1: Verify all templates exist
    verification = verify_templates
    unless verification[:all_present]
      puts '❌ Export failed - missing required templates:'
      verification[:missing].each { |name| puts "   - #{name}" }
      exit 1
    end

    puts "✅ All #{verification[:found].size} required templates found"
    puts ''

    # Step 2: Export templates
    export_templates(verification[:found])

    # Step 3: Export content blocks
    export_content_blocks

    # Step 4: Export shared images
    export_shared_images

    # Step 5: Export picker images
    export_picker_images

    # Step 6: Add metadata
    add_metadata

    # Step 7: Write to file
    write_export_file

    puts ''
    puts "✅ Export complete: #{@output_file}"
    puts "   Templates: #{@export_data[:templates].size}"
    puts "   Content Blocks: #{@export_data[:content_blocks].size}"
    puts "   Shared Images: #{@export_data[:shared_images].size}"
    puts "   Picker Images: #{@export_data[:picker_images].size}"

    exit 0
  rescue StandardError => e
    puts "💥 Export error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    exit 1
  end

  private

  def verify_templates
    AppleMessagesForBusiness::AcousticHouseBotService.verify_templates_exist(@account_id)
  end

  def export_templates(found_templates)
    puts '📋 Exporting templates...'

    template_ids = found_templates.map(&:first)
    templates = ::MessageTemplate.where(id: template_ids)

    templates.each do |template|
      template_data = template.attributes.except('created_at', 'updated_at')

      # Export attachments if present (e.g., AR .usdz files)
      # Note: attachments is ActiveStorage, not a regular association
      template_data['attachments'] = export_attachments(template) if template.attachments.attached?

      @export_data[:templates] << template_data
      puts "   ✓ #{template.name}"
    end
  end

  def export_content_blocks
    puts '📦 Exporting content blocks...'

    template_ids = @export_data[:templates].map { |t| t['id'] }
    content_blocks = ::TemplateContentBlock.where(message_template_id: template_ids)

    if content_blocks.any?
      content_blocks.each do |block|
        @export_data[:content_blocks] << block.attributes.except('created_at', 'updated_at')
      end
      puts "   ✓ #{content_blocks.size} content blocks"
    else
      puts '   ℹ️  No content blocks (templates using metadata storage)'
    end
  end

  def export_shared_images
    puts '🖼️  Exporting shared images...'

    # Collect all image identifiers from templates
    identifiers = collect_image_identifiers

    if identifiers.any?
      images = ::SharedAppleImage.where(
        account_id: @account_id,
        identifier: identifiers
      )

      images.each do |image|
        image_data = image.attributes.except('created_at', 'updated_at')

        # Export image file as base64
        if image.image.attached?
          image_data['image_base64'] = encode_active_storage_attachment(image.image)
          image_data['image_filename'] = image.image.filename.to_s
          image_data['image_content_type'] = image.image.content_type
        end

        @export_data[:shared_images] << image_data
        puts "   ✓ #{image.identifier}"
      end
    else
      puts '   ℹ️  No shared images referenced'
    end
  end

  def export_picker_images
    puts '📸 Exporting picker images...'

    # Get all inbox IDs for this account
    inbox_ids = ::Inbox.where(account_id: @account_id).pluck(:id)

    if inbox_ids.any?
      images = ::AppleListPickerImage.where(inbox_id: inbox_ids)

      images.each do |image|
        image_data = image.attributes.except('created_at', 'updated_at')

        # Export image file as base64
        if image.image.attached?
          image_data['image_base64'] = encode_active_storage_attachment(image.image)
          image_data['image_filename'] = image.image.filename.to_s
          image_data['image_content_type'] = image.image.content_type
        end

        @export_data[:picker_images] << image_data
        puts "   ✓ #{image.identifier} (inbox #{image.inbox_id})"
      end
    else
      puts '   ℹ️  No inbox-specific picker images'
    end
  end

  def collect_image_identifiers
    identifiers = Set.new

    # Scan templates for image identifiers
    @export_data[:templates].each do |template|
      metadata = template['metadata'] || {}
      content_attributes = template['content_attributes'] || {}

      # Check metadata storage
      metadata.each_value do |block_data|
        next unless block_data.is_a?(Hash)

        identifiers.merge(extract_identifiers_from_hash(block_data))
      end

      # Check content_attributes
      identifiers.merge(extract_identifiers_from_hash(content_attributes))
    end

    # Scan content blocks
    @export_data[:content_blocks].each do |block|
      properties = block['properties'] || {}
      identifiers.merge(extract_identifiers_from_hash(properties))
    end

    identifiers.to_a
  end

  def extract_identifiers_from_hash(hash)
    identifiers = Set.new

    # Recursively search for *_image_identifier keys
    hash.each do |key, value|
      if key.to_s.end_with?('_image_identifier') && value.present?
        identifiers << value
      elsif value.is_a?(Hash)
        identifiers.merge(extract_identifiers_from_hash(value))
      elsif value.is_a?(Array)
        value.each do |item|
          identifiers.merge(extract_identifiers_from_hash(item)) if item.is_a?(Hash)
        end
      end
    end

    identifiers
  end

  def export_attachments(template)
    # ActiveStorage attachments are different from Message::Attachment
    # They ARE the attachment, not a wrapper around it
    template.attachments.map do |attachment|
      {
        filename: attachment.filename.to_s,
        content_type: attachment.content_type,
        byte_size: attachment.byte_size,
        file_base64: encode_active_storage_attachment(attachment)
      }
    end
  end

  def encode_active_storage_attachment(attachment)
    Base64.strict_encode64(attachment.download)
  rescue StandardError => e
    puts "   ⚠️  Failed to encode attachment: #{e.message}"
    nil
  end

  def add_metadata
    @export_data[:metadata] = {
      account_id: @account_id,
      exported_at: Time.current.iso8601,
      exported_by: 'AcousticHouseBotTemplateExporter',
      template_names: AppleMessagesForBusiness::AcousticHouseBotService.required_template_names,
      version: '1.0'
    }
  end

  def write_export_file
    File.write(@output_file, JSON.pretty_generate(@export_data))
  end
end

# Parse arguments
account_id = ARGV[0]&.to_i || 1
output_file = ARGV[1] || Rails.root.join('tmp/acoustic_house_bot_templates.json').to_s

puts "Account ID: #{account_id}"
puts "Output file: #{output_file}"
puts ''

# Run export
exporter = AcousticHouseBotTemplateExporter.new(account_id, output_file)
exporter.export
