# frozen_string_literal: true

# Check template 366's storage strategy decision
# Run with: rails runner script/check_storage_strategy.rb

puts '=' * 80
puts 'Template 366 Storage Strategy Investigation'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)

puts "Template: #{template.name}"
puts ''

puts '=' * 80
puts 'Storage Indicators'
puts '=' * 80
puts ''

# Check metadata
puts "Has metadata? #{template.metadata.present?}"
if template.metadata.present?
  puts "metadata.keys: #{template.metadata.keys.inspect}"
  puts ''

  puts "Has 'storage_strategy' in metadata?"
  puts "  #{template.metadata.key?('storage_strategy')}"
  puts "  Value: #{template.metadata['storage_strategy'].inspect}" if template.metadata.key?('storage_strategy')
  puts ''

  puts "Has 'apple_message_content' in metadata?"
  puts "  #{template.metadata.key?('apple_message_content')}"
  if template.metadata['apple_message_content'].present?
    puts "  Keys: #{template.metadata['apple_message_content'].keys.inspect}"

    if template.metadata['apple_message_content']['content_attributes'].present?
      content_attrs = template.metadata['apple_message_content']['content_attributes']
      puts "  content_attributes.keys: #{content_attrs.keys.inspect}"
      puts "  received_image_identifier: #{content_attrs['received_image_identifier'].inspect}"
    end
  end
end

puts ''

# Check content_blocks
puts "Has content_blocks? #{template.content_blocks.exists?}"
if template.content_blocks.exists?
  puts "  Count: #{template.content_blocks.count}"
  template.content_blocks.each do |block|
    puts "  Block #{block.id}: type=#{block.block_type}, order=#{block.order_index}"
  end
end

puts ''

puts '=' * 80
puts 'TemplateFacade Decision Logic'
puts '=' * 80
puts ''

# Simulate the facade's decision logic
if template.metadata&.dig('storage_strategy')
  strategy_name = template.metadata['storage_strategy']
  puts "✓ Priority 1: Explicit storage_strategy = '#{strategy_name}'"
  puts "  → Will use: #{strategy_name.camelize}Strategy"
elsif template.content_blocks.exists?
  puts '✓ Priority 2: Has content_blocks'
  puts '  → Will use: ContentBlocksStrategy'
elsif template.metadata.present? && template.metadata['apple_message_content'].present?
  puts "✓ Priority 3: Has metadata['apple_message_content']"
  puts '  → Will use: MetadataStrategy'
else
  puts '✓ Default: No data found'
  puts '  → Will use: MetadataStrategy (default)'
end

puts ''

puts '=' * 80
puts 'Test Both Strategies'
puts '=' * 80
puts ''

# Test ContentBlocksStrategy directly
puts "ContentBlocksStrategy.load_data('list_picker'):"
content_strategy = AppleMessagesForBusiness::StorageStrategies::ContentBlocksStrategy.new(template)
content_data = content_strategy.load_data('list_picker')
puts "  received_image_identifier: #{content_data['received_image_identifier'].inspect}"
puts ''

# Test MetadataStrategy directly
puts "MetadataStrategy.load_data('list_picker'):"
metadata_strategy = AppleMessagesForBusiness::StorageStrategies::MetadataStrategy.new(template)
metadata_data = metadata_strategy.load_data('list_picker')
puts "  received_image_identifier: #{metadata_data['received_image_identifier'].inspect}"
puts ''

# Test TemplateFacade (what's actually used)
puts "TemplateFacade.load_data('list_picker'):"
facade = AppleMessagesForBusiness::TemplateFacade.new(template)
facade_data = facade.load_data('list_picker')
puts "  Storage type: #{facade.storage_type}"
puts "  received_image_identifier: #{facade_data['received_image_identifier'].inspect}"
puts ''

puts '=' * 80
puts 'COMPLETE'
puts '=' * 80
