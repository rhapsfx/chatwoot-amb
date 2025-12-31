<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import templatesAPI from 'dashboard/api/templates';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  // eslint-disable-next-line vue/no-unused-properties
  accountId: { type: Number, required: true },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

// State
const formTemplates = ref([]);
const loading = ref(false);
const errorMessage = ref('');
const jsonError = ref('');

// Load form templates
const loadTemplates = async () => {
  loading.value = true;
  errorMessage.value = '';

  try {
    const response = await templatesAPI.get({
      status: 'active',
      per_page: 100,
    });

    // Filter templates by checking for form content
    formTemplates.value = (response.data.templates || []).filter(template => {
      // Check template_type if available
      if (template.template_type === 'form') return true;

      const content = template.content || {};
      const attrs =
        content.contentAttributes || content.content_attributes || {};

      // Forms have pages or form fields (be lenient)
      const hasFormContent =
        attrs.pages !== undefined || attrs.form !== undefined;

      // Also check if it's tagged as form
      const isFormTemplate = template.tags?.includes('form');

      return hasFormContent || isFormTemplate;
    });

    if (formTemplates.value.length === 0) {
      errorMessage.value = t(
        'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.NO_TEMPLATES'
      );
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Failed to load form templates:', error);
    errorMessage.value = t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.ERROR_LOADING'
    );
  } finally {
    loading.value = false;
  }
};

onMounted(async () => {
  await loadTemplates();
});

// Two-way binding for template_id
const templateId = computed({
  get: () => props.modelValue.template_id || null,
  set: value => {
    emit('update:modelValue', { ...props.modelValue, template_id: value });
  },
});

// Pre-fill data as JSON string
const preFillJson = computed({
  get: () => {
    const data = props.modelValue.pre_fill_data || {};
    try {
      return JSON.stringify(data, null, 2);
    } catch (e) {
      return '{}';
    }
  },
  set: value => {
    try {
      const parsed = JSON.parse(value);
      jsonError.value = '';
      emit('update:modelValue', { ...props.modelValue, pre_fill_data: parsed });
    } catch (e) {
      jsonError.value = t(
        'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.PARAMETERS.JSON_ERROR'
      );
    }
  },
});

const formatJson = () => {
  try {
    const parsed = JSON.parse(preFillJson.value);
    // Update via computed setter
    preFillJson.value = JSON.stringify(parsed, null, 2);
    jsonError.value = '';
  } catch (e) {
    jsonError.value = t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.PARAMETERS.JSON_ERROR'
    );
  }
};

const selectedTemplate = computed(() => {
  if (!templateId.value) return null;
  return formTemplates.value.find(template => template.id === templateId.value);
});
</script>

<template>
  <div class="space-y-4">
    <!-- Template Selector -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.PARAMETERS.TEMPLATE'
          )
        }}
        *
      </label>

      <!-- Loading State -->
      <div
        v-if="loading"
        class="w-full px-4 py-3 border border-n-weak rounded-lg bg-n-slate-1 text-sm text-n-slate-11"
      >
        <i class="i-lucide-loader-2 w-4 h-4 inline-block animate-spin mr-2" />
        {{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.LOADING') }}
      </div>

      <!-- Error State -->
      <div
        v-else-if="errorMessage"
        class="w-full px-4 py-3 border border-red-200 rounded-lg bg-red-50 text-sm text-red-700"
      >
        <i class="i-lucide-alert-circle w-4 h-4 inline-block mr-2" />
        {{ errorMessage }}
        <button
          class="ml-2 underline hover:no-underline"
          @click="loadTemplates"
        >
          {{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.RETRY') }}
        </button>
      </div>

      <!-- Template Dropdown -->
      <select
        v-else
        v-model="templateId"
        class="w-full px-4 py-2 pr-8 border border-n-weak rounded-lg bg-n-white text-n-slate-12 appearance-none bg-[url('data:image/svg+xml;charset=utf-8,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 16 16%27 fill=%27%23666%27%3E%3Cpath d=%27M4.5 5.5l3.5 3.5 3.5-3.5h-7z%27/%3E%3C/svg%3E')] bg-[length:0.875rem] bg-[right_0.5rem_center] bg-no-repeat focus:outline-none focus:ring-2 focus:ring-n-blue-8"
      >
        <option :value="null">
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.PARAMETERS.SELECT_TEMPLATE'
            )
          }}
        </option>
        <option
          v-for="template in formTemplates"
          :key="template.id"
          :value="template.id"
        >
          {{ template.name }}
        </option>
      </select>

      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.PARAMETERS.TEMPLATE_HELP'
          )
        }}
      </p>

      <!-- Template Preview -->
      <div
        v-if="selectedTemplate"
        class="mt-2 p-3 bg-n-slate-1 border border-n-weak rounded-lg"
      >
        <div class="flex items-start gap-2">
          <i class="i-lucide-check-circle w-4 h-4 text-green-600 mt-0.5" />
          <div class="flex-1">
            <p class="text-sm font-medium text-n-slate-12">
              {{ selectedTemplate.name }}
            </p>
            <p
              v-if="selectedTemplate.description"
              class="text-xs text-n-slate-11 mt-1"
            >
              {{ selectedTemplate.description }}
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- Pre-fill Data (Optional JSON) -->
    <div>
      <div class="flex items-center justify-between mb-2">
        <label class="block text-sm font-medium text-n-slate-12">
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.PARAMETERS.PRE_FILL_DATA'
            )
          }}
        </label>
        <button
          class="px-3 py-1 text-xs text-n-blue-8 hover:bg-n-blue-2 rounded transition-colors"
          @click="formatJson"
        >
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.PARAMETERS.FORMAT_JSON'
            )
          }}
        </button>
      </div>

      <textarea
        v-model="preFillJson"
        rows="6"
        class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 font-mono text-sm"
        :class="
          jsonError
            ? 'border-red-500 focus:ring-red-500'
            : 'border-n-weak focus:ring-n-blue-8'
        "
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.PARAMETERS.PRE_FILL_PLACEHOLDER'
          )
        "
      />

      <p v-if="jsonError" class="mt-1 text-xs text-red-600">
        {{ jsonError }}
      </p>
      <p v-else class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.PARAMETERS.PRE_FILL_HELP'
          )
        }}
      </p>

      <!-- Example Section -->
      <div class="mt-3 p-3 bg-n-slate-2 border border-n-weak rounded-lg">
        <p class="text-xs font-medium text-n-slate-12 mb-1">
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.PARAMETERS.EXAMPLE'
            )
          }}
        </p>
        <pre class="text-xs text-n-slate-11 font-mono overflow-x-auto">
{
  "name": "John Doe",
  "email": "john@example.com",
  "phone": "+1234567890"
}</pre>
      </div>
    </div>
  </div>
</template>
