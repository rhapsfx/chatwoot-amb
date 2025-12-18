<!-- eslint-disable vue/no-bare-strings-in-template -->
<!-- eslint-disable @intlify/vue-i18n/no-raw-text -->
<script setup>
import { Handle, Position } from '@vue-flow/core';
import { computed } from 'vue';

const props = defineProps({
  id: {
    type: String,
    default: '',
  },
  data: {
    type: Object,
    default: () => ({}),
  },
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
  @apply bg-white dark:bg-slate-800 rounded-lg shadow-md cursor-pointer;
  border: 2px solid rgb(var(--woot-300));
  min-width: 200px;
}

.dark .state-node {
  border-color: rgb(var(--woot-600));
}

.state-node:hover {
  border-color: rgb(var(--woot-400));
  @apply shadow-lg;
}

.dark .state-node:hover {
  border-color: rgb(var(--woot-500));
}

.node-header {
  @apply flex items-center gap-2 px-3 py-2 border-b;
  border-bottom-color: rgb(var(--slate-6));
}

.dark .node-header {
  border-bottom-color: rgb(var(--slate-700));
}

.state-header {
  background: rgb(var(--woot-25));
  color: rgb(var(--woot-500));
}

.dark .state-header {
  background: rgb(var(--woot-900));
  color: rgb(var(--woot-200));
}

.node-type {
  @apply text-xs font-semibold uppercase;
}

.node-content {
  @apply p-3;
}

.state-id {
  @apply font-mono text-sm font-semibold mb-1;
  color: rgb(var(--slate-12));
}

.dark .state-id {
  @apply text-slate-200;
}

.state-label {
  @apply text-sm mb-2;
  color: rgb(var(--slate-11));
}

.dark .state-label {
  @apply text-slate-300;
}

.action-count {
  @apply text-xs italic;
  color: rgb(var(--slate-10));
}

.dark .action-count {
  @apply text-slate-400;
}
</style>
