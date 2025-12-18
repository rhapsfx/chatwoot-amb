# Bot Studio Documentation Index

## Quick Start Guides

### For Bot Builders

1. **[Handler Methods Reference](./HANDLER_METHODS_REFERENCE.md)** - **START HERE**
   - Complete list of available handler methods
   - How to use handlers in State, Intent, and Action nodes
   - Handler method types: State handlers, Keyword handlers, Interactive handlers
   - Examples and best practices

2. **[Bot Configuration Storage Guide](./BOT_CONFIG_STORAGE_GUIDE.md)** - **IMPORTANT**
   - Where bot settings are stored (`bot_config` JSONB column)
   - How to edit configuration via UI (Settings → Agent Bots → Edit Bot)
   - Configuration hierarchy (bot-level, version-level, inbox-level)
   - JSON structure and examples
   - Typing indicators, conversation flow, keyword mappings
   - Future UI enhancements

3. **[Bot Configuration Guide](./BOT_CONFIGURATION_GUIDE.md)**
   - Typing indicators configuration (LEGACY - hardcoded constants)
   - Conversation timeout settings
   - Required templates management
   - Environment-specific configuration
   - Current limitations and workarounds

### For Developers

3. **[Bot Studio Architecture](./BOT_STUDIO_ARCHITECTURE.md)**
   - System architecture overview
   - Component breakdown
   - Data flow diagrams
   - Technical decisions

4. **[Bot Studio Integration Plan](./BOT_STUDIO_INTEGRATION_PLAN.md)**
   - Integration with existing Chatwoot systems
   - API endpoints
   - Database schema
   - Migration strategies

5. **[Visual Bot Studio Implementation Plan](./VISUAL_BOT_STUDIO_IMPLEMENTATION_PLAN.md)**
   - Phase-by-phase implementation roadmap
   - Feature priorities
   - Technical requirements
   - Timeline and milestones

## Common Tasks

### Building a Bot Flow

**Prerequisites**:
- Read [Handler Methods Reference](./HANDLER_METHODS_REFERENCE.md) to understand available handlers
- Check [Bot Configuration Guide](./BOT_CONFIGURATION_GUIDE.md) for configuration options

**Steps**:
1. **Open Bot Studio**: Agent Bots → [Bot] → "Open Visual Studio"
2. **Add State Nodes**: Drag State node from palette
   - Set State ID (e.g., `AHA1`, `WELCOME`)
   - Set Label (e.g., "Welcome Message")
   - Set Handler Method (e.g., `handle_welcome`) - [See available handlers](./HANDLER_METHODS_REFERENCE.md#state-handler-methods)
3. **Add Intent Nodes**: Drag Intent node from palette
   - Set Keywords (e.g., "menu, help")
   - Set Handler Method (e.g., `handle_menu`) - [See keyword handlers](./HANDLER_METHODS_REFERENCE.md#keyword-handler-methods)
4. **Add Template Nodes**: Drag Template node from palette
   - Select template (List Picker, Time Picker, Form)
5. **Connect Nodes**: Draw edges between nodes to define flow
6. **Save Flow**: Click "Save Flow" button
7. **Test Flow**: Click "Compile & Test" button

### Understanding Handler Methods

**Quick Reference**:

| Handler Type | Purpose | Documentation Link |
|-------------|---------|-------------------|
| State Handlers | Control bot behavior at specific conversation states | [State Handler Methods](./HANDLER_METHODS_REFERENCE.md#1-state-handler-methods) |
| Keyword Handlers | Respond to user text keywords | [Keyword Handler Methods](./HANDLER_METHODS_REFERENCE.md#2-keyword-handler-methods) |
| Interactive Handlers | Process interactive template responses | [Interactive Handler Methods](./HANDLER_METHODS_REFERENCE.md#3-interactive-handler-methods) |

**Example Handlers**:
- `handle_welcome` - Welcome message (State: AHA1)
- `handle_region_prompt` - Ask for region (State: AHA2)
- `handle_guitar_selection` - Process guitar list picker (Interactive: lp_guitar_0319)
- `handle_menu` - Show menu (Keyword: "menu")
- `handle_start_over` - Restart conversation (Keyword: "startover")

**Full List**: See [Handler Methods Reference](./HANDLER_METHODS_REFERENCE.md)

### Configuring Typing Indicators

**Current Method** (Requires code edit):
1. Edit `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`
2. Modify `TYPING_INDICATORS_ENABLED` (true/false)
3. Modify `TYPING_INDICATOR_DELAY` (seconds)
4. Restart application

**Details**: See [Bot Configuration Guide - Typing Indicators](./BOT_CONFIGURATION_GUIDE.md#1-typing-indicators)

**Future**: UI-based configuration coming in Phase 7+

### Testing Your Bot

**Quick Test**:
1. Open Bot Studio
2. Make changes to flow
3. Click "Save Flow"
4. Click "Compile & Test"
5. Test in Apple Messages channel

**Detailed Testing**:
1. **Test Each State**: Verify handler methods work correctly
2. **Test Keywords**: Send keyword messages to trigger handlers
3. **Test Interactive Elements**: Click List Picker items, Time Picker, etc.
4. **Test Error Cases**: Invalid input, missing templates, etc.
5. **Test Timeout**: Wait 30+ minutes to verify conversation reset

## Node Types Reference

### State Node
- **Purpose**: Define conversation states
- **Fields**:
  - State ID: Unique identifier (e.g., `AHA1`)
  - Label: Display name (e.g., "Welcome")
  - Handler Method: Ruby method name (e.g., `handle_welcome`)
  - Description: Notes about state
- **Example**: [State Node Config](./HANDLER_METHODS_REFERENCE.md#in-state-nodes)

### Intent Node
- **Purpose**: Match user keywords and trigger actions
- **Fields**:
  - Keywords: Comma-separated list (e.g., "menu, help")
  - Handler Method: Keyword handler (e.g., `handle_menu`)
  - Exact Match: Case-sensitive matching
- **Example**: [Intent Node Config](./HANDLER_METHODS_REFERENCE.md#in-intent-nodes)

### Template Node
- **Purpose**: Send Apple Messages templates
- **Types**:
  - List Picker: Multiple-choice selection
  - Time Picker: Date/time selection
  - Form: Multi-field form
  - Quick Reply: Quick response buttons
- **Configuration**: Template-specific settings

### Action Node
- **Purpose**: Perform actions (send message, update state, etc.)
- **Fields**:
  - Action Type: Type of action
  - Handler Method: Action handler
  - Label: Display name

### Condition Node
- **Purpose**: Branching logic based on conditions
- **Fields**:
  - Expression: Condition to evaluate
  - True Branch: Next node if true
  - False Branch: Next node if false

## Troubleshooting

### Handler Method Not Found

**Symptoms**: Bot doesn't respond or throws error about missing handler

**Solutions**:
1. Check spelling of handler method name
2. Verify method exists in [Handler Methods Reference](./HANDLER_METHODS_REFERENCE.md)
3. Check state/keyword/identifier mapping matches

**Example**:
```
❌ handler: "handleWelcome"  # Wrong: camelCase
✅ handler: "handle_welcome" # Correct: snake_case
```

### Typing Indicators Not Working

**Symptoms**: Messages appear instantly without typing animation

**Solutions**:
1. Check `TYPING_INDICATORS_ENABLED = true` in bot service
2. Verify `TYPING_INDICATOR_DELAY` is set (default: 1.5)
3. Restart application after configuration changes

**Details**: [Bot Configuration Guide - Typing Indicators](./BOT_CONFIGURATION_GUIDE.md#1-typing-indicators)

### Missing Template Error

**Symptoms**: Bot crashes or skips steps mentioning missing templates

**Solutions**:
1. Check required templates exist:
   ```ruby
   result = AcousticHouseBotService.verify_templates_exist(account_id)
   ```
2. Create missing templates in Bot Studio
3. Update `REQUIRED_TEMPLATES` array if needed

**Details**: [Bot Configuration Guide - Required Templates](./BOT_CONFIGURATION_GUIDE.md#3-required-templates)

### Flow Not Updating

**Symptoms**: Changes in Bot Studio don't reflect in bot behavior

**Solutions**:
1. Click "Save Flow" button after changes
2. Click "Compile & Test" to apply changes
3. Verify flow compiled successfully (check logs)
4. Clear conversation state: send "reset" or "startover"

## API Reference

### Bot Flow APIs

**Base URL**: `/api/v1/accounts/:account_id/agent_bots/:bot_id/flows`

**Endpoints**:
- `GET /` - List all flows
- `POST /` - Create new flow
- `GET /:flow_id` - Get flow details
- `PATCH /:flow_id` - Update flow
- `DELETE /:flow_id` - Delete flow
- `POST /:flow_id/compile` - Compile flow to bot config

**Example**:
```javascript
// Get flows
const flows = await store.dispatch('agentBots/getFlows', botId);

// Create flow
const result = await store.dispatch('agentBots/createFlow', {
  botId,
  name: 'My Flow',
  flow_data: { nodes: [], edges: [] }
});

// Update flow
await store.dispatch('agentBots/updateFlow', {
  botId,
  flowId,
  flow_data: { nodes: [...], edges: [...] }
});
```

## Version History

### Current Version: Phase 6 (Version Management)

**Features**:
- ✅ Visual flow editor with drag-and-drop
- ✅ State, Intent, Template, Action, Condition nodes
- ✅ Flow import/export (JSON)
- ✅ Flow compilation to bot config
- ✅ Flow validation
- ✅ Version management (create, activate, archive, compare)
- ✅ Dark mode support

**Documentation**:
- ✅ Handler Methods Reference (this release)
- ✅ Bot Configuration Guide (this release)
- ✅ Architecture documentation
- ✅ Integration plan
- ✅ Implementation plan

### Upcoming Features (Phase 7+)

**Planned**:
- [ ] UI-based bot configuration (typing indicators, timeouts)
- [ ] Handler method autocomplete in editors
- [ ] Template visual preview in nodes
- [ ] Flow debugging tools
- [ ] Performance analytics
- [ ] A/B testing support

## Getting Help

### Documentation

- **Handler Methods**: [HANDLER_METHODS_REFERENCE.md](./HANDLER_METHODS_REFERENCE.md)
- **Configuration**: [BOT_CONFIGURATION_GUIDE.md](./BOT_CONFIGURATION_GUIDE.md)
- **Architecture**: [BOT_STUDIO_ARCHITECTURE.md](./BOT_STUDIO_ARCHITECTURE.md)
- **Integration**: [BOT_STUDIO_INTEGRATION_PLAN.md](./BOT_STUDIO_INTEGRATION_PLAN.md)
- **Implementation**: [VISUAL_BOT_STUDIO_IMPLEMENTATION_PLAN.md](./VISUAL_BOT_STUDIO_IMPLEMENTATION_PLAN.md)

### Apple Messages Integration

- **Integration Status**: [AMB_INTEGRATION_STATUS_REPORT.md](../apple-messages/AMB_INTEGRATION_STATUS_REPORT.md)
- **Dependency Map**: [AMB_DEPENDENCY_MAP.md](../apple-messages/AMB_DEPENDENCY_MAP.md)
- **Case Normalization**: [case-normalization-specification.md](../apple-messages/case-normalization-specification.md)
- **Image Architecture**: [IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md](../apple-messages/IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md)

### Code Reference

**Bot Service Classes**:
- `app/services/apple_messages_for_business/acoustic_house_bot_service.rb` - Main bot service
- `app/services/apple_messages_for_business/bot_service.rb` - Base bot service
- `app/services/apple_messages_for_business/send_message_service.rb` - Message sending
- `app/services/apple_messages_for_business/send_*_service.rb` - Template services

**Bot Studio Frontend**:
- `app/javascript/dashboard/routes/dashboard/settings/agentBots/BotStudio.vue` - Main studio
- `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/BotStudioCanvas.vue` - Canvas
- `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/editors/*` - Node editors
- `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/nodes/*` - Node components

**Bot Models**:
- `app/models/agent_bot.rb` - Bot model
- `app/models/bot_flow.rb` - Flow model
- `app/models/message_template.rb` - Template model

## Contributing

### Adding New Handler Methods

1. **Define Method**: Add method to bot service class
2. **Add Mapping**: Add to appropriate constant (KEYWORD_HANDLERS, INTERACTIVE_HANDLERS)
3. **Add State**: Add to `process_state` case statement (if state-based)
4. **Document**: Update [HANDLER_METHODS_REFERENCE.md](./HANDLER_METHODS_REFERENCE.md)
5. **Test**: Test via Bot Studio and manual testing

**Example**:
```ruby
# 1. Define method
def handle_custom_flow
  send_text_message('Custom flow message')
  update_bot_state('CUSTOM_STATE')
end

# 2. Add mapping
DEMO_KEYWORDS = {
  # ...existing
  'custom' => :handle_custom_flow
}.freeze

# 3. Add state
def process_state
  case @bot_state
  # ...existing
  when 'CUSTOM_STATE'
    handle_custom_flow
  end
end
```

### Updating Documentation

When adding features:
1. Update relevant guide ([Handler Methods](./HANDLER_METHODS_REFERENCE.md), [Configuration](./BOT_CONFIGURATION_GUIDE.md))
2. Update this index with new sections
3. Add examples and troubleshooting
4. Update version history

## Glossary

- **Handler Method**: Ruby method that controls bot behavior at specific points
- **State**: Point in conversation flow (e.g., waiting for user response)
- **State ID**: Unique identifier for a state (e.g., `AHA1`, `WELCOME`)
- **Node**: Visual element in Bot Studio representing state, intent, template, etc.
- **Edge**: Connection between nodes defining flow direction
- **Flow**: Complete bot conversation flow (nodes + edges)
- **Template**: Apple Messages interactive element (List Picker, Time Picker, Form)
- **Typing Indicator**: Animation showing "bot is typing..."
- **Request Identifier**: Unique ID for interactive template responses
- **Keyword**: Text trigger for bot actions (e.g., "menu", "reset")

---

**Last Updated**: 2025-12-09
**Bot Studio Version**: Phase 6 (Version Management)
**Documentation Version**: 1.0
