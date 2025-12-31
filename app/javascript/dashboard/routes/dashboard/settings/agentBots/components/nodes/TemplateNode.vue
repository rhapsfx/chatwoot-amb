<!-- eslint-disable vue/no-bare-strings-in-template -->
<!-- eslint-disable @intlify/vue-i18n/no-raw-text -->
<script setup>
import { Handle, Position } from '@vue-flow/core';
import { computed } from 'vue';

const props = defineProps({
  data: {
    type: Object,
    default: () => ({}),
  },
});

const templateName = computed(
  () => props.data.template_name || 'Select template'
);
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
  @apply bg-white dark:bg-slate-800 rounded-lg shadow-md cursor-pointer;
  border: 2px solid rgb(var(--violet-8));
  min-width: 200px;
}

.dark .template-node {
  border-color: rgb(var(--violet-600));
}

.template-node:hover {
  border-color: rgb(var(--violet-9));
  @apply shadow-lg;
}

.dark .template-node:hover {
  border-color: rgb(var(--violet-500));
}

.node-header {
  @apply flex items-center gap-2 px-3 py-2 border-b;
  border-bottom-color: rgb(var(--slate-6));
}

.dark .node-header {
  border-bottom-color: rgb(var(--slate-700));
}

.template-header {
  background: rgb(var(--violet-2));
  color: rgb(var(--violet-11));
}

.dark .template-header {
  background: rgb(var(--violet-900));
  color: rgb(var(--violet-200));
}

.node-type {
  @apply text-xs font-semibold uppercase;
}

.node-content {
  @apply p-3;
}

.template-type {
  @apply text-xs uppercase mb-1;
  color: rgb(var(--slate-10));
}

.dark .template-type {
  @apply text-slate-400;
}

.template-name {
  @apply text-sm font-medium font-mono;
  color: rgb(var(--slate-12));
}

.dark .template-name {
  @apply text-slate-200;
}
</style>
