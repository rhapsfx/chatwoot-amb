#!/bin/bash

# AMB Production Log Diagnostic Script
# Usage: ./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> [HOURS]
# Example: ./script/diagnose-amb-logs.sh af293df3-a37d-49e5-9437-c82e79899e7f a7565b9a-5abd-4277-a9e2-97f34e213243 6

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PRODUCTION_HOST="msp.rhaps.net"
PRODUCTION_USER="root"
COMPOSE_PATH="/opt/chatwoot"
COMPOSE_FILE="docker-compose.production.yml"

# Check parameters
if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${RED}Error: MSP ID and Business ID are required${NC}"
    echo ""
    echo "Usage: $0 <MSP_ID> <BUSINESS_ID> [HOURS]"
    echo ""
    echo "Example:"
    echo "  $0 af293df3-a37d-49e5-9437-c82e79899e7f a7565b9a-5abd-4277-a9e2-97f34e213243 6"
    echo ""
    exit 1
fi

MSP_ID="$1"
BUSINESS_ID="$2"
HOURS="${3:-6}"  # Default to 6 hours if not specified

echo -e "${CYAN}=====================================${NC}"
echo -e "${CYAN}  AMB Production Log Diagnostics${NC}"
echo -e "${CYAN}=====================================${NC}"
echo ""
echo -e "${BLUE}MSP ID:${NC} $MSP_ID"
echo -e "${BLUE}Business ID:${NC} $BUSINESS_ID"
echo -e "${BLUE}Time Range:${NC} Last $HOURS hours"
echo -e "${BLUE}Production Host:${NC} $PRODUCTION_HOST"
echo ""
echo -e "${YELLOW}Starting diagnostics...${NC}"
echo ""

# Function to run SSH command
run_ssh() {
    ssh -o ConnectTimeout=10 "$PRODUCTION_USER@$PRODUCTION_HOST" "$@"
}

# Function to print section header
print_section() {
    echo ""
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}========================================${NC}"
    echo ""
}

# Function to print subsection
print_subsection() {
    echo ""
    echo -e "${GREEN}>>> $1${NC}"
    echo ""
}

#=============================================================================
# 1. Find Inbox ID from MSP/Business ID
#=============================================================================
print_section "1. Channel Configuration Lookup"

print_subsection "Searching for channel with MSP ID and Business ID..."

CHANNEL_INFO=$(run_ssh "docker exec chatwoot-web rails runner \"
channel = Channel::AppleMessagesForBusiness.find_by(msp_id: '$MSP_ID', business_id: '$BUSINESS_ID')
if channel
  puts 'FOUND'
  puts channel.id
  puts channel.inbox.id
  puts channel.msp_id
  puts channel.business_id
  puts channel.webhook_url
else
  puts 'NOT_FOUND'
end
\"")

if echo "$CHANNEL_INFO" | grep -q "FOUND"; then
    CHANNEL_ID=$(echo "$CHANNEL_INFO" | sed -n '2p')
    INBOX_ID=$(echo "$CHANNEL_INFO" | sed -n '3p')
    FOUND_MSP_ID=$(echo "$CHANNEL_INFO" | sed -n '4p')
    FOUND_BUSINESS_ID=$(echo "$CHANNEL_INFO" | sed -n '5p')
    WEBHOOK_URL=$(echo "$CHANNEL_INFO" | sed -n '6p')

    echo -e "${GREEN}✓ Channel Found!${NC}"
    echo ""
    echo -e "  ${BLUE}Channel ID:${NC} $CHANNEL_ID"
    echo -e "  ${BLUE}Inbox ID:${NC} $INBOX_ID"
    echo -e "  ${BLUE}MSP ID:${NC} $FOUND_MSP_ID"
    echo -e "  ${BLUE}Business ID:${NC} $FOUND_BUSINESS_ID"
    echo -e "  ${BLUE}Webhook URL:${NC} $WEBHOOK_URL"
else
    echo -e "${RED}✗ Channel Not Found${NC}"
    echo ""
    echo "No AMB channel found with the specified MSP ID and Business ID."
    echo ""
    echo "Available channels:"
    run_ssh "docker exec chatwoot-web rails runner \"
Channel::AppleMessagesForBusiness.all.each do |c|
  puts '  Channel ID: ' + c.id.to_s + ', Inbox ID: ' + c.inbox.id.to_s
  puts '    MSP ID: ' + c.msp_id.to_s
  puts '    Business ID: ' + c.business_id.to_s
  puts ''
end
\""
    exit 1
fi

#=============================================================================
# 2. Recent Messages in Inbox
#=============================================================================
print_section "2. Recent Messages (Last $HOURS Hours)"

print_subsection "Querying database for messages in Inbox $INBOX_ID..."

run_ssh "docker exec chatwoot-web rails runner \"
inbox = Inbox.find($INBOX_ID)
messages = inbox.messages.where('created_at > ?', $HOURS.hours.ago).order(created_at: :desc)

puts '=== Message Summary ==='
puts 'Total messages: ' + messages.count.to_s
puts ''

if messages.any?
  puts '=== Recent Messages ==='
  messages.limit(20).each do |m|
    puts '[' + m.created_at.to_s + '] ' + m.message_type + ' - ' + m.sender_type.to_s
    puts '  ID: ' + m.id.to_s
    puts '  Content: ' + (m.content || 'N/A').to_s.truncate(100)
    if m.content_attributes.present?
      puts '  Content Attributes: ' + m.content_attributes.inspect
    end
    puts '  Status: ' + m.status.to_s
    puts '  ---'
  end
else
  puts 'No messages found in the last $HOURS hours.'
end
\""

#=============================================================================
# 3. Recent Conversations
#=============================================================================
print_section "3. Recent Conversations"

print_subsection "Checking conversation activity..."

run_ssh "docker exec chatwoot-web rails runner \"
inbox = Inbox.find($INBOX_ID)
conversations = inbox.conversations.where('updated_at > ?', $HOURS.hours.ago).order(updated_at: :desc).limit(10)

puts '=== Conversation Summary ==='
puts 'Total active conversations: ' + conversations.count.to_s
puts ''

if conversations.any?
  conversations.each do |conv|
    puts 'Conversation #' + conv.display_id.to_s
    puts '  ID: ' + conv.id.to_s
    puts '  Status: ' + conv.status
    puts '  Contact: ' + (conv.contact&.name || 'Unknown').to_s
    puts '  Updated: ' + conv.updated_at.to_s
    puts '  Message Count: ' + conv.messages.count.to_s
    last_msg = conv.messages.last
    if last_msg
      puts '  Last Message: ' + last_msg.created_at.to_s + ' (' + last_msg.message_type + ')'
    end
    puts '  ---'
  end
else
  puts 'No active conversations in the last $HOURS hours.'
end
\""

#=============================================================================
# 4. Docker Logs - Web Container
#=============================================================================
print_section "4. Docker Logs - Web Container"

print_subsection "Searching web logs for inbox $INBOX_ID, MSP ID, and Business ID..."

WEB_LOGS=$(run_ssh "cd $COMPOSE_PATH && docker compose -f $COMPOSE_FILE logs web --since ${HOURS}h 2>&1 | grep -iE '(inbox.*$INBOX_ID|$MSP_ID|$BUSINESS_ID|apple.*message)' | tail -100" 2>&1 || echo "No matching logs found")

if [ "$WEB_LOGS" != "No matching logs found" ] && [ -n "$WEB_LOGS" ]; then
    echo "$WEB_LOGS"
else
    echo -e "${YELLOW}No web logs found matching the criteria.${NC}"
fi

#=============================================================================
# 5. Docker Logs - Worker Container
#=============================================================================
print_section "5. Docker Logs - Worker Container"

print_subsection "Searching worker logs for background job processing..."

WORKER_LOGS=$(run_ssh "cd $COMPOSE_PATH && docker compose -f $COMPOSE_FILE logs worker --since ${HOURS}h 2>&1 | grep -iE '(inbox.*$INBOX_ID|$MSP_ID|$BUSINESS_ID|apple.*message)' | grep -vE '(FetchImapEmailInboxesJob|FetchSmtpEmailInboxesJob|EmailJob)' | tail -100" 2>&1 || echo "No matching logs found")

if [ "$WORKER_LOGS" != "No matching logs found" ] && [ -n "$WORKER_LOGS" ]; then
    echo "$WORKER_LOGS"
else
    echo -e "${YELLOW}No worker logs found matching the criteria.${NC}"
fi

#=============================================================================
# 6. Rails Production Log
#=============================================================================
print_section "6. Rails Production Log"

print_subsection "Searching production.log for AMB activity..."

RAILS_LOGS=$(run_ssh "docker exec chatwoot-web bash -c 'tail -2000 /app/log/production.log | grep -iE \"(inbox.*$INBOX_ID|$MSP_ID|$BUSINESS_ID|apple.*message|webhook)\"'" 2>&1 || echo "No matching logs found")

if [ "$RAILS_LOGS" != "No matching logs found" ] && [ -n "$RAILS_LOGS" ]; then
    echo "$RAILS_LOGS" | tail -100
else
    echo -e "${YELLOW}No Rails logs found matching the criteria.${NC}"
fi

#=============================================================================
# 7. Error Logs
#=============================================================================
print_section "7. Error & Exception Logs"

print_subsection "Searching for errors related to this inbox..."

ERROR_LOGS=$(run_ssh "cd $COMPOSE_PATH && docker compose -f $COMPOSE_FILE logs web worker --since ${HOURS}h 2>&1 | grep -iE '(error|exception|failed|fatal)' | grep -iE '(inbox.*$INBOX_ID|$MSP_ID|$BUSINESS_ID|apple)' | tail -50" 2>&1 || echo "No errors found")

if [ "$ERROR_LOGS" != "No errors found" ] && [ -n "$ERROR_LOGS" ]; then
    echo -e "${RED}$ERROR_LOGS${NC}"
else
    echo -e "${GREEN}✓ No errors found matching the criteria.${NC}"
fi

#=============================================================================
# 8. Webhook Activity
#=============================================================================
print_section "8. Webhook Activity"

print_subsection "Searching for webhook requests..."

WEBHOOK_LOGS=$(run_ssh "cd $COMPOSE_PATH && docker compose -f $COMPOSE_FILE logs web --since ${HOURS}h 2>&1 | grep -iE '(webhook|POST.*apple)' | grep -iE '($INBOX_ID|$MSP_ID|$BUSINESS_ID)' | tail -50" 2>&1 || echo "No webhook activity found")

if [ "$WEBHOOK_LOGS" != "No webhook activity found" ] && [ -n "$WEBHOOK_LOGS" ]; then
    echo "$WEBHOOK_LOGS"
else
    echo -e "${YELLOW}No webhook activity found matching the criteria.${NC}"
fi

#=============================================================================
# 9. Service Status Check
#=============================================================================
print_section "9. Service Status"

print_subsection "Checking Docker container status..."

run_ssh "cd $COMPOSE_PATH && docker compose -f $COMPOSE_FILE ps" 2>&1

#=============================================================================
# 10. Summary
#=============================================================================
print_section "10. Diagnostic Summary"

echo -e "${CYAN}Diagnostic Report Complete${NC}"
echo ""
echo -e "${BLUE}Channel Details:${NC}"
echo -e "  Inbox ID: $INBOX_ID"
echo -e "  MSP ID: $MSP_ID"
echo -e "  Business ID: $BUSINESS_ID"
echo ""
echo -e "${BLUE}Time Range:${NC} Last $HOURS hours"
echo ""
echo -e "${GREEN}✓ Diagnostics completed successfully${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Review message activity in section 2"
echo "  2. Check for errors in section 7"
echo "  3. Verify webhook activity in section 8"
echo "  4. Check service status in section 9"
echo ""
echo -e "${CYAN}For more detailed logs, run:${NC}"
echo "  ssh $PRODUCTION_USER@$PRODUCTION_HOST 'cd $COMPOSE_PATH && docker compose -f $COMPOSE_FILE logs web -f'"
echo ""
