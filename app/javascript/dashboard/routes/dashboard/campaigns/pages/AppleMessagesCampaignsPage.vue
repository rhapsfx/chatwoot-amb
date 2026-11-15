<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { useStoreGetters, useMapGetter } from 'dashboard/composables/store';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CampaignList from 'dashboard/components-next/Campaigns/Pages/CampaignPage/CampaignList.vue';
import AppleMessagesCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/AppleMessagesCampaign/AppleMessagesCampaignDialog.vue';
import ConfirmDeleteCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/ConfirmDeleteCampaignDialog.vue';
import AppleMessagesCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/AppleMessagesCampaignEmptyState.vue';

const { t } = useI18n();
const getters = useStoreGetters();

const selectedCampaign = ref(null);
const [showDialog, toggleDialog] = useToggle();

const uiFlags = useMapGetter('campaigns/getUIFlags');
const isFetchingCampaigns = computed(() => uiFlags.value.isFetching);

const confirmDeleteCampaignDialogRef = ref(null);

const appleMessagesCampaigns = computed(
  () => getters['campaigns/getAppleMessagesCampaigns'].value
);

const hasNoCampaigns = computed(
  () => appleMessagesCampaigns.value?.length === 0 && !isFetchingCampaigns.value
);

const handleDelete = campaign => {
  selectedCampaign.value = campaign;
  confirmDeleteCampaignDialogRef.value.dialogRef.open();
};
</script>

<template>
  <CampaignLayout
    :header-title="t('APPLE_MESSAGES.CAMPAIGN.HEADER_TITLE')"
    :button-label="t('APPLE_MESSAGES.CAMPAIGN.BUTTON_LABEL')"
    @click="toggleDialog()"
    @close="toggleDialog(false)"
  >
    <template #action>
      <AppleMessagesCampaignDialog
        v-if="showDialog"
        @close="toggleDialog(false)"
      />
    </template>
    <div
      v-if="isFetchingCampaigns"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <CampaignList
      v-else-if="!hasNoCampaigns"
      :campaigns="appleMessagesCampaigns"
      @delete="handleDelete"
    />
    <AppleMessagesCampaignEmptyState
      v-else
      :title="t('APPLE_MESSAGES.CAMPAIGN.EMPTY_STATE_TITLE')"
      :subtitle="t('APPLE_MESSAGES.CAMPAIGN.EMPTY_STATE_SUBTITLE')"
      class="pt-14"
    />
    <ConfirmDeleteCampaignDialog
      ref="confirmDeleteCampaignDialogRef"
      :selected-campaign="selectedCampaign"
    />
  </CampaignLayout>
</template>
