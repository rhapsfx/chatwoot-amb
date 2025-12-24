# Visual Bot Studio - Integration & Fixes

**Date**: December 5, 2025
**Issues Addressed**:
1. Bot config JSON not connected to Visual Studio
2. Drag-and-drop not working

---

## Issue #1: JSON Config vs Visual Studio

### Current Architecture (Disconnected)

```
┌─────────────────────────────────────────────────────────┐
│               AgentBot Model                             │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  bot_config (JSONB)                                      │
│  ├── features                                            │
│  ├── messages                                            │
│  ├── apple_maps                                          │
│  ├── conversation_flow                                   │
│  │   └── states (AHA1, AHA2, ...)                       │
│  ├── keyword_mappings                                    │
│  └── interactive_handlers                                │
│                                                           │
│  [Used by AcousticHouseBotService]                      │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│               BotFlow Model (NEW)                        │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  flow_data (JSONB)                                       │
│  ├── nodes []                                            │
│  │   ├── State nodes                                     │
│  │   ├── Intent nodes                                    │
│  │   ├── Template nodes                                  │
│  │   └── etc.                                            │
│  └── edges []                                            │
│                                                           │
│  [Used by Visual Studio UI]                             │
└─────────────────────────────────────────────────────────┘

❌ NO CONNECTION BETWEEN THEM
```

### What You Need: Bidirectional Conversion

```
bot_config JSON ←→ Visual Flow Nodes
      ↓                    ↓
  Text Editor        Visual Studio
```

**Two conversion services needed**:

1. **ImportService**: `bot_config` → `flow_data`
   - Parse conversation_flow.states → State nodes
   - Parse keyword_mappings → Intent nodes
   - Parse interactive_handlers → Connection edges
   - Position nodes automatically (auto-layout)

2. **CompilerService**: `flow_data` → `bot_config`
   - Read visual nodes and edges
   - Generate conversation_flow.states
   - Generate keyword_mappings
   - Generate interactive_handlers

### Example Conversion

**Your bot_config has**:
```json
{
  "conversation_flow": {
    "states": {
      "AHA1": {
        "name": "Welcome",
        "handler": "handle_welcome"
      },
      "AHA2": {
        "name": "Region Selection",
        "handler": "handle_region_prompt"
      }
    }
  },
  "keyword_mappings": {
    "demo_keywords": {
      "guitar": "handle_list_picker_demo"
    }
  }
}
```

**Should convert to visual nodes**:
```javascript
{
  nodes: [
    {
      id: 'node_1',
      type: 'state',
      position: { x: 100, y: 100 },
      data: {
        state_id: 'AHA1',
        label: 'Welcome',
        handler: 'handle_welcome'
      }
    },
    {
      id: 'node_2',
      type: 'state',
      position: { x: 300, y: 100 },
      data: {
        state_id: 'AHA2',
        label: 'Region Selection',
        handler: 'handle_region_prompt'
      }
    },
    {
      id: 'node_3',
      type: 'intent',
      position: { x: 100, y: 300 },
      data: {
        keywords: ['guitar'],
        handler: 'handle_list_picker_demo'
      }
    }
  ],
  edges: [
    {
      id: 'edge_1',
      source: 'node_1',
      target: 'node_2'
    }
  ]
}
```

---

## Solution: Implement Import/Export Services

### Phase 2A: Import Service

**File**: `app/services/apple_messages_for_business/flow_import_service.rb`

```ruby
class AppleMessagesForBusiness::FlowImportService
  def initialize(bot_config)
    @bot_config = bot_config
  end

  def import_to_flow_data
    {
      nodes: import_nodes,
      edges: import_edges,
      metadata: {
        imported_from: 'bot_config',
        imported_at: Time.current
      }
    }
  end

  private

  def import_nodes
    nodes = []
    nodes += import_state_nodes
    nodes += import_intent_nodes
    nodes += import_template_nodes
    nodes
  end

  def import_state_nodes
    states = @bot_config.dig('conversation_flow', 'states') || {}

    states.map.with_index do |(state_id, state_data), index|
      {
        id: "state_#{state_id}",
        type: 'state',
        position: calculate_position(index),
        data: {
          state_id: state_id,
          label: state_data['name'],
          handler: state_data['handler'],
          description: state_data['description'] || ''
        }
      }
    end
  end

  def import_intent_nodes
    keywords = @bot_config.dig('keyword_mappings', 'demo_keywords') || {}

    keywords.map.with_index do |(keyword, handler), index|
      {
        id: "intent_#{index}",
        type: 'intent',
        position: calculate_position(index + 100), # Offset from states
        data: {
          keywords: [keyword],
          handler: handler,
          exact_match: false
        }
      }
    end
  end

  def calculate_position(index)
    # Simple grid layout
    row = index / 4
    col = index % 4
    { x: col * 300 + 100, y: row * 200 + 100 }
  end
end
```

### Phase 2B: Compiler Service (Already Placeholder)

**File**: `app/services/apple_messages_for_business/flow_compiler_service.rb`

```ruby
class AppleMessagesForBusiness::FlowCompilerService
  def initialize(flow_data)
    @flow_data = flow_data
    @nodes = flow_data['nodes'] || []
    @edges = flow_data['edges'] || []
  end

  def compile_to_bot_config
    {
      conversation_flow: build_conversation_flow,
      keyword_mappings: build_keyword_mappings,
      interactive_handlers: build_interactive_handlers,
      required_templates: extract_required_templates,
      features: extract_features
    }
  end

  private

  def build_conversation_flow
    state_nodes = @nodes.select { |n| n['type'] == 'state' }

    {
      states: state_nodes.each_with_object({}) do |node, hash|
        data = node['data']
        hash[data['state_id']] = {
          name: data['label'],
          handler: data['handler']
        }
      end,
      initial_state: state_nodes.first&.dig('data', 'state_id') || 'AHA1'
    }
  end

  def build_keyword_mappings
    intent_nodes = @nodes.select { |n| n['type'] == 'intent' }

    {
      demo_keywords: intent_nodes.each_with_object({}) do |node, hash|
        data = node['data']
        keywords = data['keywords'] || []
        handler = data['handler']

        keywords.each do |keyword|
          hash[keyword] = handler
        end
      end
    }
  end

  def build_interactive_handlers
    # Map template nodes to interactive handlers
    template_nodes = @nodes.select { |n| n['type'] == 'template' }

    template_nodes.each_with_object({}) do |node, hash|
      data = node['data']
      template_name = data['template_name']
      handler = data['handler'] || "handle_#{template_name}_response"

      hash[template_name] = handler
    end
  end

  def extract_required_templates
    template_nodes = @nodes.select { |n| n['type'] == 'template' }

    {
      list: template_nodes.map { |n| n.dig('data', 'template_name') }.compact,
      validation: {
        enabled: true,
        fail_on_missing: false
      }
    }
  end
end
```

### Phase 2C: Add Import Button to Bot Studio

**Update**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/BotStudio.vue`

Add button to import from bot_config:

```vue
<Button
  icon="i-lucide-download"
  @click="importFromBotConfig"
>
  Import from JSON
</Button>

<script setup>
const importFromBotConfig = async () => {
  try {
    const response = await store.dispatch('agentBots/importFlowFromBotConfig', {
      botId: botId.value
    });

    if (response?.flow_data) {
      // Load imported flow into canvas
      currentFlow.value = response;
      useAlert('Flow imported successfully from bot config');
    }
  } catch (error) {
    useAlert('Failed to import flow from bot config');
  }
};
</script>
```

---

## Issue #2: Drag-and-Drop Fix (IMPLEMENTED)

### What Was Fixed

✅ **BotStudioCanvas.vue** now has:

1. **Node types registered**:
   ```javascript
   const nodeTypes = {
     state: StateNode,
     intent: IntentNode,
     action: ActionNode,
     template: TemplateNode,
     condition: ConditionNode,
   };
   ```

2. **Drag handlers**:
   - `onDragOver` - Prevents default and sets drop effect
   - `onDrop` - Creates new node at drop position
   - `handleDragStart` - Captures dragged node type

3. **Default node data generator**:
   ```javascript
   const getDefaultNodeData = type => {
     switch (type) {
       case 'state':
         return {
           state_id: `STATE_${nextNodeId}`,
           label: 'New State',
           description: '',
           actions: [],
         };
       // ... other types
     }
   };
   ```

4. **Template events**:
   ```vue
   <VueFlow
     @dragover="onDragOver"
     @drop="onDrop"
     @dragenter="handleDragStart"
   >
   ```

### How It Works Now

1. **User drags node from NodePalette**
   - NodePalette sets `dataTransfer` with node type

2. **User drops on canvas**
   - `onDrop` fires
   - Calculates drop position
   - Creates new node with default data
   - Adds to `nodes` array
   - VueFlow renders the node

---

## Testing the Fixes

### Test Drag-and-Drop

1. Refresh the page
2. Navigate to Bot Studio
3. Drag a State node from left palette
4. Drop onto canvas
5. ✅ Node should appear at drop location
6. Double-click node to configure it

### Test Import (After Phase 2A Implementation)

1. Click "Import from JSON" button
2. System reads bot_config from AgentBot
3. Converts states/keywords to visual nodes
4. Displays on canvas
5. Edit visually
6. Click "Compile & Test"
7. System converts back to bot_config JSON
8. Updates AgentBot.bot_config

---

## Roadmap

### ✅ Completed (Phase 1)
- Database schema for bot_flows
- CRUD API for flows
- Visual canvas with VueFlow
- Custom node components
- Drag-and-drop functionality
- Configuration panels

### 🚧 TODO (Phase 2A - Import/Export)
1. Implement `FlowImportService`
2. Implement `FlowCompilerService` (full version)
3. Add "Import from JSON" button
4. Add "Export to JSON" button
5. Test bidirectional conversion
6. Update bot_config when compiling

### 🚧 TODO (Phase 2B - Integration)
1. Auto-import on first studio open
2. Prompt user: "Import existing config?" (Yes/No)
3. If Yes: Import and show visual flow
4. If No: Start with empty canvas
5. When saving: Always update bot_config

---

## Recommended Workflow

**For now (Phase 1)**:
- Use **JSON Editor** for production bots
- Use **Visual Studio** for designing new flows
- Manually copy configurations between them

**After Phase 2A**:
- Click "Import from JSON" to load existing bot
- Edit visually
- Click "Compile & Test" to generate new bot_config
- System automatically updates AgentBot

**Future (Phase 3)**:
- Visual Studio becomes primary interface
- JSON editor becomes "Advanced Mode"
- Bot_config auto-syncs with visual flow

---

## Files Modified

**Drag-and-Drop Fix**:
- `/Users/rhaps/LocalGit/chatwoot/app/javascript/dashboard/routes/dashboard/settings/agentBots/components/BotStudioCanvas.vue`
  - Uncommented node imports
  - Added drag handlers
  - Added default node data generator
  - Added template drag events

---

**Document Version**: 1.0
**Last Updated**: December 5, 2025
