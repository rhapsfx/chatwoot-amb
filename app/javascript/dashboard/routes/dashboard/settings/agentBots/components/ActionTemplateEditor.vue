<script setup>
import { ref, computed, watch, defineAsyncComponent } from 'vue';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  accountId: {
    type: Number,
    required: true,
  },
  template: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['save', 'close']);

const { t } = useI18n();

const dialogRef = ref(null);
const templateName = ref('');
const templateType = ref('');
const templateParameters = ref({});
const isLoading = ref(false);

// Template type definitions with metadata
const templateTypes = computed(() => [
  {
    value: 'send_text_message',
    label: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TEXT_MESSAGE.NAME'
    ),
    description: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TEXT_MESSAGE.DESCRIPTION'
    ),
    icon: 'i-lucide-message-square',
  },
  {
    value: 'send_list_picker',
    label: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_LIST_PICKER.NAME'
    ),
    description: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_LIST_PICKER.DESCRIPTION'
    ),
    icon: 'i-lucide-list',
  },
  {
    value: 'send_time_picker',
    label: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.NAME'
    ),
    description: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.DESCRIPTION'
    ),
    icon: 'i-lucide-clock',
  },
  {
    value: 'send_form',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.NAME'),
    description: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.DESCRIPTION'
    ),
    icon: 'i-lucide-file-text',
  },
  {
    value: 'send_rich_link',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_RICH_LINK.NAME'),
    description: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_RICH_LINK.DESCRIPTION'
    ),
    icon: 'i-lucide-link',
  },
  {
    value: 'send_quick_reply',
    label: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.NAME'
    ),
    description: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.DESCRIPTION'
    ),
    icon: 'i-lucide-message-circle',
  },
  {
    value: 'update_attributes',
    label: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.UPDATE_ATTRIBUTES.NAME'
    ),
    description: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.UPDATE_ATTRIBUTES.DESCRIPTION'
    ),
    icon: 'i-lucide-database',
  },
  {
    value: 'conditional_branch',
    label: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.NAME'
    ),
    description: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.DESCRIPTION'
    ),
    icon: 'i-lucide-git-branch',
  },
  {
    value: 'send_apple_pay',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.NAME'),
    description: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.DESCRIPTION'
    ),
    icon: 'i-lucide-credit-card',
  },
  {
    value: 'api_call',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.NAME'),
    description: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.DESCRIPTION'
    ),
    icon: 'i-lucide-globe',
  },
  {
    value: 'send_imessage_app',
    label: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.NAME'
    ),
    description: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.DESCRIPTION'
    ),
    icon: 'i-lucide-smartphone',
  },
  {
    value: 'send_app_clip',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.NAME'),
    description: t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.DESCRIPTION'
    ),
    icon: 'i-lucide-app-window',
  },
]);

// Editor component mapping
const editorComponentMap = {
  send_text_message: defineAsyncComponent(
    () => import('./editors/templates/SendTextMessageTemplate.vue')
  ),
  send_list_picker: defineAsyncComponent(
    () => import('./editors/templates/SendListPickerTemplate.vue')
  ),
  send_time_picker: defineAsyncComponent(
    () => import('./editors/templates/SendTimePickerTemplate.vue')
  ),
  send_form: defineAsyncComponent(
    () => import('./editors/templates/SendFormTemplate.vue')
  ),
  send_rich_link: defineAsyncComponent(
    () => import('./editors/templates/SendRichLinkTemplate.vue')
  ),
  send_quick_reply: defineAsyncComponent(
    () => import('./editors/templates/SendQuickReplyTemplate.vue')
  ),
  update_attributes: defineAsyncComponent(
    () => import('./editors/templates/UpdateAttributesTemplate.vue')
  ),
  conditional_branch: defineAsyncComponent(
    () => import('./editors/templates/ConditionalBranchTemplate.vue')
  ),
  send_apple_pay: defineAsyncComponent(
    () => import('./editors/templates/SendApplePayTemplate.vue')
  ),
  api_call: defineAsyncComponent(
    () => import('./editors/templates/ApiCallTemplate.vue')
  ),
  send_imessage_app: defineAsyncComponent(
    () => import('./editors/templates/SendIMessageAppTemplate.vue')
  ),
  send_app_clip: defineAsyncComponent(
    () => import('./editors/templates/SendAppClipTemplate.vue')
  ),
};

// Current editor component based on selected type
const editorComponent = computed(() => {
  return templateType.value ? editorComponentMap[templateType.value] : null;
});

// Get selected template type info
const selectedTypeInfo = computed(() => {
  return templateTypes.value.find(type => type.value === templateType.value);
});

// Check if form is valid
const isFormValid = computed(() => {
  return Boolean(templateName.value && templateType.value);
});

// Watch template prop for editing mode
watch(
  () => props.template,
  newTemplate => {
    if (newTemplate) {
      templateName.value = newTemplate.name || '';
      templateType.value = newTemplate.template_type || '';
      templateParameters.value = newTemplate.parameters || {};
    }
  },
  { immediate: true }
);

// Reset parameters when template type changes
watch(templateType, (newType, oldType) => {
  if (newType !== oldType) {
    templateParameters.value = {};
  }
});

// Methods
const open = () => {
  dialogRef.value?.open();
};

const resetForm = () => {
  templateName.value = '';
  templateType.value = '';
  templateParameters.value = {};
  isLoading.value = false;
};

const close = () => {
  emit('close');
  dialogRef.value?.close();
  resetForm();
};

const save = () => {
  if (!isFormValid.value) {
    return;
  }

  const templateData = {
    name: templateName.value,
    template_type: templateType.value,
    parameters: templateParameters.value,
  };

  emit('save', templateData);
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="
      template
        ? t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.EDIT_TITLE')
        : t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.CREATE_TITLE')
    "
    width="7xl"
    overflow-y-auto
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="close"
  >
    <div class="flex flex-col gap-6">
      <!-- Template Name Input -->
      <div>
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.NAME') }}
          <span class="text-n-ruby-9">*</span>
        </label>
        <input
          v-model="templateName"
          type="text"
          class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8 text-n-slate-12"
          :placeholder="
            t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.NAME_PLACEHOLDER')
          "
        />
      </div>

      <!-- Template Type Selector (Grid) -->
      <div>
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.SELECT_TYPE') }}
          <span class="text-n-ruby-9">*</span>
        </label>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          <button
            v-for="type in templateTypes"
            :key="type.value"
            type="button"
            class="flex items-start gap-3 p-4 rounded-lg border-2 text-left transition-all"
            :class="[
              templateType === type.value
                ? 'border-n-blue-8 bg-n-blue-1'
                : 'border-n-weak hover:border-n-strong bg-n-white',
            ]"
            @click="templateType = type.value"
          >
            <div
              class="flex items-center justify-center w-10 h-10 rounded-lg transition-colors flex-shrink-0"
              :class="[
                templateType === type.value
                  ? 'bg-n-blue-8 text-white'
                  : 'bg-n-slate-2 text-n-slate-11',
              ]"
            >
              <i class="w-5 h-5" :class="[type.icon]" />
            </div>
            <div class="flex-1 min-w-0">
              <h4 class="font-semibold text-n-slate-12 mb-1 text-sm">
                {{ type.label }}
              </h4>
              <p class="text-xs text-n-slate-11 line-clamp-2">
                {{ type.description }}
              </p>
            </div>
          </button>
        </div>
      </div>

      <!-- Parameter Editor (Dynamic Component) -->
      <div v-if="templateType" class="border border-n-weak rounded-lg p-6">
        <h3 class="text-sm font-semibold text-n-slate-12 mb-4">
          {{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.PARAMETERS') }}
        </h3>

        <!-- Editor Component (Dynamic) -->
        <component
          :is="editorComponent"
          v-if="editorComponent"
          v-model="templateParameters"
          :account-id="accountId"
        />

        <!-- Fallback message if editor not available yet -->
        <div
          v-else
          class="flex flex-col items-center justify-center py-8 text-center"
        >
          <i class="i-lucide-construction w-12 h-12 mb-3 text-n-slate-8" />
          <p class="text-sm text-n-slate-11 mb-2">
            {{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.EDITOR_COMING_SOON') }}
          </p>
          <p class="text-xs text-n-slate-10">
            {{ selectedTypeInfo?.label }}
          </p>
        </div>
      </div>

      <!-- Preview -->
      <div
        v-if="templateType"
        class="border border-n-weak rounded-lg p-6 bg-n-slate-1"
      >
        <h3 class="text-sm font-semibold text-n-slate-12 mb-4">
          {{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.PREVIEW') }}
        </h3>
        <div class="text-sm text-n-slate-11 space-y-2">
          <p>
            <strong class="text-n-slate-12"
              >{{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPE') }}:</strong
            >
            {{ selectedTypeInfo?.label }}
          </p>
          <p>
            <strong class="text-n-slate-12"
              >{{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.ACTION') }}:</strong
            >
            {{ selectedTypeInfo?.description }}
          </p>
        </div>
      </div>

      <!-- Footer Actions -->
      <div class="flex justify-end gap-2 pt-4 border-t border-n-weak">
        <Button
          faded
          slate
          :label="t('AGENT_BOTS.FORM.CANCEL')"
          @click="close"
        />
        <Button
          :label="
            template
              ? t('AGENT_BOTS.FORM.SAVE')
              : t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.CREATE')
          "
          :disabled="!isFormValid"
          :is-loading="isLoading"
          @click="save"
        />
      </div>
    </div>
  </Dialog>
</template>
