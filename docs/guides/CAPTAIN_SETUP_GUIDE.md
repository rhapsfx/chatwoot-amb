# Captain Feature Setup Guide

## Issue
Captain feature is enabled in the database but not showing in the UI because it's restricted to CLOUD or ENTERPRISE installation types.

## Current Status
- ✅ Feature enabled in database: `captain_integration` and `captain_integration_v2`
- ❌ Installation type: Not set (defaults to self-hosted)
- ❌ Captain routes require: `INSTALLATION_TYPES.CLOUD` or `INSTALLATION_TYPES.ENTERPRISE`

## Solution Options

### Option 1: Set Installation Type to Enterprise (Recommended for Development)

Add this to your `.env` file:
```bash
INSTALLATION_TYPE=enterprise
```

Then restart the server:
```bash
./dev-server.sh restart
```

### Option 2: Modify Routes to Allow Self-Hosted (Development Only)

Edit `app/javascript/dashboard/routes/dashboard/captain/captain.routes.js` and remove or modify the `installationTypes` restriction.

**Before:**
```javascript
meta: {
  permissions: ['administrator', 'agent'],
  featureFlag: FEATURE_FLAGS.CAPTAIN,
  installationTypes: [
    INSTALLATION_TYPES.CLOUD,
    INSTALLATION_TYPES.ENTERPRISE,
  ],
},
```

**After (allow all installation types):**
```javascript
meta: {
  permissions: ['administrator', 'agent'],
  featureFlag: FEATURE_FLAGS.CAPTAIN,
  // installationTypes removed - allows all types
},
```

## What Captain Provides

Once enabled, Captain gives you access to:

### 1. **Assistants** (`/app/accounts/1/captain/assistants`)
   - Create AI assistants for your team
   - Configure assistant behavior and knowledge base
   - Set up guardrails and guidelines
   - Assign assistants to specific inboxes

### 2. **Documents** (`/app/accounts/1/captain/documents`)
   - Upload and manage knowledge base documents
   - Documents are used to train assistants
   - Supports various file formats
   - Automatic indexing and search

### 3. **Responses** (`/app/accounts/1/captain/responses`)
   - View AI-generated responses
   - Track response quality and usage
   - Manage response templates
   - Analytics on AI performance

### 4. **Tools** (`/app/accounts/1/captain/tools`)
   - Create custom tools for assistants
   - HTTP-based tool integrations
   - Connect to external APIs
   - Extend assistant capabilities

### 5. **Copilot** (In-conversation AI assistance)
   - Real-time AI suggestions during conversations
   - Context-aware response recommendations
   - Automatic sentiment analysis
   - Smart reply suggestions

## Configuration Requirements

Captain also requires these environment variables for full functionality:

```bash
# OpenAI Configuration (required)
CAPTAIN_OPEN_AI_API_KEY=your_openai_api_key
CAPTAIN_OPEN_AI_MODEL=gpt-4  # or gpt-3.5-turbo
CAPTAIN_OPEN_AI_ENDPOINT=https://api.openai.com/v1  # optional, defaults to OpenAI

# Embedding Model (for document search)
CAPTAIN_EMBEDDING_MODEL=text-embedding-ada-002

# Firecrawl (for web scraping documents)
CAPTAIN_FIRECRAWL_API_KEY=your_firecrawl_key  # optional
```

## Quick Setup Script

Run this to set up Captain for development:

```bash
# 1. Add to .env
echo "INSTALLATION_TYPE=enterprise" >> .env

# 2. Verify feature is enabled
rails runner "puts Account.first.feature_enabled?('captain_integration')"

# 3. Restart server
./dev-server.sh restart
```

## Verification

After setup, verify Captain is working:

1. **Check UI**: Look for "Captain" in the left sidebar navigation
2. **Check Routes**: Navigate to `/app/accounts/1/captain/assistants`
3. **Check Console**: 
   ```bash
   rails console
   Account.first.feature_enabled?('captain_integration')  # Should return true
   ```

## Troubleshooting

### Captain still not showing?
1. Clear browser cache and hard refresh (Cmd+Shift+R / Ctrl+Shift+F5)
2. Check browser console for JavaScript errors
3. Verify you're logged in as an administrator or agent
4. Check that the feature flag is enabled: `Account.first.enabled_features`

### Routes returning 404?
- Ensure `INSTALLATION_TYPE=enterprise` is set in `.env`
- Restart the Rails server after changing `.env`
- Check that captain routes are loaded: `rails routes | grep captain`

### AI features not working?
- Add OpenAI API key to `.env`
- Check `log/development.log` for API errors
- Verify API key has sufficient credits

## Related Files

- Feature flags: `config/features.yml`
- Captain routes: `app/javascript/dashboard/routes/dashboard/captain/captain.routes.js`
- Feature flags JS: `app/javascript/dashboard/featureFlags.js`
- Sidebar navigation: `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`