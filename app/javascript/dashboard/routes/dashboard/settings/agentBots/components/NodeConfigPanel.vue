<script setup>
import { computed, ref, watch, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import StateConfig from './config/StateConfig.vue';
import IntentConfig from './config/IntentConfig.vue';
import TemplateConfig from './config/TemplateConfig.vue';
import ActionConfig from './config/ActionConfig.vue';
import ConditionConfig from './config/ConditionConfig.vue';

const props = defineProps({
  selectedNode: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['update', 'close']);

const { t } = useI18n();

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
const panelWidth = ref(400);
const isResizing = ref(false);
const panelRef = ref(null);

watch(
  () => props.selectedNode,
  newNode => {
    if (newNode) {
      nodeData.value = { ...newNode.data };
    }
  },
  { immediate: true }
);

const saveConfig = () => {
  emit('update', {
    id: props.selectedNode.id,
    data: nodeData.value,
  });
};

// Resize functionality
const startResize = () => {
  isResizing.value = true;
  document.body.style.cursor = 'ew-resize';
  document.body.style.userSelect = 'none';
};

const handleResize = e => {
  if (!isResizing.value) return;

  const containerWidth = window.innerWidth;
  const newWidth = containerWidth - e.clientX;

  // Min width 300px, max width 800px
  panelWidth.value = Math.min(Math.max(newWidth, 300), 800);
};

const stopResize = () => {
  isResizing.value = false;
  document.body.style.cursor = '';
  document.body.style.userSelect = '';
};

onMounted(() => {
  document.addEventListener('mousemove', handleResize);
  document.addEventListener('mouseup', stopResize);
});

onUnmounted(() => {
  document.removeEventListener('mousemove', handleResize);
  document.removeEventListener('mouseup', stopResize);
});
</script>

<template>
  <div
    v-if="selectedNode"
    ref="panelRef"
    class="node-config-panel"
    :style="{ width: `${panelWidth}px` }"
  >
    <!-- Resize Handle -->
    <div class="resize-handle" @mousedown="startResize">
      <div class="resize-indicator" />
    </div>

    <div class="panel-header">
      <div class="flex items-center gap-2">
        <i class="i-lucide-settings text-n-slate-11" />
        <h3 class="text-base font-semibold text-n-slate-12 capitalize">
          {{ t('AGENT_BOTS.STUDIO.CONFIGURE') }} {{ selectedNode.type }}
        </h3>
      </div>
      <div class="flex items-center gap-2">
        <span class="text-xs text-n-slate-10">{{ selectedNode.id }}</span>
        <Button
          icon="i-lucide-x"
          size="xs"
          variant="faded"
          @click="emit('close')"
        />
      </div>
    </div>

    <div class="panel-content">
      <component :is="configComponent" v-model="nodeData" @save="saveConfig" />
    </div>

    <div class="panel-footer">
      <Button variant="faded" @click="emit('close')">
        {{ t('GENERAL_SETTINGS.CANCEL') }}
      </Button>
      <Button @click="saveConfig">{{ t('GENERAL_SETTINGS.SAVE') }}</Button>
    </div>
  </div>
  <div v-else />
</template>

<style scoped>
.node-config-panel {
  position: absolute;
  right: 0;
  top: 0;
  height: 100%;
  background: white;
  border-left: 1px solid var(--n-weak);
  display: flex;
  flex-direction: column;
  z-index: 10;
  box-shadow: -4px 0 12px rgba(0, 0, 0, 0.08);
}

.resize-handle {
  position: absolute;
  left: 0;
  top: 0;
  width: 8px;
  height: 100%;
  cursor: ew-resize;
  z-index: 20;
  display: flex;
  align-items: center;
  justify-content: center;
}

.resize-handle:hover {
  background: var(--n-blue-3);
}

.resize-indicator {
  width: 2px;
  height: 40px;
  background: var(--n-slate-7);
  border-radius: 1px;
  opacity: 0;
  transition: opacity 0.2s;
}

.resize-handle:hover .resize-indicator {
  opacity: 1;
}

.panel-header {
  padding: 16px;
  border-bottom: 1px solid var(--n-weak);
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: var(--n-slate-1);
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
  background: var(--n-slate-1);
}
</style>
