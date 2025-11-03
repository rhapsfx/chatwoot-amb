#!/bin/bash
# Script to create an AgentBot and get its access token

# Replace these with your values
ACCOUNT_ID=1
API_BASE_URL="http://localhost:10750"
USER_API_KEY="oGapyM2vNQKvrAasnRntas1x"

# Create the bot
echo "Creating AgentBot..."
RESPONSE=$(curl -X POST "$API_BASE_URL/api/v1/accounts/$ACCOUNT_ID/agent_bots" \
  -H "api_access_token: $USER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Template Bot",
    "description": "Bot for sending templates via API",
    "bot_type": "webhook"
  }')

echo "$RESPONSE" | jq '.'

# Extract the bot ID and access token
BOT_ID=$(echo "$RESPONSE" | jq -r '.id')
BOT_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token.token')

echo ""
echo "✅ Bot created successfully!"
echo "Bot ID: $BOT_ID"
echo "Bot Access Token: $BOT_TOKEN"
echo ""
echo "Use this token in your API requests:"
echo "Authorization: Bearer $BOT_TOKEN"
echo "# OR"
echo "api_access_token: $BOT_TOKEN"
