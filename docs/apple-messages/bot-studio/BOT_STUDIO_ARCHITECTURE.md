# Visual Bot Studio - Architecture Diagram

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Bot List (Index.vue)                       │  │
│  │  ┌────────────────────────────────────────────────────────┐  │  │
│  │  │ Bot: Acoustic House | [Version History] [Manage Inboxes]│  │  │
│  │  │                      [🔧 Open Studio] ← New Button      │  │  │
│  │  └────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                               ↓ Click                               │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              BotStudio.vue (Main View)                        │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │  Header: [← Back] Bot Name [Save] [Compile & Test]          │  │
│  ├────────────┬────────────────────────┬──────────────────────┤  │
│  │ NodePalette│  BotStudioCanvas.vue   │ NodeConfigPanel.vue  │  │
│  │            │                        │                      │  │
│  │ • State    │  ┌──────────────────┐ │ [Dynamic Config Form]│  │
│  │ • Intent   │  │   Vue Flow       │ │                      │  │
│  │ • Action   │  │   Canvas         │ │ ┌─────────────────┐ │  │
│  │ • Template │  │                  │ │ │ StateConfig.vue │ │  │
│  │ • Condition│  │  [Node Graph]    │ │ │ IntentConfig    │ │  │
│  │            │  │                  │ │ │ TemplateConfig  │ │  │
│  │ [Drag Me]  │  │  Background      │ │ │ ActionConfig    │ │  │
│  │            │  │  Controls        │ │ │ ConditionConfig │ │  │
│  │            │  │  MiniMap         │ │ └─────────────────┘ │  │
│  │            │  └──────────────────┘ │                      │  │
│  └────────────┴────────────────────────┴──────────────────────┘  │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
                               ↕
┌─────────────────────────────────────────────────────────────────────┐
│                      VUEX STORE (State Management)                   │
├─────────────────────────────────────────────────────────────────────┤
│  State:                                                              │
│    - flows: []                                                       │
│    - uiFlags: { isFetchingFlows, isCreatingFlow, ... }              │
│                                                                       │
│  Actions:                                                            │
│    - getFlows(botId) → Fetch all flows                             │
│    - getFlow(botId, flowId) → Fetch single flow                    │
│    - createFlow(botId, flowData) → Create new flow                 │
│    - updateFlow(botId, flowId, flowData) → Update flow             │
│    - deleteFlow(botId, flowId) → Delete flow                       │
│    - compileFlow(botId, flowId) → Compile to bot_config            │
│    - validateFlow(botId, flowId) → Validate structure              │
│    - previewFlow(botId, flowId) → Get preview data                 │
│                                                                       │
│  Mutations:                                                          │
│    - SET_FLOWS, ADD_FLOW, UPDATE_FLOW, DELETE_FLOW                  │
└─────────────────────────────────────────────────────────────────────┘
                               ↕
┌─────────────────────────────────────────────────────────────────────┐
│                      API LAYER (agentBots.js)                        │
├─────────────────────────────────────────────────────────────────────┤
│  GET    /api/v1/accounts/:account_id/agent_bots/:bot_id/flows       │
│  POST   /api/v1/accounts/:account_id/agent_bots/:bot_id/flows       │
│  GET    /api/v1/accounts/:account_id/agent_bots/:bot_id/flows/:id   │
│  PATCH  /api/v1/accounts/:account_id/agent_bots/:bot_id/flows/:id   │
│  DELETE /api/v1/accounts/:account_id/agent_bots/:bot_id/flows/:id   │
│  POST   /api/v1/accounts/:account_id/agent_bots/:bot_id/flows/:id/compile   │
│  POST   /api/v1/accounts/:account_id/agent_bots/:bot_id/flows/:id/validate  │
│  GET    /api/v1/accounts/:account_id/agent_bots/:bot_id/flows/:id/preview   │
└─────────────────────────────────────────────────────────────────────┘
                               ↕
┌─────────────────────────────────────────────────────────────────────┐
│                RAILS BACKEND (Controllers & Services)                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  FlowsController                                                     │
│  ├── index → List all flows                                         │
│  ├── show → Get single flow                                         │
│  ├── create → Create new flow                                       │
│  ├── update → Update flow                                           │
│  ├── destroy → Delete flow                                          │
│  ├── compile → FlowCompilerService.compile(flow) [Placeholder]     │
│  ├── validate → FlowValidatorService.validate(flow) [Placeholder]   │
│  └── preview → FlowPreviewService.preview(flow) [Placeholder]       │
│                                                                       │
│  Services (Phase 2):                                                 │
│  ├── FlowCompilerService → Convert flow_data to bot_config          │
│  ├── FlowValidatorService → Validate nodes and connections          │
│  └── FlowPreviewService → Generate preview/test data                │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
                               ↕
┌─────────────────────────────────────────────────────────────────────┐
│                    DATABASE (PostgreSQL)                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  agent_bots                           bot_flows                      │
│  ┌──────────────┐                    ┌──────────────────┐           │
│  │ id           │ ←──────────────────│ agent_bot_id (FK)│           │
│  │ name         │   has_many         │ name             │           │
│  │ bot_type     │   :bot_flows       │ description      │           │
│  │ bot_config   │                    │ flow_data (JSONB)│           │
│  │ ...          │                    │ metadata (JSONB) │           │
│  └──────────────┘                    │ is_active        │           │
│                                       │ version          │           │
│                                       │ created_at       │           │
│                                       │ updated_at       │           │
│                                       └──────────────────┘           │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Hierarchy

```
BotStudio.vue (Main Container)
├── Header
│   ├── Back Button
│   ├── Bot Name & Subtitle
│   ├── Save Flow Button → handleSaveFlow()
│   └── Compile & Test Button → handleCompileFlow()
│
├── Body (Three-Column Layout)
│   ├── Left Column: NodePalette.vue
│   │   ├── State Node Button (Blue)
│   │   ├── Intent Node Button (Green)
│   │   ├── Action Node Button (Orange)
│   │   ├── Template Node Button (Purple)
│   │   └── Condition Node Button (Yellow)
│   │
│   ├── Center Column: BotStudioCanvas.vue
│   │   ├── VueFlow Component
│   │   │   ├── Background
│   │   │   ├── Controls
│   │   │   ├── MiniMap
│   │   │   └── Custom Nodes
│   │   │       ├── StateNode.vue
│   │   │       ├── IntentNode.vue
│   │   │       ├── TemplateNode.vue
│   │   │       ├── ActionNode.vue
│   │   │       └── ConditionNode.vue
│   │   │
│   │   └── Toolbar (Overlay)
│   │       ├── Save Flow
│   │       └── Compile & Test
│   │
│   └── Right Column: NodeConfigPanel.vue
│       ├── Panel Header
│       │   ├── Node Type Title
│       │   └── Close Button
│       │
│       ├── Panel Content (Dynamic Component)
│       │   ├── StateConfig.vue
│       │   ├── IntentConfig.vue
│       │   ├── TemplateConfig.vue
│       │   ├── ActionConfig.vue
│       │   └── ConditionConfig.vue
│       │
│       └── Panel Footer
│           ├── Cancel Button
│           └── Save Button
```

## Data Flow Diagram

### 1. Loading a Flow

```
User clicks "Open Studio"
    ↓
BotStudio.vue mounts
    ↓
onMounted() calls loadBot()
    ↓
store.dispatch('agentBots/show', botId)
    ↓
AgentBotsAPI.show(botId)
    ↓
GET /api/v1/accounts/:account_id/agent_bots/:bot_id
    ↓
AgentBotsController#show
    ↓
Returns bot data
    ↓
loadOrCreateFlow() checks for existing flows
    ↓
store.dispatch('agentBots/getFlows', botId)
    ↓
AgentBotsAPI.getFlows(botId)
    ↓
GET /api/v1/accounts/:account_id/agent_bots/:bot_id/flows
    ↓
FlowsController#index
    ↓
Returns flows array or []
    ↓
If flows exist: Load first flow
If no flows: Create default flow
    ↓
BotStudioCanvas receives flow data
    ↓
VueFlow renders nodes and edges
```

### 2. Creating/Editing a Node

```
User drags node from NodePalette
    ↓
HTML5 drag event
    ↓
[Not yet implemented: Drop handler in canvas]
    ↓
OR: User clicks existing node
    ↓
VueFlow emits node-click event
    ↓
BotStudioCanvas captures event
    ↓
Emits 'node-selected' to BotStudio
    ↓
BotStudio sets selectedNode ref
    ↓
NodeConfigPanel receives selectedNode prop
    ↓
Dynamically loads appropriate config component:
  - StateNode → StateConfig.vue
  - IntentNode → IntentConfig.vue
  - TemplateNode → TemplateConfig.vue
  - ActionNode → ActionConfig.vue
  - ConditionNode → ConditionConfig.vue
    ↓
User fills form and clicks Save
    ↓
Config component emits 'update:modelValue'
    ↓
NodeConfigPanel emits 'update' to BotStudio
    ↓
BotStudio updates node data in VueFlow
    ↓
Canvas re-renders with updated node
```

### 3. Saving a Flow

```
User clicks "Save Flow"
    ↓
BotStudio.handleSaveFlow()
    ↓
Collects current nodes and edges from canvas
    ↓
store.dispatch('agentBots/updateFlow', {
  botId,
  flowId,
  flow_data: { nodes, edges }
})
    ↓
AgentBotsAPI.updateFlow(botId, flowId, flowData)
    ↓
PATCH /api/v1/accounts/:account_id/agent_bots/:bot_id/flows/:id
    ↓
FlowsController#update
    ↓
BotFlow.find(id).update!(flow_data: params[:flow_data])
    ↓
Returns updated flow
    ↓
Vuex commits UPDATE_FLOW mutation
    ↓
UI shows success alert
```

### 4. Compiling a Flow (Phase 2)

```
User clicks "Compile & Test"
    ↓
BotStudio.handleCompileFlow()
    ↓
store.dispatch('agentBots/compileFlow', { botId, flowId })
    ↓
AgentBotsAPI.compileFlow(botId, flowId)
    ↓
POST /api/v1/accounts/:account_id/agent_bots/:bot_id/flows/:id/compile
    ↓
FlowsController#compile
    ↓
FlowCompilerService.compile(@flow)
    ↓
Reads flow_data (nodes and edges)
    ↓
Extracts:
  - required_templates from Template nodes
  - keyword_routes from Intent nodes
  - state_handlers from State nodes
  - interactive_handlers from Action nodes
  - features flags from config
    ↓
Generates bot_config JSON structure:
{
  required_templates: [...],
  keyword_routes: {...},
  state_handlers: {...},
  interactive_handlers: {...},
  features: {...}
}
    ↓
Updates AgentBot.bot_config
    ↓
Returns compiled config
    ↓
UI shows success alert
```

## Node Type Details

### State Node (Blue)
```
┌─────────────────────────┐
│ ● State                 │ ← Header (blue background)
├─────────────────────────┤
│ AHA1                    │ ← State ID (monospace)
│ Welcome Message         │ ← Label
│ 2 action(s)             │ ← Action count
└─────────────────────────┘
   ↑                    ↑
 target              source
 handle              handle
```

**Data Structure**:
```javascript
{
  id: "node_1",
  type: "state",
  position: { x: 100, y: 100 },
  data: {
    state_id: "AHA1",
    label: "Welcome Message",
    description: "Initial state",
    actions: [
      { type: "send_template", template_name: "ah_main_menu" },
      { type: "update_attribute", key: "state", value: "AHA1" }
    ]
  }
}
```

### Intent Node (Green)
```
┌─────────────────────────┐
│ 💬 Intent               │ ← Header (green background)
├─────────────────────────┤
│ guitar +2 more          │ ← Keywords preview
│ Contains                │ ← Match type
└─────────────────────────┘
   ↑                    ↑
 target              source
 handle              handle
```

**Data Structure**:
```javascript
{
  id: "node_2",
  type: "intent",
  position: { x: 300, y: 100 },
  data: {
    keywords: ["guitar", "guitars", "list picker"],
    exact_match: false,
    case_sensitive: false
  }
}
```

### Template Node (Purple)
```
┌─────────────────────────┐
│ 📄 Template             │ ← Header (purple background)
├─────────────────────────┤
│ LIST PICKER             │ ← Template type
│ ah_main_menu            │ ← Template name
└─────────────────────────┘
   ↑                    ↑
 target              source
 handle              handle
```

**Data Structure**:
```javascript
{
  id: "node_3",
  type: "template",
  position: { x: 500, y: 100 },
  data: {
    template_name: "ah_main_menu",
    template_type: "list_picker"
  }
}
```

### Action Node (Orange)
```
┌─────────────────────────┐
│ ⚡ Action               │ ← Header (orange background)
├─────────────────────────┤
│ Send Message            │ ← Action type
│ Send welcome text       │ ← Label
└─────────────────────────┘
   ↑                    ↑
 target              source
 handle              handle
```

**Data Structure**:
```javascript
{
  id: "node_4",
  type: "action",
  position: { x: 700, y: 100 },
  data: {
    action_type: "send_message",
    label: "Send welcome text",
    parameters: {
      message: "Welcome to our store!"
    }
  }
}
```

### Condition Node (Yellow)
```
┌─────────────────────────┐
│ 🔀 Condition            │ ← Header (yellow background)
├─────────────────────────┤
│ user.age >= 18          │ ← Expression
│ Check age               │ ← Label
└─────────────────────────┘
   ↑          ↑         ↑
 target    source    source
 handle    (true)   (false)
           30%       70%
```

**Data Structure**:
```javascript
{
  id: "node_5",
  type: "condition",
  position: { x: 900, y: 100 },
  data: {
    condition_expression: "user.age >= 18",
    label: "Check age",
    true_label: "Adult",
    false_label: "Minor"
  }
}
```

## Edge/Connection Structure

```javascript
{
  id: "edge_1",
  source: "node_1",      // Source node ID
  target: "node_2",      // Target node ID
  sourceHandle: "a",     // Optional: which handle on source
  targetHandle: "b",     // Optional: which handle on target
  type: "default",       // Edge type (default, step, straight, smoothstep)
  animated: false,       // Animation effect
  label: "On guitar",    // Optional edge label
  data: {
    condition: null      // Optional condition data
  }
}
```

## Technology Stack Summary

### Backend
- **Ruby on Rails** 7.1
- **PostgreSQL** with JSONB
- **ActiveRecord** for ORM
- **RuboCop** for linting

### Frontend
- **Vue 3** with Composition API
- **Vue Flow** for node-based UI
- **Vuex** for state management
- **Vue Router** for routing
- **Tailwind CSS** for styling
- **Lucide Icons** for iconography
- **vue-i18n** for internationalization
- **Axios** for HTTP requests
- **ESLint** for linting

### Libraries
- `@vue-flow/core` - Main flow library
- `@vue-flow/background` - Canvas background
- `@vue-flow/controls` - Zoom/pan controls
- `@vue-flow/minimap` - Mini overview map

---

**Document Version**: 1.0
**Last Updated**: December 5, 2025
