#!/bin/bash

# Quick AMB Channel Lookup Script
# Usage: ./script/list-amb-channels.sh
# Lists all Apple Messages for Business channels with their IDs

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

PRODUCTION_HOST="msp.rhaps.net"
PRODUCTION_USER="root"

echo -e "${CYAN}=====================================${NC}"
echo -e "${CYAN}  AMB Channels on Production${NC}"
echo -e "${CYAN}=====================================${NC}"
echo ""

ssh -o ConnectTimeout=10 "$PRODUCTION_USER@$PRODUCTION_HOST" "docker exec chatwoot-web rails runner \"
puts '=== Apple Messages for Business Channels ==='
puts ''

channels = Channel::AppleMessagesForBusiness.all

if channels.empty?
  puts 'No AMB channels configured.'
else
  puts 'Total AMB Channels: ' + channels.count.to_s
  puts ''

  channels.each do |c|
    inbox = c.inbox
    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    puts 'Inbox: ' + inbox.name
    puts '  Inbox ID: ' + inbox.id.to_s
    puts '  Channel ID: ' + c.id.to_s
    puts '  MSP ID: ' + (c.msp_id || 'Not set').to_s
    puts '  Business ID: ' + (c.business_id || 'Not set').to_s
    puts '  Webhook URL: ' + (c.webhook_url || 'Not set').to_s

    # Count recent messages
    msg_count = inbox.messages.where('created_at > ?', 24.hours.ago).count
    puts '  Messages (24h): ' + msg_count.to_s

    puts ''
  end

  puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  puts ''
  puts 'To diagnose a specific channel, run:'
  puts '  ./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> [HOURS]'
  puts ''
end
\""

echo ""
echo -e "${GREEN}✓ Channel listing complete${NC}"
echo ""
