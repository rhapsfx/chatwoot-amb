# frozen_string_literal: true

# Debug script to trace CaseTransformer normalization
# Run with: rails runner script/trace_case_transformer.rb

puts '=' * 80
puts 'Tracing CaseTransformer.normalize_content_attributes'
puts '=' * 80
puts ''

# Get template 366
template = MessageTemplate.find_by(id: 366)
block = template.content_blocks.find_by(block_type: 'list_picker')

puts '=' * 80
puts 'STEP 1: Raw ContentBlock Properties'
puts '=' * 80
puts ''

raw_props = block.properties
puts "Raw properties class: #{raw_props.class}"
puts ''
puts 'received_image_identifier:'
puts "  Value: #{raw_props['received_image_identifier'].inspect}"
puts "  Class: #{raw_props['received_image_identifier'].class}"
puts ''

puts '=' * 80
puts 'STEP 2: Call CaseTransformer.normalize_content_attributes'
puts '=' * 80
puts ''

# Call normalize directly
normalized = AppleMessagesForBusiness::CaseTransformer.normalize_content_attributes(raw_props)

puts "Normalized result class: #{normalized.class}"
puts ''
puts 'received_image_identifier in normalized:'
puts "  Value: #{normalized['received_image_identifier'].inspect}"
puts "  Class: #{normalized['received_image_identifier']&.class || 'nil'}"
puts ''

# Check if key exists at all
puts "Has 'received_image_identifier' key? #{normalized.key?('received_image_identifier')}"
puts ''
puts 'All keys in normalized result:'
puts normalized.keys.sort.inspect
puts ''

puts '=' * 80
puts 'STEP 3: Call from_apple_format directly'
puts '=' * 80
puts ''

# Call from_apple_format with a simple test hash
test_hash = { 'received_image_identifier' => 'messages_png' }
puts "Test input: #{test_hash.inspect}"
puts ''

result = AppleMessagesForBusiness::CaseTransformer.from_apple_format(test_hash)
puts "Result: #{result.inspect}"
puts ''

puts '=' * 80
puts 'STEP 4: Check sections normalization'
puts '=' * 80
puts ''

sections = raw_props['sections'] || []
puts "Number of sections: #{sections.length}"

if sections.any?
  first_section = sections.first
  puts ''
  puts 'First section:'
  puts "  title: #{first_section['title'].inspect}"
  puts "  items count: #{first_section['items']&.length || 0}"

  if first_section['items']&.any?
    first_item = first_section['items'].first
    puts ''
    puts 'First item:'
    puts "  title: #{first_item['title'].inspect}"
    puts "  image_identifier: #{first_item['image_identifier'].inspect}"
  end
end

puts ''
puts 'Normalized sections:'
normalized_sections = normalized['sections'] || []
puts "Number of sections: #{normalized_sections.length}"

if normalized_sections.any?
  first_norm_section = normalized_sections.first
  puts ''
  puts 'First normalized section:'
  puts "  title: #{first_norm_section['title'].inspect}"
  puts "  items count: #{first_norm_section['items']&.length || 0}"

  if first_norm_section['items']&.any?
    first_norm_item = first_norm_section['items'].first
    puts ''
    puts 'First normalized item:'
    puts "  title: #{first_norm_item['title'].inspect}"
    puts "  image_identifier: #{first_norm_item['image_identifier'].inspect}"
  end
end

puts ''
puts '=' * 80
puts 'STEP 5: Call TemplateFacade'
puts '=' * 80
puts ''

template.reload
facade = AppleMessagesForBusiness::TemplateFacade.new(template)
facade_data = facade.load_data('list_picker')

puts 'TemplateFacade.load_data result:'
puts "  received_image_identifier: #{facade_data['received_image_identifier'].inspect}"
puts ''

puts '=' * 80
puts 'COMPLETE'
puts '=' * 80
