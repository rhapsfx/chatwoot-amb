<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import NodePalette from './components/NodePalette.vue';
import BotStudioCanvas from './components/BotStudioCanvas.vue';
import ValidationPanel from './components/ValidationPanel.vue';
import ImportFlowDialog from './components/ImportFlowDialog.vue';
import TemplateBrowserDialog from './components/TemplateBrowserDialog.vue';
import HandlerMethodsBrowser from './components/HandlerMethodsBrowser.vue';
import BotTestConsole from './components/BotTestConsole.vue';

// Node Editors
import StateNodeEditor from './components/editors/StateNodeEditor.vue';
import IntentNodeEditor from './components/editors/IntentNodeEditor.vue';
import TemplateNodeEditor from './components/editors/TemplateNodeEditor.vue';
import ActionNodeEditor from './components/editors/ActionNodeEditor.vue';
import ConditionNodeEditor from './components/editors/ConditionNodeEditor.vue';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();

const botId = computed(() => Number(route.params.botId));
const bot = ref(null);
const flowId = ref(null);
const selectedNode = ref(null);
const isCompiling = ref(false);
const isSaving = ref(false);
const isImporting = ref(false);
const isValidating = ref(false);

// Canvas controls ref
const canvasRef = ref(null);

// Import flow dialog ref
const importFlowDialogRef = ref(null);

// Template browser dialog ref
const templateBrowserRef = ref(null);

// Handler browser dialog ref
const handlerBrowserRef = ref(null);

// File input ref for JSON import
const fileInputRef = ref(null);

// Track if there are unsaved changes
const hasUnsavedChanges = ref(false);

// Validation state
const validationResult = ref(null);
const showValidationPanel = ref(true);
const nodeValidationErrors = ref(new Map());

// Test console state
const showTestConsole = ref(false);

// Computed property for current editor component
const currentEditor = computed(() => {
  if (!selectedNode.value) return null;

  const nodeType = selectedNode.value.type;
  const editorMap = {
    state: StateNodeEditor,
    intent: IntentNodeEditor,
    template: TemplateNodeEditor,
    action: ActionNodeEditor,
    condition: ConditionNodeEditor,
  };

  return editorMap[nodeType] || null;
});

// Load bot data
const loadBot = async () => {
  try {
    await store.dispatch('agentBots/show', botId.value);
    bot.value = store.getters['agentBots/getBot'](botId.value);
  } catch (error) {
    useAlert(t('AGENT_BOTS.STUDIO.ERROR_LOADING_BOT'));
    router.push({ name: 'agent_bots' });
  }
};

// Load or create default flow
const loadOrCreateFlow = async () => {
  try {
    // Check if there's an imported flow
    const flows = await store.dispatch('agentBots/getFlows', botId.value);
    // eslint-disable-next-line no-console
    console.log('Flows response:', flows);

    let importedFlow = flows?.flows?.find(
      f => f.name === 'Imported from bot_config'
    );
    // eslint-disable-next-line no-console
    console.log('Found imported flow:', importedFlow);

    // If no imported flow exists, try to import from bot_config
    if (!importedFlow && (!flows?.flows || flows.flows.length === 0)) {
      // eslint-disable-next-line no-console
      console.log('No flows found. Attempting to import from bot_config...');

      const importResult = await store.dispatch(
        'agentBots/importFlowFromBotConfig',
        botId.value
      );

      if (importResult?.flow) {
        importedFlow = importResult.flow;
        // eslint-disable-next-line no-console
        console.log('Successfully imported flow:', importedFlow);
        useAlert(t('AGENT_BOTS.STUDIO.FLOW_IMPORTED'));
      }
    }

    // Use imported flow if found, otherwise use first available flow
    if (importedFlow) {
      flowId.value = importedFlow.id;
      // eslint-disable-next-line no-console
      console.log('Set flowId to:', flowId.value);
    } else if (flows?.flows && flows.flows.length > 0) {
      // Use the first flow if no imported flow exists
      flowId.value = flows.flows[0].id;
      // eslint-disable-next-line no-console
      console.log(
        'Using first available flow:',
        flows.flows[0].name,
        'ID:',
        flowId.value
      );
    } else {
      // eslint-disable-next-line no-console
      console.warn('No flows available for this bot');
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Failed to load flow:', error);
  }
};

// Handle node selection from canvas
const handleNodeSelected = node => {
  selectedNode.value = node;
};

// Handle node data save from editor
const handleSaveNode = async nodeData => {
  if (!selectedNode.value || !flowId.value) return;

  // Update local node data immediately (no API call)
  // The entire flow will be saved when user clicks "Save" button
  selectedNode.value.data = { ...selectedNode.value.data, ...nodeData };

  // Mark flow as having unsaved changes
  hasUnsavedChanges.value = true;

  // Update the node in the canvas
  if (canvasRef.value) {
    const flowData = canvasRef.value.getFlowData();
    const node = flowData.nodes.find(n => n.id === selectedNode.value.id);
    if (node) {
      node.data = { ...node.data, ...nodeData };
    }
  }

  // eslint-disable-next-line no-console
  console.log(
    '[BotStudio] Node updated locally:',
    selectedNode.value.id,
    nodeData
  );
};

// Handle cancel edit
const handleCancelEdit = () => {
  // selectedNode.value = null; // Keep node selected, just don't save
};

// Handle save flow
const handleSaveFlow = async () => {
  // Get current flow data from canvas
  if (!canvasRef.value) {
    useAlert(t('AGENT_BOTS.STUDIO.ERROR_SAVING_FLOW'));
    return;
  }

  const flowData = canvasRef.value.getFlowData();

  // Debug: Log all state nodes to help find duplicates
  const stateNodes = flowData.nodes.filter(n => n.type === 'state');
  const stateIds = stateNodes.map(n => ({
    id: n.id,
    state_id: n.data?.state_id,
  }));
  // eslint-disable-next-line no-console
  console.log('[BotStudio] All state nodes:', stateIds);

  // Debug: Log the specific node we just edited
  const editedNode = flowData.nodes.find(n => n.id === 'node_1');
  // eslint-disable-next-line no-console
  console.log('[BotStudio] DEBUG - node_1 data being saved:', editedNode?.data);

  // eslint-disable-next-line no-console
  console.log('[BotStudio] Saving flow with data:', {
    flowId: flowId.value,
    botId: botId.value,
    nodeCount: flowData.nodes?.length || 0,
    edgeCount: flowData.edges?.length || 0,
  });

  isSaving.value = true;
  try {
    if (flowId.value) {
      const result = await store.dispatch('agentBots/updateFlow', {
        botId: botId.value,
        flowId: flowId.value,
        flow_data: flowData,
      });
      // eslint-disable-next-line no-console
      console.log('[BotStudio] Update result:', result);
    } else {
      const result = await store.dispatch('agentBots/createFlow', {
        botId: botId.value,
        name: 'Imported from bot_config',
        flow_data: flowData,
      });
      flowId.value = result?.flow?.id;
      // eslint-disable-next-line no-console
      console.log('[BotStudio] Create result:', result);
    }
    useAlert(t('AGENT_BOTS.STUDIO.FLOW_SAVED'));
    hasUnsavedChanges.value = false;
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('[BotStudio] Save error:', error);
    useAlert(t('AGENT_BOTS.STUDIO.ERROR_SAVING_FLOW'));
  } finally {
    isSaving.value = false;
  }
};

// Handle compile flow
const handleCompileFlow = async () => {
  if (!flowId.value) {
    useAlert(t('AGENT_BOTS.STUDIO.ERROR_COMPILING_FLOW'));
    return;
  }

  isCompiling.value = true;
  try {
    const result = await store.dispatch('agentBots/compileFlow', {
      botId: botId.value,
      flowId: flowId.value,
    });

    if (result) {
      useAlert(t('AGENT_BOTS.STUDIO.FLOW_COMPILED'));
    }
  } catch (error) {
    useAlert(t('AGENT_BOTS.STUDIO.ERROR_COMPILING_FLOW'));
  } finally {
    isCompiling.value = false;
  }
};

// Handle import from JSON file
const handleImportFromJSON = () => {
  fileInputRef.value?.click();
};

// Handle import from saved flow
const handleImportFromFlow = () => {
  importFlowDialogRef.value?.open();
};

// Handle browse templates
const handleBrowseTemplates = () => {
  templateBrowserRef.value?.open();
};

// Handle browse handlers
const handleBrowseHandlers = () => {
  handlerBrowserRef.value?.open();
};

// Handle insert template
const handleInsertTemplate = flowData => {
  if (!canvasRef.value) {
    useAlert(t('AGENT_BOTS.STUDIO.IMPORT_FLOW.ERROR'));
    return;
  }

  // Load the template flow data into the canvas
  canvasRef.value.loadFlowData(flowData);
  hasUnsavedChanges.value = true;
  useAlert(t('AGENT_BOTS.TEMPLATES.INSERT_SUCCESS'));
};

// Handle import flow data
const handleImportFlowData = flowData => {
  if (!canvasRef.value) {
    useAlert(t('AGENT_BOTS.STUDIO.IMPORT_FLOW.ERROR'));
    return;
  }

  // Load the flow data into the canvas
  canvasRef.value.loadFlowData(flowData);
  hasUnsavedChanges.value = true;
};

// Handle export to JSON file
const handleExportToJSON = () => {
  if (!canvasRef.value) {
    useAlert('Canvas not ready');
    return;
  }

  const flowData = canvasRef.value.getFlowData();
  const jsonString = JSON.stringify(flowData, null, 2);
  const blob = new Blob([jsonString], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `${bot.value?.name || 'bot'}_flow_${Date.now()}.json`;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);

  useAlert('Flow exported successfully');
};

// Handle file selection
const handleFileSelect = async event => {
  const file = event.target.files?.[0];
  if (!file) return;

  // Validate file type
  if (!file.name.endsWith('.json')) {
    useAlert('Please select a JSON file');
    return;
  }

  isImporting.value = true;
  try {
    const fileContent = await file.text();
    const flowData = JSON.parse(fileContent);

    // Validate flow data structure
    if (!flowData.nodes || !Array.isArray(flowData.nodes)) {
      useAlert('Invalid flow data: missing nodes array');
      return;
    }
    if (!flowData.edges || !Array.isArray(flowData.edges)) {
      useAlert('Invalid flow data: missing edges array');
      return;
    }

    // Create or update flow with imported data
    if (flowId.value) {
      const result = await store.dispatch('agentBots/updateFlow', {
        botId: botId.value,
        flowId: flowId.value,
        flow_data: flowData,
      });
      // eslint-disable-next-line no-console
      console.log('[BotStudio] Import update result:', result);
    } else {
      const result = await store.dispatch('agentBots/createFlow', {
        botId: botId.value,
        name: 'Imported from JSON',
        flow_data: flowData,
      });
      flowId.value = result?.flow?.id;
      // eslint-disable-next-line no-console
      console.log('[BotStudio] Import create result:', result);
    }

    useAlert(t('AGENT_BOTS.STUDIO.FLOW_IMPORTED'));
    // Reload canvas to show imported nodes
    window.location.reload();
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('[BotStudio] Import error:', error);
    if (error instanceof SyntaxError) {
      useAlert('Invalid JSON file');
    } else {
      useAlert(t('AGENT_BOTS.STUDIO.ERROR_IMPORTING_FLOW'));
    }
  } finally {
    isImporting.value = false;
    // Reset file input
    if (fileInputRef.value) {
      fileInputRef.value.value = '';
    }
  }
};

// Validate flow
const validateFlow = async () => {
  if (!flowId.value) {
    // eslint-disable-next-line no-console
    console.warn('[BotStudio] No flow to validate');
    return;
  }

  isValidating.value = true;
  try {
    const result = await store.dispatch('agentBots/validateFlow', {
      botId: botId.value,
      flowId: flowId.value,
    });

    validationResult.value = result;

    // Build map of node errors/warnings for visual feedback
    const errorMap = new Map();
    if (result?.errors) {
      result.errors.forEach(error => {
        if (error.node_id) {
          if (!errorMap.has(error.node_id)) {
            errorMap.set(error.node_id, { errors: [], warnings: [] });
          }
          errorMap.get(error.node_id).errors.push(error);
        }
      });
    }
    if (result?.warnings) {
      result.warnings.forEach(warning => {
        if (warning.node_id) {
          if (!errorMap.has(warning.node_id)) {
            errorMap.set(warning.node_id, { errors: [], warnings: [] });
          }
          errorMap.get(warning.node_id).warnings.push(warning);
        }
      });
    }
    nodeValidationErrors.value = errorMap;

    // Show feedback
    if (result?.valid) {
      useAlert(t('AGENT_BOTS.VALIDATION.VALIDATION_PASSED'));
    } else {
      useAlert(t('AGENT_BOTS.VALIDATION.VALIDATION_FAILED'));
    }

    // eslint-disable-next-line no-console
    console.log('[BotStudio] Validation result:', result);

    // Debug: Log specific errors
    if (result?.errors && result.errors.length > 0) {
      // eslint-disable-next-line no-console
      console.log('[BotStudio] ❌ Validation errors:', result.errors);
    }
    if (result?.warnings && result.warnings.length > 0) {
      // eslint-disable-next-line no-console
      console.log(
        '[BotStudio] ⚠️  Validation warnings (count):',
        result.warnings.length
      );
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('[BotStudio] Validation error:', error);
    useAlert('Failed to validate flow');
  } finally {
    isValidating.value = false;
  }
};

// Handle validation error/warning click - highlight the node
const handleValidationIssueClick = issue => {
  if (!canvasRef.value) return;

  let nodeId = issue.node_id;

  // If no node_id but we have a state_id (duplicate state_id error), search for it
  if (!nodeId && issue.state_id) {
    const flowData = canvasRef.value.getFlowData();
    const matchingNode = flowData.nodes.find(
      n => n.type === 'state' && n.data?.state_id === issue.state_id
    );
    if (matchingNode) {
      nodeId = matchingNode.id;
      // eslint-disable-next-line no-console
      console.log(
        `[BotStudio] Found node for state_id '${issue.state_id}': ${nodeId}`
      );
    }
  }

  if (!nodeId) {
    // eslint-disable-next-line no-console
    console.warn(
      '[BotStudio] Could not find node for validation issue:',
      issue
    );
    return;
  }

  // Focus and highlight the node on canvas
  canvasRef.value.focusNode(nodeId);

  // Find and select the node
  const flowData = canvasRef.value.getFlowData();
  const node = flowData.nodes.find(n => n.id === nodeId);
  if (node) {
    selectedNode.value = node;
  }

  // eslint-disable-next-line no-console
  console.log('[BotStudio] Focused on node:', nodeId);
};

// Handle node execution from test console
const handleNodeExecuted = nodeIds => {
  if (!canvasRef.value) return;

  // Highlight executed nodes on canvas
  canvasRef.value.highlightedNodeIds = nodeIds;

  // eslint-disable-next-line no-console
  console.log('[BotStudio] Executed nodes:', nodeIds);
};

// Toggle test console
const toggleTestConsole = () => {
  showTestConsole.value = !showTestConsole.value;
};

// Compute whether save/compile should be disabled
const hasCriticalErrors = computed(() => {
  return validationResult.value && !validationResult.value.valid;
});

// Navigate back to bot list
const goBack = () => {
  router.push({ name: 'agent_bots' });
};

// Watch for flow changes and auto-validate
watch(flowId, newFlowId => {
  if (newFlowId) {
    // Validate after a short delay when flow is loaded
    setTimeout(() => {
      validateFlow();
    }, 500);
  }
});

// Initialize
onMounted(async () => {
  await loadBot();
  await loadOrCreateFlow();
});
</script>

<template>
  <div class="flex flex-col h-screen w-full bg-n-slate-1">
    <!-- Header -->
    <div class="bg-n-white border-b border-n-strong">
      <!-- Top row: Title and Actions -->
      <div class="flex items-center justify-between px-6 py-4">
        <div class="flex items-center gap-4">
          <Button icon="i-lucide-arrow-left" slate faded @click="goBack" />
          <div>
            <h1 class="text-xl font-semibold text-n-slate-12">
              {{ bot?.name || 'Bot Studio' }}
            </h1>
            <p class="text-sm text-n-slate-11">
              {{ t('AGENT_BOTS.STUDIO.SUBTITLE') }}
            </p>
          </div>
        </div>
        <div class="flex gap-2">
          <Button
            icon="i-lucide-layout-template"
            :label="t('AGENT_BOTS.STUDIO.BROWSE_TEMPLATES')"
            slate
            faded
            @click="handleBrowseTemplates"
          />
          <Button
            icon="i-lucide-code-2"
            :label="t('AGENT_BOTS.STUDIO.BROWSE_HANDLERS')"
            slate
            faded
            @click="handleBrowseHandlers"
          />
          <Button
            icon="i-lucide-folder-open"
            :label="t('AGENT_BOTS.STUDIO.IMPORT_FROM_FLOW')"
            slate
            faded
            @click="handleImportFromFlow"
          />
          <Button
            icon="i-lucide-upload"
            :label="t('AGENT_BOTS.STUDIO.IMPORT_FROM_JSON')"
            slate
            faded
            :is-loading="isImporting"
            @click="handleImportFromJSON"
          />
          <Button
            icon="i-lucide-download"
            :label="t('AGENT_BOTS.STUDIO.EXPORT_TO_JSON')"
            slate
            faded
            @click="handleExportToJSON"
          />
          <Button
            icon="i-lucide-check-circle"
            :label="t('AGENT_BOTS.STUDIO.VALIDATE')"
            slate
            faded
            :is-loading="isValidating"
            @click="validateFlow"
          />
          <Button
            icon="i-lucide-play-circle"
            :label="t('AGENT_BOTS.STUDIO.TEST')"
            slate
            faded
            :class="{ 'bg-n-blue-3': showTestConsole }"
            @click="toggleTestConsole"
          />
          <Button
            icon="i-lucide-save"
            :label="t('AGENT_BOTS.STUDIO.SAVE')"
            slate
            :is-loading="isSaving"
            @click="handleSaveFlow"
          />
          <Button
            icon="i-lucide-play"
            :label="t('AGENT_BOTS.STUDIO.COMPILE_TEST')"
            :is-loading="isCompiling"
            :disabled="hasCriticalErrors"
            @click="handleCompileFlow"
          />
        </div>
      </div>

      <!-- Hidden file input for JSON import -->
      <input
        ref="fileInputRef"
        type="file"
        accept=".json"
        class="hidden"
        @change="handleFileSelect"
      />

      <!-- Toolbar row: Canvas Controls -->
      <div
        class="flex items-center gap-3 px-6 py-2 border-t border-n-soft bg-n-slate-1"
      >
        <!-- Search Input -->
        <div class="flex items-center gap-1">
          <input
            v-if="canvasRef"
            v-model="canvasRef.searchQuery"
            type="text"
            :placeholder="t('AGENT_BOTS.STUDIO.SEARCH_PLACEHOLDER')"
            class="px-3 py-1.5 text-sm border border-n-soft rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-8 focus:border-transparent w-64"
            @input="canvasRef.searchNodes"
            @keyup.enter="canvasRef.searchNodes"
            @keyup.esc="canvasRef.clearSearch"
          />
          <button
            v-if="canvasRef?.searchQuery"
            class="p-1.5 hover:bg-n-slate-3 rounded transition-colors"
            :title="t('AGENT_BOTS.STUDIO.CLEAR_SEARCH')"
            @click="canvasRef.clearSearch"
          >
            <i class="i-lucide-x w-4 h-4 text-n-slate-11" />
          </button>
          <button
            v-if="canvasRef"
            class="p-1.5 hover:bg-n-slate-3 rounded transition-colors"
            :title="t('AGENT_BOTS.STUDIO.SEARCH_NODES')"
            @click="canvasRef.searchNodes"
          >
            <i class="i-lucide-search w-4 h-4 text-n-slate-11" />
          </button>
          <div
            v-if="canvasRef?.highlightedNodeIds?.length > 0"
            class="flex items-center gap-2 ml-2"
          >
            <span class="text-sm font-medium text-n-slate-12">
              {{ canvasRef.currentSearchIndex + 1 }} /
              {{ canvasRef.highlightedNodeIds.length }}
            </span>
            <button
              class="p-1.5 hover:bg-n-slate-3 rounded transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
              :disabled="canvasRef.highlightedNodeIds.length <= 1"
              :title="$t('AGENT_BOTS.BOT_STUDIO.SEARCH.PREVIOUS_RESULT')"
              @click="canvasRef.prevSearchResult"
            >
              <i class="i-lucide-chevron-up w-4 h-4 text-n-slate-11" />
            </button>
            <button
              class="p-1.5 hover:bg-n-slate-3 rounded transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
              :disabled="canvasRef.highlightedNodeIds.length <= 1"
              :title="$t('AGENT_BOTS.BOT_STUDIO.SEARCH.NEXT_RESULT')"
              @click="canvasRef.nextSearchResult"
            >
              <i class="i-lucide-chevron-down w-4 h-4 text-n-slate-11" />
            </button>
          </div>
        </div>

        <div class="h-5 w-px bg-n-soft" />

        <!-- History Controls -->
        <div class="flex items-center gap-1">
          <button
            v-if="canvasRef"
            class="p-1.5 hover:bg-n-slate-3 rounded transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
            :disabled="!canvasRef.canUndo"
            :title="`Undo (${canvasRef.isMac ? 'Cmd' : 'Ctrl'}+Z)`"
            @click="canvasRef.undo"
          >
            <i class="i-lucide-undo w-4 h-4 text-n-slate-11" />
          </button>
          <button
            v-if="canvasRef"
            class="p-1.5 hover:bg-n-slate-3 rounded transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
            :disabled="!canvasRef.canRedo"
            :title="`Redo (${canvasRef.isMac ? 'Cmd' : 'Ctrl'}+Y)`"
            @click="canvasRef.redo"
          >
            <i class="i-lucide-redo w-4 h-4 text-n-slate-11" />
          </button>
        </div>

        <div class="h-5 w-px bg-n-soft" />

        <!-- Edit Controls -->
        <div class="flex items-center gap-1">
          <button
            v-if="canvasRef"
            class="p-1.5 hover:bg-n-slate-3 rounded transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
            :disabled="!canvasRef.canCopy"
            :title="`Copy (${canvasRef.isMac ? 'Cmd' : 'Ctrl'}+C)`"
            @click="canvasRef.copyNodes"
          >
            <i class="i-lucide-copy w-4 h-4 text-n-slate-11" />
          </button>
          <button
            v-if="canvasRef"
            class="p-1.5 hover:bg-n-slate-3 rounded transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
            :disabled="!canvasRef.canPaste"
            :title="`Paste (${canvasRef.isMac ? 'Cmd' : 'Ctrl'}+V)`"
            @click="canvasRef.pasteNodes"
          >
            <i class="i-lucide-clipboard w-4 h-4 text-n-slate-11" />
          </button>
          <button
            v-if="canvasRef"
            class="p-1.5 hover:bg-n-slate-3 rounded transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
            :disabled="!canvasRef.canCopy"
            :title="`Duplicate (${canvasRef.isMac ? 'Cmd' : 'Ctrl'}+D)`"
            @click="canvasRef.duplicateNodes"
          >
            <i class="i-lucide-copy-plus w-4 h-4 text-n-slate-11" />
          </button>
          <button
            v-if="canvasRef"
            class="p-1.5 hover:bg-n-red-3 rounded transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
            :disabled="!canvasRef.canCopy"
            :title="t('AGENT_BOTS.STUDIO.DELETE')"
            @click="canvasRef.deleteSelected"
          >
            <i class="i-lucide-trash-2 w-4 h-4 text-n-red-11" />
          </button>
        </div>

        <div class="h-5 w-px bg-n-soft" />

        <!-- Auto-layout -->
        <button
          v-if="canvasRef"
          class="flex items-center gap-1.5 px-3 py-1.5 text-sm hover:bg-n-slate-3 rounded transition-colors"
          :title="t('AGENT_BOTS.STUDIO.AUTO_LAYOUT_TITLE')"
          @click="canvasRef.autoLayout"
        >
          <i class="i-lucide-layout-grid w-4 h-4 text-n-slate-11" />
          <span class="text-n-slate-12">{{
            t('AGENT_BOTS.STUDIO.AUTO_LAYOUT')
          }}</span>
        </button>
      </div>
    </div>

    <!-- Body: Three-column layout -->
    <div class="flex flex-1 overflow-hidden">
      <!-- Left: Node Palette -->
      <div
        class="min-w-48 w-48 flex-shrink-0 bg-n-white border-r border-n-strong overflow-y-auto"
      >
        <NodePalette />
      </div>

      <!-- Center: Canvas -->
      <div class="flex-1 relative">
        <BotStudioCanvas
          ref="canvasRef"
          :bot-id="botId"
          :flow-id="flowId"
          @compile="handleCompileFlow"
          @node-selected="handleNodeSelected"
        />
      </div>

      <!-- Right: Config Panel and Test Console -->
      <div class="flex">
        <!-- Config Panel -->
        <div
          class="min-w-80 w-80 flex-shrink-0 bg-n-white border-l border-n-strong flex flex-col overflow-hidden"
        >
          <!-- Top: Node Editor (takes remaining space) -->
          <div class="flex-1 overflow-y-auto p-4">
            <!-- Dynamic Node Editor -->
            <component
              :is="currentEditor"
              v-if="selectedNode && currentEditor"
              :node="selectedNode"
              :bot-id="botId"
              @save="handleSaveNode"
              @cancel="handleCancelEdit"
            />

            <!-- Empty State -->
            <div v-else class="text-center text-n-slate-11 mt-8">
              <i class="i-lucide-mouse-pointer-click w-12 h-12 mx-auto mb-4" />
              <p>{{ t('AGENT_BOTS.STUDIO.SELECT_NODE') }}</p>
            </div>
          </div>

          <!-- Bottom: Validation Panel (collapsible) -->
          <div
            v-if="showValidationPanel"
            class="border-t border-n-strong h-80 flex-shrink-0"
          >
            <ValidationPanel
              :validation-result="validationResult"
              :is-validating="isValidating"
              @error-click="handleValidationIssueClick"
              @warning-click="handleValidationIssueClick"
            />
          </div>

          <!-- Toggle validation panel button -->
          <button
            class="flex items-center justify-center gap-2 py-2 border-t border-n-soft hover:bg-n-slate-2 transition-colors"
            @click="showValidationPanel = !showValidationPanel"
          >
            <i
              class="w-4 h-4 text-n-slate-11"
              :class="[
                showValidationPanel
                  ? 'i-lucide-chevron-down'
                  : 'i-lucide-chevron-up',
              ]"
            />
            <span class="text-xs text-n-slate-11">
              {{
                showValidationPanel
                  ? t('AGENT_BOTS.VALIDATION.HIDE')
                  : t('AGENT_BOTS.VALIDATION.SHOW')
              }}
            </span>
          </button>
        </div>

        <!-- Test Console (collapsible) -->
        <div
          v-if="showTestConsole"
          class="min-w-96 w-96 flex-shrink-0 bg-n-white border-l border-n-strong"
        >
          <BotTestConsole
            :bot-id="botId"
            :flow-id="flowId"
            :flow-name="bot?.name || 'Bot Flow'"
            @node-executed="handleNodeExecuted"
          />
        </div>
      </div>
    </div>

    <!-- Import Flow Dialog -->
    <ImportFlowDialog
      ref="importFlowDialogRef"
      :bot-id="botId"
      :has-unsaved-changes="hasUnsavedChanges"
      @import="handleImportFlowData"
    />

    <!-- Template Browser Dialog -->
    <TemplateBrowserDialog
      ref="templateBrowserRef"
      @insert-template="handleInsertTemplate"
    />

    <!-- Handler Methods Browser -->
    <HandlerMethodsBrowser
      ref="handlerBrowserRef"
      :bot-id="botId"
      service-name="AcousticHouseBotService"
    />
  </div>
</template>
