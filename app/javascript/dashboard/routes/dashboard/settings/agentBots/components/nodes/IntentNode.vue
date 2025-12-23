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

const handler = computed(() => props.data.handler || null);
const label = computed(() => props.data.label || null);

// Get scope (default to 'global' for backward compatibility)
const scope = computed(() => props.data.scope || 'global');
const scopeLabel = computed(() =>
  scope.value === 'global' ? 'Global' : 'Contextual'
);
const scopeIcon = computed(() =>
  scope.value === 'global' ? 'i-lucide-globe' : 'i-lucide-git-branch'
);

// Get validation status
// eslint-disable-next-line no-underscore-dangle
const validation = computed(() => props.data._validation);
const hasWarning = computed(() => validation.value?.level === 'warning');
const hasError = computed(() => validation.value?.level === 'error');
const validationMessages = computed(
  () => validation.value?.messages?.join(', ') || ''
);
</script>

<template>
  <div
    class="intent-node"
    :class="{
      'has-warning': hasWarning,
      'has-error': hasError,
    }"
    :title="validationMessages"
  >
    <Handle type="target" :position="Position.Left" />

    <div class="node-header intent-header">
      <i class="i-lucide-message-square-text" />
      <span class="node-type">Intent</span>
      <!-- Validation indicator -->
      <span v-if="hasError" class="validation-badge error-badge">!</span>
      <span
        v-if="hasWarning && !hasError"
        class="validation-badge warning-badge"
        >⚠</span
      >
    </div>

    <div class="node-content">
      <div v-if="label" class="intent-label">{{ label }}</div>
      <div class="keyword-preview">{{ keywordPreview }}</div>
      <div class="match-type">
        {{ data.exact_match ? 'Exact match' : 'Contains' }}
      </div>
      <div v-if="handler" class="handler-method">
        <i class="i-lucide-code" />
        <span>{{ handler }}</span>
      </div>
      <div class="scope-badge" :class="`scope-${scope}`">
        <i :class="scopeIcon" />
        <span>{{ scopeLabel }}</span>
      </div>
      <div v-if="validationMessages" class="validation-message">
        {{ validationMessages }}
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

/* Warning state - Orange border */
.intent-node.has-warning {
  border-color: #fb923c !important;
  border-width: 3px;
  box-shadow: 0 0 12px rgba(251, 146, 60, 0.3);
}

.intent-node.has-warning:hover {
  border-color: #f97316 !important;
  box-shadow: 0 0 16px rgba(249, 115, 22, 0.4);
}

/* Error state - Red border */
.intent-node.has-error {
  border-color: #ef4444 !important;
  border-width: 3px;
  box-shadow: 0 0 12px rgba(239, 68, 68, 0.3);
}

.intent-node.has-error:hover {
  border-color: #dc2626 !important;
  box-shadow: 0 0 16px rgba(220, 38, 38, 0.4);
}

.node-header {
  @apply flex items-center gap-2 px-3 py-2 border-b relative;
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

/* Warning header background */
.has-warning .intent-header {
  background: #ffedd5 !important;
  color: #9a3412 !important;
}

.dark .has-warning .intent-header {
  background: #7c2d12 !important;
  color: #fed7aa !important;
}

/* Error header background */
.has-error .intent-header {
  background: #fee2e2 !important;
  color: #991b1b !important;
}

.dark .has-error .intent-header {
  background: #7f1d1d !important;
  color: #fecaca !important;
}

.node-type {
  @apply text-xs font-semibold uppercase;
}

.validation-badge {
  @apply ml-auto text-sm font-bold;
}

.warning-badge {
  color: #ea580c;
}

.dark .warning-badge {
  color: #fb923c;
}

.error-badge {
  color: #dc2626;
}

.dark .error-badge {
  color: #f87171;
}

.node-content {
  @apply p-3;
}

.intent-label {
  @apply text-sm font-semibold mb-2;
  color: rgb(var(--slate-12));
}

.dark .intent-label {
  @apply text-slate-100;
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

.scope-badge {
  @apply flex items-center gap-1 text-xs mt-2 px-2 py-1 rounded-md font-medium;
  width: fit-content;
}

.scope-badge i {
  @apply text-xs;
}

.scope-global {
  background: rgb(var(--blue-100));
  color: rgb(var(--blue-700));
}

.dark .scope-global {
  background: rgb(var(--blue-900));
  color: rgb(var(--blue-200));
}

.scope-contextual {
  background: rgb(var(--purple-100));
  color: rgb(var(--purple-700));
}

.dark .scope-contextual {
  background: rgb(var(--purple-900));
  color: rgb(var(--purple-200));
}

.validation-message {
  @apply text-xs mt-2 pt-2 font-medium border-t;
  color: #c2410c;
  border-top-color: #fed7aa;
}

.has-error .validation-message {
  color: #b91c1c;
  border-top-color: #fecaca;
}

.dark .validation-message {
  color: #fdba74;
  border-top-color: #7c2d12;
}

.dark .has-error .validation-message {
  color: #fca5a5;
  border-top-color: #7f1d1d;
}
</style>
