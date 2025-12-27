<script setup>
import { ref, watch, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import Input from 'dashboard/components-next/input/Input.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  modelValue: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const store = useStore();

const localData = ref({
  template_name: '',
  template_type: '',
  ...props.modelValue,
});

const templates = ref([]);
const loading = ref(false);

watch(
  localData,
  newVal => {
    emit('update:modelValue', newVal);
  },
  { deep: true }
);

const templateTypeOptions = [
  { value: 'list_picker', label: 'List Picker' },
  { value: 'time_picker', label: 'Time Picker' },
  { value: 'quick_reply', label: 'Quick Reply' },
  { value: 'rich_link', label: 'Rich Link' },
  { value: 'form', label: 'Form' },
];

const templateOptions = computed(() => {
  return templates.value.map(template => ({
    value: template.name,
    label: `${template.name} (${template.template_type})`,
  }));
});

const loadTemplates = async () => {
  loading.value = true;
  try {
    // Load templates from store
    const accountId = store.getters.getCurrentAccountId;
    const response = await store.dispatch('messageTemplates/get', {
      accountId,
    });
    templates.value = response || [];
  } catch (error) {
    // Error loading templates
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  loadTemplates();
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <div v-if="loading" class="flex items-center justify-center py-8">
      <Spinner :size="32" />
      <span class="ml-2 text-sm text-n-slate-10">{{
        t('AGENT_BOTS.NODE_CONFIG.LOADING_TEMPLATES')
      }}</span>
    </div>

    <template v-else>
      <div>
        <label class="block mb-2 text-sm font-medium text-n-slate-12">
          {{ t('AGENT_BOTS.NODE_CONFIG.SELECT_TEMPLATE') }}
        </label>
        <SelectMenu
          v-model="localData.template_name"
          label="Choose a template"
          :options="templateOptions"
        />
        <p class="text-xs text-n-slate-10 mt-1">
          {{
            t('AGENT_BOTS.NODE_CONFIG.TEMPLATES_AVAILABLE', {
              count: templates.length,
            })
          }}
        </p>
      </div>

      <SelectMenu
        v-model="localData.template_type"
        label="Template Type"
        :options="templateTypeOptions"
      />

      <Input
        v-model="localData.template_name"
        label="Template Name"
        placeholder="e.g., ah_main_menu"
        message="Manually enter template name or select from dropdown above"
      />

      <div class="p-3 bg-n-slate-2 rounded-lg border border-n-weak">
        <h5 class="text-xs font-medium text-n-slate-12 mb-1">
          {{ t('AGENT_BOTS.NODE_CONFIG.TEMPLATE_INFO') }}
        </h5>
        <p class="text-xs text-n-slate-10">
          {{ t('AGENT_BOTS.NODE_CONFIG.TEMPLATE_INFO_DESCRIPTION') }}
        </p>
      </div>
    </template>
  </div>
</template>

<style scoped>
/* No custom styles needed - using Tailwind */
</style>
