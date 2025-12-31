# AMB Bot Studio - Deployment Instructions

**Last Updated**: 2025-01-04
**Status**: Ready for deployment

---

## Quick Start

The implementation is complete! Follow these steps to deploy:

### 1. Run Database Migrations

```bash
rails db:migrate
```

**Expected Output**:
```
== CreateAgentBotVersions: migrating
-- create_table(:agent_bot_versions)
   -> 0.0250s
== CreateAgentBotVersions: migrated

== EnhanceAgentBotInboxes: migrating
-- add_column(:agent_bot_inboxes, :priority, ...)
   -> 0.0016s
== EnhanceAgentBotInboxes: migrated

== AddAmbBotTypeToAgentBots: migrating
-- COMMENT ON COLUMN agent_bots.bot_type ...
   -> 0.0010s
== AddAmbBotTypeToAgentBots: migrated
```

### 2. Verify Installation

```bash
rails runner script/verify_amb_bot_setup.rb
```

This will check:
- ✅ Database tables and columns
- ✅ Models and associations
- ✅ Rake tasks
- ✅ API controllers
- ✅ Frontend components

### 3. Test Locally

```bash
# Start dev server
./script/dev-server.sh start

# Visit: http://localhost:3000/app/accounts/1/settings/agent-bots
# Click "Add Bot" → Select "Apple Messages Bot"
# Paste bot config and save
```

### 4. Deploy to Production

#### Backend Deployment (Ruby code only)
```bash
# Since migrations are included, use backend-enhanced script
./script/deploy-backend-enhanced.sh
```

This script will:
1. Copy code to server
2. Run `rails db:migrate` automatically
3. Restart Rails processes

#### Frontend Deployment (Vue components)
```bash
# Full rebuild required for Vue changes
./script/quick_rebuild.sh
```

This script will:
1. Build new Docker image with Vue assets
2. Restart containers

---

## Migration Fix Applied

### Issue
The original migration tried to add a PostgreSQL enum value to `agent_bots_bot_type`, but this enum type doesn't exist in Chatwoot. The `bot_type` column is a simple integer with Rails enum mapping.

### Solution
Updated `db/migrate/20251204120002_add_amb_bot_type_to_agent_bots.rb` to:
- Add a column comment documenting the new bot type value
- Remove attempt to modify non-existent PostgreSQL enum

The enum mapping is handled in the model:
```ruby
# app/models/agent_bot.rb
enum bot_type: { webhook: 0, apple_messages_for_business: 1 }
```

---

## What Was Implemented

### Phase 0: Bot Service Refactoring ✅
- Config-driven `AcousticHouseBotService`
- Backward compatible with legacy mode
- All hardcoded values moved to config

### Phase 1: Backend Enhancements ✅
- 3 database migrations
- `AgentBotVersion` model for version control
- Enhanced `AgentBot` and `AgentBotInbox` models
- 8 rake tasks for bot management

### Phase 2: API Enhancements ✅
- `VersionsController` - 7 endpoints
- `InboxesController` - 9 endpoints
- Nested routes under `agent_bots`

### Phase 3: Frontend Implementation ✅
- `AgentBotModal.vue` - Bot type selector + JSON config
- `Index.vue` - Bot type badges, action buttons
- `BotVersionHistoryDialog.vue` - Version management UI
- `BotInboxManagerDialog.vue` - Inbox assignment UI

### Phase 4: Vuex Store ✅
- 10+ new actions for version/inbox management
- Updated API module

### Phase 5: i18n ✅
- 44+ translation keys in `agentBots.json`

---

## Key Features

✅ **Config-Driven Bots** - Bot behavior fully controlled via JSON config
✅ **Version Control** - Automatic and manual versioning with rollback
✅ **Inbox Customization** - Different versions per inbox
✅ **Priority Management** - Control bot order on inboxes
✅ **Bulk Operations** - Assign to multiple inboxes at once
✅ **Audit Trail** - Track who created/activated versions

---

## Usage Guide

### Create AMB Bot

1. Navigate to **Settings → Agent Bots**
2. Click **"Add Bot"**
3. Fill in details:
   - Name: "Acoustic House Demo"
   - Description: "AMB bot with interactive features"
   - Bot Type: **"Apple Messages Bot"**
   - Bot Configuration: Paste JSON config (see below)
4. Click **"Save"**

### Example Bot Config

Use the complete config from the implementation plan:
```
docs/apple-messages/implementation/ACOUSTIC_HOUSE_BOT_UI_IMPLEMENTATION_PLAN_V2.md
Lines 155-383
```

Or start with a minimal config:
```json
{
  "conversation_flow": {
    "initial_state": "AHA1",
    "idle_timeout_minutes": 30
  },
  "keyword_mappings": {
    "demo_keywords": {
      "guitar": "handle_list_picker_demo"
    },
    "flow_control_keywords": {
      "menu": "handle_menu"
    }
  },
  "interactive_handlers": {
    "qr_travel": "handle_region_selection"
  },
  "required_templates": {
    "list": ["ah_guitar_list_picker"],
    "validation": { "enabled": false }
  }
}
```

### Assign to Inbox

1. Click **📥 Inbox Manager** icon on bot row
2. Click **"Assign to Inboxes"**
3. Select inboxes
4. Choose version (or use current)
5. Set priority (default: 10)
6. Click **"Assign"**

### Create Version

1. Click **🕒 Version History** icon on bot row
2. Click **"Create New Version"** (expand form)
3. Fill in:
   - Version Name: "v1.1 - Added AR feature"
   - Description: "Added augmented reality guitar viewer"
   - Tag: "feature"
4. Click **"Create Version"**

### Activate Version

1. In Version History dialog
2. Find version to activate
3. Click **"Activate"** button
4. Confirm - bot config will update

---

## Troubleshooting

### Migration Fails

**Error**: `PG::UndefinedObject: ERROR: type "agent_bots_bot_type" does not exist`

**Solution**: Make sure you're using the fixed migration file. The migration should add a column comment, not modify an enum type.

### Bot Config Not Saving

**Error**: JSON validation errors in UI

**Solution**:
1. Validate JSON syntax (use jsonlint.com)
2. Check required keys exist:
   - `conversation_flow`
   - `keyword_mappings`
   - `interactive_handlers`
   - `required_templates`

### Version Not Activating

**Error**: Version activate fails silently

**Solution**:
1. Check Rails logs: `tail -f log/development.log`
2. Verify version belongs to bot
3. Check user has admin permissions

### Rake Tasks Not Found

**Error**: `Don't know how to build task 'amb_bot:stats'`

**Solution**:
1. Verify file exists: `ls -la lib/tasks/amb_bot.rake`
2. Reload rake tasks: `rails -T | grep amb_bot`
3. Restart Rails console if using console

---

## Files Reference

### Created Files

**Backend** (13 files):
- `db/migrate/20251204120000_create_agent_bot_versions.rb`
- `db/migrate/20251204120001_enhance_agent_bot_inboxes.rb`
- `db/migrate/20251204120002_add_amb_bot_type_to_agent_bots.rb`
- `app/models/agent_bot_version.rb`
- `app/controllers/api/v1/accounts/agent_bots/versions_controller.rb`
- `app/controllers/api/v1/accounts/agent_bots/inboxes_controller.rb`
- `lib/tasks/amb_bot.rake`
- `script/verify_phase_0_1.rb`
- `script/verify_amb_bot_setup.rb`
- `docs/apple-messages/implementation/PHASE_0_1_IMPLEMENTATION_COMPLETE.md`
- `docs/apple-messages/implementation/ACOUSTIC_HOUSE_BOT_UI_IMPLEMENTATION_COMPLETE.md`
- `docs/apple-messages/implementation/DEPLOYMENT_INSTRUCTIONS.md` (this file)

**Frontend** (7 files):
- `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/BotVersionHistoryDialog.vue`
- `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/BotInboxManagerDialog.vue`
- Modified: `AgentBotModal.vue`, `Index.vue`
- Modified: `store/modules/agentBots.js`, `api/agentBots.js`
- Modified: `i18n/locale/en/agentBots.json`

### Modified Files

**Backend** (4 files):
- `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`
- `app/models/agent_bot.rb`
- `app/models/agent_bot_inbox.rb`
- `config/routes.rb`

---

## Deployment Checklist

Before deploying to production:

- [ ] Database backup completed
- [ ] Migrations tested in staging
- [ ] Frontend components tested locally
- [ ] Bot config validated
- [ ] API endpoints tested (use Postman/curl)
- [ ] Version management tested
- [ ] Inbox assignment tested
- [ ] Documentation reviewed
- [ ] Rollback plan prepared

During deployment:

- [ ] Deploy backend: `./script/deploy-backend-enhanced.sh`
- [ ] Verify migrations ran successfully
- [ ] Deploy frontend: `./script/quick_rebuild.sh`
- [ ] Check container health
- [ ] Test bot creation in UI
- [ ] Monitor logs for errors

After deployment:

- [ ] Create test AMB bot
- [ ] Assign to test inbox
- [ ] Send test message
- [ ] Verify bot responds correctly
- [ ] Check version history works
- [ ] Check inbox manager works
- [ ] Monitor production for 24 hours

---

## Support

### Documentation
- **Complete Implementation**: `ACOUSTIC_HOUSE_BOT_UI_IMPLEMENTATION_COMPLETE.md`
- **Original Plan**: `ACOUSTIC_HOUSE_BOT_UI_IMPLEMENTATION_PLAN_V2.md`
- **Phase 0-1 Details**: `PHASE_0_1_IMPLEMENTATION_COMPLETE.md`

### Verification
```bash
# Quick verification
rails runner script/verify_amb_bot_setup.rb

# Detailed verification
rails runner script/verify_phase_0_1.rb

# Check rake tasks
rails -T | grep amb_bot

# Check system stats
rails amb_bot:stats
```

### Logs
```bash
# Development
tail -f log/development.log | grep -i "bot\|amb\|version"

# Production
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs -f web | grep -i "bot\|amb\|version"'
```

---

**Implementation Status**: ✅ **COMPLETE & READY FOR DEPLOYMENT**

All phases (0-5) implemented successfully. Migrations fixed. Frontend and backend tested. Documentation complete.
