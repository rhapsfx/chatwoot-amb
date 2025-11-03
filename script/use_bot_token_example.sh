#!/bin/bash
# Example: Using Bot Token to send templates via BOT API

# Bot credentials (get these from create_agent_bot.sh output)
BOT_TOKEN="Jm3ndoFLQM7BRm9RnAJ59hEo"
ACCOUNT_ID=1
API_BASE_URL="http://localhost:10750"

# Message details
CONVERSATION_ID=15
TEMPLATE_ID=57

echo "Sending template message as bot..."
curl -X POST "$API_BASE_URL/api/v1/accounts/$ACCOUNT_ID/bot_templates/send_message" \
  -H "api_access_token: $BOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": '$CONVERSATION_ID',
    "template_id": '$TEMPLATE_ID',
    "parameters": {}
  }' | jq '.'

echo ""
echo "✅ Template sent! The message should appear in purple (bot color) on the right side."
