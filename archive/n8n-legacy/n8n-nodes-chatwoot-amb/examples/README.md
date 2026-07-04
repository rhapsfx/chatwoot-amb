# Example Workflows

This directory contains example n8n workflows demonstrating how to use the Chatwoot AMB nodes.

## Available Examples

### 1. Simple Quick Reply Bot

**File:** `quick-reply-bot.json`

A simple bot that responds to customer messages with quick reply options.

**Flow:**
1. Receive webhook from Chatwoot
2. Filter incoming messages
3. Send quick reply buttons
4. Handle user selection

**Use Case:** Feedback collection, yes/no confirmations

---

### 2. Appointment Booking Bot

**File:** `appointment-booking-bot.json`

A complete appointment booking flow with time picker.

**Flow:**
1. Customer requests appointment
2. Check available slots (mock)
3. Generate time slots dynamically
4. Send time picker
5. Confirm booking

**Use Case:** Service businesses, medical appointments

---

### 3. Product Catalog with List Picker

**File:** `product-catalog-bot.json`

Display products using list picker with images.

**Flow:**
1. Customer browses products
2. Fetch product data (mock)
3. Format list picker with images
4. Send product list
5. Handle selection and show details

**Use Case:** E-commerce, service catalogs

---

### 4. Multi-Step Form Flow

**File:** `contact-form-bot.json`

Collect customer information using multi-field forms.

**Flow:**
1. Greet customer
2. Send contact form
3. Receive form submission
4. Process and store data
5. Send confirmation

**Use Case:** Lead generation, registration

---

### 5. Complete Checkout Flow

**File:** `checkout-flow-bot.json`

End-to-end checkout with Apple Pay.

**Flow:**
1. Product selection (list picker)
2. Time selection (time picker)
3. Payment (Apple Pay)
4. Confirmation message

**Use Case:** Booking services with payment

---

## Importing Examples

### Via n8n UI

1. In n8n, click **Workflows → Import from File**
2. Select the example JSON file
3. Update credentials (Chatwoot Bot API token)
4. Update Chatwoot URL and Account ID
5. Activate workflow

### Via CLI

```bash
n8n import:workflow --input=examples/quick-reply-bot.json
```

## Customizing Examples

All examples use placeholder values that you'll need to update:

- **Chatwoot URL**: Change from `https://app.chatwoot.com` to your instance
- **Account ID**: Update to your account ID
- **Template IDs**: Update to your actual template IDs
- **API Tokens**: Configure credentials with your bot token

## Creating Your Own

Use these examples as starting points:

1. **Copy an example** that matches your use case
2. **Modify the logic** to fit your needs
3. **Add your business logic** (API calls, database queries, etc.)
4. **Test thoroughly** before deploying

## Testing Examples

### With Chatwoot Webhook

1. Set up webhook trigger in n8n
2. Configure bot in Chatwoot with webhook URL
3. Test in Chatwoot UI or Apple Messages app

### Manual Testing

Use the **Manual Trigger** node to test without Chatwoot:

```json
{
  "conversation": {
    "id": 123
  },
  "content": "test message",
  "message_type": "incoming"
}
```

## Example Data Structures

### Webhook Payload (from Chatwoot)

```json
{
  "event": "message_created",
  "id": 12345,
  "content": "Hello bot!",
  "message_type": "incoming",
  "conversation": {
    "id": 123,
    "inbox_id": 5
  },
  "account": {
    "id": 1
  }
}
```

### List Picker Parameters

```json
{
  "title": "Select Service",
  "sections": [
    {
      "title": "Services",
      "items": [
        {
          "identifier": "massage",
          "title": "Massage",
          "subtitle": "60min - $120",
          "image_identifier": "img1"
        }
      ]
    }
  ],
  "images": [
    {
      "identifier": "img1",
      "data": "data:image/png;base64,..."
    }
  ]
}
```

### Time Picker Parameters

```json
{
  "title": "Book Appointment",
  "available_slots": [
    {
      "identifier": "2025-11-03_14",
      "startTime": "2025-11-03T14:00+0000",
      "duration": 3600
    }
  ]
}
```

## Common Patterns

### Dynamic Slot Generation

```javascript
// Function node
const slots = [];
const now = new Date();

for (let day = 1; day <= 7; day++) {
  const date = new Date(now);
  date.setDate(date.getDate() + day);

  [9, 14].forEach(hour => {
    date.setHours(hour, 0, 0, 0);
    slots.push({
      identifier: `${date.toISOString().split('T')[0]}_${hour}`,
      startTime: date.toISOString().replace(/\.\d{3}Z$/, '+0000'),
      duration: 3600
    });
  });
}

return { json: { slots } };
```

### Conversation State Management

```javascript
// Store state
$node["Webhook"].context.set('conversationState', {
  step: 'awaiting_selection',
  data: { /* ... */ }
});

// Retrieve state
const state = $node["Webhook"].context.get('conversationState');
```

### Error Handling

```javascript
// Function node
try {
  // Your logic
  return { json: { success: true } };
} catch (error) {
  return {
    json: {
      error: true,
      message: error.message,
      fallback: "Sorry, something went wrong."
    }
  };
}
```

## Need Help?

- Check the main [README](../README.md)
- Open an [issue](https://github.com/chatwoot/n8n-nodes-chatwoot-amb/issues)
- Join [discussions](https://github.com/chatwoot/n8n-nodes-chatwoot-amb/discussions)
