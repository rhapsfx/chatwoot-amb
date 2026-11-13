<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import AppleMessagesImagesAPI from 'dashboard/api/appleAmbMessagesImages';

const props = defineProps({
  modelValue: {
    type: String,
    default: '',
  },
  // eslint-disable-next-line vue/no-unused-properties
  accountId: {
    type: Number,
    required: true,
  },
  inboxId: {
    type: Number,
    required: true,
  },
  // eslint-disable-next-line vue/no-unused-properties
  imageType: {
    type: String,
    default: 'template', // or 'message'
  },
  label: {
    type: String,
    default: 'Select Shared Image',
  },
  showPreview: {
    type: Boolean,
    default: true,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
  availableImages: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:modelValue', 'imageSelected']);

// Local state
const sharedImages = ref([]);
const loading = ref(false);
const selectedImageIdentifier = ref(props.modelValue || '');

// Computed
const allImages = computed(() => {
  // Combine shared images from API with available images from prop
  const combined = [...sharedImages.value];

  // Add images from availableImages prop that aren't already in shared images
  props.availableImages.forEach(img => {
    if (!combined.find(si => si.identifier === img.identifier)) {
      combined.push({
        identifier: img.identifier,
        description: img.description || img.originalName || img.identifier,
        image_url: img.preview || img.image_url,
      });
    }
  });

  return combined;
});

const selectedImage = computed(() => {
  if (!selectedImageIdentifier.value) return null;
  return allImages.value.find(
    img => img.identifier === selectedImageIdentifier.value
  );
});

const hasImages = computed(() => allImages.value.length > 0);

// Methods
const loadSharedImages = async () => {
  if (!props.inboxId) return;

  loading.value = true;
  try {
    const response = await AppleMessagesImagesAPI.get({
      inboxId: props.inboxId,
    });
    sharedImages.value = response.data.map(img => ({
      identifier: img.identifier,
      description: img.description || img.original_name || img.identifier,
      image_url: img.image_url,
      id: img.id,
    }));
  } catch (error) {
    // Error loading images - handled silently
  } finally {
    loading.value = false;
  }
};

const handleImageSelect = identifier => {
  selectedImageIdentifier.value = identifier;
  emit('update:modelValue', identifier);

  const image = allImages.value.find(img => img.identifier === identifier);
  emit('imageSelected', { identifier, image });
};

const clearSelection = () => {
  handleImageSelect('');
};

// Watchers
watch(
  () => props.modelValue,
  newValue => {
    if (newValue !== selectedImageIdentifier.value) {
      selectedImageIdentifier.value = newValue || '';
    }
  }
);

watch(
  () => props.inboxId,
  newInboxId => {
    if (newInboxId) {
      loadSharedImages();
    }
  },
  { immediate: true }
);

// Lifecycle
onMounted(() => {
  if (props.inboxId) {
    loadSharedImages();
  }
});
</script>

<template>
  <!-- eslint-disable @intlify/vue-i18n/no-raw-text -->
  <!-- eslint-disable vue/no-bare-strings-in-template -->
  <div class="shared-image-selector">
    <label
      class="block text-xs font-medium text-slate-700 dark:text-n-slate-10 mb-1"
    >
      {{ label }}
    </label>

    <div class="flex items-center space-x-2">
      <select
        v-model="selectedImageIdentifier"
        :disabled="disabled || loading"
        class="flex-1 px-2 py-1.5 text-sm border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white disabled:opacity-50 disabled:cursor-not-allowed"
        @change="handleImageSelect(selectedImageIdentifier)"
      >
        <option value="">No image</option>
        <option
          v-for="image in allImages"
          :key="image.identifier"
          :value="image.identifier"
        >
          {{ image.description }}
        </option>
      </select>

      <button
        v-if="selectedImageIdentifier"
        type="button"
        class="px-2 py-1.5 text-xs text-slate-600 dark:text-n-slate-11 hover:text-slate-800 dark:hover:text-n-slate-10 border border-slate-300 dark:border-n-slate-6 rounded-md transition-colors"
        :disabled="disabled"
        @click="clearSelection"
      >
        Clear
      </button>
    </div>

    <!-- Preview -->
    <div
      v-if="showPreview && selectedImage && selectedImage.image_url"
      class="mt-2"
    >
      <img
        :src="selectedImage.image_url"
        :alt="selectedImage.description"
        class="h-16 rounded border border-slate-300 dark:border-n-slate-6 object-cover"
      />
    </div>

    <!-- Helper text -->
    <p
      v-if="!hasImages && !loading"
      class="mt-1 text-xs text-slate-500 dark:text-n-slate-11"
    >
      No shared images available. Upload images via the composer.
    </p>

    <p
      v-else-if="hasImages"
      class="mt-1 text-xs text-slate-500 dark:text-n-slate-11"
    >
      Shared images are available across all forms and messages in this inbox.
    </p>

    <p v-if="loading" class="mt-1 text-xs text-slate-500 dark:text-n-slate-11">
      Loading images...
    </p>
  </div>
</template>

<style scoped>
.shared-image-selector {
  /* Tailwind classes handle all styling */
}
</style>
