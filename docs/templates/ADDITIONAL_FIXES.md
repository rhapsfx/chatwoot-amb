# Additional Fixes for Template Migration

## Issues Found

### Issue 1: Image Format Detection
**Problem**: All images were hardcoded as PNG format (`data:image/png;base64,...`), but some images are JPEG or JP2 format.

**Symptom**: Images showed as question mark icon (?) in editor despite being uploaded.

**Fix**: Added automatic image format detection based on base64 magic bytes.

**File**: `script/import_as_message_templates.rb:467-480`

```ruby
# Detect image format from base64 data
image_format = if base64_data.start_with?('iVBORw0KGgo')
                 'png'
               elsif base64_data.start_with?('/9j/')
                 'jpeg'
               elsif base64_data.start_with?('R0lGODlh', 'R0lGODdh')
                 'gif'
               elsif base64_data.start_with?('UklGR')
                 'webp'
               elsif base64_data.start_with?('AAAAHG', 'AAAADGpQ')  # JP2/J2K
                 'jpeg'  # Treat JP2 as JPEG for compatibility
               else
                 'png'  # Default fallback
               end
```

### Issue 2: Navigation Forms Imported as Data Forms
**Problem**: Forms like "howhelp", "guitarNLP", "menunlp" are navigation menus (with type: "page" fields), not data collection forms.

**Symptom**: Forms imported with "0 fields" because navigation buttons aren't real form fields.

**Example Navigation Form**:
```json
{
  "sections": [{
    "title": "How can we help you?",
    "fields": [
      {"type": "page", "title": "My email isn't working", "image_identifier": "Mail"},
      {"type": "page", "title": "Trouble with WiFi", "image_identifier": "WiFi"},
      {"type": "page", "title": "Other topic", "image_identifier": "Other"}
    ]
  }]
}
```

**Fix**: Skip navigation forms during import.

**File**: `script/import_as_message_templates.rb:577-582`

```ruby
# Skip navigation-only forms (fields with type: "page" are navigation buttons)
if fields.all? { |f| f['type'] == 'page' }
  puts "     ⚠️  Skipped: Navigation form (not a data collection form)"
  @stats[:errors] << "Skipped #{template_data['name']}: Navigation form"
  return nil
end
```

## Migration Results

After re-import with fixes:

### Templates That Should Import
- ✅ **guitar_listpicker** - List picker with guitar images (PNG)
- ✅ **guitar_order_listpicker** - List picker with order flow (PNG)
- ✅ **Yes/No quick replies** - Simple confirmation templates

### Templates That Will Be Skipped
- ⚠️ **howhelp** - Navigation form (Menu, not data collection)
- ⚠️ **guitarNLP** - Navigation form (Sound type selector)
- ⚠️ **menunlp** - Navigation form (Topics menu)

These navigation forms should be handled differently:
- Convert to Quick Reply templates, OR
- Document as "not supported" in Chatwoot template system

## Testing Steps

1. Delete existing templates:
   ```bash
   rails runner script/rollback_template_import.rb --account-id 1 --backup
   ```

2. Re-import with fixes:
   ```bash
   rails runner script/import_as_message_templates.rb --account-id 1 --business acoustic_house
   ```

3. Verify in Chatwoot UI:
   - Images display correctly (JPEG, PNG, JP2)
   - No "0 fields" forms
   - Navigation forms are skipped

## Expected Import Results

From 8 filtered templates:
- **2 List Pickers**: guitar_listpicker, guitar_order_listpicker ✅
- **2 Quick Replies**: Yes/No templates ✅
- **3 Navigation Forms**: SKIPPED ⚠️
- **1 Other**: TBD

Total imported: ~4-5 templates (down from 8)

## Image Format Detection

| Format | Magic Bytes | MIME Type |
|--------|------------|-----------|
| PNG | `iVBORw0KGgo` | `image/png` |
| JPEG | `/9j/` | `image/jpeg` |
| GIF | `R0lGODlh`, `R0lGODdh` | `image/gif` |
| WebP | `UklGR` | `image/webp` |
| JP2/J2K | `AAAAHG`, `AAAADGpQ` | `image/jpeg` (treated as JPEG) |

## Navigation Form Characteristics

Navigation forms have:
- All fields with `type: "page"`
- No actual input fields (text, email, phone, etc.)
- Used in bot flows for menu navigation
- Not suitable for Chatwoot template system

## Alternative Solutions for Navigation Forms

### Option A: Convert to Quick Reply
Convert navigation buttons to quick reply items:
```json
{
  "summary_text": "How can we help you?",
  "items": [
    {"title": "My email isn't working", "value": "email_issue"},
    {"title": "Trouble with WiFi", "value": "wifi_issue"},
    {"title": "Other topic", "value": "other"}
  ]
}
```

### Option B: Document as Not Supported
Add note in import summary:
```
⚠️  3 navigation forms skipped (not supported in Chatwoot templates)
   - howhelp
   - guitarNLP
   - menunlp
```

## Updated Files

- `script/import_as_message_templates.rb:467-480` - Image format detection
- `script/import_as_message_templates.rb:577-582` - Navigation form skip logic

## Related Issues

- Template 303: Navigation form with "0 fields" → Now skipped
- Template 306: Likely another navigation form → Will be skipped
- Image "Other" showing ?: Image format issue → Now fixed
