<script setup>
import { computed, watch } from 'vue';
import TextBlockEditor from './blocks/TextBlockEditor.vue';
import TimePickerBlockEditor from './blocks/TimePickerBlockEditor.vue';
import ListPickerBlockEditor from './blocks/ListPickerBlockEditor.vue';
import PaymentBlockEditor from './blocks/PaymentBlockEditor.vue';
import FormBlockEditor from './blocks/FormBlockEditor.vue';
import QuickReplyBlockEditor from './blocks/QuickReplyBlockEditor.vue';
import MediaBlockEditor from './blocks/MediaBlockEditor.vue';
import ButtonGroupBlockEditor from './blocks/ButtonGroupBlockEditor.vue';

const props = defineProps({
  blockType: {
    type: String,
    required: true,
  },
  properties: {
    type: Object,
    required: true,
  },
  parameters: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['update:properties']);

// Debug: Watch properties to see what's being passed
watch(
  () => props.properties,
  newProps => {
    // eslint-disable-next-line no-console
    console.log('ContentBlockEditor received properties:', {
      blockType: props.blockType,
      properties: newProps,
      keys: Object.keys(newProps),
    });
  },
  { immediate: true, deep: true }
);

const currentComponent = computed(() => {
  const components = {
    text: TextBlockEditor,
    time_picker: TimePickerBlockEditor,
    list_picker: ListPickerBlockEditor,
    payment: PaymentBlockEditor,
    form: FormBlockEditor,
    quick_reply: QuickReplyBlockEditor,
    media: MediaBlockEditor,
    button_group: ButtonGroupBlockEditor,
  };

  return components[props.blockType] || TextBlockEditor;
});

const updateProperties = newProperties => {
  emit('update:properties', newProperties);
};
</script>

<template>
  <component
    :is="currentComponent"
    :properties="properties"
    :parameters="parameters"
    @update:properties="updateProperties"
  />
</template>
