<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Textarea from 'dashboard/components-next/textarea/Textarea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import HandlerMethodSelector from '../HandlerMethodSelector.vue';

const props = defineProps({
  node: {
    type: Object,
    required: true,
  },
  botId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['save', 'cancel']);

const { t } = useI18n();

// Local editable state
const editedData = ref({
  state_id: '',
  label: '',
  description: '',
  handler: '',
  actions: [],
});

// Initialize with node data
watch(
  () => props.node,
  newNode => {
    if (newNode?.data) {
      editedData.value = {
        state_id: newNode.data.state_id || '',
        label: newNode.data.label || '',
        description: newNode.data.description || '',
        handler: newNode.data.handler || '',
        actions: newNode.data.actions || [],
      };
    }
  },
  { immediate: true }
);

const handleSave = () => {
  emit('save', editedData.value);
};

const handleCancel = () => {
  emit('cancel');
};

const handleHandlerSelected = handler => {
  // Optionally auto-fill description from handler metadata if description is empty
  if (!editedData.value.description && handler.description) {
    editedData.value.description = handler.description;
  }

  // Optionally set label from display name if label is empty
  if (!editedData.value.label && handler.display_name) {
    editedData.value.label = handler.display_name;
  }
};
</script>

<template>
  <div class="state-node-editor">
    <h3 class="text-lg font-semibold text-n-slate-12 mb-4">
      {{ t('AGENT_BOTS.EDITORS.EDIT_STATE_NODE') }}
    </h3>

    <div class="space-y-4">
      <!-- State ID -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.EDITORS.STATE_ID') }}
        </label>
        <Input
          v-model="editedData.state_id"
          placeholder="e.g., AHA1, WELCOME_STATE"
          class="w-full"
        />
        <p class="text-xs text-n-slate-10 mt-1">
          {{ t('AGENT_BOTS.EDITORS.STATE_ID_HELP') }}
        </p>
      </div>

      <!-- Label -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.EDITORS.LABEL') }}
        </label>
        <Input
          v-model="editedData.label"
          placeholder="e.g., Welcome Message"
          class="w-full"
        />
        <p class="text-xs text-n-slate-10 mt-1">
          {{ t('AGENT_BOTS.EDITORS.LABEL_HELP') }}
        </p>
      </div>

      <!-- Description -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.EDITORS.DESCRIPTION') }}
        </label>
        <Textarea
          v-model="editedData.description"
          placeholder="Describe what happens in this state..."
          rows="3"
          class="w-full"
        />
      </div>

      <!-- Handler Method -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.HANDLER_METHODS.SELECT_HANDLER') }}
        </label>
        <HandlerMethodSelector
          v-model="editedData.handler"
          :bot-id="botId"
          service-name="AcousticHouseBotService"
          handler-type="state"
          :required="false"
          @handler-selected="handleHandlerSelected"
        />
        <p class="text-xs text-n-slate-10 mt-1">
          {{ t('AGENT_BOTS.HANDLER_METHODS.HELP_TEXT') }}
        </p>
      </div>

      <!-- Actions (placeholder for now) -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.NODE_CONFIG.ACTIONS') }}
        </label>
        <div class="text-xs text-n-slate-10 p-3 bg-n-slate-2 rounded">
          {{ t('AGENT_BOTS.EDITORS.ACTIONS_FUTURE_PHASE') }}
        </div>
      </div>

      <!-- Save/Cancel Buttons -->
      <div class="flex gap-2 pt-4 border-t border-n-strong">
        <Button
          variant="primary"
          icon="i-lucide-save"
          class="flex-1"
          @click="handleSave"
        >
          {{ t('AGENT_BOTS.EDITORS.SAVE_CHANGES') }}
        </Button>
        <Button
          variant="slate"
          icon="i-lucide-x"
          class="flex-1"
          @click="handleCancel"
        >
          {{ t('AGENT_BOTS.EDITORS.CANCEL') }}
        </Button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.state-node-editor {
  padding: 0;
}
</style>
