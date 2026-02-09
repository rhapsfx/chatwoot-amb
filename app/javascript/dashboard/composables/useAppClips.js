import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import ConstructPayloadAPI from 'dashboard/api/appleMessages/constructPayload';

/**
 * Composable for App Clips functionality via Construct Payload API
 *
 * Provides state management and methods for generating App Clips rich links.
 *
 * @param {number} inboxId - Inbox ID (can be computed ref)
 * @returns {Object} - App Clips state and methods
 */
export function useAppClips(inboxId) {
  const store = useStore();

  // State
  const isGenerating = ref(false);
  const appClipsError = ref(null);
  const richLinkDataRef = ref(null);
  const selectedStoreRegion = ref('US');

  // Computed
  const accountId = computed(() => store.getters.getCurrentAccountId);

  // Store regions (ISO 3166 alpha-2 codes)
  const storeRegions = [
    { code: 'US', name: 'United States' },
    { code: 'GB', name: 'United Kingdom' },
    { code: 'CA', name: 'Canada' },
    { code: 'AU', name: 'Australia' },
    { code: 'DE', name: 'Germany' },
    { code: 'FR', name: 'France' },
    { code: 'JP', name: 'Japan' },
    { code: 'CN', name: 'China' },
    { code: 'IN', name: 'India' },
    { code: 'BR', name: 'Brazil' },
  ];

  /**
   * Generate App Clips rich link from URL
   *
   * Calls Apple MSP Gateway via backend API to get richLinkDataRef.
   *
   * @param {string} url - HTTPS URL for App Clips
   * @returns {Promise<Object>} - { success: boolean, richLinkDataRef?: Object, error?: string }
   */
  const generateAppClips = async url => {
    // Client-side validation
    if (!url) {
      appClipsError.value = 'Please enter a URL';
      return { success: false };
    }

    if (!ConstructPayloadAPI.mightSupportAppClips(url)) {
      appClipsError.value = 'URL must be HTTPS and have a valid domain';
      return { success: false };
    }

    // Reset state
    isGenerating.value = true;
    appClipsError.value = null;
    richLinkDataRef.value = null;

    try {
      const result = await ConstructPayloadAPI.create(
        accountId.value,
        inboxId.value,
        {
          url,
          storeRegion: selectedStoreRegion.value,
        }
      );

      if (result.success) {
        richLinkDataRef.value = result.rich_link_data_ref;
        return {
          success: true,
          richLinkDataRef: result.rich_link_data_ref,
        };
      }

      // Handle error from API
      appClipsError.value = result.error || 'Failed to generate App Clips';
      return { success: false, error: result.error };
    } catch (error) {
      // Log error for debugging, replace with proper error handling in production
      if (process.env.NODE_ENV === 'development') {
        // eslint-disable-next-line no-console
        console.error('App Clips generation error:', error);
      }
      appClipsError.value = error.message || 'Network error';
      return { success: false, error: error.message };
    } finally {
      isGenerating.value = false;
    }
  };

  /**
   * Clear error message
   */
  const clearError = () => {
    appClipsError.value = null;
  };

  /**
   * Reset all state to initial values
   */
  const reset = () => {
    isGenerating.value = false;
    appClipsError.value = null;
    richLinkDataRef.value = null;
    selectedStoreRegion.value = 'US';
  };

  return {
    // State
    isGenerating,
    appClipsError,
    richLinkDataRef,
    selectedStoreRegion,
    storeRegions,

    // Methods
    generateAppClips,
    clearError,
    reset,
  };
}
