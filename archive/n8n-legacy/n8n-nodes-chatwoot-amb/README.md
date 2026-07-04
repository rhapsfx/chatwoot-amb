# n8n-nodes-chatwoot-amb

![Version](https://img.shields.io/npm/v/n8n-nodes-chatwoot-amb)
![License](https://img.shields.io/npm/l/n8n-nodes-chatwoot-amb)
![Downloads](https://img.shields.io/npm/dt/n8n-nodes-chatwoot-amb)

Community nodes for [n8n](https://n8n.io) to leverage **Chatwoot Apple Messages for Business** (AMB) rich messaging features.

## Features

This package provides custom n8n nodes for all Apple Messages for Business rich message types:

- **📋 List Picker** - Interactive lists with images and sections
- **📅 Time Picker** - Appointment scheduling with time slots
- **⚡ Quick Reply** - Quick action buttons
- **📝 Form** - Multi-field data collection forms
- **💳 Apple Pay** - Payment requests
- **🔗 Rich Link** - Web links with rich previews
- **📄 Template Message** - Pre-configured templates with attachments ✨ NEW

## Installation

### In n8n via Community Nodes

1. Go to **Settings → Community Nodes**
2. Click **Install a community node**
3. Enter: `n8n-nodes-chatwoot-amb`
4. Click **Install**

### Via npm (self-hosted)

```bash
cd ~/.n8n/nodes
npm install n8n-nodes-chatwoot-amb
```

### From source

```bash
# Clone this repository
git clone https://github.com/chatwoot/n8n-nodes-chatwoot-amb.git
cd n8n-nodes-chatwoot-amb

# Install dependencies
npm install

# Build
npm run build

# Link to n8n
npm link
cd ~/.n8n/custom
npm link n8n-nodes-chatwoot-amb
```

## Prerequisites

- **Chatwoot instance** (self-hosted or cloud)
- **Agent Bot** configured in Chatwoot
- **Bot API Access Token** from Chatwoot
- **Apple Messages for Business channel** (for testing with real devices)

## Quick Start

### 1. Create Agent Bot in Chatwoot

1. Go to **Settings → Agent Bots**
2. Click **Add a new agent bot**
3. Name it (e.g., "n8n Bot")
4. Copy the **API Access Token**

### 2. Configure Credentials in n8n

1. In n8n, go to **Credentials**
2. Click **Add Credential**
3. Search for **Chatwoot Bot API**
4. Paste your bot's access token
5. Save

### 3. Create Your First Workflow

**Example: Send Quick Reply**

1. Add **Webhook** node to trigger the workflow
2. Add **Chatwoot AMB Quick Reply** node
3. Configure:
   - **Chatwoot URL**: `https://app.chatwoot.com`
   - **Account ID**: `1`
   - **Conversation ID**: `={{$json["conversation"]["id"]}}`
   - **Template ID**: Your template ID
   - **Summary Text**: "How satisfied are you?"
   - **Items**: Add quick reply buttons
4. Activate workflow

## Node Documentation

### Common Parameters

All nodes share these common parameters:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| Chatwoot URL | string | ✅ | Your Chatwoot instance URL |
| Account ID | number | ✅ | Chatwoot account ID |
| Conversation ID | string | ✅ | Target conversation ID |
| Template ID | number | ✅ | Template ID from Chatwoot |

### Chatwoot AMB List Picker

Send interactive lists with images and multiple sections.

**Parameters:**
- **Title** - List picker title
- **Sections** - Array of sections containing items
  - **Section Title** - Section name
  - **Multiple Selection** - Allow multi-select
  - **Items** - Array of list items
    - **Identifier** - Unique ID (returned on selection)
    - **Title** - Item title
    - **Subtitle** - Optional description
    - **Image Identifier** - Reference to image
    - **Style** - `small` or `large`
- **Images** - Array of base64-encoded images
- **Received/Reply Message** - Customization options

**Example Use Cases:**
- Product catalogs
- Service selection menus
- Restaurant menus with photos

---

### Chatwoot AMB Time Picker

Schedule appointments with available time slots.

**Parameters:**
- **Title** - Time picker title
- **Description** - Optional description
- **Available Slots** - Array of time slots
  - **Identifier** - Unique ID (e.g., `2025-11-03_14`)
  - **Start Time** - ISO 8601 format (e.g., `2025-11-03T14:00+0000`)
  - **Duration** - Duration in seconds (e.g., `3600` = 1 hour)
- **Timezone Offset** - Offset in seconds (e.g., `28800` = UTC+8)
- **Images** - Optional images
- **Received/Reply Message** - Customization options

**Example Use Cases:**
- Appointment booking
- Event registration
- Meeting scheduling

---

### Chatwoot AMB Quick Reply

Quick action buttons for fast user responses.

**Parameters:**
- **Summary Text** - Text displayed above buttons
- **Items** - Array of quick reply buttons
  - **Identifier** - Unique ID
  - **Title** - Button text (max 35 chars recommended)

**Example Use Cases:**
- Yes/No confirmations
- Feedback collection
- Quick navigation menus

---

### Chatwoot AMB Form

Multi-field forms for data collection.

**Parameters:**
- **Title** - Form title
- **Description** - Optional description
- **Show Summary** - Show summary before submission
- **Pages** - Array of form pages (multi-page support)
  - **Page Title** - Page name
  - **Fields** - Array of form fields
    - **Identifier** - Unique field ID
    - **Type** - Field type (`text`, `email`, `phone`, `number`, `select`, `multiselect`, `date`, `time`)
    - **Label** - Field label
    - **Required** - Whether field is required
    - **Placeholder** - Placeholder text
- **Images** - Optional images
- **Received/Reply Message** - Customization options

**Example Use Cases:**
- Contact information collection
- Survey forms
- Registration forms

---

### Chatwoot AMB Apple Pay

Send Apple Pay payment requests.

**Parameters:**
- **Title** - Payment request title
- **Merchant Identifier** - Apple Pay merchant ID (e.g., `merchant.com.yourcompany`)
- **Merchant Name** - Display name
- **Country Code** - ISO country code (e.g., `US`)
- **Currency Code** - ISO currency code (e.g., `USD`)
- **Total Amount** - Total payment amount (e.g., `120.00`)
- **Total Label** - Label for total (e.g., `Total`)
- **Line Items** - Array of line items
  - **Label** - Item description
  - **Amount** - Item amount
  - **Type** - `final` or `pending`
- **Payment Networks** - Accepted networks (`visa`, `mastercard`, `amex`, etc.)

**Example Use Cases:**
- E-commerce checkout
- Service payments
- Booking deposits

**Note:** Requires Apple Pay merchant certificate configured in Chatwoot.

---

### Chatwoot AMB Rich Link

Share web links with rich previews.

**Parameters:**
- **Title** - Link card title
- **Subtitle** - Optional description
- **URL** - Target URL
- **Image URL** - Preview image URL (publicly accessible)
- **Open in Safari** - Open in Safari instead of in-app browser

**Example Use Cases:**
- Sharing blog posts
- Product pages
- Documentation links

---

### Chatwoot AMB Template Message ✨ NEW

Send pre-configured message templates with automatic file attachments.

**Parameters:**
- **Template Selection** - Choose by ID or search by name
- **Template ID / Name** - Template identifier
- **Parameters** - Variable substitution (e.g., `{{customer_name}}`)
- **Additional Options** - Validation, private messages, metadata

**Key Benefits:**
- **Upload once, reuse forever** - No repeated file transfers
- **Automatic attachments** - Files included automatically from template
- **Centralized management** - Update templates in Chatwoot UI
- **High performance** - No file uploads in workflow
- **Consistent messaging** - Same content every time

**Example Use Cases:**
- Welcome packages with company brochures
- Order confirmations with receipts
- Product catalogs with images
- Legal documents (terms, privacy policy)
- Support documentation
- Marketing materials
- Newsletter attachments

**Quick Example:**
```
1. Create template in Chatwoot with attachments
2. In n8n: Add "Chatwoot AMB Template Message" node
3. Set Template ID: 123
4. Add parameters: customer_name, order_id
5. Send - attachments included automatically!
```

**Documentation:**
- [Full Node Documentation](/docs/TEMPLATE_MESSAGE_NODE.md)
- [Quick Start Guide](/docs/QUICK_START_TEMPLATE_MESSAGE.md)
- [Example Workflows](/examples/)

---

## Advanced Usage

### Dynamic Time Slot Generation

Use a **Function** node before Time Picker to generate slots dynamically:

```javascript
// Generate next 7 days, 9 AM and 2 PM slots
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

Then reference in Time Picker: `={{$json.slots}}`

### Multi-Step Conversations

Use **IF** nodes and **Switch** nodes to create conversational flows:

```
Webhook → Filter Event → IF (is incoming) → Analyze Intent → Switch (intent type)
  ├─ booking → Send Time Picker
  ├─ product → Send List Picker
  └─ payment → Send Apple Pay
```

### Error Handling

Enable **Continue on Fail** in node settings to handle errors gracefully:

```javascript
// In a Function node after AMB node
if ($json.error) {
  // Send fallback message
  return {
    json: {
      fallback: true,
      message: "Sorry, something went wrong. Please try again."
    }
  };
}

return $json;
```

## Troubleshooting

### Authentication Errors

**Problem:** 401 Unauthorized responses

**Solution:**
- Verify bot token is correct
- Check token hasn't expired
- Ensure bot is active on the inbox

### Template Not Found

**Problem:** 404 errors when sending templates

**Solution:**
- Verify template ID exists in Chatwoot
- Check template is active
- Ensure template supports Apple Messages channel

### Images Not Displaying

**Problem:** Images show as broken or plain text

**Solution:**
- Verify image is base64-encoded with proper prefix: `data:image/png;base64,...`
- Check image size (recommended max 5MB)
- Ensure image format is supported (PNG, JPEG)

### Conversation Not Found

**Problem:** Can't send message to conversation

**Solution:**
- Check conversation ID is correct
- Ensure conversation exists and is open
- Verify bot has access to the inbox

## Development

### Setup Development Environment

```bash
git clone https://github.com/chatwoot/n8n-nodes-chatwoot-amb.git
cd n8n-nodes-chatwoot-amb
npm install
```

### Build

```bash
npm run build
```

### Watch Mode

```bash
npm run dev
```

### Lint

```bash
npm run lint
npm run lintfix
```

### Format

```bash
npm run format
```

## Resources

- **Chatwoot Docs**: https://www.chatwoot.com/docs
- **n8n Docs**: https://docs.n8n.io
- **Apple Messages for Business**: https://developer.apple.com/documentation/businesschatapi
- **Community Support**: https://github.com/chatwoot/n8n-nodes-chatwoot-amb/issues

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file

## Support

- **Issues**: https://github.com/chatwoot/n8n-nodes-chatwoot-amb/issues
- **Discussions**: https://github.com/chatwoot/n8n-nodes-chatwoot-amb/discussions
- **Chatwoot Community**: https://chatwoot.com/community

---

**Built with ❤️ by the Chatwoot team**
