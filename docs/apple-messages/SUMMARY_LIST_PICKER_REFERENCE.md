# Summary List Picker - Quick Reference

## 13 Summary Items & Assets

| Order | ID | Title | Image File | File Size | Image Identifier |
|-------|--------|--------|------------|-----------|------------------|
| 1 | 1 | 1. Apple Pay | `summary_apple_pay.png` | ~60KB | 0 |
| 2 | 2 | 2. Apple Wallet | `summary_apple_wallet.png` | ~80KB | 1 |
| 3 | 3 | 3. AR Experience | `summary_ar_experience.png` | ~90KB | 2 |
| 4 | 4 | 4. Authentication | `summary_authentication.png` | ~70KB | 3 |
| 5 | 5 | 5. File Sharing | `summary_file_sharing.png` | ~75KB | 4 |
| 6 | 6 | 6. iMessage Apps | `summary_imessage_apps.png` | ~120KB | 5 |
| 7 | 7 | 7. List Picker | `summary_list_picker.png` | ~70KB | 6 |
| 8 | 8 | 8. Media Sharing | `summary_media_sharing.png` | ~85KB | 7 |
| 9 | 9 | 9. QR Code Origination | `summary_qr_code_origination.png` | ~65KB | 8 |
| 10 | 10 | 10. Quick Type Keyboard | `summary_quick_type_keyboard.png` | ~110KB | 9 |
| 11 | 11 | 11. Rich Link Locator | `summary_rich_link_locator.png` | ~100KB | 10 |
| 12 | 12 | 12. Rich Website Links | `summary_rich_website_links.png` | ~90KB | 11 |
| 13 | 13 | 13. Time Picker | `summary_time_picker.png` | ~75KB | 12 |

**Total Template Size**: ~1.1MB (base64-encoded images)

---

## Template Configuration

**Name**: `Summary List Picker`
**Type**: `apple_list_picker`
**Request Identifier**: `lp_summary_0319`

### Received Message
- **Title**: "Feature Sheet"
- **Subtitle**: "Key features that you were exposed to."
- **Style**: "small"
- **Image Identifier**: "0" (summary icon)

### Reply Message
- **Title**: "Response"
- **Subtitle**: "Tap this message to view your selection"

### List Picker Config
- **Title**: "Select a Feature to Learn More"
- **Multiple Selection**: false (single selection only)
- **Section Count**: 1
- **Items Per Section**: 13

---

## Asset Locations

### Source Directory
```
/Users/rhaps/LocalGit/chatwoot/_apple/Acoustic-House-Bot-origin/acoustichouse/images/
```

### Individual Image Paths
```bash
summary_apple_pay.png
summary_apple_wallet.png
summary_ar_experience.png
summary_authentication.png
summary_file_sharing.png
summary_imessage_apps.png
summary_list_picker.png
summary_media_sharing.png
summary_qr_code_origination.png
summary_quick_type_keyboard.png
summary_rich_link_locator.png
summary_rich_website_links.png
summary_time_picker.png
```

---

## Debug Commands

### Verify Template Exists
```bash
rails runner "puts MessageTemplate.find_by(name: 'Summary List Picker')&.name || 'NOT FOUND'"
```

### Count Images in Template
```bash
rails runner "t = MessageTemplate.find_by(name: 'Summary List Picker'); puts t&.metadata&.dig('apple_message_content', 'content_attributes', 'images')&.length || 0"
```

### Count Items in Template
```bash
rails runner "t = MessageTemplate.find_by(name: 'Summary List Picker'); puts t&.metadata&.dig('apple_message_content', 'content_attributes', 'sections', 0, 'items')&.length || 0"
```

### Get Template ID
```bash
rails runner "puts MessageTemplate.find_by(name: 'Summary List Picker')&.id || 'NOT FOUND'"
```

### Delete and Recreate Template
```bash
rails runner "MessageTemplate.find_by(name: 'Summary List Picker')&.destroy"
rails runner script/create_summary_list_picker_template.rb
```

---

## JSON Structure (Simplified)

```json
{
  "images": [
    { "identifier": "0", "data": "iVBORw0KGgo..." },
    { "identifier": "1", "data": "iVBORw0KGgo..." },
    // ... 11 more images
  ],
  "sections": [
    {
      "items": [
        {
          "title": "1. Apple Pay",
          "identifier": "1",
          "image_identifier": "0",
          "order": 1
        },
        // ... 12 more items
      ]
    }
  ],
  "summary_text": "Select a Feature to Learn More",
  "received_title": "Feature Sheet",
  "received_subtitle": "Key features that you were exposed to.",
  "received_image_identifier": "0",
  "reply_title": "Response",
  "reply_subtitle": "Tap this message to view your selection",
  "multiple_selection": false
}
```

---

## Troubleshooting

### Issue: Template not found
**Solution**:
```bash
rails runner script/create_summary_list_picker_template.rb
```

### Issue: Images not loading
**Check**:
1. All 13 image files exist in source directory
2. Template has exactly 13 images in metadata
3. Each item's `image_identifier` matches an image identifier

**Verify**:
```bash
cd /Users/rhaps/LocalGit/chatwoot/_apple/Acoustic-House-Bot-origin/acoustichouse/images
ls summary_*.png | wc -l
# Should output: 13
```

### Issue: Wrong number of items
**Expected**: 13 items total
**Check**:
```bash
rails runner "t = MessageTemplate.find_by(name: 'Summary List Picker'); items = t&.metadata&.dig('apple_message_content', 'content_attributes', 'sections', 0, 'items'); puts items&.map { |i| i['title'] }&.join('\n') || 'NO ITEMS'"
```

### Issue: Template size too large
**Current Size**: ~1.1MB (acceptable for JSONB)
**PostgreSQL Limit**: ~1GB (far below limit)

If size becomes an issue:
- Consider using ActiveStorage for images
- Reference images by URL instead of base64
- Requires SendListPickerService update

---

## Integration Points

### Bot Service Method
```ruby
def send_summary_list_picker
  template = MessageTemplate.find_by(
    account_id: @conversation.account_id,
    name: 'Summary List Picker'
  )

  # Creates message and sends via SendListPickerService
end
```

### State Flow
```
AHK1 (handle_summary)
  → send_summary_list_picker
  → User selects item
  → (Optional: handle_summary_selection - not implemented)
  → AHK2 (handle_final_message)
```

### Interactive Handler
```ruby
INTERACTIVE_HANDLERS = {
  'lp_summary_0319' => :handle_summary_selection # Optional
}
```

---

## Apple MSP API Reference

### List Picker Specification
- **Type**: `list_picker`
- **Max Items**: No strict limit (13 is well within bounds)
- **Image Format**: Base64-encoded PNG
- **Image Size**: Recommended < 500KB per image
- **Multiple Selection**: Boolean (we use `false`)

### CaseTransformer Compliance
All field names are automatically converted:
- Internal (snake_case): `image_identifier`, `summary_text`
- Apple MSP (camelCase): `imageIdentifier`, `summaryText`

No manual case conversion needed - handled by `SendListPickerService`.

---

**Last Updated**: November 12, 2025
**Phase**: 4
**Status**: ✅ Ready for Testing
