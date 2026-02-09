<script setup>
import { computed } from 'vue';
import { useMessageContext } from '../provider.js';
import BaseBubble from './Base.vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();

const { contentAttributes } = useMessageContext();

const sections = computed(() => contentAttributes.value?.sections || []);
const images = computed(() => contentAttributes.value?.images || []);
const receivedTitle = computed(
  () => contentAttributes.value?.received_title || 'Please select an option'
);
const receivedSubtitle = computed(
  () => contentAttributes.value?.received_subtitle
);
const receivedImageIdentifier = computed(
  () => contentAttributes.value?.received_image_identifier
);

// Debug logging removed - was causing excessive console output
// Uncomment for debugging if needed:
// onMounted(() => {
//   console.log('[AppleListPicker] Content attributes:', contentAttributes.value);
//   console.log('[AppleListPicker] Sections:', sections.value);
//   console.log('[AppleListPicker] Images:', images.value);
// });

const getImageById = imageId => {
  if (!imageId) return null;
  const image = images.value.find(img => img.identifier === imageId);
  if (image) {
    return `data:image/jpeg;base64,${image.data}`;
  }
  return null;
};

const getItemImageIdentifier = item => {
  // Support both snake_case and camelCase
  return item.image_identifier || item.imageIdentifier || null;
};

const handleItemClick = () => {
  // In a real implementation, this would send the selection back to the server
};
</script>

<template>
  <BaseBubble>
    <div class="apple-list-picker max-w-md">
      <!-- Header -->
      <div
        class="mb-3 p-3 bg-n-alpha-2 rounded-lg flex items-start space-x-2.5"
      >
        <!-- Header Image/Icon -->
        <div class="w-12 h-12 flex-shrink-0 rounded-lg overflow-hidden">
          <img
            v-if="
              receivedImageIdentifier && getImageById(receivedImageIdentifier)
            "
            :src="getImageById(receivedImageIdentifier)"
            :alt="receivedTitle"
            class="w-full h-full object-cover"
          />
          <div
            v-else
            class="w-full h-full bg-blue-500 flex items-center justify-center"
          >
            <svg
              class="w-6 h-6 text-white"
              fill="currentColor"
              viewBox="0 0 24 24"
            >
              <path d="M3,13H15V11H3M3,6V8H21V6M3,18H9V16H3V18Z" />
            </svg>
          </div>
        </div>

        <!-- Header Text -->
        <div class="flex-1 min-w-0">
          <h3 class="text-sm font-medium text-n-slate-12 mb-0.5">
            {{ receivedTitle }}
          </h3>
          <p
            v-if="receivedSubtitle"
            class="text-xs text-n-slate-11 line-clamp-1"
          >
            {{ receivedSubtitle }}
          </p>
          <!-- Image Indicator Badge -->
          <div
            v-if="
              receivedImageIdentifier && getImageById(receivedImageIdentifier)
            "
            class="inline-flex items-center gap-1 mt-1 px-2 py-0.5 bg-n-alpha-2 rounded text-xs text-n-slate-11"
          >
            <svg
              class="w-3 h-3"
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
            <span>{{ t('APPLE_MESSAGES.IMAGE_INDICATOR') }}</span>
          </div>
        </div>
      </div>

      <!-- Sections -->
      <div class="space-y-4">
        <div
          v-for="section in sections"
          :key="section.order || section.title"
          class="section"
        >
          <h4 class="text-sm font-medium text-n-slate-12 mb-2 px-2">
            {{ section.title }}
          </h4>

          <div class="space-y-1">
            <button
              v-for="item in section.items"
              :key="item.identifier"
              class="w-full flex items-center p-2.5 bg-n-alpha-1 hover:bg-n-alpha-2 rounded-lg transition-colors text-left border border-n-weak hover:border-n-strong group"
              @click="handleItemClick(section, item)"
            >
              <!-- Item Image Icon (Small) -->
              <div
                v-if="
                  getItemImageIdentifier(item) &&
                  getImageById(getItemImageIdentifier(item))
                "
                class="w-6 h-6 rounded-md overflow-hidden mr-2.5 flex-shrink-0 ring-1 ring-n-weak group-hover:ring-n-strong transition-all"
              >
                <img
                  :src="getImageById(getItemImageIdentifier(item))"
                  :alt="item.title"
                  class="w-full h-full object-cover"
                />
              </div>

              <!-- Fallback Icon for items without images -->
              <div
                v-else
                class="w-6 h-6 rounded-md mr-2.5 flex-shrink-0 bg-n-alpha-2 flex items-center justify-center"
              >
                <svg
                  class="w-3.5 h-3.5 text-n-slate-10"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
              </div>

              <!-- Item Content -->
              <div class="flex-1 min-w-0">
                <h5 class="text-sm font-medium text-n-slate-12 truncate">
                  {{ item.title }}
                </h5>
                <p
                  v-if="item.subtitle"
                  class="text-xs text-n-slate-11 truncate mt-0.5"
                >
                  {{ item.subtitle }}
                </p>
              </div>

              <!-- Selection Indicator -->
              <div class="ml-2 flex-shrink-0">
                <div
                  v-if="section.multiple_selection"
                  class="w-4 h-4 border border-n-strong rounded bg-n-alpha-1 group-hover:border-n-blue-8 transition-colors"
                />
                <div
                  v-else
                  class="w-4 h-4 border border-n-strong rounded-full bg-n-alpha-1 group-hover:border-n-blue-8 transition-colors"
                />
              </div>
            </button>
          </div>
        </div>
      </div>
    </div>
  </BaseBubble>
</template>

<style scoped>
.apple-list-picker {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

.section:not(:last-child) {
  border-bottom: 1px solid theme('colors.n.weak');
  padding-bottom: 1rem;
}
</style>
