<script setup>
import { ref, watch, computed, onMounted, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { addDays } from 'date-fns';

const props = defineProps({
  properties: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['update:properties']);

const { t } = useI18n();

// Flag to prevent infinite loop between watchers
const isUpdatingFromProps = ref(false);

// Initialize with default values matching AMB composer
const localProps = ref({
  // Event details
  eventTitle: '',
  eventDescription: '',
  timeslots: [],
  timezoneOffset: 0,

  // Received message
  receivedTitle: 'Please pick a time',
  receivedSubtitle: 'Select your preferred time slot',
  receivedImageIdentifier: '',
  receivedStyle: 'icon',

  // Reply message
  replyTitle: 'Thank you!',
  replySubtitle: '',
  replyImageIdentifier: '',
  replyStyle: 'icon',
  replyImageTitle: '',
  replyImageSubtitle: '',
  replySecondarySubtitle: '',
  replyTertiarySubtitle: '',

  // Images
  images: [],

  ...props.properties,
});

// Style options matching AMB with descriptions
const styleOptions = [
  {
    value: 'icon',
    label: 'Icon',
    dimensions: '280×65',
    description: 'Compact header with small icon',
  },
  {
    value: 'small',
    label: 'Small',
    dimensions: '280×85',
    description: 'Medium-sized header',
  },
  {
    value: 'large',
    label: 'Large',
    dimensions: '280×210',
    description: 'Full-width banner image',
  },
];

// Common timezone options (offset in minutes from UTC)
const timezoneOptions = [
  { label: 'GMT-12:00 (Baker Island)', value: -720 },
  { label: 'GMT-11:00 (Samoa)', value: -660 },
  { label: 'GMT-10:00 (Hawaii)', value: -600 },
  { label: 'GMT-09:00 (Alaska)', value: -540 },
  { label: 'GMT-08:00 (Pacific Time)', value: -480 },
  { label: 'GMT-07:00 (Mountain Time)', value: -420 },
  { label: 'GMT-06:00 (Central Time)', value: -360 },
  { label: 'GMT-05:00 (Eastern Time)', value: -300 },
  { label: 'GMT-04:00 (Atlantic Time)', value: -240 },
  { label: 'GMT-03:00 (Buenos Aires)', value: -180 },
  { label: 'GMT-02:00 (Mid-Atlantic)', value: -120 },
  { label: 'GMT-01:00 (Azores)', value: -60 },
  { label: 'GMT+00:00 (London, UTC)', value: 0 },
  { label: 'GMT+01:00 (Paris, Berlin)', value: 60 },
  { label: 'GMT+02:00 (Cairo, Athens)', value: 120 },
  { label: 'GMT+03:00 (Moscow, Istanbul)', value: 180 },
  { label: 'GMT+04:00 (Dubai)', value: 240 },
  { label: 'GMT+05:00 (Pakistan)', value: 300 },
  { label: 'GMT+05:30 (India)', value: 330 },
  { label: 'GMT+06:00 (Bangladesh)', value: 360 },
  { label: 'GMT+07:00 (Bangkok)', value: 420 },
  { label: 'GMT+08:00 (Singapore, Beijing)', value: 480 },
  { label: 'GMT+09:00 (Tokyo, Seoul)', value: 540 },
  { label: 'GMT+10:00 (Sydney)', value: 600 },
  { label: 'GMT+11:00 (Solomon Islands)', value: 660 },
  { label: 'GMT+12:00 (New Zealand)', value: 720 },
];

// Available images from properties
const availableImages = computed(() => {
  return localProps.value.images || [];
});

// Watch for props changes (e.g., when template data loads)
watch(
  () => props.properties,
  async newProps => {
    isUpdatingFromProps.value = true;
    // eslint-disable-next-line no-console
    console.log('TimePickerBlockEditor: props.properties changed', {
      hasImages: !!newProps?.images,
      imagesCount: newProps?.images?.length || 0,
      propertyKeys: Object.keys(newProps || {}),
      fullProps: newProps,
    });

    if (newProps && Object.keys(newProps).length > 0) {
      // Handle nested event structure from database
      const event = newProps.event || {};

      // Create a new object to trigger reactivity
      localProps.value = {
        // Event details (may be nested in event object)
        eventTitle: newProps.eventTitle || event.title || '',
        eventDescription: newProps.eventDescription || event.description || '',
        timeslots: newProps.timeslots || event.timeslots || [],
        timezoneOffset: newProps.timezoneOffset || event.timezoneOffset || 0,

        // Message configuration (flat structure)
        // Handle both camelCase and snake_case
        receivedTitle:
          newProps.receivedTitle ||
          newProps.received_title ||
          'Please pick a time',
        receivedSubtitle:
          newProps.receivedSubtitle ||
          newProps.received_subtitle ||
          'Select your preferred time slot',
        receivedImageIdentifier:
          newProps.receivedImageIdentifier ||
          newProps.received_image_identifier ||
          '',
        receivedStyle:
          newProps.receivedStyle || newProps.received_style || 'icon',
        replyTitle: newProps.replyTitle || newProps.reply_title || 'Thank you!',
        replySubtitle: newProps.replySubtitle || newProps.reply_subtitle || '',
        replyImageIdentifier:
          newProps.replyImageIdentifier ||
          newProps.reply_image_identifier ||
          '',
        replyStyle: newProps.replyStyle || newProps.reply_style || 'icon',
        replyImageTitle:
          newProps.replyImageTitle || newProps.reply_image_title || '',
        replyImageSubtitle:
          newProps.replyImageSubtitle || newProps.reply_image_subtitle || '',
        replySecondarySubtitle:
          newProps.replySecondarySubtitle ||
          newProps.reply_secondary_subtitle ||
          '',
        replyTertiarySubtitle:
          newProps.replyTertiarySubtitle ||
          newProps.reply_tertiary_subtitle ||
          '',

        // Images - try multiple possible locations
        images: newProps.images || event.images || [],
      };

      // eslint-disable-next-line no-console
      console.log('TimePickerBlockEditor: localProps updated', {
        imagesCount: localProps.value.images.length,
        images: localProps.value.images,
        hasPreview: localProps.value.images.map(img => ({
          identifier: img.identifier,
          hasPreview: !!img.preview,
          hasImageUrl: !!img.image_url,
          preview: img.preview,
        })),
        timeslotsCount: localProps.value.timeslots.length,
        receivedTitle: localProps.value.receivedTitle,
        eventTitle: localProps.value.eventTitle,
        rawImages: newProps.images,
        eventImages: event.images,
      });
    }

    // Wait for Vue to process all reactive updates before resetting flag
    await nextTick();
    isUpdatingFromProps.value = false;
  },
  { deep: true, immediate: true }
);

// Auto-sync reply image with received image
watch(
  () => localProps.value.receivedImageIdentifier,
  newIdentifier => {
    if (!localProps.value.replyImageIdentifier) {
      localProps.value.replyImageIdentifier = newIdentifier;
    }
  }
);

// Emit changes (but only if not updating from props)
watch(
  localProps,
  newValue => {
    // Only emit if this change didn't come from props
    if (!isUpdatingFromProps.value) {
      emit('update:properties', newValue);
    }
  },
  { deep: true }
);

// Timeslot management
const addTimeslot = () => {
  const newSlot = {
    startTime: new Date(addDays(new Date(), 1)).toISOString(),
    duration: 3600, // 60 minutes in seconds
  };
  localProps.value.timeslots.push(newSlot);
};

const removeTimeslot = index => {
  localProps.value.timeslots.splice(index, 1);
};

// Image upload handler
const handleImageUpload = () => {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'image/*';
  input.onchange = e => {
    const file = e.target.files[0];
    if (file) {
      const MAX_SIZE = 5 * 1024 * 1024; // 5MB
      if (file.size > MAX_SIZE) {
        // Use console.warn instead of alert
        // eslint-disable-next-line no-console
        console.warn('Image file size must be less than 5MB');
        return;
      }

      const reader = new FileReader();
      reader.onload = event => {
        const fileNameWithoutExt = file.name.replace(/\.[^/.]+$/, '');
        const cleanName = fileNameWithoutExt
          .replace(/[^a-zA-Z0-9]/g, '_')
          .toLowerCase();
        const imageIndex = localProps.value.images.length + 1;

        const imageData = {
          identifier: `${cleanName}_${imageIndex}`,
          data: event.target.result.split(',')[1],
          preview: event.target.result,
          description: file.name,
          originalName: file.name,
          size: file.size,
        };

        if (!localProps.value.images) {
          localProps.value.images = [];
        }
        localProps.value.images.push(imageData);
      };
      reader.readAsDataURL(file);
    }
  };
  input.click();
};

const removeImage = index => {
  localProps.value.images.splice(index, 1);
};

const formatFileSize = bytes => {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / k ** i).toFixed(2)) + ' ' + sizes[i];
};

// Get image preview for display
const getImagePreview = identifier => {
  if (!identifier) return null;
  const image = availableImages.value.find(
    img => img.identifier === identifier
  );
  return image?.preview || null;
};

// Initialize empty arrays if needed
onMounted(() => {
  if (!localProps.value.images) {
    localProps.value.images = [];
  }
  if (!localProps.value.timeslots) {
    localProps.value.timeslots = [];
  }
});
</script>

<template>
  <div class="space-y-6">
    <!-- Images Section - Gallery Grid -->
    <div
      class="bg-n-alpha-2 dark:bg-n-alpha-3 p-6 rounded-lg border border-n-weak dark:border-n-slate-6"
    >
      <div class="flex justify-between items-center mb-4">
        <div>
          <h4
            class="text-base font-semibold text-n-slate-12 dark:text-n-slate-11"
          >
            Choose 1 image for the Time Picker
          </h4>
          <p class="text-sm text-n-slate-10 dark:text-n-slate-9 mt-1">
            Upload images to use in your time picker messages
          </p>
        </div>
        <button
          class="px-4 py-2 bg-n-blue-9 dark:bg-n-blue-10 text-white rounded-lg text-sm font-medium hover:bg-n-blue-10 dark:hover:bg-n-blue-11 transition-colors"
          @click="handleImageUpload"
        >
          Add Image
        </button>
      </div>

      <!-- Image Gallery Grid -->
      <div
        v-if="availableImages.length === 0"
        class="text-center py-12 border-2 border-dashed border-n-slate-6 dark:border-n-slate-7 rounded-lg"
      >
        <svg
          class="mx-auto h-12 w-12 text-n-slate-9 dark:text-n-slate-8"
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
        <p class="mt-2 text-sm text-n-slate-11 dark:text-n-slate-10">
          No images uploaded yet
        </p>
        <p class="text-xs text-n-slate-10 dark:text-n-slate-9 mt-1">
          Click "Add Image" to upload images for your time picker
        </p>
      </div>

      <div v-else class="grid grid-cols-4 gap-3">
        <div
          v-for="(image, index) in availableImages"
          :key="image.identifier"
          class="relative group border-2 rounded-lg overflow-hidden transition-all duration-200 cursor-pointer aspect-square"
          :class="
            localProps.receivedImageIdentifier === image.identifier
              ? 'border-n-blue-8 ring-2 ring-n-blue-8 dark:border-n-blue-9 dark:ring-n-blue-9'
              : 'border-n-weak hover:border-n-blue-6 dark:border-n-slate-6 dark:hover:border-n-blue-7'
          "
          @click="localProps.receivedImageIdentifier = image.identifier"
        >
          <!-- Image -->
          <img
            v-if="image.preview"
            :src="image.preview"
            :alt="image.originalName || image.description"
            class="w-full h-full object-cover"
          />

          <!-- Selected indicator -->
          <div
            v-if="localProps.receivedImageIdentifier === image.identifier"
            class="absolute top-2 right-2 bg-n-blue-9 dark:bg-n-blue-10 text-white rounded-full p-1"
          >
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path
                fill-rule="evenodd"
                d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                clip-rule="evenodd"
              />
            </svg>
          </div>

          <!-- Hover overlay with remove button -->
          <div
            class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-50 transition-all duration-200 flex items-center justify-center"
          >
            <button
              class="opacity-0 group-hover:opacity-100 px-3 py-1.5 bg-n-ruby-9 text-white rounded text-sm font-medium hover:bg-n-ruby-10 transition-all"
              @click.stop="removeImage(index)"
            >
              Remove
            </button>
          </div>

          <!-- Image info -->
          <div
            class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black to-transparent p-2"
          >
            <p
              class="text-xs text-white truncate font-medium"
              :title="`${image.originalName || image.description}`"
            >
              {{ image.originalName || image.description }}
            </p>
            <p class="text-xs text-white opacity-75">
              {{ formatFileSize(image.size) }}
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- Message Configuration Section -->
    <div
      class="bg-n-alpha-2 dark:bg-n-alpha-3 p-6 rounded-lg border border-n-weak dark:border-n-slate-6"
    >
      <h4
        class="text-base font-semibold text-n-slate-12 dark:text-n-slate-11 mb-6"
      >
        Message Configuration
      </h4>

      <!-- Received Message -->
      <div class="mb-8">
        <h5
          class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-4"
        >
          Received Title
        </h5>
        <input
          v-model="localProps.receivedTitle"
          type="text"
          placeholder="Please pick a time"
          class="w-full px-4 py-2.5 border border-n-slate-7 dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-blue-7 dark:focus:ring-n-blue-8 transition-colors"
        />
      </div>

      <div class="mb-8">
        <h5
          class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-4"
        >
          Received Subtitle
        </h5>
        <input
          v-model="localProps.receivedSubtitle"
          type="text"
          placeholder="Select your preferred time slot"
          class="w-full px-4 py-2.5 border border-n-slate-7 dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-blue-7 dark:focus:ring-n-blue-8 transition-colors"
        />
      </div>

      <!-- Received Style Selection -->
      <div class="mb-8">
        <h5
          class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-4"
        >
          Received Style
        </h5>
        <div class="grid grid-cols-3 gap-4">
          <div
            v-for="style in styleOptions"
            :key="style.value"
            class="border-2 rounded-lg p-4 cursor-pointer transition-all duration-200 hover:shadow-md"
            :class="
              localProps.receivedStyle === style.value
                ? 'border-n-blue-8 bg-n-blue-1 dark:border-n-blue-9 dark:bg-n-blue-2'
                : 'border-n-weak hover:border-n-blue-6 dark:border-n-slate-6 dark:hover:border-n-blue-7'
            "
            @click="localProps.receivedStyle = style.value"
          >
            <div class="text-center">
              <!-- Style Preview -->
              <div
                class="mx-auto mb-3 rounded border-2 bg-white dark:bg-n-alpha-2 flex items-center justify-center"
                :class="
                  style.value === 'icon'
                    ? 'w-24 h-8'
                    : style.value === 'small'
                      ? 'w-24 h-10'
                      : 'w-24 h-20'
                "
              >
                <img
                  v-if="
                    localProps.receivedImageIdentifier &&
                    getImagePreview(localProps.receivedImageIdentifier)
                  "
                  :src="getImagePreview(localProps.receivedImageIdentifier)"
                  class="w-full h-full object-cover rounded"
                  alt="Preview"
                />
                <svg
                  v-else
                  class="w-8 h-8 text-n-slate-8"
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
              </div>

              <p
                class="font-medium text-sm text-n-slate-12 dark:text-n-slate-11"
              >
                {{ style.label }} ({{ style.dimensions }})
              </p>
              <p class="text-xs text-n-slate-10 dark:text-n-slate-9 mt-1">
                {{ style.description }}
              </p>

              <!-- Selected indicator -->
              <div
                v-if="localProps.receivedStyle === style.value"
                class="mt-2 flex items-center justify-center text-n-blue-10 dark:text-n-blue-9"
              >
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                    clip-rule="evenodd"
                  />
                </svg>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Reply Message -->
      <div class="border-t border-n-weak dark:border-n-slate-6 pt-8 mt-8">
        <div class="mb-8">
          <h5
            class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-4"
          >
            Reply Title
          </h5>
          <input
            v-model="localProps.replyTitle"
            type="text"
            placeholder="Thank you!"
            class="w-full px-4 py-2.5 border border-n-slate-7 dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-blue-7 dark:focus:ring-n-blue-8 transition-colors"
          />
        </div>

        <div class="mb-8">
          <h5
            class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-4"
          >
            Reply Subtitle
          </h5>
          <input
            v-model="localProps.replySubtitle"
            type="text"
            placeholder="(Optional)"
            class="w-full px-4 py-2.5 border border-n-slate-7 dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-blue-7 dark:focus:ring-n-blue-8 transition-colors"
          />
        </div>

        <!-- Reply Style Selection -->
        <div>
          <h5
            class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-4"
          >
            Reply Style
          </h5>
          <div class="grid grid-cols-3 gap-4">
            <div
              v-for="style in styleOptions"
              :key="style.value"
              class="border-2 rounded-lg p-4 cursor-pointer transition-all duration-200 hover:shadow-md"
              :class="
                localProps.replyStyle === style.value
                  ? 'border-n-blue-8 bg-n-blue-1 dark:border-n-blue-9 dark:bg-n-blue-2'
                  : 'border-n-weak hover:border-n-blue-6 dark:border-n-slate-6 dark:hover:border-n-blue-7'
              "
              @click="localProps.replyStyle = style.value"
            >
              <div class="text-center">
                <!-- Style Preview -->
                <div
                  class="mx-auto mb-3 rounded border-2 bg-white dark:bg-n-alpha-2 flex items-center justify-center"
                  :class="
                    style.value === 'icon'
                      ? 'w-24 h-8'
                      : style.value === 'small'
                        ? 'w-24 h-10'
                        : 'w-24 h-20'
                  "
                >
                  <img
                    v-if="
                      localProps.replyImageIdentifier &&
                      getImagePreview(localProps.replyImageIdentifier)
                    "
                    :src="getImagePreview(localProps.replyImageIdentifier)"
                    class="w-full h-full object-cover rounded"
                    alt="Preview"
                  />
                  <svg
                    v-else
                    class="w-8 h-8 text-n-slate-8"
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
                </div>

                <p
                  class="font-medium text-sm text-n-slate-12 dark:text-n-slate-11"
                >
                  {{ style.label }} ({{ style.dimensions }})
                </p>
                <p class="text-xs text-n-slate-10 dark:text-n-slate-9 mt-1">
                  {{ style.description }}
                </p>

                <!-- Selected indicator -->
                <div
                  v-if="localProps.replyStyle === style.value"
                  class="mt-2 flex items-center justify-center text-n-blue-10 dark:text-n-blue-9"
                >
                  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                    <path
                      fill-rule="evenodd"
                      d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Schedule Appointment Section -->
    <div
      class="bg-n-alpha-2 dark:bg-n-alpha-3 p-6 rounded-lg border border-n-weak dark:border-n-slate-6"
    >
      <div class="flex items-center justify-between mb-6">
        <div>
          <h4
            class="text-base font-semibold text-n-slate-12 dark:text-n-slate-11"
          >
            Schedule Appointment - {{ localProps.timeslots?.length || 0 }}
            slot(s) selected
          </h4>
          <p class="text-sm text-n-slate-10 dark:text-n-slate-9 mt-1">
            Add specific time slots for scheduling (click slots below to select)
          </p>
        </div>
      </div>

      <!-- Event Details -->
      <div
        class="mb-6 p-4 bg-white dark:bg-n-alpha-2 rounded-lg border border-n-weak dark:border-n-slate-6"
      >
        <h5
          class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-4"
        >
          Event Details
        </h5>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label
              class="block text-xs font-medium text-n-slate-11 dark:text-n-slate-10 mb-2"
            >
              Event Title
            </label>
            <input
              v-model="localProps.eventTitle"
              type="text"
              placeholder="e.g., Consultation Appointment"
              class="w-full px-3 py-2 text-sm border border-n-slate-7 dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-blue-7"
            />
          </div>
          <div>
            <label
              class="block text-xs font-medium text-n-slate-11 dark:text-n-slate-10 mb-2"
            >
              Timezone
            </label>
            <select
              v-model.number="localProps.timezoneOffset"
              class="w-full px-3 py-2 text-sm border border-n-slate-7 dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-blue-7"
            >
              <option
                v-for="tz in timezoneOptions"
                :key="tz.value"
                :value="tz.value"
              >
                {{ tz.label }}
              </option>
            </select>
          </div>
        </div>
        <div class="mt-4">
          <label
            class="block text-xs font-medium text-n-slate-11 dark:text-n-slate-10 mb-2"
          >
            Description
          </label>
          <textarea
            v-model="localProps.eventDescription"
            rows="2"
            placeholder="Optional description for the appointment"
            class="w-full px-3 py-2 text-sm border border-n-slate-7 dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-blue-7"
          />
        </div>
      </div>

      <!-- Timeslots Management -->
      <div class="flex items-center justify-between mb-4">
        <h5 class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11">
          Time Slots
        </h5>
        <button
          class="px-4 py-2 bg-n-blue-9 dark:bg-n-blue-10 text-white rounded-lg text-sm font-medium hover:bg-n-blue-10 dark:hover:bg-n-blue-11 transition-colors flex items-center gap-2"
          @click="addTimeslot"
        >
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path
              fill-rule="evenodd"
              d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z"
              clip-rule="evenodd"
            />
          </svg>
          Add Slot
        </button>
      </div>

      <div
        v-if="localProps.timeslots.length === 0"
        class="text-center py-12 border-2 border-dashed border-n-slate-6 dark:border-n-slate-7 rounded-lg"
      >
        <svg
          class="mx-auto h-12 w-12 text-n-slate-9 dark:text-n-slate-8"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
        <p class="mt-2 text-sm text-n-slate-11 dark:text-n-slate-10">
          No time slots added yet
        </p>
        <p class="text-xs text-n-slate-10 dark:text-n-slate-9 mt-1">
          Click "Add Slot" to create appointment time slots
        </p>
      </div>

      <div v-else class="grid grid-cols-2 gap-3">
        <div
          v-for="(slot, index) in localProps.timeslots"
          :key="index"
          class="bg-white dark:bg-n-alpha-2 p-4 rounded-lg border border-n-weak dark:border-n-slate-6 hover:shadow-md transition-shadow"
        >
          <div class="flex items-start justify-between mb-3">
            <div class="flex items-center gap-2">
              <svg
                class="w-5 h-5 text-n-blue-9 dark:text-n-blue-10"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z"
                  clip-rule="evenodd"
                />
              </svg>
              <span
                class="text-sm font-medium text-n-slate-12 dark:text-n-slate-11"
              >
                Slot {{ index + 1 }}
              </span>
            </div>
            <button
              class="text-n-ruby-9 hover:text-n-ruby-10 dark:text-n-ruby-10 dark:hover:text-n-ruby-11 transition-colors"
              @click="removeTimeslot(index)"
            >
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                <path
                  fill-rule="evenodd"
                  d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                />
              </svg>
            </button>
          </div>

          <div class="space-y-3">
            <div>
              <label
                class="block text-xs font-medium text-n-slate-11 dark:text-n-slate-10 mb-1"
              >
                Start Time
              </label>
              <input
                v-model="slot.startTime"
                type="datetime-local"
                class="w-full px-3 py-2 text-sm border border-n-weak dark:border-n-slate-6 rounded bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-blue-7"
              />
            </div>
            <div>
              <label
                class="block text-xs font-medium text-n-slate-11 dark:text-n-slate-10 mb-1"
              >
                Duration (seconds)
              </label>
              <input
                v-model.number="slot.duration"
                type="number"
                placeholder="e.g., 3600 (1 hour)"
                class="w-full px-3 py-2 text-sm border border-n-weak dark:border-n-slate-6 rounded bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-blue-7"
              />
              <p class="text-xs text-n-slate-10 dark:text-n-slate-9 mt-1">
                {{ Math.floor(slot.duration / 60) }} minutes
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
