# Visual Bot Studio - Implementation Plan

**Version**: 1.0
**Created**: 2025-01-19
**Status**: In Planning
**Effort Estimate**: 4-6 weeks (can be parallelized)

---

## Executive Summary

This document outlines the implementation of a **Visual Bot Studio** - a node-based, drag-and-drop flow editor for designing Apple Messages for Business conversation bots in Chatwoot. The studio will allow users to visually design conversation flows, configure states and transitions, and manage bot logic without writing JSON.

**Key Features**:
- 🎨 Visual canvas with drag-and-drop nodes
- 🔄 Node types: State, Intent, Action, Template, Condition
- 📝 Visual configuration panels for each node
- 🔗 Connection management between nodes
- 💾 Flow-to-bot_config compilation
- 🎭 Live preview and testing
- 📊 Flow validation and error checking
- 🎯 Template integration with visual preview

---

## Architecture Overview

### High-Level Flow

```
User Designs Flow (Canvas)
    ↓
Visual Nodes (State Machine)
    ↓
Flow Compiler (Generates bot_config JSON)
    ↓
Save to AgentBot.bot_config
    ↓
AcousticHouseBotService (Executes flow)
```

### Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Visual Bot Studio UI                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Canvas     │  │ Node Palette │  │  Properties  │      │
│  │   Editor     │  │   Toolbar    │  │    Panel     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────────────────────────────────────────┐      │
│  │          Live Preview / Test Console             │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│                     Backend Services                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Flow Storage │  │   Compiler   │  │  Validator   │      │
│  │     API      │  │   Service    │  │   Service    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│                    Database Schema                           │
│         bot_flows (visual flow data)                         │
│         agent_bots.bot_config (compiled config)              │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Database Schema & Backend API (Week 1)

### 1.1. Database Schema

**New Table: `bot_flows`**
```ruby
create_table "bot_flows" do |t|
  t.bigint "agent_bot_id", null: false
  t.string "name"
  t.text "description"
  t.jsonb "flow_data", default: {}  # Visual flow structure
  t.jsonb "metadata", default: {}   # Canvas position, zoom, etc.
  t.boolean "is_active", default: true
  t.integer "version", default: 1
  t.timestamps

  t.index ["agent_bot_id"], name: "index_bot_flows_on_agent_bot_id"
end
```

**Flow Data Structure**:
```json
{
  "nodes": [
    {
      "id": "node_1",
      "type": "state",
      "position": { "x": 100, "y": 100 },
      "data": {
        "state_id": "AHA1",
        "label": "Welcome",
        "description": "Initial welcome message",
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
      "position": { "x": 300, "y": 100 },
      "data": {
        "keywords": ["guitar", "guitars", "list picker"],
        "exact_match": false,
        "case_sensitive": false
      }
    }
  ],
  "edges": [
    {
      "id": "edge_1",
      "source": "node_1",
      "target": "node_2",
      "type": "default",
      "data": {
        "condition": null,
        "label": "On keyword match"
      }
    }
  ],
  "metadata": {
    "canvas_zoom": 1.0,
    "canvas_center": { "x": 0, "y": 0 }
  }
}
```

### 1.2. Backend API Endpoints

**New Controller**: `Api::V1::Accounts::AgentBots::FlowsController`

```ruby
# Routes
resources :agent_bots do
  resources :flows, controller: 'agent_bots/flows' do
    member do
      post :compile        # Compile flow to bot_config
      post :validate       # Validate flow structure
      get :preview         # Get preview data
    end
  end
end
```

**Endpoints**:
- `GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows` - List flows
- `GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id` - Get flow
- `POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows` - Create flow
- `PATCH /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id` - Update flow
- `DELETE /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id` - Delete flow
- `POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/compile` - Compile to bot_config
- `POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/validate` - Validate flow
- `GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/preview` - Preview flow

### 1.3. Flow Compiler Service

**Service**: `AppleMessagesForBusiness::FlowCompilerService`

**Purpose**: Convert visual flow to bot_config JSON

```ruby
class AppleMessagesForBusiness::FlowCompilerService
  def initialize(flow)
    @flow = flow
    @nodes = flow.flow_data['nodes']
    @edges = flow.flow_data['edges']
  end

  def compile
    {
      required_templates: extract_required_templates,
      keyword_routes: build_keyword_routes,
      state_handlers: build_state_handlers,
      interactive_handlers: build_interactive_handlers,
      features: extract_features
    }
  end

  private

  def build_state_handlers
    # Convert state nodes to state machine logic
  end

  def build_keyword_routes
    # Convert intent nodes to keyword routing
  end

  def extract_required_templates
    # Find all template nodes
  end
end
```

---

## Phase 2: Flow Editor Library Integration (Week 1-2)

### 2.1. Library Selection

**Recommended**: **Vue Flow** (formerly Vue Flow)
- ✅ Vue 3 compatible
- ✅ TypeScript support
- ✅ Extensive customization
- ✅ Good performance
- ✅ Active maintenance

**Alternative**: **React Flow** (if we want to use React for this component)

**Installation**:
```bash
pnpm add @vue-flow/core @vue-flow/background @vue-flow/controls @vue-flow/minimap
```

### 2.2. Base Canvas Component

**File**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/BotStudioCanvas.vue`

```vue
<script setup>
import { ref, computed } from 'vue';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import { MiniMap } from '@vue-flow/minimap';

// Custom node components
import StateNode from './nodes/StateNode.vue';
import IntentNode from './nodes/IntentNode.vue';
import ActionNode from './nodes/ActionNode.vue';
import TemplateNode from './nodes/TemplateNode.vue';
import ConditionNode from './nodes/ConditionNode.vue';

const props = defineProps({
  botId: {
    type: Number,
    required: true,
  },
  flowId: {
    type: Number,
    default: null,
  },
});

const emit = defineEmits(['save', 'compile']);

// Vue Flow instance
const { onConnect, addEdges, addNodes } = useVueFlow();

const nodes = ref([]);
const edges = ref([]);

// Node types registration
const nodeTypes = {
  state: StateNode,
  intent: IntentNode,
  action: ActionNode,
  template: TemplateNode,
  condition: ConditionNode,
};

// Connection handler
onConnect((params) => {
  addEdges([params]);
});

// Load flow data
const loadFlow = async () => {
  if (!props.flowId) return;

  const response = await store.dispatch('agentBots/getFlow', {
    botId: props.botId,
    flowId: props.flowId,
  });

  if (response?.flow_data) {
    nodes.value = response.flow_data.nodes || [];
    edges.value = response.flow_data.edges || [];
  }
};

// Save flow
const saveFlow = async () => {
  const flowData = {
    nodes: nodes.value,
    edges: edges.value,
  };

  emit('save', flowData);
};

// Compile flow to bot_config
const compileFlow = async () => {
  emit('compile');
};
</script>

<template>
  <div class="bot-studio-canvas">
    <VueFlow
      v-model:nodes="nodes"
      v-model:edges="edges"
      :node-types="nodeTypes"
      fit-view-on-init
      class="vue-flow-container"
    >
      <Background pattern-color="#aaa" :gap="16" />
      <Controls />
      <MiniMap />
    </VueFlow>

    <!-- Toolbar -->
    <div class="studio-toolbar">
      <Button icon="i-lucide-save" @click="saveFlow">Save Flow</Button>
      <Button icon="i-lucide-play" @click="compileFlow">Compile & Test</Button>
    </div>
  </div>
</template>

<style scoped>
.bot-studio-canvas {
  width: 100%;
  height: calc(100vh - 200px);
  position: relative;
}

.vue-flow-container {
  width: 100%;
  height: 100%;
  background: var(--n-slate-1);
}

.studio-toolbar {
  position: absolute;
  top: 20px;
  right: 20px;
  display: flex;
  gap: 8px;
}
</style>
```

---

## Phase 3: Custom Node Components (Week 2-3)

### 3.1. State Node Component

**File**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/nodes/StateNode.vue`

```vue
<script setup>
import { Handle, Position } from '@vue-flow/core';
import { computed } from 'vue';

const props = defineProps({
  id: String,
  data: Object,
});

const emit = defineEmits(['configure']);

const stateLabel = computed(() => props.data.label || 'New State');
const stateId = computed(() => props.data.state_id || 'AHA?');
</script>

<template>
  <div class="state-node" @dblclick="emit('configure', id)">
    <Handle type="target" :position="Position.Left" />

    <div class="node-header state-header">
      <i class="i-lucide-circle-dot" />
      <span class="node-type">State</span>
    </div>

    <div class="node-content">
      <div class="state-id">{{ stateId }}</div>
      <div class="state-label">{{ stateLabel }}</div>

      <div v-if="data.actions?.length" class="action-count">
        {{ data.actions.length }} action(s)
      </div>
    </div>

    <Handle type="source" :position="Position.Right" />
  </div>
</template>

<style scoped>
.state-node {
  background: white;
  border: 2px solid var(--n-blue-8);
  border-radius: 8px;
  min-width: 200px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  cursor: pointer;
}

.state-node:hover {
  border-color: var(--n-blue-9);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.node-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  border-bottom: 1px solid var(--n-weak);
}

.state-header {
  background: var(--n-blue-2);
  color: var(--n-blue-11);
}

.node-type {
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
}

.node-content {
  padding: 12px;
}

.state-id {
  font-family: monospace;
  font-size: 14px;
  font-weight: 600;
  color: var(--n-slate-12);
  margin-bottom: 4px;
}

.state-label {
  font-size: 13px;
  color: var(--n-slate-11);
  margin-bottom: 8px;
}

.action-count {
  font-size: 11px;
  color: var(--n-slate-10);
  font-style: italic;
}
</style>
```

### 3.2. Intent Node Component

**File**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/nodes/IntentNode.vue`

```vue
<script setup>
import { Handle, Position } from '@vue-flow/core';
import { computed } from 'vue';

const props = defineProps({
  id: String,
  data: Object,
});

const keywords = computed(() => props.data.keywords || []);
const keywordPreview = computed(() => {
  if (keywords.value.length === 0) return 'No keywords';
  if (keywords.value.length === 1) return keywords.value[0];
  return `${keywords.value[0]} +${keywords.value.length - 1} more`;
});
</script>

<template>
  <div class="intent-node">
    <Handle type="target" :position="Position.Left" />

    <div class="node-header intent-header">
      <i class="i-lucide-message-square-text" />
      <span class="node-type">Intent</span>
    </div>

    <div class="node-content">
      <div class="keyword-preview">{{ keywordPreview }}</div>
      <div class="match-type">
        {{ data.exact_match ? 'Exact match' : 'Contains' }}
      </div>
    </div>

    <Handle type="source" :position="Position.Right" />
  </div>
</template>

<style scoped>
.intent-node {
  background: white;
  border: 2px solid var(--n-green-8);
  border-radius: 8px;
  min-width: 180px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  cursor: pointer;
}

.intent-header {
  background: var(--n-green-2);
  color: var(--n-green-11);
}

.keyword-preview {
  font-size: 13px;
  font-weight: 500;
  color: var(--n-slate-12);
  margin-bottom: 4px;
}

.match-type {
  font-size: 11px;
  color: var(--n-slate-10);
}
</style>
```

### 3.3. Template Node Component

**File**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/nodes/TemplateNode.vue`

```vue
<script setup>
import { Handle, Position } from '@vue-flow/core';
import { computed } from 'vue';

const props = defineProps({
  id: String,
  data: Object,
});

const templateName = computed(() => props.data.template_name || 'Select template');
const templateType = computed(() => {
  const name = props.data.template_name || '';
  if (name.includes('list_picker')) return 'List Picker';
  if (name.includes('form')) return 'Form';
  if (name.includes('time_picker')) return 'Time Picker';
  return 'Template';
});
</script>

<template>
  <div class="template-node">
    <Handle type="target" :position="Position.Left" />

    <div class="node-header template-header">
      <i class="i-lucide-layout-template" />
      <span class="node-type">Template</span>
    </div>

    <div class="node-content">
      <div class="template-type">{{ templateType }}</div>
      <div class="template-name">{{ templateName }}</div>
    </div>

    <Handle type="source" :position="Position.Right" />
  </div>
</template>

<style scoped>
.template-node {
  background: white;
  border: 2px solid var(--n-purple-8);
  border-radius: 8px;
  min-width: 200px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  cursor: pointer;
}

.template-header {
  background: var(--n-purple-2);
  color: var(--n-purple-11);
}

.template-type {
  font-size: 11px;
  text-transform: uppercase;
  color: var(--n-slate-10);
  margin-bottom: 4px;
}

.template-name {
  font-size: 13px;
  font-weight: 500;
  color: var(--n-slate-12);
  font-family: monospace;
}
</style>
```

### 3.4. Action Node & Condition Node

Similar structure to above, with appropriate styling and data handling.

---

## Phase 4: Configuration Panels (Week 3-4)

### 4.1. Node Configuration Sidebar

**File**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/NodeConfigPanel.vue`

```vue
<script setup>
import { computed, ref, watch } from 'vue';
import StateConfig from './config/StateConfig.vue';
import IntentConfig from './config/IntentConfig.vue';
import TemplateConfig from './config/TemplateConfig.vue';
import ActionConfig from './config/ActionConfig.vue';
import ConditionConfig from './config/ConditionConfig.vue';

const props = defineProps({
  selectedNode: Object,
});

const emit = defineEmits(['update', 'close']);

const configComponent = computed(() => {
  if (!props.selectedNode) return null;

  const componentMap = {
    state: StateConfig,
    intent: IntentConfig,
    template: TemplateConfig,
    action: ActionConfig,
    condition: ConditionConfig,
  };

  return componentMap[props.selectedNode.type];
});

const nodeData = ref(null);

watch(() => props.selectedNode, (newNode) => {
  if (newNode) {
    nodeData.value = { ...newNode.data };
  }
}, { immediate: true });

const saveConfig = () => {
  emit('update', {
    id: props.selectedNode.id,
    data: nodeData.value,
  });
};
</script>

<template>
  <div v-if="selectedNode" class="node-config-panel">
    <div class="panel-header">
      <h3>Configure {{ selectedNode.type }}</h3>
      <Button icon="i-lucide-x" xs faded @click="emit('close')" />
    </div>

    <div class="panel-content">
      <component
        :is="configComponent"
        v-model="nodeData"
        @save="saveConfig"
      />
    </div>

    <div class="panel-footer">
      <Button faded @click="emit('close')">Cancel</Button>
      <Button @click="saveConfig">Save</Button>
    </div>
  </div>
</template>

<style scoped>
.node-config-panel {
  position: absolute;
  right: 0;
  top: 0;
  width: 400px;
  height: 100%;
  background: white;
  border-left: 1px solid var(--n-weak);
  display: flex;
  flex-direction: column;
  z-index: 10;
}

.panel-header {
  padding: 16px;
  border-bottom: 1px solid var(--n-weak);
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.panel-content {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
}

.panel-footer {
  padding: 16px;
  border-top: 1px solid var(--n-weak);
  display: flex;
  gap: 8px;
  justify-content: flex-end;
}
</style>
```

### 4.2. State Configuration Form

**File**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/config/StateConfig.vue`

```vue
<script setup>
import { ref, watch } from 'vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const props = defineProps({
  modelValue: Object,
});

const emit = defineEmits(['update:modelValue', 'save']);

const localData = ref({
  state_id: '',
  label: '',
  description: '',
  actions: [],
  ...props.modelValue,
});

watch(localData, (newVal) => {
  emit('update:modelValue', newVal);
}, { deep: true });

const addAction = () => {
  localData.value.actions.push({
    type: 'send_template',
    template_name: '',
  });
};

const removeAction = (index) => {
  localData.value.actions.splice(index, 1);
};
</script>

<template>
  <div class="state-config">
    <Input
      v-model="localData.state_id"
      label="State ID"
      placeholder="e.g., AHA1"
      help="Unique identifier for this state"
    />

    <Input
      v-model="localData.label"
      label="Label"
      placeholder="e.g., Welcome Message"
    />

    <TextArea
      v-model="localData.description"
      label="Description"
      placeholder="Describe what happens in this state"
      rows="3"
    />

    <div class="section">
      <div class="section-header">
        <h4>Actions</h4>
        <Button icon="i-lucide-plus" xs @click="addAction">Add Action</Button>
      </div>

      <div v-for="(action, index) in localData.actions" :key="index" class="action-item">
        <Select
          v-model="action.type"
          label="Action Type"
          :options="[
            { value: 'send_template', label: 'Send Template' },
            { value: 'send_text', label: 'Send Text' },
            { value: 'update_attribute', label: 'Update Attribute' },
          ]"
        />

        <Input
          v-if="action.type === 'send_template'"
          v-model="action.template_name"
          label="Template Name"
          placeholder="e.g., ah_main_menu"
        />

        <Button
          icon="i-lucide-trash-2"
          xs
          faded
          ruby
          @click="removeAction(index)"
        >
          Remove
        </Button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.state-config {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.section {
  margin-top: 16px;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.action-item {
  padding: 12px;
  border: 1px solid var(--n-weak);
  border-radius: 6px;
  margin-bottom: 8px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
</style>
```

---

## Phase 5: Main Studio View & Integration (Week 4)

### 5.1. Bot Studio Main View

**File**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/BotStudio.vue`

**Route**: `/app/accounts/:accountId/settings/agent-bots/:botId/studio`

```vue
<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import BotStudioCanvas from './components/BotStudioCanvas.vue';
import NodePalette from './components/NodePalette.vue';
import NodeConfigPanel from './components/NodeConfigPanel.vue';

const route = useRoute();
const store = useStore();

const botId = computed(() => parseInt(route.params.botId));
const bot = ref(null);
const currentFlow = ref(null);
const selectedNode = ref(null);

const loadBot = async () => {
  bot.value = await store.dispatch('agentBots/show', botId.value);
};

const loadFlow = async () => {
  // Load or create default flow
  const flows = await store.dispatch('agentBots/getFlows', botId.value);
  currentFlow.value = flows?.[0] || await createDefaultFlow();
};

const createDefaultFlow = async () => {
  return await store.dispatch('agentBots/createFlow', {
    botId: botId.value,
    name: 'Main Flow',
    flow_data: {
      nodes: [],
      edges: [],
    },
  });
};

const saveFlow = async (flowData) => {
  await store.dispatch('agentBots/updateFlow', {
    botId: botId.value,
    flowId: currentFlow.value.id,
    flow_data: flowData,
  });
};

const compileFlow = async () => {
  const result = await store.dispatch('agentBots/compileFlow', {
    botId: botId.value,
    flowId: currentFlow.value.id,
  });

  if (result.success) {
    alert('Flow compiled successfully! Bot config updated.');
  }
};

onMounted(() => {
  loadBot();
  loadFlow();
});
</script>

<template>
  <div class="bot-studio">
    <div class="studio-header">
      <div class="header-left">
        <router-link :to="`/app/accounts/${route.params.accountId}/settings/agent-bots`">
          <Button icon="i-lucide-arrow-left" faded xs>Back to Bots</Button>
        </router-link>
        <h2>{{ bot?.name }} - Visual Studio</h2>
      </div>
      <div class="header-right">
        <Button icon="i-lucide-play" @click="compileFlow">
          Compile & Test
        </Button>
      </div>
    </div>

    <div class="studio-body">
      <NodePalette />

      <BotStudioCanvas
        :bot-id="botId"
        :flow-id="currentFlow?.id"
        @save="saveFlow"
        @compile="compileFlow"
        @node-selected="selectedNode = $event"
      />

      <NodeConfigPanel
        :selected-node="selectedNode"
        @update="updateNodeConfig"
        @close="selectedNode = null"
      />
    </div>
  </div>
</template>

<style scoped>
.bot-studio {
  width: 100%;
  height: 100vh;
  display: flex;
  flex-direction: column;
  background: var(--n-slate-1);
}

.studio-header {
  height: 60px;
  padding: 0 20px;
  border-bottom: 1px solid var(--n-weak);
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: white;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 16px;
}

.studio-body {
  flex: 1;
  display: flex;
  position: relative;
  overflow: hidden;
}
</style>
```

### 5.2. Update Bot Index to Include Studio Link

**File**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/Index.vue`

Add "Open Studio" button for AMB bots:

```vue
<Button
  v-if="bot.bot_type === 'apple_messages_for_business'"
  v-tooltip.top="$t('AGENT_BOTS.OPEN_STUDIO')"
  icon="i-lucide-workflow"
  xs
  faded
  @click="openStudio(bot)"
/>
```

---

## Phase 6: Flow Compiler Implementation (Week 5)

**Full compiler implementation in Ruby to convert visual flow to bot_config**

See detailed implementation in separate section below.

---

## Phase 7: Testing & Preview (Week 5-6)

### 7.1. Flow Validator

Validate flow before compilation:
- All nodes have required data
- No orphaned nodes
- Valid connections
- Templates exist
- No circular dependencies

### 7.2. Live Preview

Interactive test console to simulate bot conversations.

---

## Implementation Strategy

### Parallel Work Streams:

**Stream 1 (Backend)**: Week 1-2
- Database migration
- API endpoints
- Flow compiler service

**Stream 2 (Canvas)**: Week 1-3
- Vue Flow integration
- Custom node components
- Canvas functionality

**Stream 3 (Configuration)**: Week 2-4
- Configuration panels
- Form components
- Validation

**Stream 4 (Integration)**: Week 4-5
- Main studio view
- Routes and navigation
- Vuex store actions

**Stream 5 (Compiler)**: Week 5
- Flow-to-bot_config compiler
- Validator service

**Stream 6 (Testing)**: Week 5-6
- Live preview
- Flow testing
- Documentation

---

## Next Steps

Would you like me to:
1. **Start implementing in parallel** using multiple agents?
2. **Focus on a specific phase first** (e.g., backend, then frontend)?
3. **Create a proof-of-concept** with basic canvas and one node type?

Let me know your preference and I'll coordinate the parallel agents to start building!
