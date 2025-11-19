# frozen_string_literal: true

# Check template 366 history and find what identifiers it originally had
# Run with: rails runner script/find_original_identifiers.rb

puts '=' * 80
puts 'Find Original Working Image Identifiers for Template 366'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
block = template.content_blocks.find_by(block_type: 'list_picker')

puts "Template: #{template.name}"
puts ''

puts '=' * 80
puts 'CHECKING BOTH STORAGE LOCATIONS'
puts '=' * 80
puts ''

# Check ContentBlocks (current)
puts '1. ContentBlocks (current storage):'
if block
  props = block.properties
  sections = props['sections'] || []
  section = sections.first
  items = section['items'] || []

  puts "   Received image: #{props['received_image_identifier'].inspect}"
  puts '   Menu items:'
  items.take(3).each_with_index do |item, i|
    puts "     #{i + 1}. #{item['title']}: #{item['image_identifier'].inspect}"
  end
  puts "   ... (#{items.count} total items)"
else
  puts '   No content block found'
end
puts ''

# Check Metadata (old storage)
puts '2. Metadata (old storage):'
if template.metadata&.dig('apple_message_content', 'content_attributes')
  content_attrs = template.metadata['apple_message_content']['content_attributes']

  # Check if it's nested or flat format
  if content_attrs['list_picker']
    list_picker_data = content_attrs['list_picker']
    puts '   Format: OLD NESTED'
    puts "   Received image: #{list_picker_data['received_image_identifier'].inspect}"

    sections = list_picker_data['sections'] || []
    if sections.any?
      items = sections.first['items'] || []
      puts '   Menu items:'
      items.take(3).each_with_index do |item, i|
        puts "     #{i + 1}. #{item['title']}: #{item['image_identifier'].inspect}"
      end
      puts "   ... (#{items.count} total items)"
    end
  elsif content_attrs['sections']
    puts '   Format: NEW FLAT'
    puts "   Received image: #{content_attrs['received_image_identifier'].inspect}"

    sections = content_attrs['sections'] || []
    if sections.any?
      items = sections.first['items'] || []
      puts '   Menu items:'
      items.take(3).each_with_index do |item, i|
        puts "     #{i + 1}. #{item['title']}: #{item['image_identifier'].inspect}"
      end
      puts "   ... (#{items.count} total items)"
    end
  else
    puts '   No list_picker data in metadata'
  end
else
  puts '   No metadata content found'
end
puts ''

puts '=' * 80
puts 'PROBLEM DIAGNOSIS'
puts '=' * 80
puts ''

current_identifiers = []
if block
  props = block.properties
  sections = props['sections'] || []
  section = sections.first
  items = section['items'] || []
  current_identifiers = items.map { |i| i['image_identifier'] }.uniq
end

puts 'Current unique image identifiers in template:'
current_identifiers.each do |id|
  exists = AppleListPickerImage.exists?(inbox_id: 4, identifier: id)
  status = exists ? '✅ EXISTS' : '❌ MISSING'
  puts "  '#{id}' - #{status}"
end
puts ''

puts '=' * 80
puts 'SOLUTION OPTIONS'
puts '=' * 80
puts ''

puts 'Since the correct menu icon images are NOT in the database, you have 2 options:'
puts ''
puts 'Option 1: Upload the correct images'
puts '  - Go to Chatwoot UI → Inbox 4 → Apple List Picker Images'
puts '  - Upload: Messages.png, list.bullet-512.png, ARKit-512.png, etc.'
puts '  - Note the identifiers assigned to each'
puts '  - Update template 366 with those identifiers'
puts ''
puts 'Option 2: Use existing images (aha19 series or others)'
puts '  - Map the 12 menu items to existing images that are close enough'
puts '  - For example:'
puts "    - 'aha19_2' (summary_list_picker.png) for list items"
puts "    - 'aha19_3' (summary_ar_experience.png) for AR"
puts "    - 'aha19_1' (summary_apple_pay.png) for Apple Pay"
puts '    - etc.'
puts ''
puts 'Which option do you prefer?'
puts ''
