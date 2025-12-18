# Flow Compiler Service Implementation - Phase 3

**Status**: ✅ Complete
**Date**: 2025-12-08
**Component**: Visual Bot Studio - Flow Compiler

## Overview

The `FlowCompilerService` converts visual flow data (React Flow nodes and edges) into the `bot_config` JSON format that `AcousticHouseBotService` understands. This enables the Visual Bot Studio to generate executable bot configurations from the drag-and-drop visual interface.

## Architecture

### Input Format (Visual Flow)

```json
{
  "nodes": [
    {
      "id": "node_1",
      "type": "state",
      "data": {
        "state_id": "AHA1",
        "label": "Welcome",
        "description": "Welcome state",
        "handler": "handle_welcome",
        "actions": [
          {
            "type": "send_template",
            "template_name": "ah_main_menu"
          }
        ]
      }
    },
    {
      "id": "node_2",
      "type": "intent",
      "data": {
        "keywords": ["guitar", "guitars"],
        "handler": "handle_guitar_selection",
        "category": "demo",
        "exact_match": false
      }
    },
    {
      "id": "node_3",
      "type": "template",
      "data": {
        "template_name": "ah_guitar_list_picker",
        "template_type": "list_picker",
        "request_identifier": "lp_guitar_0319"
      }
    }
  ],
  "edges": [
    {
      "id": "edge_1",
      "source": "node_1",
      "target": "node_2",
      "type": "default"
    }
  ],
  "metadata": {
    "idle_timeout_minutes": 30,
    "validate_templates": true
  }
}
```

### Output Format (bot_config)

```json
{
  "conversation_flow": {
    "initial_state": "AHA1",
    "idle_timeout_minutes": 30,
    "states": {
      "AHA1": {
        "name": "Welcome",
        "handler": "handle_welcome",
        "description": "Welcome state",
        "actions": [
          {
            "type": "send_template",
            "template_name": "ah_main_menu",
            "parameters": {}
          }
        ],
        "transitions": {
          "default": "AHA2"
        }
      }
    }
  },
  "keyword_mappings": {
    "demo_keywords": {
      "guitar": "handle_guitar_selection",
      "guitars": "handle_guitar_selection"
    },
    "flow_control_keywords": {
      "menu": "handle_menu",
      "startover": "handle_start_over"
    }
  },
  "interactive_handlers": {
    "lp_guitar_0319": "handle_guitar_selection",
    "time_0319": "handle_time_picker_response",
    "form_0343": "handle_form_response"
  },
  "required_templates": {
    "list": [
      "ah_main_menu",
      "ah_guitar_list_picker"
    ],
    "validation": {
      "enabled": true,
      "fail_on_missing": false
    }
  },
  "typing_indicators": {
    "enabled": true,
    "delay_seconds": 1.5
  },
  "idempotency": {
    "enabled": true,
    "ttl_minutes": 2,
    "redis_key_prefix": "amb_bot"
  },
  "features": {
    "ar_enabled": true,
    "forms_enabled": true,
    "oauth_enabled": true,
    "app_clips_enabled": true,
    "apple_pay_enabled": true,
    "apple_maps_enabled": true,
    "rich_links_enabled": true,
    "attachments_enabled": true,
    "imessage_apps_enabled": true
  }
}
```

## Node Types

### 1. State Nodes

**Purpose**: Represent conversation states in the state machine.

**Data Structure**:
```ruby
{
  'state_id' => 'AHA1',           # Unique state identifier
  'label' => 'Welcome',            # Human-readable name
  'description' => 'Welcome state', # Optional description
  'handler' => 'handle_welcome',   # Handler method name
  'is_initial' => true,            # Mark as initial state
  'actions' => [                   # Actions to execute
    {
      'type' => 'send_template',
      'template_name' => 'ah_main_menu',
      'parameters' => {}
    }
  ]
}
```

**Compilation**:
- Extracted into `conversation_flow.states`
- Transitions built by following outgoing edges
- Initial state determined by `is_initial` flag or first state

### 2. Intent Nodes

**Purpose**: Map keywords to handler methods (e.g., "guitar" → handle_guitar_selection).

**Data Structure**:
```ruby
{
  'keywords' => ['guitar', 'guitars'],
  'handler' => 'handle_guitar_selection',
  'category' => 'demo',           # 'demo' or 'flow_control'
  'exact_match' => false,         # Match mode
  'case_sensitive' => false       # Case sensitivity
}
```

**Compilation**:
- Extracted into `keyword_mappings.demo_keywords` or `keyword_mappings.flow_control_keywords`
- Each keyword mapped to the same handler
- Keywords normalized to lowercase

### 3. Template Nodes

**Purpose**: Reference message templates (list pickers, forms, time pickers).

**Data Structure**:
```ruby
{
  'template_name' => 'ah_guitar_list_picker',
  'template_type' => 'list_picker',  # list_picker, time_picker, form, quick_reply
  'request_identifier' => 'lp_guitar_0319',  # Optional: explicit request_id
  'handler' => 'handle_guitar_selection'     # Optional: explicit handler
}
```

**Compilation**:
- Added to `required_templates.list`
- `request_identifier` → handler mapping in `interactive_handlers`
- Auto-generates request_id and handler if not provided

### 4. Action Nodes

**Purpose**: Define custom actions with explicit request identifiers.

**Data Structure**:
```ruby
{
  'action_type' => 'custom_action',
  'request_identifier' => 'act_custom_123',
  'handler' => 'handle_custom_action'
}
```

**Compilation**:
- Mapped directly to `interactive_handlers`
- Used for custom interactive messages not covered by templates

### 5. Condition Nodes

**Purpose**: Branch flow based on conditions (future enhancement).

**Status**: Planned for Phase 4

## Key Methods

### `compile`

Main entry point. Returns complete bot_config structure.

```ruby
compiler = AppleMessagesForBusiness::FlowCompilerService.new(flow)
bot_config = compiler.compile
```

### `build_conversation_flow`

Builds the conversation flow section with states and transitions.

**Features**:
- Finds initial state (marked or first)
- Maps state_id → state definition
- Builds transitions by following edges
- Supports conditional transitions (future)

### `build_keyword_mappings`

Maps keywords to handlers, split by category.

**Categories**:
- `demo_keywords`: Isolated template demos
- `flow_control_keywords`: Flow control (menu, restart, etc.)

### `build_interactive_handlers`

Maps request identifiers to handler methods.

**Sources**:
1. Template nodes (generates request_id from template_name + type)
2. Action nodes (explicit request_identifier)

**Auto-generation**:
- `ah_guitar_list_picker` + `list_picker` → `lp_guitar_0319`
- `ah_guitar_form` + `form` → `form_guitar_4721`

### `extract_required_templates`

Collects all template names used in the flow.

**Sources**:
1. Template nodes (`template_name`)
2. State actions (`send_template` actions)

**Output**:
- Deduplicated list of template names
- Validation configuration

### `extract_features`

Feature flags for bot capabilities.

**Default**: All features enabled (AR, forms, OAuth, Apple Pay, etc.)

**Override**: Can be customized via `flow.metadata['features']`

## Handler Name Generation

### States

```ruby
'AHA1' → 'handle_aha1'
'WELCOME' → 'handle_welcome'
```

### Intents

Follows edges to find target state:
```ruby
Intent('guitar') → State('AHA2') → 'handle_aha2'
```

### Templates

Based on template type and name:

```ruby
# List Picker
'ah_guitar_list_picker' → 'handle_guitar_selection'

# Time Picker
'ah_lesson_time' → 'handle_lesson_time_response'

# Form
'ah_guitar_info_form' → 'handle_guitar_info_response'

# Quick Reply
'ah_region_select' → 'handle_region_select_response'
```

## Request Identifier Generation

Format: `<type_prefix>_<base_name>_<random_suffix>`

**Type Prefixes**:
- `lp`: list_picker
- `time`: time_picker
- `form`: form
- `qr`: quick_reply
- `applepay`: apple_pay
- `act`: action (default)

**Examples**:
```ruby
'ah_guitar_list_picker' + 'list_picker' → 'lp_guitar_0319'
'ah_lesson_time' + 'time_picker' → 'time_lesson_7824'
'ah_info_form' + 'form' → 'form_info_2156'
```

**Random Suffix**: 4-digit random number for uniqueness

## API Integration

### Endpoint

```
POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/compile
```

### Controller Method

```ruby
def compile
  compiler = AppleMessagesForBusiness::FlowCompilerService.new(@flow)
  compiled_config = compiler.compile

  # Update bot's bot_config
  @agent_bot.update!(bot_config: compiled_config)

  render json: {
    bot_config: compiled_config,
    message: 'Flow compiled and bot config updated successfully'
  }
rescue StandardError => e
  render json: {
    error: e.message,
    message: 'Failed to compile flow'
  }, status: :unprocessable_entity
end
```

### Response Format

**Success (200)**:
```json
{
  "bot_config": { ... },
  "message": "Flow compiled and bot config updated successfully"
}
```

**Error (422)**:
```json
{
  "error": "Flow has no nodes",
  "message": "Failed to compile flow"
}
```

## Validation

### Flow Validation

```ruby
def validate_flow!
  raise StandardError, 'Flow has no nodes' if @nodes.empty?
  raise StandardError, 'Flow has no state nodes' if state_nodes.empty?
end
```

**Validation Rules**:
1. Flow must have at least one node
2. Flow must have at least one state node
3. Initial state must exist (first state or marked as initial)

### Template Validation

Configured via `required_templates.validation`:

```ruby
{
  'validation' => {
    'enabled' => true,              # Enable validation
    'fail_on_missing' => false      # Fail on missing templates
  }
}
```

**Validation Behavior**:
- `enabled: true, fail_on_missing: false`: Log warnings for missing templates
- `enabled: true, fail_on_missing: true`: Raise error if templates missing
- `enabled: false`: Skip validation

## Edge Types

### Default Edges

Connect sequential states:

```ruby
{
  'id' => 'edge_1',
  'source' => 'node_1',
  'target' => 'node_2',
  'type' => 'default'
}
```

Compiled as:
```ruby
'transitions' => { 'default' => 'AHA2' }
```

### Conditional Edges (Future)

Branch based on conditions:

```ruby
{
  'id' => 'edge_2',
  'source' => 'condition_node',
  'target' => 'node_3',
  'type' => 'conditional',
  'label' => 'true'
}
```

Compiled as:
```ruby
'transitions' => { 'true' => 'AHA3', 'false' => 'AHA4' }
```

## Usage Examples

### Example 1: Simple Linear Flow

**Visual Flow**:
```
State(AHA1) → State(AHA2) → State(AHA3)
```

**Compiled bot_config**:
```ruby
{
  'conversation_flow' => {
    'initial_state' => 'AHA1',
    'states' => {
      'AHA1' => { 'transitions' => { 'default' => 'AHA2' } },
      'AHA2' => { 'transitions' => { 'default' => 'AHA3' } },
      'AHA3' => { 'transitions' => {} }
    }
  }
}
```

### Example 2: Keyword + Template Flow

**Visual Flow**:
```
Intent('guitar') → Template(ah_guitar_list_picker)
```

**Compiled bot_config**:
```ruby
{
  'keyword_mappings' => {
    'demo_keywords' => {
      'guitar' => 'handle_guitar_selection'
    }
  },
  'interactive_handlers' => {
    'lp_guitar_0319' => 'handle_guitar_selection'
  },
  'required_templates' => {
    'list' => ['ah_guitar_list_picker']
  }
}
```

### Example 3: State with Template Action

**Visual Flow**:
```
State(AHA1) with action: send_template('ah_main_menu')
```

**Compiled bot_config**:
```ruby
{
  'conversation_flow' => {
    'states' => {
      'AHA1' => {
        'actions' => [
          {
            'type' => 'send_template',
            'template_name' => 'ah_main_menu',
            'parameters' => {}
          }
        ]
      }
    }
  },
  'required_templates' => {
    'list' => ['ah_main_menu']
  }
}
```

## Testing

### Unit Tests

Location: `spec/services/apple_messages_for_business/flow_compiler_service_spec.rb`

**Test Coverage**:
- ✅ Simple linear flows (state → state)
- ✅ Branching flows (intent keywords)
- ✅ Template extraction
- ✅ Handler name generation
- ✅ Request identifier generation
- ✅ Error handling (no nodes, no states)

### Integration Tests

Location: `spec/requests/api/v1/accounts/agent_bots/flows_controller_spec.rb`

**Test Coverage**:
- ✅ Compile endpoint (POST)
- ✅ Success response format
- ✅ Error response format
- ✅ Bot config update

## Files

### Created/Modified

1. **Service**: `app/services/apple_messages_for_business/flow_compiler_service.rb` (398 lines)
2. **Controller**: `app/controllers/api/v1/accounts/agent_bots/flows_controller.rb` (already integrated)
3. **Documentation**: `docs/apple-messages/bot-studio/FLOW_COMPILER_IMPLEMENTATION.md` (this file)

### Dependencies

- **Models**: `BotFlow`, `AgentBot`, `MessageTemplate`
- **Services**: None (standalone service)
- **Gems**: Rails core (no additional gems)

## Performance

### Complexity Analysis

- **Time Complexity**: O(N + E) where N = nodes, E = edges
- **Space Complexity**: O(N + E)
- **Typical Flow**: ~50 nodes, ~60 edges = <10ms compile time

### Optimization Opportunities

1. **Caching**: Cache compiled bot_config until flow changes
2. **Incremental Compilation**: Only recompile changed nodes
3. **Validation Caching**: Cache template validation results

## Future Enhancements

### Phase 4 (Planned)

1. **Conditional Edges**: Support branching based on conditions
2. **Variable Nodes**: Store/retrieve conversation variables
3. **Loop Detection**: Detect and prevent infinite loops
4. **Flow Validation**: Enhanced validation (unreachable nodes, etc.)
5. **Flow Preview**: Generate visual preview of compiled flow
6. **Flow Debugging**: Debug mode with step-by-step execution

### Phase 5 (Planned)

1. **Flow Templates**: Pre-built flow templates for common patterns
2. **Flow Import/Export**: Import/export flows as JSON
3. **Flow Versioning**: Track flow changes over time
4. **Flow Testing**: Unit test flows in the visual editor

## Troubleshooting

### Issue: "Flow has no nodes"

**Cause**: Empty flow or invalid flow_data structure

**Solution**: Ensure flow has at least one node:
```ruby
flow.flow_data = {
  'nodes' => [{ 'id' => 'node_1', 'type' => 'state', ... }],
  'edges' => []
}
```

### Issue: "Flow has no state nodes"

**Cause**: Flow only has non-state nodes (intent, template, action)

**Solution**: Add at least one state node to the flow

### Issue: Missing templates in compiled config

**Cause**: Template nodes missing `template_name`

**Solution**: Ensure all template nodes have `template_name`:
```ruby
{
  'type' => 'template',
  'data' => {
    'template_name' => 'ah_guitar_list_picker',  # Required
    'template_type' => 'list_picker'
  }
}
```

### Issue: Handler name conflicts

**Cause**: Multiple nodes generate same handler name

**Solution**: Provide explicit handler names:
```ruby
{
  'type' => 'template',
  'data' => {
    'template_name' => 'ah_guitar_list_picker',
    'handler' => 'handle_custom_guitar_selection'  # Explicit
  }
}
```

## Related Documentation

- **Visual Bot Studio Overview**: `docs/apple-messages/bot-studio/README.md`
- **Flow Importer**: `docs/apple-messages/bot-studio/FLOW_IMPORTER.md`
- **Flow Validator**: `docs/apple-messages/bot-studio/FLOW_VALIDATOR.md`
- **AcousticHouseBotService**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

## Success Criteria

✅ **Compiler successfully converts visual flow to bot_config**
✅ **Generated bot_config is valid and follows AcousticHouseBotService format**
✅ **All node types are properly handled (state, intent, template, action)**
✅ **Transitions are correctly mapped from edges**
✅ **Templates are extracted and listed**
✅ **Compile endpoint returns proper JSON**
✅ **RuboCop passes with no offenses**
✅ **Code follows Chatwoot style guide**

---

**Implementation Status**: ✅ **Complete**
**Phase**: Phase 3 (Flow Compiler)
**Next Phase**: Phase 4 (Flow Validator Enhancement + Condition Nodes)
