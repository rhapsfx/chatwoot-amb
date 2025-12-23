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

const actionType = computed(() => props.data.action_type || 'Action');
const actionLabel = computed(() => props.data.label || 'New Action');
const handler = computed(() => props.data.handler || null);
</script>

<template>
  <div class="action-node" @dblclick="emit('configure', id)">
    <Handle type="target" :position="Position.Left" />

    <div class="node-header action-header">
      <i class="i-lucide-zap" />
      <span class="node-type">Action</span>
    </div>

    <div class="node-content">
      <div class="action-type">{{ actionType }}</div>
      <div class="action-label">{{ actionLabel }}</div>
      <div v-if="handler" class="handler-method">
        <i class="i-lucide-code" />
        <span>{{ handler }}</span>
      </div>
    </div>

    <Handle type="source" :position="Position.Right" />
  </div>
</template>

<style scoped>
.action-node {
  @apply bg-white dark:bg-slate-800 rounded-lg shadow-md cursor-pointer;
  border: 2px solid rgb(var(--yellow-300));
  min-width: 180px;
}

.dark .action-node {
  border-color: rgb(var(--yellow-600));
}

.action-node:hover {
  border-color: rgb(var(--yellow-400));
  @apply shadow-lg;
}

.dark .action-node:hover {
  border-color: rgb(var(--yellow-500));
}

.node-header {
  @apply flex items-center gap-2 px-3 py-2 border-b;
  border-bottom-color: rgb(var(--slate-6));
}

.dark .node-header {
  border-bottom-color: rgb(var(--slate-700));
}

.action-header {
  background: rgb(var(--yellow-50));
  color: rgb(var(--yellow-500));
}

.dark .action-header {
  background: rgb(var(--yellow-900));
  color: rgb(var(--yellow-200));
}

.node-type {
  @apply text-xs font-semibold uppercase;
}

.node-content {
  @apply p-3;
}

.action-type {
  @apply text-xs uppercase mb-1;
  color: rgb(var(--slate-10));
}

.dark .action-type {
  @apply text-slate-400;
}

.action-label {
  @apply text-sm font-medium;
  color: rgb(var(--slate-12));
}

.dark .action-label {
  @apply text-slate-200;
}

.handler-method {
  @apply flex items-center gap-1 text-xs mt-2 px-2 py-1 rounded-md font-mono;
  background: rgb(var(--slate-100));
  color: rgb(var(--slate-700));
  width: fit-content;
}

.dark .handler-method {
  background: rgb(var(--slate-800));
  color: rgb(var(--slate-300));
}

.handler-method i {
  @apply text-xs;
}
</style>
