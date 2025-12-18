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

const keywords = computed(() => props.data.keywords || []);
const keywordPreview = computed(() => {
  if (keywords.value.length === 0) return 'No keywords';
  if (keywords.value.length === 1) return keywords.value[0];
  return `${keywords.value[0]} +${keywords.value.length - 1} more`;
});
</script>

<template>
  <div class="intent-node">
    <Handle type="target" :position="Position.Left" />

    <div class="node-header intent-header">
      <i class="i-lucide-message-square-text" />
      <span class="node-type">Intent</span>
    </div>

    <div class="node-content">
      <div class="keyword-preview">{{ keywordPreview }}</div>
      <div class="match-type">
        {{ data.exact_match ? 'Exact match' : 'Contains' }}
      </div>
    </div>

    <Handle type="source" :position="Position.Right" />
  </div>
</template>

<style scoped>
.intent-node {
  @apply bg-white dark:bg-slate-800 rounded-lg shadow-md cursor-pointer;
  border: 2px solid rgb(var(--green-300));
  min-width: 180px;
}

.dark .intent-node {
  border-color: rgb(var(--green-600));
}

.intent-node:hover {
  border-color: rgb(var(--green-400));
  @apply shadow-lg;
}

.dark .intent-node:hover {
  border-color: rgb(var(--green-500));
}

.node-header {
  @apply flex items-center gap-2 px-3 py-2 border-b;
  border-bottom-color: rgb(var(--slate-6));
}

.dark .node-header {
  border-bottom-color: rgb(var(--slate-700));
}

.intent-header {
  background: rgb(var(--green-100));
  color: rgb(var(--green-700));
}

.dark .intent-header {
  background: rgb(var(--green-900));
  color: rgb(var(--green-200));
}

.node-type {
  @apply text-xs font-semibold uppercase;
}

.node-content {
  @apply p-3;
}

.keyword-preview {
  @apply text-sm font-medium mb-1;
  color: rgb(var(--slate-12));
}

.dark .keyword-preview {
  @apply text-slate-200;
}

.match-type {
  @apply text-xs;
  color: rgb(var(--slate-10));
}

.dark .match-type {
  @apply text-slate-400;
}
</style>
