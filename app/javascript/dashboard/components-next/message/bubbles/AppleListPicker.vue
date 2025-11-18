<script setup>
import { computed } from 'vue';
import { useMessageContext } from '../provider.js';
import BaseBubble from './Base.vue';

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

const getImageById = imageId => {
  const image = images.value.find(img => img.identifier === imageId);
  return image ? `data:image/jpeg;base64,${image.data}` : null;
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
              class="w-full flex items-center p-3 bg-n-alpha-1 hover:bg-n-alpha-2 rounded-lg transition-colors text-left border border-n-weak hover:border-n-strong"
              @click="handleItemClick(section, item)"
            >
              <!-- Item Image -->
              <img
                v-if="
                  item.image_identifier && getImageById(item.image_identifier)
                "
                :src="getImageById(item.image_identifier)"
                :alt="item.title"
                class="w-10 h-10 rounded-lg object-cover mr-3 flex-shrink-0"
              />

              <!-- Item Content -->
              <div class="flex-1 min-w-0">
                <h5 class="text-sm font-medium text-n-slate-12 truncate">
                  {{ item.title }}
                </h5>
                <p
                  v-if="item.subtitle"
                  class="text-xs text-n-slate-11 truncate mt-1"
                >
                  {{ item.subtitle }}
                </p>
              </div>

              <!-- Selection Indicator -->
              <div class="ml-2 flex-shrink-0">
                <div
                  v-if="section.multiple_selection"
                  class="w-4 h-4 border border-n-strong rounded bg-n-alpha-1"
                />
                <div
                  v-else
                  class="w-4 h-4 border border-n-strong rounded-full bg-n-alpha-1"
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
