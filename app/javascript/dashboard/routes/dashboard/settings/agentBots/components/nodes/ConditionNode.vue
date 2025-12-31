<!-- eslint-disable vue/no-bare-strings-in-template -->
<!-- eslint-disable @intlify/vue-i18n/no-raw-text -->
<!-- eslint-disable vue/no-static-inline-styles -->
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

const conditionExpr = computed(() => props.data.expression || 'if true');
const conditionLabel = computed(() => props.data.label || 'Condition');
</script>

<template>
  <div class="condition-node" @dblclick="emit('configure', id)">
    <Handle type="target" :position="Position.Left" />

    <div class="node-header condition-header">
      <i class="i-lucide-git-branch" />
      <span class="node-type">Condition</span>
    </div>

    <div class="node-content">
      <div class="condition-label">{{ conditionLabel }}</div>
      <div class="condition-expr">{{ conditionExpr }}</div>
    </div>

    <Handle
      id="true"
      type="source"
      :position="Position.Right"
      :style="{ top: '30%' }"
    />
    <Handle
      id="false"
      type="source"
      :position="Position.Right"
      :style="{ top: '70%' }"
    />
  </div>
</template>

<style scoped>
.condition-node {
  @apply bg-white dark:bg-slate-800 rounded-lg shadow-md cursor-pointer;
  border: 2px solid rgb(var(--yellow-600));
  min-width: 180px;
}

.dark .condition-node {
  border-color: rgb(var(--yellow-700));
}

.condition-node:hover {
  border-color: rgb(var(--yellow-700));
  @apply shadow-lg;
}

.dark .condition-node:hover {
  border-color: rgb(var(--yellow-600));
}

.node-header {
  @apply flex items-center gap-2 px-3 py-2 border-b;
  border-bottom-color: rgb(var(--slate-6));
}

.dark .node-header {
  border-bottom-color: rgb(var(--slate-700));
}

.condition-header {
  background: rgb(var(--yellow-100));
  color: rgb(var(--yellow-700));
}

.dark .condition-header {
  background: rgb(var(--yellow-950));
  color: rgb(var(--yellow-300));
}

.node-type {
  @apply text-xs font-semibold uppercase;
}

.node-content {
  @apply p-3;
}

.condition-label {
  @apply text-sm font-medium mb-1;
  color: rgb(var(--slate-12));
}

.dark .condition-label {
  @apply text-slate-200;
}

.condition-expr {
  @apply text-xs font-mono;
  color: rgb(var(--slate-10));
}

.dark .condition-expr {
  @apply text-slate-400;
}
</style>
