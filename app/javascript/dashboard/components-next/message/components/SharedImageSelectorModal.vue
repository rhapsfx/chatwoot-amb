<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useSharedAppleImages } from 'dashboard/composables/useSharedAppleImages';

const props = defineProps({
  modelValue: {
    type: String,
    default: '',
  },
  accountId: {
    type: Number,
    required: true,
  },
  imageType: {
    type: String,
    default: 'system',
    validator: value => ['system', 'branding', 'template'].includes(value),
  },
  allowUpload: {
    type: Boolean,
    default: true,
  },
  // eslint-disable-next-line vue/no-unused-properties
  multiple: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update:modelValue', 'imageSelected']);

const { t } = useI18n();

// State
const activeTab = ref(props.imageType);
const searchQuery = ref('');
const selectedIdentifier = ref(props.modelValue);

// Composable
const { images, loading, error, fetchImagesByType, createImage, deleteImage } =
  useSharedAppleImages(props.accountId);

// Tab configuration
const tabs = [
  {
    id: 'system',
    label: t('APPLE_MESSAGES.SHARED_IMAGES.TABS.SYSTEM'),
    icon: '⚙️',
  },
  {
    id: 'branding',
    label: t('APPLE_MESSAGES.SHARED_IMAGES.TABS.BRANDING'),
    icon: '🎨',
  },
  {
    id: 'template',
    label: t('APPLE_MESSAGES.SHARED_IMAGES.TABS.TEMPLATE'),
    icon: '📋',
  },
];

// Computed
const filteredImages = computed(() => {
  if (!searchQuery.value) return images.value;

  const query = searchQuery.value.toLowerCase();
  return images.value.filter(
    img =>
      img.identifier?.toLowerCase().includes(query) ||
      img.description?.toLowerCase().includes(query)
  );
});

const hasImages = computed(() => filteredImages.value.length > 0);

const isAdmin = computed(() => {
  // Check if user has admin role - integrate with your auth system
  return true; // For now, allow all users
});

const canUpload = computed(() => props.allowUpload && isAdmin.value);

// Methods
const loadImages = async () => {
  try {
    await fetchImagesByType(activeTab.value);
  } catch (err) {
    // Error is already handled by the composable
  }
};

const selectImage = image => {
  selectedIdentifier.value = image.identifier;
  emit('update:modelValue', image.identifier);
  emit('imageSelected', image);
};

const isSelected = image => {
  return selectedIdentifier.value === image.identifier;
};

const handleTabChange = async tab => {
  activeTab.value = tab;
  searchQuery.value = '';
  await loadImages();
};

const triggerImageUpload = () => {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'image/*';
  input.onchange = async e => {
    const file = e.target.files[0];
    if (!file) return;

    // Validate file size (max 5MB)
    if (file.size > 5 * 1024 * 1024) {
      useAlert(t('APPLE_MESSAGES.SHARED_IMAGES.ERRORS.FILE_TOO_LARGE'));
      return;
    }

    try {
      // Convert file to base64
      const reader = new FileReader();
      reader.onload = async event => {
        const base64Data = event.target.result.split(',')[1];

        // Generate identifier from filename
        const fileNameWithoutExt = file.name.replace(/\.[^/.]+$/, '');
        const identifier = fileNameWithoutExt
          .replace(/[^a-zA-Z0-9]/g, '_')
          .toLowerCase();

        // Create image record
        await createImage({
          identifier: `${activeTab.value}_${identifier}_${Date.now()}`,
          image_type: activeTab.value,
          description: file.name,
          base64_data: base64Data,
        });

        // Reload images
        await loadImages();
      };
      reader.readAsDataURL(file);
    } catch (err) {
      useAlert('Failed to upload image. Please try again.');
    }
  };
  input.click();
};

const handleDeleteImage = async image => {
  try {
    await deleteImage(image.id);
    if (selectedIdentifier.value === image.identifier) {
      selectedIdentifier.value = '';
      emit('update:modelValue', '');
    }
    useAlert('Image deleted successfully');
  } catch (err) {
    useAlert('Failed to delete image. Please try again.');
  }
};

// Watch for external changes to modelValue
watch(
  () => props.modelValue,
  newValue => {
    selectedIdentifier.value = newValue;
  }
);

// Lifecycle
onMounted(() => {
  loadImages();
});
</script>

<template>
  <!-- eslint-disable @intlify/vue-i18n/no-raw-text -->
  <!-- eslint-disable vue/no-bare-strings-in-template -->
  <div class="shared-image-selector">
    <!-- Header with Tabs -->
    <div class="flex items-center justify-between mb-4">
      <div class="flex space-x-2">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          class="px-4 py-2 text-sm font-medium rounded-lg transition-all duration-200"
          :class="
            activeTab === tab.id
              ? 'bg-blue-600 text-white shadow-md'
              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
          "
          @click="handleTabChange(tab.id)"
        >
          <span class="mr-2">{{ tab.icon }}</span>
          {{ tab.label }}
        </button>
      </div>

      <!-- Upload Button -->
      <button
        v-if="canUpload"
        class="px-4 py-2 text-sm font-medium bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors flex items-center"
        @click="triggerImageUpload"
      >
        <span class="mr-2">📤</span>
        {{ $t('APPLE_MESSAGES.SHARED_IMAGES.UPLOAD') }}
      </button>
    </div>

    <!-- Search Bar -->
    <div class="mb-4">
      <input
        v-model="searchQuery"
        type="text"
        :placeholder="$t('APPLE_MESSAGES.SHARED_IMAGES.SEARCH_PLACEHOLDER')"
        class="w-full px-4 py-2 border border-gray-300 rounded-lg bg-white text-gray-900 focus:border-blue-500 focus:ring-2 focus:ring-blue-500 focus:ring-opacity-20 transition-all"
      />
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center py-12">
      <div
        class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"
      />
      <span class="ml-3 text-sm text-gray-600">
        {{ $t('APPLE_MESSAGES.SHARED_IMAGES.LOADING') }}
      </span>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="flex items-center justify-center py-12">
      <div class="text-center">
        <span class="text-4xl mb-2">⚠️</span>
        <p class="text-sm text-red-600">
          {{ $t('APPLE_MESSAGES.SHARED_IMAGES.ERROR') }}
        </p>
        <button
          class="mt-4 px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          @click="loadImages"
        >
          {{ $t('APPLE_MESSAGES.SHARED_IMAGES.RETRY') }}
        </button>
      </div>
    </div>

    <!-- Empty State -->
    <div v-else-if="!hasImages" class="flex items-center justify-center py-12">
      <div class="text-center">
        <span class="text-6xl mb-4">📷</span>
        <p class="text-sm text-gray-600 mb-2">
          {{ $t('APPLE_MESSAGES.SHARED_IMAGES.EMPTY_STATE') }}
        </p>
        <p class="text-xs text-gray-500">
          {{ $t('APPLE_MESSAGES.SHARED_IMAGES.EMPTY_STATE_HINT') }}
        </p>
      </div>
    </div>

    <!-- Image Grid -->
    <div
      v-else
      class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3"
    >
      <div
        v-for="image in filteredImages"
        :key="image.id"
        class="group relative cursor-pointer rounded-lg overflow-hidden border-2 transition-all duration-200 hover:shadow-lg aspect-square"
        :class="
          isSelected(image)
            ? 'border-blue-600 bg-blue-50 ring-2 ring-blue-600 ring-opacity-50'
            : 'border-gray-200 hover:border-blue-500'
        "
        @click="selectImage(image)"
      >
        <!-- Image Preview -->
        <div
          class="w-full h-full bg-gray-100 flex items-center justify-center overflow-hidden"
        >
          <img
            v-if="image.image_url"
            :src="image.image_url"
            :alt="image.description || image.identifier"
            class="w-full h-full object-contain"
            loading="lazy"
          />
          <span v-else class="text-4xl">📷</span>
        </div>

        <!-- Image name label with gradient overlay (always visible) -->
        <div
          class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black via-black/90 to-transparent text-white text-xs px-2 py-2"
        >
          <div
            class="font-medium truncate text-shadow-sm"
            :title="
              image.original_name || image.description || image.identifier
            "
          >
            {{ image.original_name || image.description || image.identifier }}
          </div>
        </div>

        <!-- Selected Indicator -->
        <div
          v-if="isSelected(image)"
          class="absolute top-2 right-2 w-6 h-6 bg-blue-600 rounded-full flex items-center justify-center shadow-lg z-10"
        >
          <span class="text-white text-sm font-bold">✓</span>
        </div>

        <!-- Delete button (appears on hover) -->
        <button
          v-if="isAdmin"
          class="absolute top-2 left-2 opacity-0 group-hover:opacity-100 w-8 h-8 bg-red-600 hover:bg-red-700 rounded-full flex items-center justify-center shadow-lg transition-all z-10"
          title="Delete image"
          @click.stop="handleDeleteImage(image)"
        >
          <span class="text-white text-base">🗑️</span>
        </button>

        <!-- Hover overlay for darkening -->
        <div
          class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-40 transition-opacity pointer-events-none"
        />
      </div>
    </div>

    <!-- Image Count -->
    <div
      v-if="hasImages && !loading"
      class="mt-4 text-center text-xs text-gray-500"
    >
      {{
        $t('APPLE_MESSAGES.SHARED_IMAGES.IMAGE_COUNT', {
          count: filteredImages.length,
        })
      }}
    </div>
  </div>
</template>

<style scoped>
.shared-image-selector {
  @apply w-full;
}
</style>
