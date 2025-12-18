<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Textarea from 'dashboard/components-next/textarea/Textarea.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  node: {
    type: Object,
    required: true,
  },
  // eslint-disable-next-line vue/no-unused-properties
  botId: {
    type: Number,
    required: false,
    default: null,
  },
});

const emit = defineEmits(['save', 'cancel']);

const { t } = useI18n();

// Local editable state
const editedData = ref({
  action_type: 'send_message',
  label: '',
  parameters: {},
});

// Initialize with node data
watch(
  () => props.node,
  newNode => {
    if (newNode?.data) {
      editedData.value = {
        action_type: newNode.data.action_type || 'send_message',
        label: newNode.data.label || '',
        parameters: newNode.data.parameters || {},
      };
    }
  },
  { immediate: true }
);

const parametersJson = ref('');

watch(
  () => editedData.value.parameters,
  newParams => {
    parametersJson.value = JSON.stringify(newParams, null, 2);
  },
  { immediate: true }
);

const updateParameters = () => {
  try {
    editedData.value.parameters = JSON.parse(parametersJson.value);
  } catch (e) {
    // Keep existing parameters if JSON is invalid
  }
};

const handleSave = () => {
  updateParameters();
  emit('save', editedData.value);
};

const handleCancel = () => {
  emit('cancel');
};
</script>

<template>
  <div class="action-node-editor">
    <h3 class="text-lg font-semibold text-n-slate-12 mb-4">
      {{ t('AGENT_BOTS.EDITORS.EDIT_ACTION_NODE') }}
    </h3>

    <div class="space-y-4">
      <!-- Label -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.EDITORS.LABEL') }}
        </label>
        <Input
          v-model="editedData.label"
          placeholder="e.g., Send Welcome Message"
          class="w-full"
        />
      </div>

      <!-- Action Type -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.EDITORS.ACTION_TYPE') }}
        </label>
        <select
          v-model="editedData.action_type"
          class="w-full px-3 py-2 pr-8 border border-n-strong rounded-md bg-n-white text-n-slate-12 appearance-none bg-[url('data:image/svg+xml;charset=utf-8,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 16 16%27 fill=%27%23666%27%3E%3Cpath d=%27M4.5 5.5l3.5 3.5 3.5-3.5h-7z%27/%3E%3C/svg%3E')] bg-[length:0.875rem] bg-[right_0.5rem_center] bg-no-repeat"
        >
          <option value="send_message">
            {{ t('AGENT_BOTS.EDITORS.SEND_MESSAGE') }}
          </option>
          <option value="transition_state">
            {{ t('AGENT_BOTS.EDITORS.TRANSITION_STATE') }}
          </option>
          <option value="call_api">
            {{ t('AGENT_BOTS.EDITORS.CALL_API') }}
          </option>
          <option value="set_variable">
            {{ t('AGENT_BOTS.EDITORS.SET_VARIABLE') }}
          </option>
        </select>
      </div>

      <!-- Parameters (JSON) -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.EDITORS.PARAMETERS_JSON') }}
        </label>
        <Textarea
          v-model="parametersJson"
          placeholder='{"message": "Hello!"}'
          rows="6"
          class="w-full font-mono text-sm"
          @blur="updateParameters"
        />
        <p class="text-xs text-n-slate-10 mt-1">
          {{ t('AGENT_BOTS.EDITORS.PARAMETERS_DESCRIPTION') }}
        </p>
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
.action-node-editor {
  padding: 0;
}
</style>
