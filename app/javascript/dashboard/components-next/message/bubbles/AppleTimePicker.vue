<script setup>
import { computed } from 'vue';
import { useMessageContext } from '../provider.js';
import BaseBubble from './Base.vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();

const { contentAttributes } = useMessageContext();

const event = computed(() => contentAttributes.value?.event || {});
const images = computed(() => contentAttributes.value?.images || []);
const receivedImageIdentifier = computed(
  () => contentAttributes.value?.received_image_identifier
);

const getImageById = imageId => {
  if (!imageId) return null;
  const image = images.value.find(img => img.identifier === imageId);
  return image ? `data:image/jpeg;base64,${image.data}` : null;
};

const timeslots = computed(() => {
  // Try event.timeslots first (current format), then fall back to top-level timeslots (legacy)
  const rawSlots =
    contentAttributes.value?.event?.timeslots ||
    contentAttributes.value?.timeslots ||
    [];

  // Normalize slots to handle both snake_case (database) and camelCase (Apple MSP) formats
  return rawSlots.map(slot => ({
    identifier: slot.identifier,
    startTime: slot.startTime || slot.start_time,
    duration: slot.duration,
  }));
});

const formatDateTime = dateTimeString => {
  const date = new Date(dateTimeString);
  return {
    date: date.toLocaleDateString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
    }),
    time: date.toLocaleTimeString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    }),
  };
};

const formatDuration = durationValue => {
  // Handle both seconds and minutes - if > 300, assume it's seconds
  const minutes =
    durationValue > 300 ? Math.floor(durationValue / 60) : durationValue;

  if (minutes < 60) {
    return `${minutes}m`;
  }
  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;
  return remainingMinutes > 0 ? `${hours}h ${remainingMinutes}m` : `${hours}h`;
};

const handleTimeSlotClick = () => {
  // In a real implementation, this would send the selection back to the server
  // User interaction handled by parent component
};
</script>

<template>
  <BaseBubble>
    <div class="apple-time-picker max-w-md">
      <!-- Event Header -->
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
            :alt="event.title || 'Schedule Time'"
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
                d="M19,19H5V8H19M16,1V3H8V1H6V3H5C3.89,3 3,3.89 3,5V19A2,2 0 0,0 5,21H19A2,2 0 0,0 21,19V5C21,3.89 20.1,3 19,3H18V1M17,12H12V17H17V12Z"
              />
            </svg>
          </div>
        </div>

        <!-- Header Text -->
        <div class="flex-1 min-w-0">
          <h3 class="text-sm font-medium text-n-slate-12 mb-0.5">
            {{ event.title || 'Schedule Time' }}
          </h3>
          <p
            v-if="event.description"
            class="text-xs text-n-slate-11 line-clamp-1"
          >
            {{ event.description }}
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

      <!-- Time Slots -->
      <div class="space-y-2">
        <button
          v-for="slot in timeslots"
          :key="slot.identifier"
          class="w-full flex items-center justify-between p-3 bg-n-alpha-1 hover:bg-n-alpha-2 rounded-lg transition-colors text-left border border-n-weak hover:border-n-strong"
          @click="handleTimeSlotClick(slot)"
        >
          <div class="flex-1">
            <div class="flex items-center space-x-3">
              <!-- Date -->
              <div class="text-center">
                <div class="text-xs text-n-slate-11 uppercase tracking-wide">
                  {{ formatDateTime(slot.startTime).date }}
                </div>
              </div>

              <!-- Time -->
              <div>
                <div class="text-sm font-medium text-n-slate-12">
                  {{ formatDateTime(slot.startTime).time }}
                </div>
                <div v-if="slot.duration" class="text-xs text-n-slate-11">
                  {{ formatDuration(slot.duration) }}
                </div>
              </div>
            </div>
          </div>

          <!-- Availability Indicator -->
          <div class="flex-shrink-0 ml-3">
            <div class="w-3 h-3 bg-n-solid-green rounded-full" />
          </div>
        </button>
      </div>

      <!-- Empty State -->
      <div v-if="timeslots.length === 0" class="text-center py-6">
        <div class="text-n-slate-11 text-sm">{{ event.title || '' }}</div>
      </div>

      <!-- Footer Note -->
      <div
        v-if="timeslots.length > 0"
        class="mt-4 text-xs text-n-slate-11 text-center bg-n-alpha-1 rounded p-2"
      >
        {{ event.description || '' }}
      </div>
    </div>
  </BaseBubble>
</template>

<style scoped>
.apple-time-picker {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

button:active {
  transform: scale(0.98);
}
</style>
