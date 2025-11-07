# Quick Start: Chatwoot AMB Template Message

**Time to complete**: 10 minutes

This guide will walk you through sending your first template message with attachments using n8n.

## Prerequisites

- Chatwoot instance (self-hosted or cloud)
- n8n instance (cloud or self-hosted)
- Agent bot configured in Chatwoot

## Step 1: Create Template in Chatwoot (3 min)

### 1.1 Navigate to Templates
1. Log into Chatwoot
2. Go to **Settings → Message Templates**
3. Click **Create New Template**

### 1.2 Configure Template
Fill in the following:

- **Name**: `Welcome Package`
- **Category**: `Onboarding`
- **Description**: `Send welcome materials to new customers`
- **Supported Channels**: ☑️ Apple Messages for Business
- **Content**:
```
Welcome to {{business_name}}! 👋

Hi {{customer_name}}, we're excited to have you with us!

Below you'll find our welcome materials:
- Company brochure
- Product catalog
- Getting started guide

If you have any questions, just reply to this message!
```

### 1.3 Upload Attachments
1. Click **Add Attachments** button
2. Upload files:
   - `company-brochure.pdf`
   - `product-catalog.pdf`
   - `getting-started-guide.pdf`
3. Verify files appear in attachment list

### 1.4 Save & Note Template ID
1. Click **Save**
2. You'll see the template in the list
3. Note the **Template ID** (shown in the list or URL)
   - Example: `123`

## Step 2: Install n8n Node (2 min)

### 2.1 Install Package

**If using n8n Cloud or Community Edition:**
1. Go to **Settings → Community Nodes**
2. Click **Install a community node**
3. Enter: `n8n-nodes-chatwoot-amb`
4. Click **Install**
5. Wait for installation to complete
6. Restart n8n if prompted

**If using self-hosted n8n:**
```bash
cd ~/.n8n/nodes
npm install n8n-nodes-chatwoot-amb
# Restart n8n
```

### 2.2 Verify Installation
1. Create a new workflow
2. Click **Add Node**
3. Search for "Chatwoot AMB"
4. You should see **Chatwoot AMB Template Message** in the list

## Step 3: Configure Bot Credentials (2 min)

### 3.1 Get Bot Token from Chatwoot
1. In Chatwoot, go to **Settings → Agent Bots**
2. Click **Add a new agent bot** (or use existing bot)
3. Name it: `n8n Bot`
4. Copy the **API Access Token**
5. Assign bot to your inbox

### 3.2 Add Credentials in n8n
1. In n8n, go to **Credentials** menu
2. Click **Add Credential**
3. Search for **Chatwoot Bot API**
4. Fill in:
   - **Chatwoot URL**: `https://app.chatwoot.com` (or your instance)
   - **API Access Token**: (paste token from step 3.1)
5. Click **Create**

## Step 4: Create First Workflow (3 min)

### 4.1 Add Webhook Trigger
1. Create new workflow
2. Add **Webhook** node
3. Set **HTTP Method**: `POST`
4. Set **Path**: `/chatwoot-test`
5. Click **Execute Node** to get webhook URL
6. Copy the webhook URL (you'll use this for testing)

### 4.2 Add Template Message Node
1. Click **+** to add node
2. Search for **Chatwoot AMB Template Message**
3. Configure:
   - **Credentials**: Select "Chatwoot Bot API" from dropdown
   - **Account ID**: `1` (or your account ID)
   - **Conversation ID**: `={{$json.conversation_id}}`
   - **Template Selection**: `Use Template ID`
   - **Template ID**: `123` (your template ID from Step 1.4)
4. Add Parameters:
   - Click **Add Parameter**
   - **Key**: `business_name`
   - **Value**: `={{$json.business_name}}`
   - Click **Add Parameter** again
   - **Key**: `customer_name`
   - **Value**: `={{$json.customer_name}}`

### 4.3 Save Workflow
1. Name workflow: "Chatwoot Template Test"
2. Click **Save**
3. Click **Active** toggle to activate workflow

## Step 5: Test the Workflow (2 min)

### 5.1 Prepare Test Data

Get a valid conversation ID from Chatwoot:
1. Open any conversation in Chatwoot
2. Look at the URL: `https://app.chatwoot.com/app/accounts/1/conversations/{conversation_id}`
3. Note the conversation ID (e.g., `45678`)

### 5.2 Send Test Request

Use curl or Postman to trigger webhook:

```bash
curl -X POST https://your-n8n-instance.com/webhook-test/chatwoot-test \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": 45678,
    "business_name": "Acme Corporation",
    "customer_name": "John Doe"
  }'
```

**Or use Postman:**
- Method: `POST`
- URL: (your webhook URL from step 4.1)
- Body (raw JSON):
```json
{
  "conversation_id": 45678,
  "business_name": "Acme Corporation",
  "customer_name": "John Doe"
}
```

### 5.3 Verify Result

1. Check n8n execution log (should show success)
2. Open Chatwoot conversation
3. You should see:
   - Message: "Welcome to Acme Corporation! Hi John Doe, we're excited..."
   - 3 file attachments below the message
   - Files should be downloadable/viewable

**Expected Response in n8n:**
```json
{
  "message": {
    "id": 789012,
    "content": "Welcome to Acme Corporation! Hi John Doe, we're excited...",
    "attachments": [
      {
        "id": 111,
        "file_name": "company-brochure.pdf",
        "file_size": 1234567
      },
      {
        "id": 222,
        "file_name": "product-catalog.pdf",
        "file_size": 2345678
      },
      {
        "id": 333,
        "file_name": "getting-started-guide.pdf",
        "file_size": 987654
      }
    ]
  },
  "template_applied": true,
  "template_id": 123,
  "attachments_sent": 3,
  "metadata": {
    "template_id": 123,
    "parameters_used": {
      "business_name": "Acme Corporation",
      "customer_name": "John Doe"
    },
    "attachments_sent": 3,
    "has_attachments": true
  }
}
```

## Congratulations! 🎉

You've successfully:
- ✅ Created a template with attachments in Chatwoot
- ✅ Installed the n8n node package
- ✅ Configured bot credentials
- ✅ Built and tested your first workflow
- ✅ Sent a message with 3 file attachments automatically included

## Next Steps

### 1. Connect to Real Triggers

Replace the Webhook trigger with real events:

**Chatwoot Conversation Created:**
```
Chatwoot Webhook (conversation_created)
  ↓
Chatwoot AMB Template Message
```

**CRM New Customer:**
```
Schedule (daily at 9 AM)
  ↓
HTTP Request (fetch new customers from CRM)
  ↓
Item Lists (loop)
  ↓
Chatwoot AMB Template Message
```

**Order Placed:**
```
Webhook (Shopify/WooCommerce order)
  ↓
Chatwoot Create Conversation
  ↓
Chatwoot AMB Template Message
```

### 2. Create More Templates

Build a library of templates for different scenarios:
- Order confirmations
- Shipping notifications
- Support documentation
- Product information
- FAQ responses
- Appointment reminders

### 3. Add Error Handling

Make workflows production-ready:
```
Chatwoot AMB Template Message
  - Continue on Fail: ON
  - Validate Template: ON
  ↓
IF (error exists)
  ├─ YES → Send Simple Text (fallback)
  └─ NO → Log Success
```

### 4. Implement Advanced Features

- **Dynamic template selection** based on customer segment
- **Multi-language support** with different templates per language
- **A/B testing** with template variants
- **Analytics tracking** of template performance

## Troubleshooting

### Common Issues & Solutions

**Issue**: "Template not found"
- **Solution**: Verify template ID is correct in Chatwoot

**Issue**: "Conversation not found"
- **Solution**: Check conversation ID is valid and exists

**Issue**: "401 Unauthorized"
- **Solution**: Verify bot token is correct in n8n credentials

**Issue**: "No attachments sent"
- **Solution**: Ensure template has files uploaded in Chatwoot UI

**Issue**: "Parameters not replaced"
- **Solution**: Check parameter keys match template placeholders exactly (case-sensitive)

## Getting Help

- **Node Documentation**: See `/docs/TEMPLATE_MESSAGE_NODE.md`
- **GitHub Issues**: https://github.com/chatwoot/n8n-nodes-chatwoot-amb/issues
- **Chatwoot Community**: https://chatwoot.com/community
- **n8n Community**: https://community.n8n.io

## Example Workflows

Import ready-to-use example workflows:
- `/examples/welcome-package-workflow.json`
- `/examples/order-confirmation-workflow.json`
- `/examples/bulk-template-sending.json`

---

**You're now ready to build powerful automated messaging workflows with file attachments!** 🚀
