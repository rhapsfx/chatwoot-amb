<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import TemplatesAPI from 'dashboard/api/templates';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  messageType: {
    type: String,
    required: true,
    validator: value =>
      [
        'quick_reply',
        'list_picker',
        'time_picker',
        'form',
        'imessage_app',
        'oauth',
        'apple_pay',
      ].includes(value),
  },
  messageData: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close', 'save', 'saveAndSend']);

const { t } = useI18n();

const store = useStore();

// Form state
const templateName = ref('');
const shortCode = ref('');
const category = ref('general');
const description = ref('');
const tags = ref('');
const shortCodeError = ref('');
const templateNameError = ref('');
const existingTemplates = ref([]);

// Category options - must match MessageTemplate::CATEGORIES
const categoryOptions = [
  { value: 'general', label: t('TEMPLATES.CATEGORIES.GENERAL') },
  { value: 'payment', label: t('TEMPLATES.CATEGORIES.PAYMENT') },
  { value: 'scheduling', label: t('TEMPLATES.CATEGORIES.SCHEDULING') },
  { value: 'support', label: t('TEMPLATES.CATEGORIES.SUPPORT') },
  { value: 'marketing', label: t('TEMPLATES.CATEGORIES.MARKETING') },
  { value: 'feedback', label: t('TEMPLATES.CATEGORIES.FEEDBACK') },
  { value: 'notification', label: t('TEMPLATES.CATEGORIES.NOTIFICATION') },
  { value: 'confirmation', label: t('TEMPLATES.CATEGORIES.CONFIRMATION') },
  { value: 'sales', label: t('TEMPLATES.CATEGORIES.SALES') },
];

// Computed
const existingCannedResponses = computed(() => {
  return store.getters.getCannedResponses || [];
});

const isShortCodeUnique = computed(() => {
  if (!shortCode.value) return true;
  return !existingCannedResponses.value.some(
    response =>
      response.short_code.toLowerCase() === shortCode.value.toLowerCase()
  );
});

const isTemplateNameUnique = computed(() => {
  if (!templateName.value) return true;
  return !existingTemplates.value.some(
    template =>
      template.name.toLowerCase() === templateName.value.trim().toLowerCase()
  );
});

const isFormValid = computed(() => {
  return (
    templateName.value.trim().length > 0 &&
    description.value.trim().length > 0 &&
    isTemplateNameUnique.value
  );
});

// Methods
const generateTemplateName = () => {
  const typeMap = {
    quick_reply: 'Quick Reply',
    list_picker: 'List Picker',
    time_picker: 'Time Picker',
    form: 'Form',
    imessage_app: 'iMessage App',
    oauth: 'OAuth',
    apple_pay: 'Apple Pay',
  };

  const baseType = typeMap[props.messageType] || props.messageType;

  // Extract meaningful content from messageData
  let contentSuffix = '';

  switch (props.messageType) {
    case 'quick_reply':
      if (props.messageData.title) {
        contentSuffix = props.messageData.title
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '_')
          .substring(0, 30);
      }
      break;
    case 'list_picker':
      if (props.messageData.title) {
        contentSuffix = props.messageData.title
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '_')
          .substring(0, 30);
      }
      break;
    case 'time_picker':
      if (props.messageData.received_message?.title) {
        contentSuffix = props.messageData.received_message.title
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '_')
          .substring(0, 30);
      } else if (props.messageData.receivedMessage?.title) {
        contentSuffix = props.messageData.receivedMessage.title
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '_')
          .substring(0, 30);
      }
      break;
    case 'form':
      if (props.messageData.title) {
        contentSuffix = props.messageData.title
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '_')
          .substring(0, 30);
      }
      break;
    default:
      break;
  }

  const baseName = contentSuffix
    ? `${baseType} ${contentSuffix}`
    : `${baseType} Template`;

  const normalizedBaseName = baseName
    .replace(/\s+/g, '_')
    .replace(/_+/g, '_')
    .toLowerCase();

  // Ensure uniqueness by checking existing templates
  const existingNames = existingTemplates.value.map(template =>
    template.name.toLowerCase()
  );

  // Debug logging
  // eslint-disable-next-line no-console
  console.log('[SaveAsTemplateModal] Generating name:', {
    baseName: normalizedBaseName,
    existingTemplatesCount: existingTemplates.value.length,
    existingNames,
  });

  let candidateName = normalizedBaseName;
  let counter = 1;

  while (existingNames.includes(candidateName.toLowerCase())) {
    candidateName = `${normalizedBaseName}_${counter}`;
    counter += 1;
  }

  // eslint-disable-next-line no-console
  console.log('[SaveAsTemplateModal] Generated unique name:', candidateName);

  return candidateName;
};

const generateShortCode = () => {
  const prefix = props.messageType.substring(0, 3);
  const timestamp = Date.now().toString().slice(-6);

  const baseShortCode = `${prefix}_${timestamp}`;
  const existingShortCodes = existingCannedResponses.value.map(
    response => response.short_code
  );

  // Ensure uniqueness
  let counter = 1;
  let candidateShortCode = baseShortCode;

  while (existingShortCodes.includes(candidateShortCode)) {
    candidateShortCode = `${baseShortCode}_${counter}`;
    counter += 1;
  }

  return candidateShortCode;
};

const generateDescription = () => {
  const typeMap = {
    quick_reply: 'Quick reply message',
    list_picker: 'List picker with options',
    time_picker: 'Time picker for scheduling',
    form: 'Form for collecting information',
    imessage_app: 'iMessage app integration',
    oauth: 'OAuth authentication',
    apple_pay: 'Apple Pay payment request',
  };

  const baseDescription =
    typeMap[props.messageType] || 'Apple Messages template';

  // Add content-specific details
  let detailSuffix = '';

  switch (props.messageType) {
    case 'quick_reply':
      if (props.messageData.title) {
        detailSuffix = `: ${props.messageData.title}`;
      }
      break;
    case 'list_picker':
      if (props.messageData.title) {
        detailSuffix = `: ${props.messageData.title}`;
      }
      break;
    case 'time_picker':
      if (props.messageData.received_message?.title) {
        detailSuffix = `: ${props.messageData.received_message.title}`;
      } else if (props.messageData.receivedMessage?.title) {
        detailSuffix = `: ${props.messageData.receivedMessage.title}`;
      }
      break;
    case 'form':
      if (props.messageData.title) {
        detailSuffix = `: ${props.messageData.title}`;
      }
      break;
    default:
      break;
  }

  return `${baseDescription}${detailSuffix}`;
};

const detectCategory = () => {
  const messageType = props.messageType;
  const dataStr = JSON.stringify(props.messageData).toLowerCase();

  if (
    messageType === 'time_picker' ||
    dataStr.includes('appointment') ||
    dataStr.includes('schedule')
  ) {
    return 'scheduling';
  }
  if (
    messageType === 'apple_pay' ||
    dataStr.includes('payment') ||
    dataStr.includes('pay')
  ) {
    return 'payment';
  }
  if (
    messageType === 'quick_reply' &&
    (dataStr.includes('help') || dataStr.includes('support'))
  ) {
    return 'support';
  }
  if (
    dataStr.includes('buy') ||
    dataStr.includes('purchase') ||
    dataStr.includes('order')
  ) {
    return 'sales';
  }

  return 'general';
};

const initializeFormFields = () => {
  templateName.value = generateTemplateName();
  shortCode.value = generateShortCode();
  description.value = generateDescription();
  category.value = detectCategory();
  tags.value = '';
  shortCodeError.value = '';
  templateNameError.value = '';
};

const validateTemplateName = () => {
  if (!templateName.value.trim()) {
    templateNameError.value = t(
      'TEMPLATES.SAVE_AS_TEMPLATE.TEMPLATE_NAME.ERROR_REQUIRED'
    );
    return false;
  }

  if (!isTemplateNameUnique.value) {
    templateNameError.value = t(
      'TEMPLATES.SAVE_AS_TEMPLATE.TEMPLATE_NAME.ERROR_EXISTS'
    );
    return false;
  }

  templateNameError.value = '';
  return true;
};

const validateShortCode = () => {
  if (!shortCode.value.trim()) {
    shortCodeError.value = t(
      'TEMPLATES.SAVE_AS_TEMPLATE.SHORT_CODE.ERROR_REQUIRED'
    );
    return false;
  }

  if (!isShortCodeUnique.value) {
    shortCodeError.value = t(
      'TEMPLATES.SAVE_AS_TEMPLATE.SHORT_CODE.ERROR_EXISTS'
    );
    return false;
  }

  shortCodeError.value = '';
  return true;
};

const handleClose = () => {
  emit('close');
};

// Load templates helper function
const loadTemplates = async () => {
  try {
    // Fetch ALL templates by requesting a large per_page value and including all statuses
    // This ensures we check against all existing template names for uniqueness
    // including deprecated ones to avoid name conflicts
    const response = await TemplatesAPI.get({ per_page: 1000, status: 'all' });
    existingTemplates.value = response.data?.templates || [];
    // eslint-disable-next-line no-console
    console.log('[SaveAsTemplateModal] Templates loaded:', {
      count: existingTemplates.value.length,
      total: response.data?.total,
      templates: existingTemplates.value.map(template => ({
        id: template.id,
        name: template.name,
        status: template.status,
      })),
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('[SaveAsTemplateModal] Failed to load templates:', error);
    existingTemplates.value = [];
  }
};

const handleSave = async () => {
  if (!isFormValid.value) {
    useAlert('Please fill in all required fields');
    return;
  }

  try {
    const payload = {
      messageType: props.messageType,
      messageData: props.messageData,
      templateName: templateName.value.trim(),
      category: category.value,
      description: description.value.trim(),
      tags: tags.value
        .split(',')
        .map(tag => tag.trim())
        .filter(tag => tag.length > 0),
    };

    const template = await store.dispatch(
      'messageTemplates/createFromAppleMessage',
      payload
    );

    useAlert('Template saved successfully');
    emit('save', template);
    handleClose();
  } catch (error) {
    const errorMessage =
      error.response?.data?.details ||
      error.response?.data?.error ||
      error.message ||
      'Failed to save template';

    useAlert(errorMessage, 'error');
  }
};

const handleSaveAndSend = async () => {
  if (!isFormValid.value) {
    useAlert('Please fill in all required fields');
    return;
  }

  try {
    const payload = {
      messageType: props.messageType,
      messageData: props.messageData,
      templateName: templateName.value.trim(),
      category: category.value,
      description: description.value.trim(),
      tags: tags.value
        .split(',')
        .map(tag => tag.trim())
        .filter(tag => tag.length > 0),
    };

    const template = await store.dispatch(
      'messageTemplates/createFromAppleMessage',
      payload
    );

    useAlert('Template saved successfully');
    emit('saveAndSend', { template, messageData: props.messageData });
    handleClose();
  } catch (error) {
    const errorMessage =
      error.response?.data?.details ||
      error.response?.data?.error ||
      error.message ||
      'Failed to save template';

    useAlert(errorMessage, 'error');
  }
};

// Watch props.show to initialize form
watch(
  () => props.show,
  async newShow => {
    if (newShow) {
      // eslint-disable-next-line no-console
      console.log('[SaveAsTemplateModal] Modal opened, loading templates...');
      // Load templates first to ensure we have fresh data
      await loadTemplates();
      // eslint-disable-next-line no-console
      console.log(
        '[SaveAsTemplateModal] Templates loaded, initializing form...'
      );
      // Then initialize form with unique name
      initializeFormFields();
    }
  },
  { immediate: true }
);

// Watch templateName for validation
watch(templateName, () => {
  validateTemplateName();
});

// Watch shortCode for validation
watch(shortCode, () => {
  validateShortCode();
});

// Load canned responses on mount
onMounted(async () => {
  try {
    await store.dispatch('getCannedResponse');
  } catch (error) {
    // Silent fail - canned responses will be empty
  }
});
</script>

<template>
  <div
    v-show="show"
    class="fixed inset-0 z-50 overflow-y-auto bg-black bg-opacity-80 flex items-center justify-center p-4"
  >
    <div
      class="bg-n-solid-1 dark:bg-n-slate-2 rounded-lg max-w-2xl w-full max-h-full overflow-hidden flex flex-col shadow-2xl border-4 border-woot-500 dark:border-woot-400"
    >
      <!-- Header -->
      <div
        class="flex items-center justify-between p-6 border-b border-slate-200 dark:border-n-slate-6"
      >
        <div>
          <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-100">
            {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.TITLE') }}
          </h2>
          <p class="text-sm text-slate-600 dark:text-n-slate-11 mt-1">
            {{
              $t('TEMPLATES.SAVE_AS_TEMPLATE.SUBTITLE', {
                messageType: messageType.replace('_', ' '),
              })
            }}
          </p>
        </div>
        <button
          class="text-slate-400 hover:text-slate-600 dark:hover:text-n-slate-10 transition-colors"
          @click="handleClose"
        >
          <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
            <path
              d="M19,6.41L17.59,5L12,10.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L12,13.41L17.59,19L19,17.59L13.41,12L19,6.41Z"
            />
          </svg>
        </button>
      </div>

      <!-- Form Content -->
      <div class="flex-1 overflow-y-auto p-6">
        <div class="space-y-4">
          <!-- Template Name -->
          <div>
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
            >
              {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.TEMPLATE_NAME.LABEL') }}
              <span class="text-red-500">{{
                $t('TEMPLATES.SAVE_AS_TEMPLATE.TEMPLATE_NAME.REQUIRED')
              }}</span>
            </label>
            <input
              v-model="templateName"
              type="text"
              :placeholder="
                $t('TEMPLATES.SAVE_AS_TEMPLATE.TEMPLATE_NAME.PLACEHOLDER')
              "
              class="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:text-white"
              :class="{
                'border-red-500': templateNameError,
                'border-slate-300 dark:border-slate-600': !templateNameError,
              }"
            />
            <p
              v-if="templateNameError"
              class="text-xs text-red-500 dark:text-red-400 mt-1"
            >
              {{ templateNameError }}
            </p>
            <p
              v-else-if="isTemplateNameUnique && templateName.trim().length > 0"
              class="text-xs text-green-600 dark:text-green-400 mt-1"
            >
              {{
                $t('TEMPLATES.SAVE_AS_TEMPLATE.TEMPLATE_NAME.SUCCESS_AVAILABLE')
              }}
            </p>
            <p v-else class="text-xs text-slate-500 dark:text-slate-400 mt-1">
              {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.TEMPLATE_NAME.HELP') }}
            </p>
          </div>

          <!-- Short Code -->
          <div>
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
            >
              {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.SHORT_CODE.LABEL') }}
              <span class="text-red-500">{{
                $t('TEMPLATES.SAVE_AS_TEMPLATE.SHORT_CODE.REQUIRED')
              }}</span>
            </label>
            <input
              v-model="shortCode"
              type="text"
              :placeholder="
                $t('TEMPLATES.SAVE_AS_TEMPLATE.SHORT_CODE.PLACEHOLDER')
              "
              class="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:text-white"
              :class="{
                'border-red-500': shortCodeError,
                'border-slate-300 dark:border-slate-600': !shortCodeError,
              }"
            />
            <p
              v-if="shortCodeError"
              class="text-xs text-red-500 dark:text-red-400 mt-1"
            >
              {{ shortCodeError }}
            </p>
            <p
              v-else-if="isShortCodeUnique && shortCode.trim().length > 0"
              class="text-xs text-green-600 dark:text-green-400 mt-1"
            >
              {{
                $t('TEMPLATES.SAVE_AS_TEMPLATE.SHORT_CODE.SUCCESS_AVAILABLE')
              }}
            </p>
            <p v-else class="text-xs text-slate-500 dark:text-slate-400 mt-1">
              {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.SHORT_CODE.HELP') }}
            </p>
          </div>

          <!-- Category -->
          <div>
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
            >
              {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.CATEGORY.LABEL') }}
            </label>
            <select
              v-model="category"
              class="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:text-white"
            >
              <option
                v-for="option in categoryOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
              {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.CATEGORY.HELP') }}
            </p>
          </div>

          <!-- Description -->
          <div>
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
            >
              {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.DESCRIPTION.LABEL') }}
              <span class="text-red-500">{{
                $t('TEMPLATES.SAVE_AS_TEMPLATE.DESCRIPTION.REQUIRED')
              }}</span>
            </label>
            <textarea
              v-model="description"
              rows="3"
              placeholder="Describe what this template does and when to use it"
              class="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:text-white resize-none"
              :class="{
                'border-red-500': description.trim().length === 0,
              }"
            />
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
              {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.DESCRIPTION.HELP') }}
            </p>
          </div>

          <!-- Tags -->
          <div>
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
            >
              {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.TAGS.LABEL') }}
            </label>
            <input
              v-model="tags"
              type="text"
              :placeholder="$t('TEMPLATES.SAVE_AS_TEMPLATE.TAGS.PLACEHOLDER')"
              class="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:text-white"
            />
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
              {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.TAGS.HELP') }}
            </p>
          </div>

          <!-- Preview Box -->
          <div
            class="bg-slate-50 dark:bg-slate-700 rounded-lg p-4 border border-slate-200 dark:border-slate-600"
          >
            <h4
              class="text-sm font-semibold text-slate-900 dark:text-slate-100 mb-2"
            >
              {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.PREVIEW.TITLE') }}
            </h4>
            <div class="space-y-2 text-sm">
              <div class="flex">
                <span class="text-slate-600 dark:text-slate-400 w-24">
                  {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.PREVIEW.TYPE') }}
                </span>
                <span class="text-slate-900 dark:text-slate-100 font-medium">
                  {{ messageType.replace('_', ' ').toUpperCase() }}
                </span>
              </div>
              <div class="flex">
                <span class="text-slate-600 dark:text-slate-400 w-24">
                  {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.PREVIEW.CODE') }}
                </span>
                <span class="text-slate-900 dark:text-slate-100 font-mono">
                  {{ shortCode || '(not set)' }}
                </span>
              </div>
              <div class="flex">
                <span class="text-slate-600 dark:text-slate-400 w-24">
                  {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.PREVIEW.CATEGORY') }}
                </span>
                <span class="text-slate-900 dark:text-slate-100 capitalize">
                  {{ category }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Footer Actions -->
      <div
        class="flex items-center justify-end space-x-3 p-6 border-t border-slate-200 dark:border-n-slate-6"
      >
        <button
          class="px-4 py-2 text-slate-600 dark:text-n-slate-11 hover:text-slate-800 dark:hover:text-n-slate-10 transition-colors"
          @click="handleClose"
        >
          {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.ACTIONS.CANCEL') }}
        </button>
        <button
          :disabled="!isFormValid"
          class="px-4 py-2 bg-slate-500 text-white rounded-md hover:bg-slate-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          @click="handleSave"
        >
          {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.ACTIONS.SAVE') }}
        </button>
        <button
          :disabled="!isFormValid"
          class="px-4 py-2 bg-woot-500 text-white rounded-md hover:bg-woot-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          @click="handleSaveAndSend"
        >
          {{ $t('TEMPLATES.SAVE_AS_TEMPLATE.ACTIONS.SAVE_AND_SEND') }}
        </button>
      </div>
    </div>
  </div>
</template>
