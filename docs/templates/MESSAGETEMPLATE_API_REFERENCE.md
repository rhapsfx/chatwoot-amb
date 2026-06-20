# MessageTemplate API Reference

## Overview

This document provides quick API reference for the MessageTemplate system used for Apple Messages for Business and other channels.

---

## Endpoints

### List Templates
```
GET /api/v1/accounts/:account_id/templates
```

**Query Parameters**:
- `category` - Filter by category (general, payment, scheduling, support, marketing, feedback, notification, confirmation, sales)
- `status` - Filter by status (active, draft, deprecated) - Default: active + draft
- `channel` - Filter by channel (apple_messages_for_business, whatsapp, web_widget)
- `search` - Search in name, description, tags
- `page` - Page number (default: 1)
- `per_page` - Items per page (default: 20, max: 100)

**Response**:
```json
{
  "templates": [
    {
      "id": 123,
      "name": "Order Confirmation",
      "category": "notification",
      "description": "...",
      "supportedChannels": ["apple_messages_for_business"],
      "tags": ["wismo", "acoustic-house"],
      "useCases": ["agent_ui"],
      "parameters": { "order_id": { "type": "string", "required": true } },
      "status": "active",
      "version": 1,
      "metadata": {},
      "content": {...},
      "createdAt": "2025-11-07T10:00:00Z",
      "updatedAt": "2025-11-07T10:00:00Z"
    }
  ],
  "total": 150,
  "page": 1,
  "perPage": 20
}
```

---

### Get Template
```
GET /api/v1/accounts/:account_id/templates/:id
```

**Response**:
```json
{
  "id": 123,
  "name": "Order Confirmation",
  "category": "notification",
  "description": "Send order confirmation with status tracking",
  "supportedChannels": ["apple_messages_for_business"],
  "tags": ["wismo", "acoustic-house"],
  "useCases": ["agent_ui"],
  "parameters": {
    "order_id": { "type": "string", "required": true, "description": "Order ID" },
    "customer_name": { "type": "string", "required": true }
  },
  "status": "active",
  "version": 1,
  "metadata": {
    "apple_message_content": {
      "content_type": "apple_list_picker",
      "content_attributes": {
        "sections": [{
          "items": [{ "title": "View Order", "identifier": "view_order" }]
        }]
      }
    }
  },
  "content": {...},
  "contentBlocks": [
    {
      "id": 456,
      "blockType": "list_picker",
      "properties": {...},
      "conditions": {},
      "orderIndex": 0
    }
  ],
  "channelMappings": [
    {
      "id": 789,
      "channelType": "apple_messages_for_business",
      "contentType": "apple_list_picker",
      "fieldMappings": {}
    }
  ],
  "createdAt": "2025-11-07T10:00:00Z",
  "updatedAt": "2025-11-07T10:00:00Z"
}
```

---

### Create Template
```
POST /api/v1/accounts/:account_id/templates
```

**Request Body**:
```json
{
  "template": {
    "name": "Order Confirmation",
    "category": "notification",
    "description": "Send order confirmation",
    "status": "active",
    "version": 1,
    "supportedChannels": ["apple_messages_for_business"],
    "tags": ["wismo"],
    "useCases": ["agent_ui"],
    "parameters": {
      "order_id": {
        "type": "string",
        "required": true,
        "description": "Order ID",
        "example": "ORD-123456"
      }
    },
    "metadata": {
      "apple_message_content": {...}
    }
  },
  "contentBlocks": [
    {
      "blockType": "time_picker",
      "properties": {
        "title": "Select appointment time",
        "event": {
          "title": "Appointment",
          "timeslots": [...]
        }
      },
      "conditions": {
        "if": "{{order_type}} == 'appointment'"
      },
      "orderIndex": 0
    }
  ],
  "channelMappings": [
    {
      "channelType": "apple_messages_for_business",
      "contentType": "apple_time_picker",
      "fieldMappings": {}
    }
  ]
}
```

**Response**: Same as GET Template (with 201 Created status)

---

### Update Template
```
PUT /api/v1/accounts/:account_id/templates/:id
```

**Request Body**: Same as Create Template (partial updates allowed)

**Response**: Updated template (200 OK)

---

### Delete Template
```
DELETE /api/v1/accounts/:account_id/templates/:id
```

**Note**: Performs soft delete (sets status to 'deprecated')

**Response**:
```json
{
  "message": "Template deprecated successfully"
}
```

---

### Render Template
```
POST /api/v1/accounts/:account_id/templates/:id/render
```

**Request Body**:
```json
{
  "parameters": {
    "order_id": "ORD-123456",
    "customer_name": "John Doe"
  },
  "channelType": "apple_messages_for_business"
}
```

**Response**:
```json
{
  "templateId": 123,
  "templateName": "Order Confirmation",
  "contentType": "apple_time_picker",
  "content": "Select appointment time",
  "contentAttributes": {
    "event": {
      "title": "Appointment",
      "identifier": "apt-123",
      "timeslots": [
        {
          "identifier": "slot-1",
          "startTime": "2025-11-07T14:00+0000",
          "duration": 3600
        }
      ]
    },
    "receivedTitle": "Select time",
    "replyTitle": "Time selected: ${event.title}",
    "images": [
      {
        "identifier": "img_123",
        "data": "base64encodeddata...",
        "description": "Calendar icon"
      }
    ]
  },
  "webhookData": {
    "templateId": 123,
    "templateName": "Order Confirmation",
    "templateCategory": "notification",
    "parametersUsed": {
      "order_id": "ORD-123456",
      "customer_name": "John Doe"
    },
    "channelType": "apple_messages_for_business",
    "timestamp": "2025-11-07T10:00:00Z"
  }
}
```

---

### Create Template from Apple Message
```
POST /api/v1/accounts/:account_id/templates/from_apple_message
```

**Request Body**:
```json
{
  "messageType": "time_picker",
  "messageData": {
    "event": {
      "title": "Book Appointment",
      "timeslots": [...]
    },
    "receivedTitle": "Select time",
    "receivedImageIdentifier": "img_123"
  },
  "templateName": "Appointment Booking",
  "category": "scheduling",
  "description": "Let customers book appointment",
  "tags": ["appointments", "scheduling"]
}
```

**Response**: New template (201 Created)

---

## Content Types

### apple_time_picker
```json
{
  "contentType": "apple_time_picker",
  "contentAttributes": {
    "event": {
      "title": "string",
      "description": "string (optional)",
      "identifier": "string (UUID)",
      "timeslots": [
        {
          "identifier": "string",
          "startTime": "2025-11-07T14:00+0000",
          "duration": 3600
        }
      ],
      "timezoneOffset": 28800,
      "imageIdentifier": "string (optional)"
    },
    "receivedTitle": "string",
    "receivedSubtitle": "string (optional)",
    "receivedImageIdentifier": "string (optional)",
    "receivedStyle": "large|small (default: large)",
    "replyTitle": "string",
    "replySubtitle": "string (optional)",
    "replyImageIdentifier": "string (optional - auto-fallback to received)",
    "replyStyle": "large|small (default: large)",
    "images": [
      { "identifier": "string", "data": "base64", "description": "string" }
    ]
  }
}
```

### apple_list_picker
```json
{
  "contentType": "apple_list_picker",
  "contentAttributes": {
    "sections": [
      {
        "title": "string",
        "multipleSelection": false,
        "order": 0,
        "items": [
          {
            "identifier": "string",
            "title": "string",
            "subtitle": "string (optional)",
            "imageIdentifier": "string (optional)",
            "order": 0,
            "style": "icon|small|large (default: icon)"
          }
        ]
      }
    ],
    "receivedTitle": "string",
    "receivedSubtitle": "string (optional)",
    "receivedImageIdentifier": "string (optional)",
    "receivedStyle": "small|large (default: small)",
    "replyTitle": "string",
    "replyImageIdentifier": "string (optional - auto-fallback)",
    "replyStyle": "icon|small|large (default: icon)",
    "images": [
      { "identifier": "string", "data": "base64", "description": "string" }
    ]
  }
}
```

### apple_form
```json
{
  "contentType": "apple_form",
  "contentAttributes": {
    "title": "string",
    "description": "string (optional)",
    "pages": [...],
    "showSummary": false,
    "receivedMessage": {
      "title": "string",
      "subtitle": "string (optional)",
      "imageIdentifier": "string (optional)",
      "style": "large"
    },
    "replyMessage": {
      "title": "string",
      "subtitle": "string (optional)",
      "imageIdentifier": "string (optional - auto-fallback)",
      "style": "large"
    },
    "images": [...]
  }
}
```

### apple_quick_reply
```json
{
  "contentType": "apple_quick_reply",
  "contentAttributes": {
    "summaryText": "string",
    "items": [
      {
        "identifier": "string",
        "title": "string"
      }
    ]
  }
}
```

### apple_pay
```json
{
  "contentType": "apple_pay",
  "contentAttributes": {
    "payment": {
      "merchantIdentifier": "string",
      "merchantName": "string",
      "countryCode": "US",
      "currencyCode": "USD",
      "paymentNetworks": ["visa", "mastercard", "amex"],
      "lineItems": [...],
      "total": {
        "label": "Total",
        "amount": "99.99",
        "type": "final"
      }
    },
    "receivedTitle": "string",
    "replyTitle": "string",
    "images": [...]
  }
}
```

---

## Parameters Format

### Parameter Definition
```json
{
  "parameter_name": {
    "type": "string|integer|boolean|array|object|datetime",
    "required": true|false,
    "description": "Human-readable description",
    "default": "default_value",
    "example": "example_value"
  }
}
```

### Parameter Types
- **string** - Text parameter
- **integer** - Whole number
- **number** - Floating point
- **boolean** - True/false
- **array** - Array of values
- **object** - Nested object
- **datetime** - ISO8601 datetime
- **hash** - Object (same as object)

---

## Error Responses

### Validation Error (400 Bad Request)
```json
{
  "error": "Parameter validation failed",
  "details": "Required parameter 'order_id' is missing"
}
```

### Not Found (404)
```json
{
  "error": "Template not found"
}
```

### Authorization Error (403)
```json
{
  "error": "Access denied"
}
```

### Server Error (500)
```json
{
  "error": "Template rendering failed",
  "details": "Error message"
}
```

---

## Template Content Blocks

### Supported Block Types
- `text` - Plain text
- `media` - Images/videos
- `button_group` - Buttons
- `list_picker` - List selection
- `time_picker` - Time selection
- `quick_reply` - Quick replies
- `payment_request` - Payment request
- `auth_request` - Authentication
- `oauth` - OAuth flow
- `form` - Form submission
- `location_picker` - Location selection
- `file_upload` - File upload
- `rich_link` - URL preview
- `apple_pay` - Apple Pay
- `list` - Generic list
- `imessage_app` - iMessage app

### Block Structure
```json
{
  "blockType": "time_picker",
  "properties": {
    "title": "Select a time",
    "event": {...},
    "imageSomething": "value"
  },
  "conditions": {
    "if": "{{user_type}} == 'premium'"
  },
  "orderIndex": 0
}
```

---

## Channel Mappings

Used for custom field mappings per channel.

```json
{
  "channelType": "apple_messages_for_business",
  "contentType": "apple_time_picker",
  "fieldMappings": {
    "target.path": "{{source.path}}",
    "event.title": "{{blocks.0.properties.title}}"
  }
}
```

---

## Usage Logging

Templates automatically log usage. Query via:

```
GET /api/v1/accounts/:account_id/templates/:id/usage_logs
```

Returns analytics on:
- Total uses
- Success rate
- Uses by channel
- Uses by sender type
- Most common parameters
- Daily usage trends

---

## Best Practices

1. **Parameters**: Define all expected parameters with types and descriptions
2. **Channels**: Specify supported channels when creating templates
3. **Tags**: Use consistent tags for filtering and discovery
4. **Versioning**: Increment version when making breaking changes
5. **Testing**: Use `render_template` endpoint to test before deployment
6. **Images**: Use standard identifiers for image references
7. **Conditions**: Use simple equality checks in conditions
8. **Content Blocks**: Order content blocks by importance
9. **Channel Mappings**: Define for advanced channel-specific customization
10. **Metadata**: Store extra data in metadata (Apple content, bot config, etc.)

---

## Rendering Pipeline

When template is rendered:

1. **Validate parameters** against template parameter definitions
2. **Check channel compatibility** - Template must support requested channel
3. **Load template content** from content_blocks or metadata
4. **Replace variables** - Substitute {{param_name}} with actual values
5. **Evaluate conditions** - Skip blocks that don't meet conditions
6. **Load images** - Resolve image identifiers to actual image data
7. **Adapt for channel** - Transform to channel-specific format
8. **Encode images** - Convert images to base64 for transmission
9. **Log usage** - Record template use for analytics

---

## Attachment Support (Future)

Templates will support direct file attachments:

```json
{
  "attachments": [
    {
      "id": "att_123",
      "filename": "menu.pdf",
      "contentType": "application/pdf",
      "size": 125000,
      "url": "/api/v1/accounts/:id/templates/:id/attachments/att_123"
    }
  ]
}
```

For now, use:
- Content attributes (inline base64)
- AppleListPickerImage (for list picker images)
- Message attachments (separate from templates)
