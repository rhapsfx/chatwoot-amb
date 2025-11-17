#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to copy Apple Pay settings from one Apple Messages inbox to another
# Usage: rails runner script/copy_apple_pay_settings.rb

puts "=" * 80
puts "Apple Pay Settings Copy Script"
puts "=" * 80
puts ""

# Find source inbox (Rhaps AMB)
source_inbox = Inbox.find_by(name: 'Rhaps AMB')

unless source_inbox
  puts "❌ ERROR: Source inbox 'Rhaps AMB' not found"
  exit 1
end

# Verify it's an Apple Messages inbox
unless source_inbox.channel.is_a?(Channel::AppleMessagesForBusiness)
  puts "❌ ERROR: Source inbox is not an Apple Messages for Business inbox"
  puts "   Found type: #{source_inbox.channel.class.name}"
  exit 1
end

puts "✅ Found source inbox: #{source_inbox.name} (ID: #{source_inbox.id})"
puts "   Channel ID: #{source_inbox.channel_id}"
puts "   Channel Type: #{source_inbox.channel.class.name}"

# Find target inbox (Apple Temp (No branding))
target_inbox = Inbox.find_by(name: 'Apple Temp (No branding)')

unless target_inbox
  puts "❌ ERROR: Target inbox 'Apple Temp (No branding)' not found"
  exit 1
end

# Verify it's an Apple Messages inbox
unless target_inbox.channel.is_a?(Channel::AppleMessagesForBusiness)
  puts "❌ ERROR: Target inbox is not an Apple Messages for Business inbox"
  puts "   Found type: #{target_inbox.channel.class.name}"
  exit 1
end

puts "✅ Found target inbox: #{target_inbox.name} (ID: #{target_inbox.id})"
puts "   Channel ID: #{target_inbox.channel_id}"
puts "   Channel Type: #{target_inbox.channel.class.name}"
puts ""

# Get source channel payment settings
source_channel = source_inbox.channel
source_payment_settings = source_channel.payment_settings || {}

puts "📋 Source Channel Payment Settings:"
if source_payment_settings.empty?
  puts "   (empty)"
else
  # Show settings without exposing sensitive data
  source_payment_settings.each do |key, value|
    if key.to_s.include?('certificate') || key.to_s.include?('key') || key.to_s.include?('private')
      puts "   #{key}: [REDACTED - #{value.to_s.length} characters]"
    else
      puts "   #{key}: #{value}"
    end
  end
end
puts ""

# Confirm before copying
puts "🔄 Ready to copy payment settings to target inbox"
puts "   From: #{source_inbox.name}"
puts "   To:   #{target_inbox.name}"
puts ""

# Copy settings
target_channel = target_inbox.channel

puts "💾 Backing up current target settings..."
backup_settings = target_channel.payment_settings&.dup || {}
puts "   Backup created: #{backup_settings.keys.inspect}"
puts ""

puts "📝 Copying payment settings..."
target_channel.payment_settings = source_payment_settings.deep_dup

if target_channel.save
  puts "✅ Successfully copied payment settings!"
  puts ""
  puts "📊 Target Channel Payment Settings (after copy):"
  target_channel.payment_settings.each do |key, value|
    if key.to_s.include?('certificate') || key.to_s.include?('key') || key.to_s.include?('private')
      puts "   #{key}: [REDACTED - #{value.to_s.length} characters]"
    else
      puts "   #{key}: #{value}"
    end
  end
  puts ""
  puts "✅ COMPLETE: Apple Pay settings copied successfully"
  puts ""
  puts "📝 Next steps:"
  puts "   1. Restart your dev server if running"
  puts "   2. Test Apple Pay flow with 'Apple Temp (No branding)' inbox"
  puts "   3. Bot should use mock merchant session (test_mode enabled)"
else
  puts "❌ ERROR: Failed to save target channel"
  puts "   Errors: #{target_channel.errors.full_messages.join(', ')}"
  puts ""
  puts "🔙 Restoring backup settings..."
  target_channel.payment_settings = backup_settings
  target_channel.save
  puts "   Backup restored"
  exit 1
end

puts "=" * 80
