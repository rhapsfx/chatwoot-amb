<script setup>
import { ref, computed, onMounted } from 'vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TemplatesAPI from 'dashboard/api/templates';

const props = defineProps({
  modelValue: {
    type: [String, Number, Object],
    default: null,
  },
  hasError: {
    type: Boolean,
    default: false,
  },
  message: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['update:modelValue']);

const templates = ref([]);
const isLoading = ref(false);

const templateOptions = computed(() =>
  templates.value.map(template => ({
    value: template.id,
    label: template.name,
    template,
  }))
);

const selectedId = computed({
  get: () => {
    if (props.modelValue && typeof props.modelValue === 'object') {
      return props.modelValue.id ?? null;
    }
    return props.modelValue ?? null;
  },
  set: val => {
    const option = templateOptions.value.find(o => o.value === val);
    emit('update:modelValue', option ? option.template : null);
  },
});

const fetchTemplates = async () => {
  isLoading.value = true;
  try {
    const response = await TemplatesAPI.get({
      channel: 'apple_messages_for_business',
      category: 'notification',
    });
    templates.value = response.data?.templates ?? response.data ?? [];
  } catch {
    templates.value = [];
  } finally {
    isLoading.value = false;
  }
};

onMounted(fetchTemplates);
</script>

<template>
  <ComboBox
    v-model="selectedId"
    :options="templateOptions"
    :has-error="hasError"
    :message="message"
    placeholder="Select an invitation template"
    class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
  />
</template>
