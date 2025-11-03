#!/bin/bash
set -e

# Script to enable or disable Captain AI on remote server
# Usage: ./manage-captain-remote.sh [enable|disable]

ACTION="${1:-enable}"

if [[ "$ACTION" != "enable" && "$ACTION" != "disable" ]]; then
    echo "❌ Invalid action: $ACTION"
    echo "Usage: $0 [enable|disable]"
    exit 1
fi

if [[ "$ACTION" == "enable" ]]; then
    echo "=== Enabling Captain AI on Remote Server ==="
else
    echo "=== Disabling Captain AI on Remote Server ==="
fi

echo "Server: msp.rhaps.net"
echo ""

# Step 1: Create the script locally
echo "Step 1: Creating ${ACTION} script..."
cat > /tmp/captain_remote.rb << RUBY_SCRIPT
#!/usr/bin/env ruby
# frozen_string_literal: true

ACTION = '$ACTION'

if ACTION == 'enable'
  puts "=== Enabling Captain AI Features ==="
  puts ""
  
  # Enable Captain feature flags for all accounts
  puts "Enabling Captain feature flags..."
  Account.find_each do |account|
    account.enable_features!('captain_integration', 'captain_integration_v2')
    puts "  ✅ Account #{account.id} (#{account.name}): Captain enabled"
  end
  
  puts ""
  puts "Setting enterprise pricing plan..."
  config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN')
  config.value = 'enterprise'
  if config.save
    puts "  ✅ INSTALLATION_PRICING_PLAN set to 'enterprise'"
  else
    puts "  ❌ Failed: #{config.errors.full_messages.join(', ')}"
  end
  
  puts ""
  puts "=== Summary ==="
  puts "Total accounts: #{Account.count}"
  puts "Installation plan: #{InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.value || 'community'}"
  puts ""
  puts "✅ Captain AI is now enabled!"
  
else
  puts "=== Disabling Captain AI Features ==="
  puts ""
  
  # Disable Captain feature flags for all accounts
  puts "Disabling Captain feature flags..."
  Account.find_each do |account|
    account.disable_features!('captain_integration', 'captain_integration_v2')
    puts "  ✅ Account #{account.id} (#{account.name}): Captain disabled"
  end
  
  puts ""
  puts "Resetting pricing plan to community..."
  config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN')
  config.value = 'community'
  if config.save
    puts "  ✅ INSTALLATION_PRICING_PLAN set to 'community'"
  else
    puts "  ❌ Failed: #{config.errors.full_messages.join(', ')}"
  end
  
  puts ""
  puts "=== Summary ==="
  puts "Total accounts: #{Account.count}"
  puts "Installation plan: #{InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.value || 'community'}"
  puts ""
  puts "✅ Captain AI is now disabled!"
end

puts ""
puts "⚠️  IMPORTANT: Restarting containers to apply changes..."
RUBY_SCRIPT

# Step 2: Copy script to server and execute
echo ""
echo "Step 2: Deploying and executing on remote server..."
scp /tmp/captain_remote.rb root@msp.rhaps.net:/tmp/

ssh root@msp.rhaps.net 'bash -s' << 'ENDSSH'
set -e
cd /opt/chatwoot

WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)

if [ -z "$WEB_CONTAINER" ]; then
    echo "❌ Web container not running!"
    exit 1
fi

echo "Copying script to web container..."
docker cp /tmp/captain_remote.rb $WEB_CONTAINER:/tmp/

echo ""
echo "Executing Captain management script..."
docker exec $WEB_CONTAINER bundle exec rails runner /tmp/captain_remote.rb

echo ""
echo "Restarting services to apply changes..."
docker compose -f docker-compose.production.yml restart web worker

echo ""
echo "Waiting for services to restart..."
sleep 8

echo ""
echo "Verifying services are running..."
docker compose -f docker-compose.production.yml ps

echo ""
echo "Cleaning up temporary files..."
rm -f /tmp/captain_remote.rb
docker exec $WEB_CONTAINER rm -f /tmp/captain_remote.rb 2>/dev/null || true

echo ""
echo "✅ Operation completed successfully!"
ENDSSH

# Step 3: Cleanup local temp file
rm -f /tmp/captain_remote.rb

echo ""
echo "=== Deployment Complete ==="

if [[ "$ACTION" == "enable" ]]; then
    echo "✅ Captain feature flags enabled for all accounts"
    echo "✅ Enterprise pricing plan configured"
    echo "✅ Services restarted"
    echo ""
    echo "🎯 Next Steps:"
    echo "1. Navigate to: https://msp.rhaps.net/app/accounts/1/captain/assistants"
    echo "2. Captain AI should now be accessible without paywall"
else
    echo "✅ Captain feature flags disabled for all accounts"
    echo "✅ Pricing plan reset to community"
    echo "✅ Services restarted"
    echo ""
    echo "🎯 Result:"
    echo "1. Captain AI is now disabled"
    echo "2. Paywall will be shown if users try to access Captain features"
fi

echo ""
echo "Monitor logs if needed:"
echo "  ssh root@msp.rhaps.net \"cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs web -f\""