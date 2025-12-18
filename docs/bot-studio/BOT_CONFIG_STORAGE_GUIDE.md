# Bot Configuration Storage & UI Guide

## Overview

Bot configuration in Chatwoot is stored per-bot in the `agent_bots.bot_config` JSONB column. This allows each bot to have its own unique configuration including typing indicators, conversation flow, keyword mappings, and more.

## Current Configuration UI

### Location in Chatwoot UI

**Path**: Settings → Agent Bots → [Create/Edit Bot] → Bot Configuration

**Access**:
1. Navigate to Settings → Agent Bots
2. Click "Add Bot" (for new bot) or "Edit" button on existing bot
3. Select "Apple Messages" as Bot Type
4. The "Bot Configuration" field appears

### Bot Configuration Field

**Type**: JSON textarea (manual JSON editing)
**Stored in**: `agent_bots.bot_config` (JSONB column)
**Required for**: Apple Messages for Business (AMB) bots
**Optional for**: Webhook bots

**UI Component**: `AgentBotModal.vue` (lines 405-422)

```vue
<!-- Bot Config (only for AMB type) -->
<div v-if="showBotConfig" class="flex flex-col gap-2">
  <label class="text-sm font-medium text-n-slate-12">
    {{ $t('AGENT_BOTS.FORM.BOT_CONFIG.LABEL') }}
  </label>
  <textarea
    v-model="formState.botConfig"
    class="w-full px-3 py-2 text-sm font-mono bg-n-slate-1 dark:bg-n-slate-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8 min-h-[200px] max-h-[400px]"
    :class="{ 'border-ruby-8': jsonError }"
    :placeholder="$t('AGENT_BOTS.FORM.BOT_CONFIG.PLACEHOLDER')"
    @blur="v$.botConfig.$touch()"
  />
  <p v-if="jsonError" class="text-xs text-ruby-11">
    {{ jsonError }}
  </p>
  <p v-else class="text-xs text-n-slate-11">
    {{ $t('AGENT_BOTS.FORM.BOT_CONFIG.HELP') }}
  </p>
</div>
```

## Database Schema

### Agent Bot Model

**Table**: `agent_bots`
**File**: `app/models/agent_bot.rb`

**Key Columns**:
- `id` (bigint, primary key)
- `name` (string) - Bot name
- `description` (string) - Bot description
- `bot_type` (integer) - 0 = webhook, 1 = apple_messages_for_business
- `bot_config` (jsonb) - **Bot configuration JSON**
- `outgoing_url` (string) - Webhook URL (for webhook bots)
- `account_id` (bigint) - Account owner

**bot_config Structure**:
```json
{
  "typing_indicators": {
    "enabled": true,
    "delay": 1.5
  },
  "conversation_flow": {
    "states": {
      "AHA1": {
        "handler": "handle_welcome",
        "next_state": "AHA2"
      },
      "AHA2": {
        "handler": "handle_region_prompt",
        "next_state": "AHA3"
      }
    }
  },
  "keyword_mappings": {
    "demo": {
      "guitar": "handle_list_picker_demo",
      "form": "handle_form_demo"
    },
    "flow_control": {
      "menu": "handle_menu",
      "reset": "handle_start_over"
    }
  },
  "interactive_handlers": {
    "qr_travel": "handle_region_selection",
    "lp_guitar_0319": "handle_guitar_selection",
    "time_0319": "handle_time_picker_response"
  },
  "required_templates": [
    "ah_guitar_list_picker",
    "ah_guitar_info_form",
    "ah_main_menu"
  ]
}
```

## Configuration Hierarchy

### 3-Level Configuration System

Chatwoot supports a hierarchical configuration system for AMB bots:

1. **Bot-Level Config** (`agent_bots.bot_config`)
   - Default configuration for the bot
   - Used when no version or inbox overrides exist

2. **Version-Level Config** (`agent_bot_versions.config`)
   - Version-specific configuration
   - Overrides bot-level config when version is active

3. **Inbox-Level Config** (`agent_bot_inboxes.config_overrides`)
   - Inbox-specific configuration overrides
   - Allows per-inbox customization
   - Merged with version/bot config

**Resolution Order**:
```ruby
def effective_config(inbox_id: nil)
  base_config = active_version&.config || bot_config

  return base_config unless inbox_id

  # Merge with inbox-specific overrides if provided
  inbox_association = agent_bot_inboxes.find_by(inbox_id: inbox_id)
  return base_config unless inbox_association&.config_overrides.present?

  base_config.deep_merge(inbox_association.config_overrides)
end
```

## How to Edit Bot Configuration

### Method 1: Via Chatwoot UI (Current)

1. **Navigate**: Settings → Agent Bots
2. **Edit Bot**: Click "Edit" button on bot
3. **Select Type**: Choose "Apple Messages" as Bot Type
4. **Edit JSON**: Modify the "Bot Configuration" textarea
5. **Validate**: JSON is automatically validated on blur
6. **Save**: Click "Update Bot"

**Validation**:
- JSON syntax must be valid
- Required keys for AMB bots: `conversation_flow`, `keyword_mappings`, `interactive_handlers`, `required_templates`
- Validation runs in `agent_bot.rb` (lines 146-153)

### Method 2: Via Rails Console

```ruby
# Find bot
bot = AgentBot.find(bot_id)

# View current config
puts JSON.pretty_generate(bot.bot_config)

# Update config
bot.update!(
  bot_config: {
    typing_indicators: {
      enabled: true,
      delay: 1.5
    },
    conversation_flow: { ... },
    keyword_mappings: { ... },
    interactive_handlers: { ... },
    required_templates: [ ... ]
  }
)

# Save
bot.save!
```

### Method 3: Via API

**Endpoint**: `PATCH /api/v1/accounts/:account_id/agent_bots/:id`

**Request Body**:
```json
{
  "name": "My Bot",
  "description": "Bot description",
  "bot_type": "apple_messages_for_business",
  "bot_config": {
    "typing_indicators": {
      "enabled": true,
      "delay": 1.5
    },
    "conversation_flow": { ... },
    "keyword_mappings": { ... },
    "interactive_handlers": { ... },
    "required_templates": [ ... ]
  }
}
```

## Configuration Options

### Typing Indicators

**Current Status**: Configurable per bot via `bot_config`

**Structure**:
```json
{
  "typing_indicators": {
    "enabled": true,
    "delay": 1.5
  }
}
```

**Fields**:
- `enabled` (boolean) - Enable/disable typing indicators
- `delay` (number) - Delay in seconds before sending message

**Usage in Bot Service**:
```ruby
def typing_indicators_enabled?
  @config&.dig('typing_indicators', 'enabled') ||
    self.class::TYPING_INDICATORS_ENABLED
end

def typing_indicator_delay
  @config&.dig('typing_indicators', 'delay') ||
    self.class::TYPING_INDICATOR_DELAY
end
```

### Conversation Flow

**Structure**:
```json
{
  "conversation_flow": {
    "states": {
      "STATE_ID": {
        "handler": "handler_method_name",
        "next_state": "NEXT_STATE_ID",
        "description": "State description"
      }
    }
  }
}
```

**Example**:
```json
{
  "conversation_flow": {
    "states": {
      "AHA1": {
        "handler": "handle_welcome",
        "next_state": "AHA2",
        "description": "Welcome message"
      },
      "AHA2": {
        "handler": "handle_region_prompt",
        "next_state": "AHA3",
        "description": "Ask for customer region"
      }
    }
  }
}
```

### Keyword Mappings

**Structure**:
```json
{
  "keyword_mappings": {
    "category": {
      "keyword": "handler_method_name"
    }
  }
}
```

**Example**:
```json
{
  "keyword_mappings": {
    "demo": {
      "guitar": "handle_list_picker_demo",
      "form": "handle_form_demo",
      "ar": "handle_ar_demo"
    },
    "flow_control": {
      "menu": "handle_menu",
      "reset": "handle_start_over",
      "stop": "handle_stop"
    }
  }
}
```

### Interactive Handlers

**Structure**:
```json
{
  "interactive_handlers": {
    "request_identifier": "handler_method_name"
  }
}
```

**Example**:
```json
{
  "interactive_handlers": {
    "qr_travel": "handle_region_selection",
    "lp_guitar_0319": "handle_guitar_selection",
    "time_0319": "handle_time_picker_response",
    "form_large_content": "handle_large_form_response"
  }
}
```

### Required Templates

**Structure**:
```json
{
  "required_templates": [
    "template_name_1",
    "template_name_2"
  ]
}
```

**Example**:
```json
{
  "required_templates": [
    "ah_guitar_list_picker",
    "ah_guitar_info_form",
    "ah_large_form_demo",
    "ah_main_menu",
    "ah_ar_guitar",
    "ah_summary"
  ]
}
```

## Bot Studio Integration

### How Bot Studio Uses bot_config

**Flow Compilation**: Bot Studio compiles visual flows into `bot_config` JSON

**Process**:
1. User designs flow visually in Bot Studio
2. Click "Compile & Test"
3. Bot Studio converts nodes/edges to `bot_config` structure
4. Config is saved to `agent_bots.bot_config`
5. Bot service reads config to process messages

**Service**: `AppleMessagesForBusiness::FlowCompilerService`

**Example Compilation**:
```ruby
# Visual flow (nodes + edges)
flow_data = {
  nodes: [
    { id: '1', type: 'state', data: { state_id: 'AHA1', handler: 'handle_welcome' } },
    { id: '2', type: 'state', data: { state_id: 'AHA2', handler: 'handle_region_prompt' } }
  ],
  edges: [
    { source: '1', target: '2' }
  ]
}

# Compiled to bot_config
bot_config = {
  conversation_flow: {
    states: {
      'AHA1' => { handler: 'handle_welcome', next_state: 'AHA2' },
      'AHA2' => { handler: 'handle_region_prompt', next_state: 'AHA3' }
    }
  }
}
```

### Import/Export Flow

**Export**: Bot Studio → Export to JSON → Downloads flow JSON
**Import**: Bot Studio → Import from JSON → Uploads flow JSON → Compiles to `bot_config`

**Files**:
- Visual flow format: `{ nodes: [...], edges: [...] }`
- Bot config format: `{ conversation_flow: {...}, keyword_mappings: {...}, ... }`

## Future Enhancements

### Planned UI Improvements (Phase 7+)

**Visual Configuration Editor**:
- Replace JSON textarea with form fields
- Separate tabs for:
  - Typing Indicators
  - Conversation Flow (via Bot Studio)
  - Keyword Mappings (table editor)
  - Interactive Handlers (table editor)
  - Required Templates (multi-select)

**Benefits**:
- ✅ No manual JSON editing
- ✅ Better validation
- ✅ Autocomplete for handler methods
- ✅ Template selection from dropdown
- ✅ Real-time validation

**Mock-up Structure**:
```
Bot Configuration
├── General Settings
│   ├── Typing Indicators
│   │   ├── [✓] Enable typing indicators
│   │   └── Delay: [1.5] seconds
│   └── Conversation Timeout
│       └── Timeout: [30] minutes
├── Conversation Flow (→ Bot Studio)
│   └── [Open Visual Studio]
├── Keyword Mappings
│   ├── Demo Keywords
│   │   ├── guitar → handle_list_picker_demo [Edit] [Delete]
│   │   └── [+ Add Keyword]
│   └── Flow Control
│       ├── menu → handle_menu [Edit] [Delete]
│       └── [+ Add Keyword]
├── Interactive Handlers
│   ├── qr_travel → handle_region_selection [Edit] [Delete]
│   └── [+ Add Handler]
└── Required Templates
    ├── [✓] ah_guitar_list_picker
    ├── [✓] ah_guitar_info_form
    └── [+ Add Template]
```

## Troubleshooting

### Issue: JSON validation error when saving bot

**Symptoms**: "Invalid JSON" error in Bot Configuration field

**Solutions**:
1. Use JSON validator (e.g., jsonlint.com) to check syntax
2. Check for:
   - Missing commas
   - Unclosed brackets/braces
   - Invalid characters
3. Copy from working example and modify

### Issue: Bot doesn't respect typing indicator config

**Symptoms**: Bot sends messages instantly even with `enabled: true`

**Possible Causes**:
1. Config not saved properly
2. Bot service not reading config
3. Hardcoded constants overriding config

**Solutions**:
1. Verify config saved:
   ```ruby
   bot = AgentBot.find(bot_id)
   puts bot.bot_config.dig('typing_indicators', 'enabled')
   ```
2. Check bot service reads config:
   ```ruby
   # In bot service
   def typing_indicators_enabled?
     @config&.dig('typing_indicators', 'enabled') ||
       self.class::TYPING_INDICATORS_ENABLED
   end
   ```

### Issue: Required keys validation error

**Symptoms**: "missing required keys for AMB bot: ..." error

**Required Keys**:
- `conversation_flow`
- `keyword_mappings`
- `interactive_handlers`
- `required_templates`

**Solution**:
Add all required keys to `bot_config`, even if empty:
```json
{
  "conversation_flow": { "states": {} },
  "keyword_mappings": {},
  "interactive_handlers": {},
  "required_templates": []
}
```

## Best Practices

### JSON Editing Tips

1. **Use a JSON editor**: Consider editing in VS Code or online JSON editor first
2. **Format for readability**: Use 2-space indentation
3. **Validate before saving**: Check JSON syntax before clicking Save
4. **Keep backups**: Copy current config before making changes
5. **Test changes**: Test bot behavior after config changes

### Configuration Management

1. **Version control**: Store bot configs in version control (e.g., `config/bots/`)
2. **Environment-specific**: Use different configs for dev/staging/production
3. **Documentation**: Document custom handler methods and their purpose
4. **Testing**: Test bot with different configurations before production

### Handler Method Naming

1. **Consistent naming**: Use `handle_` prefix for all handler methods
2. **Descriptive names**: `handle_guitar_selection` better than `handle_gs`
3. **Match state IDs**: State `AHA1` → handler `handle_welcome` (document mapping)
4. **Document mappings**: Keep a reference guide of state → handler mappings

## Related Documentation

- [Handler Methods Reference](./HANDLER_METHODS_REFERENCE.md) - All available handler methods
- [Bot Studio README](./README.md) - Complete Bot Studio documentation
- [Bot Studio Architecture](./BOT_STUDIO_ARCHITECTURE.md) - System architecture
- [AMB Integration Status](../apple-messages/AMB_INTEGRATION_STATUS_REPORT.md) - AMB system overview

## API Reference

**Controller**: `Api::V1::Accounts::AgentBotsController`
**Model**: `AgentBot` (`app/models/agent_bot.rb`)

**Endpoints**:
- `GET /api/v1/accounts/:account_id/agent_bots` - List bots
- `POST /api/v1/accounts/:account_id/agent_bots` - Create bot
- `GET /api/v1/accounts/:account_id/agent_bots/:id` - Show bot
- `PATCH /api/v1/accounts/:account_id/agent_bots/:id` - Update bot
- `DELETE /api/v1/accounts/:account_id/agent_bots/:id` - Delete bot

**bot_config Field**:
- Type: JSONB
- Required for: AMB bots
- Validated by: `AgentBot#validate_amb_config`
- Accessed by: `AgentBot#effective_config(inbox_id:)`
