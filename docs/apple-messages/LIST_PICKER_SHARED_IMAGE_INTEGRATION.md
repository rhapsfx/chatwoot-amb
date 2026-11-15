# List Picker Shared Image Selector Integration

**Date**: November 19, 2025
**Status**: ✅ Complete

## Overview

Integrated SharedImageSelector component into ListPickerBlockEditor to allow selecting shared images from the account's Apple Business Chat inboxes when creating message templates.

## Implementation

### New Component: SharedImageSelector.vue

**Location**: `app/javascript/dashboard/routes/dashboard/settings/templates/components/SharedImageSelector.vue`

**Features**:
- Loads shared images from Apple Business Chat inboxes via `apple_amb_images` API
- Inbox selector dropdown (auto-selects first available inbox)
- Image grid display with preview on hover
- Selected image indicator
- Refresh functionality
- Loading, error, and empty states
- Responsive grid layout (3 columns)

**Props**:
- `modelValue` (String): Currently selected image identifier
- `accountId` (Number|String): Account ID to filter inboxes
- `imageType` (String): Type of image context (template, message, form)

**Events**:
- `update:modelValue`: Emitted when image identifier changes
- `image-selected`: Emitted when image is selected (passes full image object)

### Updated Component: ListPickerBlockEditor.vue

**Location**: `app/javascript/dashboard/routes/dashboard/settings/templates/components/blocks/ListPickerBlockEditor.vue`

**Changes**:
1. Added SharedImageSelector component import
2. Added tab navigation for "Upload New" and "Use Shared Images"
3. Integrated SharedImageSelector in "Use Shared Images" tab
4. Updated image picker modal to show both inline and shared images
5. Added `imageTabMode` state to toggle between upload/shared views
6. Added `sharedImageIdentifier` ref for tracking shared image selection
7. Added `handleSharedImageSelected` function to handle shared image selection

## UI/UX Flow

### Images Management Section (Line ~497)

```
┌─────────────────────────────────────────┐
│  Images                                  │
├─────────────────────────────────────────┤
│  [Upload New Images] [Use Shared Images] │ <- Tabs
├─────────────────────────────────────────┤
│                                          │
│  TAB: Upload New Images                  │
│  - Shows inline base64 images           │
│  - "Add Image" button to upload         │
│  - Grid of uploaded images              │
│                                          │
│  TAB: Use Shared Images                  │
│  - Inbox selector dropdown              │
│  - SharedImageSelector component        │
│  - Grid of shared images from inbox     │
│                                          │
└─────────────────────────────────────────┘
```

### Image Picker Modal (Line ~802)

When clicking "Select" or "Change" on list items:

```
┌─────────────────────────────────────────┐
│  Select Image                        [X] │
├─────────────────────────────────────────┤
│  [Inline Images (3)] [Shared Images]    │ <- Tabs
├─────────────────────────────────────────┤
│  Shows either:                           │
│  - Inline images grid (from upload)     │
│  - Shared images (via component)        │
└─────────────────────────────────────────┘
```

## Data Flow

### Shared Image Selection

1. User switches to "Use Shared Images" tab
2. Component loads Apple Business Chat inboxes from Vuex store
3. Auto-selects first inbox
4. Fetches shared images via `AppleMessagesImagesAPI.get({ inboxId })`
5. User selects image from grid
6. `handleSharedImageSelected` updates `image_identifier` in block data
7. Template saves with shared `image_identifier` (snake_case)

### Backwards Compatibility

- ✅ Existing inline images continue to work
- ✅ Can switch between inline and shared images
- ✅ Shared image identifiers stored in same `image_identifier` field
- ✅ Both inline and shared images shown in picker modal

## Architecture

### Component Hierarchy

```
ListPickerBlockEditor.vue
├── SharedImageSelector.vue (new)
│   ├── Inbox Selector Dropdown
│   ├── Image Grid Display
│   └── Loading/Error/Empty States
└── Image Picker Modal (updated)
    ├── Tab: Inline Images
    └── Tab: Shared Images (uses SharedImageSelector)
```

### State Management

**ListPickerBlockEditor**:
- `imageTabMode` - 'upload' or 'shared'
- `sharedImageIdentifier` - Currently selected shared image identifier
- `localProps.sections[].items[].image_identifier` - Image reference (inline or shared)

**SharedImageSelector**:
- `selectedInboxId` - Current inbox for loading images
- `sharedImages` - Array of shared images from API
- `loading` - Loading state
- `error` - Error state

## API Integration

### Endpoint Used

`GET /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images`

**Response Format**:
```json
[
  {
    "id": 123,
    "identifier": "img_001",
    "description": "Product image",
    "original_name": "product.png",
    "image_url": "https://...",
    "created_at": "2025-11-19T...",
    "updated_at": "2025-11-19T..."
  }
]
```

### Case Normalization

- Frontend naturally sends camelCase
- API auto-normalizes to snake_case via `before_action`
- Database stores snake_case (`image_identifier`)
- CaseTransformer converts to camelCase when sending to Apple MSP

## Testing Checklist

- [ ] Load template editor with Apple Business Chat inbox
- [ ] Verify inbox dropdown appears and auto-selects
- [ ] Switch between "Upload New" and "Use Shared Images" tabs
- [ ] Select shared image and verify preview
- [ ] Open item image picker and verify both tabs work
- [ ] Select shared image in picker and verify item updates
- [ ] Save template and verify `image_identifier` is stored correctly
- [ ] Load saved template and verify shared image displays
- [ ] Test with no Apple Business Chat inboxes
- [ ] Test with empty shared images library

## Edge Cases Handled

1. **No Apple Business Chat Inboxes**:
   - Shows warning message
   - Disables refresh button
   - Graceful empty state

2. **Empty Shared Images**:
   - Shows helpful empty state message
   - Guides user to upload via Reply Box

3. **Loading State**:
   - Shows spinner with message
   - Prevents interaction during load

4. **Error State**:
   - Shows error message
   - Allows retry via refresh

5. **Mixed Image Types**:
   - Allows both inline and shared images in same template
   - Clear indication of source in UI

## Future Enhancements

1. **Multi-Inbox Image Browser**:
   - Show images from all inboxes
   - Filter by inbox

2. **Image Upload from Templates**:
   - Direct upload to shared library
   - Batch upload to multiple inboxes

3. **Image Metadata Display**:
   - Show which inbox image belongs to
   - Display usage count

4. **Image Search/Filter**:
   - Search by filename or identifier
   - Filter by size or type

## Related Files

**Components**:
- `app/javascript/dashboard/routes/dashboard/settings/templates/components/SharedImageSelector.vue` (new)
- `app/javascript/dashboard/routes/dashboard/settings/templates/components/blocks/ListPickerBlockEditor.vue` (updated)

**API Client**:
- `app/javascript/dashboard/api/appleAmbMessagesImages.js` (existing)

**Backend**:
- `app/controllers/api/v1/accounts/inboxes/apple_amb_images_controller.rb` (existing)
- `app/models/apple_list_picker_image.rb` (existing)

**Documentation**:
- `docs/apple-messages/case-normalization-specification.md`
- `docs/apple-messages/PHASE_1_COMPLETE.md`

## Integration with Existing Features

### CaseTransformer Compliance

✅ **All image identifiers use snake_case internally**
✅ **API auto-normalizes camelCase → snake_case**
✅ **CaseTransformer handles snake_case → camelCase for Apple MSP**

### Time Picker Integration

The same SharedImageSelector pattern can be applied to:
- TimePickerBlockEditor (for template-based time picker)
- FormBlockEditor (for template-based forms)

## Summary

Successfully integrated SharedImageSelector into List Picker template editor with:
- ✅ Inbox-aware image loading
- ✅ Dual-tab interface (inline vs shared)
- ✅ Picker modal integration
- ✅ Backwards compatibility
- ✅ Proper error handling
- ✅ Responsive design
- ✅ Case normalization compliance

The implementation provides a seamless way to reuse images across conversations while maintaining the option to use inline images when needed.
