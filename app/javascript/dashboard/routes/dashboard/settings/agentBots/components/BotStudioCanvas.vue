<!-- eslint-disable no-underscore-dangle, no-use-before-define, no-continue, no-restricted-globals, vue/prefer-true-attribute-shorthand -->
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
  project,
} = useVueFlow();

const nodes = ref([]);
const edges = ref([]);
const isInteractive = ref(true);
const searchQuery = ref('');
const highlightedNodeIds = ref([]);
const currentSearchIndex = ref(0); // Track which search result we're viewing

// ========================================
// Node Validation (Warnings & Errors)
// ========================================

// Detect nodes with warnings (orange) or errors (red)
const getNodeValidationStatus = nodeId => {
  const node = nodes.value.find(n => n.id === nodeId);
  if (!node) return null;

  const outgoingEdges = edges.value.filter(e => e.source === nodeId);
  const hasOutgoingEdge = outgoingEdges.length > 0;

  // Check for warnings (orange)
  const warnings = [];

  // Intent nodes without outgoing edges
  if (node.type === 'intent' && !hasOutgoingEdge) {
    warnings.push('Intent has no outgoing connection');
  }

  // State nodes with missing handler
  if (node.type === 'state') {
    const handler = node.data?.handler;
    if (handler && handler.trim() !== '') {
      // Handler specified but might not exist
      // We'll show this as a warning since we can't check existence here
      // The FlowExecutorService will handle it gracefully via delegation
    }
  }

  // Intent nodes with no keywords
  if (node.type === 'intent') {
    const keywords = node.data?.keywords || [];
    if (keywords.length === 0) {
      warnings.push('No keywords defined');
    }
  }

  // Check for errors (red)
  const errors = [];

  // State nodes without state_id
  if (node.type === 'state' && !node.data?.state_id) {
    errors.push('Missing state_id');
  }

  // Template nodes without template_name
  if (node.type === 'template' && !node.data?.template_name) {
    errors.push('Missing template_name');
  }

  // Return validation status
  if (errors.length > 0) {
    return { level: 'error', messages: errors };
  }
  if (warnings.length > 0) {
    return { level: 'warning', messages: warnings };
  }
  return null;
};

// Apply validation status to nodes directly
const updateNodeValidation = () => {
  nodes.value.forEach(node => {
    const validation = getNodeValidationStatus(node.id);

    // Update node class for styling
    if (validation?.level === 'error') {
      node.class = 'node-error';
    } else if (validation?.level === 'warning') {
      node.class = 'node-warning';
    } else {
      node.class = '';
    }

    // Pass validation to node component
    if (!node.data) node.data = {};
    node.data._validation = validation;
  });
};

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
  currentSearchIndex.value = 0; // Reset to first result

  // Focus on first matched node
  if (matchedNodes.length > 0) {
    focusOnSearchResult(0);
  }

  // eslint-disable-next-line no-console
  console.log(
    '[BotStudioCanvas] Search results:',
    matchedNodes.length,
    'nodes matched'
  );
};

// Focus on a specific search result by index
const focusOnSearchResult = index => {
  const matchedNodeId = highlightedNodeIds.value[index];
  if (!matchedNodeId) return;

  const node = nodes.value.find(n => n.id === matchedNodeId);
  if (!node) return;

  const padding = 100;
  fitBounds(
    {
      x: node.position.x - padding,
      y: node.position.y - padding,
      width: 400,
      height: 300,
    },
    { duration: 300 }
  );

  // eslint-disable-next-line no-console
  console.log(
    `[BotStudioCanvas] Focused on search result ${index + 1}/${highlightedNodeIds.value.length}`
  );
};

// Navigate to next search result
const nextSearchResult = () => {
  if (highlightedNodeIds.value.length === 0) return;

  currentSearchIndex.value =
    (currentSearchIndex.value + 1) % highlightedNodeIds.value.length;
  focusOnSearchResult(currentSearchIndex.value);
};

// Navigate to previous search result
const prevSearchResult = () => {
  if (highlightedNodeIds.value.length === 0) return;

  currentSearchIndex.value =
    (currentSearchIndex.value - 1 + highlightedNodeIds.value.length) %
    highlightedNodeIds.value.length;
  focusOnSearchResult(currentSearchIndex.value);
};

// Clear search
const clearSearch = () => {
  searchQuery.value = '';
  highlightedNodeIds.value = [];
  currentSearchIndex.value = 0;
};

// Auto-layout nodes using flow-based grid algorithm
const autoLayout = () => {
  if (nodes.value.length === 0) return;

  const horizontalSpacing = 350;
  const verticalSpacing = 180;
  const maxNodesPerRow = 4; // Limit vertical stacking

  // Find the root node (initial state or first state node)
  const rootNode =
    nodes.value.find(n => n.type === 'state' && n.data?.is_initial) ||
    nodes.value.find(n => n.type === 'state');

  if (!rootNode) {
    // No state nodes, fall back to simple grid layout
    layoutGrid();
    return;
  }

  // Build adjacency map from edges
  const adjacency = new Map();
  edges.value.forEach(edge => {
    if (!adjacency.has(edge.source)) {
      adjacency.set(edge.source, []);
    }
    adjacency.get(edge.source).push(edge.target);
  });

  // BFS to assign grid positions
  const visited = new Set();
  const positions = new Map();
  const queue = [{ nodeId: rootNode.id, col: 0, row: 0 }];

  let maxCol = 0;
  let maxRow = 0;

  while (queue.length > 0) {
    const { nodeId, col, row } = queue.shift();
    if (visited.has(nodeId)) continue;

    visited.add(nodeId);
    positions.set(nodeId, { col, row });
    maxCol = Math.max(maxCol, col);
    maxRow = Math.max(maxRow, row);

    // Get children
    const children = adjacency.get(nodeId) || [];

    if (children.length === 0) continue;

    // Distribute children horizontally and vertically to avoid tall stacks
    children.forEach((childId, index) => {
      if (visited.has(childId)) return;

      // Spread children: alternate between moving right and down
      const nextCol = col + 1 + Math.floor(index / maxNodesPerRow);
      const nextRow = row + (index % maxNodesPerRow);

      queue.push({ nodeId: childId, col: nextCol, row: nextRow });
    });
  }

  // Position nodes based on grid positions
  positions.forEach((pos, nodeId) => {
    const node = nodes.value.find(n => n.id === nodeId);
    if (node) {
      // eslint-disable-next-line no-param-reassign
      node.position = {
        x: 50 + pos.col * horizontalSpacing,
        y: 50 + pos.row * verticalSpacing,
      };
    }
  });

  // Handle orphaned nodes
  const orphanNodes = nodes.value.filter(n => !visited.has(n.id));
  if (orphanNodes.length > 0) {
    const orphanY = 50 + (maxRow + 2) * verticalSpacing;
    orphanNodes.forEach((node, index) => {
      // eslint-disable-next-line no-param-reassign
      node.position = {
        x: 50 + index * horizontalSpacing,
        y: orphanY,
      };
    });
  }

  // Fit view
  setTimeout(() => {
    fitView({ padding: 0.2, duration: 300 });
  }, 100);

  // eslint-disable-next-line no-console
  console.log(
    '[BotStudioCanvas] Flow-grid auto-layout:',
    `${maxCol + 1} cols × ${maxRow + 1} rows,`,
    orphanNodes.length,
    'orphans'
  );

  // Helper function for simple grid layout (fallback)
  function layoutGrid() {
    const cols = Math.ceil(Math.sqrt(nodes.value.length));

    nodes.value.forEach((node, index) => {
      const row = Math.floor(index / cols);
      const col = index % cols;

      // eslint-disable-next-line no-param-reassign
      node.position = {
        x: 50 + col * horizontalSpacing,
        y: 50 + row * verticalSpacing,
      };
    });

    setTimeout(() => {
      fitView({ padding: 0.2, duration: 300 });
    }, 100);

    // eslint-disable-next-line no-console
    console.log('[BotStudioCanvas] Grid auto-layout (fallback)');
  }
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

// Grid snapping helper
const GRID_SIZE = 20;
const snapToGrid = (x, y) => ({
  x: Math.round(x / GRID_SIZE) * GRID_SIZE,
  y: Math.round(y / GRID_SIZE) * GRID_SIZE,
});

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
        scope: 'global', // global: always checked, contextual: state-specific
        handler: '', // Handler method to call when keywords match
        label: 'New Intent',
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
        handler: '', // Handler method to execute
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

  // Use VueFlow's project() to convert screen coordinates to flow coordinates
  // This properly accounts for zoom and pan transformations
  const projectedPosition = project({
    x: event.clientX,
    y: event.clientY,
  });

  // Offset to center the node at cursor position
  const centeredPosition = {
    x: projectedPosition.x - 100,
    y: projectedPosition.y - 50,
  };

  // Snap position to grid for clean alignment
  const position = snapToGrid(centeredPosition.x, centeredPosition.y);

  // Create new node with default data
  const newNode = {
    id: `node_${nextNodeId}`,
    type: nodeType,
    position,
    data: getDefaultNodeData(nodeType),
  };

  nextNodeId += 1;

  // eslint-disable-next-line no-console
  console.log(
    'Creating node:',
    newNode,
    'snapped from',
    centeredPosition,
    'to',
    position
  );
  nodes.value.push(newNode);

  // Update validation for new node
  nextTick(() => {
    updateNodeValidation();
  });

  // Save to history
  saveToHistory('add_node');
};

// Connection handler
onConnect(params => {
  // eslint-disable-next-line no-console
  console.log('[BotStudioCanvas] Connection added:', params);

  addEdges([params]);

  // Update validation after edge added
  nextTick(() => {
    updateNodeValidation();
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

      // Initialize nextNodeId to prevent duplicate IDs
      // Find the highest node_N id in existing nodes
      const nodeNumbers = nodes.value
        .filter(n => n.id && n.id.startsWith('node_'))
        .map(n => {
          const match = n.id.match(/node_(\d+)/);
          return match ? parseInt(match[1], 10) : 0;
        })
        .filter(n => !isNaN(n));

      if (nodeNumbers.length > 0) {
        nextNodeId = Math.max(...nodeNumbers) + 1;
        // eslint-disable-next-line no-console
        console.log('[BotStudioCanvas] Initialized nextNodeId to:', nextNodeId);
      }

      // Remove duplicate nodes (same ID)
      const seenIds = new Set();
      const uniqueNodes = [];
      nodes.value.forEach(node => {
        if (!seenIds.has(node.id)) {
          seenIds.add(node.id);
          uniqueNodes.push(node);
        } else {
          // eslint-disable-next-line no-console
          console.warn(
            '[BotStudioCanvas] 🗑️  Removed duplicate node:',
            node.id
          );
        }
      });

      if (uniqueNodes.length < nodes.value.length) {
        nodes.value = uniqueNodes;
        // eslint-disable-next-line no-console
        console.log(
          `[BotStudioCanvas] ✅ Cleaned ${nodes.value.length - uniqueNodes.length} duplicate nodes`
        );
      }

      // Update validation for loaded nodes
      nextTick(() => {
        updateNodeValidation();
      });

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

  // Update validation and fit view after loading
  nextTick(() => {
    updateNodeValidation();

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

// Handle nodes changes (position, dimensions, etc.)
const onNodesChange = changes => {
  // Don't process changes if we're applying history
  if (isApplyingHistory.value) return;

  // VueFlow already updates nodes via v-model, so we don't need to manually apply changes
  // We only use this handler for history tracking

  // Save to history only when drag ends (not during dragging)
  const hasPositionChange = changes.some(
    c => c.type === 'position' && c.dragging === false
  );
  if (hasPositionChange) {
    saveToHistory('node_moved');
  }
};

// Handle node selection
const onNodeClick = event => {
  emit('nodeSelected', event.node);
};

// Handle node double-click (for editing)
const onNodeDoubleClick = event => {
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
  currentSearchIndex,
  canUndo,
  canRedo,
  canCopy,
  canPaste,
  isMac,

  // Methods
  searchNodes,
  clearSearch,
  nextSearchResult,
  prevSearchResult,
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
      snap-to-grid
      :snap-grid="[20, 20]"
      fit-view-on-init
      class="vue-flow-container"
      @node-click="onNodeClick"
      @node-double-click="onNodeDoubleClick"
      @dragover="onDragOver"
      @drop="onDrop"
      @nodes-change="onNodesChange"
    >
      <Background pattern-color="#aaa" :gap="20" />
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
