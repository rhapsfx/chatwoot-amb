#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to add content block to existing Guitar Information Form template
# Usage: rails runner script/fix_guitar_form_content_block.rb --template-id 342

require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: rails runner script/fix_guitar_form_content_block.rb [options]'

  opts.on('--template-id ID', Integer, 'Template ID (required)') do |id|
    options[:template_id] = id
  end

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end
end.parse!

unless options[:template_id]
  puts 'Error: --template-id is required'
  exit 1
end

template = MessageTemplate.find(options[:template_id])

puts "Found template: #{template.name} (ID: #{template.id})"

# Get the content_attributes from template metadata
content_attributes = template.metadata.dig('apple_message_content', 'content_attributes')

if content_attributes.nil?
  puts 'Error: No content_attributes found in template metadata'
  exit 1
end

# Check if content block already exists
existing_block = template.content_blocks.find_by(block_type: 'form')
if existing_block
  puts "✅ Content block already exists (ID: #{existing_block.id})"
  puts '   Updating properties...'
  existing_block.update!(properties: content_attributes)
  puts '   ✅ Updated successfully'
else
  # Create content block
  block = template.content_blocks.create!(
    block_type: 'form',
    properties: content_attributes,
    order_index: 0
  )
  puts "✅ Created content block (ID: #{block.id})"
end

puts "\n✨ Success! Template is now ready to use"
puts "Template ID: #{template.id}"
