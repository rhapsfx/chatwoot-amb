# n8n Bot Integration Guide for Chatwoot

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Custom n8n Nodes (Recommended)](#custom-n8n-nodes-recommended)
4. [Setting up n8n Locally](#setting-up-n8n-locally)
5. [Creating a Bot in Chatwoot](#creating-a-bot-in-chatwoot)
6. [Configuring n8n Webhook](#configuring-n8n-webhook)
7. [Working with Active Conversations](#working-with-active-conversations)
8. [Sending Messages from n8n to Chatwoot](#sending-messages-from-n8n-to-chatwoot)
9. [Using Chatwoot Templates via Bot API](#using-chatwoot-templates-via-bot-api)
10. [Apple Messages for Business Content Types](#apple-messages-for-business-content-types)
11. [Building Bot Flows in n8n](#building-bot-flows-in-n8n)
12. [Example Workflows](#example-workflows)
13. [Troubleshooting](#troubleshooting)
14. [Production Deployment](#production-deployment)
15. [Best Practices](#best-practices)
16. [Resources](#resources)
17. [Support](#support)
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
# 1. Build the package (icons are automatically copied to each node directory)
cd /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
npm install
npm run build

# 2. Stop existing n8n (if running)
container stop n8n 2>/dev/null || true
container rm n8n 2>/dev/null || true

# 3. Copy entire package to custom directory
rm -rf ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb
cp -r ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb ~/.n8n/custom/node_modules/

# 4. Verify icons are in each node directory
ls ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/dist/nodes/ChatwootAMBListPicker/
# Should show: amb.svg, chatwoot.svg, ChatwootAMBListPicker.node.js

# 5. Start n8n with custom nodes
container run \
  --name n8n \
  --detach \
  --publish 5678:5678 \
  --volume ~/.n8n:/home/node/.n8n \
  --env N8N_SECURE_COOKIE=false \
  --dns 8.8.8.8 \
  --dns 1.1.1.1 \
  n8nio/n8n

# 6. Verify installation
sleep 10
container logs n8n | tail -20
```

**Important Notes:**
- The `npm run build` command now automatically copies icons to each node directory (via gulpfile.js)
- Icons must be in the same directory as each node file for n8n to display them correctly
- DNS configuration (`--dns 8.8.8.8 --dns 1.1.1.1`) ensures n8n can reach external APIs
- We no longer need `N8N_CUSTOM_EXTENSIONS` env var - n8n automatically loads from `~/.n8n/custom/node_modules/`

**For Docker Desktop users:**

```bash
# 1. Build the package (icons are automatically copied to each node directory)
cd /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
npm install
npm run build

# 2. Copy entire package to custom directory
mkdir -p ~/.n8n/custom/node_modules
rm -rf ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb
cp -r ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb ~/.n8n/custom/node_modules/

# 3. Restart Docker container
docker stop n8n 2>/dev/null || true
docker rm n8n 2>/dev/null || true

docker run -d \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  --dns 8.8.8.8 \
  --dns 1.1.1.1 \
  n8nio/n8n

# 4. Verify installation
docker logs n8n | tail -20
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

#### Option 3: Build from Source (For Developers)

If you want to modify or contribute to the custom nodes:

**1. Clone and Setup:**
```bash
# Clone or navigate to the package directory
cd /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb

# Install dependencies
npm install

# Verify package structure
ls -la nodes/
# Should show all node directories (ChatwootAMBListPicker, ChatwootAMBTimePicker, etc.)
```

**2. Build Process:**
```bash
# Compile TypeScript and copy icons
npm run build

# This will:
# - Compile all .ts files to .js
# - Generate .d.ts type definitions
# - Copy icons to dist/ directory
# - Output to dist/ directory
```

**3. Check Build Output:**
```bash
# Verify build completed
ls -la dist/nodes/ChatwootAMBListPicker/

# Should show:
# - ChatwootAMBListPicker.node.js
# - ChatwootAMBListPicker.node.d.ts
# - amb.svg (icon)
# - chatwoot.svg (icon)
```

**4. Code Quality Checks:**
```bash
# Run linter
npm run lint

# Fix linting errors automatically
npm run lintfix

# Run tests (if available)
npm test
```

**5. Link for Development:**
```bash
# In package directory
npm link

# In n8n custom directory
cd ~/.n8n/custom
npm link n8n-nodes-chatwoot-amb

# Restart n8n to load changes
```

**Development Workflow:**
1. Make changes to `.ts` files in `nodes/` directory
2. Run `npm run build` to compile
3. Restart n8n to test changes
4. Iterate until satisfied
5. Run `npm run lint` before committing

### Testing Custom Nodes

After installation (via any method), thoroughly test the custom nodes:

**Manual Testing Checklist:**

1. **Verify Node Appears:**
   - [ ] Open http://localhost:5678
   - [ ] Create new workflow
   - [ ] Click "+ Add node"
   - [ ] Search for "Chatwoot AMB"
   - [ ] All 6-7 nodes should appear

2. **Check Icons:**
   - [ ] Icons display correctly (not showing "?" icon)
   - [ ] Icons are visible in node list
   - [ ] Icons appear in workflow canvas

3. **Test Node Configuration:**
   - [ ] Open a node (e.g., List Picker)
   - [ ] All parameters render correctly
   - [ ] Dropdowns work
   - [ ] Text fields accept input
   - [ ] Validation works

4. **Test with Real Chatwoot:**
   - [ ] Add Chatwoot credentials
   - [ ] Test connection works
   - [ ] Template ID selection works (if applicable)
   - [ ] Execute node with test data
   - [ ] Response returns expected structure
   - [ ] Error handling works (try invalid data)

5. **Test Each Node Type:**
   - [ ] List Picker - sections and items render
   - [ ] Time Picker - time slots are formatted correctly
   - [ ] Quick Reply - buttons display properly
   - [ ] Form - fields and pages work
   - [ ] Apple Pay - payment request structured correctly
   - [ ] Rich Link - preview data is complete
   - [ ] Template Message - template rendering works

**Automated Testing (via n8n):**

Create a test workflow with all nodes:
1. Add all Chatwoot AMB nodes to a workflow
2. Connect them in sequence
3. Configure each with test data
4. Execute workflow
5. Verify all nodes complete successfully

**Troubleshooting Test Failures:**

**Node doesn't appear:**
```bash
# Check n8n logs
container logs n8n | grep -i "chatwoot\|custom\|community"

# Verify files exist in container
container exec n8n ls -la /home/node/.n8n/custom/node_modules/

# Check package.json n8n section
cat ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb/package.json | grep -A 20 '"n8n"'
```

**Icons missing:**
```bash
# Verify icons in dist after build
ls ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb/dist/nodes/*/

# Each directory should contain .svg files
# If missing, run: npm run build

# Check gulpfile.js has icon copy task
cat ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb/gulpfile.js | grep -i icon
```

**Execution fails:**
```bash
# Check n8n execution logs in UI
# Enable "Continue on Fail" to see detailed error messages
# Verify Chatwoot API credentials are correct
# Check network connectivity (DNS configuration)
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
     cp ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/icons/amb.svg "$dir"
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
   container exec n8n ls -la /home/node/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/

   # Docker
   docker exec n8n ls -la /home/node/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/
   ```

2. **Check node files and icons:**
   ```bash
   # Verify icons are in each node directory
   container exec n8n ls /home/node/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/dist/nodes/ChatwootAMBListPicker/
   # Should show: amb.svg, chatwoot.svg, ChatwootAMBListPicker.node.js
   ```

3. **Rebuild if needed:**
   ```bash
   cd /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
   npm run build

   # Copy fresh build
   container stop n8n && container rm n8n
   rm -rf ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb
   cp -r ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb ~/.n8n/custom/node_modules/

   # Restart n8n (use container run command from installation section)
   ```

**Icons showing as "?" or not loading (404 errors):**

This usually happens when icons aren't in the node directories. Our updated build process fixes this automatically.

1. **Verify gulpfile.js has icon copying code:**
   ```bash
   cat ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb/gulpfile.js
   # Should show buildIconsMain() and buildIconsNodes() functions
   ```

2. **Rebuild with icon copying:**
   ```bash
   cd ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
   npm run build

   # Verify icons were copied to node directories
   ls dist/nodes/ChatwootAMBListPicker/
   # Should show: amb.svg, chatwoot.svg, *.node.js
   ```

3. **Update n8n and hard refresh browser:**
   ```bash
   # Stop n8n
   container stop n8n && container rm n8n

   # Update custom directory
   rm -rf ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb
   cp -r ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb ~/.n8n/custom/node_modules/

   # Start n8n
   container run \
     --name n8n \
     --detach \
     --publish 5678:5678 \
     --volume ~/.n8n:/home/node/.n8n \
     --env N8N_SECURE_COOKIE=false \
     --dns 8.8.8.8 \
     --dns 1.1.1.1 \
     n8nio/n8n

   # Hard refresh browser: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
   ```

4. **Check browser console:**
   - Open DevTools (F12)
   - Look for 404 errors loading `amb.svg`
   - If present, icons aren't in the correct location

**Technical Background:**
- n8n loads icons using `icon: 'file:amb.svg'` syntax
- This requires the icon file to be in the **same directory** as the node's `.js` file
- Our gulpfile.js automatically copies icons to all 7 node directories during build
- If you see 404 errors for icons, the build step didn't complete or files weren't copied

**Note:** The rest of this guide covers using HTTP Request nodes, which is still valid but requires more manual configuration.

---

## Setting up n8n Locally

### Installation Options

**Note:** This section covers basic n8n installation. For custom Chatwoot AMB nodes, see the [Custom n8n Nodes](#custom-n8n-nodes-recommended) section above for installation instructions.

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

   **Simplified command (recommended):**

   ```bash
   container run \
     --name n8n \
     --detach \
     --publish 5678:5678 \
     --volume ~/.n8n:/home/node/.n8n \
     --env N8N_SECURE_COOKIE=false \
     --dns 8.8.8.8 \
     --dns 1.1.1.1 \
     n8nio/n8n
   ```

   **Note:**
   - `N8N_SECURE_COOKIE=false` allows local development access via HTTP
   - `--dns 8.8.8.8 --dns 1.1.1.1` configures public DNS (Google & Cloudflare) for external API access
   - Custom nodes in `~/.n8n/custom/node_modules/` are automatically loaded by n8n

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

   **To update custom nodes:** Stop, remove, and re-run container with updated `~/.n8n/custom/` directory.

**Access n8n:** Open `http://localhost:5678` in your browser.

**Note:** If you configured DNS, you could also access it via `http://n8n.test:5678` (requires adding `--hostname n8n` to the run command).

---

#### Option 2: Using Docker Desktop

```bash
# Pull n8n Docker image
docker pull n8nio/n8n

# Run n8n with persistent data and DNS configuration
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  --dns 8.8.8.8 \
  --dns 1.1.1.1 \
  n8nio/n8n
```

**Note**: DNS configuration (`--dns`) ensures n8n can connect to external APIs like Google Gemini, OpenAI, etc.

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

#### 6. n8n Cannot Connect to External APIs (DNS Issues)

**Symptoms:**
- n8n cannot connect to Google Gemini, OpenAI, Chatwoot (Tailscale), or other external APIs
- Error messages like "ENOTFOUND", "getaddrinfo failed", or "Cannot resolve hostname"

**Solutions:**

**For macOS Container users:**

1. **Stop and remove existing n8n container:**
   ```bash
   container stop n8n
   container rm n8n
   ```

2. **Restart with DNS configuration:**
   ```bash
   container run \
     --name n8n \
     --detach \
     --publish 5678:5678 \
     --volume ~/.n8n:/home/node/.n8n \
     --env N8N_SECURE_COOKIE=false \
     --dns 8.8.8.8 \
     --dns 1.1.1.1 \
     n8nio/n8n
   ```

3. **Verify DNS is working:**
   ```bash
   container exec n8n wget -q -O - https://www.google.com 2>&1 | head -1
   # Should show HTML content, not "getaddrinfo failed"
   ```

**For Docker Desktop users:**

```bash
docker stop n8n
docker rm n8n

docker run -d \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  --dns 8.8.8.8 \
  --dns 1.1.1.1 \
  n8nio/n8n
```

**Why this happens:**
- Containers may not inherit proper DNS configuration from the host
- The `--dns` flags configure public DNS servers (Google: 8.8.8.8, Cloudflare: 1.1.1.1)
- This ensures n8n can reach external APIs regardless of your network configuration

**Accessing Chatwoot via Tailscale:**
If your Chatwoot instance is on Tailscale (e.g., `https://liquid-m3-pro.tail367da4.ts.net`), the DNS configuration allows n8n to resolve Tailscale hostnames:

```javascript
// In n8n HTTP Request node
URL: https://liquid-m3-pro.tail367da4.ts.net/api/v1/accounts/1/bot_templates/send_message
```

#### 7. Duplicate Messages from Quick Reply/Interactive Responses

**Symptoms:**
- Bot sends the same response message twice
- Happens specifically after customer taps quick reply buttons, time pickers, or forms

**Cause:**
- Chatwoot sends both `message_created` AND `message_updated` webhooks for interactive messages
- n8n processes both events, triggering duplicate responses

**Solution:**

Add this check at the beginning of your "Extract Message Context" function:

```javascript
// Extract data from the correct location (nested in 'body')
const messageData = $json.body || $json;
const event = messageData.event;

// Skip message_updated events to avoid duplicate processing
if (event === 'message_updated') {
  return {
    json: {
      messageCategory: 'skip',
      reason: 'Message updated event - already processed on message_created'
    }
  };
}

// Continue with rest of your logic...
```

This ensures only `message_created` events are processed, eliminating duplicates.

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

## Production Deployment

Once you've tested your n8n bot workflows locally, you'll need to deploy to production.

### Production Architecture

**Recommended Setup**: n8n runs in its own Docker environment at `/opt/n8n/`, separate from Chatwoot.

```
┌──────────────────────────────────┐
│    Nginx Proxy Manager (SSL)    │

### Step-by-Step Production Setup

This section provides complete instructions for setting up n8n in production alongside Chatwoot.

#### Step 1: Create n8n Directory Structure

```bash
ssh root@msp.rhaps.net

# Create directory structure
mkdir -p /opt/n8n/data/custom/node_modules
cd /opt/n8n
```

**Directory Layout**:
```
/opt/n8n/
├── docker-compose.yml          # n8n container config
├── .env                         # Environment variables
└── data/                        # Persistent data (mounted volume)
    ├── custom/
    │   └── node_modules/
    │       └── n8n-nodes-chatwoot-amb/  # Custom AMB nodes
    └── [n8n database files]
```

#### Step 2: Create docker-compose.yml

Create `/opt/n8n/docker-compose.yml`:

```yaml
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=n8n.msp.rhaps.net
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://n8n.msp.rhaps.net
      - NODE_ENV=production
      - N8N_SECURE_COOKIE=true
      # Custom nodes path (automatically detected)
      - N8N_CUSTOM_EXTENSIONS=/home/node/.n8n/custom
    volumes:
      - ./data:/home/node/.n8n
    dns:
      - 8.8.8.8
      - 1.1.1.1
    networks:
      - n8n-network
      - chatwoot_default  # Connect to Chatwoot network

networks:
  n8n-network:
    driver: bridge
  chatwoot_default:
    external: true  # Use existing Chatwoot network
```

**Important Settings**:
- `N8N_HOST`: Your n8n domain (for webhooks)
- `WEBHOOK_URL`: Full webhook URL (with https)
- `N8N_SECURE_COOKIE=true`: Required for HTTPS
- `volumes`: Mounts `./data` so custom nodes persist
- `networks`: Connects to both n8n network and Chatwoot network
- `dns`: Public DNS for external API access

#### Step 3: Create .env File (Optional)

Create `/opt/n8n/.env` for sensitive variables:

```bash
# Encryption key (generate with: openssl rand -base64 32)
N8N_ENCRYPTION_KEY=your-encryption-key-here

# Basic auth (optional, recommended for production)
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your-secure-password

# Timezone
GENERIC_TIMEZONE=America/Los_Angeles

# Execution mode
EXECUTIONS_MODE=regular
```

**Security Best Practices**:
- Always set `N8N_ENCRYPTION_KEY` in production
- Use `N8N_BASIC_AUTH` or configure OAuth
- Keep `.env` file secure (don't commit to git)

#### Step 4: Connect n8n to Chatwoot Network

The key to making n8n and Chatwoot communicate is sharing a Docker network.

**Verify Chatwoot network exists**:
```bash
docker network ls | grep chatwoot
# Should show: chatwoot_default
```

**If network doesn't exist, create it**:
```bash
docker network create chatwoot_default
```

**Then connect Chatwoot web container** (if not already connected):
```bash
cd /opt/chatwoot
docker compose -f docker-compose.production.yml down
# Edit docker-compose.production.yml to add network
docker compose -f docker-compose.production.yml up -d
```

#### Step 5: Start n8n

```bash
cd /opt/n8n
docker compose up -d

# Check it's running
docker compose ps
docker compose logs -f

# Verify custom nodes directory
docker compose exec n8n ls -la /home/node/.n8n/custom/node_modules/
```

**Expected Output**:
```
NAME                COMMAND                  SERVICE             STATUS              PORTS
n8n                 "tini -- /docker-ent…"   n8n                 running             0.0.0.0:5678->5678/tcp
```

#### Step 6: Configure Nginx Proxy Manager

Add SSL reverse proxy for n8n.

**Access Nginx Proxy Manager**:
- URL: `http://msp.rhaps.net:81`
- Default: `admin@example.com` / `changeme`

**Add Proxy Host for n8n**:

1. Click **Hosts → Proxy Hosts → Add Proxy Host**

2. **Details Tab**:
   - Domain Names: `n8n.msp.rhaps.net`
   - Scheme: `http`
   - Forward Hostname/IP: `n8n` (container name)
   - Forward Port: `5678`
   - ✅ Cache Assets
   - ✅ Block Common Exploits
   - ✅ Websockets Support (required for n8n)

3. **SSL Tab**:
   - SSL Certificate: Request a new SSL Certificate
   - ✅ Force SSL
   - ✅ HTTP/2 Support
   - Email: `your-email@example.com`
   - ✅ Agree to Let's Encrypt ToS

4. Click **Save**

#### Step 7: Configure DNS

Add DNS A record for n8n subdomain:

- **Subdomain**: `n8n.msp.rhaps.net`
- **Type**: `A`
- **Value**: `82.64.228.224` (server IP)
- **TTL**: `300` (5 minutes)

**Verify DNS**:
```bash
nslookup n8n.msp.rhaps.net
dig n8n.msp.rhaps.net +short
```

#### Step 8: Test n8n Access

**Via Browser**:
1. Open `https://n8n.msp.rhaps.net`
2. Should load n8n UI with valid SSL
3. Check browser console for errors (F12 → Console)

**From Chatwoot Container**:
```bash
# Test n8n is accessible from Chatwoot
docker exec chatwoot-web curl -I http://n8n:5678
# Should return: HTTP/1.1 200 OK

# Test webhook endpoint
docker exec chatwoot-web curl -X POST http://n8n:5678/webhook/test \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

**From n8n Container**:
```bash
# Test Chatwoot API is accessible from n8n
docker exec n8n curl -I http://chatwoot-web:3000/api/v1/accounts/1/conversations
# Should return: HTTP/1.1 401 Unauthorized (expected without token)
```

#### Step 9: Deploy Custom AMB Nodes

**From Local Machine**:

```bash
# Build custom nodes locally (if not already built)
cd /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
npm install
npm run build

# Install to local n8n for testing
cp -r . ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/

# Deploy to production (syncs to /opt/n8n/data/)
cd /Users/rhaps/LocalGit/chatwoot
./script/deploy-backend-changes-safe.sh
```

**The deployment script automatically**:
- Syncs custom nodes to `/opt/n8n/data/custom/node_modules/`
- Restarts n8n container
- Verifies deployment

**Verify Custom Nodes Loaded**:

```bash
# Check files on server
ssh root@msp.rhaps.net "ls -la /opt/n8n/data/custom/node_modules/n8n-nodes-chatwoot-amb/dist/nodes/"

# Check n8n logs for loading
ssh root@msp.rhaps.net "cd /opt/n8n && docker compose logs | grep -i 'custom\|community'"

# Check in n8n UI
# 1. Open https://n8n.msp.rhaps.net
# 2. Create workflow
# 3. Click "+ Add node"
# 4. Search "Chatwoot AMB"
# 5. Should see all 6 custom nodes
```

#### Step 10: Configure Chatwoot Bot Webhook

Update bot to use n8n internal hostname.

**Create/Update Agent Bot**:

```bash
# Via Rails console
ssh root@msp.rhaps.net
docker exec -it chatwoot-web rails console

# Create bot
bot = AgentBot.create\!(
  name: 'n8n Production Bot',
  description: 'Automated workflows via n8n',
  outgoing_url: 'http://n8n:5678/webhook/chatwoot'  # Internal hostname
)

# Copy the access token
puts bot.access_token

# Assign to inbox
inbox = Inbox.find_by(channel_type: 'Channel::AppleMessagesForBusiness')
inbox.agent_bot = bot
inbox.save\!
```

**Important**: Use internal Docker hostname `n8n:5678`, not the public URL.

### Network Configuration Summary

#### Internal Communication (Container-to-Container)

**Chatwoot → n8n**:
- URL: `http://n8n:5678/webhook/chatwoot`
- Network: `chatwoot_default` Docker bridge
- No SSL (internal traffic)

**n8n → Chatwoot**:
- URL: `http://chatwoot-web:3000/api/v1/...`
- Network: `chatwoot_default` Docker bridge
- No SSL (internal traffic)

#### External Access (User/Browser)

**Users → Chatwoot**:
- URL: `https://msp.rhaps.net`
- Via: Nginx Proxy Manager (SSL termination)
- SSL: Let's Encrypt certificate

**Users → n8n**:
- URL: `https://n8n.msp.rhaps.net`
- Via: Nginx Proxy Manager (SSL termination)
- SSL: Let's Encrypt certificate

### Maintenance Commands

**View n8n Logs**:
```bash
ssh root@msp.rhaps.net "cd /opt/n8n && docker compose logs -f"
```

**Restart n8n**:
```bash
ssh root@msp.rhaps.net "cd /opt/n8n && docker compose restart"
```

**Update n8n Version**:
```bash
ssh root@msp.rhaps.net "cd /opt/n8n && docker compose pull && docker compose up -d"
```

**Backup n8n Data**:
```bash
ssh root@msp.rhaps.net "cd /opt/n8n && tar -czf n8n-backup-$(date +%Y%m%d).tar.gz data/"
```

**Check Custom Nodes**:
```bash
ssh root@msp.rhaps.net "docker exec n8n ls -la /home/node/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/"
```

**Redeploy Custom Nodes**:
```bash
# From local machine
./script/deploy-backend-changes-safe.sh
```

### Security Considerations

**Production Checklist**:
- ✅ Use `N8N_ENCRYPTION_KEY` for data encryption
- ✅ Enable `N8N_BASIC_AUTH` or OAuth
- ✅ Use HTTPS for all external access
- ✅ Keep n8n updated (`docker compose pull`)
- ✅ Regular backups of `/opt/n8n/data/`
- ✅ Restrict firewall rules (only 80, 443, 22, 81)
- ✅ Use internal Docker hostnames for inter-container communication
- ✅ Keep credentials in `.env` file (not in docker-compose.yml)

**Network Security**:
- **Internal traffic**: Unencrypted HTTP over Docker bridge (secure, isolated network)
- **External traffic**: HTTPS with Let's Encrypt (SSL termination at Nginx)
- **Firewall**: Only expose ports 80 (HTTP), 443 (HTTPS), 22 (SSH), 81 (Nginx UI)

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
