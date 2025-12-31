puts '=' * 70
puts 'TEMPLATE DIAGNOSTIC'
puts '=' * 70
puts ''

# Count all templates for account 1
total = MessageTemplate.where(account_id: 1).count
puts "Total templates for account 1: #{total}"

# Show ALL templates
puts ''
puts 'ALL templates for account 1:'
puts '-' * 70
MessageTemplate.where(account_id: 1).each do |t|
  puts "Name: #{t.name}"
  puts "  ID: #{t.id}"
  puts "  Status: #{t.status.inspect}"
  puts "  Category: #{t.category.inspect}"
  puts "  Supported Channels: #{t.supported_channels.inspect}"
  puts ''
end

# Count bot templates
bot_names = %w[ah_guitar_list_picker ah_guitar_info_form ah_large_form_demo ah_main_menu ah_ar_guitar ah_summary]
bot_count = MessageTemplate.where(account_id: 1, name: bot_names).count

puts '=' * 70
puts "Bot templates found: #{bot_count}/6"
puts '=' * 70

if bot_count == 0
  puts ''
  puts '❌ No bot templates exist - they need to be imported!'
  puts ''
  puts 'The import may have failed. Checking if export file exists...'
  if File.exist?('/tmp/bot_templates.json')
    data = JSON.parse(File.read('/tmp/bot_templates.json'))
    puts "✅ Export file exists with #{data['templates'].size} templates"
    puts ''
    puts 'Template names in export:'
    data['templates'].each { |t| puts "  - #{t['name']}" }
  else
    puts '❌ Export file not found at /tmp/bot_templates.json'
    puts 'Run deployment script to export and import templates'
  end
end
