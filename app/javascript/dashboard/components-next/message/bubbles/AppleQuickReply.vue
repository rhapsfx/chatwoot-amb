<script setup>
import { computed } from 'vue';
import { useMessageContext } from '../provider.js';
import BaseBubble from './Base.vue';

const { contentAttributes } = useMessageContext();

const summaryText = computed(
  () => contentAttributes.value?.summary_text || 'Quick Reply'
);
const items = computed(() => contentAttributes.value?.items || []);
const images = computed(() => contentAttributes.value?.images || []);
const receivedImageIdentifier = computed(
  () => contentAttributes.value?.received_image_identifier
);

const getImageById = imageId => {
  if (!imageId) return null;
  const image = images.value.find(img => img.identifier === imageId);
  return image ? `data:image/jpeg;base64,${image.data}` : null;
};

const handleReplyClick = () => {
  // In a real implementation, this would send the reply back to the server
};
</script>

<template>
  <BaseBubble>
    <div class="apple-quick-reply max-w-md">
      <!-- Summary Text -->
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
            :alt="summaryText"
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
              <path
                d="M20,2H4A2,2 0 0,0 2,4V22L6,18H20A2,2 0 0,0 22,16V4A2,2 0 0,0 20,2M6,9H18V11H6M14,14H6V12H14M18,8H6V6H18"
              />
            </svg>
          </div>
        </div>

        <!-- Summary Text -->
        <div class="flex-1 min-w-0">
          <p class="text-sm text-n-slate-12">
            {{ summaryText }}
          </p>
        </div>
      </div>

      <!-- Quick Reply Buttons -->
      <div class="flex flex-wrap gap-2">
        <button
          v-for="item in items"
          :key="item.identifier"
          class="px-4 py-2 bg-n-solid-blue text-n-slate-12 rounded-full text-sm font-medium hover:bg-n-solid-blue/80 transition-colors border border-n-blue-8 hover:border-n-blue-9"
          @click="handleReplyClick(item)"
        >
          {{ item.title }}
        </button>
      </div>
    </div>
  </BaseBubble>
</template>

<style scoped>
.apple-quick-reply {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

button:active {
  transform: scale(0.98);
}
</style>
