# Chatwoot AMB Template Message Node

**Version**: 1.0.0
**Date**: 2025-01-07

## Overview

The **Chatwoot AMB Template Message** node allows you to send pre-configured message templates through the Chatwoot Bot API. This node is specifically designed to work with templates that have pre-uploaded attachments, making it ideal for sending standardized messages with files (brochures, catalogs, documents, etc.) without re-uploading them each time.

## Key Features

- Send messages from pre-configured Chatwoot templates
- Automatic inclusion of template attachments
- Template parameter substitution (e.g., `{{customer_name}}`)
- Template selection by ID or by name search
- Optional template validation before sending
- Support for private messages (agent notes)
- Enhanced response metadata

## Use Cases

### Standard Documents
- **Welcome packages** with company brochures
- **Product catalogs** with high-res images
- **Legal documents** (terms of service, privacy policy)
- **Onboarding materials** for new customers

### Standardized Communications
- **Order confirmations** with tracking info
- **Appointment reminders** with calendar attachments
- **Support responses** with help documentation
- **Marketing campaigns** with consistent materials

### High-Volume Sending
- **Newsletter attachments** sent to thousands
- **Product updates** with updated documentation
- **Promotional materials** with images/PDFs
- **Event information** with registration forms

## Why Use Templates with Attachments?

### Efficiency Benefits
- **Upload once, reuse forever** - No repeated file transfers in n8n workflows
- **Faster execution** - No download/upload delays in workflow
- **Lower bandwidth** - Only metadata sent via API, not file data
- **Reduced errors** - Fewer points of failure in automation

### Consistency Benefits
- **Same files every time** - No version mismatches or errors
- **Centralized management** - Update files in Chatwoot UI
- **Quality control** - Pre-approved content by team
- **Brand consistency** - Standardized materials across channels

### Operational Benefits
- **Simpler workflows** - Just one API call instead of file handling logic
- **Easier maintenance** - Update template, all workflows benefit
- **Better tracking** - Template usage metrics in Chatwoot
- **Scalability** - Works at any volume without performance impact

## Node Configuration

### Required Parameters

#### Account ID
- **Type**: Number
- **Default**: `1`
- **Description**: Your Chatwoot account ID
- **Where to find**: Chatwoot URL: `https://app.chatwoot.com/app/accounts/{account_id}/...`

#### Conversation ID
- **Type**: String
- **Default**: `={{$json["conversation"]["id"]}}`
- **Description**: Target conversation ID to send message to
- **Dynamic**: Usually comes from webhook trigger or previous node

### Template Selection

Choose how to specify the template:

#### Option 1: Use Template ID
- **Best for**: When you know the exact template ID
- **Performance**: Fastest (direct lookup)
- **Template ID** (required): Numeric ID from Chatwoot

**Example**: `123`

#### Option 2: Search Templates
- **Best for**: When you want to reference by name
- **Performance**: Slightly slower (requires search API call)
- **Template Name** (required): Name or partial name to search

**Example**: `Welcome Package` or `Order Confirmation`

**Note**: Uses first matching template if multiple results found.

### Parameters (Optional)

Template parameters for variable substitution. These replace placeholders like `{{customer_name}}` in the template content.

**Structure**:
- **Key**: Parameter name (without curly braces)
- **Value**: Value to substitute

**Examples**:

```json
{
  "customer_name": "John Doe",
  "order_id": "12345",
  "appointment_date": "2025-11-10",
  "business_name": "Acme Corporation"
}
```

**n8n Configuration**:
- Click "Add Parameter"
- Key: `customer_name`
- Value: `John Doe` (or `={{$json.customer_name}}` for dynamic values)

### Additional Options

#### Private
- **Type**: Boolean
- **Default**: `false`
- **Description**: Send as private note (visible only to agents, not customer)
- **Use case**: Internal notes with attachments for team reference

#### Return Template Info
- **Type**: Boolean
- **Default**: `false`
- **Description**: Include full template metadata in response
- **Use case**: Debugging, logging template details used

#### Validate Template
- **Type**: Boolean
- **Default**: `false`
- **Description**: Check template exists before sending message
- **Use case**: Validate template availability, catch errors early

## Response Structure

### Success Response

```json
{
  "message": {
    "id": 456789,
    "content": "Welcome to Acme Corporation! Here's your welcome package.",
    "message_type": "outgoing",
    "content_type": "text",
    "created_at": "2025-01-07T10:30:00.000Z",
    "attachments": [
      {
        "id": 111,
        "file_type": "file",
        "file_url": "https://chatwoot.example.com/rails/active_storage/blobs/...",
        "file_name": "company-brochure.pdf",
        "file_size": 2456789
      },
      {
        "id": 222,
        "file_type": "file",
        "file_url": "https://chatwoot.example.com/rails/active_storage/blobs/...",
        "file_name": "product-catalog.pdf",
        "file_size": 8945123
      }
    ]
  },
  "template_applied": true,
  "template_id": 123,
  "attachments_sent": 2,
  "metadata": {
    "template_id": 123,
    "parameters_used": {
      "customer_name": "John Doe"
    },
    "attachments_sent": 2,
    "has_attachments": true
  }
}
```

### Error Response (when Continue on Fail is enabled)

```json
{
  "error": "Template not found: Invalid Template",
  "success": false
}
```

## Example Workflows

### Example 1: Simple Welcome Message

**Scenario**: Send welcome package when new conversation starts

**Workflow**:
```
Webhook (Chatwoot conversation_created)
  ↓
Filter (only new conversations)
  ↓
Chatwoot AMB Template Message
  - Template ID: 123
  - Parameters: None
```

**Node Configuration**:
- **Account ID**: `1`
- **Conversation ID**: `={{$json.conversation.id}}`
- **Template Selection**: `Use Template ID`
- **Template ID**: `123`

**Result**: Sends template with pre-uploaded brochure and catalog automatically.

---

### Example 2: Personalized Order Confirmation

**Scenario**: Send order confirmation with customer-specific details

**Workflow**:
```
Webhook (order placed)
  ↓
Function (extract customer data)
  ↓
Chatwoot AMB Template Message
  - Template: "Order Confirmation"
  - Parameters: customer_name, order_id, order_total
```

**Node Configuration**:
- **Account ID**: `1`
- **Conversation ID**: `={{$json.conversation_id}}`
- **Template Selection**: `Search Templates`
- **Template Name**: `Order Confirmation`
- **Parameters**:
  - Key: `customer_name`, Value: `={{$json.customer.name}}`
  - Key: `order_id`, Value: `={{$json.order.id}}`
  - Key: `order_total`, Value: `={{$json.order.total}}`

**Result**: Sends order confirmation with personalized details and standard order receipt template attachment.

---

### Example 3: Conditional Template Sending

**Scenario**: Send different templates based on user language preference

**Workflow**:
```
Webhook (customer message)
  ↓
IF (language = "en")
  ├─ YES → Chatwoot AMB Template Message (English Template)
  └─ NO → IF (language = "es")
      ├─ YES → Chatwoot AMB Template Message (Spanish Template)
      └─ NO → Chatwoot AMB Template Message (Default Template)
```

**Node Configuration** (English branch):
- **Template ID**: `101` (English welcome template)
- **Parameters**:
  - Key: `customer_name`, Value: `={{$json.customer.name}}`

**Node Configuration** (Spanish branch):
- **Template ID**: `102` (Spanish welcome template)
- **Parameters**:
  - Key: `customer_name`, Value: `={{$json.customer.name}}`

---

### Example 4: Template with Validation & Error Handling

**Scenario**: Send template with pre-validation and fallback on error

**Workflow**:
```
Webhook
  ↓
Chatwoot AMB Template Message
  - Validate Template: ON
  - Continue on Fail: ON
  ↓
IF (error exists)
  ├─ YES → Send Simple Text Message (fallback)
  └─ NO → Continue workflow
```

**Node Configuration**:
- **Template ID**: `123`
- **Additional Options**:
  - **Validate Template**: `true`
  - **Return Template Info**: `true`
- **Node Settings**:
  - **Continue on Fail**: `true`

**IF Node Expression**:
```javascript
={{$json.error !== undefined}}
```

**Result**: Validates template exists before sending, falls back to simple text if template unavailable.

---

### Example 5: Bulk Template Sending

**Scenario**: Send same template to multiple conversations from CRM list

**Workflow**:
```
Schedule Trigger (daily at 9 AM)
  ↓
HTTP Request (fetch customers from CRM)
  ↓
Split In Batches (process 10 at a time)
  ↓
Item Lists (loop over customers)
  ↓
Chatwoot AMB Template Message (for each customer)
  ↓
Aggregate (collect results)
  ↓
Email (send summary report)
```

**Node Configuration**:
- **Template ID**: `456` (Daily newsletter template)
- **Conversation ID**: `={{$json.chatwoot_conversation_id}}`
- **Parameters**:
  - Key: `customer_name`, Value: `={{$json.name}}`
  - Key: `offer_code`, Value: `={{$json.promo_code}}`

**Result**: Sends newsletter template with attachments to all customers efficiently.

---

## Advanced Configuration

### Dynamic Template Selection

Use Function node to determine template ID based on conditions:

```javascript
// Function node before Template Message node
const customer = $json.customer;
let templateId;

if (customer.vip) {
  templateId = 201; // VIP welcome package
} else if (customer.new) {
  templateId = 202; // New customer welcome
} else {
  templateId = 203; // Standard welcome
}

return {
  json: {
    ...customer,
    template_id: templateId
  }
};
```

Then in Template Message node:
- **Template ID**: `={{$json.template_id}}`

---

### Chaining Template Messages

Send multiple templates in sequence:

```
Trigger
  ↓
Chatwoot AMB Template Message #1 (Welcome)
  ↓
Wait (5 seconds)
  ↓
Chatwoot AMB Template Message #2 (Product Info)
  ↓
Wait (5 seconds)
  ↓
Chatwoot AMB Template Message #3 (Contact Info)
```

---

### Error Handling with Retry

```
Chatwoot AMB Template Message
  - Continue on Fail: ON
  ↓
IF (error exists)
  ├─ YES → Wait (30 seconds) → Chatwoot AMB Template Message (retry)
  └─ NO → Success (continue)
```

---

## Comparison: Template Message vs Rich Feature Nodes

| Feature | Template Message Node | Rich Feature Nodes (List Picker, etc.) |
|---------|----------------------|----------------------------------------|
| **Attachments** | Pre-uploaded, automatic | Not supported |
| **Content Management** | Centralized in Chatwoot | Defined in n8n workflow |
| **Consistency** | Guaranteed (same template) | Manual (can vary) |
| **Setup Complexity** | Medium (template creation) | Low (direct configuration) |
| **Flexibility** | Low (pre-configured) | High (fully customizable) |
| **Performance** | High (no file transfer) | Medium (more parameters) |
| **Use Case** | Standard messages with files | Dynamic, customized messages |
| **File Uploads** | Once in Chatwoot | N/A |
| **Parameter Support** | Yes (variable substitution) | Yes (full customization) |

### When to Use Each

**Use Template Message Node When:**
- Sending standard company documents
- Files rarely change
- Need consistent messaging
- High-volume sending
- Centralized content control needed

**Use Rich Feature Nodes When:**
- Content is fully dynamic
- No file attachments needed
- Workflow-specific customization
- Rapid iteration/testing
- Simple one-off messages

---

## Prerequisites

### 1. Chatwoot Setup

#### Create Template in Chatwoot UI

1. Go to **Settings → Message Templates**
2. Click **Create New Template**
3. Fill in details:
   - **Name**: "Welcome Package"
   - **Category**: "General" or "Onboarding"
   - **Supported Channels**: Check "Apple Messages for Business"
   - **Content**: "Welcome to {{business_name}}! Here's your welcome package."
4. **Upload Attachments** (if template supports attachments):
   - Click "Add Attachments"
   - Upload files (PDFs, images, documents)
   - Drag to reorder if needed
5. Click **Save**
6. Note the **Template ID** from URL or list

#### Create Agent Bot

1. Go to **Settings → Agent Bots**
2. Click **Add a new agent bot**
3. Name: "n8n Bot"
4. Copy **API Access Token**
5. Assign bot to inbox(es) where you'll send messages

### 2. n8n Setup

#### Install Node Package

**Option A: Via Community Nodes** (recommended)
1. Go to **Settings → Community Nodes**
2. Click **Install a community node**
3. Enter: `n8n-nodes-chatwoot-amb`
4. Click **Install**
5. Restart n8n

**Option B: Via npm** (self-hosted)
```bash
cd ~/.n8n/nodes
npm install n8n-nodes-chatwoot-amb
```

#### Configure Credentials

1. In n8n, go to **Credentials**
2. Click **Add Credential**
3. Search for **Chatwoot Bot API**
4. Fill in:
   - **Chatwoot URL**: `https://app.chatwoot.com` (or your instance URL)
   - **API Access Token**: (paste bot token from Chatwoot)
5. Click **Save**

---

## Troubleshooting

### Template Not Found

**Error**: `Template not found: [name]` or `404 Not Found`

**Solutions**:
- Verify template ID exists in Chatwoot
- Check template is active (status = "active")
- Ensure template supports "Apple Messages for Business" channel
- If using search, verify exact template name
- Try using Template ID instead of search

---

### No Attachments Sent

**Issue**: Message sent but `attachments_sent: 0`

**Solutions**:
- Verify template has attachments uploaded in Chatwoot UI
- Check template was saved after uploading attachments
- Ensure attachments are valid file types
- Check Chatwoot logs for attachment processing errors

---

### Parameters Not Substituted

**Issue**: Message shows `{{customer_name}}` instead of actual value

**Solutions**:
- Verify parameter key matches template placeholder (case-sensitive)
- Check parameter key doesn't include curly braces: use `customer_name`, not `{{customer_name}}`
- Ensure parameters are passed in correct format
- Check template content actually has placeholders

---

### Authentication Errors

**Error**: `401 Unauthorized`

**Solutions**:
- Verify bot token is correct in n8n credentials
- Check bot is active on the inbox
- Ensure token hasn't expired
- Verify bot has access to the account/inbox

---

### Conversation Not Found

**Error**: `Conversation not found` or `404`

**Solutions**:
- Verify conversation ID is valid and exists
- Check conversation is open (not resolved/closed)
- Ensure bot has access to the conversation's inbox
- Verify account ID matches the conversation's account

---

### Rate Limiting

**Error**: `429 Too Many Requests`

**Solutions**:
- Add delays between requests (use Wait nodes)
- Use Split In Batches node for bulk operations
- Check Chatwoot rate limit settings
- Reduce parallel execution in n8n workflows

---

## API Reference

### Endpoint Used

```
POST /api/v1/accounts/{account_id}/bot_templates/send_message
```

### Request Format

```json
{
  "conversation_id": 12345,
  "template_id": 123,
  "parameters": {
    "customer_name": "John Doe",
    "business_name": "Acme Corp"
  },
  "private": false
}
```

### Response Format

See "Response Structure" section above.

### Related Endpoints

**Search Templates**:
```
GET /api/v1/accounts/{account_id}/bot_templates/search?query={name}&channel=apple_messages_for_business
```

**Get Template Details**:
```
GET /api/v1/accounts/{account_id}/templates/{template_id}
```

---

## Best Practices

### Template Design

1. **Use descriptive names**: "Order Confirmation v2" better than "Template 1"
2. **Version your templates**: Append version numbers for tracking changes
3. **Keep attachments updated**: Review quarterly for outdated content
4. **Test before production**: Send to test conversation first
5. **Document parameters**: List required parameters in template description

### Workflow Design

1. **Enable Continue on Fail**: Always add error handling for production workflows
2. **Validate inputs**: Check conversation exists before sending
3. **Log template usage**: Track which templates are sent when for analytics
4. **Use batch processing**: For bulk sends, process in batches to avoid rate limits
5. **Add retry logic**: Network issues happen, build in retry mechanisms

### Performance Optimization

1. **Use Template ID**: Faster than search (skips API call)
2. **Cache template IDs**: Store frequently used IDs in workflow variables
3. **Minimize parameters**: Only pass parameters actually used in template
4. **Disable validation**: Skip if you're certain template exists
5. **Batch operations**: Group multiple sends when possible

### Security & Privacy

1. **Protect bot tokens**: Never expose in workflows shared publicly
2. **Validate user input**: Sanitize parameters from external sources
3. **Use private flag**: For sensitive internal documents
4. **Audit template access**: Review who can create/edit templates
5. **Encrypt credentials**: Use n8n credential encryption

---

## Changelog

### Version 1.0.0 (2025-01-07)

**Initial Release**

Features:
- Template selection by ID or name search
- Parameter substitution support
- Automatic attachment inclusion
- Optional template validation
- Private message support
- Enhanced response metadata
- Error handling with Continue on Fail
- Comprehensive documentation

---

## Resources

- **Chatwoot Template Docs**: [docs/templates/SENDING_FILES_VIA_BOT_API.md](/archive/n8n-legacy/docs/templates/SENDING_FILES_VIA_BOT_API.md)
- **n8n Node Development**: https://docs.n8n.io/integrations/creating-nodes/
- **Chatwoot Bot API**: https://www.chatwoot.com/docs/product/channels/live-chat/integrations/chatwoot-bot
- **Apple Messages for Business**: https://developer.apple.com/documentation/businesschatapi

---

## Support

- **Issues**: https://github.com/chatwoot/n8n-nodes-chatwoot-amb/issues
- **Discussions**: https://github.com/chatwoot/n8n-nodes-chatwoot-amb/discussions
- **Chatwoot Community**: https://chatwoot.com/community

---

**Built with ❤️ for the Chatwoot community**
