# n8n Quick Reply Response Routing Example

## Overview

This guide shows how to extract quick reply responses in n8n and route different flows based on the customer's selection.

## Understanding Quick Reply Events

### Two Separate Webhook Events

When working with Quick Replies, you'll receive **TWO different webhook events**:

#### Event 1: Bot Sends Quick Reply (OUTGOING) - Ignore This!

```json
{
  "event": "message_created",
  "message_type": "outgoing",  ← Bot sending the quick reply
  "sender_type": "agent_bot",
  "sender_id": 3,
  "content_type": "apple_quick_reply",
  "content_attributes": {
    "summary_text": "Please select your region:",
    "items": [
      { "identifier": "c7ea9e7d-...", "title": "Americas" },
      { "identifier": "cd436f5e-...", "title": "EMEA" },
      { "identifier": "40711c79-...", "title": "APAC" }
    ]
  }
}
```

**Action**: Skip this event in your n8n workflow (it's just confirmation the bot sent the message).

#### Event 2: Customer Responds (INCOMING) - Process This!

When a customer taps a quick reply button, the webhook receives:

```json
{
  "event": "message_created",
  "message_type": "incoming",  ← Customer responding!
  "sender_type": "contact",  ← The customer (not the bot)
  "content_type": "text",
  "content": "Americas",  ← The title of the button they tapped
  "content_attributes": {
    "in_reply_to": "MESSAGE_ID",
    "items": [
      {
        "identifier": "c7ea9e7d-55be-48dc-bfc3-2e7275bb198d",  ← Extract this!
        "title": "Americas"
      }
    ]
  },
  "conversation": {
    "id": 123,
    "inbox_id": 5
  },
  "sender": {
    "id": 456,
    "name": "Customer Name",
    "type": "contact"
  }
}
```

**Action**: Extract `content_attributes.items[0].identifier` to route your workflow.

## n8n Workflow Setup

### Node 1: Webhook Trigger
- **Name**: Chatwoot Events
- **Path**: `chatwoot`
- **Method**: POST
- **Respond**: Using 'Respond to Webhook' node

### Node 2: Extract Quick Reply Response (Function)

**IMPORTANT**: Only process INCOMING messages (customer responses), not outgoing messages from the bot.

```javascript
// Only process INCOMING messages (customer responses)
// Skip outgoing messages (when bot sends quick reply)
if ($json.message_type !== 'incoming') {
  return {
    json: {
      shouldRoute: false,
      reason: 'Outgoing message - bot sent this'
    }
  };
}

const event = $json.event;
const contentAttributes = $json.content_attributes || {};

// Check if this is a quick reply response
// When customer taps a button, items array contains their selection
if (event === 'message_created' &&
    contentAttributes.items &&
    contentAttributes.items.length > 0) {

  // Extract the selected item (customer's choice)
  const selectedItem = contentAttributes.items[0];
  const selectedIdentifier = selectedItem.identifier;
  const selectedTitle = selectedItem.title;

  return {
    json: {
      conversationId: $json.conversation.id,
      accountId: $json.account?.id,
      inboxId: $json.inbox?.id,
      responseType: 'quick_reply',
      selectedIdentifier: selectedIdentifier,
      selectedTitle: selectedTitle,
      rawContent: $json.content,
      shouldRoute: true
    }
  };
}

// Regular text message (not a quick reply response)
return {
  json: {
    conversationId: $json.conversation?.id,
    responseType: 'text',
    content: $json.content,
    shouldRoute: false
  }
};
```

### Node 3: Check if Quick Reply (IF Node)
- **Condition**: `{{ $json.shouldRoute }}` equals `true`
- **True Branch**: Continue to Switch node
- **False Branch**: Handle as regular message or ignore

### Node 4: Route by Selection (Switch Node)
- **Mode**: Rules
- **Value to Route On**: `{{ $json.selectedIdentifier }}`
- **Rules**:
  - **Output 0** (Yes Response):
    - **Condition**: equals
    - **Value**: `yes`
  - **Output 1** (No Response):
    - **Condition**: equals
    - **Value**: `no`
  - **Output 2** (Somewhat Response):
    - **Condition**: equals
    - **Value**: `somewhat`
  - **Fallback Output**: Unrecognized response

### Node 5a: Handle "Yes" Flow (HTTP Request)
- **Method**: POST
- **URL**: `http://your-chatwoot.com/api/v1/accounts/1/bot_templates/send_message`
- **Authentication**: Header Auth
  - **Header Name**: `api_access_token`
  - **Header Value**: `YOUR_BOT_TOKEN`
- **Body**:
```json
{
  "conversation_id": {{ $json.conversationId }},
  "template_id": 50,
  "parameters": {
    "message": "Thank you for your positive feedback! 🎉 We're glad you're satisfied with our service."
  }
}
```

### Node 5b: Handle "No" Flow (Multi-Step)

**Step 1: Send Apology (HTTP Request)**
```json
{
  "conversation_id": {{ $json.conversationId }},
  "template_id": 51,
  "parameters": {
    "message": "We're sorry to hear that you're not satisfied. An agent will assist you shortly to address your concerns."
  }
}
```

**Step 2: Assign to Agent (HTTP Request)**
- **Method**: POST
- **URL**: `http://your-chatwoot.com/api/v1/accounts/1/conversations/{{ $json.conversationId }}/assignments`
- **Body**:
```json
{
  "assignee_id": 5,
  "team_id": 2
}
```

**Step 3: Set Priority (HTTP Request)**
- **Method**: PATCH
- **URL**: `http://your-chatwoot.com/api/v1/accounts/1/conversations/{{ $json.conversationId }}`
- **Body**:
```json
{
  "priority": "urgent",
  "custom_attributes": {
    "feedback": "negative",
    "needs_attention": true
  }
}
```

### Node 5c: Handle "Somewhat" Flow (HTTP Request)
```json
{
  "conversation_id": {{ $json.conversationId }},
  "template_id": 52,
  "parameters": {
    "summary_text": "What could we improve?",
    "items": [
      { "identifier": "speed", "title": "Faster service" },
      { "identifier": "quality", "title": "Better quality" },
      { "identifier": "price", "title": "Lower prices" },
      { "identifier": "other", "title": "Something else" }
    ]
  }
}
```

### Node 6: Respond to Webhook
- **Response Code**: 200
- **Response Body**: `{ "status": "processed" }`

## Complete Flow Diagram

```
Webhook (Chatwoot Event)
    ↓
Extract Quick Reply (Function)
    ↓
Is Quick Reply Response? (IF)
    ↓ Yes
Route by Identifier (Switch)
    ├─ yes → Send Thank You
    ├─ no → Send Apology + Assign Agent + Set Priority
    └─ somewhat → Send Follow-up Survey
```

## Testing the Workflow

### 1. Test Quick Reply Extraction

Send this test payload to your webhook:

```bash
curl -X POST http://localhost:5678/webhook/chatwoot \
  -H "Content-Type: application/json" \
  -d '{
    "event": "message_created",
    "message_type": "incoming",
    "content_type": "text",
    "content": "Yes, very satisfied!",
    "content_attributes": {
      "items": [
        {
          "identifier": "yes",
          "title": "Yes, very satisfied!"
        }
      ]
    },
    "conversation": {
      "id": 123,
      "inbox_id": 5
    },
    "account": {
      "id": 1
    }
  }'
```

Expected output from Extract Function:
```json
{
  "conversationId": 123,
  "accountId": 1,
  "inboxId": 5,
  "responseType": "quick_reply",
  "selectedIdentifier": "yes",
  "selectedTitle": "Yes, very satisfied!",
  "shouldRoute": true
}
```

### 2. Test Each Route

Test "yes" response:
```javascript
// Function output
{
  "selectedIdentifier": "yes"
}
// Should route to Output 0 (Thank You flow)
```

Test "no" response:
```javascript
// Function output
{
  "selectedIdentifier": "no"
}
// Should route to Output 1 (Apology + Agent Assignment)
```

## Advanced: Multi-Level Routing

For complex workflows with multiple quick reply steps:

```javascript
// Store conversation state
const state = $execution.context.get('conversationState') || {};

// Update state based on response
if ($json.selectedIdentifier === 'somewhat') {
  state.awaitingFeedbackDetails = true;
  state.initialResponse = 'somewhat';
} else if (state.awaitingFeedbackDetails && $json.selectedIdentifier) {
  state.feedbackCategory = $json.selectedIdentifier;
  state.awaitingFeedbackDetails = false;
}

// Save state
$execution.context.set('conversationState', state);

return { json: { ...state, ...$json } };
```

## Common Issues

### Issue 1: Switch Node Not Routing Correctly

**Problem**: All responses go to fallback output.

**Solution**: Verify the expression in Switch node is exactly:
```
{{ $json.selectedIdentifier }}
```

### Issue 2: content_attributes is undefined

**Problem**: Function node throws error accessing `content_attributes.items`.

**Solution**: Use optional chaining:
```javascript
const contentAttrs = $json.content_attributes || {};
const items = contentAttrs.items || [];
```

### Issue 3: Regular Messages Trigger Quick Reply Flow

**Problem**: Text messages are incorrectly processed as quick replies.

**Solution**: Add proper validation in Function node:
```javascript
if (contentAttrs.items?.length > 0 && contentAttrs.items[0].identifier) {
  // This is a quick reply
} else {
  // This is a regular message
}
```

## Best Practices

1. **Always validate**: Check if `content_attributes.items` exists before accessing
2. **Use descriptive identifiers**: Use clear identifiers like `confirm_booking` instead of `btn1`
3. **Log for debugging**: Add console.log in Function nodes during development
4. **Handle fallback**: Always have a default route for unexpected responses
5. **Store context**: Use execution context to maintain multi-step conversation state

## Example: Complete Satisfaction Survey Workflow

```
Send Initial Quick Reply:
  "How satisfied are you?"
  - yes (very satisfied)
  - no (not satisfied)
  - somewhat (somewhat satisfied)
    ↓
Route Based on Response:
  ├─ "yes" → "Great! Would you recommend us?"
  │           - definitely / maybe / no
  ├─ "no" → Assign to agent immediately
  └─ "somewhat" → "What could we improve?"
                   - speed / quality / price / other
                      ↓
                   Send to feedback database
                   + Send thank you
```

---

**Additional Resources**:
- [n8n Switch Node Documentation](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.switch/)
- [Chatwoot Bot Integration Guide](./n8n-bot-integration-guide.md)
- [Apple Messages Quick Reply Spec](https://developer.apple.com/documentation/businesschatapi/messages_sent/sending_quick_reply_messages)
