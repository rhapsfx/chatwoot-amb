# Quick Start Guide

Get started with Chatwoot AMB nodes in n8n in under 10 minutes!

## Step 1: Install the Package (2 minutes)

### In n8n Cloud or Self-hosted

1. Go to **Settings → Community Nodes**
2. Click **Install a community node**
3. Enter: `n8n-nodes-chatwoot-amb`
4. Click **Install**
5. Wait for installation to complete

## Step 2: Set Up Chatwoot (3 minutes)

### Create Agent Bot

1. Log in to your Chatwoot instance
2. Go to **Settings → Agent Bots**
3. Click **Add a new agent bot**
4. Fill in:
   - **Name**: `n8n Bot`
   - **Description**: `Automated bot powered by n8n`
   - **Outgoing URL**: Leave blank for now
5. Click **Create**
6. **Copy the API Access Token** (you'll need this!)

### Connect Bot to Inbox

1. Go to **Settings → Inboxes**
2. Select your inbox (preferably Apple Messages)
3. Click **Collaborators** tab
4. Click **Add bot**
5. Select `n8n Bot`
6. Ensure it's **Active**

## Step 3: Configure Credentials in n8n (1 minute)

1. In n8n, go to **Credentials** (left sidebar)
2. Click **Add Credential**
3. Search for **Chatwoot Bot API**
4. Paste your bot's API access token
5. Click **Save**

## Step 4: Create Your First Workflow (4 minutes)

### Simple Quick Reply Example

1. **Create New Workflow**
   - Click **Workflows → New workflow**
   - Name it: "My First AMB Bot"

2. **Add Webhook Trigger**
   - Drag **Webhook** node to canvas
   - Configure:
     - **Method**: POST
     - **Path**: `chatwoot`
     - **Respond**: Using 'Respond to Webhook' node
   - Click **Listen for Test Event**
   - **Copy the webhook URL**

3. **Add Function Node** (Filter Events)
   - Drag **Function** node
   - Connect it to Webhook
   - Name: "Filter Incoming Messages"
   - Add this code:
     ```javascript
     if ($json.event === 'message_created' &&
         $json.message_type === 'incoming') {
       return {
         json: {
           conversationId: $json.conversation.id,
           shouldRespond: true
         }
       };
     }
     return { json: { shouldRespond: false } };
     ```

4. **Add IF Node**
   - Drag **IF** node
   - Connect to Function
   - Condition: `{{ $json.shouldRespond }}` equals `true`

5. **Add AMB Quick Reply Node**
   - Find **Chatwoot AMB Quick Reply** in node list
   - Connect to IF node's **true** output
   - Configure:
     - **Credential**: Select your saved credential
     - **Chatwoot URL**: Your Chatwoot URL (e.g., `https://app.chatwoot.com`)
     - **Account ID**: `1` (or your account ID)
     - **Conversation ID**: `={{$json.conversationId}}`
     - **Template ID**: Enter a template ID (create one in Chatwoot first, or use `1` for testing)
     - **Summary Text**: `How satisfied are you with our service?`
     - Click **Add Item** under Quick Reply Items:
       - **Identifier**: `very_satisfied`
       - **Title**: `Very satisfied! 😊`
     - Click **Add Item** again:
       - **Identifier**: `satisfied`
       - **Title**: `Satisfied`
     - Click **Add Item** again:
       - **Identifier**: `not_satisfied`
       - **Title**: `Not satisfied 😞`

6. **Add Respond to Webhook Node**
   - Connect to Quick Reply node
   - Response Code: `200`
   - Body: `{"status": "processed"}`

7. **Save Workflow**
   - Click **Save** (top right)

## Step 5: Connect n8n to Chatwoot (1 minute)

1. Go back to **Chatwoot → Settings → Agent Bots**
2. Click on your `n8n Bot`
3. Update **Outgoing URL** with your n8n webhook URL
4. Click **Update**

## Step 6: Test It! (1 minute)

### Test in Chatwoot

1. Go to **Conversations** in Chatwoot
2. Create a new conversation (or use existing)
3. Send a message: `Hello bot`
4. Wait a moment...
5. You should see the quick reply buttons appear! 🎉

### What Just Happened?

1. Customer sent message → Chatwoot
2. Chatwoot → webhook → n8n
3. n8n processed message
4. n8n → Chatwoot Bot API
5. Chatwoot → Customer (quick reply buttons)

## Next Steps

### Try Other Nodes

Now that you have a working bot, try:

- **List Picker**: Display products with images
- **Time Picker**: Let customers book appointments
- **Form**: Collect customer information
- **Apple Pay**: Accept payments

### Example: Add List Picker

1. **Create Template in Chatwoot** (Settings → Templates)
   - Type: List Picker
   - Note the template ID

2. **Modify Your Workflow**
   - Replace Quick Reply node with **AMB List Picker**
   - Configure sections and items
   - Add images (base64-encoded)

3. **Test** in a conversation

### Resources

- **Full Documentation**: [README.md](README.md)
- **Examples**: [examples/](examples/)
- **Contributing**: [CONTRIBUTING.md](CONTRIBUTING.md)

## Troubleshooting

### Webhook not receiving events

- Check bot is **Active** on inbox
- Verify webhook URL is correct
- Check n8n is accessible from Chatwoot

### Authentication errors

- Verify bot token is correct
- Check token in credentials
- Try regenerating token in Chatwoot

### Node not showing in n8n

- Refresh n8n page
- Check package installed correctly
- Restart n8n if self-hosted

## Common Patterns

### Dynamic Template Selection

Use a **Switch** node to route to different templates based on customer intent:

```
Webhook → Filter → Analyze Intent → Switch
  ├─ booking → Time Picker
  ├─ browse → List Picker
  └─ payment → Apple Pay
```

### Multi-Step Flows

Use context to maintain conversation state across multiple messages.

### Error Handling

Enable **Continue on Fail** on nodes to handle errors gracefully.

## Need Help?

- Check [examples/](examples/) for complete workflows
- Open an [issue](https://github.com/chatwoot/n8n-nodes-chatwoot-amb/issues)
- Join [discussions](https://github.com/chatwoot/n8n-nodes-chatwoot-amb/discussions)

---

**Congratulations!** 🎉 You've created your first Chatwoot AMB bot with n8n!
