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
});

const emit = defineEmits(['save', 'cancel']);

const { t } = useI18n();

// Local editable state
const editedData = ref({
  condition_expression: '',
  label: '',
  true_label: 'True',
  false_label: 'False',
});

// Initialize with node data
watch(
  () => props.node,
  newNode => {
    if (newNode?.data) {
      editedData.value = {
        condition_expression: newNode.data.condition_expression || '',
        label: newNode.data.label || '',
        true_label: newNode.data.true_label || 'True',
        false_label: newNode.data.false_label || 'False',
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
</script>

<template>
  <div class="condition-node-editor">
    <h3 class="text-lg font-semibold text-n-slate-12 mb-4">
      {{ t('AGENT_BOTS.EDITORS.EDIT_CONDITION_NODE') }}
    </h3>

    <div class="space-y-4">
      <!-- Label -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.EDITORS.LABEL') }}
        </label>
        <Input
          v-model="editedData.label"
          placeholder="e.g., Check User Type"
          class="w-full"
        />
      </div>

      <!-- Condition Expression -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.EDITORS.CONDITION_EXPRESSION') }}
        </label>
        <Textarea
          v-model="editedData.condition_expression"
          placeholder="e.g., user.vip? || user.credits > 100"
          rows="3"
          class="w-full font-mono text-sm"
        />
        <p class="text-xs text-n-slate-10 mt-1">
          {{ t('AGENT_BOTS.EDITORS.CONDITION_EXPRESSION_HELP') }}
        </p>
      </div>

      <!-- True Path Label -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.EDITORS.TRUE_PATH_LABEL') }}
        </label>
        <Input
          v-model="editedData.true_label"
          placeholder="True"
          class="w-full"
        />
      </div>

      <!-- False Path Label -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.EDITORS.FALSE_PATH_LABEL') }}
        </label>
        <Input
          v-model="editedData.false_label"
          placeholder="False"
          class="w-full"
        />
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
.condition-node-editor {
  padding: 0;
}
</style>
