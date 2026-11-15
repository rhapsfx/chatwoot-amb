# SharedImageSelectorModal Component

## Overview

A reusable Vue 3 component for selecting shared Apple Messages images with support for:
- Tab-based filtering by image type (System, Branding, Template)
- Search/filter by identifier or description
- Image upload for admins
- Delete functionality for admins
- Grid display with image previews
- Loading and error states
- Empty state handling

## Location

`app/javascript/dashboard/components-next/message/components/SharedImageSelectorModal.vue`

## API Composable

`app/javascript/dashboard/composables/useSharedAppleImages.js`

## Props

| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `modelValue` | String | No | `''` | Selected image identifier (for v-model) |
| `accountId` | Number | Yes | - | Account ID for API calls |
| `imageType` | String | No | `'system'` | Default tab ('system', 'branding', 'template') |
| `allowUpload` | Boolean | No | `true` | Show upload button |
| `multiple` | Boolean | No | `false` | Allow multiple selection (future feature) |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `update:modelValue` | `String` (identifier) | When selection changes (v-model support) |
| `image-selected` | `Object` (full image object) | When an image is selected |

## Usage Examples

### Basic Usage

```vue
<script setup>
import { ref } from 'vue';
import SharedImageSelectorModal from 'dashboard/components-next/message/components/SharedImageSelectorModal.vue';

const selectedImageIdentifier = ref('');
const accountId = ref(1);

const handleImageSelected = (image) => {
  console.log('Selected image:', image);
};
</script>

<template>
  <SharedImageSelectorModal
    v-model="selectedImageIdentifier"
    :account-id="accountId"
    @image-selected="handleImageSelected"
  />
</template>
```

### With Specific Default Tab

```vue
<template>
  <SharedImageSelectorModal
    v-model="selectedImageIdentifier"
    :account-id="accountId"
    image-type="branding"
  />
</template>
```

### Disable Upload (Read-Only Mode)

```vue
<template>
  <SharedImageSelectorModal
    v-model="selectedImageIdentifier"
    :account-id="accountId"
    :allow-upload="false"
  />
</template>
```

### In a Modal/Dialog

```vue
<script setup>
import { ref } from 'vue';
import SharedImageSelectorModal from 'dashboard/components-next/message/components/SharedImageSelectorModal.vue';

const showModal = ref(false);
const selectedImageIdentifier = ref('');
const accountId = ref(1);

const handleImageSelected = (image) => {
  console.log('Selected:', image.identifier);
  showModal.value = false; // Close modal after selection
};
</script>

<template>
  <div>
    <button @click="showModal = true">
      Select Image
    </button>

    <div v-if="showModal" class="modal">
      <div class="modal-content">
        <h2>Select Shared Image</h2>
        <SharedImageSelectorModal
          v-model="selectedImageIdentifier"
          :account-id="accountId"
          @image-selected="handleImageSelected"
        />
        <button @click="showModal = false">Cancel</button>
      </div>
    </div>
  </div>
</template>
```

### Integration with Form Builder

```vue
<script setup>
import { ref } from 'vue';
import SharedImageSelectorModal from 'dashboard/components-next/message/components/SharedImageSelectorModal.vue';

const formData = ref({
  receivedImageIdentifier: '',
  replyImageIdentifier: '',
});

const accountId = ref(1);

const handleReceivedImageSelected = (image) => {
  formData.value.receivedImageIdentifier = image.identifier;
  // Auto-sync reply image with received image
  formData.value.replyImageIdentifier = image.identifier;
};
</script>

<template>
  <div class="form-builder">
    <div class="form-section">
      <h3>Received Message</h3>
      <SharedImageSelectorModal
        v-model="formData.receivedImageIdentifier"
        :account-id="accountId"
        image-type="template"
        @image-selected="handleReceivedImageSelected"
      />
    </div>

    <div class="form-section">
      <h3>Reply Message</h3>
      <SharedImageSelectorModal
        v-model="formData.replyImageIdentifier"
        :account-id="accountId"
        image-type="template"
      />
    </div>
  </div>
</template>
```

## API Endpoints Used

The component uses the `useSharedAppleImages` composable which calls:

- `GET /api/v1/accounts/:accountId/shared_apple_images/system_images`
- `GET /api/v1/accounts/:accountId/shared_apple_images/branding_images`
- `GET /api/v1/accounts/:accountId/shared_apple_images/template_images`
- `POST /api/v1/accounts/:accountId/shared_apple_images` (upload)
- `DELETE /api/v1/accounts/:accountId/shared_apple_images/:id` (delete)

## Features

### Tab Navigation
- System images (⚙️) - System-level shared images
- Branding images (🎨) - Brand-specific images
- Template images (📋) - Template-specific images

### Search/Filter
- Real-time search by identifier or description
- Works across all tabs independently

### Upload
- File input with image validation
- Max file size: 5MB
- Auto-generates identifier from filename
- Reloads images after successful upload
- Admin-only feature

### Delete
- Confirmation dialog before deletion
- Auto-deselects if selected image is deleted
- Admin-only feature

### Grid Display
- Responsive grid (2-6 columns based on screen size)
- Image thumbnails with aspect ratio preservation
- Hover effects and transitions
- Selected state highlighting
- Image info (identifier, description, file size)

### States
- **Loading**: Spinner with loading text
- **Error**: Error message with retry button
- **Empty**: Empty state with helpful hint
- **Loaded**: Grid of images with count

## Styling

The component uses Tailwind CSS classes with:
- Responsive grid layout
- Smooth transitions and hover effects
- Blue color scheme for selected/active states
- Gray tones for neutral states
- Red for delete actions

## Accessibility

- Semantic HTML structure
- Keyboard navigation support
- Focus states for interactive elements
- Alt text for images
- Loading indicators
- Error messages

## Future Enhancements

1. **Multiple Selection** - Allow selecting multiple images (prop already exists)
2. **Drag & Drop Upload** - Drag files directly into the component
3. **Bulk Delete** - Select and delete multiple images
4. **Image Preview Modal** - Click to see full-size preview
5. **Pagination** - For accounts with many images
6. **Sorting Options** - Sort by name, date, size
7. **Filtering by Tags** - Add tags to images for better organization

## Related Files

- Component: `app/javascript/dashboard/components-next/message/components/SharedImageSelectorModal.vue`
- Composable: `app/javascript/dashboard/composables/useSharedAppleImages.js`
- I18n (Backend): `config/locales/en.yml` (apple_messages.shared_images)
- I18n (Frontend): `app/javascript/dashboard/i18n/locale/en/appleMessages.json`
- Controller: `app/controllers/api/v1/accounts/shared_apple_images_controller.rb`
- Model: `app/models/shared_apple_image.rb`

## Testing

```bash
# Component tests
pnpm test SharedImageSelectorModal.spec.js

# API tests
bundle exec rspec spec/requests/api/v1/accounts/shared_apple_images_spec.rb

# Integration tests
bundle exec rspec spec/features/apple_messages/shared_images_spec.rb
```

## Notes

- The component is designed to work with the shared_apple_images API
- It's separate from the inbox-specific SharedImageSelector component
- Uses CaseTransformer for consistent data formatting
- Follows Vue 3 Composition API best practices
- Adheres to Chatwoot's Tailwind-only styling guidelines
