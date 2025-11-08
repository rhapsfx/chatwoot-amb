#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to check template structure
# Usage: rails runner scripts/debug_template_structure.rb TEMPLATE_ID

template_id = ARGV[0]&.to_i

unless template_id && template_id > 0
  puts 'Usage: rails runner scripts/debug_template_structure.rb TEMPLATE_ID'
  exit 1
end

template = MessageTemplate.find_by(id: template_id)

unless template
  puts "Template ##{template_id} not found"
  exit 1
end

puts '=' * 80
puts "Template ##{template_id}: #{template.name}"
puts '=' * 80
puts

puts '📋 Basic Info:'
puts "  Category: #{template.category}"
puts "  Status: #{template.status}"
puts "  Content Type (from metadata): #{template.metadata.dig('apple_message_content', 'content_type')}"
puts

puts "📦 Content Blocks (#{template.content_blocks.count}):"
template.content_blocks.order(:order_index).each do |block|
  puts "  Block ##{block.id}:"
  puts "    Type: #{block.block_type}"
  puts "    Properties keys: #{block.properties.keys.inspect}"

  if block.block_type == 'list_picker'
    sections = block.properties['sections'] || []
    puts "    Sections count: #{sections.size}"
    sections.each_with_index do |section, idx|
      items = section['items'] || []
      puts "      Section #{idx}: #{items.size} items"
    end

    puts "    Has receivedMessage: #{block.properties['receivedMessage'].present?}"
    puts "    Has replyMessage: #{block.properties['replyMessage'].present?}"
    puts "    MultipleSelection: #{block.properties['multipleSelection']}"
  end
  puts
end

puts "🔗 Channel Mappings (#{template.channel_mappings.count}):"
template.channel_mappings.each do |mapping|
  puts "  Mapping ##{mapping.id}:"
  puts "    Channel: #{mapping.channel_type}"
  puts "    Content Type: #{mapping.content_type}"
  puts "    Field Mappings: #{mapping.field_mappings.inspect}"
  puts
end

puts '💾 Full Properties JSON:'
template.content_blocks.first&.properties&.then do |props|
  puts JSON.pretty_generate(props)
end
