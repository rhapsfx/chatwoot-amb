# n8n Bot Integration Guide for Chatwoot

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Custom n8n Nodes (Recommended)](#custom-n8n-nodes-recommended)
4. [Setting up n8n Locally](#setting-up-n8n-locally)
5. [Creating a Bot in Chatwoot](#creating-a-bot-in-chatwoot)
6. [Configuring n8n Webhook](#configuring-n8n-webhook)
7. [Working with Active Conversations](#working-with-active-conversations)
8. [Using Chatwoot Templates via Bot API](#using-chatwoot-templates-via-bot-api)
9. [Apple Messages for Business Content Types](#apple-messages-for-business-content-types)
10. [Building Bot Flows in n8n](#building-bot-flows-in-n8n)
11. [Example Workflows](#example-workflows)
12. [Troubleshooting](#troubleshooting)

---

## Overview

This guide explains how to integrate n8n (workflow automation platform) with Chatwoot using the Bot API. You'll learn how to:

- Connect Chatwoot to n8n using webhooks
- Receive and process incoming messages
- Send rich messages using Chatwoot templates
- Work with Apple Messages for Business content types
- Build sophisticated bot flows

**Architecture Flow:**
```
Customer → Chatwoot Inbox → AgentBot → n8n Webhook
                                            ↓
                                     Process Logic
                                            ↓
                                    n8n HTTP Request
                                            ↓
                         Chatwoot Bot API (Templates)
                                            ↓
                                  Customer Response
```

---

## Prerequisites

### Required
- Chatwoot instance running (local or production)
- n8n instance (will be set up in this guide)
- API access token from Chatwoot
- Basic understanding of REST APIs and webhooks

### Optional
- Apple Messages for Business channel configured in Chatwoot
- Message templates created in Chatwoot

---

## Custom n8n Nodes (Recommended)

**NEW! 🎉** We've created custom n8n nodes that make it much easier to use Chatwoot AMB features!

### Why Use Custom Nodes?

**Before (HTTP Request Nodes):**
- ⏱️ 5-10 minutes to configure each AMB feature
- 📝 Manual JSON editing
- ❌ No validation or type checking
- 📖 Need to reference documentation constantly

**After (Custom Nodes):**
- ⚡ 30 seconds to configure
- 🎨 Drag-and-drop interface
- ✅ Built-in validation
- 💡 Inline documentation and hints

### Installation

#### Option 1: Via npm (When Published)

Once published to npm, install via n8n UI:
1. Go to **Settings → Community Nodes**
2. Click **Install a community node**
3. Enter: `n8n-nodes-chatwoot-amb`
4. Click **Install**

#### Option 2: Local Installation (Development/Testing)

**For macOS Container users:**

```bash
# 1. Build the package
cd /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
npm install
npm run build

# 2. Create custom nodes directory
mkdir -p ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb

# 3. Copy built files
cp -r dist/* ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/
cp package.json ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/

# 4. Fix package.json paths (remove dist/ prefix)
# Edit ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/package.json
# Change "dist/credentials/..." to "credentials/..."
# Change "dist/nodes/..." to "nodes/..."

# 5. Copy icons to each node directory (for proper display)
for dir in ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/nodes/*/; do
  cp ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/icons/chatwoot.svg "$dir"
done

# 6. Stop and restart n8n with custom extensions path
container stop n8n
container rm n8n

container run \
  --name n8n \
  --detach \
  --publish 5678:5678 \
  --volume ~/.n8n:/home/node/.n8n \
  --env N8N_SECURE_COOKIE=false \
  --env N8N_CUSTOM_EXTENSIONS="/home/node/.n8n/custom" \
  n8nio/n8n

# 7. Verify installation
container logs n8n | tail -20
```

**For Docker Desktop users:**

```bash
# 1. Build the package
cd /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
npm install
npm run build

# 2. Install in n8n
mkdir -p ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb
cp -r dist/* ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/
cp package.json ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/

# 3. Fix paths and copy icons (same as above)
# ... (same steps 4-5 from macOS Container)

# 4. Restart Docker container
docker restart n8n
```

**For npm/npx users:**

```bash
# 1. Build the package
cd /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
npm install
npm run build

# 2. Install locally
cd ~/.n8n/custom
npm install /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb

# 3. Restart n8n
# Stop n8n (Ctrl+C)
# Set custom extensions path
export N8N_CUSTOM_EXTENSIONS="$HOME/.n8n/custom"
n8n start
```

### Available Custom Nodes

After installation, you'll have these nodes available:
- 📋 **Chatwoot AMB List Picker** - Interactive lists with images
- 📅 **Chatwoot AMB Time Picker** - Appointment scheduling
- ⚡ **Chatwoot AMB Quick Reply** - Quick action buttons
- 📝 **Chatwoot AMB Form** - Multi-field forms
- 💳 **Chatwoot AMB Apple Pay** - Payment requests
- 🔗 **Chatwoot AMB Rich Link** - Rich web links

### Quick Start with Custom Nodes

See the [custom nodes package documentation](../n8n-nodes-chatwoot-amb/README.md) for:
- Quick start guide
- Example workflows
- Complete node documentation
- Best practices

### Verifying Installation

After installing custom nodes:

1. **Check n8n logs** for loading messages:
   ```bash
   # For macOS Container
   container logs n8n | grep -i "custom\|community"

   # For Docker
   docker logs n8n | grep -i "custom\|community"
   ```

2. **Check in n8n UI:**
   - Open http://localhost:5678
   - Create new workflow
   - Click "+ Add node"
   - Search for "Chatwoot"
   - You should see all 6 AMB nodes

3. **If icons are missing (showing "?" icons):**
   ```bash
   # Copy icons to each node directory
   for dir in ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/nodes/*/; do
     cp ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/icons/chatwoot.svg "$dir"
   done

   # Restart n8n
   container stop n8n && container start n8n  # macOS Container
   # or
   docker restart n8n  # Docker
   ```

### Troubleshooting Custom Nodes

**Nodes not appearing in n8n:**

1. **Verify files exist inside container:**
   ```bash
   # macOS Container
   container exec n8n ls -la /home/node/.n8n/custom/node_modules/

   # Docker
   docker exec n8n ls -la /home/node/.n8n/custom/node_modules/
   ```

2. **Check N8N_CUSTOM_EXTENSIONS is set:**
   ```bash
   # macOS Container
   container exec n8n printenv | grep N8N_CUSTOM

   # Docker
   docker exec n8n printenv | grep N8N_CUSTOM
   ```

   Should show: `N8N_CUSTOM_EXTENSIONS=/home/node/.n8n/custom`

3. **Verify package.json paths are correct:**
   ```bash
   cat ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/package.json | grep -A 10 '"n8n"'
   ```

   Paths should be `credentials/...` and `nodes/...` (NOT `dist/credentials/...`)

4. **Rebuild if needed:**
   ```bash
   cd /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
   npm run build
   cp -r dist/* ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/
   # Restart n8n
   ```

**Icons showing as "?" (blue question marks):**
- Icons are copied to wrong location
- Follow the icon fix in "Verifying Installation" section above
- Hard refresh browser after restart (Cmd+Shift+R or Ctrl+Shift+R)

**Note:** The rest of this guide covers using HTTP Request nodes, which is still valid but requires more manual configuration.

---

## Setting up n8n Locally

### Installation Options

**IMPORTANT:** If you plan to use custom Chatwoot AMB nodes (recommended), you need to set the `N8N_CUSTOM_EXTENSIONS` environment variable during n8n startup. See the examples below.

#### Option 1: Using macOS Container (Recommended for macOS)

macOS Container provides native container support on macOS without requiring Docker Desktop.

**Prerequisites:**
- macOS with Apple Silicon or Intel processor
- Homebrew (recommended for installation)

**Installation Steps:**

1. **Start the Container Service:**
   ```bash
   # Start the container system
   container system start

   # If prompted, allow automatic Linux kernel installation
   # Verify installation
   container list --all
   ```

2. **Optional - Configure DNS for easier access:**
   ```bash
   # Create local domain "test" for container access
   sudo container system dns create test
   container system property set dns.domain test
   ```

3. **Run n8n:**

   **With custom Chatwoot AMB nodes (recommended):**

   ```bash
   container run \
     --name n8n \
     --detach \
     --publish 5678:5678 \
     --volume ~/.n8n:/home/node/.n8n \
     --env N8N_SECURE_COOKIE=false \
     --env N8N_CUSTOM_EXTENSIONS="/home/node/.n8n/custom" \
     n8nio/n8n
   ```

   **Without custom nodes (using HTTP Request nodes only):**

   ```bash
   container run \
     --name n8n \
     --detach \
     --publish 5678:5678 \
     --volume ~/.n8n:/home/node/.n8n \
     --env N8N_SECURE_COOKIE=false \
     n8nio/n8n
   ```

   **Note**: We set `N8N_SECURE_COOKIE=false` for local development. For production deployments, use HTTPS/TLS instead.

4. **Manage n8n Container:**
   ```bash
   # Stop n8n
   container stop n8n

   # Start n8n again
   container start n8n

   # View logs
   container logs n8n

   # View logs with filtering
   container logs n8n | grep -i "custom\|community\|chatwoot"

   # Remove container (data persists in ~/.n8n)
   container rm n8n
   ```

   **Note:** If you need to restart with different environment variables (e.g., adding `N8N_CUSTOM_EXTENSIONS`), you must stop, remove, and re-run the container with the new parameters.

**Access n8n:** Open `http://localhost:5678` in your browser.

**Note:** If you configured DNS, you could also access it via `http://n8n.test:5678` (requires adding `--hostname n8n` to the run command).

---

#### Option 2: Using Docker Desktop

```bash
# Pull n8n Docker image
docker pull n8nio/n8n

# Run n8n with persistent data
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  n8nio/n8n
```

#### Option 3: Using npm

```bash
# Install n8n globally
npm install -g n8n

# Start n8n
n8n start
```

#### Option 4: Using pnpm

```bash
# Install n8n globally
pnpm add -g n8n

# Start n8n
n8n start
```

### Accessing n8n

Once started, access n8n at: `http://localhost:5678`

**First-time setup:**
1. Create an owner account
2. Set your email and password
3. You're ready to create workflows!

---

## Creating a Bot in Chatwoot

### Step 1: Create an Agent Bot

1. **Via Chatwoot UI (Recommended)**:
   - Navigate to **Settings → Agent Bots**
   - Click **Add a new agent bot**
   - Fill in:
     - **Name**: e.g., "n8n Bot"
     - **Description**: e.g., "Automated bot powered by n8n"
     - **Outgoing URL**: `http://localhost:5678/webhook/chatwoot` (temporary - will update with actual n8n webhook URL)

2. **Via API**:
```bash
curl -X POST https://your-chatwoot-instance.com/api/v1/accounts/1/agent_bots \
  -H "api_access_token: YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "n8n Bot",
    "description": "Automated bot powered by n8n",
    "outgoing_url": "http://localhost:5678/webhook/chatwoot"
  }'
```

### Step 2: Copy the Bot's Access Token

After creating the bot:
1. Click on the bot in the list
2. Copy the **API Access Token** - you'll need this to authenticate n8n's API calls back to Chatwoot

### Step 3: Connect Bot to an Inbox

1. Navigate to **Settings → Inboxes**
2. Select your inbox (e.g., Apple Messages channel)
3. Go to **Collaborators** tab
4. Click **Add agents** or **Add bot**
5. Select your n8n bot
6. Ensure the bot is set to **Active**

**Via API:**
```bash
curl -X POST https://your-chatwoot-instance.com/api/v1/accounts/1/inbox/INBOX_ID/set_agent_bot \
  -H "api_access_token: YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_bot_id": AGENT_BOT_ID
  }'
```

---

## Configuring n8n Webhook

### Step 1: Create a New Workflow in n8n

1. In n8n, click **+ New workflow**
2. Name it "Chatwoot Bot Handler"

### Step 2: Add a Webhook Trigger

1. Click **Add node**
2. Search for **Webhook**
3. Configure:
   - **Authentication**: None (we'll validate in Chatwoot)
   - **HTTP Method**: POST
   - **Path**: `chatwoot` (this creates the endpoint `/webhook/chatwoot`)
   - **Respond**: Using 'Respond to Webhook' node

4. Click **Execute Node** to get the webhook URL
5. Copy the webhook URL (e.g., `http://localhost:5678/webhook/chatwoot`)

### Step 3: Update Bot's Outgoing URL

Go back to Chatwoot and update your bot's outgoing URL with the n8n webhook URL.

**Via API:**
```bash
curl -X PATCH https://your-chatwoot-instance.com/api/v1/accounts/1/agent_bots/AGENT_BOT_ID \
  -H "api_access_token: YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "outgoing_url": "http://localhost:5678/webhook/chatwoot"
  }'
```

### Step 4: Test Webhook Reception

The webhook will receive events from Chatwoot with this structure:

```json
{
  "event": "message_created",
  "id": 12345,
  "content": "Hello bot!",
  "created_at": "2025-01-15T10:30:00Z",
  "message_type": "incoming",
  "content_type": "text",
  "content_attributes": {},
  "sender": {
    "id": 1,
    "name": "Customer Name",
    "type": "contact"
  },
  "conversation": {
    "id": 123,
    "inbox_id": 5,
    "status": "open",
    "channel": "Channel::AppleMessagesForBusiness"
  },
  "inbox": {
    "id": 5,
    "name": "Apple Messages"
  },
  "account": {
    "id": 1,
    "name": "Your Company"
  }
}
```

**Events you'll receive:**
- `message_created` - New message from customer or agent
- `message_updated` - Message edited
- `conversation_opened` - New conversation started
- `conversation_resolved` - Conversation closed

---

## Working with Active Conversations

### Understanding Conversation State

When a webhook event arrives, it includes conversation information:

```json
{
  "event": "message_created",
  "conversation": {
    "id": 123,
    "inbox_id": 5,
    "status": "open",
    "messages": [...],
    "contact": {...},
    "custom_attributes": {},
    "additional_attributes": {}
  }
}
```

### Accessing Conversation Context in n8n

Add a **Function** node after your webhook to extract conversation details:

```javascript
// Extract conversation data
const event = $json.event;
const conversationId = $json.conversation.id;
const inboxId = $json.conversation.inbox_id;
const contactId = $json.sender?.id;
const messageContent = $json.content;

// Only process incoming messages
if (event === 'message_created' && $json.message_type === 'incoming') {
  return {
    json: {
      conversationId,
      inboxId,
      contactId,
      messageContent,
      shouldRespond: true
    }
  };
}

// Ignore other events
return {
  json: {
    shouldRespond: false
  }
};
```

### Filtering Messages

Add an **IF** node to filter:
- **Condition**: `{{ $json.shouldRespond }}` equals `true`
- **True branch**: Process and respond
- **False branch**: End workflow

---

## Sending Messages from n8n to Chatwoot

### Direct Messages API (Without Templates)

For simple text messages and basic Apple Messages content types, you can use the direct Messages API instead of templates.

#### HTTP Request Node Configuration

1. **Method**: POST
2. **URL**: `http://your-chatwoot.com/api/v1/accounts/1/conversations/{conversation_id}/messages`
   - For local with n8n in container: `http://192.168.1.53:10750/api/v1/accounts/1/conversations/{{ $input.item.json.conversationId }}/messages`
   - Replace `192.168.1.53` with your Mac's IP address

3. **Authentication**:
   - **Type**: Header Auth
   - **Header Name**: `api_access_token`
   - **Header Value**: User API token (from Settings → Profile Settings → Access Token)
   - **Note**: Use user tokens for direct Messages API, not bot tokens

4. **Body Content Type**: JSON

#### Example 1: Send Simple Text Message

**JSON Body**:
```json
{
  "content": "Welcome to Acoustic House! 👋",
  "message_type": "outgoing",
  "private": false
}
```

#### Example 2: Send Apple Quick Reply (No Template)

**JSON Body**:
```json
{
  "content": "Please select your region:",
  "message_type": "outgoing",
  "private": false,
  "content_type": "apple_quick_reply",
  "content_attributes": {
    "summary_text": "Please select your region:",
    "items": [
      { "identifier": "americas", "title": "Americas" },
      { "identifier": "emea", "title": "EMEA" },
      { "identifier": "apac", "title": "APAC" }
    ]
  }
}
```

#### Example 3: Send Apple Rich Link

**JSON Body**:
```json
{
  "content": "Check out our website!",
  "message_type": "outgoing",
  "private": false,
  "content_type": "apple_rich_link",
  "content_attributes": {
    "title": "Acoustic House",
    "subtitle": "Premium audio equipment",
    "url": "https://acoustichouse.com",
    "image_url": "https://acoustichouse.com/og-image.jpg"
  }
}
```

**Key Points:**
- ✅ **Use user API token** (not bot token) for direct Messages API
- ✅ `content_type` must match Apple Messages types (e.g., `apple_quick_reply`, `apple_rich_link`)
- ✅ `content_attributes` structure varies by content type
- ✅ Set `private: false` for customer-facing messages
- ⚠️ For complex templates (List Picker, Time Picker, Forms), use the Bot Templates API instead

---

## Using Chatwoot Templates via Bot API

### Bot API Endpoints

Chatwoot provides three key endpoints for bot integration:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/accounts/{account_id}/bot_templates/search` | GET | Search available templates |
| `/api/v1/accounts/{account_id}/bot_templates/render` | POST | Render template with parameters |
| `/api/v1/accounts/{account_id}/bot_templates/send_message` | POST | Send rendered template to conversation |

### Authentication

All bot API requests require the bot's API access token:

```
Authorization: Bearer YOUR_BOT_ACCESS_TOKEN
```

Or use the query parameter:
```
?api_access_token=YOUR_BOT_ACCESS_TOKEN
```

### 1. Search Templates

Search for available templates by category, channel, or use case.

**n8n HTTP Request Node Configuration:**

- **Method**: GET
- **URL**: `https://your-chatwoot.com/api/v1/accounts/1/bot_templates/search`
- **Authentication**: Generic Credential Type
  - **Header Name**: `api_access_token`
  - **Header Value**: `YOUR_BOT_ACCESS_TOKEN`
- **Query Parameters**:
  ```json
  {
    "channel": "apple_messages_for_business",
    "category": "scheduling",
    "tags": "appointment,booking"
  }
  ```

**Example Response:**
```json
{
  "templates": [
    {
      "id": 42,
      "name": "Appointment Scheduler",
      "category": "scheduling",
      "description": "Book an appointment",
      "channels": ["apple_messages_for_business"],
      "tags": ["appointment", "booking"],
      "use_cases": ["scheduling", "calendar"],
      "parameters": {
        "business_name": {
          "type": "string",
          "required": true,
          "description": "Your business name"
        },
        "available_slots": {
          "type": "array",
          "required": true,
          "description": "Available time slots"
        }
      },
      "content_blocks": [
        {
          "type": "time_picker",
          "properties": {
            "title": "{{business_name}} - Select a time",
            "description": "Choose your preferred appointment time"
          }
        }
      ],
      "version": 1,
      "status": "active"
    }
  ],
  "total": 1,
  "page": 1,
  "perPage": 20,
  "totalPages": 1
}
```

### 2. Render Template

Render a template with specific parameters (useful for preview or validation).

**n8n HTTP Request Node:**

- **Method**: POST
- **URL**: `https://your-chatwoot.com/api/v1/accounts/1/bot_templates/render`
- **Body (JSON)**:
```json
{
  "template_id": 42,
  "channel_type": "apple_messages_for_business",
  "parameters": {
    "business_name": "Acme Spa",
    "available_slots": [
      {
        "identifier": "2025-11-03_14",
        "startTime": "2025-11-03T14:00+0000",
        "duration": 3600
      },
      {
        "identifier": "2025-11-03_15",
        "startTime": "2025-11-03T15:00+0000",
        "duration": 3600
      }
    ]
  }
}
```

**Example Response:**
```json
{
  "template_id": 42,
  "template_name": "Appointment Scheduler",
  "content_type": "apple_time_picker",
  "content": "Acme Spa - Select a time",
  "content_attributes": {
    "event": {
      "title": "Acme Spa - Select a time",
      "timeslots": [
        {
          "identifier": "2025-11-03_14",
          "start_time": "2025-11-03T14:00+0000",
          "duration": 3600
        },
        {
          "identifier": "2025-11-03_15",
          "start_time": "2025-11-03T15:00+0000",
          "duration": 3600
        }
      ]
    }
  }
}
```

### 3. Send Template Message

Send a rendered template message directly to a conversation.

**n8n HTTP Request Node:**

- **Method**: POST
- **URL**: `https://your-chatwoot.com/api/v1/accounts/1/bot_templates/send_message`
- **Body (JSON)**:
```json
{
  "conversation_id": 123,
  "template_id": 42,
  "parameters": {
    "business_name": "Acme Spa",
    "available_slots": [
      {
        "identifier": "2025-11-03_14",
        "startTime": "2025-11-03T14:00+0000",
        "duration": 3600
      }
    ]
  }
}
```

**Example Response:**
```json
{
  "message": {
    "id": 98765,
    "content": "Acme Spa - Select a time",
    "content_type": "apple_time_picker",
    "message_type": "outgoing",
    "created_at": "2025-11-03T10:30:00Z",
    "conversation_id": 123,
    "sender": {
      "id": 1,
      "type": "agent_bot"
    }
  },
  "templateApplied": true,
  "templateId": 42
}
```

---

## Apple Messages for Business Content Types

Chatwoot supports all Apple Messages for Business interactive message types. Here's how to configure each in n8n.

### Content Type Reference

| Type | Enum Value | Use Case |
|------|------------|----------|
| `apple_list_picker` | 13 | Select from list (with images) |
| `apple_time_picker` | 14 | Schedule appointments |
| `apple_quick_reply` | 15 | Quick response buttons |
| `apple_pay` | 16 | Payment requests |
| `apple_rich_link` | 17 | Rich web links |
| `apple_authentication` | 18 | OAuth authentication |
| `apple_form` | 19 | Multi-field forms |
| `apple_custom_app` | 20 | iMessage apps |
| `apple_form_response` | 21 | Form submission response |

---

### General n8n HTTP Request Configuration for Templates

**All template types use the same HTTP Request node pattern in n8n:**

#### HTTP Request Node Setup

1. **Method**: POST
2. **URL**: `http://your-chatwoot.com/api/v1/accounts/1/bot_templates/send_message`
   - Replace `your-chatwoot.com` with your Chatwoot URL
   - Replace `1` with your account ID
   - For local development with n8n in a container: use your Mac's IP (e.g., `http://192.168.1.53:10750`)

3. **Authentication**:
   - **Type**: Header Auth
   - **Click**: "+ Create new credential"
   - **Credential Name**: "Chatwoot Bot Token" (any name for your reference)
   - **Header Name**: `api_access_token`
   - **Header Value**: Your bot's access token (found in Chatwoot → Settings → Agent Bots)

4. **Send Body**: Yes
5. **Body Content Type**: JSON
6. **Specify Body**: Using 'JSON'

7. **JSON Body Structure** (all templates follow this):
   ```json
   {
     "conversation_id": {{ $input.item.json.conversationId }},
     "template_id": TEMPLATE_ID,
     "parameters": {
       // Template-specific parameters here
     }
   }
   ```

**Key Points:**
- `conversation_id`: Reference from previous node using `{{ $input.item.json.conversationId }}`
- `template_id`: Your template's ID from Chatwoot (find via search or UI)
- `parameters`: Each template type has different required parameters (see below)

**For local development with macOS Container:**
- n8n runs inside a container and can't access `localhost` of your Mac
- Use your Mac's IP address: `http://192.168.1.53:10750/api/v1/...`
- Find your IP with: `ifconfig en0 | grep "inet " | awk '{print $2}'`

---

### 1. Apple List Picker (13)

**Use Case**: Present a list of options with images (e.g., products, services, menu items).

**Template Parameters:**
```json
{
  "template_id": TEMPLATE_ID,
  "parameters": {
    "title": "Select a Service",
    "sections": [
      {
        "title": "Spa Services",
        "multipleSelection": false,
        "order": 0,
        "items": [
          {
            "identifier": "massage",
            "title": "Massage Therapy",
            "subtitle": "60 minutes - $120",
            "image_identifier": "img_massage",
            "style": "large",
            "order": 0
          },
          {
            "identifier": "facial",
            "title": "Facial Treatment",
            "subtitle": "45 minutes - $80",
            "image_identifier": "img_facial",
            "style": "large",
            "order": 1
          }
        ]
      }
    ],
    "received_title": "Select a Service",
    "reply_title": "Selected: ${item.title}",
    "received_image_identifier": "img_spa_logo",
    "reply_image_identifier": "img_spa_logo",
    "images": [
      {
        "identifier": "img_massage",
        "data": "base64_encoded_image_data"
      },
      {
        "identifier": "img_facial",
        "data": "base64_encoded_image_data"
      },
      {
        "identifier": "img_spa_logo",
        "data": "base64_encoded_image_data"
      }
    ]
  }
}
```

**n8n HTTP Request Node Configuration:**

1. **Add HTTP Request Node**
   - **Name**: Send List Picker Template
   - **Method**: POST
   - **URL**: `http://your-chatwoot.com/api/v1/accounts/1/bot_templates/send_message`

2. **Authentication**:
   - **Type**: Header Auth
   - **Header Name**: `api_access_token`
   - **Header Value**: `YOUR_BOT_ACCESS_TOKEN` (from Chatwoot bot settings)

3. **Body Content Type**: JSON

4. **Specify Body**: Using 'JSON'

5. **JSON Body**:
   ```json
   {
     "conversation_id": {{ $input.item.json.conversationId }},
     "template_id": 42,
     "parameters": {
       "title": "Select a Service",
       "sections": [
         {
           "title": "Spa Services",
           "multipleSelection": false,
           "order": 0,
           "items": [
             {
               "identifier": "massage",
               "title": "Massage Therapy",
               "subtitle": "60 minutes - $120",
               "image_identifier": "img_massage",
               "style": "large",
               "order": 0
             }
           ]
         }
       ],
       "received_title": "Select a Service",
       "reply_title": "Selected: ${item.title}",
       "images": [
         {
           "identifier": "img_massage",
           "data": "data:image/png;base64,iVBORw0KGgo..."
         }
       ]
     }
   }
   ```

**Important Notes:**
- Replace `YOUR_BOT_ACCESS_TOKEN` with your actual bot token
- Replace `42` with your actual template ID
- Use `{{ $input.item.json.conversationId }}` to reference the conversation ID from previous nodes
- Images must be base64-encoded with `data:image/[type];base64,` prefix

---

### 2. Apple Time Picker (14)

**Use Case**: Schedule appointments with available time slots.

**Template Parameters:**
```json
{
  "template_id": TEMPLATE_ID,
  "parameters": {
    "title": "Book Your Appointment",
    "description": "Choose your preferred time",
    "available_slots": [
      {
        "identifier": "2025-11-03_14",
        "startTime": "2025-11-03T14:00+0000",
        "duration": 3600
      },
      {
        "identifier": "2025-11-03_15",
        "startTime": "2025-11-03T15:00+0000",
        "duration": 3600
      },
      {
        "identifier": "2025-11-04_10",
        "startTime": "2025-11-04T10:00+0000",
        "duration": 3600
      }
    ],
    "timezone_offset": 28800,
    "received_title": "Book Your Appointment",
    "reply_title": "Booked: ${event.title}",
    "received_image_identifier": "img_calendar",
    "reply_image_identifier": "img_calendar"
  }
}
```

**Dynamic Slot Generation in n8n:**
```javascript
// Function node to generate time slots
const slots = [];
const startDate = new Date('2025-11-03T09:00:00Z');

// Generate 10 slots, 1 hour apart
for (let i = 0; i < 10; i++) {
  const slotTime = new Date(startDate.getTime() + (i * 60 * 60 * 1000));
  const identifier = slotTime.toISOString().split('T')[0] + '_' + slotTime.getUTCHours();

  slots.push({
    identifier: identifier,
    startTime: slotTime.toISOString().replace(/\.\d{3}Z$/, '+0000'),
    duration: 3600
  });
}

return {
  json: {
    available_slots: slots
  }
};
```

**n8n HTTP Request Node Configuration:**

1. **Add HTTP Request Node**
   - **Name**: Send Time Picker Template
   - **Method**: POST
   - **URL**: `http://your-chatwoot.com/api/v1/accounts/1/bot_templates/send_message`

2. **Authentication**:
   - **Type**: Header Auth
   - **Header Name**: `api_access_token`
   - **Header Value**: `YOUR_BOT_ACCESS_TOKEN`

3. **Body Content Type**: JSON

4. **JSON Body**:
   ```json
   {
     "conversation_id": {{ $input.item.json.conversationId }},
     "template_id": 43,
     "parameters": {
       "title": "Book Your Appointment",
       "description": "Choose your preferred time",
       "available_slots": {{ $json.available_slots }},
       "timezone_offset": 28800,
       "received_title": "Book Your Appointment",
       "reply_title": "Booked: ${event.title}"
     }
   }
   ```

**Important Notes:**
- Use `{{ $json.available_slots }}` to reference the slots from the previous Function node
- `timezone_offset` is in seconds (28800 = UTC+8)
- Time format must be: `YYYY-MM-DDTHH:MM+0000`

---

### 3. Apple Quick Reply (15)

**Use Case**: Quick action buttons (e.g., Yes/No, feedback options).

**Template Parameters:**
```json
{
  "template_id": TEMPLATE_ID,
  "parameters": {
    "summary_text": "Are you satisfied with our service?",
    "items": [
      {
        "identifier": "yes",
        "title": "Yes, very satisfied!"
      },
      {
        "identifier": "no",
        "title": "No, not satisfied"
      },
      {
        "identifier": "somewhat",
        "title": "Somewhat satisfied"
      }
    ]
  }
}
```

**n8n HTTP Request Node Configuration:**

1. **Method**: POST
2. **URL**: `http://your-chatwoot.com/api/v1/accounts/1/bot_templates/send_message`
3. **Authentication**: Header Auth (`api_access_token` = `YOUR_BOT_ACCESS_TOKEN`)
4. **JSON Body**:
   ```json
   {
     "conversation_id": {{ $input.item.json.conversationId }},
     "template_id": 44,
     "parameters": {
       "summary_text": "Are you satisfied with our service?",
       "items": [
         { "identifier": "yes", "title": "Yes, very satisfied!" },
         { "identifier": "no", "title": "No, not satisfied" },
         { "identifier": "somewhat", "title": "Somewhat satisfied" }
       ]
     }
   }
   ```

**Note**: Quick Replies are simple and don't require images or complex configuration.

---

### 4. Apple Pay (16)

**Use Case**: Request payment via Apple Pay.

**Template Parameters:**
```json
{
  "template_id": TEMPLATE_ID,
  "parameters": {
    "title": "Complete Your Purchase",
    "merchantIdentifier": "merchant.com.yourcompany",
    "merchantName": "Your Company",
    "countryCode": "US",
    "currencyCode": "USD",
    "amount": "120.00",
    "totalLabel": "Total",
    "lineItems": [
      {
        "label": "Massage Therapy",
        "amount": "100.00",
        "type": "final"
      },
      {
        "label": "Tax",
        "amount": "20.00",
        "type": "final"
      }
    ],
    "paymentNetworks": ["visa", "mastercard", "amex"],
    "receivedTitle": "Payment Request",
    "replyTitle": "Payment Sent"
  }
}
```

**Important**: Apple Pay requires merchant certificate configuration in Chatwoot.

---

### 5. Apple Rich Link (17)

**Use Case**: Share rich preview links with images.

**Template Parameters:**
```json
{
  "template_id": TEMPLATE_ID,
  "parameters": {
    "title": "Check out our website!",
    "subtitle": "Browse our full service catalog",
    "url": "https://yourcompany.com/services",
    "imageUrl": "https://yourcompany.com/og-image.jpg",
    "openInSafari": false
  }
}
```

---

### 6. Apple Authentication (18)

**Use Case**: OAuth authentication flow.

**Template Parameters:**
```json
{
  "template_id": TEMPLATE_ID,
  "parameters": {
    "title": "Sign in to continue",
    "responseType": "code",
    "scope": ["profile", "email"],
    "state": "unique_state_token",
    "responseEncryptionKey": "your_public_key",
    "receivedTitle": "Please authenticate",
    "replyTitle": "Authentication complete"
  }
}
```

---

### 7. Apple Form (19)

**Use Case**: Multi-field data collection forms.

**Template Parameters:**
```json
{
  "template_id": TEMPLATE_ID,
  "parameters": {
    "title": "Contact Information",
    "description": "Please fill out your details",
    "pages": [
      {
        "title": "Personal Info",
        "fields": [
          {
            "identifier": "name",
            "type": "text",
            "label": "Full Name",
            "required": true
          },
          {
            "identifier": "email",
            "type": "email",
            "label": "Email Address",
            "required": true
          },
          {
            "identifier": "phone",
            "type": "phone",
            "label": "Phone Number",
            "required": false
          }
        ]
      }
    ],
    "show_summary": true,
    "received_message": {
      "title": "Contact Information",
      "imageIdentifier": "img_form",
      "style": "large"
    },
    "reply_message": {
      "title": "Thank you for your submission!",
      "imageIdentifier": "img_form",
      "style": "large"
    }
  }
}
```

---

### 8. Apple Custom App (20)

**Use Case**: Launch iMessage app extensions.

**Template Parameters:**
```json
{
  "template_id": TEMPLATE_ID,
  "parameters": {
    "title": "Launch Store App",
    "appId": "com.yourcompany.imessageapp",
    "appName": "Your Store",
    "url": "imessageapp://launch?product=123",
    "useLiveLayout": false,
    "receivedTitle": "Browse our products",
    "replyTitle": "Message from Your Store",
    "data": {
      "productId": "123",
      "category": "spa"
    }
  }
}
```

---

## Building Bot Flows in n8n

### Basic Flow Structure

```
Webhook Trigger
    ↓
Filter Events (Function)
    ↓
IF Node (is incoming message?)
    ↓ true
Process Message (Function)
    ↓
Decision Logic (Switch/IF)
    ↓
Search Templates (HTTP Request)
    ↓
Prepare Parameters (Function)
    ↓
Send Template (HTTP Request)
    ↓
Respond to Webhook (200 OK)
```

### Example: Simple Appointment Booking Flow

#### Node 1: Webhook Trigger
- **Name**: Chatwoot Events
- **Path**: `chatwoot`
- **Method**: POST

#### Node 2: Filter Events (Function)
```javascript
// Only process incoming text messages
if ($json.event === 'message_created' &&
    $json.message_type === 'incoming' &&
    $json.content_type === 'text') {

  return {
    json: {
      conversationId: $json.conversation.id,
      accountId: $json.account.id,
      inboxId: $json.inbox.id,
      messageContent: $json.content.toLowerCase(),
      shouldProcess: true
    }
  };
}

return { json: { shouldProcess: false } };
```

#### Node 3: IF Node
- **Condition**: `{{ $json.shouldProcess }}` equals `true`

#### Node 4: Check Intent (Switch)
- **Mode**: Rules
- **Rules**:
  - If `{{ $json.messageContent }}` contains `book`
  - If `{{ $json.messageContent }}` contains `schedule`
  - If `{{ $json.messageContent }}` contains `appointment`
  - Output: "booking_intent"

#### Node 5: Search Templates (HTTP Request)
- **Method**: GET
- **URL**: `https://chatwoot.com/api/v1/accounts/{{ $json.accountId }}/bot_templates/search`
- **Query Parameters**:
  ```
  category=scheduling
  channel=apple_messages_for_business
  ```

#### Node 6: Prepare Time Slots (Function)
```javascript
// Generate available slots for next 7 days
const slots = [];
const now = new Date();

for (let day = 1; day <= 7; day++) {
  const date = new Date(now);
  date.setDate(date.getDate() + day);

  // Add 9 AM and 2 PM slots
  [9, 14].forEach(hour => {
    date.setHours(hour, 0, 0, 0);
    const identifier = date.toISOString().split('T')[0] + '_' + hour;

    slots.push({
      identifier: identifier,
      startTime: date.toISOString().replace(/\.\d{3}Z$/, '+0000'),
      duration: 3600
    });
  });
}

return {
  json: {
    template_id: $json.templates[0].id,
    conversationId: $node["Filter Events"].json.conversationId,
    parameters: {
      business_name: "Acme Spa",
      available_slots: slots
    }
  }
};
```

#### Node 7: Send Template (HTTP Request)
- **Method**: POST
- **URL**: `https://chatwoot.com/api/v1/accounts/{{ $json.accountId }}/bot_templates/send_message`
- **Body**:
  ```json
  {
    "conversation_id": "={{ $json.conversationId }}",
    "template_id": "={{ $json.template_id }}",
    "parameters": "={{ $json.parameters }}"
  }
  ```

#### Node 8: Respond to Webhook
- **Node Type**: Respond to Webhook
- **Response Code**: 200
- **Body**: `{ "status": "processed" }`

---

### Advanced Flow: Multi-Step Conversation

Use n8n's **Context** feature to maintain conversation state:

```javascript
// Store conversation context
$node["Webhook"].context.set('conversationState', {
  conversationId: $json.conversation.id,
  step: 'awaiting_service_selection',
  selectedService: null,
  selectedTime: null
});

// Retrieve context later
const state = $node["Webhook"].context.get('conversationState');
```

**Flow Structure:**
1. Welcome message → List picker (services)
2. Service selected → Time picker (appointments)
3. Time selected → Confirmation → Apple Pay
4. Payment complete → Confirmation message

---

## Example Workflows

### Example 1: Customer Support Triage Bot

**Workflow:**
1. Receive message
2. Analyze content (keywords, sentiment)
3. If urgent → Send quick reply options
4. If general question → Send rich link to FAQ
5. If needs agent → Assign to agent (via Chatwoot API)

**n8n Nodes:**
- Webhook Trigger
- Function (analyze message)
- Switch (route by intent)
- HTTP Request (send quick reply template)
- HTTP Request (assign to agent)

### Example 2: Appointment Booking Bot

**Workflow:**
1. Receive booking request
2. Check business calendar (via external API)
3. Generate available slots
4. Send time picker template
5. Receive time selection
6. Create calendar event
7. Send confirmation with Apple Pay (if needed)

**n8n Nodes:**
- Webhook Trigger
- HTTP Request (check calendar)
- Function (generate slots)
- HTTP Request (send time picker)
- Webhook Trigger (receive selection)
- HTTP Request (create event)
- HTTP Request (send confirmation)

### Example 3: Product Recommendation Bot

**Workflow:**
1. Receive product inquiry
2. Search product database
3. Send list picker with products
4. Receive selection
5. Send rich link with product details
6. Send Apple Pay for checkout

**n8n Nodes:**
- Webhook Trigger
- HTTP Request (search products)
- Function (format list picker data)
- HTTP Request (send list picker)
- Webhook Trigger (receive selection)
- HTTP Request (send rich link)
- HTTP Request (send Apple Pay)

---

## Troubleshooting

### Common Issues

#### 1. Webhook Not Receiving Events

**Symptoms:**
- n8n webhook shows no executions
- Chatwoot not sending events

**Solutions:**
- Verify bot is **Active** on inbox
- Check outgoing URL is correct
- Ensure n8n is accessible from Chatwoot
- Check Chatwoot logs: `tail -f log/development.log | grep AgentBot`

#### 2. Authentication Errors

**Symptoms:**
- 401 Unauthorized responses
- Template API calls failing

**Solutions:**
- Verify bot's access token
- Check token is included in requests:
  - Header: `api_access_token: TOKEN`
  - Or query param: `?api_access_token=TOKEN`
- Regenerate token if needed (Chatwoot → Agent Bots → Reset Token)

#### 3. Template Not Found

**Symptoms:**
- 404 errors when sending templates
- Template ID not recognized

**Solutions:**
- Verify template exists and is **active**
- Check template supports the channel (e.g., `apple_messages_for_business`)
- Search templates first to confirm ID

#### 4. Invalid Parameters

**Symptoms:**
- 400 Bad Request
- "Parameter validation failed" error

**Solutions:**
- Check required parameters are provided
- Verify parameter types match template definition
- Use `/render` endpoint first to validate

#### 5. Apple Messages Content Not Displaying

**Symptoms:**
- Message sends but displays as plain text
- Interactive elements not working

**Solutions:**
- Verify inbox channel is Apple Messages for Business
- Check `content_attributes` structure matches Apple MSP specs
- Ensure images are properly base64 encoded
- Check CaseTransformer is handling snake_case → camelCase conversion

### Debugging Tips

#### Enable n8n Workflow Logging
Add **Function** nodes with logging:
```javascript
console.log('Debug:', JSON.stringify($json, null, 2));
return $json;
```

#### Check Chatwoot Logs
```bash
# Development
tail -f log/development.log

# Production
tail -f log/production.log

# Filter for bot events
tail -f log/development.log | grep -E 'AgentBot|BotTemplates|BotMessaging'
```

#### Test Webhook Manually
```bash
curl -X POST http://localhost:5678/webhook/chatwoot \
  -H "Content-Type: application/json" \
  -d '{
    "event": "message_created",
    "content": "test message",
    "message_type": "incoming",
    "conversation": {
      "id": 123,
      "inbox_id": 5
    }
  }'
```

#### Validate Template Rendering
Test templates independently:
```bash
curl -X POST https://chatwoot.com/api/v1/accounts/1/bot_templates/render \
  -H "api_access_token: YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "template_id": 42,
    "channel_type": "apple_messages_for_business",
    "parameters": { ... }
  }'
```

---

## Best Practices

### 1. Handle All Event Types
Don't assume only `message_created` events. Handle:
- `message_updated` - User edited their message
- `conversation_opened` - Send welcome message
- `conversation_resolved` - Send survey or feedback

### 2. Validate Incoming Data
Always validate webhook payloads:
```javascript
if (!$json.conversation || !$json.conversation.id) {
  console.error('Invalid webhook payload');
  return { json: { error: 'Invalid payload' } };
}
```

### 3. Use Template Search Wisely
Cache template IDs in n8n context to avoid repeated searches:
```javascript
// Check cache first
let templateId = $node["Webhook"].context.get('appointmentTemplateId');

if (!templateId) {
  // Search and cache
  // ... search logic ...
  $node["Webhook"].context.set('appointmentTemplateId', templateId);
}
```

### 4. Implement Retry Logic
Use n8n's built-in retry settings on HTTP Request nodes:
- **Retry on Fail**: Yes
- **Max Tries**: 3
- **Wait Between Tries**: 1000ms

### 5. Monitor and Log
Add error handling to all critical nodes:
```javascript
try {
  // Your logic
} catch (error) {
  console.error('Error:', error.message);
  // Send fallback message or alert
  return { json: { error: error.message } };
}
```

### 6. Test Each Content Type
Create a test workflow for each Apple Messages content type:
- Send test message
- Verify display in Apple Messages simulator
- Test user interactions
- Validate response handling

### 7. Optimize for Performance
- Keep workflows simple and focused
- Use sub-workflows for complex logic
- Minimize API calls (batch when possible)
- Use webhook responses efficiently (200 OK immediately)

---

## Resources

### Chatwoot Documentation
- Bot API Reference: `/docs/product/channels/live-chat/integrations/chatwoot-bot`
- Template System: `/docs/product/channels/live-chat/integrations/templates`
- Apple Messages: `/docs/product/channels/apple-messages`

### n8n Documentation
- Workflow basics: https://docs.n8n.io/workflows/
- Webhook node: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/
- HTTP Request node: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.httprequest/

### Apple Messages for Business
- Developer docs: https://developer.apple.com/documentation/businesschatapi
- Interactive messages: https://developer.apple.com/documentation/businesschatapi/messages_sent/interactive_messages
- Message types: https://developer.apple.com/documentation/businesschatapi/messages_sent

### Code Examples
- Template examples: `/app/services/templates/`
- Apple Messages adapters: `/app/services/templates/adapters/apple_messages_template_adapter.rb`
- Bot services: `/app/services/templates/bot_messaging_service.rb`

---

## Support

If you encounter issues:
1. Check Chatwoot logs: `log/development.log`
2. Check n8n execution logs in the workflow UI
3. Verify API credentials and permissions
4. Test endpoints with curl or Postman
5. Review this guide's troubleshooting section

For Chatwoot-specific questions:
- Community: https://chatwoot.com/community
- GitHub: https://github.com/chatwoot/chatwoot

For n8n-specific questions:
- Community: https://community.n8n.io
- GitHub: https://github.com/n8n-io/n8n

---

**Happy bot building!** 🤖
