<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();

const nodeTypes = ref([
  {
    type: 'state',
    label: 'State',
    icon: 'i-lucide-circle-dot',
    description: 'Conversation state node',
    color: 'text-blue-600',
  },
  {
    type: 'intent',
    label: 'Intent',
    icon: 'i-lucide-message-square',
    description: 'User intent detection',
    color: 'text-green-600',
  },
  {
    type: 'action',
    label: 'Action',
    icon: 'i-lucide-zap',
    description: 'Execute action',
    color: 'text-orange-600',
  },
  {
    type: 'template',
    label: 'Template',
    icon: 'i-lucide-file-text',
    description: 'Message template',
    color: 'text-purple-600',
  },
  {
    type: 'condition',
    label: 'Condition',
    icon: 'i-lucide-git-branch',
    description: 'Conditional branch',
    color: 'text-amber-600',
  },
]);

// Handle drag start
const handleDragStart = (event, nodeType) => {
  event.dataTransfer.effectAllowed = 'move';
  event.dataTransfer.setData('application/vueflow', nodeType.type);
  event.dataTransfer.setData('nodeData', JSON.stringify(nodeType));
};
</script>

<template>
  <div class="flex flex-col h-full">
    <div class="p-4 border-b border-n-strong">
      <h2 class="text-lg font-semibold text-n-slate-12">
        {{ t('AGENT_BOTS.STUDIO.NODE_PALETTE') }}
      </h2>
      <p class="text-xs text-n-slate-11 mt-1">
        {{ t('AGENT_BOTS.STUDIO.DRAG_TO_CANVAS') }}
      </p>
    </div>

    <div class="flex-1 p-4 space-y-2">
      <div
        v-for="nodeType in nodeTypes"
        :key="nodeType.type"
        class="group cursor-move"
        draggable="true"
        @dragstart="handleDragStart($event, nodeType)"
      >
        <div
          class="flex items-center gap-3 p-3 rounded-lg border border-n-weak bg-n-slate-1 hover:bg-n-slate-2 hover:border-n-strong transition-all duration-200"
        >
          <div
            class="flex items-center justify-center w-10 h-10 rounded-lg bg-n-white border border-n-weak group-hover:border-n-strong transition-colors"
          >
            <i class="w-5 h-5" :class="[nodeType.icon, nodeType.color]" />
          </div>
          <div class="flex-1 min-w-0">
            <div class="font-medium text-n-slate-12 text-sm">
              {{ nodeType.label }}
            </div>
            <div class="text-xs text-n-slate-11 truncate">
              {{ nodeType.description }}
            </div>
          </div>
          <i
            class="i-lucide-grip-vertical w-4 h-4 text-n-slate-11 opacity-0 group-hover:opacity-100 transition-opacity"
          />
        </div>
      </div>
    </div>

    <div class="p-4 border-t border-n-strong bg-n-slate-1">
      <div class="text-xs text-n-slate-11">
        <p class="flex items-center gap-2 mb-1">
          <i class="i-lucide-info w-3 h-3" />
          {{ t('AGENT_BOTS.STUDIO.PALETTE_TIP') }}
        </p>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Ensure drag cursor shows properly */
[draggable='true'] {
  -webkit-user-drag: element;
  -webkit-user-select: none;
  user-select: none;
}
</style>
