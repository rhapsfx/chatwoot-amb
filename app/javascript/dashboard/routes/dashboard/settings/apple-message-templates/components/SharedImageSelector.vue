<script setup>
import { ref, onMounted, computed } from 'vue';
import { useAlert } from 'dashboard/composables';
import SharedAppleImagesAPI from 'dashboard/api/sharedAppleImages';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: {
    type: String,
    default: '',
  },
  // eslint-disable-next-line vue/no-unused-properties
  accountId: {
    type: [Number, String],
    required: true,
  },
  imageType: {
    type: String,
    default: 'template',
    validator: value => ['template', 'message', 'form'].includes(value),
  },
});

const emit = defineEmits(['update:modelValue', 'imageSelected']);

const sharedImages = ref([]);
const loading = ref(false);
const error = ref(null);

// Load shared images from API
const loadSharedImages = async () => {
  loading.value = true;
  error.value = null;

  try {
    // ApiClient with accountScoped: true automatically uses account from URL
    const response = await SharedAppleImagesAPI.get();

    // API returns { data: { data: [...], meta: {...} } }
    // So we need response.data.data to get the actual images array
    sharedImages.value = response.data?.data || [];
  } catch (err) {
    error.value = 'Failed to load shared images';
    sharedImages.value = [];
  } finally {
    loading.value = false;
  }
};

// Watch for inbox selection changes (optional - could be used for filtering in future)
// For now, we load all account-wide shared images on mount
// watch(selectedInboxId, () => {
//   loadSharedImages();
// });

// Handle image selection
const selectImage = image => {
  emit('update:modelValue', image.identifier);
  emit('imageSelected', image);
};

// Clear selection
const clearSelection = () => {
  emit('update:modelValue', '');
  emit('imageSelected', null);
};

// Get selected image
const selectedImage = computed(() => {
  if (!props.modelValue) return null;
  return sharedImages.value.find(img => img.identifier === props.modelValue);
});

// Refresh button
const refreshImages = () => {
  loadSharedImages();
};

// Upload new image
const uploadNewImage = () => {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'image/png,image/jpeg,image/jpg,image/gif';

  input.onchange = async e => {
    const file = e.target.files[0];
    if (!file) return;

    // Validate file size (5MB max)
    if (file.size > 5 * 1024 * 1024) {
      useAlert('File size must be less than 5MB');
      return;
    }

    try {
      loading.value = true;

      // Convert to base64
      const reader = new FileReader();
      reader.onload = async event => {
        const base64Data = event.target.result.split(',')[1];

        // Generate identifier from filename
        const fileNameWithoutExt = file.name.replace(/\.[^/.]+$/, '');
        const identifier = fileNameWithoutExt
          .replace(/[^a-zA-Z0-9]/g, '_')
          .toLowerCase();

        // Create image record
        const imageData = {
          shared_apple_image: {
            identifier: `${identifier}_${Date.now()}`,
            image_type: props.imageType,
            description: file.name,
            original_name: file.name,
          },
          image_data: base64Data,
          filename: file.name,
          content_type: file.type,
        };

        await SharedAppleImagesAPI.create(imageData);

        // Reload images
        await loadSharedImages();
      };

      reader.readAsDataURL(file);
    } catch (err) {
      useAlert('Failed to upload image. Please try again.');
    } finally {
      loading.value = false;
    }
  };

  input.click();
};

// Delete image
const deleteImage = async image => {
  try {
    loading.value = true;

    // Delete via API
    await SharedAppleImagesAPI.delete(image.id);

    // Reload images
    await loadSharedImages();

    // Clear selection if deleted image was selected
    if (props.modelValue === image.identifier) {
      clearSelection();
    }

    useAlert('Image deleted successfully');
  } catch (err) {
    useAlert('Failed to delete image. Please try again.');
  } finally {
    loading.value = false;
  }
};

// Load on mount
onMounted(() => {
  loadSharedImages();
});
</script>

<template>
  <!-- eslint-disable @intlify/vue-i18n/no-raw-text -->
  <!-- eslint-disable vue/no-bare-strings-in-template -->
  <div class="shared-image-selector">
    <!-- Header with info and refresh -->
    <div class="flex items-center justify-between mb-3">
      <div class="flex items-center gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          Shared Images Library
        </span>
        <span
          class="text-xs text-n-slate-10 bg-n-alpha-2 px-2 py-0.5 rounded-full"
        >
          {{ sharedImages.length }} available
        </span>
      </div>
      <div class="flex items-center gap-2">
        <Button
          icon="i-lucide-upload"
          xs
          solid
          blue
          :disabled="loading"
          @click="uploadNewImage"
        >
          Upload Image
        </Button>
        <Button
          icon="i-lucide-refresh-cw"
          xs
          :disabled="loading"
          @click="refreshImages"
        >
          Refresh
        </Button>
      </div>
    </div>

    <!-- Helper text -->
    <p class="text-xs text-n-slate-10 mb-3">
      Shared images are available across all Apple Messages conversations in
      your account. Upload new images using the button above or select from
      existing images below.
    </p>

    <!-- Loading state -->
    <div
      v-if="loading"
      class="flex items-center justify-center py-8 text-n-slate-10"
    >
      <div
        class="animate-spin rounded-full h-8 w-8 border-b-2 border-n-blue-9"
      />
      <span class="ml-3 text-sm">Loading shared images...</span>
    </div>

    <!-- Error state -->
    <div
      v-else-if="error"
      class="p-4 bg-n-ruby-1 border border-n-ruby-7 rounded-lg text-n-ruby-11 text-sm"
    >
      {{ error }}
    </div>

    <!-- Empty state -->
    <div
      v-else-if="sharedImages.length === 0"
      class="text-center py-8 bg-n-alpha-2 rounded-lg border-2 border-dashed border-n-weak"
    >
      <div class="text-4xl mb-2">📷</div>
      <p class="text-sm text-n-slate-11 mb-1">No shared images yet</p>
      <p class="text-xs text-n-slate-10">
        Upload images from the Reply Box to add them to the shared library
      </p>
    </div>

    <!-- Image grid -->
    <div v-else class="space-y-3">
      <!-- Selected image preview (if any) -->
      <div
        v-if="selectedImage"
        class="p-3 bg-n-blue-1 border border-n-blue-7 rounded-lg"
      >
        <div class="flex items-center gap-3">
          <img
            :src="selectedImage.image_url"
            :alt="selectedImage.original_name"
            class="w-16 h-16 object-contain rounded-lg border-2 border-n-blue-8 bg-n-alpha-1 dark:bg-n-alpha-2"
          />
          <div class="flex-1 min-w-0">
            <div class="text-sm font-medium text-n-slate-12 truncate">
              {{ selectedImage.original_name || selectedImage.description }}
            </div>
            <div class="text-xs text-n-slate-10">
              {{ selectedImage.identifier }}
            </div>
          </div>
          <Button icon="i-lucide-x" xs ruby @click="clearSelection">
            Clear
          </Button>
        </div>
      </div>

      <!-- Image grid -->
      <div class="grid grid-cols-3 gap-2 max-h-96 overflow-y-auto">
        <div
          v-for="image in sharedImages"
          :key="image.identifier"
          class="relative cursor-pointer border-2 rounded-lg overflow-hidden transition-all group"
          :class="
            modelValue === image.identifier
              ? 'border-n-blue-8 bg-n-blue-1 ring-2 ring-n-blue-7'
              : 'border-n-weak hover:border-n-blue-7'
          "
          @click="selectImage(image)"
        >
          <!-- Image -->
          <img
            :src="image.image_url"
            :alt="image.original_name || image.description"
            class="w-full h-24 object-contain bg-n-alpha-1 dark:bg-n-alpha-2"
          />

          <!-- Hover overlay for delete button -->
          <div
            class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-50 transition-opacity"
          />

          <!-- Selected checkmark -->
          <div
            v-if="modelValue === image.identifier"
            class="absolute top-2 right-2 bg-n-blue-9 rounded-full w-6 h-6 flex items-center justify-center shadow-lg z-10"
          >
            <span class="text-white text-sm">✓</span>
          </div>

          <!-- Delete button (appears on hover) -->
          <button
            class="absolute top-2 left-2 opacity-0 group-hover:opacity-100 bg-red-500 hover:bg-red-600 rounded-full w-8 h-8 flex items-center justify-center shadow-lg transition-all z-10"
            title="Delete image"
            @click.stop="deleteImage(image)"
          >
            <svg
              class="w-4 h-4 text-white"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2.5"
                d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
              />
            </svg>
          </button>

          <!-- Image name label at bottom (always visible) -->
          <div
            class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black via-black/95 to-transparent text-white px-2 py-2"
            :title="image.original_name || image.description"
          >
            <div class="text-sm font-semibold truncate drop-shadow-lg">
              {{ image.original_name || image.description }}
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
