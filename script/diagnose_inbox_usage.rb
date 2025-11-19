# frozen_string_literal: true

# Diagnose which inboxes are being used and where images are stored
# Run with: rails runner script/diagnose_inbox_usage.rb

puts '=' * 80
puts 'Diagnose Inbox Usage and Image Storage'
puts '=' * 80
puts ''

# Find all Apple Messages for Business inboxes
amb_channels = Channel::AppleMessagesForBusiness.all

puts 'Apple Messages for Business Channels:'
puts ''

amb_channels.each do |channel|
  inbox = channel.inbox
  puts "Channel ID: #{channel.id}"
  puts "  Inbox ID: #{inbox.id}"
  puts "  Inbox Name: #{inbox.name}"
  puts "  Account ID: #{inbox.account_id}"
  puts ''
end

# Check which inbox has recent conversations
puts '=' * 80
puts 'Recent Conversations (last 24 hours)'
puts '=' * 80
puts ''

recent_conversations = Conversation
                       .where('created_at > ?', 24.hours.ago)
                       .where(inbox_id: amb_channels.map { |c| c.inbox.id })
                       .order(created_at: :desc)
                       .limit(10)

if recent_conversations.any?
  recent_conversations.each do |conv|
    puts "Conversation #{conv.id}"
    puts "  Inbox: #{conv.inbox_id} (#{conv.inbox.name})"
    puts "  Created: #{conv.created_at}"
    puts "  Messages: #{conv.messages.count}"
    puts ''
  end
else
  puts 'No recent conversations found'
  puts ''
end

# Check image distribution across inboxes
puts '=' * 80
puts 'Image Distribution by Inbox'
puts '=' * 80
puts ''

AppleListPickerImage.group(:inbox_id).count.each do |inbox_id, count|
  inbox = Inbox.find_by(id: inbox_id)
  puts "Inbox #{inbox_id} (#{inbox&.name || 'DELETED'}): #{count} images"
end

puts ''

# Check messages_png specifically
puts '=' * 80
puts 'messages_png Location'
puts '=' * 80
puts ''

messages_images = AppleListPickerImage.where(identifier: 'messages_png')

if messages_images.any?
  puts "Found 'messages_png' in these inboxes:"
  messages_images.each do |img|
    inbox = img.inbox
    puts "  - Inbox #{img.inbox_id}: #{inbox.name}"
    puts "    Account: #{inbox.account_id}"
    puts "    Has attachment: #{img.image.attached?}"
  end
else
  puts "❌ 'messages_png' not found in any inbox!"
end

puts ''

# Check menu item images
puts '=' * 80
puts 'Menu Item Images (sample: list_bullet_512_12)'
puts '=' * 80
puts ''

menu_images = AppleListPickerImage.where(identifier: 'list_bullet_512_12')

if menu_images.any?
  puts 'Found menu item images in these inboxes:'
  menu_images.each do |img|
    inbox = img.inbox
    puts "  - Inbox #{img.inbox_id}: #{inbox.name}"
    puts "    Account: #{inbox.account_id}"
    puts "    Has attachment: #{img.image.attached?}"
  end
else
  puts '❌ Menu item images not found in any inbox!'
end

puts ''

# DIAGNOSIS
puts '=' * 80
puts 'DIAGNOSIS'
puts '=' * 80
puts ''

messages_inbox_ids = messages_images.map(&:inbox_id).uniq
menu_inbox_ids = menu_images.map(&:inbox_id).uniq

if messages_inbox_ids.any? && menu_inbox_ids.any?
  if messages_inbox_ids == menu_inbox_ids
    puts "✅ Both image types are in the SAME inbox(es): #{messages_inbox_ids.inspect}"
  else
    puts '❌ MISMATCH!'
    puts "   'messages_png' is in inbox(es): #{messages_inbox_ids.inspect}"
    puts "   Menu items are in inbox(es): #{menu_inbox_ids.inspect}"
    puts ''
    puts "When bot sends from inbox(es) #{menu_inbox_ids.inspect}, it can't find messages_png!"
    puts ''
    puts "SOLUTION: Copy messages_png to inbox(es): #{menu_inbox_ids.inspect}"
  end
elsif messages_inbox_ids.empty?
  puts '❌ messages_png not uploaded yet!'
elsif menu_inbox_ids.empty?
  puts "❌ Menu items haven't been sent yet (will be uploaded on first send)"
end

puts ''
