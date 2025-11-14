<script setup>
import { ref, watch, computed, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import { createRichLinkPreview } from 'dashboard/helper/appleMessagesRichLink';

const props = defineProps({
  properties: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['update:properties']);

const { t } = useI18n();

// Helper to normalize message objects from snake_case or camelCase to camelCase
const normalizeMessageObject = msg => {
  if (!msg) {
    return {
      title: '',
      subtitle: '',
      imageIdentifier: '',
      style: 'large',
    };
  }

  return {
    title: msg.title || '',
    subtitle: msg.subtitle || '',
    // Handle both snake_case and camelCase
    imageIdentifier: msg.imageIdentifier || msg.image_identifier || '',
    style: msg.style || 'large',
  };
};

// Flag to prevent infinite loop between watchers
const isUpdatingFromProps = ref(false);

const localProps = ref({
  title: '',
  description: '',
  pages: [],
  receivedMessage: {
    title: '',
    subtitle: '',
    imageIdentifier: '',
    style: 'large',
  },
  replyMessage: {
    title: '',
    subtitle: '',
    imageIdentifier: '',
    style: 'large',
  },
  images: [],
});

// Watch for props changes (e.g., when template data loads)
watch(
  () => props.properties,
  async newProps => {
    isUpdatingFromProps.value = true;

    if (newProps && Object.keys(newProps).length > 0) {
      // Handle nested form structure from database
      // Database may store form data nested in a 'form' object
      const form = newProps.form || {};

      // Create a new object to trigger reactivity
      localProps.value = {
        // Form details (may be nested in form object)
        title: newProps.title || form.title || '',
        description: newProps.description || form.description || '',
        pages: newProps.pages || form.pages || [],

        // Message configuration (flat structure)
        // Handle both camelCase (frontend) and snake_case (database)
        receivedMessage: normalizeMessageObject(
          newProps.receivedMessage ||
            newProps.received_message ||
            form.receivedMessage ||
            form.received_message
        ),
        replyMessage: normalizeMessageObject(
          newProps.replyMessage ||
            newProps.reply_message ||
            form.replyMessage ||
            form.reply_message
        ),

        // Images - try multiple possible locations
        images: newProps.images || form.images || [],
      };
    }

    // Wait for Vue to process all reactive updates before resetting flag
    await nextTick();
    isUpdatingFromProps.value = false;
  },
  { deep: true, immediate: true }
);

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

// Automatically sync reply image with received image
watch(
  () => localProps.value.receivedMessage?.imageIdentifier,
  newIdentifier => {
    if (localProps.value.replyMessage) {
      localProps.value.replyMessage.imageIdentifier = newIdentifier || '';
    }
  }
);

// Automatically sync received message title with form title
watch(
  () => localProps.value.title,
  newTitle => {
    if (localProps.value.receivedMessage) {
      localProps.value.receivedMessage.title = newTitle || '';
    }
  }
);

// Automatically sync received message subtitle with form description
watch(
  () => localProps.value.description,
  newDescription => {
    if (
      localProps.value.receivedMessage &&
      (!localProps.value.receivedMessage.subtitle ||
        localProps.value.receivedMessage.subtitle ===
          localProps.value.description)
    ) {
      localProps.value.receivedMessage.subtitle = newDescription || '';
    }
  }
);

const fieldTypes = computed(() => [
  {
    value: 'text',
    label: t('APPLE_FORM.FIELD_TYPES.TEXT'),
    icon: '📝',
    description: t('APPLE_FORM.FIELD_DESCRIPTIONS.TEXT'),
  },
  {
    value: 'textArea',
    label: t('APPLE_FORM.FIELD_TYPES.TEXT_AREA'),
    icon: '📄',
    description: t('APPLE_FORM.FIELD_DESCRIPTIONS.TEXT_AREA'),
  },
  {
    value: 'email',
    label: t('APPLE_FORM.FIELD_TYPES.EMAIL'),
    icon: '📧',
    description: t('APPLE_FORM.FIELD_DESCRIPTIONS.EMAIL'),
  },
  {
    value: 'phone',
    label: t('APPLE_FORM.FIELD_TYPES.PHONE'),
    icon: '📱',
    description: t('APPLE_FORM.FIELD_DESCRIPTIONS.PHONE'),
  },
  {
    value: 'singleSelect',
    label: t('APPLE_FORM.FIELD_TYPES.SINGLE_CHOICE'),
    icon: '🔘',
    description: t('APPLE_FORM.FIELD_DESCRIPTIONS.SINGLE_CHOICE'),
  },
  {
    value: 'multiSelect',
    label: t('APPLE_FORM.FIELD_TYPES.MULTIPLE_CHOICE'),
    icon: '☑️',
    description: t('APPLE_FORM.FIELD_DESCRIPTIONS.MULTIPLE_CHOICE'),
  },
  {
    value: 'dateTime',
    label: t('APPLE_FORM.FIELD_TYPES.DATE_TIME'),
    icon: '📅',
    description: t('APPLE_FORM.FIELD_DESCRIPTIONS.DATE_TIME'),
  },
  {
    value: 'toggle',
    label: t('APPLE_FORM.FIELD_TYPES.TOGGLE'),
    icon: '🔄',
    description: t('APPLE_FORM.FIELD_DESCRIPTIONS.TOGGLE'),
  },
  {
    value: 'stepper',
    label: t('APPLE_FORM.FIELD_TYPES.STEPPER'),
    icon: '🔢',
    description: t('APPLE_FORM.FIELD_DESCRIPTIONS.STEPPER'),
  },
  {
    value: 'richLink',
    label: t('APPLE_FORM.FIELD_TYPES.RICH_LINK'),
    icon: '🔗',
    description: t('APPLE_FORM.FIELD_DESCRIPTIONS.RICH_LINK'),
  },
]);

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

const currentPageIndex = ref(0);
const showAddFieldModal = ref(false);

const newField = ref({
  item_id: '',
  item_type: 'text',
  title: '',
  description: '',
  required: false,
  placeholder: '',
  options: [{ value: '', title: '' }],
  min_value: 1,
  max_value: 10,
  max_length: null,
  url: '',
  default_value: '',
  keyboard_type: 'default',
  text_content_type: '',
  regex: '',
  input_type: 'singleline',
  label_text: '',
  prefix_text: '',
  maximum_character_count: null,
  hint_text: '',
  date_format: 'MM/dd/yyyy',
  start_date: '',
  maximum_date: '',
  minimum_date: '',
  picker_title: '',
  selected_item_index: 0,
  multiple_selection: false,
});

const currentPage = computed(() => {
  if (!localProps.value.pages || localProps.value.pages.length === 0) {
    return null;
  }
  return localProps.value.pages[currentPageIndex.value];
});

const fileInputRef = ref(null);

const getImagePreviewUrl = identifier => {
  const image = localProps.value.images.find(
    img => img.identifier === identifier
  );

  if (!image) return null;
  return (
    image.preview ||
    image.imageUrl ||
    image.image_url ||
    `data:image/jpeg;base64,${image.data}`
  );
};

const handleImageUpload = () => {
  if (fileInputRef.value) {
    fileInputRef.value.click();
  }
};

const handleFileSelected = async event => {
  const file = event.target.files[0];
  if (!file) return;

  if (!file.type.startsWith('image/')) {
    useAlert(t('APPLE_FORM.IMAGE_UPLOAD.INVALID_FILE_TYPE'));
    return;
  }

  const reader = new FileReader();
  reader.onload = e => {
    const imageData = {
      identifier: `${Date.now()}_${file.name.replace(/[^a-zA-Z0-9]/g, '_')}`,
      data: e.target.result.split(',')[1],
      preview: e.target.result,
      description: file.name,
      originalName: file.name,
      size: file.size,
    };

    localProps.value.images.push(imageData);
    localProps.value.receivedMessage.imageIdentifier = imageData.identifier;
  };
  reader.readAsDataURL(file);

  event.target.value = '';
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

const addNewPage = () => {
  const pageNumber = localProps.value.pages.length + 1;
  const newPage = {
    page_id: `page_${pageNumber}`,
    title: `${t('APPLE_FORM.PAGE_LABEL')} ${pageNumber}`,
    description: '',
    items: [],
  };

  localProps.value.pages.push(newPage);
  currentPageIndex.value = localProps.value.pages.length - 1;
};

const removePage = index => {
  if (localProps.value.pages.length > 1) {
    localProps.value.pages.splice(index, 1);
    if (currentPageIndex.value >= localProps.value.pages.length) {
      currentPageIndex.value = localProps.value.pages.length - 1;
    }
  }
};

const resetNewField = () => {
  newField.value = {
    item_id: '',
    item_type: 'text',
    title: '',
    description: '',
    required: false,
    placeholder: '',
    options: [{ value: '', title: '' }],
    min_value: 1,
    max_value: 10,
    max_length: null,
    url: '',
    default_value: '',
    keyboard_type: 'default',
    text_content_type: '',
    regex: '',
    input_type: 'singleline',
    label_text: '',
    prefix_text: '',
    maximum_character_count: null,
    hint_text: '',
    date_format: 'MM/dd/yyyy',
    start_date: '',
    maximum_date: '',
    minimum_date: '',
    picker_title: '',
    selected_item_index: 0,
    multiple_selection: false,
  };
};

const openAddFieldModal = () => {
  resetNewField();
  showAddFieldModal.value = true;
};

const addFieldToCurrentPage = () => {
  if (!currentPage.value) return;

  const isEditing = typeof newField.value.editingIndex === 'number';

  if (!newField.value.item_id && !isEditing) {
    const fieldCount = currentPage.value.items.length;
    newField.value.item_id = `field_${currentPageIndex.value + 1}_${fieldCount + 1}`;
  }

  const fieldData = { ...newField.value };
  delete fieldData.editingIndex;

  if (!['singleSelect', 'multiSelect'].includes(fieldData.item_type)) {
    delete fieldData.options;
  }

  if (fieldData.item_type !== 'stepper') {
    delete fieldData.min_value;
    delete fieldData.max_value;
  }

  if (!['text', 'textArea', 'email', 'phone'].includes(fieldData.item_type)) {
    delete fieldData.max_length;
    delete fieldData.keyboard_type;
    delete fieldData.text_content_type;
  }

  if (fieldData.item_type !== 'richLink') {
    delete fieldData.url;
  }

  if (!fieldData.keyboard_type || fieldData.keyboard_type === 'default') {
    delete fieldData.keyboard_type;
  }
  if (!fieldData.text_content_type) {
    delete fieldData.text_content_type;
  }

  if (fieldData.options) {
    fieldData.options = fieldData.options
      .filter(opt => opt.value && opt.title)
      .map(opt => ({
        ...opt,
        // Convert camelCase imageIdentifier back to snake_case for database
        image_identifier: opt.imageIdentifier || opt.image_identifier || '',
      }));
  }

  if (isEditing) {
    currentPage.value.items[newField.value.editingIndex] = fieldData;
  } else {
    currentPage.value.items.push(fieldData);
  }

  showAddFieldModal.value = false;
  resetNewField();
};

const removeField = fieldIndex => {
  // eslint-disable-next-line no-console
  console.log('removeField called with index:', fieldIndex);
  if (currentPage.value && currentPage.value.items) {
    currentPage.value.items.splice(fieldIndex, 1);
    // eslint-disable-next-line no-console
    console.log(
      'Field removed, remaining items:',
      currentPage.value.items.length
    );
  }
};

const editField = fieldIndex => {
  if (currentPage.value && currentPage.value.items) {
    const field = currentPage.value.items[fieldIndex];
    newField.value = { ...field };

    // Normalize options to handle both snake_case and camelCase
    if (!newField.value.options || newField.value.options.length === 0) {
      newField.value.options = [{ value: '', title: '' }];
    } else {
      // Convert snake_case image_identifier to camelCase imageIdentifier for the editor
      newField.value.options = newField.value.options.map(opt => ({
        ...opt,
        imageIdentifier: opt.imageIdentifier || opt.image_identifier || '',
      }));
    }

    newField.value.editingIndex = fieldIndex;
    showAddFieldModal.value = true;
  }
};

const addOption = () => {
  newField.value.options.push({ value: '', title: '' });
};

const removeOption = index => {
  if (newField.value.options.length > 1) {
    newField.value.options.splice(index, 1);
  }
};

const isLoadingRichLink = ref(false);

const fetchRichLinkData = async () => {
  if (!newField.value.url) {
    useAlert('Please enter a URL first');
    return;
  }

  isLoadingRichLink.value = true;
  try {
    const result = await createRichLinkPreview(newField.value.url);

    if (result.success && result.richLinkData) {
      // Auto-fill title if empty
      if (!newField.value.title && result.richLinkData.title) {
        newField.value.title = result.richLinkData.title;
      }

      // Auto-fill description if empty
      if (!newField.value.description && result.richLinkData.description) {
        newField.value.description = result.richLinkData.description;
      }

      useAlert(t('TEMPLATES.BUILDER.APPLE_FORM.RICH_LINK_AUTOFILL.SUCCESS'));
    } else {
      useAlert(
        t('TEMPLATES.BUILDER.APPLE_FORM.RICH_LINK_AUTOFILL.WARNING'),
        'warning'
      );
    }
  } catch (error) {
    useAlert(
      t('TEMPLATES.BUILDER.APPLE_FORM.RICH_LINK_AUTOFILL.ERROR'),
      'error'
    );
  } finally {
    isLoadingRichLink.value = false;
  }
};

// Initialize with one page if empty
if (localProps.value.pages.length === 0) {
  addNewPage();
}
</script>

<template>
  <div class="space-y-6">
    <!-- Hidden file input for image upload -->
    <input
      ref="fileInputRef"
      type="file"
      accept="image/*"
      class="hidden"
      @change="handleFileSelected"
    />

    <!-- Images Section - Gallery Grid -->
    <div
      class="bg-n-alpha-2 dark:bg-n-alpha-3 p-6 rounded-lg border border-n-weak dark:border-n-slate-6"
    >
      <div class="flex justify-between items-center mb-4">
        <div>
          <h4
            class="text-base font-semibold text-n-slate-12 dark:text-n-slate-11"
          >
            Choose 1 image for the Form
          </h4>
          <p class="text-sm text-n-slate-10 dark:text-n-slate-9 mt-1">
            Upload images to use in your form messages
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
        v-if="localProps.images.length === 0"
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
          Click "Add Image" to upload images for your form
        </p>
      </div>

      <div v-else class="grid grid-cols-4 gap-3">
        <div
          v-for="(image, index) in localProps.images"
          :key="image.identifier"
          class="relative group border-2 rounded-lg overflow-hidden transition-all duration-200 cursor-pointer aspect-square"
          :class="
            localProps.receivedMessage.imageIdentifier === image.identifier
              ? 'border-n-blue-8 ring-2 ring-n-blue-8 dark:border-n-blue-9 dark:ring-n-blue-9'
              : 'border-n-weak hover:border-n-blue-6 dark:border-n-slate-6 dark:hover:border-n-blue-7'
          "
          @click="localProps.receivedMessage.imageIdentifier = image.identifier"
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
            v-if="
              localProps.receivedMessage.imageIdentifier === image.identifier
            "
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

    <!-- Form Details -->
    <div
      class="bg-n-alpha-2 dark:bg-n-alpha-3 p-6 rounded-lg border border-n-weak dark:border-n-slate-6"
    >
      <h3
        class="text-base font-semibold text-n-slate-12 dark:text-n-slate-11 mb-6"
      >
        {{ t('APPLE_FORM.FORM_DETAILS') }}
      </h3>

      <div class="space-y-4">
        <div>
          <label
            class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
          >
            {{ t('APPLE_FORM.FORM_TITLE_LABEL') }}
          </label>
          <input
            v-model="localProps.title"
            type="text"
            :placeholder="t('APPLE_FORM.FORM_TITLE_PLACEHOLDER')"
            class="w-full px-4 py-2.5 border border-n-slate-7 dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-blue-7 dark:focus:ring-n-blue-8"
          />
        </div>

        <div>
          <label
            class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
          >
            {{ t('APPLE_FORM.DESCRIPTION_LABEL') }}
          </label>
          <textarea
            v-model="localProps.description"
            rows="2"
            :placeholder="t('APPLE_FORM.DESCRIPTION_PLACEHOLDER')"
            class="w-full px-4 py-2.5 border border-n-slate-7 dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-blue-7 dark:focus:ring-n-blue-8"
          />
        </div>
      </div>
    </div>

    <!-- Message Configuration -->
    <div
      class="bg-n-alpha-2 dark:bg-n-alpha-3 p-6 rounded-lg border border-n-weak dark:border-n-slate-6"
    >
      <h3
        class="text-base font-semibold text-n-slate-12 dark:text-n-slate-11 mb-6"
      >
        {{ t('APPLE_FORM.MESSAGES_TAB.MESSAGE_CONFIGURATION') }}
      </h3>

      <!-- Received Message Subtitle -->
      <div class="mb-8">
        <label
          class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
        >
          {{ t('APPLE_FORM.MESSAGES_TAB.RECEIVED_MESSAGE_SUBTITLE_LABEL') }}
        </label>
        <input
          v-model="localProps.receivedMessage.subtitle"
          type="text"
          :placeholder="
            t('APPLE_FORM.MESSAGES_TAB.RECEIVED_MESSAGE_SUBTITLE_PLACEHOLDER')
          "
          class="w-full px-4 py-2.5 border border-n-slate-7 dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-blue-7 dark:focus:ring-n-blue-8"
        />
      </div>

      <!-- Received Style Selection -->
      <div class="mb-8">
        <label
          class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-4"
        >
          {{ t('APPLE_FORM.MESSAGES_TAB.IMAGE_STYLE') }}
        </label>
        <div class="grid grid-cols-3 gap-4">
          <div
            v-for="style in styleOptions"
            :key="style.value"
            class="border-2 rounded-lg p-4 cursor-pointer transition-all duration-200 hover:shadow-md"
            :class="
              localProps.receivedMessage.style === style.value
                ? 'border-n-blue-8 bg-n-blue-1 dark:border-n-blue-9 dark:bg-n-blue-2'
                : 'border-n-weak hover:border-n-blue-6 dark:border-n-slate-6 dark:hover:border-n-blue-7'
            "
            @click="localProps.receivedMessage.style = style.value"
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
                    localProps.receivedMessage.imageIdentifier &&
                    getImagePreviewUrl(
                      localProps.receivedMessage.imageIdentifier
                    )
                  "
                  :src="
                    getImagePreviewUrl(
                      localProps.receivedMessage.imageIdentifier
                    )
                  "
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
                v-if="localProps.receivedMessage.style === style.value"
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
      <div class="border-t border-n-weak dark:border-n-slate-6 pt-8">
        <h4
          class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-6"
        >
          {{ t('APPLE_FORM.MESSAGES_TAB.REPLY_MESSAGE') }}
        </h4>

        <div class="space-y-4">
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
            >
              {{ t('APPLE_FORM.REPLY_MESSAGE_TITLE_LABEL') }}
            </label>
            <input
              v-model="localProps.replyMessage.title"
              type="text"
              :placeholder="t('APPLE_FORM.REPLY_MESSAGE_TITLE_PLACEHOLDER')"
              class="w-full px-4 py-2.5 border border-n-slate-7 dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-blue-7 dark:focus:ring-n-blue-8"
            />
          </div>

          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
            >
              {{ t('APPLE_FORM.REPLY_MESSAGE_SUBTITLE_LABEL') }}
            </label>
            <input
              v-model="localProps.replyMessage.subtitle"
              type="text"
              :placeholder="t('APPLE_FORM.REPLY_MESSAGE_SUBTITLE_PLACEHOLDER')"
              class="w-full px-4 py-2.5 border border-n-slate-7 dark:border-n-slate-6 rounded-lg bg-white dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-blue-7 dark:focus:ring-n-blue-8"
            />
          </div>

          <!-- Reply Style Selection -->
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-4"
            >
              Reply Style
            </label>
            <div class="grid grid-cols-3 gap-4">
              <div
                v-for="style in styleOptions"
                :key="style.value"
                class="border-2 rounded-lg p-4 cursor-pointer transition-all duration-200 hover:shadow-md"
                :class="
                  localProps.replyMessage.style === style.value
                    ? 'border-n-blue-8 bg-n-blue-1 dark:border-n-blue-9 dark:bg-n-blue-2'
                    : 'border-n-weak hover:border-n-blue-6 dark:border-n-slate-6 dark:hover:border-n-blue-7'
                "
                @click="localProps.replyMessage.style = style.value"
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
                        localProps.replyMessage.imageIdentifier &&
                        getImagePreviewUrl(
                          localProps.replyMessage.imageIdentifier
                        )
                      "
                      :src="
                        getImagePreviewUrl(
                          localProps.replyMessage.imageIdentifier
                        )
                      "
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
                    v-if="localProps.replyMessage.style === style.value"
                    class="mt-2 flex items-center justify-center text-n-blue-10 dark:text-n-blue-9"
                  >
                    <svg
                      class="w-5 h-5"
                      fill="currentColor"
                      viewBox="0 0 20 20"
                    >
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
    </div>

    <!-- Pages Management -->
    <div
      class="bg-n-alpha-2 dark:bg-n-alpha-3 p-6 rounded-lg border border-n-weak dark:border-n-slate-6"
    >
      <div class="flex items-center justify-between mb-4">
        <div>
          <h3
            class="text-base font-semibold text-n-slate-12 dark:text-n-slate-11"
          >
            {{ t('APPLE_FORM.PAGES') }}
          </h3>
          <p class="text-xs text-n-slate-10 dark:text-n-slate-9 mt-1">
            Click a page to view and edit its fields
          </p>
        </div>
        <Button icon="i-lucide-plus" xs @click="addNewPage" />
      </div>

      <div class="space-y-2">
        <div
          v-for="(page, index) in localProps.pages"
          :key="page.page_id"
          class="flex items-center justify-between p-3 rounded-lg border cursor-pointer transition-colors group"
          :class="[
            index === currentPageIndex
              ? 'border-n-blue-7 bg-n-blue-2'
              : 'border-n-slate-7 hover:border-n-blue-6 hover:bg-n-blue-1',
          ]"
          @click="currentPageIndex = index"
        >
          <div class="flex-1 min-w-0 flex items-center gap-3">
            <!-- Click indicator icon -->
            <i
              class="i-lucide-chevron-right text-lg transition-transform"
              :class="[
                index === currentPageIndex
                  ? 'rotate-90 text-n-blue-10'
                  : 'text-n-slate-9 group-hover:text-n-blue-9',
              ]"
            />
            <div class="flex-1">
              <input
                v-model="page.title"
                class="w-full text-sm font-medium text-n-slate-12 bg-transparent border-none p-0 focus:outline-none truncate"
                @click.stop
              />
              <p class="text-xs text-n-slate-11">
                {{ page.items ? page.items.length : 0 }}
                {{ t('APPLE_FORM.FIELDS_COUNT') }}
              </p>
            </div>
          </div>
          <Button
            v-if="localProps.pages.length > 1"
            icon="i-lucide-x"
            ruby
            xs
            faded
            @click.stop="removePage(index)"
          />
        </div>
      </div>
    </div>

    <!-- Current Page Fields -->
    <div
      v-if="currentPage"
      class="bg-n-alpha-2 dark:bg-n-alpha-3 p-6 rounded-lg border border-n-weak dark:border-n-slate-6"
    >
      <div class="flex items-center justify-between mb-4">
        <h4
          class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 truncate"
        >
          {{ t('APPLE_FORM.FIELDS_TITLE', { page: currentPage.title }) }}
        </h4>
        <Button icon="i-lucide-plus" xs @click="openAddFieldModal" />
      </div>

      <div class="space-y-2">
        <div
          v-for="(field, index) in currentPage.items"
          :key="field.item_id"
          class="flex items-center justify-between p-3 bg-n-slate-2 rounded-lg cursor-pointer hover:bg-n-slate-3 transition-colors"
          @click="editField(index)"
        >
          <div class="flex-1 min-w-0">
            <div class="text-sm font-medium text-n-slate-12 truncate">
              {{ field.title }}
            </div>
            <div class="text-xs text-n-slate-11 truncate">
              {{
                fieldTypes.find(ft => ft.value === field.item_type)?.label ||
                field.item_type
              }}
              <span v-if="field.required" class="text-n-ruby-9 ml-1">*</span>
            </div>
          </div>
          <Button
            icon="i-lucide-trash-2"
            ruby
            xs
            faded
            @click.stop="removeField(index)"
          />
        </div>
      </div>
    </div>

    <!-- Add/Edit Field Modal -->
    <div
      v-if="showAddFieldModal"
      class="fixed inset-0 z-50 overflow-y-auto bg-black bg-opacity-50 flex items-center justify-center p-4"
    >
      <div
        class="bg-white dark:bg-n-slate-2 rounded-lg max-w-2xl w-full max-h-full overflow-y-auto shadow-xl"
      >
        <div class="p-6 space-y-4">
          <h3 class="text-lg font-medium text-n-slate-12">
            {{
              typeof newField.editingIndex === 'number'
                ? t('TEMPLATES.BUILDER.APPLE_FORM.EDIT_FIELD_TITLE')
                : t('TEMPLATES.BUILDER.APPLE_FORM.ADD_FIELD_TITLE')
            }}
          </h3>

          <!-- Field Type Selection -->
          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              {{ t('APPLE_FORM.FIELD_TYPE') }}
            </label>
            <div class="grid grid-cols-2 gap-2">
              <button
                v-for="fieldType in fieldTypes"
                :key="fieldType.value"
                class="text-left p-3 border-2 rounded-lg transition-colors"
                :class="[
                  newField.item_type === fieldType.value
                    ? 'border-n-blue-7 bg-n-blue-2'
                    : 'border-n-slate-7 hover:border-n-slate-8',
                ]"
                @click="newField.item_type = fieldType.value"
              >
                <div class="flex items-center gap-2">
                  <span class="text-lg">{{ fieldType.icon }}</span>
                  <div>
                    <div class="font-medium text-n-slate-12 text-sm">
                      {{ fieldType.label }}
                    </div>
                    <div class="text-xs text-n-slate-11">
                      {{ fieldType.description }}
                    </div>
                  </div>
                </div>
              </button>
            </div>
          </div>

          <!-- Basic Field Info -->
          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              {{ t('APPLE_FORM.FIELD_TITLE') }}
            </label>
            <input
              v-model="newField.title"
              type="text"
              :placeholder="t('APPLE_FORM.FIELD_TITLE_PLACEHOLDER')"
              class="w-full px-4 py-2 border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              {{ t('APPLE_FORM.DESCRIPTION_LABEL') }}
            </label>
            <input
              v-model="newField.description"
              type="text"
              :placeholder="t('APPLE_FORM.FIELD_DESCRIPTION_PLACEHOLDER')"
              class="w-full px-4 py-2 border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7"
            />
          </div>

          <div class="flex items-center gap-2">
            <input
              v-model="newField.required"
              type="checkbox"
              class="w-4 h-4 rounded border-n-slate-7 text-n-blue-9 focus:ring-2 focus:ring-n-blue-7"
            />
            <label class="text-sm text-n-slate-12">
              {{ t('APPLE_FORM.REQUIRED_FIELD') }}
            </label>
          </div>

          <!-- Input Field Options (text, textArea, email, phone) -->
          <div
            v-if="
              ['text', 'textArea', 'email', 'phone'].includes(
                newField.item_type
              )
            "
            class="space-y-4 pt-4 border-t border-n-slate-6"
          >
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ t('APPLE_FORM.PLACEHOLDER') }}
              </label>
              <input
                v-model="newField.placeholder"
                type="text"
                :placeholder="t('APPLE_FORM.PLACEHOLDER_TEXT')"
                class="w-full px-4 py-2 border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ t('APPLE_FORM.FIELD_OPTIONS.LABEL_TEXT') }}
              </label>
              <input
                v-model="newField.label_text"
                type="text"
                :placeholder="
                  t('APPLE_FORM.FIELD_OPTIONS.LABEL_TEXT_PLACEHOLDER')
                "
                class="w-full px-4 py-2 border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{
                  t('TEMPLATES.BUILDER.APPLE_FORM.FIELD_OPTIONS.MAX_CHAR_COUNT')
                }}
              </label>
              <input
                v-model.number="newField.maximum_character_count"
                type="number"
                :placeholder="
                  t(
                    'TEMPLATES.BUILDER.APPLE_FORM.FIELD_OPTIONS.MAX_CHAR_COUNT_PLACEHOLDER'
                  )
                "
                class="w-full px-4 py-2 border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7"
              />
            </div>
          </div>

          <!-- Select Options (singleSelect, multiSelect) -->
          <div
            v-if="['singleSelect', 'multiSelect'].includes(newField.item_type)"
            class="space-y-4 pt-4 border-t border-n-slate-6"
          >
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ t('APPLE_FORM.OPTIONS') }}
              </label>
              <div class="space-y-2">
                <div
                  v-for="(option, index) in newField.options"
                  :key="index"
                  class="space-y-2"
                >
                  <div class="flex items-center gap-2">
                    <input
                      v-model="option.value"
                      type="text"
                      :placeholder="t('APPLE_FORM.OPTION_VALUE')"
                      class="flex-1 px-3 py-2 text-sm border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7"
                    />
                    <input
                      v-model="option.title"
                      type="text"
                      :placeholder="t('APPLE_FORM.OPTION_LABEL')"
                      class="flex-1 px-3 py-2 text-sm border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7"
                    />
                    <Button
                      icon="i-lucide-x"
                      ruby
                      xs
                      faded
                      @click="removeOption(index)"
                    />
                  </div>

                  <!-- Image selector for option -->
                  <div class="ml-4 flex items-center gap-2">
                    <label class="text-xs text-n-slate-11">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.FIELD_OPTIONS.OPTION_IMAGE'
                        )
                      }}
                    </label>
                    <select
                      v-model="option.imageIdentifier"
                      class="flex-1 px-2 py-1 text-sm border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7"
                    >
                      <option value="">
                        {{
                          t(
                            'TEMPLATES.BUILDER.APPLE_FORM.MESSAGES_TAB.NO_IMAGE'
                          )
                        }}
                      </option>
                      <option
                        v-for="img in localProps.images"
                        :key="img.identifier"
                        :value="img.identifier"
                      >
                        {{ img.identifier }}
                      </option>
                    </select>
                    <div
                      v-if="
                        option.imageIdentifier &&
                        getImagePreviewUrl(option.imageIdentifier)
                      "
                      class="w-8 h-8 rounded overflow-hidden border border-n-slate-7"
                    >
                      <img
                        :src="getImagePreviewUrl(option.imageIdentifier)"
                        alt="Option image"
                        class="w-full h-full object-cover"
                      />
                    </div>
                  </div>
                </div>
                <button
                  class="w-full py-2 border-2 border-dashed border-n-slate-7 rounded-lg text-n-slate-11 hover:border-n-slate-8 transition-colors"
                  @click="addOption"
                >
                  {{ t('APPLE_FORM.ADD_OPTION') }}
                </button>
              </div>
            </div>
          </div>

          <!-- Stepper Options -->
          <div
            v-if="newField.item_type === 'stepper'"
            class="space-y-4 pt-4 border-t border-n-slate-6"
          >
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-n-slate-12 mb-2">
                  {{ t('TEMPLATES.BUILDER.APPLE_FORM.STEPPER.MIN_VALUE') }}
                </label>
                <input
                  v-model.number="newField.min_value"
                  type="number"
                  class="w-full px-4 py-2 border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-n-slate-12 mb-2">
                  {{ t('TEMPLATES.BUILDER.APPLE_FORM.STEPPER.MAX_VALUE') }}
                </label>
                <input
                  v-model.number="newField.max_value"
                  type="number"
                  class="w-full px-4 py-2 border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7"
                />
              </div>
            </div>
          </div>

          <!-- Rich Link Options -->
          <div
            v-if="newField.item_type === 'richLink'"
            class="space-y-4 pt-4 border-t border-n-slate-6"
          >
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ t('TEMPLATES.BUILDER.APPLE_FORM.RICH_LINK.URL_LABEL') }}
              </label>
              <div class="flex gap-2">
                <input
                  v-model="newField.url"
                  type="url"
                  :placeholder="
                    t('TEMPLATES.BUILDER.APPLE_FORM.RICH_LINK.URL_PLACEHOLDER')
                  "
                  class="flex-1 px-4 py-2 border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-7"
                />
                <Button
                  slate
                  icon="i-lucide-sparkles"
                  :disabled="!newField.url || isLoadingRichLink"
                  @click="fetchRichLinkData"
                >
                  {{
                    isLoadingRichLink
                      ? t('TEMPLATES.BUILDER.APPLE_FORM.RICH_LINK.LOADING')
                      : t(
                          'TEMPLATES.BUILDER.APPLE_FORM.RICH_LINK.AUTOFILL_BUTTON'
                        )
                  }}
                </Button>
              </div>
              <p class="text-xs text-n-slate-10 mt-1">
                {{
                  t(
                    'TEMPLATES.BUILDER.APPLE_FORM.RICH_LINK.AUTOFILL_DESCRIPTION'
                  )
                }}
              </p>
            </div>
          </div>

          <div class="flex justify-end gap-3 pt-4">
            <Button slate @click="showAddFieldModal = false">
              {{ t('APPLE_FORM.CANCEL') }}
            </Button>
            <Button :disabled="!newField.title" @click="addFieldToCurrentPage">
              {{ t('APPLE_FORM.ADD_FIELD') }}
            </Button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
