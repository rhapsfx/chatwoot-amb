# Block Editor UI Fix - Complete Solution

## Problem Summary

All Apple Messages template block editors were rendering incorrectly:
- **List Picker**: Empty block (no fields visible)
- **Time Picker**: Would have same issue
- **Apple Form**: Showing "2 fields", "5 fields" text instead of actual form fields

## Root Causes

### Issue 1: Missing Image Preview Fields
Images only had `identifier` and `data`, but Vue components require:
- `preview` - Full data URL for rendering
- `originalName`, `description`, `size` - For UI display

### Issue 2: Inconsistent Data Formats
Each block editor expects a different format:

| Editor | Format Expected |
|--------|----------------|
| **List Picker** | snake_case flat: `received_title`, `reply_title` |
| **Time Picker** | camelCase flat: `receivedTitle`, `replyTitle` |
| **Apple Form** | Nested camelCase: `receivedMessage.title`, `replyMessage.title` |

But we were storing everything in flattened snake_case format.

## Solution

### 1. Image Fields Fix

**File**: `script/import_as_message_templates.rb:461-475`

```ruby
images_array = images_data.map do |img|
  base64_data = img['data']
  {
    'identifier' => img['identifier'],
    'data' => base64_data,
    'preview' => base64_data ? "data:image/png;base64,#{base64_data}" : nil,
    'description' => "Migrated image #{img['identifier']}",
    'originalName' => "image_#{img['identifier']}.png",
    'size' => (base64_data.length * 0.75).to_i
  }.compact
end.compact
```

### 2. List Picker Format (snake_case flat)

**File**: `script/import_as_message_templates.rb:496-504`

```ruby
when /list_picker/
  # List Picker editor uses snake_case flat fields
  list_picker_data = content_attrs['list_picker'] || {}
  flattened_messages.merge({
    'sections' => list_picker_data['sections'] || [],
    'multiple_selection' => list_picker_data['multiple_selection'] || false,
    'images' => images_array
  })
```

Properties stored:
```json
{
  "received_title": "Please select an option",
  "received_subtitle": "Choose one",
  "received_image_identifier": "0",
  "received_style": "icon",
  "reply_title": "Selection Made",
  "sections": [...],
  "images": [...]
}
```

### 3. Time Picker Format (camelCase flat)

**File**: `script/import_as_message_templates.rb:506-534`

```ruby
when /time_picker/
  # Time Picker editor uses camelCase flat fields
  {
    'event' => event_data,
    'timeslots' => timeslots,
    'timezoneOffset' => 0,
    'receivedTitle' => received_msg['title'] || 'Please pick a time',
    'receivedSubtitle' => received_msg['subtitle'] || 'Select your preferred time slot',
    'receivedImageIdentifier' => received_msg['image_identifier'] || '',
    'receivedStyle' => received_msg['style'] || 'large',
    'replyTitle' => reply_msg['title'] || 'Thank you!',
    'replySubtitle' => reply_msg['subtitle'] || '',
    'replyImageIdentifier' => reply_msg['image_identifier'] || '',
    'replyStyle' => reply_msg['style'] || 'large',
    'images' => images_array
  }
```

Properties stored:
```json
{
  "receivedTitle": "Please pick a time",
  "receivedSubtitle": "Select your preferred time slot",
  "receivedImageIdentifier": "0",
  "receivedStyle": "large",
  "replyTitle": "Thank you!",
  "event": {...},
  "timeslots": [...],
  "images": [...]
}
```

### 4. Apple Form Format (nested camelCase)

**File**: `script/import_as_message_templates.rb:536-576`

```ruby
when /form/
  # Forms need nested camelCase objects
  form_data_with_both = flattened_messages.merge(form_data).merge({
    'receivedMessage' => {
      'title' => received_msg['title'] || form_data['title'] || '',
      'subtitle' => received_msg['subtitle'] || form_data['description'] || '',
      'imageIdentifier' => received_msg['image_identifier'] || '',
      'style' => received_msg['style'] || 'large'
    }.compact,
    'replyMessage' => {
      'title' => reply_msg['title'] || '',
      'subtitle' => reply_msg['subtitle'] || '',
      'imageIdentifier' => reply_msg['image_identifier'] || '',
      'style' => reply_msg['style'] || 'large'
    }.compact,
    'images' => images_array
  })
```

Properties stored:
```json
{
  "title": "Survey Form",
  "description": "Please fill out this form",
  "pages": [...],
  "receivedMessage": {
    "title": "Survey Form",
    "subtitle": "Please fill out this form",
    "imageIdentifier": "0",
    "style": "large"
  },
  "replyMessage": {
    "title": "Thank you!",
    "subtitle": "Form submitted",
    "imageIdentifier": "0",
    "style": "large"
  },
  "images": [...]
}
```

## Testing

Run the test script to verify image extraction:
```bash
ruby script/test_image_extraction.rb
```

Expected output:
```
✅ Images found: 5
- ID: 0
  Name: image_0.png
  Size: 60786 bytes
  Preview: data:image/png;base64,iVBORw0...
```

## Migration Steps

Since templates were already imported with the old format, you must re-import:

### Step 1: Backup and Delete Old Templates

```bash
rails runner script/rollback_template_import.rb --account-id 1 --backup
```

This creates a backup at `tmp/template_backups/rollback_backup_account_1_TIMESTAMP.json`

### Step 2: Re-import with Fixed Format

```bash
rails runner script/import_as_message_templates.rb --account-id 1 --business acoustic_house
```

### Step 3: Verify in Chatwoot UI

1. Go to Settings → Message Templates
2. Click on a migrated template (e.g., "Guitar List Picker")
3. Verify:
   - ✅ Images display as thumbnails (not placeholder icons)
   - ✅ All form fields are visible and editable
   - ✅ Sections/items/pages render correctly

## Expected Outcomes

After re-importing:

### List Picker Editor
- ✅ Sections display with items
- ✅ Images show thumbnails
- ✅ Received/reply message fields are editable
- ✅ Can add/remove sections and items

### Time Picker Editor
- ✅ Event details are editable
- ✅ Timeslots display correctly
- ✅ Images show thumbnails
- ✅ Received/reply message fields are editable

### Form Editor
- ✅ Pages display with field count
- ✅ Each page is expandable/editable
- ✅ Fields display correctly
- ✅ Can add/remove pages and fields
- ✅ Received/reply messages are editable

## Technical Details

### Why Different Formats?

Each editor was built independently:
- **List Picker**: Built first, used Rails convention (snake_case)
- **Time Picker**: Built later, used JavaScript convention (camelCase)
- **Form Editor**: Built with complex nested structure (Vue component pattern)

### Validator vs Editor

- **Validator** (backend): Accepts both formats, normalizes internally
- **Editor** (frontend): Expects specific format, doesn't normalize

### CaseTransformer Impact

The `CaseTransformer` handles conversions when sending to Apple MSP, but doesn't affect what Vue editors expect. Editors read directly from `properties` without transformation.

## Related Files

- `script/import_as_message_templates.rb` - Updated import logic
- `script/test_image_extraction.rb` - Test script for verification
- `script/rollback_template_import.rb` - Backup and delete script
- `app/javascript/.../ListPickerBlockEditor.vue` - List Picker editor (lines 66-106)
- `app/javascript/.../TimePickerBlockEditor.vue` - Time Picker editor (lines 18-45)
- `app/javascript/.../FormBlockEditor.vue` - Form editor (lines 19-36)

## Future Improvements

Consider creating a normalization layer in Vue components to accept any format:
```javascript
// Normalize properties on load
const normalizeProps = (props) => {
  return {
    receivedTitle: props.receivedTitle || props.received_title || '',
    // ... etc
  }
}
```

This would make the system more resilient to format variations.
