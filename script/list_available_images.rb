# frozen_string_literal: true

# List all available AppleListPickerImage records for template 366's inbox
# Run with: rails runner script/list_available_images.rb

puts '=' * 80
puts 'Available AppleListPickerImage Records'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
inbox_id = template.account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').first&.id

puts "Template: #{template.name}"
puts "Account ID: #{template.account_id}"
puts "Inbox ID: #{inbox_id}"
puts ''

if inbox_id.nil?
  puts '❌ No Apple Messages inbox found for this account'
  exit 1
end

puts '=' * 80
puts 'All AppleListPickerImage Records'
puts '=' * 80
puts ''

images = AppleListPickerImage.where(inbox_id: inbox_id).order(:id)

if images.empty?
  puts "❌ No images found in AppleListPickerImage table for inbox #{inbox_id}"
  puts ''
  puts 'This means images need to be uploaded first via the UI or upload scripts.'
  exit 1
end

puts "Found #{images.count} image(s):"
puts ''

images.each_with_index do |img, i|
  puts "#{i + 1}. ID: #{img.id}"
  puts "   Identifier: #{img.identifier.inspect}"
  puts "   Description: #{img.description.inspect}"
  puts "   Original Name: #{img.original_name.inspect}"
  puts "   Image attached? #{img.image.attached?}"
  puts ''
end

puts '=' * 80
puts 'IDENTIFIER MAPPING'
puts '=' * 80
puts ''

puts 'Use these identifiers in your template:'
images.each do |img|
  puts "  '#{img.identifier}' => #{img.original_name.inspect}"
end

puts ''
puts '=' * 80
puts 'COMPLETE'
puts '=' * 80
