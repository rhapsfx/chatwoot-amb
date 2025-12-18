<script setup>
import { ref, watch, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

const props = defineProps({
  modelValue: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const localData = ref({
  action_type: 'send_message',
  parameters: {},
  ...props.modelValue,
});

watch(
  localData,
  newVal => {
    emit('update:modelValue', newVal);
  },
  { deep: true }
);

const actionTypeOptions = [
  { value: 'send_message', label: 'Send Message' },
  { value: 'send_template', label: 'Send Template' },
  { value: 'update_conversation', label: 'Update Conversation' },
  { value: 'assign_agent', label: 'Assign Agent' },
  { value: 'add_label', label: 'Add Label' },
  { value: 'set_attribute', label: 'Set Attribute' },
  { value: 'trigger_webhook', label: 'Trigger Webhook' },
];

const showParameters = computed(() => {
  return localData.value.action_type !== 'send_message';
});

const parameterFields = computed(() => {
  switch (localData.value.action_type) {
    case 'send_template':
      return [
        {
          key: 'template_name',
          label: 'Template Name',
          type: 'text',
          placeholder: 'e.g., ah_main_menu',
        },
      ];
    case 'update_conversation':
      return [
        {
          key: 'status',
          label: 'Status',
          type: 'select',
          options: [
            { value: 'open', label: 'Open' },
            { value: 'resolved', label: 'Resolved' },
            { value: 'pending', label: 'Pending' },
          ],
        },
      ];
    case 'assign_agent':
      return [
        {
          key: 'agent_id',
          label: 'Agent ID',
          type: 'number',
          placeholder: 'Enter agent ID',
        },
      ];
    case 'add_label':
      return [
        {
          key: 'label_name',
          label: 'Label Name',
          type: 'text',
          placeholder: 'e.g., priority, vip',
        },
      ];
    case 'set_attribute':
      return [
        {
          key: 'attribute_name',
          label: 'Attribute Name',
          type: 'text',
          placeholder: 'e.g., user_region',
        },
        {
          key: 'attribute_value',
          label: 'Attribute Value',
          type: 'text',
          placeholder: 'e.g., Americas',
        },
      ];
    case 'trigger_webhook':
      return [
        {
          key: 'webhook_url',
          label: 'Webhook URL',
          type: 'text',
          placeholder: 'https://example.com/webhook',
        },
        {
          key: 'method',
          label: 'HTTP Method',
          type: 'select',
          options: [
            { value: 'POST', label: 'POST' },
            { value: 'GET', label: 'GET' },
            { value: 'PUT', label: 'PUT' },
          ],
        },
      ];
    default:
      return [];
  }
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <SelectMenu
      v-model="localData.action_type"
      label="Action Type"
      :options="actionTypeOptions"
    />

    <TextArea
      v-if="localData.action_type === 'send_message'"
      v-model="localData.parameters.message_content"
      label="Message Content"
      placeholder="Enter the message text to send"
      :max-length="1000"
    />

    <div v-if="showParameters" class="flex flex-col gap-3">
      <h4 class="text-sm font-medium text-n-slate-12">
        {{ t('AGENT_BOTS.NODE_CONFIG.PARAMETERS') }}
      </h4>

      <div
        v-for="field in parameterFields"
        :key="field.key"
        class="parameter-field"
      >
        <SelectMenu
          v-if="field.type === 'select'"
          v-model="localData.parameters[field.key]"
          :label="field.label"
          :options="field.options"
        />

        <Input
          v-else
          v-model="localData.parameters[field.key]"
          :label="field.label"
          :type="field.type"
          :placeholder="field.placeholder"
        />
      </div>
    </div>

    <div class="p-3 bg-n-slate-2 rounded-lg border border-n-weak">
      <h5 class="text-xs font-medium text-n-slate-12 mb-1">
        {{ t('AGENT_BOTS.NODE_CONFIG.ACTION_INFO') }}
      </h5>
      <p class="text-xs text-n-slate-10">
        {{ t('AGENT_BOTS.NODE_CONFIG.ACTION_INFO_DESCRIPTION') }}
      </p>
    </div>
  </div>
</template>

<style scoped>
.parameter-field {
  padding: 8px;
  background: var(--n-slate-2);
  border-radius: 6px;
}
</style>
