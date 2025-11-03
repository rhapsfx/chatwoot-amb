#!/usr/bin/env ruby
# Script to enable Captain feature for development
# Usage: rails runner enable_captain_feature.rb

puts '🚀 Enabling Captain feature for development...'
puts ''

# Get all accounts
accounts = Account.all

if accounts.empty?
  puts '❌ No accounts found in the database.'
  puts '   Please create an account first.'
  exit 1
end

puts "Found #{accounts.count} account(s):"
accounts.each do |account|
  puts "  - Account ##{account.id}: #{account.name}"
end
puts ''

# Enable Captain for all accounts
accounts.each do |account|
  puts "Enabling Captain for Account ##{account.id} (#{account.name})..."

  # Enable both versions of Captain
  account.enable_features!('captain_integration', 'captain_integration_v2')

  # Verify
  v1_enabled = account.feature_enabled?('captain_integration')
  v2_enabled = account.feature_enabled?('captain_integration_v2')

  if v1_enabled && v2_enabled
    puts '  ✅ Captain v1: Enabled'
    puts '  ✅ Captain v2: Enabled'
  else
    puts "  ⚠️  Captain v1: #{v1_enabled ? 'Enabled' : 'Failed'}"
    puts "  ⚠️  Captain v2: #{v2_enabled ? 'Enabled' : 'Failed'}"
  end
  puts ''
end

puts '✨ Done! Captain feature has been enabled.'
puts ''
puts '📝 Next steps:'
puts '   1. Restart your Rails server (./dev-server.sh restart)'
puts '   2. Refresh your browser'
puts '   3. Look for Captain in the navigation menu'
puts ''
puts '🔍 To verify in Rails console:'
puts '   rails console'
puts "   Account.first.feature_enabled?('captain_integration')"
puts ''
