<script>
import { useAlert } from 'dashboard/composables';
import inboxMixin from 'shared/mixins/inboxMixin';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import SettingsAccordion from 'dashboard/components-next/Settings/SettingsAccordion.vue';
import ImapSettings from '../ImapSettings.vue';
import SmtpSettings from '../SmtpSettings.vue';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TextArea from 'next/textarea/TextArea.vue';
import WhatsappReauthorize from '../channels/whatsapp/Reauthorize.vue';
import { sanitizeAllowedDomains } from 'dashboard/helper/URLHelper';

export default {
  components: {
    SettingsFieldSection,
    SettingsToggleSection,
    SettingsAccordion,
    ImapSettings,
    SmtpSettings,
    NextButton,
    TextArea,
    WhatsappReauthorize,
  },
  mixins: [inboxMixin],
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      hmacMandatory: false,
      allowMobileWebview: false,
      whatsAppInboxAPIKey: '',
      isRequestingReauthorization: false,
      isSyncingTemplates: false,
      allowedDomains: '',
      isUpdatingAllowedDomains: false,
      isSettingDefaults: false,
      // Apple Messages for Business OAuth2 and Apple Pay settings
      oauth2Providers: {
        google: { enabled: false, clientId: '', clientSecret: '' },
        linkedin: { enabled: false, clientId: '', clientSecret: '' },
        facebook: { enabled: false, clientId: '', clientSecret: '' },
      },
      paymentSettings: {
        applePayEnabled: false,
        merchantIdentifier: '',
        merchantDomain: '',
        supportedNetworks: ['visa', 'masterCard', 'amex'],
        countryCode: 'US',
        currencyCode: 'USD',
      },
      paymentProcessors: {
        stripe: { enabled: false, publishableKey: '', secretKey: '' },
        square: { enabled: false, applicationId: '', accessToken: '' },
        braintree: {
          enabled: false,
          merchantId: '',
          publicKey: '',
          privateKey: '',
        },
      },
      // iMessage Apps configuration
      imessageApps: [
        {
          id: 'app_1',
          name: 'Custom Business App',
          app_id: 'com.example.businessapp',
          bid: 'com.apple.messages.MSMessageExtensionBalloonPlugin:com.example.businessapp:extension',
          version: '1.0',
          url: '',
          description: 'Default business integration app',
          enabled: false,
          use_live_layout: true,
          app_data: {},
          images: [],
        },
      ],
      updateTimeout: null,
    };
  },
  validations: {
    whatsAppInboxAPIKey: { required },
  },
  computed: {
    isEmbeddedSignupWhatsApp() {
      return this.inbox.provider_config?.source === 'embedded_signup';
    },
    whatsappAppId() {
      return window.chatwootConfig?.whatsappAppId;
    },
    isForwardingEnabled() {
      return !!this.inbox.forwarding_enabled;
    },
  },
  watch: {
    inbox() {
      this.setDefaults();
    },
    allowMobileWebview() {
      if (!this.isSettingDefaults) this.handleMobileWebviewFlag();
    },
    hmacMandatory() {
      if (!this.isSettingDefaults && this.isAWebWidgetInbox)
        this.handleHmacFlag();
    },
  },
  mounted() {
    this.setDefaults();
  },
  methods: {
    setDefaults() {
      this.isSettingDefaults = true;
      this.hmacMandatory = this.inbox.hmac_mandatory || false;
      this.allowMobileWebview = (
        this.inbox.selected_feature_flags || []
      ).includes('allow_mobile_webview');
      this.allowedDomains = this.inbox.allowed_domains || '';

      // Load Apple Messages for Business settings
      if (this.isAnAppleMessagesForBusinessChannel) {
        // Initialize OAuth2 providers with proper structure and safe defaults
        const oauth2Data = this.inbox.oauth2_providers || {};
        this.oauth2Providers = {
          google: {
            enabled: oauth2Data.google?.enabled || false,
            clientId: oauth2Data.google?.clientId || '',
            clientSecret: oauth2Data.google?.clientSecret || '',
          },
          linkedin: {
            enabled: oauth2Data.linkedin?.enabled || false,
            clientId: oauth2Data.linkedin?.clientId || '',
            clientSecret: oauth2Data.linkedin?.clientSecret || '',
          },
          facebook: {
            enabled: oauth2Data.facebook?.enabled || false,
            clientId: oauth2Data.facebook?.clientId || '',
            clientSecret: oauth2Data.facebook?.clientSecret || '',
          },
        };

        // Initialize payment settings with safe defaults
        const paymentData = this.inbox.payment_settings || {};
        this.paymentSettings = {
          applePayEnabled: paymentData.applePayEnabled || false,
          merchantIdentifier: paymentData.merchantIdentifier || '',
          merchantDomain: paymentData.merchantDomain || '',
          supportedNetworks: paymentData.supportedNetworks || [
            'visa',
            'masterCard',
            'amex',
          ],
          countryCode: paymentData.countryCode || 'US',
          currencyCode: paymentData.currencyCode || 'USD',
        };

        // Initialize payment processors with safe defaults
        const processorsData = this.inbox.payment_processors || {};
        this.paymentProcessors = {
          stripe: {
            enabled: processorsData.stripe?.enabled || false,
            publishableKey: processorsData.stripe?.publishableKey || '',
            secretKey: processorsData.stripe?.secretKey || '',
          },
          square: {
            enabled: processorsData.square?.enabled || false,
            applicationId: processorsData.square?.applicationId || '',
            accessToken: processorsData.square?.accessToken || '',
          },
          braintree: {
            enabled: processorsData.braintree?.enabled || false,
            merchantId: processorsData.braintree?.merchantId || '',
            publicKey: processorsData.braintree?.publicKey || '',
            privateKey: processorsData.braintree?.privateKey || '',
          },
        };

        // Initialize iMessage apps with safe defaults (mimic payment processors pattern)
        const imessageAppsData = this.inbox.imessage_apps || [];

        this.imessageApps =
          imessageAppsData.length > 0
            ? imessageAppsData
            : [
                {
                  id: 'app_1',
                  name: 'Custom Business App',
                  app_id: 'com.example.businessapp',
                  bid: 'com.apple.messages.MSMessageExtensionBalloonPlugin:com.example.businessapp:extension',
                  version: '1.0',
                  url: '',
                  description: 'Default business integration app',
                  enabled: false,
                  use_live_layout: true,
                  app_data: {},
                  images: [],
                },
              ];
      }

      this.$nextTick(() => {
        this.isSettingDefaults = false;
      });
    },
    handleHmacFlag() {
      this.updateInbox();
    },
    async updateInbox() {
      try {
        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {
            hmac_mandatory: this.hmacMandatory,
          },
        };
        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      }
    },
    async handleMobileWebviewFlag() {
      try {
        const currentFlags = this.inbox.selected_feature_flags || [];
        const selectedFlags = this.allowMobileWebview
          ? [...currentFlags, 'allow_mobile_webview']
          : currentFlags.filter(f => f !== 'allow_mobile_webview');

        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {
            selected_feature_flags: selectedFlags,
          },
        };
        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      }
    },
    async updateAllowedDomains() {
      this.isUpdatingAllowedDomains = true;
      const sanitizedAllowedDomains = sanitizeAllowedDomains(
        this.allowedDomains
      );
      try {
        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {
            allowed_domains: sanitizedAllowedDomains,
          },
        };
        await this.$store.dispatch('inboxes/updateInbox', payload);
        this.allowedDomains = sanitizedAllowedDomains;
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      } finally {
        this.isUpdatingAllowedDomains = false;
      }
    },
    async updateWhatsAppInboxAPIKey() {
      try {
        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {},
        };

        payload.channel.provider_config = {
          ...this.inbox.provider_config,
          api_key: this.whatsAppInboxAPIKey,
        };

        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      }
    },
    async handleReconfigure() {
      if (this.$refs.whatsappReauth) {
        await this.$refs.whatsappReauth.requestAuthorization();
      }
    },
    async syncTemplates() {
      this.isSyncingTemplates = true;
      try {
        await this.$store.dispatch('inboxes/syncTemplates', this.inbox.id);
        useAlert(
          this.$t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_TEMPLATES_SYNC_SUCCESS')
        );
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      } finally {
        this.isSyncingTemplates = false;
      }
    },
    async updateAppleMessagesSettings() {
      try {
        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {
            oauth2_providers: this.oauth2Providers,
            payment_settings: this.paymentSettings,
            payment_processors: this.paymentProcessors,
            imessage_apps: this.imessageApps,
          },
        };

        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      }
    },

    // iMessage Apps Management
    addImessageApp() {
      const newApp = {
        id: `app_${Date.now()}`,
        name: '',
        app_id: '',
        bid: '',
        version: '1.0',
        url: '',
        description: '',
        enabled: false,
        use_live_layout: true,
        app_data: {},
        images: [],
      };
      this.imessageApps.push(newApp);
      this.updateAppleMessagesSettings();
    },

    removeImessageApp(index) {
      if (this.imessageApps.length > 1) {
        this.imessageApps.splice(index, 1);
        this.updateAppleMessagesSettings();
      }
    },
  },
};
</script>

<template>
  <div v-if="isATwilioChannel">
    <SettingsFieldSection
      :label="$t('INBOX_MGMT.ADD.TWILIO.API_CALLBACK.TITLE')"
      :help-text="$t('INBOX_MGMT.ADD.TWILIO.API_CALLBACK.SUBTITLE')"
    >
      <woot-code :script="inbox.callback_webhook_url" lang="html" />
    </SettingsFieldSection>
    <SettingsFieldSection
      v-if="isATwilioWhatsAppChannel"
      :label="$t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_TEMPLATES_SYNC_TITLE')"
      :help-text="
        $t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_TEMPLATES_SYNC_SUBHEADER')
      "
    >
      <NextButton :disabled="isSyncingTemplates" @click="syncTemplates">
        {{ $t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_TEMPLATES_SYNC_BUTTON') }}
      </NextButton>
    </SettingsFieldSection>
  </div>

  <div v-else-if="isALineChannel">
    <SettingsFieldSection
      :label="$t('INBOX_MGMT.ADD.LINE_CHANNEL.API_CALLBACK.TITLE')"
      :help-text="$t('INBOX_MGMT.ADD.LINE_CHANNEL.API_CALLBACK.SUBTITLE')"
    >
      <woot-code :script="inbox.callback_webhook_url" lang="html" />
    </SettingsFieldSection>
  </div>
  <div v-else-if="isAWebWidgetInbox">
    <div class="space-y-4">
      <SettingsToggleSection
        :header="$t('INBOX_MGMT.SETTINGS_POPUP.ALLOWED_DOMAINS.TITLE')"
        :description="
          $t('INBOX_MGMT.SETTINGS_POPUP.ALLOWED_DOMAINS.DESCRIPTION')
        "
        hide-toggle
      >
        <template #editor>
          <TextArea
            v-model="allowedDomains"
            :placeholder="
              $t('INBOX_MGMT.SETTINGS_POPUP.ALLOWED_DOMAINS.PLACEHOLDER')
            "
            auto-height
            resize
            class="w-full [&>div]:!bg-transparent [&>div]:!border-none [&>div]:!border-0 [&>div]:px-0 [&>div]:pb-0 [&>div]:pt-0"
          />
          <div class="mt-3 flex justify-end">
            <NextButton
              :label="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
              :is-loading="isUpdatingAllowedDomains"
              @click="updateAllowedDomains"
            />
          </div>
        </template>
      </SettingsToggleSection>
      <SettingsToggleSection
        v-model="allowMobileWebview"
        :header="$t('INBOX_MGMT.SETTINGS_POPUP.ALLOW_MOBILE_WEBVIEW.LABEL')"
        :description="
          $t('INBOX_MGMT.SETTINGS_POPUP.ALLOW_MOBILE_WEBVIEW.SUBTITLE')
        "
      />
    </div>

    <SettingsAccordion
      :title="$t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.TITLE')"
      class="mt-6"
    >
      <SettingsToggleSection
        :header="$t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.TITLE')"
        :description="
          $t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.DESCRIPTION')
        "
        hide-toggle
      >
        <template #editor>
          <p class="mb-1 text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.SECRET_KEY') }}
          </p>
          <woot-code :script="inbox.hmac_token" />
          <p class="mt-1.5 text-label-small text-n-slate-11">
            {{ $t('INBOX_MGMT.SETTINGS_POPUP.HMAC_DESCRIPTION') }}
            <a
              target="_blank"
              rel="noopener noreferrer"
              href="https://www.chatwoot.com/docs/product/channels/live-chat/sdk/identity-validation/"
              class="text-n-blue-11 hover:underline text-label-small"
            >
              {{
                $t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.VIEW_DOCS')
              }}
            </a>
          </p>
        </template>
      </SettingsToggleSection>

      <SettingsToggleSection
        v-model="hmacMandatory"
        :header="
          $t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.REQUIRE_LABEL')
        "
        :description="
          $t(
            'INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.REQUIRE_DESCRIPTION'
          )
        "
      />
    </SettingsAccordion>
  </div>
  <div v-else-if="isAPIInbox">
    <SettingsFieldSection
      :label="$t('INBOX_MGMT.SETTINGS_POPUP.INBOX_IDENTIFIER')"
      :help-text="$t('INBOX_MGMT.SETTINGS_POPUP.INBOX_IDENTIFIER_SUB_TEXT')"
    >
      <woot-code :script="inbox.inbox_identifier" />
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="$t('INBOX_MGMT.SETTINGS_POPUP.HMAC_VERIFICATION')"
      :help-text="$t('INBOX_MGMT.SETTINGS_POPUP.HMAC_DESCRIPTION')"
    >
      <woot-code :script="inbox.hmac_token" />
    </SettingsFieldSection>
    <SettingsFieldSection
      :label="$t('INBOX_MGMT.SETTINGS_POPUP.HMAC_MANDATORY_VERIFICATION')"
      :help-text="$t('INBOX_MGMT.SETTINGS_POPUP.HMAC_MANDATORY_DESCRIPTION')"
    >
      <div class="flex gap-2 items-center">
        <input
          id="hmacMandatory"
          v-model="hmacMandatory"
          type="checkbox"
          @change="handleHmacFlag"
        />
        <label for="hmacMandatory" class="text-body-main text-n-slate-12">
          {{ $t('INBOX_MGMT.EDIT.ENABLE_HMAC.LABEL') }}
        </label>
      </div>
    </SettingsFieldSection>
  </div>
  <div v-else-if="isAnEmailChannel">
    <div>
      <SettingsFieldSection
        :label="$t('INBOX_MGMT.SETTINGS_POPUP.FORWARD_EMAIL_TITLE')"
        :help-text="
          isForwardingEnabled
            ? $t('INBOX_MGMT.SETTINGS_POPUP.FORWARD_EMAIL_SUB_TEXT')
            : ''
        "
      >
        <woot-code
          v-if="isForwardingEnabled"
          :script="inbox.forward_to_email"
        />
        <div
          v-else
          class="py-2 px-3 bg-n-amber-3 outline-n-amber-4 text-n-amber-11 outline outline-1 -outline-offset-1 rounded-xl"
        >
          <p class="text-body-para mb-0">
            {{ $t('INBOX_MGMT.SETTINGS_POPUP.FORWARD_EMAIL_NOT_CONFIGURED') }}
          </p>
        </div>
      </SettingsFieldSection>
    </div>
    <ImapSettings :inbox="inbox" />
    <SmtpSettings v-if="inbox.imap_enabled" :inbox="inbox" />
  </div>
  <div v-else-if="isAWhatsAppChannel && !isATwilioChannel">
    <div v-if="inbox.provider_config">
      <!-- Embedded Signup Section -->
      <template v-if="isEmbeddedSignupWhatsApp">
        <SettingsFieldSection
          v-if="whatsappAppId"
          :label="
            $t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_EMBEDDED_SIGNUP_TITLE')
          "
          :help-text="`${$t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_EMBEDDED_SIGNUP_SUBHEADER')} ${$t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_EMBEDDED_SIGNUP_DESCRIPTION')}`"
        >
          <div class="flex flex-col gap-1 items-start">
            <NextButton @click="handleReconfigure">
              {{ $t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_RECONFIGURE_BUTTON') }}
            </NextButton>
          </div>
        </SettingsFieldSection>
      </template>

      <!-- Manual Setup Section -->
      <template v-else>
        <SettingsFieldSection
          :label="$t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_WEBHOOK_TITLE')"
          :help-text="
            $t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_WEBHOOK_SUBHEADER')
          "
        >
          <woot-code :script="inbox.provider_config.webhook_verify_token" />
        </SettingsFieldSection>
        <SettingsFieldSection
          :label="$t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_SECTION_TITLE')"
          :help-text="
            $t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_SECTION_SUBHEADER')
          "
        >
          <woot-code :script="inbox.provider_config.api_key" />
        </SettingsFieldSection>
        <SettingsFieldSection
          :label="$t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_SECTION_UPDATE_TITLE')"
          :help-text="
            $t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_SECTION_UPDATE_SUBHEADER')
          "
        >
          <div
            class="flex flex-1 justify-between items-center whatsapp-settings--content"
          >
            <woot-input
              v-model="whatsAppInboxAPIKey"
              type="text"
              class="flex-1 mr-2 [&>input]:!mb-0"
              :placeholder="
                $t(
                  'INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_SECTION_UPDATE_PLACEHOLDER'
                )
              "
            />
            <NextButton
              :disabled="v$.whatsAppInboxAPIKey.$invalid"
              @click="updateWhatsAppInboxAPIKey"
            >
              {{
                $t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_SECTION_UPDATE_BUTTON')
              }}
            </NextButton>
          </div>
        </SettingsFieldSection>
      </template>
      <SettingsFieldSection
        :label="$t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_TEMPLATES_SYNC_TITLE')"
        :help-text="
          $t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_TEMPLATES_SYNC_SUBHEADER')
        "
      >
        <NextButton :disabled="isSyncingTemplates" @click="syncTemplates">
          {{ $t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_TEMPLATES_SYNC_BUTTON') }}
        </NextButton>
      </SettingsFieldSection>
    </div>
    <WhatsappReauthorize
      v-if="isEmbeddedSignupWhatsApp"
      ref="whatsappReauth"
      :inbox="inbox"
      class="hidden"
    />
  </div>
  <div v-else-if="isAnAppleMessagesForBusinessChannel">
    <SettingsFieldSection
      :label="$t('INBOX_MGMT.SETTINGS_POPUP.APPLE_MESSAGES_MSP_TITLE')"
      :help-text="$t('INBOX_MGMT.SETTINGS_POPUP.APPLE_MESSAGES_MSP_SUBTITLE')"
    >
      <woot-code :script="inbox.msp_id" />
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="$t('INBOX_MGMT.SETTINGS_POPUP.APPLE_MESSAGES_BUSINESS_ID_TITLE')"
      :help-text="
        $t('INBOX_MGMT.SETTINGS_POPUP.APPLE_MESSAGES_BUSINESS_ID_SUBTITLE')
      "
    >
      <woot-code :script="inbox.business_id" />
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="$t('INBOX_MGMT.SETTINGS_POPUP.APPLE_MESSAGES_WEBHOOK_TITLE')"
      :help-text="
        $t('INBOX_MGMT.SETTINGS_POPUP.APPLE_MESSAGES_WEBHOOK_SUBTITLE')
      "
    >
      <woot-code :script="inbox.webhook_url" />
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="$t('INBOX_MGMT.SETTINGS_POPUP.APPLE_MESSAGES_SECRET_TITLE')"
      :help-text="
        $t('INBOX_MGMT.SETTINGS_POPUP.APPLE_MESSAGES_SECRET_SUBTITLE')
      "
    >
      <woot-code :script="inbox.secret" />
    </SettingsFieldSection>

    <!-- OAuth2 Authentication Settings -->
    <SettingsFieldSection
      :label="$t('INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.OAUTH2.TITLE')"
      :help-text="$t('INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.OAUTH2.DESC')"
    >
      <div class="space-y-6">
        <!-- Google OAuth2 -->
        <div class="bg-n-solid-2 p-4 rounded-lg">
          <div class="flex items-center space-x-3 mb-4">
            <input
              id="google-oauth-enabled"
              v-model="oauth2Providers.google.enabled"
              type="checkbox"
              class="h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              @change="updateAppleMessagesSettings"
            />
            <label
              for="google-oauth-enabled"
              class="text-sm font-medium text-gray-900"
            >
              {{
                $t(
                  'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.OAUTH2.GOOGLE_ENABLED'
                )
              }}
            </label>
          </div>
          <div
            v-if="oauth2Providers.google?.enabled"
            class="grid grid-cols-1 md:grid-cols-2 gap-4"
          >
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{
                  $t(
                    'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.OAUTH2.CLIENT_ID'
                  )
                }}
              </label>
              <input
                v-model="oauth2Providers.google.clientId"
                type="text"
                :placeholder="
                  $t('INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.GOOGLE_CLIENT_ID')
                "
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                @blur="updateAppleMessagesSettings"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{
                  $t(
                    'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.OAUTH2.CLIENT_SECRET'
                  )
                }}
              </label>
              <input
                v-model="oauth2Providers.google.clientSecret"
                type="password"
                :placeholder="
                  $t(
                    'INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.GOOGLE_CLIENT_SECRET'
                  )
                "
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                @blur="updateAppleMessagesSettings"
              />
            </div>
          </div>
        </div>

        <!-- LinkedIn OAuth2 -->
        <div class="bg-n-solid-2 p-4 rounded-lg">
          <div class="flex items-center space-x-3 mb-4">
            <input
              id="linkedin-oauth-enabled"
              v-model="oauth2Providers.linkedin.enabled"
              type="checkbox"
              class="h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              @change="updateAppleMessagesSettings"
            />
            <label
              for="linkedin-oauth-enabled"
              class="text-sm font-medium text-gray-900"
            >
              {{
                $t(
                  'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.OAUTH2.LINKEDIN_ENABLED'
                )
              }}
            </label>
          </div>
          <div
            v-if="oauth2Providers.linkedin?.enabled"
            class="grid grid-cols-1 md:grid-cols-2 gap-4"
          >
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{
                  $t(
                    'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.OAUTH2.CLIENT_ID'
                  )
                }}
              </label>
              <input
                v-model="oauth2Providers.linkedin.clientId"
                type="text"
                :placeholder="
                  $t(
                    'INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.LINKEDIN_CLIENT_ID'
                  )
                "
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                @blur="updateAppleMessagesSettings"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{
                  $t(
                    'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.OAUTH2.CLIENT_SECRET'
                  )
                }}
              </label>
              <input
                v-model="oauth2Providers.linkedin.clientSecret"
                type="password"
                :placeholder="
                  $t(
                    'INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.LINKEDIN_CLIENT_SECRET'
                  )
                "
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                @blur="updateAppleMessagesSettings"
              />
            </div>
          </div>
        </div>

        <!-- Facebook OAuth2 -->
        <div class="bg-n-solid-2 p-4 rounded-lg">
          <div class="flex items-center space-x-3 mb-4">
            <input
              id="facebook-oauth-enabled"
              v-model="oauth2Providers.facebook.enabled"
              type="checkbox"
              class="h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              @change="updateAppleMessagesSettings"
            />
            <label
              for="facebook-oauth-enabled"
              class="text-sm font-medium text-gray-900"
            >
              {{
                $t(
                  'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.OAUTH2.FACEBOOK_ENABLED'
                )
              }}
            </label>
          </div>
          <div
            v-if="oauth2Providers.facebook?.enabled"
            class="grid grid-cols-1 md:grid-cols-2 gap-4"
          >
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{
                  $t(
                    'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.OAUTH2.CLIENT_ID'
                  )
                }}
              </label>
              <input
                v-model="oauth2Providers.facebook.clientId"
                type="text"
                :placeholder="
                  $t('INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.FACEBOOK_APP_ID')
                "
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                @blur="updateAppleMessagesSettings"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{
                  $t(
                    'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.OAUTH2.CLIENT_SECRET'
                  )
                }}
              </label>
              <input
                v-model="oauth2Providers.facebook.clientSecret"
                type="password"
                :placeholder="
                  $t(
                    'INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.FACEBOOK_APP_SECRET'
                  )
                "
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                @blur="updateAppleMessagesSettings"
              />
            </div>
          </div>
        </div>
      </div>
    </SettingsFieldSection>

    <!-- Apple Pay Settings -->
    <SettingsFieldSection
      :label="$t('INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.APPLE_PAY.TITLE')"
      :help-text="
        $t('INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.APPLE_PAY.DESC')
      "
    >
      <div class="space-y-6">
        <div class="bg-n-solid-2 p-4 rounded-lg">
          <div class="flex items-center space-x-3 mb-4">
            <input
              id="apple-pay-enabled"
              v-model="paymentSettings.applePayEnabled"
              type="checkbox"
              class="h-4 w-4 text-green-600 border-gray-300 rounded focus:ring-green-500"
              @change="updateAppleMessagesSettings"
            />
            <label
              for="apple-pay-enabled"
              class="text-sm font-medium text-gray-900"
            >
              {{
                $t(
                  'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.APPLE_PAY.ENABLED'
                )
              }}
            </label>
          </div>

          <div v-if="paymentSettings.applePayEnabled" class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{
                    $t(
                      'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.APPLE_PAY.MERCHANT_IDENTIFIER'
                    )
                  }}
                </label>
                <input
                  v-model="paymentSettings.merchantIdentifier"
                  type="text"
                  :placeholder="
                    $t(
                      'INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.MERCHANT_IDENTIFIER'
                    )
                  "
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500"
                  @blur="updateAppleMessagesSettings"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{
                    $t(
                      'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.APPLE_PAY.MERCHANT_DOMAIN'
                    )
                  }}
                </label>
                <input
                  v-model="paymentSettings.merchantDomain"
                  type="text"
                  :placeholder="
                    $t('INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.MERCHANT_DOMAIN')
                  "
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500"
                  @blur="updateAppleMessagesSettings"
                />
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{
                    $t(
                      'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.APPLE_PAY.COUNTRY_CODE'
                    )
                  }}
                </label>
                <select
                  v-model="paymentSettings.countryCode"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500"
                  @change="updateAppleMessagesSettings"
                >
                  <option value="US">
                    {{ $t('INBOX_MGMT.SETTINGS_POPUP.COUNTRIES.US') }}
                  </option>
                  <option value="CA">
                    {{ $t('INBOX_MGMT.SETTINGS_POPUP.COUNTRIES.CA') }}
                  </option>
                  <option value="GB">
                    {{ $t('INBOX_MGMT.SETTINGS_POPUP.COUNTRIES.GB') }}
                  </option>
                  <option value="AU">
                    {{ $t('INBOX_MGMT.SETTINGS_POPUP.COUNTRIES.AU') }}
                  </option>
                  <option value="JP">
                    {{ $t('INBOX_MGMT.SETTINGS_POPUP.COUNTRIES.JP') }}
                  </option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{
                    $t(
                      'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.APPLE_PAY.CURRENCY_CODE'
                    )
                  }}
                </label>
                <select
                  v-model="paymentSettings.currencyCode"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500"
                  @change="updateAppleMessagesSettings"
                >
                  <option value="USD">
                    {{ $t('INBOX_MGMT.SETTINGS_POPUP.CURRENCIES.USD') }}
                  </option>
                  <option value="CAD">
                    {{ $t('INBOX_MGMT.SETTINGS_POPUP.CURRENCIES.CAD') }}
                  </option>
                  <option value="GBP">
                    {{ $t('INBOX_MGMT.SETTINGS_POPUP.CURRENCIES.GBP') }}
                  </option>
                  <option value="AUD">
                    {{ $t('INBOX_MGMT.SETTINGS_POPUP.CURRENCIES.AUD') }}
                  </option>
                  <option value="JPY">
                    {{ $t('INBOX_MGMT.SETTINGS_POPUP.CURRENCIES.JPY') }}
                  </option>
                </select>
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                {{
                  $t(
                    'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.APPLE_PAY.SUPPORTED_NETWORKS'
                  )
                }}
              </label>
              <div class="flex flex-wrap gap-3">
                <label class="flex items-center">
                  <input
                    v-model="paymentSettings.supportedNetworks"
                    type="checkbox"
                    value="visa"
                    class="mr-2 h-4 w-4 text-green-600 border-gray-300 rounded focus:ring-green-500"
                    @change="updateAppleMessagesSettings"
                  />
                  {{ $t('INBOX_MGMT.SETTINGS_POPUP.PAYMENT_NETWORKS.VISA') }}
                </label>
                <label class="flex items-center">
                  <input
                    v-model="paymentSettings.supportedNetworks"
                    type="checkbox"
                    value="masterCard"
                    class="mr-2 h-4 w-4 text-green-600 border-gray-300 rounded focus:ring-green-500"
                    @change="updateAppleMessagesSettings"
                  />
                  {{
                    $t('INBOX_MGMT.SETTINGS_POPUP.PAYMENT_NETWORKS.MASTERCARD')
                  }}
                </label>
                <label class="flex items-center">
                  <input
                    v-model="paymentSettings.supportedNetworks"
                    type="checkbox"
                    value="amex"
                    class="mr-2 h-4 w-4 text-green-600 border-gray-300 rounded focus:ring-green-500"
                    @change="updateAppleMessagesSettings"
                  />
                  {{ $t('INBOX_MGMT.SETTINGS_POPUP.PAYMENT_NETWORKS.AMEX') }}
                </label>
                <label class="flex items-center">
                  <input
                    v-model="paymentSettings.supportedNetworks"
                    type="checkbox"
                    value="discover"
                    class="mr-2 h-4 w-4 text-green-600 border-gray-300 rounded focus:ring-green-500"
                    @change="updateAppleMessagesSettings"
                  />
                  {{
                    $t('INBOX_MGMT.SETTINGS_POPUP.PAYMENT_NETWORKS.DISCOVER')
                  }}
                </label>
              </div>
            </div>
          </div>
        </div>
      </div>
    </SettingsFieldSection>

    <!-- Payment Processors -->
    <SettingsFieldSection
      v-if="paymentSettings.applePayEnabled"
      :label="
        $t(
          'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.PAYMENT_PROCESSORS.TITLE'
        )
      "
      :help-text="
        $t('INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.PAYMENT_PROCESSORS.DESC')
      "
    >
      <div class="space-y-6">
        <!-- Stripe -->
        <div class="bg-n-solid-2 p-4 rounded-lg">
          <div class="flex items-center space-x-3 mb-4">
            <input
              id="stripe-enabled"
              v-model="paymentProcessors.stripe.enabled"
              type="checkbox"
              class="h-4 w-4 text-purple-600 border-gray-300 rounded focus:ring-purple-500"
              @change="updateAppleMessagesSettings"
            />
            <label
              for="stripe-enabled"
              class="text-sm font-medium text-gray-900"
            >
              {{
                $t(
                  'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.PAYMENT_PROCESSORS.STRIPE_ENABLED'
                )
              }}
            </label>
          </div>
          <div
            v-if="paymentProcessors.stripe?.enabled"
            class="grid grid-cols-1 md:grid-cols-2 gap-4"
          >
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{
                  $t(
                    'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.PAYMENT_PROCESSORS.PUBLISHABLE_KEY'
                  )
                }}
              </label>
              <input
                v-model="paymentProcessors.stripe.publishableKey"
                type="text"
                :placeholder="
                  $t(
                    'INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.STRIPE_PUBLISHABLE_KEY'
                  )
                "
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
                @blur="updateAppleMessagesSettings"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{
                  $t(
                    'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.PAYMENT_PROCESSORS.SECRET_KEY'
                  )
                }}
              </label>
              <input
                v-model="paymentProcessors.stripe.secretKey"
                type="password"
                :placeholder="
                  $t('INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.STRIPE_SECRET_KEY')
                "
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
                @blur="updateAppleMessagesSettings"
              />
            </div>
          </div>
        </div>

        <!-- Square -->
        <div class="bg-n-solid-2 p-4 rounded-lg">
          <div class="flex items-center space-x-3 mb-4">
            <input
              id="square-enabled"
              v-model="paymentProcessors.square.enabled"
              type="checkbox"
              class="h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              @change="updateAppleMessagesSettings"
            />
            <label
              for="square-enabled"
              class="text-sm font-medium text-gray-900"
            >
              {{
                $t(
                  'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.PAYMENT_PROCESSORS.SQUARE_ENABLED'
                )
              }}
            </label>
          </div>
          <div
            v-if="paymentProcessors.square?.enabled"
            class="grid grid-cols-1 md:grid-cols-2 gap-4"
          >
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{
                  $t(
                    'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.PAYMENT_PROCESSORS.APPLICATION_ID'
                  )
                }}
              </label>
              <input
                v-model="paymentProcessors.square.applicationId"
                type="text"
                :placeholder="
                  $t(
                    'INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.SQUARE_APPLICATION_ID'
                  )
                "
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                @blur="updateAppleMessagesSettings"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{
                  $t(
                    'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.PAYMENT_PROCESSORS.ACCESS_TOKEN'
                  )
                }}
              </label>
              <input
                v-model="paymentProcessors.square.accessToken"
                type="password"
                :placeholder="
                  $t(
                    'INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.SQUARE_ACCESS_TOKEN'
                  )
                "
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                @blur="updateAppleMessagesSettings"
              />
            </div>
          </div>
        </div>

        <!-- Braintree -->
        <div class="bg-n-solid-2 p-4 rounded-lg">
          <div class="flex items-center space-x-3 mb-4">
            <input
              id="braintree-enabled"
              v-model="paymentProcessors.braintree.enabled"
              type="checkbox"
              class="h-4 w-4 text-yellow-600 border-gray-300 rounded focus:ring-yellow-500"
              @change="updateAppleMessagesSettings"
            />
            <label
              for="braintree-enabled"
              class="text-sm font-medium text-gray-900"
            >
              {{
                $t(
                  'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.PAYMENT_PROCESSORS.BRAINTREE_ENABLED'
                )
              }}
            </label>
          </div>
          <div
            v-if="paymentProcessors.braintree?.enabled"
            class="grid grid-cols-1 md:grid-cols-3 gap-4"
          >
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{
                  $t(
                    'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.PAYMENT_PROCESSORS.MERCHANT_ID'
                  )
                }}
              </label>
              <input
                v-model="paymentProcessors.braintree.merchantId"
                type="text"
                :placeholder="
                  $t(
                    'INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.BRAINTREE_MERCHANT_ID'
                  )
                "
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-yellow-500"
                @blur="updateAppleMessagesSettings"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{
                  $t(
                    'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.PAYMENT_PROCESSORS.PUBLIC_KEY'
                  )
                }}
              </label>
              <input
                v-model="paymentProcessors.braintree.publicKey"
                type="text"
                :placeholder="
                  $t(
                    'INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.BRAINTREE_PUBLIC_KEY'
                  )
                "
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-yellow-500"
                @blur="updateAppleMessagesSettings"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{
                  $t(
                    'INBOX_MGMT.ADD.APPLE_MESSAGES_FOR_BUSINESS.PAYMENT_PROCESSORS.PRIVATE_KEY'
                  )
                }}
              </label>
              <input
                v-model="paymentProcessors.braintree.privateKey"
                type="password"
                :placeholder="
                  $t(
                    'INBOX_MGMT.SETTINGS_POPUP.PLACEHOLDERS.BRAINTREE_PRIVATE_KEY'
                  )
                "
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-yellow-500"
                @blur="updateAppleMessagesSettings"
              />
            </div>
          </div>
        </div>
      </div>
    </SettingsFieldSection>

    <!-- iMessage Apps Configuration -->
    <SettingsFieldSection
      :label="$t('INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.TITLE')"
      :help-text="$t('INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.SUBTITLE')"
    >
      <div class="space-y-6">
        <!-- Apps List -->
        <div class="space-y-4">
          <div
            v-for="(app, index) in imessageApps"
            :key="app.id"
            class="bg-n-solid-2 p-4 rounded-lg border border-n-weak"
          >
            <div class="flex items-center justify-between mb-4">
              <div class="flex items-center space-x-3">
                <input
                  v-model="app.enabled"
                  type="checkbox"
                  class="h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                  @change="updateAppleMessagesSettings"
                />
                <h4 class="font-medium text-gray-900">
                  {{ app.name || `iMessage App ${index + 1}` }}
                </h4>
              </div>
              <button
                v-if="imessageApps.length > 1"
                class="text-red-500 hover:text-red-700 transition-colors"
                @click="removeImessageApp(index)"
              >
                <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <path
                    d="M19,6.41L17.59,5L12,10.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L12,13.41L17.59,19L19,17.59L13.41,12L19,6.41Z"
                  />
                </svg>
              </button>
            </div>

            <div
              v-if="app.enabled"
              class="grid grid-cols-1 md:grid-cols-2 gap-4"
            >
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{ $t('INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.APP_NAME') }}
                </label>
                <input
                  v-model="app.name"
                  type="text"
                  :placeholder="
                    $t(
                      'INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.PLACEHOLDER.APP_NAME'
                    )
                  "
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  @blur="updateAppleMessagesSettings"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{ $t('INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.APP_ID') }}
                </label>
                <input
                  v-model="app.app_id"
                  type="text"
                  :placeholder="
                    $t(
                      'INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.PLACEHOLDER.APP_ID'
                    )
                  "
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  @blur="updateAppleMessagesSettings"
                />
              </div>

              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{ $t('INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.BUNDLE_ID') }}
                </label>
                <input
                  v-model="app.bid"
                  type="text"
                  :placeholder="
                    $t(
                      'INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.PLACEHOLDER.BUNDLE_ID'
                    )
                  "
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  @blur="updateAppleMessagesSettings"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{ $t('INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.VERSION') }}
                </label>
                <input
                  v-model="app.version"
                  type="text"
                  :placeholder="
                    $t(
                      'INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.PLACEHOLDER.VERSION'
                    )
                  "
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  @blur="updateAppleMessagesSettings"
                />
              </div>

              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{ $t('INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.APP_URL') }}
                </label>
                <input
                  v-model="app.url"
                  type="url"
                  :placeholder="
                    $t(
                      'INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.PLACEHOLDER.APP_URL'
                    )
                  "
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  @blur="updateAppleMessagesSettings"
                />
              </div>

              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{
                    $t('INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.DESCRIPTION')
                  }}
                </label>
                <textarea
                  v-model="app.description"
                  rows="2"
                  :placeholder="
                    $t(
                      'INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.PLACEHOLDER.DESCRIPTION'
                    )
                  "
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  @blur="updateAppleMessagesSettings"
                />
              </div>

              <div class="md:col-span-2">
                <div class="flex items-center space-x-3">
                  <input
                    v-model="app.use_live_layout"
                    type="checkbox"
                    class="h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                    @blur="updateAppleMessagesSettings"
                  />
                  <label class="text-sm text-gray-700">
                    {{
                      $t(
                        'INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.USE_LIVE_LAYOUT'
                      )
                    }}
                  </label>
                </div>
                <p class="text-xs text-gray-500 mt-1">
                  {{
                    $t(
                      'INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.USE_LIVE_LAYOUT_HELP'
                    )
                  }}
                </p>
              </div>
            </div>
          </div>
        </div>

        <!-- Add New App Button -->
        <button
          type="button"
          class="w-full py-3 border-2 border-dashed border-gray-300 rounded-lg text-gray-500 hover:border-gray-400 hover:text-gray-600 transition-colors"
          @click="addImessageApp"
        >
          {{ $t('INBOX_MGMT.SETTINGS_POPUP.IMESSAGE_APPS.ADD_APP') }}
        </button>
      </div>
    </SettingsFieldSection>
  </div>
</template>

<style lang="scss" scoped>
.whatsapp-settings--content {
  :deep(input) {
    margin-bottom: 0;
  }
}
</style>
