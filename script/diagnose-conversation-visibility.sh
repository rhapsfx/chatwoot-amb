#!/bin/bash

# Conversation Visibility Diagnostic Script
# Usage: ./script/diagnose-conversation-visibility.sh <INBOX_ID>
# Example: ./script/diagnose-conversation-visibility.sh 11

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

# Check parameters
if [ -z "$1" ]; then
    echo -e "${RED}Error: Inbox ID is required${NC}"
    echo ""
    echo "Usage: $0 <INBOX_ID>"
    echo ""
    echo "Example:"
    echo "  $0 11"
    echo ""
    exit 1
fi

INBOX_ID="$1"

echo -e "${CYAN}=====================================${NC}"
echo -e "${CYAN}  Conversation Visibility Diagnostics${NC}"
echo -e "${CYAN}=====================================${NC}"
echo ""
echo -e "${BLUE}Inbox ID:${NC} $INBOX_ID"
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

#=============================================================================
# 1. Inbox Information
#=============================================================================
print_section "1. Inbox Information"

run_ssh "docker exec chatwoot-web rails runner \"
inbox = Inbox.find($INBOX_ID)
puts 'Inbox Name: ' + inbox.name
puts 'Channel Type: ' + inbox.channel_type
puts 'Account: ' + inbox.account.name + ' (ID: ' + inbox.account.id.to_s + ')'
puts 'Greeting Message: ' + (inbox.greeting_message || 'None').to_s
puts 'Enabled: ' + inbox.greeting_enabled.to_s
\""

#=============================================================================
# 2. Recent Conversations
#=============================================================================
print_section "2. Recent Conversations (Last 24 Hours)"

run_ssh "docker exec chatwoot-web rails runner \"
inbox = Inbox.find($INBOX_ID)
conversations = inbox.conversations.where('created_at > ?', 24.hours.ago).order(created_at: :desc).limit(10)

puts 'Total conversations: ' + conversations.count.to_s
puts ''

if conversations.any?
  conversations.each do |conv|
    puts 'Conversation #' + conv.display_id.to_s + ' (ID: ' + conv.id.to_s + ')'
    puts '  Status: ' + conv.status
    puts '  Created: ' + conv.created_at.to_s
    puts '  Messages: ' + conv.messages.count.to_s
    puts '  Contact: ' + (conv.contact&.name || 'Unknown')
    puts '  Assignee: ' + (conv.assignee&.name || 'Unassigned')
    puts '  ---'
  end
else
  puts 'No conversations found in the last 24 hours.'
end
\""

#=============================================================================
# 3. Recent Messages
#=============================================================================
print_section "3. Recent Messages (Last 1 Hour)"

run_ssh "docker exec chatwoot-web rails runner \"
inbox = Inbox.find($INBOX_ID)
messages = inbox.messages.where('created_at > ?', 1.hour.ago).order(created_at: :desc).limit(10)

puts 'Total messages: ' + messages.count.to_s
puts ''

if messages.any?
  messages.each do |msg|
    puts '[' + msg.created_at.to_s + '] ' + msg.message_type
    puts '  Content: ' + (msg.content || 'N/A').to_s.truncate(100)
    puts '  Conversation ID: ' + msg.conversation_id.to_s
    puts '  Sender: ' + msg.sender_type.to_s
    puts '  ---'
  end
else
  puts 'No messages found in the last hour.'
end
\""

#=============================================================================
# 4. Recent Contacts
#=============================================================================
print_section "4. Recent Contacts (Last 24 Hours)"

run_ssh "docker exec chatwoot-web rails runner \"
contacts = Contact.joins(:contact_inboxes)
  .where(contact_inboxes: { inbox_id: $INBOX_ID })
  .where('contacts.created_at > ?', 24.hours.ago)
  .order('contacts.created_at DESC')
  .limit(5)

puts 'Total contacts: ' + contacts.count.to_s
puts ''

if contacts.any?
  contacts.each do |contact|
    puts 'Name: ' + (contact.name || 'Unknown')
    puts '  Email: ' + (contact.email || 'N/A')
    puts '  Phone: ' + (contact.phone_number || 'N/A')
    puts '  Created: ' + contact.created_at.to_s
    puts '  ---'
  end
else
  puts 'No contacts created in the last 24 hours.'
end
\""

#=============================================================================
# 5. All Recent Conversations (Any Inbox)
#=============================================================================
print_section "5. All Recent Conversations (Last 1 Hour - Any Inbox)"

run_ssh "docker exec chatwoot-web rails runner \"
conversations = Conversation.where('created_at > ?', 1.hour.ago).order(created_at: :desc).limit(10)

puts 'Total conversations: ' + conversations.count.to_s
puts ''

if conversations.any?
  conversations.each do |conv|
    puts 'Inbox: ' + conv.inbox.name + ' (ID: ' + conv.inbox_id.to_s + ')'
    puts '  Conversation #' + conv.display_id.to_s
    puts '  Status: ' + conv.status
    puts '  Messages: ' + conv.messages.count.to_s
    puts '  ---'
  end
else
  puts 'No conversations found in the last hour across all inboxes.'
end
\""

#=============================================================================
# 6. Webhook Logs
#=============================================================================
print_section "6. Recent Webhook Activity"

echo -e "${YELLOW}Checking web container logs for inbox $INBOX_ID...${NC}"
run_ssh "docker logs chatwoot-web --since 1h 2>&1 | grep -i 'inbox.*$INBOX_ID\|apple.*message' | tail -30" || echo "No webhook logs found"

#=============================================================================
# 7. Summary
#=============================================================================
print_section "7. Diagnostic Summary"

echo -e "${CYAN}Diagnostic Report Complete${NC}"
echo ""
echo -e "${BLUE}Inbox ID:${NC} $INBOX_ID"
echo ""
echo -e "${GREEN}✓ Diagnostics completed successfully${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Review conversation count in section 2"
echo "  2. Check message activity in section 3"
echo "  3. Verify contacts were created in section 4"
echo "  4. Check if conversations exist in other inboxes (section 5)"
echo "  5. Review webhook logs in section 6"
echo ""