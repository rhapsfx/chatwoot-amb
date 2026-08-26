<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAppClips } from 'dashboard/composables/useAppClips';
import SharedImageSelector from 'dashboard/routes/dashboard/settings/message-templates/components/SharedImageSelector.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  initialData: {
    type: Object,
    default: () => ({}),
  },
  inboxId: {
    type: Number,
    required: true,
  },
  accountId: {
    type: Number,
    required: false,
    default: null,
  },
});

const emit = defineEmits(['close', 'save', 'saveAndSend']);

const { t } = useI18n();

const store = useStore();

// Modal state
const modalRef = ref(null);
const isVisible = ref(false);
const isAnimating = ref(false);

// Mode: 'manual' or 'appclips'
const mode = ref('manual');

// Form data
const formData = ref({
  url: '',
  title: '',
  imageUrl: '',
  imageData: '',
  imageMimeType: '',
  videoUrl: '',
  videoMimeType: '',
  faviconUrl: '',
  description: '',
  imageIdentifier: '',
  richLinkDataRef: null,
  storeRegion: 'US',
});

// Image source toggle
const imageSource = ref('inline'); // 'inline', 'shared', or 'url'

// Computed
const currentAccountId = computed(() => {
  return props.accountId || store.getters.getCurrentAccountId;
});

// Use App Clips composable
const {
  isGenerating,
  appClipsError,
  selectedStoreRegion,
  storeRegions,
  generateAppClips,
  clearError,
  reset: resetAppClips,
} = useAppClips(computed(() => props.inboxId));

// Form validation
const isFormValid = computed(() => {
  if (mode.value === 'appclips') {
    // App Clips mode: URL required + richLinkDataRef generated
    return formData.value.url.trim() && formData.value.richLinkDataRef;
  }

  // Manual mode: URL required
  return formData.value.url.trim();
});

// Success banner state
const showSuccessBanner = ref(false);
const successMessage = ref('');

// Error banner state
const showErrorModal = ref(false);
const errorMessage = ref('');

// Methods - Define before they're used in watch
const openModal = () => {
  isVisible.value = true;
  isAnimating.value = true;

  // Initialize form data from props
  if (props.initialData) {
    Object.assign(formData.value, props.initialData);

    // Detect mode based on richLinkDataRef
    if (props.initialData.richLinkDataRef) {
      mode.value = 'appclips';
      formData.value.richLinkDataRef = props.initialData.richLinkDataRef;
    } else {
      mode.value = 'manual';
    }
  }

  nextTick(() => {
    if (modalRef.value) {
      modalRef.value.focus();
    }
    setTimeout(() => {
      isAnimating.value = false;
    }, 300);
  });
};

const closeModal = () => {
  isAnimating.value = true;
  setTimeout(() => {
    isVisible.value = false;
    isAnimating.value = false;
    emit('close');
  }, 300);
};

const dismissSuccessBanner = () => {
  showSuccessBanner.value = false;
};

const dismissErrorBanner = () => {
  clearError();
};

const handleSharedImageSelected = imageData => {
  if (!imageData) {
    formData.value.imageIdentifier = '';
  }
};

const triggerImageUpload = () => {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'image/*';
  input.onchange = e => {
    const file = e.target.files[0];
    if (file) {
      // Validate file size (max 5MB)
      if (file.size > 5 * 1024 * 1024) {
        errorMessage.value = t('APPLE_MESSAGES.RICH_LINK.IMAGE_SIZE_ERROR');
        showErrorModal.value = true;
        return;
      }

      const reader = new FileReader();
      reader.onload = event => {
        formData.value.imageData = event.target.result;
        formData.value.imageMimeType = file.type;
      };
      reader.readAsDataURL(file);
    }
  };
  input.click();
};

const handleGenerateAppClips = async () => {
  if (!formData.value.url) {
    return;
  }

  clearError();
  showSuccessBanner.value = false;

  const result = await generateAppClips(formData.value.url);

  if (result.success) {
    formData.value.richLinkDataRef = result.richLinkDataRef;
    formData.value.storeRegion = selectedStoreRegion.value;

    // Show success banner
    showSuccessBanner.value = true;
    successMessage.value = t('APPLE_MESSAGES.RICH_LINK.APP_CLIPS_SUCCESS');

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      showSuccessBanner.value = false;
    }, 5000);
  }
};

const handleSave = () => {
  if (!isFormValid.value) return;

  const richLinkData = {
    url: formData.value.url,
  };

  if (mode.value === 'appclips') {
    // App Clips mode - send richLinkDataRef
    richLinkData.rich_link_data_ref = formData.value.richLinkDataRef;
  } else {
    // Manual mode - send manual fields
    if (formData.value.title) richLinkData.title = formData.value.title;
    if (formData.value.imageUrl)
      richLinkData.image_url = formData.value.imageUrl;
    if (formData.value.imageData) {
      richLinkData.image_data = formData.value.imageData;
      richLinkData.image_mime_type = formData.value.imageMimeType;
    }
    if (formData.value.imageIdentifier) {
      richLinkData.image_identifier = formData.value.imageIdentifier;
    }
    if (formData.value.videoUrl) {
      richLinkData.video_url = formData.value.videoUrl;
      richLinkData.video_mime_type = formData.value.videoMimeType;
    }
    if (formData.value.faviconUrl)
      richLinkData.favicon_url = formData.value.faviconUrl;
    if (formData.value.description)
      richLinkData.description = formData.value.description;
  }

  emit('save', richLinkData);
  closeModal();
};

const handleSaveAndSend = () => {
  if (!isFormValid.value) return;

  const richLinkData = {
    url: formData.value.url,
  };

  if (mode.value === 'appclips') {
    // App Clips mode - send richLinkDataRef
    richLinkData.rich_link_data_ref = formData.value.richLinkDataRef;
  } else {
    // Manual mode - send manual fields
    if (formData.value.title) richLinkData.title = formData.value.title;
    if (formData.value.imageUrl)
      richLinkData.image_url = formData.value.imageUrl;
    if (formData.value.imageData) {
      richLinkData.image_data = formData.value.imageData;
      richLinkData.image_mime_type = formData.value.imageMimeType;
    }
    if (formData.value.imageIdentifier) {
      richLinkData.image_identifier = formData.value.imageIdentifier;
    }
    if (formData.value.videoUrl) {
      richLinkData.video_url = formData.value.videoUrl;
      richLinkData.video_mime_type = formData.value.videoMimeType;
    }
    if (formData.value.faviconUrl)
      richLinkData.favicon_url = formData.value.faviconUrl;
    if (formData.value.description)
      richLinkData.description = formData.value.description;
  }

  emit('saveAndSend', richLinkData);
  closeModal();
};

// Watch mode changes
watch(mode, newMode => {
  if (newMode === 'appclips') {
    // Switching to App Clips mode - clear manual fields
    formData.value.title = '';
    formData.value.imageUrl = '';
    formData.value.imageData = '';
    formData.value.videoUrl = '';
    formData.value.faviconUrl = '';
    formData.value.description = '';
    formData.value.imageIdentifier = '';
  } else {
    // Switching to manual mode - clear App Clips data
    formData.value.richLinkDataRef = null;
    formData.value.storeRegion = 'US';
    resetAppClips();
  }

  // Clear any errors
  clearError();
  showSuccessBanner.value = false;
});

// Watch for modal open
watch(
  () => props.show,
  newVal => {
    if (newVal) {
      openModal();
    } else {
      closeModal();
    }
  }
);
</script>

<template>
  <!-- Modal Backdrop -->
  <Teleport to="body">
    <div
      v-if="isVisible"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black bg-opacity-75 transition-opacity duration-300"
      :class="{ 'opacity-100': !isAnimating, 'opacity-0': isAnimating }"
      @click.self="closeModal"
    >
      <!-- Modal Container -->
      <div
        ref="modalRef"
        class="w-full max-w-3xl max-h-[90vh] bg-white dark:bg-n-slate-1 rounded-xl shadow-2xl overflow-hidden transition-all duration-300 transform"
        :class="{
          'scale-100 opacity-100': !isAnimating,
          'scale-95 opacity-0': isAnimating,
        }"
        tabindex="-1"
        role="dialog"
        aria-labelledby="modal-title"
        aria-describedby="modal-description"
      >
        <!-- Modal Header -->
        <div
          class="flex items-center justify-between p-6 border-b border-n-weak dark:border-n-slate-6"
        >
          <div>
            <h2
              id="modal-title"
              class="text-xl font-semibold text-n-slate-12 dark:text-n-slate-1"
            >
              {{ $t('APPLE_MESSAGES.RICH_LINK.MODAL_TITLE') }}
            </h2>
            <p
              id="modal-description"
              class="text-sm text-n-slate-11 dark:text-n-slate-3 mt-1"
            >
              {{ $t('APPLE_MESSAGES.RICH_LINK.MODAL_DESCRIPTION') }}
            </p>
          </div>
          <button
            class="text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-3 dark:hover:text-n-slate-1 transition-colors p-1"
            :aria-label="$t('APPLE_MESSAGES.RICH_LINK.CLOSE_MODAL')"
            @click="closeModal"
          >
            <svg
              class="w-6 h-6"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>

        <!-- Modal Content -->
        <div class="p-6 overflow-y-auto max-h-[calc(90vh-200px)]">
          <!-- Mode Toggle -->
          <div class="mb-6">
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-3"
            >
              {{ $t('APPLE_MESSAGES.RICH_LINK.MODE_LABEL') }}
            </label>
            <div class="flex bg-n-alpha-2 dark:bg-n-alpha-3 rounded-lg p-1">
              <button
                type="button"
                class="flex-1 px-4 py-2 text-sm font-medium rounded transition-colors"
                :class="
                  mode === 'manual'
                    ? 'bg-n-blue-9 text-white dark:bg-n-blue-10'
                    : 'text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-10 dark:hover:text-n-slate-9'
                "
                @click="mode = 'manual'"
              >
                {{ $t('APPLE_MESSAGES.RICH_LINK.MANUAL_MODE') }}
              </button>
              <button
                type="button"
                class="flex-1 px-4 py-2 text-sm font-medium rounded transition-colors"
                :class="
                  mode === 'appclips'
                    ? 'bg-n-blue-9 text-white dark:bg-n-blue-10'
                    : 'text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-10 dark:hover:text-n-slate-9'
                "
                @click="mode = 'appclips'"
              >
                {{ $t('APPLE_MESSAGES.RICH_LINK.APP_CLIPS_MODE') }}
              </button>
            </div>
          </div>

          <!-- URL Field (Common) -->
          <div class="mb-6">
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
            >
              {{ $t('APPLE_MESSAGES.RICH_LINK.URL_REQUIRED') }}
            </label>
            <input
              v-model="formData.url"
              type="url"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9 focus:ring-1 focus:ring-n-blue-8 dark:focus:ring-n-blue-9 transition-colors"
              :placeholder="$t('APPLE_MESSAGES.RICH_LINK.URL_PLACEHOLDER')"
              required
            />
            <p class="text-xs text-n-slate-10 dark:text-n-slate-9 mt-1">
              {{ $t('APPLE_MESSAGES.RICH_LINK.URL_HELP') }}
            </p>
          </div>

          <!-- Success Banner -->
          <div
            v-if="showSuccessBanner"
            class="mb-6 p-4 bg-n-green-2 dark:bg-n-green-3 border border-n-green-6 dark:border-n-green-7 rounded-lg flex items-start justify-between"
          >
            <div class="flex items-start">
              <svg
                class="w-5 h-5 text-n-green-10 dark:text-n-green-9 mr-3 flex-shrink-0 mt-0.5"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <p class="text-sm text-n-green-11 dark:text-n-green-10">
                {{ successMessage }}
              </p>
            </div>
            <button
              class="text-n-green-10 hover:text-n-green-11 dark:text-n-green-9 dark:hover:text-n-green-10 transition-colors"
              @click="dismissSuccessBanner"
            >
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>

          <!-- Error Banner -->
          <div
            v-if="appClipsError"
            class="mb-6 p-4 bg-n-ruby-2 dark:bg-n-ruby-3 border border-n-ruby-6 dark:border-n-ruby-7 rounded-lg flex items-start justify-between"
          >
            <div class="flex items-start">
              <svg
                class="w-5 h-5 text-n-ruby-10 dark:text-n-ruby-9 mr-3 flex-shrink-0 mt-0.5"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <p class="text-sm text-n-ruby-11 dark:text-n-ruby-10">
                {{ appClipsError }}
              </p>
            </div>
            <button
              class="text-n-ruby-10 hover:text-n-ruby-11 dark:text-n-ruby-9 dark:hover:text-n-ruby-10 transition-colors"
              @click="dismissErrorBanner"
            >
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>

          <!-- App Clips Mode -->
          <div v-if="mode === 'appclips'" class="space-y-6">
            <!-- Store Region -->
            <div>
              <label
                class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
              >
                {{ $t('APPLE_MESSAGES.RICH_LINK.STORE_REGION_LABEL') }}
              </label>
              <select
                v-model="selectedStoreRegion"
                class="w-full px-3 py-2 border border-n-weak dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9 transition-colors"
              >
                <option
                  v-for="region in storeRegions"
                  :key="region.code"
                  :value="region.code"
                >
                  {{ region.name }}
                </option>
              </select>
              <p class="text-xs text-n-slate-10 dark:text-n-slate-9 mt-1">
                {{ $t('APPLE_MESSAGES.RICH_LINK.STORE_REGION_HELP') }}
              </p>
            </div>

            <!-- Generate Button -->
            <div>
              <button
                type="button"
                class="w-full px-4 py-3 bg-n-blue-9 dark:bg-n-blue-10 text-white rounded-lg hover:bg-n-blue-10 dark:hover:bg-n-blue-11 transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none flex items-center justify-center"
                :disabled="!formData.url || isGenerating"
                @click="handleGenerateAppClips"
              >
                <svg
                  v-if="isGenerating"
                  class="animate-spin -ml-1 mr-3 h-5 w-5 text-white"
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
                <span v-if="isGenerating">{{
                  $t('APPLE_MESSAGES.RICH_LINK.GENERATING_APP_CLIPS')
                }}</span>
                <span v-else>{{
                  $t('APPLE_MESSAGES.RICH_LINK.GENERATE_APP_CLIPS')
                }}</span>
              </button>
            </div>

            <!-- App Clips Success Info -->
            <div
              v-if="formData.richLinkDataRef"
              class="p-4 bg-n-blue-2 dark:bg-n-blue-3 border border-n-blue-6 dark:border-n-blue-7 rounded-lg"
            >
              <div class="flex items-start">
                <svg
                  class="w-5 h-5 text-n-blue-10 dark:text-n-blue-9 mr-3 flex-shrink-0 mt-0.5"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <div>
                  <p
                    class="text-sm font-medium text-n-blue-11 dark:text-n-blue-10"
                  >
                    {{ $t('APPLE_MESSAGES.RICH_LINK.APP_CLIPS_READY_TITLE') }}
                  </p>
                  <p class="text-xs text-n-blue-10 dark:text-n-blue-9 mt-1">
                    {{ $t('APPLE_MESSAGES.RICH_LINK.APP_CLIPS_READY_INFO') }}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <!-- Manual Mode -->
          <div v-if="mode === 'manual'" class="space-y-6">
            <!-- Title -->
            <div>
              <label
                class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
              >
                {{ $t('APPLE_MESSAGES.RICH_LINK.TITLE_LABEL') }}
              </label>
              <input
                v-model="formData.title"
                type="text"
                class="w-full px-3 py-2 border border-n-weak dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9 transition-colors"
                :placeholder="$t('APPLE_MESSAGES.RICH_LINK.TITLE_PLACEHOLDER')"
              />
            </div>

            <!-- Description -->
            <div>
              <label
                class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
              >
                {{ $t('APPLE_MESSAGES.RICH_LINK.DESCRIPTION_LABEL') }}
              </label>
              <textarea
                v-model="formData.description"
                rows="3"
                class="w-full px-3 py-2 border border-n-weak dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9 resize-none transition-colors"
                :placeholder="
                  $t('APPLE_MESSAGES.RICH_LINK.DESCRIPTION_PLACEHOLDER')
                "
              />
            </div>

            <!-- Image Selection Mode -->
            <div>
              <label
                class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
              >
                {{ $t('APPLE_MESSAGES.RICH_LINK.IMAGE_LABEL') }}
              </label>

              <!-- Image Source Toggle -->
              <div
                class="flex items-center gap-2 mb-3 p-2 bg-n-alpha-1 dark:bg-n-alpha-2 rounded-lg"
              >
                <button
                  type="button"
                  class="flex-1 px-3 py-1.5 text-xs font-medium rounded transition-all"
                  :class="
                    imageSource === 'inline'
                      ? 'bg-n-blue-9 text-white dark:bg-n-blue-10'
                      : 'text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-10 dark:hover:text-n-slate-9'
                  "
                  @click="imageSource = 'inline'"
                >
                  {{ $t('APPLE_MESSAGES.RICH_LINK.IMAGE_SOURCE_UPLOAD') }}
                </button>
                <button
                  type="button"
                  class="flex-1 px-3 py-1.5 text-xs font-medium rounded transition-all"
                  :class="
                    imageSource === 'shared'
                      ? 'bg-n-blue-9 text-white dark:bg-n-blue-10'
                      : 'text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-10 dark:hover:text-n-slate-9'
                  "
                  @click="imageSource = 'shared'"
                >
                  {{ $t('APPLE_MESSAGES.RICH_LINK.IMAGE_SOURCE_SHARED') }}
                </button>
                <button
                  type="button"
                  class="flex-1 px-3 py-1.5 text-xs font-medium rounded transition-all"
                  :class="
                    imageSource === 'url'
                      ? 'bg-n-blue-9 text-white dark:bg-n-blue-10'
                      : 'text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-10 dark:hover:text-n-slate-9'
                  "
                  @click="imageSource = 'url'"
                >
                  {{ $t('APPLE_MESSAGES.RICH_LINK.IMAGE_SOURCE_URL') }}
                </button>
              </div>

              <!-- Inline Upload -->
              <div v-if="imageSource === 'inline'">
                <button
                  type="button"
                  class="w-full px-4 py-2 border-2 border-dashed border-n-weak dark:border-n-slate-6 rounded-lg hover:border-n-blue-8 dark:hover:border-n-blue-9 transition-colors"
                  @click="triggerImageUpload"
                >
                  <div class="text-center">
                    <svg
                      class="mx-auto h-12 w-12 text-n-slate-10 dark:text-n-slate-9"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                      />
                    </svg>
                    <p
                      class="mt-2 text-sm text-n-slate-11 dark:text-n-slate-10"
                    >
                      {{ $t('APPLE_MESSAGES.RICH_LINK.IMAGE_UPLOAD_TEXT') }}
                    </p>
                    <p class="text-xs text-n-slate-10 dark:text-n-slate-9">
                      {{ $t('APPLE_MESSAGES.RICH_LINK.IMAGE_SIZE_LIMIT') }}
                    </p>
                  </div>
                </button>
                <img
                  v-if="formData.imageData"
                  :src="formData.imageData"
                  class="mt-3 w-full h-48 object-cover rounded-lg border border-n-weak dark:border-n-slate-6"
                  :alt="$t('APPLE_MESSAGES.RICH_LINK.IMAGE_PREVIEW_ALT')"
                />
              </div>

              <!-- Shared Images -->
              <div v-else-if="imageSource === 'shared'">
                <SharedImageSelector
                  v-model="formData.imageIdentifier"
                  :account-id="currentAccountId"
                  image-type="branding"
                  @image-selected="handleSharedImageSelected"
                />
              </div>

              <!-- Image URL -->
              <div v-else-if="imageSource === 'url'">
                <input
                  v-model="formData.imageUrl"
                  type="url"
                  class="w-full px-3 py-2 border border-n-weak dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9 transition-colors"
                  :placeholder="
                    $t('APPLE_MESSAGES.RICH_LINK.IMAGE_URL_PLACEHOLDER')
                  "
                />
              </div>
            </div>

            <!-- Video URL (Optional) -->
            <div>
              <label
                class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
              >
                {{ $t('APPLE_MESSAGES.RICH_LINK.VIDEO_URL_LABEL') }}
              </label>
              <input
                v-model="formData.videoUrl"
                type="url"
                class="w-full px-3 py-2 border border-n-weak dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9 transition-colors"
                :placeholder="
                  $t('APPLE_MESSAGES.RICH_LINK.VIDEO_URL_PLACEHOLDER')
                "
              />
            </div>

            <!-- Favicon URL (Optional) -->
            <div>
              <label
                class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
              >
                {{ $t('APPLE_MESSAGES.RICH_LINK.FAVICON_URL_LABEL') }}
              </label>
              <input
                v-model="formData.faviconUrl"
                type="url"
                class="w-full px-3 py-2 border border-n-weak dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9 transition-colors"
                :placeholder="
                  $t('APPLE_MESSAGES.RICH_LINK.FAVICON_URL_PLACEHOLDER')
                "
              />
            </div>
          </div>
        </div>

        <!-- Modal Footer -->
        <div
          class="flex items-center justify-end gap-3 p-6 border-t border-n-weak dark:border-n-slate-6 bg-n-alpha-1 dark:bg-n-alpha-2 flex-shrink-0"
        >
          <button
            class="px-4 py-2 text-n-slate-11 dark:text-n-slate-10 hover:text-n-slate-12 dark:hover:text-n-slate-9 transition-colors"
            @click="closeModal"
          >
            {{ $t('APPLE_MESSAGES.RICH_LINK.CANCEL') }}
          </button>
          <button
            class="px-4 py-2 border border-n-blue-9 dark:border-n-blue-10 text-n-blue-9 dark:text-n-blue-10 rounded-lg hover:bg-n-blue-1 dark:hover:bg-n-blue-2 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
            :disabled="!isFormValid"
            @click="handleSave"
          >
            {{ $t('APPLE_MESSAGES.RICH_LINK.CREATE_ONLY') }}
          </button>
          <button
            class="px-6 py-2 bg-n-blue-9 dark:bg-n-blue-10 text-white dark:text-n-slate-12 rounded-lg hover:bg-n-blue-10 dark:hover:bg-n-blue-11 transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
            :disabled="!isFormValid"
            @click="handleSaveAndSend"
          >
            {{ $t('APPLE_MESSAGES.RICH_LINK.CREATE_AND_SEND') }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
