# Vuex Flow Management Usage Guide

## Overview

The agentBots Vuex module now includes comprehensive flow data management for visual conversation flow editing. This enables loading, editing, validating, and saving conversation flows stored in `bot_config.conversation_flow`.

## Architecture

### Data Flow
```
bot_config.conversation_flow (backend)
  ↓ [parseFlow]
VueFlow format (nodes, edges)
  ↓ [Visual Editing]
Updated VueFlow format
  ↓ [compileFlow]
bot_config.conversation_flow (save to backend)
```

### State Structure

```javascript
state: {
  currentFlow: {
    nodes: [],      // VueFlow nodes
    edges: [],      // VueFlow edges
    viewport: { x: 0, y: 0, zoom: 1 }
  },
  flowValidation: {
    isValid: true,
    errors: []
  }
}
```

## Usage in Vue Components

### 1. Loading a Flow

```vue
<script setup>
import { computed, onMounted } from 'vue';
import { useStore } from 'vuex';

const store = useStore();
const botId = 123;

// Getters
const nodes = computed(() => store.getters['agentBots/getFlowNodes']);
const edges = computed(() => store.getters['agentBots/getFlowEdges']);
const viewport = computed(() => store.getters['agentBots/getFlowViewport']);
const isValid = computed(() => store.getters['agentBots/isFlowValid']);
const validationErrors = computed(() => store.getters['agentBots/getFlowValidationErrors']);
const isLoading = computed(() => store.state.agentBots.uiFlags.isLoadingFlow);

onMounted(async () => {
  // Load flow from bot_config
  const result = await store.dispatch('agentBots/loadFlow', botId);

  if (result) {
    console.log('Flow loaded:', result.nodes.length, 'nodes');
    console.log('Validation:', result.validation);
  }
});
</script>

<template>
  <div v-if="isLoading">Loading flow...</div>
  <div v-else>
    <VueFlow
      v-model:nodes="nodes"
      v-model:edges="edges"
      v-model:viewport="viewport"
    />

    <div v-if="!isValid" class="validation-errors">
      <h3>Flow Validation Errors:</h3>
      <ul>
        <li v-for="error in validationErrors" :key="error.message">
          {{ error.message }}
        </li>
      </ul>
    </div>
  </div>
</template>
```

### 2. Adding a Node

```javascript
// Add a new state node
const addStateNode = () => {
  const newNode = {
    id: `state_${Date.now()}`,
    type: 'state',
    position: { x: 100, y: 100 },
    data: {
      label: 'New State',
      stateType: 'standard',
      config: {
        state_id: `state_${Date.now()}`,
        label: 'New State',
        state_type: 'standard',
        actions: [],
        transitions: []
      }
    }
  };

  await store.dispatch('agentBots/addNode', newNode);
};

// Add an intent node
const addIntentNode = () => {
  const newNode = {
    id: `intent_${Date.now()}`,
    type: 'intent',
    position: { x: 200, y: 200 },
    data: {
      label: 'Greeting Intent',
      patterns: ['hello', 'hi', 'hey'],
      config: {
        intent_id: `intent_${Date.now()}`,
        name: 'Greeting Intent',
        patterns: ['hello', 'hi', 'hey']
      }
    }
  };

  await store.dispatch('agentBots/addNode', newNode);
};
```

### 3. Updating a Node

```javascript
const updateNode = (nodeId, newData) => {
  const updatedNode = {
    id: nodeId,
    data: {
      label: newData.label,
      config: {
        ...newData
      }
    }
  };

  await store.dispatch('agentBots/updateNode', updatedNode);
};

// Example: Update state configuration
const updateStateConfig = (stateId) => {
  await updateNode(stateId, {
    label: 'Updated State Name',
    state_type: 'start',
    actions: [
      {
        action_type: 'send_message',
        template_id: 'template_123'
      }
    ]
  });
};
```

### 4. Adding an Edge (Transition)

```javascript
const addTransition = (sourceId, targetId, condition = '') => {
  const newEdge = {
    id: `${sourceId}_${targetId}_${Date.now()}`,
    source: sourceId,
    target: targetId,
    label: condition,
    type: condition ? 'conditional' : 'default',
    data: {
      condition,
      priority: 0
    }
  };

  await store.dispatch('agentBots/addEdge', newEdge);
};

// Example: Add conditional transition
await addTransition('state_1', 'state_2', 'user_confirmed');
```

### 5. Deleting Nodes and Edges

```javascript
// Delete a node (also removes connected edges)
const deleteNode = async (nodeId) => {
  await store.dispatch('agentBots/deleteNode', nodeId);
};

// Delete an edge
const deleteEdge = async (edgeId) => {
  await store.dispatch('agentBots/deleteEdge', edgeId);
};
```

### 6. Saving the Flow

```javascript
const saveFlow = async () => {
  const isSaving = computed(() => store.state.agentBots.uiFlags.isSavingFlow);

  try {
    const result = await store.dispatch('agentBots/saveFlow', {
      botId: botId,
      // Optional: provide custom flowData, otherwise uses state.currentFlow
      flowData: {
        nodes: nodes.value,
        edges: edges.value
      }
    });

    if (result) {
      console.log('Flow saved successfully');
    }
  } catch (error) {
    console.error('Flow validation failed:', error.message);
    // Check validation errors
    const errors = store.getters['agentBots/getFlowValidationErrors'];
    errors.forEach(err => console.error(err.message));
  }
};
```

### 7. Validating the Flow

```javascript
// Manual validation trigger
const validateFlow = async () => {
  const validation = await store.dispatch('agentBots/validateFlow');

  if (!validation.isValid) {
    console.error('Validation errors:', validation.errors);

    // Group errors by type
    const errorsByType = validation.errors.reduce((acc, err) => {
      acc[err.type] = acc[err.type] || [];
      acc[err.type].push(err);
      return acc;
    }, {});

    console.log('Errors by type:', errorsByType);
  }
};
```

### 8. Using Getters for Specific Data

```javascript
// Get specific node
const node = computed(() =>
  store.getters['agentBots/getFlowNode']('state_123')
);

// Get specific edge
const edge = computed(() =>
  store.getters['agentBots/getFlowEdge']('edge_123')
);

// Get all edges connected to a node
const connectedEdges = computed(() =>
  store.getters['agentBots/getConnectedEdges']('state_123')
);
```

### 9. Viewport Management

```javascript
// Update viewport (position/zoom)
const updateViewport = (viewport) => {
  store.dispatch('agentBots/updateViewport', viewport);
};

// Example: Center viewport
const centerViewport = () => {
  updateViewport({
    x: 0,
    y: 0,
    zoom: 1
  });
};

// Example: Zoom in
const zoomIn = () => {
  const currentViewport = store.getters['agentBots/getFlowViewport'];
  updateViewport({
    ...currentViewport,
    zoom: Math.min(currentViewport.zoom * 1.2, 2)
  });
};
```

### 10. Clearing the Flow

```javascript
// Clear all flow data
const clearFlow = () => {
  store.dispatch('agentBots/clearFlow');
};
```

## Complete Component Example

```vue
<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { VueFlow, useVueFlow } from '@vue-flow/core';

const props = defineProps({
  botId: {
    type: Number,
    required: true
  }
});

const store = useStore();
const { fitView } = useVueFlow();

// State
const nodes = computed({
  get: () => store.getters['agentBots/getFlowNodes'],
  set: (value) => store.commit('agentBots/SET_FLOW_DATA', {
    nodes: value,
    edges: edges.value
  })
});

const edges = computed({
  get: () => store.getters['agentBots/getFlowEdges'],
  set: (value) => store.commit('agentBots/SET_FLOW_DATA', {
    nodes: nodes.value,
    edges: value
  })
});

const viewport = computed({
  get: () => store.getters['agentBots/getFlowViewport'],
  set: (value) => store.dispatch('agentBots/updateViewport', value)
});

const isValid = computed(() => store.getters['agentBots/isFlowValid']);
const validationErrors = computed(() => store.getters['agentBots/getFlowValidationErrors']);
const isLoading = computed(() => store.state.agentBots.uiFlags.isLoadingFlow);
const isSaving = computed(() => store.state.agentBots.uiFlags.isSavingFlow);

// Methods
const loadFlow = async () => {
  const result = await store.dispatch('agentBots/loadFlow', props.botId);
  if (result) {
    setTimeout(() => fitView(), 100);
  }
};

const saveFlow = async () => {
  try {
    await store.dispatch('agentBots/saveFlow', { botId: props.botId });
    // Success notification
  } catch (error) {
    // Error notification
  }
};

const addStateNode = () => {
  const newNode = {
    id: `state_${Date.now()}`,
    type: 'state',
    position: { x: Math.random() * 400, y: Math.random() * 400 },
    data: {
      label: 'New State',
      stateType: 'standard',
      config: {
        state_id: `state_${Date.now()}`,
        label: 'New State',
        state_type: 'standard',
        actions: [],
        transitions: []
      }
    }
  };

  store.dispatch('agentBots/addNode', newNode);
};

const onNodeClick = (event) => {
  console.log('Node clicked:', event.node);
};

const onConnect = (params) => {
  const newEdge = {
    id: `${params.source}_${params.target}_${Date.now()}`,
    source: params.source,
    target: params.target,
    type: 'default'
  };

  store.dispatch('agentBots/addEdge', newEdge);
};

const onNodeDelete = (nodes) => {
  nodes.forEach(node => {
    store.dispatch('agentBots/deleteNode', node.id);
  });
};

const onEdgeDelete = (edges) => {
  edges.forEach(edge => {
    store.dispatch('agentBots/deleteEdge', edge.id);
  });
};

onMounted(() => {
  loadFlow();
});
</script>

<template>
  <div class="flow-editor">
    <!-- Toolbar -->
    <div class="toolbar">
      <button @click="addStateNode" :disabled="isLoading || isSaving">
        Add State
      </button>
      <button @click="saveFlow" :disabled="isLoading || isSaving || !isValid">
        {{ isSaving ? 'Saving...' : 'Save Flow' }}
      </button>
      <button @click="loadFlow" :disabled="isLoading || isSaving">
        Reload
      </button>
    </div>

    <!-- Validation Errors -->
    <div v-if="!isValid" class="validation-errors">
      <h3>Validation Errors:</h3>
      <ul>
        <li v-for="error in validationErrors" :key="error.message">
          {{ error.message }}
        </li>
      </ul>
    </div>

    <!-- Flow Canvas -->
    <div v-if="isLoading" class="loading">
      Loading flow...
    </div>
    <VueFlow
      v-else
      v-model:nodes="nodes"
      v-model:edges="edges"
      v-model:viewport="viewport"
      @node-click="onNodeClick"
      @connect="onConnect"
      @nodes-delete="onNodeDelete"
      @edges-delete="onEdgeDelete"
    >
      <!-- Custom node types can be added here -->
    </VueFlow>
  </div>
</template>

<style scoped>
.flow-editor {
  width: 100%;
  height: 100vh;
  display: flex;
  flex-direction: column;
}

.toolbar {
  padding: 1rem;
  background: #f5f5f5;
  border-bottom: 1px solid #ddd;
}

.validation-errors {
  padding: 1rem;
  background: #fee;
  border-bottom: 1px solid #fcc;
}

.loading {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
}

.vue-flow-wrapper {
  flex: 1;
}
</style>
```

## Validation Rules

The flow validation system checks for:

1. **Duplicate Node IDs**: All nodes must have unique IDs
2. **Invalid Edges**: Edges must connect to existing nodes
3. **Start State Required**: At least one state must be marked as a start state
4. **Orphaned Nodes**: Nodes (except start states) must have at least one connection

### Error Types

```javascript
{
  type: 'duplicate_ids',
  message: 'Duplicate node IDs found: state_1, state_2',
  nodeIds: ['state_1', 'state_2']
}

{
  type: 'invalid_edge',
  message: 'Edge edge_123 references non-existent source node: state_999',
  edgeId: 'edge_123'
}

{
  type: 'no_start_state',
  message: 'Flow must have at least one start state'
}

{
  type: 'orphaned_node',
  message: 'Node state_5 is orphaned (no connections)',
  nodeId: 'state_5'
}
```

## Data Format Reference

### VueFlow Node Format

```javascript
{
  id: 'state_1',              // Unique node ID
  type: 'state',              // Node type: 'state', 'intent', 'action'
  position: { x: 100, y: 100 }, // Canvas position
  data: {
    label: 'Welcome State',   // Display label
    stateType: 'start',       // For states: 'start', 'standard', 'end'
    config: {                 // Original bot_config data
      state_id: 'state_1',
      label: 'Welcome State',
      state_type: 'start',
      actions: [...],
      transitions: [...]
    }
  }
}
```

### VueFlow Edge Format

```javascript
{
  id: 'state_1_state_2_0',    // Unique edge ID
  source: 'state_1',          // Source node ID
  target: 'state_2',          // Target node ID
  label: 'user_confirmed',    // Display label
  type: 'conditional',        // Edge type: 'conditional', 'default', 'intent-trigger'
  data: {
    condition: 'user_confirmed', // Condition for transition
    priority: 0               // Transition priority
  }
}
```

### bot_config.conversation_flow Format

```javascript
{
  states: [
    {
      state_id: 'state_1',
      label: 'Welcome State',
      state_type: 'start',
      actions: [
        {
          action_type: 'send_message',
          template_id: 'template_123'
        }
      ],
      transitions: [
        {
          next_state: 'state_2',
          condition: 'user_confirmed',
          priority: 0
        }
      ]
    }
  ],
  intents: [
    {
      intent_id: 'intent_1',
      name: 'Greeting',
      patterns: ['hello', 'hi'],
      target_state: 'state_1'
    }
  ],
  actions: [
    // Optional standalone actions
  ]
}
```

## Best Practices

1. **Always validate before saving**: The `saveFlow` action validates automatically, but you can call `validateFlow` manually for real-time feedback.

2. **Use auto-layout for new nodes**: The `FlowHelpers.calculatePosition()` function provides automatic grid layout.

3. **Preserve viewport state**: The viewport is automatically saved to state and can be restored on reload.

4. **Handle validation errors gracefully**: Display validation errors to users and prevent saving invalid flows.

5. **Use getters for computed data**: Leverage Vuex getters for node/edge lookups and filtered data.

6. **Batch updates when possible**: When adding multiple nodes, consider adding them all before triggering validation.

7. **Clean up on unmount**: Call `clearFlow` when navigating away from the flow editor to reset state.
