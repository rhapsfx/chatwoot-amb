#!/usr/bin/env ruby
# Script to enable Custom Roles feature for development
# Usage: rails runner enable_custom_roles.rb

puts '🔐 Enabling Custom Roles feature for development...'
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

# Enable Custom Roles for all accounts
accounts.each do |account|
  puts "Enabling Custom Roles for Account ##{account.id} (#{account.name})..."

  # Enable custom_roles feature
  account.enable_features!('custom_roles')

  # Verify
  enabled = account.feature_enabled?('custom_roles')

  if enabled
    puts '  ✅ Custom Roles: Enabled'
  else
    puts '  ❌ Custom Roles: Failed to enable'
  end
  puts ''
end

puts '✨ Done! Custom Roles feature has been enabled.'
puts ''
puts '📝 Next steps:'
puts '   1. Restart your Rails server (./dev-server.sh restart)'
puts '   2. Refresh your browser'
puts '   3. Navigate to: /app/accounts/1/settings/custom-roles/list'
puts '   4. You should now see the Custom Roles settings page'
puts ''
puts '🔍 To verify in Rails console:'
puts '   rails console'
puts "   Account.first.feature_enabled?('custom_roles')"
puts ''
