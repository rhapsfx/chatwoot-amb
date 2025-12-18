<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  botId: {
    type: Number,
    required: true,
  },
  hasUnsavedChanges: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['import']);

const store = useStore();
const { t } = useI18n();

const dialogRef = ref(null);
const flows = ref([]);
const selectedFlow = ref(null);
const isLoading = ref(false);
const isImporting = ref(false);
const showConfirmation = ref(false);

const hasFlows = computed(() => flows.value && flows.value.length > 0);

const loadFlows = async () => {
  if (!props.botId) return;

  isLoading.value = true;
  try {
    const response = await store.dispatch('agentBots/getFlows', props.botId);
    flows.value = response?.flows || [];
  } catch (error) {
    useAlert(t('AGENT_BOTS.STUDIO.IMPORT_FLOW.ERROR_LOADING'));
    flows.value = [];
  } finally {
    isLoading.value = false;
  }
};

const selectFlow = flow => {
  selectedFlow.value = flow;
};

const close = () => {
  selectedFlow.value = null;
  showConfirmation.value = false;
  dialogRef.value?.close();
};

const cancelConfirmation = () => {
  showConfirmation.value = false;
};

const handleImport = async () => {
  if (!selectedFlow.value) {
    useAlert(t('AGENT_BOTS.STUDIO.IMPORT_FLOW.SELECT_FLOW_ERROR'));
    return;
  }

  // If there are unsaved changes, show confirmation dialog
  if (props.hasUnsavedChanges && !showConfirmation.value) {
    showConfirmation.value = true;
    return;
  }

  isImporting.value = true;
  try {
    const response = await store.dispatch('agentBots/getFlow', {
      botId: props.botId,
      flowId: selectedFlow.value.id,
    });

    if (response?.flow?.flow_data) {
      emit('import', response.flow.flow_data);
      useAlert(t('AGENT_BOTS.STUDIO.IMPORT_FLOW.SUCCESS'));
      close();
    } else {
      useAlert(t('AGENT_BOTS.STUDIO.IMPORT_FLOW.INVALID_FLOW'));
    }
  } catch (error) {
    useAlert(t('AGENT_BOTS.STUDIO.IMPORT_FLOW.ERROR'));
  } finally {
    isImporting.value = false;
    showConfirmation.value = false;
  }
};

const formatDate = dateString => {
  if (!dateString) return '';
  const date = new Date(dateString);
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
};

watch(
  () => props.botId,
  async newBotId => {
    if (newBotId) {
      await loadFlows();
    }
  },
  { immediate: true }
);

defineExpose({ open: () => dialogRef.value?.open(), close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="
      showConfirmation
        ? t('AGENT_BOTS.STUDIO.IMPORT_FLOW.CONFIRM_TITLE')
        : t('AGENT_BOTS.STUDIO.IMPORT_FLOW.TITLE')
    "
    :show-cancel-button="false"
    :show-confirm-button="false"
    width="xl"
    overflow-y-auto
  >
    <!-- Confirmation dialog for unsaved changes -->
    <div v-if="showConfirmation" class="flex flex-col gap-4">
      <div
        class="flex items-start gap-3 p-4 bg-n-amber-2 border border-n-amber-6 rounded-lg"
      >
        <i class="i-lucide-alert-triangle w-5 h-5 text-n-amber-11 mt-0.5" />
        <div class="flex-1">
          <p class="text-sm font-medium text-n-amber-12 mb-1">
            {{ t('AGENT_BOTS.STUDIO.IMPORT_FLOW.CONFIRM_MESSAGE') }}
          </p>
          <p class="text-xs text-n-amber-11">
            {{ t('AGENT_BOTS.STUDIO.IMPORT_FLOW.CONFIRM_DESCRIPTION') }}
          </p>
        </div>
      </div>

      <div class="flex gap-2 justify-end">
        <Button
          faded
          slate
          :label="t('AGENT_BOTS.FORM.CANCEL')"
          @click="cancelConfirmation"
        />
        <Button
          color="ruby"
          :label="t('AGENT_BOTS.STUDIO.IMPORT_FLOW.CONFIRM_IMPORT')"
          :is-loading="isImporting"
          @click="handleImport"
        />
      </div>
    </div>

    <!-- Flow selection dialog -->
    <div v-else class="flex flex-col gap-4">
      <p class="text-sm text-n-slate-11">
        {{ t('AGENT_BOTS.STUDIO.IMPORT_FLOW.DESCRIPTION') }}
      </p>

      <!-- Loading state -->
      <div
        v-if="isLoading && flows.length === 0"
        class="flex items-center justify-center py-8"
      >
        <div class="flex items-center gap-2 text-n-slate-11">
          <i class="i-lucide-loader-2 w-5 h-5 animate-spin" />
          <span class="text-sm">{{ t('AGENT_BOTS.LIST.LOADING') }}</span>
        </div>
      </div>

      <!-- Empty state -->
      <div
        v-else-if="!isLoading && !hasFlows"
        class="flex flex-col items-center justify-center py-8 text-center"
      >
        <i class="i-lucide-workflow w-12 h-12 mb-3 text-n-slate-8" />
        <p class="text-sm text-n-slate-11">
          {{ t('AGENT_BOTS.STUDIO.IMPORT_FLOW.NO_FLOWS') }}
        </p>
      </div>

      <!-- Flows list -->
      <div v-else class="flex flex-col gap-2">
        <div
          v-for="flow in flows"
          :key="flow.id"
          class="flex items-start gap-3 p-4 border rounded-lg cursor-pointer transition-all"
          :class="
            selectedFlow?.id === flow.id
              ? 'border-n-blue-8 bg-n-blue-2'
              : 'border-n-weak hover:border-n-soft hover:bg-n-slate-2'
          "
          @click="selectFlow(flow)"
        >
          <div class="flex items-center justify-center mt-0.5">
            <i
              v-if="selectedFlow?.id === flow.id"
              class="i-lucide-check-circle-2 w-5 h-5 text-n-blue-11"
            />
            <i v-else class="i-lucide-circle w-5 h-5 text-n-slate-8" />
          </div>

          <div class="flex-1">
            <div class="flex items-center gap-2 mb-1">
              <h4 class="text-sm font-medium text-n-slate-12">
                {{ flow.name }}
              </h4>
              <span
                v-if="flow.is_active"
                class="text-xs bg-n-green-8 text-white rounded-full px-2 py-0.5"
              >
                {{ t('AGENT_BOTS.STUDIO.IMPORT_FLOW.ACTIVE') }}
              </span>
            </div>

            <div class="flex items-center gap-3 text-xs text-n-slate-11">
              <span v-if="flow.flow_data?.nodes?.length">
                <i class="i-lucide-box w-3 h-3 inline mr-1" />
                {{
                  t('AGENT_BOTS.STUDIO.IMPORT_FLOW.NODES_COUNT', {
                    count: flow.flow_data.nodes.length,
                  })
                }}
              </span>
              <span v-if="flow.flow_data?.edges?.length">
                <i class="i-lucide-git-branch w-3 h-3 inline mr-1" />
                {{
                  t('AGENT_BOTS.STUDIO.IMPORT_FLOW.EDGES_COUNT', {
                    count: flow.flow_data.edges.length,
                  })
                }}
              </span>
              <span v-if="flow.updated_at">
                <i class="i-lucide-clock w-3 h-3 inline mr-1" />
                {{ formatDate(flow.updated_at) }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Footer actions -->
      <div class="flex gap-2 justify-end pt-2 border-t border-n-soft">
        <Button
          faded
          slate
          :label="t('AGENT_BOTS.FORM.CANCEL')"
          @click="close"
        />
        <Button
          :label="t('AGENT_BOTS.STUDIO.IMPORT_FLOW.IMPORT')"
          :disabled="!selectedFlow || isImporting"
          :is-loading="isImporting"
          @click="handleImport"
        />
      </div>
    </div>
  </Dialog>
</template>
