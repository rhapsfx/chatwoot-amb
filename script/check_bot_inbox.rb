# frozen_string_literal: true

# Check which inbox the acoustic_house_bot is using
# Run with: rails runner script/check_bot_inbox.rb

puts '=' * 80
puts 'Check Acoustic House Bot Inbox'
puts '=' * 80
puts ''

# Find the bot service file
bot_service_path = Rails.root.join('app/services/apple_messages_for_business/acoustic_house_bot_service.rb')

if File.exist?(bot_service_path)
  puts '✅ Found acoustic_house_bot_service.rb'
  puts ''

  # Read the file to see which inbox it uses
  content = File.read(bot_service_path)

  # Look for inbox references
  inbox_refs = content.scan(/inbox[_\s]*[=:]\s*(\d+|Inbox\.|@inbox)/).flatten.uniq

  puts 'Inbox references found in bot service:'
  inbox_refs.each { |ref| puts "  - #{ref}" }
  puts ''

  # Search for conversation.inbox pattern
  if content.include?('conversation.inbox')
    puts '✅ Uses: conversation.inbox (dynamic - depends on which inbox receives the message)'
    puts ''
  elsif content.include?('Inbox.find')
    puts 'Uses: Inbox.find (hardcoded lookup)'
  end
else
  puts '❌ acoustic_house_bot_service.rb not found'
end

puts '=' * 80
puts "Check which inboxes have 'messages_png'"
puts '=' * 80
puts ''

messages_images = AppleListPickerImage.where(identifier: 'messages_png')

if messages_images.any?
  puts "Found 'messages_png' in these inboxes:"
  messages_images.each do |img|
    inbox = img.inbox
    puts "  - Inbox #{img.inbox_id}: #{inbox.name}"
    puts "    Account: #{inbox.account_id}"
    puts "    Channel: #{inbox.channel_type}"
  end
else
  puts "❌ No 'messages_png' found in any inbox!"
end

puts ''

puts '=' * 80
puts 'Check which inboxes have the menu item images'
puts '=' * 80
puts ''

sample_identifier = 'list_bullet_512_12'
sample_images = AppleListPickerImage.where(identifier: sample_identifier)

if sample_images.any?
  puts "Found '#{sample_identifier}' in these inboxes:"
  sample_images.each do |img|
    inbox = img.inbox
    puts "  - Inbox #{img.inbox_id}: #{inbox.name}"
  end
else
  puts "❌ No '#{sample_identifier}' found!"
end

puts ''

puts '=' * 80
puts 'DIAGNOSIS'
puts '=' * 80
puts ''

messages_inbox_ids = messages_images.map(&:inbox_id).uniq
menu_item_inbox_ids = sample_images.map(&:inbox_id).uniq

if messages_inbox_ids.any? && menu_item_inbox_ids.any?
  if messages_inbox_ids == menu_item_inbox_ids
    puts "✅ Both image types are in the SAME inbox(es): #{messages_inbox_ids.inspect}"
  else
    puts '❌ MISMATCH!'
    puts "   'messages_png' is in inbox(es): #{messages_inbox_ids.inspect}"
    puts "   Menu items are in inbox(es): #{menu_item_inbox_ids.inspect}"
    puts ''
    puts "You need to upload 'messages_png' to inbox(es): #{menu_item_inbox_ids.inspect}"
  end
end

puts ''
