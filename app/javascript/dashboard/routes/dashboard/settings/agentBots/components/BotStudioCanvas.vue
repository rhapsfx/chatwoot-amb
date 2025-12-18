<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import { MiniMap } from '@vue-flow/minimap';

// Import VueFlow styles
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';
import '@vue-flow/controls/dist/style.css';
import '@vue-flow/minimap/dist/style.css';

// Custom node components
import {
  StateNode,
  IntentNode,
  ActionNode,
  TemplateNode,
  ConditionNode,
} from './nodes';

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

const emit = defineEmits(['compile', 'nodeSelected']);

const store = useStore();

// Vue Flow instance
const {
  onConnect,
  addEdges,
  fitView,
  setInteractive,
  fitBounds,
  getSelectedNodes,
  getSelectedEdges,
  removeNodes,
} = useVueFlow();

const nodes = ref([]);
const edges = ref([]);
const isInteractive = ref(true);
const searchQuery = ref('');
const highlightedNodeIds = ref([]);

// Platform detection for keyboard shortcuts display
const isMac = computed(
  () => navigator.platform.toUpperCase().indexOf('MAC') >= 0
);

// ========================================
// History Management (Undo/Redo)
// ========================================
const history = ref([]);
const currentHistoryIndex = ref(-1);
const MAX_HISTORY = 50;
const isApplyingHistory = ref(false); // Prevent history recording during undo/redo

const canUndo = computed(() => currentHistoryIndex.value > 0);
const canRedo = computed(
  () => currentHistoryIndex.value < history.value.length - 1
);

// Save current state to history
const saveToHistory = (action = 'change') => {
  // Don't save to history if we're applying history (undo/redo)
  if (isApplyingHistory.value) return;

  const state = {
    nodes: JSON.parse(JSON.stringify(nodes.value)),
    edges: JSON.parse(JSON.stringify(edges.value)),
    action: action,
    timestamp: Date.now(),
  };

  // Remove any future history if we're not at the end
  if (currentHistoryIndex.value < history.value.length - 1) {
    history.value = history.value.slice(0, currentHistoryIndex.value + 1);
  }

  history.value.push(state);

  // Limit history size
  if (history.value.length > MAX_HISTORY) {
    history.value.shift();
  } else {
    currentHistoryIndex.value += 1;
  }

  // eslint-disable-next-line no-console
  console.log(
    '[BotStudioCanvas] Saved to history:',
    action,
    '(',
    history.value.length,
    'states,',
    'index:',
    currentHistoryIndex.value,
    ')'
  );
};

// Undo last action
const undo = () => {
  if (!canUndo.value) return;

  isApplyingHistory.value = true;
  currentHistoryIndex.value -= 1;
  const state = history.value[currentHistoryIndex.value];

  nodes.value = JSON.parse(JSON.stringify(state.nodes));
  edges.value = JSON.parse(JSON.stringify(state.edges));

  nextTick(() => {
    isApplyingHistory.value = false;
  });

  // eslint-disable-next-line no-console
  console.log(
    '[BotStudioCanvas] Undo:',
    state.action,
    '(index:',
    currentHistoryIndex.value,
    ')'
  );
};

// Redo previously undone action
const redo = () => {
  if (!canRedo.value) return;

  isApplyingHistory.value = true;
  currentHistoryIndex.value += 1;
  const state = history.value[currentHistoryIndex.value];

  nodes.value = JSON.parse(JSON.stringify(state.nodes));
  edges.value = JSON.parse(JSON.stringify(state.edges));

  nextTick(() => {
    isApplyingHistory.value = false;
  });

  // eslint-disable-next-line no-console
  console.log(
    '[BotStudioCanvas] Redo:',
    state.action,
    '(index:',
    currentHistoryIndex.value,
    ')'
  );
};

// ========================================
// Copy/Paste/Duplicate
// ========================================
const clipboard = ref(null);

const canCopy = computed(() => {
  const selectedNodes = getSelectedNodes.value || [];
  return selectedNodes.length > 0;
});

const canPaste = computed(() => clipboard.value !== null);

// Copy selected nodes and their edges
const copyNodes = () => {
  const selectedNodes = getSelectedNodes.value || [];

  if (selectedNodes.length === 0) {
    // eslint-disable-next-line no-console
    console.log('[BotStudioCanvas] No nodes selected to copy');
    return;
  }

  const selectedNodeIds = selectedNodes.map(n => n.id);

  // Copy nodes
  const copiedNodes = nodes.value.filter(n => selectedNodeIds.includes(n.id));

  // Copy edges between selected nodes
  const copiedEdges = edges.value.filter(
    e =>
      selectedNodeIds.includes(e.source) && selectedNodeIds.includes(e.target)
  );

  clipboard.value = {
    nodes: JSON.parse(JSON.stringify(copiedNodes)),
    edges: JSON.parse(JSON.stringify(copiedEdges)),
    timestamp: Date.now(),
  };

  // eslint-disable-next-line no-console
  console.log(
    '[BotStudioCanvas] Copied',
    copiedNodes.length,
    'nodes and',
    copiedEdges.length,
    'edges'
  );
};

// Paste nodes from clipboard
const pasteNodes = () => {
  if (!clipboard.value) {
    // eslint-disable-next-line no-console
    console.log('[BotStudioCanvas] Nothing to paste');
    return;
  }

  const PASTE_OFFSET = 50;
  const idMap = {};

  // Generate new IDs and offset positions
  const pastedNodes = clipboard.value.nodes.map(node => {
    const newId = `node_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    idMap[node.id] = newId;

    return {
      ...node,
      id: newId,
      position: {
        x: node.position.x + PASTE_OFFSET,
        y: node.position.y + PASTE_OFFSET,
      },
      selected: true, // Select pasted nodes
    };
  });

  // Update edge references with new IDs
  const pastedEdges = clipboard.value.edges.map(edge => ({
    ...edge,
    id: `edge_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
    source: idMap[edge.source],
    target: idMap[edge.target],
  }));

  // Deselect all existing nodes
  nodes.value.forEach(node => {
    // eslint-disable-next-line no-param-reassign
    node.selected = false;
  });

  // Add pasted nodes and edges
  nodes.value.push(...pastedNodes);
  edges.value.push(...pastedEdges);

  // Save to history
  saveToHistory('paste');

  // eslint-disable-next-line no-console
  console.log(
    '[BotStudioCanvas] Pasted',
    pastedNodes.length,
    'nodes and',
    pastedEdges.length,
    'edges'
  );
};

// Duplicate selected nodes (copy + paste in one action)
const duplicateNodes = () => {
  copyNodes();
  if (clipboard.value) {
    pasteNodes();
  }
};

// Delete selected nodes
const deleteSelected = () => {
  const selectedNodes = getSelectedNodes.value || [];
  const selectedEdges = getSelectedEdges.value || [];

  if (selectedNodes.length === 0 && selectedEdges.length === 0) {
    // eslint-disable-next-line no-console
    console.log('[BotStudioCanvas] Nothing selected to delete');
    return;
  }

  // Remove selected nodes (this will also remove connected edges)
  const nodeIds = selectedNodes.map(n => n.id);
  removeNodes(nodeIds);

  // Remove selected edges
  const edgeIds = selectedEdges.map(e => e.id);
  edges.value = edges.value.filter(e => !edgeIds.includes(e.id));

  // Save to history
  saveToHistory('delete');

  // eslint-disable-next-line no-console
  console.log(
    '[BotStudioCanvas] Deleted',
    nodeIds.length,
    'nodes and',
    edgeIds.length,
    'edges'
  );
};

// ========================================
// Keyboard Shortcuts
// ========================================
const handleKeyDown = event => {
  // Check if we're in an input field (don't intercept text editing)
  const target = event.target;
  if (
    target.tagName === 'INPUT' ||
    target.tagName === 'TEXTAREA' ||
    target.isContentEditable
  ) {
    // Allow Ctrl+A (select all) in inputs
    return;
  }

  const modifier = isMac.value ? event.metaKey : event.ctrlKey;

  // Undo: Ctrl+Z / Cmd+Z
  if (modifier && event.key === 'z' && !event.shiftKey) {
    event.preventDefault();
    undo();
  }
  // Redo: Ctrl+Y / Cmd+Y or Ctrl+Shift+Z / Cmd+Shift+Z
  else if (
    modifier &&
    (event.key === 'y' || (event.key === 'z' && event.shiftKey))
  ) {
    event.preventDefault();
    redo();
  }
  // Copy: Ctrl+C / Cmd+C
  else if (modifier && event.key === 'c') {
    event.preventDefault();
    copyNodes();
  }
  // Paste: Ctrl+V / Cmd+V
  else if (modifier && event.key === 'v') {
    event.preventDefault();
    pasteNodes();
  }
  // Duplicate: Ctrl+D / Cmd+D
  else if (modifier && event.key === 'd') {
    event.preventDefault();
    duplicateNodes();
  }
  // Delete: Delete or Backspace
  else if (event.key === 'Delete' || event.key === 'Backspace') {
    event.preventDefault();
    deleteSelected();
  }
};

// ========================================
// Existing functionality
// ========================================

// Toggle interactive mode (lock/unlock)
const toggleInteractive = () => {
  isInteractive.value = !isInteractive.value;
  setInteractive(isInteractive.value);
  // eslint-disable-next-line no-console
  console.log(
    '[BotStudioCanvas] Interactive mode:',
    isInteractive.value ? 'unlocked' : 'locked'
  );
};

// Search and highlight nodes
const searchNodes = () => {
  const query = searchQuery.value.toLowerCase().trim();

  if (!query) {
    highlightedNodeIds.value = [];
    return;
  }

  const matchedNodes = nodes.value.filter(node => {
    const label = node.data?.label?.toLowerCase() || '';
    const stateId = node.data?.state_id?.toLowerCase() || '';
    const templateName = node.data?.template_name?.toLowerCase() || '';
    const actionType = node.data?.action_type?.toLowerCase() || '';
    const keywords = (node.data?.keywords || [])
      .map(k => k.toLowerCase())
      .join(' ');

    return (
      label.includes(query) ||
      stateId.includes(query) ||
      templateName.includes(query) ||
      actionType.includes(query) ||
      keywords.includes(query) ||
      node.id.toLowerCase().includes(query)
    );
  });

  highlightedNodeIds.value = matchedNodes.map(n => n.id);

  // Focus on first matched node
  if (matchedNodes.length > 0) {
    const firstNode = matchedNodes[0];
    const padding = 100;

    fitBounds(
      {
        x: firstNode.position.x - padding,
        y: firstNode.position.y - padding,
        width: 400,
        height: 300,
      },
      { duration: 300 }
    );
  }

  // eslint-disable-next-line no-console
  console.log(
    '[BotStudioCanvas] Search results:',
    matchedNodes.length,
    'nodes matched'
  );
};

// Clear search
const clearSearch = () => {
  searchQuery.value = '';
  highlightedNodeIds.value = [];
};

// Auto-layout nodes using dagre algorithm
const autoLayout = () => {
  if (nodes.value.length === 0) return;

  // Simple hierarchical layout algorithm
  const nodeHeight = 100;
  const horizontalSpacing = 250;
  const verticalSpacing = 150;

  // Group nodes by type for better organization
  const stateNodes = nodes.value.filter(n => n.type === 'state');
  const intentNodes = nodes.value.filter(n => n.type === 'intent');
  const templateNodes = nodes.value.filter(n => n.type === 'template');
  const actionNodes = nodes.value.filter(n => n.type === 'action');
  const conditionNodes = nodes.value.filter(n => n.type === 'condition');

  let currentY = 50;

  // Layout state nodes in first row
  stateNodes.forEach((node, index) => {
    // eslint-disable-next-line no-param-reassign
    node.position = {
      x: 50 + index * horizontalSpacing,
      y: currentY,
    };
  });

  if (stateNodes.length > 0) currentY += nodeHeight + verticalSpacing;

  // Layout intent nodes in second row
  intentNodes.forEach((node, index) => {
    // eslint-disable-next-line no-param-reassign
    node.position = {
      x: 50 + index * horizontalSpacing,
      y: currentY,
    };
  });

  if (intentNodes.length > 0) currentY += nodeHeight + verticalSpacing;

  // Layout template nodes in third row
  templateNodes.forEach((node, index) => {
    // eslint-disable-next-line no-param-reassign
    node.position = {
      x: 50 + index * horizontalSpacing,
      y: currentY,
    };
  });

  if (templateNodes.length > 0) currentY += nodeHeight + verticalSpacing;

  // Layout action nodes in fourth row
  actionNodes.forEach((node, index) => {
    // eslint-disable-next-line no-param-reassign
    node.position = {
      x: 50 + index * horizontalSpacing,
      y: currentY,
    };
  });

  if (actionNodes.length > 0) currentY += nodeHeight + verticalSpacing;

  // Layout condition nodes in fifth row
  conditionNodes.forEach((node, index) => {
    // eslint-disable-next-line no-param-reassign
    node.position = {
      x: 50 + index * horizontalSpacing,
      y: currentY,
    };
  });

  // Fit view to show all nodes
  setTimeout(() => {
    fitView({ padding: 0.2, duration: 300 });
  }, 100);

  // eslint-disable-next-line no-console
  console.log(
    '[BotStudioCanvas] Auto-layout applied to',
    nodes.value.length,
    'nodes'
  );
};

// Node types registration
const nodeTypes = {
  state: StateNode,
  intent: IntentNode,
  action: ActionNode,
  template: TemplateNode,
  condition: ConditionNode,
};

// Drag and drop support
let nextNodeId = 1;

const getDefaultNodeData = type => {
  const currentId = nextNodeId;
  switch (type) {
    case 'state':
      return {
        state_id: `STATE_${currentId}`,
        label: 'New State',
        description: '',
        actions: [],
      };
    case 'intent':
      return {
        keywords: [],
        exact_match: false,
        case_sensitive: false,
      };
    case 'template':
      return {
        template_name: '',
        template_type: 'list_picker',
      };
    case 'action':
      return {
        action_type: 'send_message',
        label: 'New Action',
        parameters: {},
      };
    case 'condition':
      return {
        condition_expression: '',
        label: 'New Condition',
        true_label: 'True',
        false_label: 'False',
      };
    default:
      return {};
  }
};

const onDragOver = event => {
  event.preventDefault();
  event.dataTransfer.dropEffect = 'move';
};

const onDrop = event => {
  event.preventDefault();

  // Get node type from dataTransfer
  const nodeType = event.dataTransfer.getData('application/vueflow');

  if (!nodeType) {
    // eslint-disable-next-line no-console
    console.warn('No node type found in drag data');
    return;
  }

  // Get the VueFlow viewport for proper coordinate conversion
  const vueFlowElement = event.currentTarget;
  const { left, top } = vueFlowElement.getBoundingClientRect();

  // Calculate position relative to canvas
  const position = {
    x: event.clientX - left - 100, // Offset to center the node
    y: event.clientY - top - 50,
  };

  // Create new node with default data
  const newNode = {
    id: `node_${nextNodeId}`,
    type: nodeType,
    position,
    data: getDefaultNodeData(nodeType),
  };

  nextNodeId += 1;

  // eslint-disable-next-line no-console
  console.log('Creating node:', newNode);
  nodes.value.push(newNode);

  // Save to history
  saveToHistory('add_node');
};

// Connection handler
onConnect(params => {
  // eslint-disable-next-line no-console
  console.log('[BotStudioCanvas] Connection added:', params);

  addEdges([params]);

  // Save to history after adding edge
  nextTick(() => {
    saveToHistory('add_edge');
  });
});

// Load flow data from store
const loadFlow = async () => {
  // eslint-disable-next-line no-console
  console.log('BotStudioCanvas.loadFlow called with flowId:', props.flowId);

  if (!props.flowId) {
    // eslint-disable-next-line no-console
    console.warn('No flowId provided, skipping load');
    return;
  }

  try {
    const response = await store.dispatch('agentBots/getFlow', {
      botId: props.botId,
      flowId: props.flowId,
    });

    // eslint-disable-next-line no-console
    console.log('getFlow response:', response);

    if (response?.flow?.flow_data) {
      const flowData = response.flow.flow_data;
      // eslint-disable-next-line no-console
      console.log('Flow data found:', {
        nodes: flowData.nodes?.length || 0,
        edges: flowData.edges?.length || 0,
      });

      nodes.value = flowData.nodes || [];
      edges.value = flowData.edges || [];

      // Add a test node at origin to verify VueFlow is working
      if (nodes.value.length > 0) {
        const testNode = {
          id: 'test-node-origin',
          type: 'state',
          position: { x: 0, y: 0 },
          data: { label: 'TEST NODE AT ORIGIN', state_id: 'TEST' },
        };
        nodes.value.unshift(testNode);
        // eslint-disable-next-line no-console
        console.log('Added test node at (0,0)');
      }

      // eslint-disable-next-line no-console
      console.log(
        'Loaded nodes:',
        nodes.value.length,
        'edges:',
        edges.value.length
      );
      // eslint-disable-next-line no-console
      console.log(
        'First 3 nodes:',
        nodes.value.slice(0, 3).map(n => ({
          id: n.id,
          type: n.type,
          position: n.position,
          hasData: !!n.data,
        }))
      );

      // Use nextTick to wait for Vue to update the DOM, then fit view
      setTimeout(() => {
        // eslint-disable-next-line no-console
        console.log('Calling fitView to zoom to nodes');
        fitView({ padding: 0.2, duration: 300 });
      }, 100);
    } else {
      // eslint-disable-next-line no-console
      console.error('No flow_data in response:', response);
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Failed to load flow:', error);
  }
};

// Compile flow to bot_config (exposed for parent component)
// eslint-disable-next-line no-unused-vars
const compileFlow = () => {
  emit('compile');
};

// Load flow data directly (for import functionality)
const loadFlowData = flowData => {
  if (!flowData || !flowData.nodes || !flowData.edges) {
    // eslint-disable-next-line no-console
    console.error('Invalid flow data provided to loadFlowData');
    return;
  }

  // eslint-disable-next-line no-console
  console.log('Loading flow data:', {
    nodes: flowData.nodes.length,
    edges: flowData.edges.length,
  });

  nodes.value = flowData.nodes;
  edges.value = flowData.edges;

  // Fit view after loading
  nextTick(() => {
    if (nodes.value.length > 0) {
      setTimeout(() => {
        fitView({ padding: 0.2, duration: 300 });
      }, 100);
    }
  });

  // Save to history
  saveToHistory('flow_imported');
};

// Focus on a specific node (for validation errors, search, etc.)
const focusNode = nodeId => {
  const node = nodes.value.find(n => n.id === nodeId);
  if (!node) {
    // eslint-disable-next-line no-console
    console.warn(`[BotStudioCanvas] Node not found: ${nodeId}`);
    return;
  }

  // Highlight the node
  highlightedNodeIds.value = [nodeId];

  // Calculate bounds for the specific node with padding
  const padding = 200; // Pixels of padding around the node
  const nodeBounds = {
    x: node.position.x - padding,
    y: node.position.y - padding,
    width: (node.width || 200) + padding * 2,
    height: (node.height || 100) + padding * 2,
  };

  // Fit view to the node
  nextTick(() => {
    fitBounds(nodeBounds, { duration: 500 });
  });

  // eslint-disable-next-line no-console
  console.log('[BotStudioCanvas] Focused on node:', nodeId);
};

// Handle node selection
const onNodeClick = event => {
  emit('nodeSelected', event.node);
};

// Initialize
onMounted(() => {
  // Add keyboard listener
  window.addEventListener('keydown', handleKeyDown);
  // eslint-disable-next-line no-console
  console.log('[BotStudioCanvas] Keyboard shortcuts enabled');

  // Load flow and save initial state after loading
  loadFlow().then(() => {
    nextTick(() => {
      saveToHistory('initial_load');
    });
  });
});

// Cleanup
onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyDown);
  // eslint-disable-next-line no-console
  console.log('[BotStudioCanvas] Keyboard shortcuts disabled');
});

// Watch for flowId changes and reload
watch(
  () => props.flowId,
  newFlowId => {
    // eslint-disable-next-line no-console
    console.log('flowId changed to:', newFlowId);
    if (newFlowId) {
      loadFlow().then(() => {
        nextTick(() => {
          saveToHistory('flow_loaded');
        });
      });
    }
  }
);

// Expose methods and state for parent component
defineExpose({
  // State
  searchQuery,
  highlightedNodeIds,
  canUndo,
  canRedo,
  canCopy,
  canPaste,
  isMac,

  // Methods
  searchNodes,
  clearSearch,
  undo,
  redo,
  copyNodes,
  pasteNodes,
  duplicateNodes,
  deleteSelected,
  autoLayout,
  loadFlowData,
  focusNode,

  // Data access
  getFlowData: () => ({
    nodes: nodes.value,
    edges: edges.value,
  }),
});
</script>

<template>
  <div class="bot-studio-canvas">
    <VueFlow
      v-model:nodes="nodes"
      v-model:edges="edges"
      :node-types="nodeTypes"
      :nodes-draggable="isInteractive"
      :edges-updatable="isInteractive"
      :elements-selectable="isInteractive"
      :zoom-on-scroll="isInteractive"
      :pan-on-scroll="isInteractive"
      fit-view-on-init
      class="vue-flow-container"
      @node-click="onNodeClick"
      @dragover="onDragOver"
      @drop="onDrop"
    >
      <Background pattern-color="#aaa" :gap="16" />
      <Controls
        show-zoom
        show-fit-view
        show-interactive
        @interaction-change="toggleInteractive"
      />
      <MiniMap />

      <!-- Highlighted node overlay -->
      <template #node-state="nodeProps">
        <StateNode
          v-bind="nodeProps"
          :class="{
            'highlighted-node': highlightedNodeIds.includes(nodeProps.id),
          }"
        />
      </template>
      <template #node-intent="nodeProps">
        <IntentNode
          v-bind="nodeProps"
          :class="{
            'highlighted-node': highlightedNodeIds.includes(nodeProps.id),
          }"
        />
      </template>
      <template #node-template="nodeProps">
        <TemplateNode
          v-bind="nodeProps"
          :class="{
            'highlighted-node': highlightedNodeIds.includes(nodeProps.id),
          }"
        />
      </template>
      <template #node-action="nodeProps">
        <ActionNode
          v-bind="nodeProps"
          :class="{
            'highlighted-node': highlightedNodeIds.includes(nodeProps.id),
          }"
        />
      </template>
      <template #node-condition="nodeProps">
        <ConditionNode
          v-bind="nodeProps"
          :class="{
            'highlighted-node': highlightedNodeIds.includes(nodeProps.id),
          }"
        />
      </template>
    </VueFlow>
  </div>
</template>

<style scoped>
.bot-studio-canvas {
  width: 100%;
  height: 100%;
  position: relative;
}

.vue-flow-container {
  width: 100%;
  height: 100%;
  background: var(--n-slate-1);
}

/* Highlighted Node Effect */
:deep(.highlighted-node) {
  animation: highlight-pulse 1s ease-in-out infinite;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.4) !important;
  border-color: var(--n-blue-8) !important;
}

@keyframes highlight-pulse {
  0%,
  100% {
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.4);
  }
  50% {
    box-shadow: 0 0 0 6px rgba(59, 130, 246, 0.2);
  }
}
</style>
