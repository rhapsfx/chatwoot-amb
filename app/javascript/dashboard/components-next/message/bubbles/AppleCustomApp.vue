<script setup>
import { computed, ref, onMounted } from 'vue';
import { useMessageContext } from '../provider.js';
import { useStore } from 'dashboard/composables/store';
import BaseBubble from './Base.vue';

const { contentAttributes } = useMessageContext();
const store = useStore();

const accountId = computed(() => store.getters.getCurrentAccountId);
const appData = computed(() => contentAttributes.value || {});
const appMetadata = ref(null);
const loading = ref(false);
const error = ref(false);

// Use the configured axios instance with authentication
const axios = window.axios;

// Get bundle ID from backend data
const bundleId = computed(() => {
  // Backend stores it as 'bid', but also check common alternatives and nested interactive_data
  return (
    appData.value.bid ||
    appData.value.bundle_id ||
    appData.value.bundleId ||
    appData.value.interactive_data?.bid ||
    appData.value.interactive_data?.bundleId
  );
});

// Get app name - use cached metadata first, then fallback to backend data
const appName = computed(() => {
  return appMetadata.value?.app_name || appData.value.app_name || 'Custom App';
});

// Get developer name - use cached metadata first
const developerName = computed(() => {
  return (
    appMetadata.value?.developer_name ||
    appData.value.developer_name ||
    'Developer'
  );
});

// Get app icon URL - use cached metadata first, with fallback
const appIconUrl = computed(() => {
  return (
    appMetadata.value?.app_icon_url ||
    appData.value.app_icon_url ||
    '/AppStore-1024.png'
  );
});

// Get app store URL
const appStoreUrl = computed(() => {
  return (
    appMetadata.value?.app_store_url || appData.value.app_store_url || null
  );
});

// Fetch app metadata from iTunes API via our backend proxy
const fetchAppMetadata = async () => {
  // Debug logging
  // eslint-disable-next-line no-console
  console.log('[AppleCustomApp] contentAttributes:', appData.value);
  // eslint-disable-next-line no-console
  console.log('[AppleCustomApp] bundleId:', bundleId.value);

  if (!bundleId.value || !accountId.value) {
    // eslint-disable-next-line no-console
    console.warn('[AppleCustomApp] Missing bundleId or accountId', {
      bundleId: bundleId.value,
      accountId: accountId.value,
    });
    return;
  }

  loading.value = true;
  error.value = false;

  try {
    // eslint-disable-next-line no-console
    console.log('[AppleCustomApp] Fetching metadata for:', bundleId.value);
    const response = await axios.get(
      `/api/v1/accounts/${accountId.value}/apple_messages/app_metadata`,
      {
        params: { bundle_id: bundleId.value },
      }
    );
    appMetadata.value = response.data;
    // eslint-disable-next-line no-console
    console.log('[AppleCustomApp] Fetched metadata:', appMetadata.value);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[AppleCustomApp] Failed to fetch metadata:', err);
    // Fail silently and use fallback data from contentAttributes
    error.value = true;
  } finally {
    loading.value = false;
  }
};

// Open app in App Store
const openAppStore = () => {
  if (appStoreUrl.value) {
    window.open(appStoreUrl.value, '_blank');
  }
};

onMounted(() => {
  fetchAppMetadata();
});
</script>

<template>
  <BaseBubble>
    <div
      class="apple-custom-app-bubble cursor-pointer transition-all rounded-lg overflow-hidden border border-slate-200 dark:border-slate-700"
      :class="{ 'hover:shadow-lg hover:-translate-y-0.5': appStoreUrl }"
      @click="openAppStore"
    >
      <!-- Loading State -->
      <div
        v-if="loading"
        class="flex items-center justify-center p-3 bg-slate-50 dark:bg-slate-800"
      >
        <div
          class="flex items-center space-x-2 text-slate-500 dark:text-slate-400"
        >
          <svg
            class="animate-spin h-4 w-4"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
          >
            <circle
              class="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              stroke-width="4"
            />
            <path
              class="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            />
          </svg>
          <span class="text-xs">{{
            $t('APPLE_MESSAGES.CUSTOM_APP_BUBBLE.LOADING')
          }}</span>
        </div>
      </div>

      <!-- App Content -->
      <div v-else class="bg-gradient-to-br from-blue-500 to-purple-600 p-3">
        <div class="flex items-center space-x-2">
          <!-- App Icon -->
          <img
            :src="appIconUrl"
            :alt="appName"
            class="w-10 h-10 rounded-lg shadow-md bg-white flex-shrink-0"
            @error="$event.target.src = '/AppStore-1024.png'"
          />
          <div class="flex-1 min-w-0">
            <h3 class="text-white font-semibold text-sm truncate">
              {{ appName }}
            </h3>
            <p class="text-blue-100 text-xs truncate">
              {{ developerName }}
            </p>
          </div>
          <!-- App Store Badge (only show if URL is available) -->
          <div v-if="appStoreUrl" class="flex-shrink-0">
            <svg
              class="w-5 h-5 text-white opacity-80"
              fill="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"
              />
            </svg>
          </div>
        </div>
      </div>
    </div>
  </BaseBubble>
</template>

<style scoped lang="scss">
.apple-custom-app-bubble {
  max-width: 280px;
}
</style>
