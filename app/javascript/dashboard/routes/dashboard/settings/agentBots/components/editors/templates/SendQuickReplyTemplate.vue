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
const quickReplyTemplates = ref([]);
const loading = ref(false);
const errorMessage = ref('');

// Load quick reply templates
const loadTemplates = async () => {
  loading.value = true;
  errorMessage.value = '';

  try {
    const response = await templatesAPI.get({
      status: 'active',
      per_page: 100,
    });

    // Filter templates by checking for quick_reply content structure
    quickReplyTemplates.value = (response.data.templates || []).filter(
      template => {
        // Check template_type if available
        if (template.template_type === 'quick_reply') return true;

        // Check content structure for quick reply attributes
        const content = template.content || {};
        const attrs =
          content.contentAttributes || content.content_attributes || {};

        // Quick replies have items array with title/value pairs (be lenient)
        const hasItems = attrs.items !== undefined;

        // Also check if it's tagged as quick_reply
        const isQuickReplyTemplate =
          template.tags?.includes('quick_reply') ||
          template.tags?.includes('quick-reply');

        return hasItems || isQuickReplyTemplate;
      }
    );

    if (quickReplyTemplates.value.length === 0) {
      errorMessage.value = t(
        'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.NO_TEMPLATES'
      );
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Failed to load quick reply templates:', error);
    errorMessage.value = t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.ERROR_LOADING'
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

// Find selected template details
const selectedTemplate = computed(() => {
  if (!templateId.value) return null;
  return quickReplyTemplates.value.find(
    template => template.id === templateId.value
  );
});
</script>

<template>
  <div class="space-y-4">
    <!-- Template Selector -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.PARAMETERS.TEMPLATE'
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
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.LOADING'
          )
        }}
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
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.RETRY'
            )
          }}
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
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.PARAMETERS.SELECT_TEMPLATE'
            )
          }}
        </option>
        <option
          v-for="template in quickReplyTemplates"
          :key="template.id"
          :value="template.id"
        >
          {{ template.name }}
        </option>
      </select>

      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.PARAMETERS.TEMPLATE_HELP'
          )
        }}
      </p>

      <!-- Template Preview (if selected) -->
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
  </div>
</template>
