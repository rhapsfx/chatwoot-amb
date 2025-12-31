#!/usr/bin/env ruby
# Test template 323 (Quick Reply with hyphenated key)

template = MessageTemplate.find(323)
puts "Template 323: #{template.name}"

# Simulate bot rendering
service = Templates::BotRendererService.new(
  template_id: 323,
  parameters: {},
  channel_type: 'apple_messages_for_business'
)

result = service.render_for_bot
puts "Detected content type: #{result[:content_type]}"
puts "Content attributes keys: #{result[:content_attributes].keys.join(', ')}"
puts "Items count: #{result[:content_attributes]['items']&.length || 0}"

if result[:content_attributes]['items'].present?
  puts "\nItems:"
  result[:content_attributes]['items'].each_with_index do |item, idx|
    puts "  #{idx + 1}. #{item['title']} (#{item['identifier']})"
  end
end
