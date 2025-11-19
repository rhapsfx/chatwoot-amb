# frozen_string_literal: true

# Fix template 366 storage strategy preference
# Run with: rails runner script/fix_storage_strategy.rb

puts '=' * 80
puts 'Fix Template 366 Storage Strategy'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)

puts "Template: #{template.name}"
puts ''

puts '=' * 80
puts 'BEFORE'
puts '=' * 80
puts ''

puts "Current storage_strategy: #{template.metadata['storage_strategy'].inspect}"
puts ''

facade_before = AppleMessagesForBusiness::TemplateFacade.new(template)
data_before = facade_before.load_data('list_picker')
puts "TemplateFacade currently using: #{facade_before.storage_type}"
puts "Current received_image_identifier: #{data_before['received_image_identifier'].inspect}"
puts ''

puts '=' * 80
puts 'APPLYING FIX'
puts '=' * 80
puts ''

# Change storage strategy to 'content_blocks'
template.metadata['storage_strategy'] = 'content_blocks'
template.save!

puts "✅ Changed storage_strategy to: 'content_blocks'"
puts ''

puts '=' * 80
puts 'AFTER'
puts '=' * 80
puts ''

template.reload
facade_after = AppleMessagesForBusiness::TemplateFacade.new(template)
data_after = facade_after.load_data('list_picker')

puts "New storage_strategy: #{template.metadata['storage_strategy'].inspect}"
puts "TemplateFacade now using: #{facade_after.storage_type}"
puts "New received_image_identifier: #{data_after['received_image_identifier'].inspect}"
puts ''

puts '=' * 80
puts 'VERIFICATION'
puts '=' * 80
puts ''

# Check all important fields
puts 'Checking all message fields:'
puts "  received_title: #{data_after['received_title'].inspect}"
puts "  received_subtitle: #{data_after['received_subtitle'].inspect}"
puts "  received_image_identifier: #{data_after['received_image_identifier'].inspect}"
puts "  received_style: #{data_after['received_style'].inspect}"
puts ''
puts "  reply_title: #{data_after['reply_title'].inspect}"
puts "  reply_subtitle: #{data_after['reply_subtitle'].inspect}"
puts "  reply_image_identifier: #{data_after['reply_image_identifier'].inspect}"
puts "  reply_style: #{data_after['reply_style'].inspect}"
puts ''

# Check first few items
sections = data_after['sections'] || []
if sections.any?
  first_section = sections.first
  items = first_section['items'] || []
  puts 'First 3 items:'
  items.take(3).each_with_index do |item, i|
    puts "  #{i + 1}. #{item['title']}: image=#{item['image_identifier']}"
  end
end
puts ''

if data_after['received_image_identifier'] == 'messages_png'
  puts '✅ SUCCESS! received_image_identifier is now correct'
else
  puts "⚠️  received_image_identifier is still wrong: #{data_after['received_image_identifier'].inspect}"
end

puts ''
puts '=' * 80
puts 'COMPLETE'
puts '=' * 80
