<script setup>
import { ref, computed, reactive, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { required, helpers } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { useToggle } from '@vueuse/core';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import AccessToken from 'dashboard/routes/dashboard/settings/profile/AccessToken.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

const props = defineProps({
  type: {
    type: String,
    default: 'create',
    validator: value => ['create', 'edit'].includes(value),
  },
  selectedBot: {
    type: Object,
    default: () => ({}),
  },
});

const MODAL_TYPES = {
  CREATE: 'create',
  EDIT: 'edit',
};

const store = useStore();
const { t } = useI18n();
const dialogRef = ref(null);
const uiFlags = useMapGetter('agentBots/getUIFlags');

const formState = reactive({
  botName: '',
  botDescription: '',
  botType: 'webhook',
  botUrl: '',
  botConfig: '{}',
  botAvatar: null,
  botAvatarUrl: '',
  // Structured bot config fields
  typingIndicatorsEnabled: true,
  typingIndicatorDelay: 1.5,
  conversationTimeout: 30,
  showAdvancedConfig: false,
});

const [showAccessToken, toggleAccessToken] = useToggle();
const accessToken = ref('');
const jsonError = ref('');

// Bot type options
const botTypeOptions = computed(() => [
  { value: 'webhook', label: t('AGENT_BOTS.FORM.BOT_TYPE.WEBHOOK') },
  {
    value: 'apple_messages_for_business',
    label: t('AGENT_BOTS.FORM.BOT_TYPE.AMB'),
  },
]);

const selectedBotTypeLabel = computed(() => {
  const option = botTypeOptions.value.find(
    opt => opt.value === formState.botType
  );
  return option?.label || '';
});

const showWebhookUrl = computed(() => formState.botType === 'webhook');
const showBotConfig = computed(
  () => formState.botType === 'apple_messages_for_business'
);

// Custom URL validator that accepts localhost, IP addresses, and standard URLs
const isValidWebhookUrl = value => {
  if (!value) return true; // Optional field

  // Allow localhost, IP addresses, and standard URLs
  const urlPattern =
    /^https?:\/\/(localhost|127\.0\.0\.1|\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|[\w.-]+\.[\w.-]+)(:\d+)?(\/.*)?$/i;
  return urlPattern.test(value);
};

// JSON validator
const isValidJSON = () => {
  if (formState.botType === 'webhook') return true;

  try {
    JSON.parse(formState.botConfig);
    jsonError.value = '';
    return true;
  } catch (e) {
    jsonError.value = t('AGENT_BOTS.FORM.ERRORS.INVALID_JSON');
    return false;
  }
};

const v$ = useVuelidate(
  {
    botName: {
      required: helpers.withMessage(
        () => t('AGENT_BOTS.FORM.ERRORS.NAME'),
        required
      ),
    },
    botUrl: {
      // Webhook URL is optional, but if provided, it must be valid
      isValidWebhookUrl: helpers.withMessage(
        () => t('AGENT_BOTS.FORM.ERRORS.VALID_URL'),
        isValidWebhookUrl
      ),
    },
    botConfig: {
      isValidJSON: helpers.withMessage(
        () => t('AGENT_BOTS.FORM.ERRORS.INVALID_JSON'),
        isValidJSON
      ),
    },
  },
  formState
);

const isLoading = computed(() =>
  props.type === MODAL_TYPES.CREATE
    ? uiFlags.value.isCreating
    : uiFlags.value.isUpdating
);

const dialogTitle = computed(() => {
  if (showAccessToken.value) {
    return t('AGENT_BOTS.ACCESS_TOKEN.TITLE');
  }

  return props.type === MODAL_TYPES.CREATE
    ? t('AGENT_BOTS.ADD.TITLE')
    : t('AGENT_BOTS.EDIT.TITLE');
});

const dialogDescription = computed(() => {
  if (showAccessToken.value) {
    return t('AGENT_BOTS.ACCESS_TOKEN.DESCRIPTION');
  }
  return '';
});

const confirmButtonLabel = computed(() =>
  props.type === MODAL_TYPES.CREATE
    ? t('AGENT_BOTS.FORM.CREATE')
    : t('AGENT_BOTS.FORM.UPDATE')
);

const botNameError = computed(() =>
  v$.value.botName.$error ? v$.value.botName.$errors[0]?.$message : ''
);

const botUrlError = computed(() =>
  v$.value.botUrl.$error ? v$.value.botUrl.$errors[0]?.$message : ''
);

const showAccessTokenInput = computed(
  () =>
    showAccessToken.value ||
    props.type === MODAL_TYPES.EDIT ||
    accessToken.value
);

const resetForm = () => {
  Object.assign(formState, {
    botName: '',
    botDescription: '',
    botType: 'webhook',
    botUrl: '',
    botConfig: '{}',
    botAvatar: null,
    botAvatarUrl: '',
    typingIndicatorsEnabled: true,
    typingIndicatorDelay: 1.5,
    conversationTimeout: 30,
    showAdvancedConfig: false,
  });
  jsonError.value = '';
  v$.value.$reset();
};

// Build bot_config JSON from form fields
const buildBotConfig = () => {
  if (formState.botType === 'webhook') return {};

  // If using advanced config, parse the JSON
  if (formState.showAdvancedConfig) {
    try {
      return JSON.parse(formState.botConfig);
    } catch (e) {
      return {};
    }
  }

  // Build config from form fields
  return {
    typing_indicators: {
      enabled: formState.typingIndicatorsEnabled,
      delay: formState.typingIndicatorDelay,
    },
    conversation: {
      idle_timeout: formState.conversationTimeout * 60, // Convert minutes to seconds
    },
    conversation_flow: {},
    keyword_mappings: {},
    interactive_handlers: {},
    required_templates: [],
  };
};

// Parse bot_config JSON into form fields
const parseBotConfig = botConfig => {
  if (!botConfig || Object.keys(botConfig).length === 0) {
    formState.typingIndicatorsEnabled = true;
    formState.typingIndicatorDelay = 1.5;
    formState.conversationTimeout = 30;
    return;
  }

  formState.typingIndicatorsEnabled =
    botConfig.typing_indicators?.enabled ?? true;
  formState.typingIndicatorDelay = botConfig.typing_indicators?.delay ?? 1.5;
  formState.conversationTimeout = botConfig.conversation?.idle_timeout
    ? Math.round(botConfig.conversation.idle_timeout / 60)
    : 30;
};

const handleImageUpload = ({ file, url: avatarUrl }) => {
  formState.botAvatar = file;
  formState.botAvatarUrl = avatarUrl;
};

const handleAvatarDelete = async () => {
  if (props.selectedBot?.id) {
    try {
      await store.dispatch(
        'agentBots/deleteAgentBotAvatar',
        props.selectedBot.id
      );
      formState.botAvatar = null;
      formState.botAvatarUrl = '';
      useAlert(t('AGENT_BOTS.AVATAR.SUCCESS_DELETE'));
    } catch (error) {
      useAlert(t('AGENT_BOTS.AVATAR.ERROR_DELETE'));
    }
  } else {
    formState.botAvatar = null;
    formState.botAvatarUrl = '';
  }
};

const handleSubmit = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;
  if (showAccessToken.value) return;

  const botData = {
    name: formState.botName,
    description: formState.botDescription,
    bot_type: formState.botType,
    avatar: formState.botAvatar,
  };

  // Add type-specific fields
  if (formState.botType === 'webhook') {
    botData.outgoing_url = formState.botUrl;
  } else if (formState.botType === 'apple_messages_for_business') {
    botData.bot_config = buildBotConfig();
  }

  const isCreate = props.type === MODAL_TYPES.CREATE;

  try {
    const actionPayload = isCreate
      ? botData
      : { id: props.selectedBot.id, data: botData };

    const response = await store.dispatch(
      `agentBots/${isCreate ? 'create' : 'update'}`,
      actionPayload
    );

    const alertKey = isCreate
      ? t('AGENT_BOTS.ADD.API.SUCCESS_MESSAGE')
      : t('AGENT_BOTS.EDIT.API.SUCCESS_MESSAGE');
    useAlert(alertKey);

    // Show access token after creation
    if (isCreate) {
      const { access_token: responseAccessToken, id } = response || {};

      if (id && responseAccessToken) {
        accessToken.value = responseAccessToken;
        toggleAccessToken(true);
      } else {
        accessToken.value = '';
        dialogRef.value.close();
      }
    } else {
      dialogRef.value.close();
    }

    resetForm();
  } catch (error) {
    const errorKey = isCreate
      ? t('AGENT_BOTS.ADD.API.ERROR_MESSAGE')
      : t('AGENT_BOTS.EDIT.API.ERROR_MESSAGE');
    useAlert(errorKey);
  }
};

const initializeForm = () => {
  if (props.selectedBot && Object.keys(props.selectedBot).length) {
    const {
      name,
      description,
      bot_type: botType,
      outgoing_url: botUrl,
      thumbnail,
      bot_config: botConfig,
      access_token: botAccessToken,
    } = props.selectedBot;
    formState.botName = name || '';
    formState.botDescription = description || '';
    formState.botType = botType || 'webhook';
    formState.botUrl = botUrl || botConfig?.webhook_url || '';
    formState.botConfig = botConfig ? JSON.stringify(botConfig, null, 2) : '{}';
    formState.botAvatarUrl = thumbnail || '';

    // Parse bot config into form fields
    if (botConfig && botType === 'apple_messages_for_business') {
      parseBotConfig(botConfig);
    }

    if (botAccessToken && props.type === MODAL_TYPES.EDIT) {
      accessToken.value = botAccessToken;
    }
  } else {
    resetForm();
  }
};

const onCopyToken = async value => {
  await copyTextToClipboard(value);
  useAlert(t('AGENT_BOTS.ACCESS_TOKEN.COPY_SUCCESSFUL'));
};

const onResetToken = async () => {
  const response = await store.dispatch(
    'agentBots/resetAccessToken',
    props.selectedBot.id
  );
  if (response) {
    accessToken.value = response.access_token;
    useAlert(t('AGENT_BOTS.ACCESS_TOKEN.RESET_SUCCESS'));
  } else {
    useAlert(t('AGENT_BOTS.ACCESS_TOKEN.RESET_ERROR'));
  }
};

const closeModal = () => {
  if (!showAccessToken.value) v$.value?.$reset();
  accessToken.value = '';
  toggleAccessToken(false);
};

const onClickClose = () => {
  closeModal();
  dialogRef.value.close();
};

watch(() => props.selectedBot, initializeForm, { immediate: true, deep: true });

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="dialogTitle"
    :description="dialogDescription"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="closeModal"
  >
    <form class="flex flex-col" @submit.prevent="handleSubmit">
      <!-- Scrollable content area -->
      <div class="flex flex-col gap-4 max-h-[60vh] overflow-y-auto pr-1">
        <div
          v-if="!showAccessToken || type === MODAL_TYPES.EDIT"
          class="flex flex-col gap-4"
        >
          <div class="mb-2 flex flex-col items-start">
            <span class="mb-2 text-sm font-medium text-n-slate-12">
              {{ $t('AGENT_BOTS.FORM.AVATAR.LABEL') }}
            </span>
            <Avatar
              :src="formState.botAvatarUrl"
              :name="formState.botName"
              :size="68"
              allow-upload
              icon-name="i-lucide-bot-message-square"
              @upload="handleImageUpload"
              @delete="handleAvatarDelete"
            />
          </div>

          <Input
            id="bot-name"
            v-model="formState.botName"
            :label="$t('AGENT_BOTS.FORM.NAME.LABEL')"
            :placeholder="$t('AGENT_BOTS.FORM.NAME.PLACEHOLDER')"
            :message="botNameError"
            :message-type="botNameError ? 'error' : 'info'"
            @blur="v$.botName.$touch()"
          />

          <TextArea
            id="bot-description"
            v-model="formState.botDescription"
            :label="$t('AGENT_BOTS.FORM.DESCRIPTION.LABEL')"
            :placeholder="$t('AGENT_BOTS.FORM.DESCRIPTION.PLACEHOLDER')"
          />

          <!-- Bot Type Selector -->
          <div class="flex flex-col gap-2" @click.stop>
            <label class="text-sm font-medium text-n-slate-12">
              {{ $t('AGENT_BOTS.FORM.BOT_TYPE.LABEL') }}
            </label>
            <SelectMenu
              v-model="formState.botType"
              :options="botTypeOptions"
              :label="selectedBotTypeLabel"
              sub-menu-position="bottom"
            />
          </div>

          <!-- Webhook URL (only for webhook type) -->
          <Input
            v-if="showWebhookUrl"
            id="bot-url"
            v-model="formState.botUrl"
            :label="$t('AGENT_BOTS.FORM.WEBHOOK_URL.LABEL')"
            :placeholder="$t('AGENT_BOTS.FORM.WEBHOOK_URL.PLACEHOLDER')"
            :message="botUrlError"
            :message-type="botUrlError ? 'error' : 'info'"
            @blur="v$.botUrl.$touch()"
          />

          <!-- Bot Config (only for AMB type) -->
          <div v-if="showBotConfig" class="flex flex-col gap-4">
            <div class="flex flex-col gap-2">
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ $t('AGENT_BOTS.FORM.BOT_CONFIG.LABEL') }}
              </h3>
              <p class="text-xs text-n-slate-11">
                {{ $t('AGENT_BOTS.FORM.BOT_CONFIG.HELP') }}
              </p>
            </div>

            <!-- Typing Indicators Section -->
            <div
              class="flex flex-col gap-3 p-4 bg-n-slate-1 dark:bg-n-slate-2 rounded-lg border border-n-weak"
            >
              <h4 class="text-sm font-medium text-n-slate-12">
                {{ $t('AGENT_BOTS.FORM.BOT_CONFIG.TYPING_INDICATORS.TITLE') }}
              </h4>

              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  v-model="formState.typingIndicatorsEnabled"
                  type="checkbox"
                  class="rounded"
                />
                <span class="text-sm text-n-slate-11">
                  {{
                    $t('AGENT_BOTS.FORM.BOT_CONFIG.TYPING_INDICATORS.ENABLED')
                  }}
                </span>
              </label>

              <div v-if="formState.typingIndicatorsEnabled">
                <label class="block text-sm font-medium text-n-slate-11 mb-1">
                  {{ $t('AGENT_BOTS.FORM.BOT_CONFIG.TYPING_INDICATORS.DELAY') }}
                </label>
                <Input
                  v-model.number="formState.typingIndicatorDelay"
                  type="number"
                  step="0.1"
                  min="0.1"
                  max="5"
                  class="w-full"
                />
                <p class="text-xs text-n-slate-10 mt-1">
                  {{
                    $t(
                      'AGENT_BOTS.FORM.BOT_CONFIG.TYPING_INDICATORS.DELAY_HELP'
                    )
                  }}
                </p>
              </div>
            </div>

            <!-- Conversation Settings Section -->
            <div
              class="flex flex-col gap-3 p-4 bg-n-slate-1 dark:bg-n-slate-2 rounded-lg border border-n-weak"
            >
              <h4 class="text-sm font-medium text-n-slate-12">
                {{ $t('AGENT_BOTS.FORM.BOT_CONFIG.CONVERSATION.TITLE') }}
              </h4>

              <div>
                <label class="block text-sm font-medium text-n-slate-11 mb-1">
                  {{ $t('AGENT_BOTS.FORM.BOT_CONFIG.CONVERSATION.TIMEOUT') }}
                </label>
                <Input
                  v-model.number="formState.conversationTimeout"
                  type="number"
                  min="1"
                  max="1440"
                  class="w-full"
                />
                <p class="text-xs text-n-slate-10 mt-1">
                  {{
                    $t('AGENT_BOTS.FORM.BOT_CONFIG.CONVERSATION.TIMEOUT_HELP')
                  }}
                </p>
              </div>
            </div>

            <!-- Advanced Configuration Toggle -->
            <div class="flex flex-col gap-2">
              <button
                type="button"
                class="flex items-center gap-2 text-sm text-n-blue-11 hover:text-n-blue-12"
                @click="
                  formState.showAdvancedConfig = !formState.showAdvancedConfig
                "
              >
                <i
                  :class="
                    formState.showAdvancedConfig
                      ? 'i-lucide-chevron-down'
                      : 'i-lucide-chevron-right'
                  "
                  class="w-4 h-4"
                />
                <span>{{
                  $t('AGENT_BOTS.FORM.BOT_CONFIG.ADVANCED_CONFIG')
                }}</span>
              </button>

              <!-- Advanced JSON Editor -->
              <div
                v-if="formState.showAdvancedConfig"
                class="flex flex-col gap-2"
              >
                <p class="text-xs text-n-slate-11">
                  {{ $t('AGENT_BOTS.FORM.BOT_CONFIG.ADVANCED_CONFIG_HELP') }}
                </p>
                <textarea
                  v-model="formState.botConfig"
                  class="w-full px-3 py-2 text-sm font-mono bg-n-slate-1 dark:bg-n-slate-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8 min-h-[150px] max-h-[300px]"
                  :class="{ 'border-ruby-8': jsonError }"
                  :placeholder="$t('AGENT_BOTS.FORM.BOT_CONFIG.PLACEHOLDER')"
                  @blur="v$.botConfig.$touch()"
                />
                <p v-if="jsonError" class="text-xs text-ruby-11">
                  {{ jsonError }}
                </p>
                <div v-else class="text-xs text-n-slate-11 space-y-1">
                  <p>
                    <a
                      href="https://github.com/yourusername/chatwoot/blob/develop/docs/bot-studio/BOT_CONFIG_STORAGE_GUIDE.md"
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-n-blue-11 hover:text-n-blue-12 underline"
                    >
                      {{ $t('AGENT_BOTS.FORM.BOT_CONFIG.HELP_LINK') }}
                    </a>
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Access Token Section (outside scroll area) -->
      <div
        v-if="showAccessTokenInput"
        class="flex flex-col gap-1 pt-4 border-t border-n-weak mt-4"
      >
        <label
          v-if="type === MODAL_TYPES.EDIT"
          class="mb-0.5 text-sm font-medium text-n-slate-12"
        >
          {{ $t('AGENT_BOTS.ACCESS_TOKEN.TITLE') }}
        </label>
        <AccessToken
          v-if="type === MODAL_TYPES.EDIT"
          :value="accessToken"
          @on-copy="onCopyToken"
          @on-reset="onResetToken"
        />
        <AccessToken
          v-else
          :value="accessToken"
          :show-reset-button="false"
          @on-copy="onCopyToken"
        />
      </div>

      <!-- Sticky buttons at bottom -->
      <div
        class="flex items-center justify-end w-full gap-2 px-0 py-2 pt-4 border-t border-n-weak mt-4"
      >
        <NextButton
          faded
          slate
          type="reset"
          :label="$t('AGENT_BOTS.FORM.CANCEL')"
          @click="onClickClose()"
        />
        <NextButton
          v-if="!showAccessToken"
          type="submit"
          data-testid="label-submit"
          :label="confirmButtonLabel"
          :is-loading="isLoading"
          :disabled="v$.$invalid"
        />
      </div>
    </form>
  </Dialog>
</template>
