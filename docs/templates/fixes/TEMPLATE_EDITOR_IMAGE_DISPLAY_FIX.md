# Image Extraction Fix for Template Editor UI

## Problem

The List Picker block editor in Chatwoot UI was rendering empty (no fields visible) when editing migrated templates. The issue was that migrated images only had `identifier` and `data` fields, but the Vue component requires additional fields:

- `preview` - Full data URL (`data:image/png;base64,...`) for rendering in UI
- `originalName` - Filename for display
- `description` - Description text
- `size` - File size in bytes for display

## Root Cause

**Vue Component** (`ListPickerBlockEditor.vue:536-547`):
```vue
<img
  v-if="image.preview"
  :src="image.preview"
  ...
/>
```

The component expects `image.preview` but migrated templates only had:
```json
{
  "identifier": "0",
  "data": "iVBORw0KGgo..."
}
```

## Solution

Updated `build_block_properties` in `import_as_message_templates.rb` to include all required fields.

### Code Changes

**File**: `script/import_as_message_templates.rb:461-475`

```ruby
# Extract images from original_payload.data.images (for list picker and time picker)
images_data = payload_data.dig('original_payload', 'data', 'images') || []
images_array = images_data.map do |img|
  base64_data = img['data']
  {
    'identifier' => img['identifier'],
    'data' => base64_data,
    # Add preview field for Vue component (full data URL)
    'preview' => base64_data ? "data:image/png;base64,#{base64_data}" : nil,
    # Add metadata for better UI display
    'description' => "Migrated image #{img['identifier']}",
    'originalName' => "image_#{img['identifier']}.png",
    'size' => base64_data ? (base64_data.length * 0.75).to_i : 0  # Approximate original size
  }.compact
end.compact
```

## Testing

Updated `script/test_image_extraction.rb` to verify all fields:

```bash
ruby script/test_image_extraction.rb
```

**Results**: ✅ All fields present
```
Images found: 5
- ID: 0
  Name: image_0.png
  Size: 60786 bytes
  Data: iVBORw0KGgo...
  Preview: data:image/png;base64,iVBORw0KGgo...
```

## Image Field Mapping

| Field | Purpose | Example Value |
|-------|---------|---------------|
| `identifier` | Reference in list items | `"0"`, `"1"`, `"2"` |
| `data` | Base64 for Apple MSP API | `"iVBORw0KGgo..."` |
| `preview` | Data URL for Vue rendering | `"data:image/png;base64,iVBORw0..."` |
| `originalName` | Display name in UI | `"image_0.png"` |
| `description` | Tooltip/metadata | `"Migrated image 0"` |
| `size` | File size for display | `60786` (bytes) |

## Expected Outcome

After re-importing templates with the fix:

1. ✅ List Picker editor will render properly in Chatwoot UI
2. ✅ Images will display as thumbnails in the editor
3. ✅ All form fields (sections, items, messages) will be visible
4. ✅ Users can edit migrated templates in the UI
5. ✅ Image selection UI will show previews correctly

## Migration Steps

Since templates were already imported without `preview` fields, you need to:

### Option A: Re-import Templates (Recommended)

1. Delete existing migrated templates:
   ```bash
   rails runner script/rollback_template_import.rb --account-id 1 --backup
   ```

2. Re-import with the fix:
   ```bash
   rails runner script/import_as_message_templates.rb --account-id 1 --business acoustic_house
   ```

### Option B: Fix Existing Templates (Advanced)

Create a migration script to add `preview`, `originalName`, `description`, and `size` fields to existing template images.

## Related Files

- **Fixed**: `script/import_as_message_templates.rb:461-475` - Image extraction logic
- **Updated**: `script/test_image_extraction.rb` - Test script
- **Vue Component**: `app/javascript/dashboard/routes/dashboard/settings/templates/components/blocks/ListPickerBlockEditor.vue:536-547` - Requires `preview` field

## Technical Details

### Why `preview` is Required

The Vue component uses conditional rendering:
```vue
<img v-if="image.preview" :src="image.preview" />
<div v-else>📷</div>  <!-- Fallback icon when no preview -->
```

Without `preview`, the component shows the fallback icon (camera emoji) instead of the actual image.

### Data URL Format

Preview format: `data:image/png;base64,{base64_data}`

This is a standard data URL that browsers can render directly without separate image requests.

### Size Calculation

`size` is calculated as approximately 75% of base64 length:
```ruby
(base64_data.length * 0.75).to_i
```

This estimates the original binary size (base64 encoding adds ~33% overhead).
