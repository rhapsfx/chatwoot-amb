<script setup>
import { reactive, computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import InvitationTemplatePicker from './InvitationTemplatePicker.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const AUDIENCE_MODES = { LABELS: 'labels', PHONES: 'phones' };

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  inboxes: useMapGetter('inboxes/getInboxes'),
};

const audienceMode = ref(AUDIENCE_MODES.LABELS);

const initialState = {
  title: '',
  inboxId: null,
  template: null,
  referenceIdPrefix: '',
  locale: '',
  scheduledAt: null,
  selectedLabels: [],
  phoneNumbers: '',
};

const state = reactive({ ...initialState });

const rules = {
  title: { required, minLength: minLength(1) },
  inboxId: { required },
  template: { required },
  scheduledAt: { required },
};

const v$ = useVuelidate(rules, state);

const isCreating = computed(() => formState.uiFlags.value.isCreating);

const currentDateTime = computed(() => {
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];

const ambInboxes = computed(() =>
  (formState.inboxes.value ?? []).filter(
    inbox => inbox.channel_type === INBOX_TYPES.APPLE_MESSAGES_FOR_BUSINESS
  )
);

const inboxOptions = computed(() =>
  mapToOptions(ambInboxes.value, 'id', 'name')
);

const audienceList = computed(() =>
  mapToOptions(formState.labels.value, 'id', 'title')
);

const getErrorMessage = (field, label) =>
  v$.value[field]?.$error ? `${label} is required` : '';

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'Title'),
  inbox: getErrorMessage('inboxId', 'Inbox'),
  template: getErrorMessage('template', 'Template'),
  scheduledAt: getErrorMessage('scheduledAt', 'Scheduled time'),
}));

const isSubmitDisabled = computed(() => v$.value.$invalid);

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const resetState = () => {
  Object.assign(state, initialState);
  audienceMode.value = AUDIENCE_MODES.LABELS;
  v$.value.$reset();
};

const handleCancel = () => emit('cancel');

const buildAudience = () => {
  if (audienceMode.value === AUDIENCE_MODES.PHONES) {
    return state.phoneNumbers
      .split('\n')
      .map(line => line.trim())
      .filter(Boolean)
      .map(phone => ({ type: 'Phone', phone }));
  }
  return state.selectedLabels.map(id => ({ id, type: 'Label' }));
};

const prepareCampaignDetails = () => ({
  title: state.title,
  message: state.template?.name ?? '',
  inbox_id: state.inboxId,
  scheduled_at: formatToUTCString(state.scheduledAt),
  audience: buildAudience(),
  template_params: {
    template_id:
      state.template?.metadata?.invitation_template_id ||
      state.template?.name ||
      '',
    locale:
      state.locale || state.template?.metadata?.invitation_locale || 'en-us',
    parameters: state.template?.metadata?.invitation_parameters || {},
  },
});

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  emit('submit', prepareCampaignDetails());
  resetState();
  handleCancel();
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      label="Title"
      placeholder="Enter campaign title"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label for="amb-inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('APPLE_MESSAGES.CAMPAIGN.FORM.SELECT_INBOX') }}
      </label>
      <ComboBox
        id="amb-inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        placeholder="Select an Apple Messages inbox"
        :message="formErrors.inbox"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label
        for="amb-template"
        class="mb-0.5 text-sm font-medium text-n-slate-12"
      >
        {{ t('APPLE_MESSAGES.CAMPAIGN.FORM.INVITATION_TEMPLATE') }}
      </label>
      <InvitationTemplatePicker
        id="amb-template"
        v-model="state.template"
        :has-error="!!formErrors.template"
        :message="formErrors.template"
      />
    </div>

    <Input
      v-model="state.referenceIdPrefix"
      label="Reference ID Prefix (optional)"
      placeholder="e.g. ORDER-"
    />

    <Input
      v-model="state.locale"
      label="Locale (optional)"
      placeholder="e.g. en-us"
    />

    <div class="flex flex-col gap-2">
      <label class="text-sm font-medium text-n-slate-12">
        {{ t('APPLE_MESSAGES.CAMPAIGN.FORM.AUDIENCE') }}
      </label>
      <div class="flex gap-2">
        <button
          type="button"
          class="px-3 py-1.5 text-sm rounded-lg border transition-colors"
          :class="
            audienceMode === 'labels'
              ? 'bg-n-blue-text text-white border-n-blue-text'
              : 'bg-n-alpha-2 text-n-slate-11 border-n-weak hover:bg-n-alpha-3'
          "
          @click="audienceMode = 'labels'"
        >
          {{ t('APPLE_MESSAGES.CAMPAIGN.FORM.LABELS') }}
        </button>
        <button
          type="button"
          class="px-3 py-1.5 text-sm rounded-lg border transition-colors"
          :class="
            audienceMode === 'phones'
              ? 'bg-n-blue-text text-white border-n-blue-text'
              : 'bg-n-alpha-2 text-n-slate-11 border-n-weak hover:bg-n-alpha-3'
          "
          @click="audienceMode = 'phones'"
        >
          {{ t('APPLE_MESSAGES.CAMPAIGN.FORM.PHONES') }}
        </button>
      </div>

      <TagMultiSelectComboBox
        v-if="audienceMode === 'labels'"
        v-model="state.selectedLabels"
        :options="audienceList"
        label="Labels"
        placeholder="Select customer labels"
        class="[&>div>button]:bg-n-alpha-black2"
      />

      <textarea
        v-else
        v-model="state.phoneNumbers"
        placeholder="One phone number per line, e.g. tel:+14155551234"
        rows="4"
        class="w-full px-3 py-2 text-sm rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak placeholder:text-n-slate-9 focus:outline-none focus:ring-2 focus:ring-n-blue-text resize-none"
      />
    </div>

    <Input
      v-model="state.scheduledAt"
      label="Scheduled time"
      type="datetime-local"
      :min="currentDateTime"
      placeholder="Select scheduled time"
      :message="formErrors.scheduledAt"
      :message-type="formErrors.scheduledAt ? 'error' : 'info'"
    />

    <div class="flex gap-3 justify-between items-center w-full">
      <Button
        variant="faded"
        color="slate"
        type="button"
        label="Cancel"
        class="w-full bg-n-alpha-2 text-n-blue-text hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        label="Create"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
