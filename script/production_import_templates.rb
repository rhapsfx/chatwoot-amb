require 'json'

# This script imports bot templates, content blocks, and shared images
# from /tmp/bot_templates.json into the production database

puts '=' * 70
puts '📦 Importing Acoustic House Bot Templates'
puts '=' * 70

template_file = '/tmp/bot_templates.json'

unless File.exist?(template_file)
  puts ''
  puts "❌ Template file not found: #{template_file}"
  puts '   This file should be created by the deployment script before running import'
  exit 1
end

data = JSON.parse(File.read(template_file))

puts ''
puts 'Export metadata:'
puts "  Account ID: #{data['metadata']['account_id']}"
puts "  Exported at: #{data['metadata']['exported_at']}"
puts "  Templates: #{data['templates'].size}"
puts "  Content Blocks: #{data['content_blocks'].size}"
puts "  Shared Images: #{data['shared_images'].size}"

# Import templates
puts ''
puts '=' * 70
puts "📋 Importing #{data['templates'].size} templates..."
puts '=' * 70

template_success = 0
template_errors = 0

data['templates'].each do |template_data|
  template = MessageTemplate.find_or_initialize_by(
    account_id: template_data['account_id'],
    name: template_data['name']
  )

  status = template.new_record? ? 'NEW' : 'UPDATE'

  # Don't copy status - let it use database default ('active')
  # This ensures imported templates are visible in UI
  template.assign_attributes(template_data.except('id', 'attachments', 'status'))

  if template.save
    puts "   ✓ #{template.name} (#{status}, ID: #{template.id})"
    template_success += 1

    # Import attachments if present (e.g., AR .usdz files)
    if template_data['attachments'].present?
      template_data['attachments'].each do |attachment_data|
        next unless attachment_data['file_base64'].present?

        # Decode base64 and attach to template
        decoded_data = Base64.strict_decode64(attachment_data['file_base64'])
        template.attachments.attach(
          io: StringIO.new(decoded_data),
          filename: attachment_data['filename'],
          content_type: attachment_data['content_type']
        )
      end
    end
  else
    puts "   ✗ #{template_data['name']} - FAILED: #{template.errors.full_messages.join(', ')}"
    template_errors += 1
  end
end

puts ''
puts "Templates: #{template_success} imported, #{template_errors} errors"

# Import content blocks if present
if data['content_blocks'].any?
  puts ''
  puts '=' * 70
  puts "📦 Importing #{data['content_blocks'].size} content blocks..."
  puts '=' * 70

  block_success = 0
  block_errors = 0

  data['content_blocks'].each do |block_data|
    # Find corresponding template by message_template_id
    source_template_id = block_data['message_template_id']
    source_template_name = data['templates'].find { |t| t['id'] == source_template_id }&.fetch('name', nil)

    unless source_template_name
      puts "   ✗ Content block - no source template for ID #{source_template_id}"
      block_errors += 1
      next
    end

    # Find template in production by name
    template = MessageTemplate.find_by(
      account_id: data['metadata']['account_id'],
      name: source_template_name
    )

    unless template
      puts "   ✗ Content block - template '#{source_template_name}' not found"
      block_errors += 1
      next
    end

    # Find or create content block using actual schema fields
    block = TemplateContentBlock.find_or_initialize_by(
      message_template_id: template.id,
      block_type: block_data['block_type'],
      order_index: block_data['order_index']
    )

    status = block.new_record? ? 'NEW' : 'UPDATE'
    block.assign_attributes(block_data.except('id', 'message_template_id'))

    if block.save
      puts "   ✓ #{template.name} / #{block.block_type} (#{status})"
      block_success += 1
    else
      puts "   ✗ #{template.name} / #{block.block_type} - FAILED: #{block.errors.full_messages.join(', ')}"
      block_errors += 1
    end
  end

  puts ''
  puts "Content blocks: #{block_success} imported, #{block_errors} errors"
end

# Import shared images
if data['shared_images'].any?
  puts ''
  puts '=' * 70
  puts "🖼️  Importing #{data['shared_images'].size} shared images..."
  puts '=' * 70

  image_success = 0
  image_errors = 0

  data['shared_images'].each do |image_data|
    image = SharedAppleImage.find_or_initialize_by(
      account_id: image_data['account_id'],
      identifier: image_data['identifier']
    )

    status = image.new_record? ? 'NEW' : 'UPDATE'
    image.assign_attributes(image_data.except('id', 'image_base64', 'image_filename', 'image_content_type'))

    # Attach image file if present
    if image_data['image_base64']
      decoded_data = Base64.strict_decode64(image_data['image_base64'])
      image.image.attach(
        io: StringIO.new(decoded_data),
        filename: image_data['image_filename'],
        content_type: image_data['image_content_type']
      )
    end

    if image.save
      puts "   ✓ #{image.identifier} (#{status})"
      image_success += 1
    else
      puts "   ✗ #{image.identifier} - FAILED: #{image.errors.full_messages.join(', ')}"
      image_errors += 1
    end
  end

  puts ''
  puts "Shared images: #{image_success} imported, #{image_errors} errors"
end

# Final summary
puts ''
puts '=' * 70
puts '✅ Import complete'
puts '=' * 70

total_errors = template_errors + (block_errors || 0) + (image_errors || 0)

if total_errors > 0
  puts ''
  puts "⚠️  Import completed with #{total_errors} error(s)"
  puts '   Check errors above for details'
  exit 1
else
  puts ''
  puts '✅ All data imported successfully'
  exit 0
end
