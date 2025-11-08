#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to list Apple Messages for Business inboxes
# Usage: rails runner script/list_apple_inboxes.rb

puts "\n=== Apple Messages for Business Inboxes ==="
puts '=' * 50

Account.all.each do |account|
  puts "\nAccount: #{account.name} (ID: #{account.id})"

  amb_inboxes = account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness')

  if amb_inboxes.any?
    amb_inboxes.each do |inbox|
      puts "  ✅ Inbox ID: #{inbox.id}"
      puts "     Name: #{inbox.name}"
      puts "     Channel: #{inbox.channel_type}"
      puts '     ---'
    end
  else
    puts '  ⚠️  No Apple Messages for Business inboxes found'
  end
end

puts "\n" + ('=' * 50)
puts 'To use the guitar form script:'
puts 'rails runner script/create_guitar_info_form_template.rb --account-id <ACCOUNT_ID> --inbox-id <INBOX_ID>'
puts '=' * 50
