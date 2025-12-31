require 'json'

puts '=' * 70
puts 'MANUAL TEMPLATE IMPORT'
puts '=' * 70
puts ''

template_file = '/tmp/bot_templates.json'

unless File.exist?(template_file)
  puts "❌ Template file not found: #{template_file}"
  exit 1
end

data = JSON.parse(File.read(template_file))

puts 'Export metadata:'
puts "  Account ID: #{data['metadata']['account_id']}"
puts "  Exported at: #{data['metadata']['exported_at']}"
puts "  Templates: #{data['templates'].size}"
puts ''

puts '=' * 70
puts 'IMPORTING TEMPLATES'
puts '=' * 70
puts ''

success_count = 0
error_count = 0

data['templates'].each do |template_data|
  puts "Processing: #{template_data['name']}"

  # Find or initialize template
  template = MessageTemplate.find_or_initialize_by(
    account_id: template_data['account_id'],
    name: template_data['name']
  )

  puts "  Status: #{template.new_record? ? 'NEW' : 'EXISTS (updating)'}"
  puts "  Current ID: #{template.id}" unless template.new_record?

  # Assign attributes (excluding id, attachments, status)
  attrs_to_assign = template_data.except('id', 'attachments', 'status')
  puts "  Attributes to assign: #{attrs_to_assign.keys.join(', ')}"

  template.assign_attributes(attrs_to_assign)

  # Show what will be saved
  puts '  After assignment:'
  puts "    name: #{template.name}"
  puts "    account_id: #{template.account_id}"
  puts "    status: #{template.status}"
  puts "    category: #{template.category}"
  puts "    supported_channels: #{template.supported_channels.inspect}"
  puts "    metadata: #{template.metadata.present? ? 'present' : 'nil'}"

  # Try to save
  if template.save
    puts "  ✅ Saved (ID: #{template.id})"
    success_count += 1
  else
    puts '  ❌ FAILED TO SAVE'
    puts "  Errors: #{template.errors.full_messages.join(', ')}"
    puts '  Validation errors:'
    template.errors.each do |error|
      puts "    - #{error.attribute}: #{error.message}"
    end
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
  puts '❌ Some templates failed to import - see errors above'
  exit 1
else
  puts '✅ All templates imported successfully'

  # Verify they're actually in the database
  puts ''
  puts 'Verifying templates exist in database...'
  bot_names = data['templates'].map { |t| t['name'] }
  found_count = MessageTemplate.where(account_id: 1, name: bot_names).count
  puts "  Templates in database: #{found_count}/#{data['templates'].size}"

  if found_count == data['templates'].size
    puts '  ✅ All templates verified in database'
  else
    puts '  ❌ Some templates missing from database after import!'
  end
end
