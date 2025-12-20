# FlowExecutorService - Production Flow Executor

**Status**: ✅ **Active** (Deployed December 2025)

## Overview

`FlowExecutorService` is the production flow execution engine for Bot Studio visual flows. It replaces the legacy `AcousticHouseBotService` by executing user-designed flows and sending actual messages to Apple Messages for Business.

**Location**: `app/services/apple_messages_for_business/flow_executor_service.rb`

## Purpose

- **Execute visual bot flows** designed in Bot Studio
- **Send actual messages** to Apple MSP (not simulations)
- **Store conversation state** persistently
- **Handle transitions** between flow nodes
- **Track execution** for debugging and analytics

## Architecture

### Key Components

```
FlowExecutorService
  ├── Flow Logic (nodes, edges, transitions)
  ├── Message Sending (via SendListPickerService, etc.)
  ├── State Management (conversation session)
  └── Execution Tracking (executed nodes, messages sent)
```

### Differences from FlowSimulatorService

| Feature | FlowSimulatorService | FlowExecutorService |
|---------|---------------------|---------------------|
| **Purpose** | Testing in Bot Studio | Production execution |
| **Messages** | Returns text previews | Sends actual messages via Apple MSP |
| **State** | Temporary (in-memory) | Persistent (conversation) |
| **Usage** | Test console | Real conversations |
| **Output** | Simulation result JSON | Message delivery + state update |

## Usage

### Basic Usage

```ruby
# Incoming message triggers flow execution
executor = AppleMessagesForBusiness::FlowExecutorService.new(
  flow,           # BotFlow object
  conversation,   # Conversation object
  message         # Incoming Message object
)

result = executor.execute

# Returns:
# {
#   success: true,
#   nodes_executed: ['node-1', 'node-2'],
#   current_state: 'AHA2',
#   messages_sent: 1
# }
```

### Integration with Incoming Messages

The service is automatically invoked by `IncomingMessageService` when:
1. A bot is configured for the inbox
2. The bot has an active published flow

```ruby
# In incoming_message_service.rb
active_flow = configured_bot.bot_flows.active.published.first

if active_flow
  # Use FlowExecutorService
  executor = AppleMessagesForBusiness::FlowExecutorService.new(
    active_flow, @conversation, @message
  )
  executor.execute
else
  # Fall back to legacy AcousticHouseBotService
  # (will be deprecated)
end
```

## How It Works

### 1. Message Processing Flow

```
Incoming Message
  ↓
Load Session State (from conversation)
  ↓
Find Matching Node (intent or state)
  ↓
Execute Node Actions
  ↓
Send Messages (via Send Services)
  ↓
Update State & Transitions
  ↓
Save Session State
  ↓
Return Result
```

### 2. Node Execution

#### State Node
- Executes handler method (loads templates from metadata)
- Executes inline actions (send_template, send_text)
- Handles transitions via edges
- Updates current_state

#### Intent Node
- Matches keywords against message
- Follows edge to target node (state/template/action)
- Executes target node

#### Template Node
- Loads template by name
- Sends via appropriate send service
- Transitions to next state

#### Action Node
- Executes custom actions
- Transitions to next node

### 3. Message Sending

Templates are sent using existing send services:

| Template Type | Send Service |
|---------------|-------------|
| `list_picker` | `SendListPickerService` |
| `time_picker` | `SendTimePickerService` |
| `form`, `apple_form` | `FormService` |
| `rich_link` | `SendRichLinkService` |

### 4. State Management

Session state is stored in `conversation.additional_attributes`:

```ruby
{
  'bot_session' => {
    'current_state' => 'AHA2',
    'message_count' => 5,
    'last_update' => '2025-12-19T10:30:00Z',
    'flow_id' => 123,
    'flow_name' => 'Main Flow'
  }
}
```

## Handler Method Execution

When a state node has a `handler` field, the service:

1. Looks up handler metadata from `AcousticHouseBotService.handler_methods_metadata`
2. Extracts template dependencies from metadata
3. Loads and sends each template

**Example**:

```ruby
# State node has handler: 'handle_welcome'
# Handler metadata defines:
{
  handle_welcome: {
    dependencies: {
      templates: ['ah_welcome_message', 'ah_main_menu']
    }
  }
}

# FlowExecutorService will:
# 1. Load 'ah_welcome_message' template → send via appropriate service
# 2. Load 'ah_main_menu' template → send via appropriate service
```

## Execution Result

```ruby
{
  success: true,                              # Execution succeeded
  nodes_executed: ['intent-1', 'state-2'],   # Array of executed node IDs
  current_state: 'AHA3',                     # Current conversation state
  messages_sent: 2,                          # Number of messages sent
  error: nil                                 # Error message (if failed)
}
```

## Error Handling

The service handles errors gracefully:

```ruby
rescue StandardError => e
  log_error "[FlowExecutor] ❌ Execution failed: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")

  {
    success: false,
    error: e.message,
    nodes_executed: @executed_nodes,
    current_state: @current_state
  }
end
```

## Logging

Comprehensive logging for debugging:

```
[FlowExecutor] 🚀 Executing flow 'Main Flow' for message: hello
[FlowExecutor] 📍 Current state: AHA1
[FlowExecutor] 🔑 Intent matched: Welcome
[FlowExecutor] 🔧 Executing handler: handle_welcome
[FlowExecutor] 📤 Sending template: ah_welcome_message (list_picker)
[FlowExecutor] ➡️ Transitioned to state: AHA2
[FlowExecutor] ✅ Execution complete. Nodes: 2, Messages: 1
```

## Migration from Legacy Service

### Phase 1: Parallel Operation ✅ **Complete**
- Bots with active flows → Use `FlowExecutorService`
- Bots without flows → Use `AcousticHouseBotService` (legacy)

### Phase 2: Visual Flows Created ✅ **Complete**
- Visual flows created for all bots in Bot Studio
- Flows tested in test console
- Flows ready for publishing to production
- Legacy service available as fallback

### Phase 3: Production Publishing (Current)
- Publish flows to production (set `is_published: true`)
- Monitor production execution
- Verify behavior matches expectations
- Gather feedback and iterate

### Phase 4: Deprecation (Future)
- Remove `AcousticHouseBotService`
- All bots use visual flows exclusively
- Legacy bot_config format deprecated

## Configuration Requirements

For a flow to be executed:

1. **Bot must be assigned to inbox**:
   ```ruby
   AgentBotInbox.find_by(inbox: inbox, agent_bot: bot).active? # => true
   ```

2. **Bot must have active published flow**:
   ```ruby
   bot.bot_flows.active.published.exists? # => true
   ```

3. **Flow must have valid flow_data**:
   ```ruby
   flow.flow_data # => { 'nodes' => [...], 'edges' => [...] }
   ```

## Testing

### Test Console
Use the Bot Studio test console to test flows before publishing:
- Simulates flow execution
- Shows visual template previews
- Tracks executed nodes
- Safe testing without sending actual messages

### Production Testing
1. Create test inbox with test device
2. Publish flow to production
3. Send test messages from device
4. Monitor logs for execution flow
5. Verify messages received on device

## Performance Considerations

- **Session state**: Stored in conversation, minimal database writes
- **Template loading**: Cached by Rails, efficient lookups
- **Send services**: Reuse existing optimized services
- **Execution tracking**: Lightweight array of node IDs

## Troubleshooting

### Flow not executing
**Check**:
- Bot is assigned to inbox and active
- Flow is published (`is_published: true`)
- Flow is active (`is_active: true`)
- Flow has valid nodes and edges

**Logs**:
```bash
# Look for executor logs
tail -f log/development.log | grep FlowExecutor

# Check routing decision
tail -f log/development.log | grep "Bot has active flow"
```

### Messages not sending
**Check**:
- Templates exist with correct names
- Templates support 'apple_messages_for_business' channel
- Send services are working (test individually)
- Network connectivity to Apple MSP

**Debug**:
```ruby
# In rails console
flow = BotFlow.find(123)
executor = AppleMessagesForBusiness::FlowExecutorService.new(
  flow, conversation, message
)
result = executor.execute
# Check result[:error]
```

### State not persisting
**Check**:
- Conversation.additional_attributes is writable
- Database transactions are committing
- No exceptions in save_session_state

**Verify**:
```ruby
# In rails console
conversation.reload
conversation.additional_attributes['bot_session']
# Should show current_state, message_count, etc.
```

## Related Documentation

- **Test Console**: `docs/bot-studio/TEST_CONSOLE_IMPLEMENTATION.md`
- **Flow Simulator**: `docs/bot-studio/FLOW_SIMULATOR_SERVICE.md` (to be created)
- **Bot Studio Guide**: `docs/bot-studio/README.md`
- **Handler Methods**: `docs/bot-studio/HANDLER_METHODS_REFERENCE.md`
- **Version Management**: `docs/apple-messages/BOT_STUDIO_PHASE_6_VERSION_MANAGEMENT.md`

## Example Flows

### Simple Welcome Flow

```javascript
// Flow data structure
{
  nodes: [
    {
      id: 'start',
      type: 'state',
      data: {
        state_id: 'AHA1',
        label: 'Welcome',
        handler: 'handle_welcome',
        is_initial: true
      }
    }
  ],
  edges: []
}

// Execution:
// User sends: "hello"
// → Matches initial state (AHA1)
// → Executes handle_welcome handler
// → Sends welcome templates
// → Conversation state saved
```

### Intent-based Flow

```javascript
{
  nodes: [
    {
      id: 'menu-intent',
      type: 'intent',
      data: {
        label: 'Main Menu',
        keywords: ['menu', 'start'],
        exact_match: false
      }
    },
    {
      id: 'menu-state',
      type: 'state',
      data: {
        state_id: 'AHA_MENU',
        label: 'Show Menu',
        handler: 'handle_menu'
      }
    }
  ],
  edges: [
    {
      source: 'menu-intent',
      target: 'menu-state'
    }
  ]
}

// Execution:
// User sends: "menu"
// → Matches intent keywords
// → Follows edge to menu-state
// → Executes handle_menu handler
// → Sends menu template
```

## Future Enhancements

### Planned Features
- ✅ Basic flow execution (completed)
- ✅ Handler method integration (completed)
- ✅ Template sending (completed)
- 🔲 Condition node evaluation
- 🔲 Custom action execution
- 🔲 Flow analytics & metrics
- 🔲 A/B testing support
- 🔲 Multi-language flows

### Performance Optimizations
- Template preloading
- Edge caching
- Batch message sending
- Async execution for complex flows

## Changelog

### December 2025 - Initial Release
- Created FlowExecutorService
- Integrated with IncomingMessageService
- Support for state, intent, template, action nodes
- Handler method execution
- Template sending via existing services
- Session state management
- Comprehensive logging
- Error handling

---

**Next Steps**: Test on production with published flow, then gradually migrate all bots to visual flows.
