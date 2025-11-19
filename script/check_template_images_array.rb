# frozen_string_literal: true

# Check template 366 images array in properties
# Run with: rails runner script/check_template_images_array.rb

puts '=' * 80
puts 'Check Template 366 Images Array'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
block = template.content_blocks.find_by(block_type: 'list_picker')

puts "Template: #{template.name}"
puts ''

props = block.properties
images = props['images'] || []

puts 'Images array in template properties:'
puts "  Count: #{images.count}"
puts ''

if images.any?
  puts 'Template has embedded images array:'
  puts ''

  images.each_with_index do |img, i|
    puts "#{i + 1}. Identifier: #{img['identifier'].inspect}"
    puts "   originalName: #{img['originalName'].inspect}"
    puts "   description: #{img['description'].inspect}"
    puts "   preview: #{img['preview'] ? 'present (base64 data)' : 'none'}"
    puts ''
  end
else
  puts '❌ No images array in template properties!'
  puts ''
  puts 'This means the template does NOT have embedded images.'
  puts 'The UI must be loading images from somewhere else.'
end

puts '=' * 80
puts 'ALL PROPERTIES'
puts '=' * 80
puts ''

puts "Template properties keys: #{props.keys.inspect}"
puts ''
