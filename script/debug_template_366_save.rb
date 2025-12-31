# frozen_string_literal: true

# Debug script to understand why received_image_identifier isn't saving
# Run with: rails runner script/debug_template_366_save.rb

puts '=' * 80
puts 'Template 366 Save Debug'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)

puts "Found template: #{template.name}"
puts ''

# Get the content block
block = template.content_blocks.find_by(block_type: 'list_picker')

puts '=' * 80
puts 'BEFORE MODIFICATION'
puts '=' * 80
puts ''

puts "Block ID: #{block.id}"
puts "Block properties keys: #{block.properties.keys.inspect}"
puts ''
puts "Current received_image_identifier: #{block.properties['received_image_identifier'].inspect}"
puts "Current reply_image_identifier: #{block.properties['reply_image_identifier'].inspect}"
puts ''

puts 'Full properties structure:'
puts JSON.pretty_generate(block.properties.slice('received_image_identifier', 'reply_image_identifier', 'received_title', 'received_subtitle',
                                                 'reply_title', 'reply_subtitle'))
puts ''

puts '=' * 80
puts 'MODIFYING'
puts '=' * 80
puts ''

# Make a copy of properties
new_props = block.properties.deep_dup

# Set the received image identifier
new_props['received_image_identifier'] = 'messages_png'

puts "Setting received_image_identifier to: 'messages_png'"
puts ''

# Assign back and save
block.properties = new_props
puts 'Assigned new properties to block'
puts ''

puts 'Calling block.save!...'
begin
  result = block.save!
  puts "✅ Save returned: #{result}"
rescue StandardError => e
  puts "❌ Save failed: #{e.message}"
  puts "   #{e.backtrace.first}"
end
puts ''

puts '=' * 80
puts 'AFTER SAVE (before reload)'
puts '=' * 80
puts ''

puts "block.properties['received_image_identifier']: #{block.properties['received_image_identifier'].inspect}"
puts ''

puts '=' * 80
puts 'AFTER RELOAD'
puts '=' * 80
puts ''

block.reload
puts "block.properties['received_image_identifier']: #{block.properties['received_image_identifier'].inspect}"
puts ''

puts 'Full properties structure:'
puts JSON.pretty_generate(block.properties.slice('received_image_identifier', 'reply_image_identifier', 'received_title', 'received_subtitle',
                                                 'reply_title', 'reply_subtitle'))
puts ''

# Also check via TemplateFacade
puts '=' * 80
puts 'VIA TEMPLATE FACADE'
puts '=' * 80
puts ''

template.reload
facade = AppleMessagesForBusiness::TemplateFacade.new(template)
data = facade.load_data('list_picker')

puts 'facade.load_data result:'
puts "  received_image_identifier: #{data['received_image_identifier'].inspect}"
puts "  reply_image_identifier: #{data['reply_image_identifier'].inspect}"
puts ''

puts '=' * 80
puts 'INVESTIGATION COMPLETE'
puts '=' * 80
