# Bot Studio Configuration Guide

## Overview

This guide explains how to configure bot behavior, including typing indicators, timeouts, and other global bot settings.

## Current Configuration Location

Bot configuration is currently hardcoded in the bot service class. For the Acoustic House Bot, configuration is in:

**File**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

## Available Configuration Options

### 1. Typing Indicators

**Location**: Lines 51-55 of `acoustic_house_bot_service.rb`

```ruby
# Typing indicator configuration
# Set to false during development for faster testing
# Set to true in production for better user experience
TYPING_INDICATORS_ENABLED = true
TYPING_INDICATOR_DELAY = 1.5 # seconds
```

**What They Do**:
- When enabled, the bot sends typing indicator events before each message
- Makes the conversation feel more natural by simulating "bot is typing..."
- Adds a delay before each message to give the appearance of thinking/composing

**Configuration**:
- `TYPING_INDICATORS_ENABLED`: Set to `true` (production) or `false` (development/testing)
- `TYPING_INDICATOR_DELAY`: Delay in seconds before sending message (default: 1.5)

**Best Practices**:
- **Development**: Set to `false` for faster testing iterations
- **Production**: Set to `true` for better user experience
- **Delay**: Keep between 1-2 seconds for optimal UX
  - Too short (<1s): Feels robotic
  - Too long (>2s): Feels slow/unresponsive
  - Sweet spot: 1.5s (default)

**How to Change**:
1. Edit `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`
2. Modify `TYPING_INDICATORS_ENABLED` or `TYPING_INDICATOR_DELAY`
3. Restart the application for changes to take effect

### 2. Conversation Timeout

**Location**: Line 4 of `acoustic_house_bot_service.rb`

```ruby
IDLE_TIMEOUT = 30.minutes
```

**What It Does**:
- Automatically resets conversation to welcome state after 30 minutes of inactivity
- Prevents stale conversations from continuing after long breaks

**Configuration**:
- Default: 30 minutes
- Can be set to any duration (e.g., `15.minutes`, `1.hour`)

**How to Change**:
1. Edit `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`
2. Modify `IDLE_TIMEOUT = 30.minutes` to desired duration
3. Restart the application

### 3. Required Templates

**Location**: Lines 9-16 of `acoustic_house_bot_service.rb`

```ruby
REQUIRED_TEMPLATES = %w[
  ah_guitar_list_picker
  ah_guitar_info_form
  ah_large_form_demo
  ah_main_menu
  ah_ar_guitar
  ah_summary
].freeze
```

**What They Do**:
- Define which Apple Messages templates are required for the bot to function
- Used by deployment automation to verify all dependencies exist
- Prevents bot errors from missing templates

**How to Add Templates**:
1. Add template name to `REQUIRED_TEMPLATES` array
2. Create the template in Bot Studio or via API
3. Deploy and verify with:
   ```ruby
   result = AcousticHouseBotService.verify_templates_exist(account_id)
   ```

### 4. Keyword Handlers

**Location**: Lines 59-102 of `acoustic_house_bot_service.rb`

See [Handler Methods Reference](./HANDLER_METHODS_REFERENCE.md) for complete documentation on keyword handlers.

**Configuration Structure**:
```ruby
DEMO_KEYWORDS = {
  'keyword' => :handler_method_name,
  'another keyword' => :handler_method_name,
}.freeze

FLOW_CONTROL_KEYWORDS = {
  'menu' => :handle_menu,
  'reset' => :handle_start_over,
}.freeze
```

**How to Add Keywords**:
1. Add keyword-to-handler mapping in appropriate constant
2. Implement the handler method
3. Test with keyword message

## Future: UI-Based Configuration

### Planned Features (Future Phases)

**Bot Configuration Panel** (Phase 7+):
- ✅ Visual configuration of typing indicators
- ✅ Adjustable timeout settings
- ✅ Template dependency management
- ✅ Keyword/handler configuration via UI
- ✅ Per-bot configuration (not global)

**Expected UI Location**:
- Bot Studio → Bot Settings → Configuration tab
- Or: Agent Bots → [Bot] → Settings button → Configuration

**Configuration Storage**:
Currently, configuration is stored as Ruby constants in the bot service class. Future implementation will store configuration in:
- `agent_bots.bot_config` (JSONB column)
- Per-bot configuration instead of global constants
- API endpoints for updating configuration

**Example Future API Structure**:
```json
{
  "bot_config": {
    "typing_indicators": {
      "enabled": true,
      "delay": 1.5
    },
    "conversation": {
      "idle_timeout": 1800
    },
    "templates": {
      "required": ["ah_guitar_list_picker", "ah_main_menu"]
    },
    "keywords": {
      "demo": {
        "guitar": "handle_list_picker_demo",
        "form": "handle_form_demo"
      },
      "flow_control": {
        "menu": "handle_menu",
        "reset": "handle_start_over"
      }
    }
  }
}
```

## Current Limitations

### What You CANNOT Configure via UI (Yet)

1. **Typing Indicators**: Must edit Ruby code directly
2. **Timeout Duration**: Must edit Ruby code directly
3. **Keyword Handlers**: Must edit Ruby code directly
4. **Required Templates**: Must edit Ruby code directly

### Workarounds

**For Development Testing**:
```ruby
# Temporarily disable typing indicators for faster testing
# In acoustic_house_bot_service.rb:
TYPING_INDICATORS_ENABLED = false  # Change to false

# Restart application
./script/dev-server.sh restart
```

**For Different Environments**:
```ruby
# Environment-specific configuration
TYPING_INDICATORS_ENABLED = Rails.env.production?
TYPING_INDICATOR_DELAY = Rails.env.production? ? 1.5 : 0.1
```

## Configuration by Environment

### Development Environment

**Recommended Settings**:
```ruby
TYPING_INDICATORS_ENABLED = false  # Fast testing
TYPING_INDICATOR_DELAY = 0.1      # Minimal delay
IDLE_TIMEOUT = 5.minutes          # Shorter timeout for testing
```

### Production Environment

**Recommended Settings**:
```ruby
TYPING_INDICATORS_ENABLED = true  # Better UX
TYPING_INDICATOR_DELAY = 1.5     # Natural feel
IDLE_TIMEOUT = 30.minutes        # Standard timeout
```

## Verification

### Check Current Configuration

Use Rails console to verify current configuration:

```ruby
# In rails console
AcousticHouseBotService::TYPING_INDICATORS_ENABLED
# => true

AcousticHouseBotService::TYPING_INDICATOR_DELAY
# => 1.5

AcousticHouseBotService::IDLE_TIMEOUT
# => 1800 (seconds)

AcousticHouseBotService::REQUIRED_TEMPLATES
# => ["ah_guitar_list_picker", "ah_guitar_info_form", ...]
```

### Verify Templates Exist

```ruby
# In rails console
result = AcousticHouseBotService.verify_templates_exist(account_id)

puts "All templates present: #{result[:all_present]}"
puts "Found templates: #{result[:found]}"
puts "Missing templates: #{result[:missing]}"
```

## Best Practices

### During Development

1. **Disable Typing Indicators**: Speeds up testing significantly
2. **Use Shorter Timeouts**: Faster conversation reset for testing
3. **Log Configuration Changes**: Document when/why you changed settings
4. **Test Both Modes**: Test with typing indicators on/off before production

### During Production

1. **Enable Typing Indicators**: Improves user experience
2. **Use Standard Timeout**: 30 minutes is good default
3. **Monitor Performance**: Watch for slow response times
4. **Document Changes**: Keep changelog of configuration updates

### Configuration Checklist

Before deploying a bot to production:

- [ ] Typing indicators enabled (`TYPING_INDICATORS_ENABLED = true`)
- [ ] Appropriate delay set (`TYPING_INDICATOR_DELAY = 1.5`)
- [ ] Timeout configured (`IDLE_TIMEOUT = 30.minutes`)
- [ ] All required templates exist and verified
- [ ] All keyword handlers implemented
- [ ] All interactive handlers implemented
- [ ] State machine complete with all states

## Troubleshooting

### Issue: Bot responds too slowly

**Possible Causes**:
- Typing indicators enabled in development
- Delay set too high

**Solution**:
```ruby
# In development, disable typing indicators
TYPING_INDICATORS_ENABLED = false
```

### Issue: Conversations reset unexpectedly

**Possible Causes**:
- `IDLE_TIMEOUT` set too short
- System clock issues

**Solution**:
```ruby
# Increase timeout
IDLE_TIMEOUT = 60.minutes  # or longer
```

### Issue: Missing template error

**Possible Causes**:
- Template not created
- Template name mismatch
- Template in different account

**Solution**:
```ruby
# Verify templates
result = AcousticHouseBotService.verify_templates_exist(account_id)

# Check missing templates
puts result[:missing]
# Create missing templates or update REQUIRED_TEMPLATES
```

## Migration Path to UI Configuration

When UI-based configuration becomes available:

1. **Export Current Configuration**: Bot service constants → JSON
2. **Create Bot Config Record**: Store in `agent_bots.bot_config`
3. **Update Bot Service**: Read from bot_config instead of constants
4. **Test Equivalence**: Verify behavior matches
5. **Remove Constants**: Clean up hardcoded configuration

This guide will be updated as UI configuration becomes available in future phases.

## Related Documentation

- [Handler Methods Reference](./HANDLER_METHODS_REFERENCE.md) - Complete handler method documentation
- [Bot Studio Architecture](./BOT_STUDIO_ARCHITECTURE.md) - Overall architecture
- [Bot Studio Integration Plan](./BOT_STUDIO_INTEGRATION_PLAN.md) - Integration details
- [Visual Bot Studio Implementation Plan](./VISUAL_BOT_STUDIO_IMPLEMENTATION_PLAN.md) - Implementation roadmap
