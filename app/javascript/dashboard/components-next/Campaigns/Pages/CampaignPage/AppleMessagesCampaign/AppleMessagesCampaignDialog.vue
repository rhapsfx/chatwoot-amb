<script setup>
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert, useTrack } from 'dashboard/composables';
import { CAMPAIGN_TYPES } from 'shared/constants/campaign.js';
import { CAMPAIGNS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events.js';

import AppleMessagesCampaignForm from './AppleMessagesCampaignForm.vue';

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();

const addCampaign = async campaignDetails => {
  try {
    await store.dispatch('campaigns/create', campaignDetails);

    useTrack(CAMPAIGNS_EVENTS.CREATE_CAMPAIGN, {
      type: CAMPAIGN_TYPES.ONE_OFF,
    });

    useAlert('Apple Messages campaign created successfully');
  } catch (error) {
    const errorMessage =
      error?.response?.message || 'There was an error. Please try again.';
    useAlert(errorMessage);
  }
};

const handleSubmit = campaignDetails => {
  addCampaign(campaignDetails);
};

const handleClose = () => emit('close');
</script>

<template>
  <div
    class="w-[25rem] z-50 min-w-0 absolute top-10 ltr:right-0 rtl:left-0 bg-n-alpha-3 backdrop-blur-[100px] rounded-xl border border-n-weak shadow-md max-h-[80vh] overflow-y-auto"
  >
    <div class="p-6 flex flex-col gap-6">
      <h3 class="text-base font-medium text-n-slate-12 flex-shrink-0">
        {{ t('APPLE_MESSAGES.CAMPAIGN.CREATE_TITLE') }}
      </h3>
      <AppleMessagesCampaignForm @submit="handleSubmit" @cancel="handleClose" />
    </div>
  </div>
</template>
