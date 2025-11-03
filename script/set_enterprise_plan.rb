#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to set enterprise pricing plan for development
# This bypasses the Captain paywall by setting the installation pricing plan to 'enterprise'

puts "Setting INSTALLATION_PRICING_PLAN to 'enterprise'..."

# Find or create the InstallationConfig record
config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN')
config.value = 'enterprise'

if config.save
  puts "✅ Successfully set INSTALLATION_PRICING_PLAN to 'enterprise'"
  puts "   Current value: #{InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.value}"
  puts "\n⚠️  IMPORTANT: You must restart your Rails server for this change to take effect!"
  puts '   Run: ./dev-server.sh restart'
else
  puts '❌ Failed to set INSTALLATION_PRICING_PLAN'
  puts "   Errors: #{config.errors.full_messages.join(', ')}"
end
