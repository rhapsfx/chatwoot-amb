# Bot Studio - Visual Flow Editor & Template System

**Status**: ✅ **Phase 1 & 2 Complete** (Deployed Jan 2025)

## Overview

Bot Studio is a visual flow editor for creating Apple Messages for Business bot conversation flows using a drag-and-drop node-based interface.

**Key Features**:
- Visual flow design with 5 node types (State, Intent, Template, Action, Condition)
- Template-based message system (12 template types)
- Flow validation with error highlighting
- Template browser with 4 pre-built flow templates
- Real-time flow testing and simulation

## Critical: Flow Activation Requirement

**🚨 IMPORTANT**: For a bot flow to execute in production, it MUST have BOTH flags set to `true`:
- `is_active: true` - Flow is activated
- `is_published: true` - Flow is published and ready

**How FlowExecutorService Selects Flows**:
```ruby
# In IncomingMessageService (line 1297)
active_flow = configured_bot.bot_flows.active.published.first
```

If a flow is NOT active+published, the system falls back to legacy `AcousticHouseBotService`.

## Activating Flows

**For Existing Flows** (created before Jan 2025):
```bash
rails runner script/activate_master_bot_flow.rb
```

This script:
1. Finds the Acoustic House Master Bot
2. Sets `is_active: true` and `is_published: true`
3. Verifies the flow will be picked up by FlowExecutorService

**For New Flows**:
- Flows created via `script/create_acoustic_house_master_bot.rb` (updated) are automatically activated
- Flows created via Bot Studio UI default to `is_active: false, is_published: false` (draft mode)

## Checking Flow Status

**Via Logs** - When bot processes a message, check for:
```
✅ CORRECT (using visual flow):
[Bot] 🤖 Using configured AMB bot: Acoustic House Master Bot (ID: 18)
[Bot] 🎨 Bot has active flow: 'Acoustic House Flow' (ID: 5)
[Bot] 🚀 Using FlowExecutorService for visual bot flow

❌ INCORRECT (using legacy handlers):
[Bot] 📜 No active flow found - using legacy AcousticHouseBotService
[Bot] 🎯 handle_welcome called - State: AHA1
```

**Via Database** (if needed):
```bash
rails runner "
bot = AgentBot.find_by(name: 'Acoustic House Master Bot')
flow = bot.bot_flows.first
puts \"is_active: #{flow.is_active}\"
puts \"is_published: #{flow.is_published}\"
"
```

## UI Flow Status Display

**Current State** (Phase 2):
- Flow activation status is NOT visible in UI
- Users must check logs or database to verify activation

**Planned Enhancement** (Phase 3+):
- Show flow publish status in **Inbox Assignments** dialog when assigning bots
- Display: "Status: ✅ Active (Flow Published)" or "Status: ⚠️ Active (Flow Unpublished)"
- Add "Publish Flow" button in Inbox Assignments dialog
- Avoids cluttering Bot Studio toolbar (already has 10 buttons)

**User Feedback**: Flow status should be visible at inbox assignment level, not buried in Bot Studio UI.

## Template System Architecture

**Template Execution Flow**:
```
1. User message arrives
   ↓
2. IncomingMessageService checks for active+published flow
   ↓
3. FlowExecutorService.execute(flow, conversation, message)
   ↓
4. Flow finds matching intent/state node
   ↓
5. Node actions reference BotActionTemplate by ID
   ↓
6. TemplateExecutorService.execute(template)
   ↓
7. Template sends message via Apple MSP
```

**12 Template Types**:
1. `send_text_message` - Plain text
2. `send_rich_link` - Links with metadata
3. `send_list_picker` - Interactive list selection
4. `send_time_picker` - Date/time selection
5. `send_form` - Multi-field forms
6. `send_apple_pay` - Payment requests
7. `send_quick_reply` - Quick reply buttons
8. `send_imessage_app` - iMessage app integration
9. `send_app_clip` - App Clip invocation
10. `send_authentication` - OAuth authentication
11. `send_location` - Location picker
12. `send_typing_indicator` - Typing indicators

**Template Storage**:
- Model: `BotActionTemplate` (database-stored, reusable)
- Location: `app/models/bot_action_template.rb`
- Templates belong to account (account-scoped)

## Acoustic House Master Bot - Reference Bot

**Important**: Bot 18 ("Acoustic House Master Bot") is a **reference/demo bot**, NOT a working conversational bot.

**Purpose**: Visual reference showcasing all 12 template types in a single flow.

**What It Demonstrates**:
- ✅ All 12 template types (send_text, send_list_picker, send_time_picker, etc.)
- ✅ Visual flow structure with 13 nodes
- ✅ How to connect states, intents, and actions
- ✅ Template ID referencing pattern
- ✅ Node positioning and layout

**What It's NOT For**:
- ❌ Production conversations - Intent nodes have no keywords
- ❌ Live customer interactions - No conversation logic
- ❌ Testing message flows - States may not transition properly

**Why It Doesn't Respond to User Messages**:
1. **Intent nodes have empty keywords** - Won't match user input like "hi" or "start"
2. **No conversation flow logic** - Just demonstrates template usage
3. **State transitions are simplified** - Designed for visual inspection, not execution

**How to Use It**:
1. Open Bot 18 in Bot Studio to view the visual flow
2. Examine node configurations as examples
3. Copy template patterns to your own bots
4. Use as architectural reference when building real conversational bots

**Creating a Working Bot**:
To create a production-ready conversational bot:
1. Start with Bot 18 as a visual reference
2. Add keywords to intent nodes (e.g., `keywords: ['start', 'hello', 'help']`)
3. Design proper conversation flow logic
4. Add state transitions based on user input
5. Test thoroughly before assigning to production inbox

**Reference Script**: `script/create_acoustic_house_master_bot.rb`

## Related Documentation

- **Bot Studio UI**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/BotStudio.vue`
- **FlowExecutorService**: `app/services/apple_messages_for_business/flow_executor_service.rb`
- **TemplateExecutorService**: `app/services/apple_messages_for_business/template_executor_service.rb`
- **BotFlow Model**: `app/models/bot_flow.rb`
- **Test Specs**: `spec/services/apple_messages_for_business/flow_executor_service_spec.rb`

## Troubleshooting

**Problem**: Bot using legacy handlers instead of visual flow

**Solution**: Check flow activation
```bash
rails runner script/activate_master_bot_flow.rb
```

**Problem**: Flow validation errors

**Solution**: Common issues
- Intent nodes without keywords → Add keywords or mark scope as 'global'
- State nodes without outgoing connections → Add transitions or mark as terminal
- Duplicate state_id values → Ensure unique state_id for each state node

**Problem**: Templates not loading in Template Browser

**Solution**: Check API endpoint and policy
- Endpoint: `/api/v1/accounts/:account_id/agent_bots/:bot_id/flows/templates`
- Policy: `AgentBotPolicy#templates?` must allow access
- Templates need `metadata['is_template'] = true` and `is_published = true`