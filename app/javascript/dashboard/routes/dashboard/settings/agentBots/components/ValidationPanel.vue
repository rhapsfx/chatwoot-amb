<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  validationResult: {
    type: Object,
    default: () => ({ valid: true, errors: [], warnings: [] }),
  },
  isValidating: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['errorClick', 'warningClick']);

const { t } = useI18n();

const hasErrors = computed(() => props.validationResult?.errors?.length > 0);
const hasWarnings = computed(
  () => props.validationResult?.warnings?.length > 0
);
const hasIssues = computed(() => hasErrors.value || hasWarnings.value);

const validationStatus = computed(() => {
  if (props.isValidating) return 'validating';
  if (!props.validationResult) return 'unknown';
  if (hasErrors.value) return 'invalid';
  if (hasWarnings.value) return 'warnings';
  return 'valid';
});

const statusText = computed(() => {
  switch (validationStatus.value) {
    case 'validating':
      return t('AGENT_BOTS.VALIDATION.VALIDATING');
    case 'valid':
      return t('AGENT_BOTS.VALIDATION.VALID');
    case 'warnings':
      return t('AGENT_BOTS.VALIDATION.WARNINGS', {
        count: props.validationResult.warnings.length,
      });
    case 'invalid':
      return t('AGENT_BOTS.VALIDATION.INVALID', {
        count: props.validationResult.errors.length,
      });
    default:
      return t('AGENT_BOTS.VALIDATION.UNKNOWN');
  }
});

const handleErrorClick = error => {
  emit('errorClick', error);
};

const handleWarningClick = warning => {
  emit('warningClick', warning);
};

const getErrorTypeLabel = type => {
  const typeMap = {
    empty_flow: t('AGENT_BOTS.VALIDATION.ERROR_TYPES.EMPTY_FLOW'),
    missing_state_nodes: t(
      'AGENT_BOTS.VALIDATION.ERROR_TYPES.MISSING_STATE_NODES'
    ),
    missing_start_node: t(
      'AGENT_BOTS.VALIDATION.ERROR_TYPES.MISSING_START_NODE'
    ),
    missing_end_node: t('AGENT_BOTS.VALIDATION.ERROR_TYPES.MISSING_END_NODE'),
    duplicate_state_id: t(
      'AGENT_BOTS.VALIDATION.ERROR_TYPES.DUPLICATE_STATE_ID'
    ),
    invalid_node_type: t('AGENT_BOTS.VALIDATION.ERROR_TYPES.INVALID_NODE_TYPE'),
    missing_required_field: t(
      'AGENT_BOTS.VALIDATION.ERROR_TYPES.MISSING_REQUIRED_FIELD'
    ),
    invalid_state_id_format: t(
      'AGENT_BOTS.VALIDATION.ERROR_TYPES.INVALID_STATE_ID_FORMAT'
    ),
    isolated_state: t('AGENT_BOTS.VALIDATION.ERROR_TYPES.ISOLATED_STATE'),
    invalid_keyword: t('AGENT_BOTS.VALIDATION.ERROR_TYPES.INVALID_KEYWORD'),
    invalid_template: t('AGENT_BOTS.VALIDATION.ERROR_TYPES.INVALID_TEMPLATE'),
    invalid_action_type: t(
      'AGENT_BOTS.VALIDATION.ERROR_TYPES.INVALID_ACTION_TYPE'
    ),
    invalid_condition_branches: t(
      'AGENT_BOTS.VALIDATION.ERROR_TYPES.INVALID_CONDITION_BRANCHES'
    ),
    start_node_no_connection: t(
      'AGENT_BOTS.VALIDATION.ERROR_TYPES.START_NODE_NO_CONNECTION'
    ),
    orphaned_node: t('AGENT_BOTS.VALIDATION.ERROR_TYPES.ORPHANED_NODE'),
    dead_end_node: t('AGENT_BOTS.VALIDATION.ERROR_TYPES.DEAD_END_NODE'),
    circular_reference: t(
      'AGENT_BOTS.VALIDATION.ERROR_TYPES.CIRCULAR_REFERENCE'
    ),
    invalid_state_transition: t(
      'AGENT_BOTS.VALIDATION.ERROR_TYPES.INVALID_STATE_TRANSITION'
    ),
  };
  return typeMap[type] || type;
};
</script>

<template>
  <div class="validation-panel flex flex-col h-full bg-n-white">
    <!-- Header with status indicator -->
    <div
      class="flex items-center justify-between px-4 py-3 border-b border-n-soft"
    >
      <div class="flex items-center gap-2">
        <i
          class="w-5 h-5"
          :class="[
            {
              'i-lucide-loader-2 text-n-blue-11 animate-spin':
                validationStatus === 'validating',
              'i-lucide-check-circle text-n-green-11':
                validationStatus === 'valid',
              'i-lucide-alert-triangle text-n-yellow-11':
                validationStatus === 'warnings',
              'i-lucide-x-circle text-n-red-11': validationStatus === 'invalid',
              'i-lucide-help-circle text-n-slate-11':
                validationStatus === 'unknown',
            },
          ]"
        />
        <h3 class="text-sm font-semibold text-n-slate-12">
          {{ t('AGENT_BOTS.VALIDATION.TITLE') }}
        </h3>
      </div>
      <span class="text-xs text-n-slate-11">{{ statusText }}</span>
    </div>

    <!-- Content area -->
    <div class="flex-1 overflow-y-auto p-4">
      <!-- No issues state -->
      <div
        v-if="!hasIssues && !isValidating"
        class="flex flex-col items-center justify-center text-center py-8"
      >
        <i
          class="i-lucide-check-circle w-12 h-12 text-n-green-11 mb-3 opacity-60"
        />
        <p class="text-sm text-n-slate-11">
          {{ t('AGENT_BOTS.VALIDATION.NO_ISSUES') }}
        </p>
        <p class="text-xs text-n-slate-10 mt-1">
          {{ t('AGENT_BOTS.VALIDATION.NO_ISSUES_DESCRIPTION') }}
        </p>
      </div>

      <!-- Validating state -->
      <div
        v-if="isValidating"
        class="flex flex-col items-center justify-center text-center py-8"
      >
        <i
          class="i-lucide-loader-2 w-12 h-12 text-n-blue-11 mb-3 animate-spin"
        />
        <p class="text-sm text-n-slate-11">
          {{ t('AGENT_BOTS.VALIDATION.VALIDATING_MESSAGE') }}
        </p>
      </div>

      <!-- Errors list -->
      <div v-if="hasErrors" class="mb-4">
        <h4 class="text-xs font-semibold text-n-red-11 uppercase mb-2">
          {{ t('AGENT_BOTS.VALIDATION.ERRORS') }} ({{
            validationResult.errors.length
          }})
        </h4>
        <div class="space-y-2">
          <button
            v-for="(error, index) in validationResult.errors"
            :key="`error-${index}`"
            class="w-full text-left p-3 rounded-lg border border-n-red-6 bg-n-red-2 hover:bg-n-red-3 transition-colors"
            @click="handleErrorClick(error)"
          >
            <div class="flex items-start gap-2">
              <i
                class="i-lucide-x-circle w-4 h-4 text-n-red-11 flex-shrink-0 mt-0.5"
              />
              <div class="flex-1 min-w-0">
                <p class="text-xs font-medium text-n-red-12 mb-1">
                  {{ getErrorTypeLabel(error.type) }}
                </p>
                <p class="text-xs text-n-red-11 break-words">
                  {{ error.message }}
                </p>
                <div
                  v-if="error.node_id"
                  class="flex items-center gap-1 mt-1.5"
                >
                  <i class="i-lucide-map-pin w-3 h-3 text-n-red-10" />
                  <span class="text-xs text-n-red-10 font-mono">{{
                    error.node_id
                  }}</span>
                </div>
                <div v-if="error.field" class="flex items-center gap-1 mt-1.5">
                  <i class="i-lucide-alert-circle w-3 h-3 text-n-red-10" />
                  <span class="text-xs text-n-red-10">
                    {{ t('AGENT_BOTS.VALIDATION.FIELD') }}: {{ error.field }}
                  </span>
                </div>
              </div>
              <i
                class="i-lucide-chevron-right w-4 h-4 text-n-red-10 flex-shrink-0 mt-0.5"
              />
            </div>
          </button>
        </div>
      </div>

      <!-- Warnings list -->
      <div v-if="hasWarnings">
        <h4 class="text-xs font-semibold text-n-yellow-11 uppercase mb-2">
          {{ t('AGENT_BOTS.VALIDATION.WARNINGS') }} ({{
            validationResult.warnings.length
          }})
        </h4>
        <div class="space-y-2">
          <button
            v-for="(warning, index) in validationResult.warnings"
            :key="`warning-${index}`"
            class="w-full text-left p-3 rounded-lg border border-n-yellow-6 bg-n-yellow-2 hover:bg-n-yellow-3 transition-colors"
            @click="handleWarningClick(warning)"
          >
            <div class="flex items-start gap-2">
              <i
                class="i-lucide-alert-triangle w-4 h-4 text-n-yellow-11 flex-shrink-0 mt-0.5"
              />
              <div class="flex-1 min-w-0">
                <p class="text-xs font-medium text-n-yellow-12 mb-1">
                  {{ getErrorTypeLabel(warning.type) }}
                </p>
                <p class="text-xs text-n-yellow-11 break-words">
                  {{ warning.message }}
                </p>
                <div
                  v-if="warning.node_id"
                  class="flex items-center gap-1 mt-1.5"
                >
                  <i class="i-lucide-map-pin w-3 h-3 text-n-yellow-10" />
                  <span class="text-xs text-n-yellow-10 font-mono">{{
                    warning.node_id
                  }}</span>
                </div>
                <div
                  v-if="warning.field"
                  class="flex items-center gap-1 mt-1.5"
                >
                  <i class="i-lucide-alert-circle w-3 h-3 text-n-yellow-10" />
                  <span class="text-xs text-n-yellow-10">
                    {{ t('AGENT_BOTS.VALIDATION.FIELD') }}: {{ warning.field }}
                  </span>
                </div>
              </div>
              <i
                class="i-lucide-chevron-right w-4 h-4 text-n-yellow-10 flex-shrink-0 mt-0.5"
              />
            </div>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
