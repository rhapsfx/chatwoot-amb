<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const localData = ref({
  state_id: '',
  label: '',
  description: '',
  actions: [],
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
  { value: 'send_template', label: 'Send Template' },
  { value: 'send_text', label: 'Send Text' },
  { value: 'update_attribute', label: 'Update Attribute' },
];

const addAction = () => {
  localData.value.actions.push({
    type: 'send_template',
    template_name: '',
  });
};

const removeAction = index => {
  localData.value.actions.splice(index, 1);
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <Input
      v-model="localData.state_id"
      label="State ID"
      placeholder="e.g., AHA1"
      message="Unique identifier for this state"
    />

    <Input
      v-model="localData.label"
      label="Label"
      placeholder="e.g., Welcome Message"
    />

    <TextArea
      v-model="localData.description"
      label="Description"
      placeholder="Describe what happens in this state"
      :max-length="500"
    />

    <div class="mt-4">
      <div class="flex justify-between items-center mb-3">
        <h4 class="text-sm font-medium text-n-slate-12">
          {{ t('AGENT_BOTS.NODE_CONFIG.ACTIONS') }}
        </h4>
        <Button icon="i-lucide-plus" size="xs" @click="addAction">
          {{ t('AGENT_BOTS.NODE_CONFIG.ADD_ACTION') }}
        </Button>
      </div>

      <div
        v-for="(action, index) in localData.actions"
        :key="index"
        class="action-item"
      >
        <SelectMenu
          v-model="action.type"
          label="Action Type"
          :options="actionTypeOptions"
        />

        <Input
          v-if="action.type === 'send_template'"
          v-model="action.template_name"
          label="Template Name"
          placeholder="e.g., ah_main_menu"
        />

        <Input
          v-if="action.type === 'send_text'"
          v-model="action.text_content"
          label="Text Content"
          placeholder="Enter message text"
        />

        <div
          v-if="action.type === 'update_attribute'"
          class="flex flex-col gap-2"
        >
          <Input
            v-model="action.attribute_name"
            label="Attribute Name"
            placeholder="e.g., user_region"
          />
          <Input
            v-model="action.attribute_value"
            label="Attribute Value"
            placeholder="e.g., Americas"
          />
        </div>

        <Button
          icon="i-lucide-trash-2"
          size="xs"
          variant="faded"
          color="ruby"
          class="mt-2"
          @click="removeAction(index)"
        >
          {{ t('AGENT_BOTS.NODE_CONFIG.REMOVE') }}
        </Button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.action-item {
  padding: 12px;
  border: 1px solid var(--n-weak);
  border-radius: 6px;
  margin-bottom: 8px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
</style>
