<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import TemplatesAPI from 'dashboard/api/templates';
import ParameterEditor from './components/ParameterEditor.vue';
import ContentBlockList from './components/ContentBlockList.vue';
import TemplatePreview from './components/TemplatePreview.vue';
import AttachmentManager from './components/AttachmentManager.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

// State
const loading = ref(false);
const saving = ref(false);
const templateId = computed(() => route.params.templateId);
const isEditMode = computed(() => !!templateId.value);

const template = ref({
  name: '',
  description: '',
  category: 'general',
  status: 'draft',
  supportedChannels: [],
  tags: [],
  useCases: [],
  parameters: {},
  contentBlocks: [],
  version: 1,
  attachments: [],
  metadata: { invitation_locale: 'en-US' }, // IMPORTANT: Include metadata field so it persists on save
});

const errors = ref({});
const activeTab = ref('basic');
const newTag = ref('');
const newUseCase = ref('');

// Hoisted early — used inside fetchTemplate
const customTemplateIdActive = ref(false);
const TEMPLATE_ID_OPTIONS = [
  {
    value: 'binaryChoice.engage.noImage',
    label: 'binaryChoice.engage.noImage',
  },
  {
    value: 'binaryChoice.engage.withImage',
    label: 'binaryChoice.engage.withImage',
  },
  { value: '__custom__', label: 'Custom value...' },
];

// Computed
const availableChannels = [
  {
    value: 'apple_messages_for_business',
    label: t('TEMPLATES.CHANNELS.APPLE_MESSAGES'),
  },
  { value: 'whatsapp', label: t('TEMPLATES.CHANNELS.WHATSAPP') },
  { value: 'web_widget', label: t('TEMPLATES.CHANNELS.WEB_WIDGET') },
  { value: 'sms', label: t('TEMPLATES.CHANNELS.SMS') },
  { value: 'email', label: t('TEMPLATES.CHANNELS.EMAIL') },
];

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

const statusOptions = [
  { value: 'draft', label: t('TEMPLATES.STATUS.DRAFT') },
  { value: 'active', label: t('TEMPLATES.STATUS.ACTIVE') },
  { value: 'deprecated', label: t('TEMPLATES.STATUS.DEPRECATED') },
];

const tabs = computed(() => [
  {
    id: 'basic',
    label: t('TEMPLATES.BUILDER.BASIC_INFO'),
    icon: 'i-lucide-info',
  },
  {
    id: 'parameters',
    label: t('TEMPLATES.BUILDER.PARAMETERS.TITLE'),
    icon: 'i-lucide-braces',
  },
  {
    id: 'content',
    label: t('TEMPLATES.BUILDER.CONTENT_BLOCKS.TITLE'),
    icon: 'i-lucide-blocks',
  },
  {
    id: 'attachments',
    label: t('TEMPLATES.BUILDER.ATTACHMENTS.TITLE'),
    icon: 'i-lucide-paperclip',
    visible: () =>
      template.value.supportedChannels.includes('apple_messages_for_business'),
  },
  {
    id: 'preview',
    label: t('TEMPLATES.BUILDER.PREVIEW.TITLE'),
    icon: 'i-lucide-eye',
  },
]);

// Methods
const fetchTemplate = async () => {
  if (!templateId.value) return;

  loading.value = true;
  try {
    const response = await TemplatesAPI.show(templateId.value);
    template.value = response.data;
    if (!template.value.metadata) template.value.metadata = {};
    if (!template.value.metadata.invitation_locale) {
      template.value.metadata.invitation_locale = 'en-US';
    }
    const existingTemplateId = template.value.metadata.invitation_template_id;
    customTemplateIdActive.value = !!(
      existingTemplateId &&
      !TEMPLATE_ID_OPTIONS.slice(0, -1).some(
        o => o.value === existingTemplateId
      )
    );
  } catch (error) {
    useAlert(t('TEMPLATES.API.FETCH_ERROR'));
    router.push({ name: 'template_list' });
  } finally {
    loading.value = false;
  }
};

const validateTemplate = () => {
  errors.value = {};

  if (!template.value.name?.trim()) {
    errors.value.name = t('TEMPLATES.BUILDER.VALIDATION.NAME_REQUIRED');
  }

  if (!template.value.category) {
    errors.value.category = t('TEMPLATES.BUILDER.VALIDATION.CATEGORY_REQUIRED');
  }

  if (template.value.supportedChannels.length === 0) {
    errors.value.channels = t('TEMPLATES.BUILDER.VALIDATION.CHANNEL_REQUIRED');
  }

  const isAppleMessages = template.value.supportedChannels.includes(
    'apple_messages_for_business'
  );
  const hasAttachments = template.value.attachments?.length > 0;
  const isNewTemplate = !isEditMode.value;
  const isNotificationCategory = template.value.category === 'notification';

  // Content blocks not required for:
  // - Notification templates (Apple Invitation — no content blocks needed)
  // - Apple Messages with attachments
  // - New Apple Messages templates (attachments added after first save)
  const canSkipContentBlocks =
    isNotificationCategory ||
    (isAppleMessages && (hasAttachments || isNewTemplate));

  if (template.value.contentBlocks.length === 0 && !canSkipContentBlocks) {
    errors.value.content = t('TEMPLATES.BUILDER.VALIDATION.CONTENT_REQUIRED');
  }

  return Object.keys(errors.value).length === 0;
};

const saveTemplate = async () => {
  if (!validateTemplate()) {
    useAlert(Object.values(errors.value)[0]);
    return;
  }

  saving.value = true;
  try {
    if (isEditMode.value) {
      await TemplatesAPI.update(templateId.value, template.value);
      useAlert(t('TEMPLATES.API.UPDATE_SUCCESS'));
      // Stay on edit page after update so user can continue editing
    } else {
      const response = await TemplatesAPI.create(template.value);
      useAlert(t('TEMPLATES.API.CREATE_SUCCESS'));

      // Redirect to edit mode for the newly created template
      // This allows user to add attachments without closing the form
      router.push({
        name: 'template_edit',
        params: { templateId: response.data.id },
      });
    }
  } catch (error) {
    const message = isEditMode.value
      ? t('TEMPLATES.API.UPDATE_ERROR')
      : t('TEMPLATES.API.CREATE_ERROR');
    useAlert(message);
  } finally {
    saving.value = false;
  }
};

const cancel = () => {
  router.push({ name: 'templates_list' });
};

const toggleChannel = channel => {
  const index = template.value.supportedChannels.indexOf(channel);
  if (index === -1) {
    template.value.supportedChannels.push(channel);
  } else {
    template.value.supportedChannels.splice(index, 1);
  }
};

const addTag = () => {
  const tag = newTag.value.trim();
  if (tag && !template.value.tags.includes(tag)) {
    template.value.tags.push(tag);
    newTag.value = '';
  }
};

const removeTag = index => {
  template.value.tags.splice(index, 1);
};

const addUseCase = () => {
  const useCase = newUseCase.value.trim();
  if (useCase && !template.value.useCases.includes(useCase)) {
    template.value.useCases.push(useCase);
    newUseCase.value = '';
  }
};

const removeUseCase = index => {
  template.value.useCases.splice(index, 1);
};

const updateParameters = parameters => {
  template.value.parameters = parameters;
};

const updateContentBlocks = blocks => {
  template.value.contentBlocks = blocks;
};

const updateAttachments = attachments => {
  template.value.attachments = attachments;
};

const templateIdSelectValue = computed({
  get() {
    if (customTemplateIdActive.value) return '__custom__';
    const val = template.value.metadata?.invitation_template_id;
    if (!val) return '';
    return TEMPLATE_ID_OPTIONS.slice(0, -1).some(o => o.value === val)
      ? val
      : '__custom__';
  },
  set(val) {
    if (!template.value.metadata) template.value.metadata = {};
    if (val === '__custom__') {
      customTemplateIdActive.value = true;
      // preserve existing value if it was already custom
      if (
        !template.value.metadata.invitation_template_id ||
        TEMPLATE_ID_OPTIONS.slice(0, -1).some(
          o => o.value === template.value.metadata.invitation_template_id
        )
      ) {
        template.value.metadata.invitation_template_id = '';
      }
    } else {
      customTemplateIdActive.value = false;
      template.value.metadata.invitation_template_id = val;
    }
  },
});

const LOCALE_OPTIONS = [
  { value: 'en-US', label: 'English (United States)' },
  { value: 'en-GB', label: 'English (United Kingdom)' },
  { value: 'en-CA', label: 'English (Canada)' },
  { value: 'en-AU', label: 'English (Australia)' },
  { value: 'fr-FR', label: 'French (France)' },
  { value: 'fr-CA', label: 'French (Canada)' },
  { value: 'de-DE', label: 'German (Germany)' },
  { value: 'es-ES', label: 'Spanish (Spain)' },
  { value: 'es-MX', label: 'Spanish (Mexico)' },
  { value: 'it-IT', label: 'Italian (Italy)' },
  { value: 'pt-BR', label: 'Portuguese (Brazil)' },
  { value: 'pt-PT', label: 'Portuguese (Portugal)' },
  { value: 'nl-NL', label: 'Dutch (Netherlands)' },
  { value: 'ru-RU', label: 'Russian (Russia)' },
  { value: 'ja-JP', label: 'Japanese (Japan)' },
  { value: 'ko-KR', label: 'Korean (South Korea)' },
  { value: 'zh-CN', label: 'Chinese Simplified (China)' },
  { value: 'zh-TW', label: 'Chinese Traditional (Taiwan)' },
  { value: 'ar-SA', label: 'Arabic (Saudi Arabia)' },
  { value: 'he-IL', label: 'Hebrew (Israel)' },
  { value: 'tr-TR', label: 'Turkish (Turkey)' },
  { value: 'pl-PL', label: 'Polish (Poland)' },
  { value: 'sv-SE', label: 'Swedish (Sweden)' },
  { value: 'da-DK', label: 'Danish (Denmark)' },
  { value: 'fi-FI', label: 'Finnish (Finland)' },
  { value: 'nb-NO', label: 'Norwegian Bokmål (Norway)' },
];

// Toggle: visual UI vs raw JSON editor
const invitationParamsVisualMode = ref(true);

// JSON editor — syncs with metadata.invitation_parameters
const invitationParametersJson = computed({
  get() {
    const params = template.value.metadata?.invitation_parameters;
    if (!params || Object.keys(params).length === 0) return '';
    try {
      return JSON.stringify(params, null, 2);
    } catch {
      return '';
    }
  },
  set(val) {
    if (!val.trim()) {
      if (template.value.metadata)
        delete template.value.metadata.invitation_parameters;
      return;
    }
    try {
      const parsed = JSON.parse(val);
      if (!template.value.metadata) template.value.metadata = {};
      template.value.metadata.invitation_parameters = parsed;
    } catch {
      // keep raw string until blur
    }
  },
});

const invitationParametersError = ref('');

const parseInvitationParameters = event => {
  const val = event.target.value.trim();
  if (!val) {
    invitationParametersError.value = '';
    if (template.value.metadata)
      delete template.value.metadata.invitation_parameters;
    return;
  }
  try {
    JSON.parse(val);
    invitationParametersError.value = '';
  } catch {
    invitationParametersError.value = t(
      'TEMPLATES.BUILDER.INVITATION.PARAMETERS.INVALID_JSON'
    );
  }
};

// Visual invitation parameters editor
const invitationBrandName = computed({
  get() {
    return template.value.metadata?.invitation_parameters?.brandName ?? '';
  },
  set(val) {
    if (!template.value.metadata) template.value.metadata = {};
    if (!template.value.metadata.invitation_parameters) {
      template.value.metadata.invitation_parameters = {};
    }
    if (val) {
      template.value.metadata.invitation_parameters.brandName = val;
    } else {
      delete template.value.metadata.invitation_parameters.brandName;
    }
  },
});

const invitationBrandLogo = computed({
  get() {
    return template.value.metadata?.invitation_parameters?.brandLogo ?? '';
  },
  set(val) {
    if (!template.value.metadata) template.value.metadata = {};
    if (!template.value.metadata.invitation_parameters) {
      template.value.metadata.invitation_parameters = {};
    }
    if (val) {
      template.value.metadata.invitation_parameters.brandLogo = val;
    } else {
      delete template.value.metadata.invitation_parameters.brandLogo;
    }
  },
});

const brandLogoDragging = ref(false);

const handleBrandLogoFile = file => {
  if (!file || !file.type.startsWith('image/')) return;
  const reader = new FileReader();
  reader.onload = e => {
    invitationBrandLogo.value = e.target.result.split(',')[1];
  };
  reader.readAsDataURL(file);
};

const handleBrandLogoDrop = e => {
  brandLogoDragging.value = false;
  handleBrandLogoFile(e.dataTransfer?.files?.[0]);
};

const handleBrandLogoInput = e => {
  handleBrandLogoFile(e.target.files?.[0]);
};

const removeBrandLogo = () => {
  invitationBrandLogo.value = '';
};

const formatLocaleOption = opt => `${opt.label} — ${opt.value}`;

const resetTemplate = () => {
  template.value = {
    name: '',
    description: '',
    category: 'general',
    status: 'draft',
    supportedChannels: [],
    tags: [],
    useCases: [],
    parameters: {},
    contentBlocks: [],
    version: 1,
    attachments: [],
    metadata: { invitation_locale: 'en-US' }, // IMPORTANT: Include metadata field
  };
  customTemplateIdActive.value = false;
  errors.value = {};
  activeTab.value = 'basic';
};

// Watch for route changes
watch(
  () => route.params.templateId,
  newId => {
    if (newId) {
      fetchTemplate();
    } else {
      resetTemplate();
    }
  }
);

onMounted(() => {
  if (isEditMode.value) {
    fetchTemplate();
  } else {
    resetTemplate();
  }
});
</script>

<template>
  <div class="flex flex-col h-full bg-n-slate-1">
    <!-- Header -->
    <div
      class="flex items-center justify-between px-6 py-4 bg-white dark:bg-n-slate-2 border-b border-n-weak"
    >
      <div>
        <h1 class="text-2xl font-semibold text-n-slate-12">
          {{
            isEditMode
              ? t('TEMPLATES.BUILDER.TITLE_EDIT')
              : t('TEMPLATES.BUILDER.TITLE_NEW')
          }}
        </h1>
        <p v-if="template.name" class="text-sm text-n-slate-11 mt-1">
          {{ template.name }}
        </p>
      </div>
      <div class="flex gap-3">
        <Button variant="outline" slate @click="cancel">
          {{ t('TEMPLATES.BUILDER.CANCEL') }}
        </Button>
        <Button
          icon="i-lucide-save"
          :label="
            saving ? t('TEMPLATES.BUILDER.SAVING') : t('TEMPLATES.BUILDER.SAVE')
          "
          :disabled="saving"
          @click="saveTemplate"
        />
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center flex-1">
      <woot-loading-state :message="t('TEMPLATES.LOADING')" />
    </div>

    <!-- Main Content -->
    <div v-else class="flex flex-1 overflow-hidden">
      <!-- Tabs Sidebar -->
      <div
        class="w-64 bg-white dark:bg-n-slate-2 border-r border-n-weak overflow-y-auto"
      >
        <nav class="p-4 space-y-1">
          <button
            v-for="tab in tabs.filter(t => !t.visible || t.visible())"
            :key="tab.id"
            class="w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left transition-colors"
            :class="[
              activeTab === tab.id
                ? 'bg-n-blue-2 text-n-blue-11 font-medium'
                : 'text-n-slate-11 hover:bg-n-slate-2',
            ]"
            @click="activeTab = tab.id"
          >
            <i class="text-lg" :class="[tab.icon]" />
            <span>{{ tab.label }}</span>
          </button>
        </nav>
      </div>

      <!-- Content Area -->
      <div class="flex-1 overflow-y-auto p-6">
        <!-- Basic Information Tab -->
        <div v-show="activeTab === 'basic'" class="max-w-3xl mx-auto space-y-6">
          <!-- Name -->
          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              {{ t('TEMPLATES.BUILDER.NAME.LABEL') }}
              <span
                class="text-n-red-11 required-indicator"
                aria-hidden="true"
              />
            </label>
            <input
              v-model="template.name"
              type="text"
              :placeholder="t('TEMPLATES.BUILDER.NAME.PLACEHOLDER')"
              class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 bg-white dark:bg-n-slate-1 text-n-slate-12 dark:text-n-slate-11"
              :class="[
                errors.name
                  ? 'border-n-red-7 focus:ring-n-red-7'
                  : 'border-n-slate-7 dark:border-n-slate-6 focus:ring-n-blue-7',
              ]"
            />
            <p v-if="errors.name" class="mt-1 text-sm text-n-red-11">
              {{ errors.name }}
            </p>
          </div>

          <!-- Description -->
          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              {{ t('TEMPLATES.BUILDER.DESCRIPTION.LABEL') }}
            </label>
            <textarea
              v-model="template.description"
              rows="3"
              :placeholder="t('TEMPLATES.BUILDER.DESCRIPTION.PLACEHOLDER')"
              class="w-full px-4 py-2 border border-n-slate-7 dark:border-n-slate-6 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7 bg-white dark:bg-n-slate-1 text-n-slate-12 dark:text-n-slate-11"
            />
          </div>

          <!-- Category and Status -->
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ t('TEMPLATES.BUILDER.CATEGORY.LABEL') }}
                <span
                  class="text-n-red-11 required-indicator"
                  aria-hidden="true"
                />
              </label>
              <select
                v-model="template.category"
                class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 bg-white dark:bg-n-slate-1 text-n-slate-12 dark:text-n-slate-11"
                :class="[
                  errors.category
                    ? 'border-n-red-7 focus:ring-n-red-7'
                    : 'border-n-slate-7 dark:border-n-slate-6 focus:ring-n-blue-7',
                ]"
              >
                <option value="">
                  {{ t('TEMPLATES.BUILDER.CATEGORY.PLACEHOLDER') }}
                </option>
                <option
                  v-for="option in categoryOptions"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
              <p v-if="errors.category" class="mt-1 text-sm text-n-red-11">
                {{ errors.category }}
              </p>
            </div>

            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ t('TEMPLATES.BUILDER.STATUS.LABEL') }}
              </label>
              <select
                v-model="template.status"
                class="w-full px-4 py-2 border border-n-slate-7 dark:border-n-slate-6 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7 bg-white dark:bg-n-slate-1 text-n-slate-12 dark:text-n-slate-11"
              >
                <option
                  v-for="option in statusOptions"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
            </div>
          </div>

          <!-- Supported Channels -->
          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              {{ t('TEMPLATES.BUILDER.CHANNELS.LABEL') }}
              <span
                class="text-n-red-11 required-indicator"
                aria-hidden="true"
              />
            </label>
            <p class="text-sm text-n-slate-11 mb-3">
              {{ t('TEMPLATES.BUILDER.CHANNELS.DESCRIPTION') }}
            </p>
            <div class="grid grid-cols-2 gap-3">
              <button
                v-for="channel in availableChannels"
                :key="channel.value"
                class="flex items-center gap-3 px-4 py-3 border-2 rounded-lg transition-all"
                :class="[
                  template.supportedChannels.includes(channel.value)
                    ? 'border-n-blue-7 bg-n-blue-2 text-n-blue-11'
                    : 'border-n-slate-7 hover:border-n-slate-8',
                ]"
                @click="toggleChannel(channel.value)"
              >
                <div
                  class="w-5 h-5 rounded border-2 flex items-center justify-center"
                  :class="[
                    template.supportedChannels.includes(channel.value)
                      ? 'border-n-blue-9 bg-n-blue-9'
                      : 'border-n-slate-7',
                  ]"
                >
                  <i
                    v-if="template.supportedChannels.includes(channel.value)"
                    class="i-lucide-check text-white text-sm"
                  />
                </div>
                <span class="text-sm font-medium">{{ channel.label }}</span>
              </button>
            </div>
            <p v-if="errors.channels" class="mt-2 text-sm text-n-red-11">
              {{ errors.channels }}
            </p>

            <!-- Apple Messages invitation hint -->
            <div
              v-if="
                template.supportedChannels.includes(
                  'apple_messages_for_business'
                )
              "
              class="mt-4 flex items-start gap-3 p-4 bg-n-teal-1 border border-n-teal-7 rounded-lg"
            >
              <i
                class="i-lucide-bell-ring text-n-teal-9 text-lg flex-shrink-0 mt-0.5"
              />
              <div class="flex-1 text-sm text-n-teal-11">
                <p>
                  {{ t('TEMPLATES.BUILDER.INVITATION.HINT_TEXT') }}
                  <button
                    type="button"
                    class="font-semibold underline hover:text-n-teal-12"
                    @click="activeTab = 'parameters'"
                  >
                    {{ t('TEMPLATES.BUILDER.INVITATION.HINT_LINK') }}
                  </button>
                </p>
              </div>
            </div>
          </div>

          <!-- Tags -->
          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              {{ t('TEMPLATES.BUILDER.TAGS.LABEL') }}
            </label>
            <p class="text-sm text-n-slate-11 mb-3">
              {{ t('TEMPLATES.BUILDER.TAGS.DESCRIPTION') }}
            </p>
            <div class="flex gap-2 mb-3">
              <input
                v-model="newTag"
                type="text"
                :placeholder="t('TEMPLATES.BUILDER.TAGS.PLACEHOLDER')"
                class="flex-1 px-4 py-2 border border-n-slate-7 dark:border-n-slate-6 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7 bg-white dark:bg-n-slate-1 text-n-slate-12 dark:text-n-slate-11"
                @keyup.enter="addTag"
              />
              <Button icon="i-lucide-plus" @click="addTag" />
            </div>
            <div v-if="template.tags.length > 0" class="flex flex-wrap gap-2">
              <span
                v-for="(tag, index) in template.tags"
                :key="index"
                class="inline-flex items-center gap-2 px-3 py-1 bg-n-slate-3 dark:bg-n-slate-4 text-n-slate-12 dark:text-n-slate-11 rounded-full text-sm"
              >
                {{ tag }}
                <button class="hover:text-n-red-11" @click="removeTag(index)">
                  <i class="i-lucide-x text-xs" />
                </button>
              </span>
            </div>
          </div>

          <!-- Use Cases -->
          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              {{ t('TEMPLATES.BUILDER.USE_CASES.LABEL') }}
            </label>
            <p class="text-sm text-n-slate-11 mb-3">
              {{ t('TEMPLATES.BUILDER.USE_CASES.DESCRIPTION') }}
            </p>
            <div class="flex gap-2 mb-3">
              <input
                v-model="newUseCase"
                type="text"
                :placeholder="t('TEMPLATES.BUILDER.USE_CASES.PLACEHOLDER')"
                class="flex-1 px-4 py-2 border border-n-slate-7 dark:border-n-slate-6 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7 bg-white dark:bg-n-slate-1 text-n-slate-12 dark:text-n-slate-11"
                @keyup.enter="addUseCase"
              />
              <Button icon="i-lucide-plus" @click="addUseCase" />
            </div>
            <div
              v-if="template.useCases.length > 0"
              class="flex flex-wrap gap-2"
            >
              <span
                v-for="(useCase, index) in template.useCases"
                :key="index"
                class="inline-flex items-center gap-2 px-3 py-1 bg-n-slate-3 dark:bg-n-slate-4 text-n-slate-12 dark:text-n-slate-11 rounded-full text-sm"
              >
                {{ useCase }}
                <button
                  class="hover:text-n-red-11"
                  @click="removeUseCase(index)"
                >
                  <i class="i-lucide-x text-xs" />
                </button>
              </span>
            </div>
          </div>
        </div>

        <!-- Parameters Tab -->
        <div
          v-show="activeTab === 'parameters'"
          class="max-w-4xl mx-auto space-y-8"
        >
          <ParameterEditor
            :parameters="template.parameters"
            @update:parameters="updateParameters"
          />

          <!-- Apple Invitation Settings (shown when Apple Messages + Notification) -->
          <div
            v-if="
              template.supportedChannels.includes(
                'apple_messages_for_business'
              ) && template.category === 'notification'
            "
            class="p-5 border border-n-slate-7 rounded-lg space-y-5"
          >
            <div class="flex items-center gap-2">
              <i class="i-lucide-bell text-n-blue-9" />
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('TEMPLATES.BUILDER.INVITATION.TITLE') }}
              </h3>
            </div>
            <p class="text-xs text-n-slate-11 -mt-3">
              {{ t('TEMPLATES.BUILDER.INVITATION.DESCRIPTION') }}
            </p>

            <!-- Apple Template ID — dropdown + custom input -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-1">
                {{ t('TEMPLATES.BUILDER.INVITATION.TEMPLATE_ID.LABEL') }}
                <span
                  class="text-n-red-11 required-indicator"
                  aria-hidden="true"
                />
              </label>
              <select
                v-model="templateIdSelectValue"
                class="w-full px-4 py-2 border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7 bg-white text-n-slate-12 text-sm"
              >
                <option value="" disabled>
                  {{
                    t('TEMPLATES.BUILDER.INVITATION.TEMPLATE_ID.PLACEHOLDER')
                  }}
                </option>
                <option
                  v-for="opt in TEMPLATE_ID_OPTIONS"
                  :key="opt.value"
                  :value="opt.value"
                >
                  {{ opt.label }}
                </option>
              </select>
              <input
                v-if="templateIdSelectValue === '__custom__'"
                v-model="template.metadata.invitation_template_id"
                type="text"
                :placeholder="
                  t('TEMPLATES.BUILDER.INVITATION.CUSTOM_TEMPLATE_PLACEHOLDER')
                "
                class="w-full mt-2 px-4 py-2 border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7 bg-white text-n-slate-12 font-mono text-sm"
              />
              <p class="mt-1 text-xs text-n-slate-11">
                {{ t('TEMPLATES.BUILDER.INVITATION.TEMPLATE_ID.HINT') }}
              </p>
            </div>

            <!-- Default Locale — full dropdown -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-1">
                {{ t('TEMPLATES.BUILDER.INVITATION.LOCALE.LABEL') }}
              </label>
              <select
                v-model="template.metadata.invitation_locale"
                class="w-full px-4 py-2 border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7 bg-white text-n-slate-12 text-sm"
              >
                <option
                  v-for="opt in LOCALE_OPTIONS"
                  :key="opt.value"
                  :value="opt.value"
                >
                  {{ formatLocaleOption(opt) }}
                </option>
              </select>
              <p class="mt-1 text-xs text-n-slate-11">
                {{ t('TEMPLATES.BUILDER.INVITATION.LOCALE.HINT') }}
              </p>
            </div>

            <!-- Default Parameters — visual editor -->
            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <label class="text-sm font-medium text-n-slate-12">
                  {{ t('TEMPLATES.BUILDER.INVITATION.PARAMETERS.LABEL') }}
                </label>
                <button
                  type="button"
                  class="flex items-center gap-1 text-xs text-n-blue-9 hover:underline"
                  @click="
                    invitationParamsVisualMode = !invitationParamsVisualMode
                  "
                >
                  <i
                    :class="
                      invitationParamsVisualMode
                        ? 'i-lucide-code'
                        : 'i-lucide-layout-template'
                    "
                  />
                  {{
                    invitationParamsVisualMode
                      ? t('TEMPLATES.BUILDER.INVITATION.PARAMETERS.SWITCH_JSON')
                      : t(
                          'TEMPLATES.BUILDER.INVITATION.PARAMETERS.SWITCH_VISUAL'
                        )
                  }}
                </button>
              </div>

              <template v-if="invitationParamsVisualMode">
                <!-- Brand Name -->
                <div>
                  <label class="block text-xs text-n-slate-11 mb-1">
                    {{
                      t(
                        'TEMPLATES.BUILDER.INVITATION.PARAMETERS.BRAND_NAME.LABEL'
                      )
                    }}
                  </label>
                  <input
                    v-model="invitationBrandName"
                    type="text"
                    :placeholder="
                      t(
                        'TEMPLATES.BUILDER.INVITATION.PARAMETERS.BRAND_NAME.PLACEHOLDER'
                      )
                    "
                    class="w-full px-4 py-2 border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7 bg-white text-n-slate-12 text-sm"
                  />
                </div>

                <!-- Brand Logo -->
                <div>
                  <label class="block text-xs text-n-slate-11 mb-2">
                    {{
                      t(
                        'TEMPLATES.BUILDER.INVITATION.PARAMETERS.BRAND_LOGO.LABEL'
                      )
                    }}
                  </label>
                  <div
                    v-if="invitationBrandLogo"
                    class="relative inline-block mb-2"
                  >
                    <img
                      :src="`data:image/png;base64,${invitationBrandLogo}`"
                      class="h-16 w-16 rounded-lg border border-n-slate-7 object-contain bg-n-slate-1"
                      alt="Brand logo"
                    />
                    <button
                      type="button"
                      class="absolute -top-1.5 -right-1.5 h-5 w-5 flex items-center justify-center rounded-full bg-n-slate-12 text-white hover:bg-n-red-11"
                      @click="removeBrandLogo"
                    >
                      <i class="i-lucide-x text-[10px]" />
                    </button>
                  </div>
                  <label
                    class="flex flex-col items-center justify-center w-full h-24 border-2 border-dashed rounded-lg cursor-pointer transition-colors"
                    :class="
                      brandLogoDragging
                        ? 'border-n-blue-9 bg-n-blue-1'
                        : 'border-n-slate-7 hover:border-n-blue-7 hover:bg-n-slate-2'
                    "
                    @dragover.prevent="brandLogoDragging = true"
                    @dragleave="brandLogoDragging = false"
                    @drop.prevent="handleBrandLogoDrop"
                  >
                    <i class="i-lucide-image text-xl text-n-slate-9 mb-1" />
                    <span class="text-xs text-n-slate-11">
                      {{
                        t(
                          'TEMPLATES.BUILDER.INVITATION.PARAMETERS.BRAND_LOGO.DROP_HINT'
                        )
                      }}
                    </span>
                    <input
                      type="file"
                      accept="image/png"
                      class="hidden"
                      @change="handleBrandLogoInput"
                    />
                  </label>
                </div>
              </template>

              <!-- JSON editor -->
              <template v-else>
                <textarea
                  v-model="invitationParametersJson"
                  rows="5"
                  placeholder='{"key": "value"}'
                  class="w-full px-4 py-2 border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7 bg-white text-n-slate-12 font-mono text-sm"
                  @blur="parseInvitationParameters"
                />
                <p
                  v-if="invitationParametersError"
                  class="mt-1 text-xs text-n-red-11"
                >
                  {{ invitationParametersError }}
                </p>
              </template>

              <p class="text-xs text-n-slate-11">
                {{ t('TEMPLATES.BUILDER.INVITATION.PARAMETERS.HINT') }}
              </p>
            </div>
          </div>
        </div>

        <!-- Content Blocks Tab -->
        <div v-show="activeTab === 'content'" class="max-w-5xl mx-auto">
          <ContentBlockList
            :blocks="template.contentBlocks"
            :parameters="template.parameters"
            :referenced-images="template.referencedImages || []"
            @update:blocks="updateContentBlocks"
          />
        </div>

        <!-- Attachments Tab -->
        <div v-show="activeTab === 'attachments'" class="max-w-4xl mx-auto">
          <AttachmentManager
            v-if="templateId"
            :template-id="templateId"
            channel-type="apple_messages_for_business"
            @attachments-updated="updateAttachments"
          />
          <div
            v-else
            class="p-8 bg-n-blue-1 border border-n-blue-7 rounded-lg text-center"
          >
            <i class="i-lucide-info text-n-blue-9 text-3xl mb-3" />
            <p class="text-sm text-n-slate-11">
              {{ t('TEMPLATES.BUILDER.ATTACHMENTS.SAVE_FIRST') }}
            </p>
          </div>
        </div>

        <!-- Preview Tab -->
        <div v-show="activeTab === 'preview'" class="max-w-6xl mx-auto">
          <TemplatePreview :template="template" />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.required-indicator::after {
  content: '*';
}
</style>
