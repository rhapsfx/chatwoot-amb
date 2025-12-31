require 'json'

puts '=' * 70
puts 'CONTENT BLOCK IMPORT'
puts '=' * 70
puts ''

template_file = '/tmp/bot_templates.json'

unless File.exist?(template_file)
  puts "❌ Template file not found: #{template_file}"
  exit 1
end

data = JSON.parse(File.read(template_file))

puts 'Export contains:'
puts "  Templates: #{data['templates'].size}"
puts "  Content Blocks: #{data['content_blocks'].size}"
puts "  Shared Images: #{data['shared_images'].size}"
puts ''

if data['content_blocks'].empty?
  puts '⚠️  No content blocks to import'
  exit 0
end

puts '=' * 70
puts 'IMPORTING CONTENT BLOCKS'
puts '=' * 70
puts ''

success_count = 0
error_count = 0

data['content_blocks'].each do |block_data|
  puts 'Processing content block:'
  puts "  Source template ID (from export): #{block_data['message_template_id']}"
  puts "  Block type: #{block_data['block_type']}"
  puts "  Order index: #{block_data['order_index']}"

  # Find the source template name from export
  source_template_id = block_data['message_template_id']
  source_template = data['templates'].find { |t| t['id'] == source_template_id }

  unless source_template
    puts "  ❌ Could not find source template with ID #{source_template_id} in export"
    error_count += 1
    puts ''
    next
  end

  source_template_name = source_template['name']
  puts "  Source template name: #{source_template_name}"

  # Find the template in production by name
  template = MessageTemplate.find_by(
    account_id: data['metadata']['account_id'],
    name: source_template_name
  )

  unless template
    puts "  ❌ Template '#{source_template_name}' not found in production database"
    error_count += 1
    puts ''
    next
  end

  puts "  Production template ID: #{template.id}"

  # Find or create content block
  block = TemplateContentBlock.find_or_initialize_by(
    message_template_id: template.id,
    block_type: block_data['block_type'],
    order_index: block_data['order_index']
  )

  puts "  Status: #{block.new_record? ? 'NEW' : 'EXISTS (updating)'}"

  # Assign attributes (exclude id and message_template_id)
  block.assign_attributes(block_data.except('id', 'message_template_id'))

  # Show what will be saved
  puts "  Properties: #{block.properties.present? ? block.properties.keys.join(', ') : 'none'}"
  puts "  Conditions: #{block.conditions.present? ? 'present' : 'none'}"

  # Try to save
  if block.save
    puts "  ✅ Saved content block (ID: #{block.id})"
    success_count += 1
  else
    puts '  ❌ FAILED TO SAVE'
    puts "  Errors: #{block.errors.full_messages.join(', ')}"
    error_count += 1
  end

  puts ''
end

puts '=' * 70
puts 'IMPORT SUMMARY'
puts '=' * 70
puts "  Success: #{success_count}"
puts "  Errors: #{error_count}"
puts ''

if error_count > 0
  puts '❌ Some content blocks failed to import'
  exit 1
else
  puts '✅ All content blocks imported successfully'

  # Show template content block counts
  puts ''
  puts 'Templates with content blocks:'
  bot_names = data['templates'].map { |t| t['name'] }
  MessageTemplate.where(account_id: 1, name: bot_names).each do |t|
    block_count = t.content_blocks.count
    puts "  #{t.name}: #{block_count} block(s)"
  end
end
