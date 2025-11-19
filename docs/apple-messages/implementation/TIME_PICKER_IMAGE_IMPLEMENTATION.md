# Time Picker Image Implementation

## Summary

Added time_picker.png image to the lesson scheduling time picker in the Acoustic House Bot service.

## Changes Made

### 1. Service Code Updated
**File**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

**Method**: `send_lesson_time_picker` (lines 1982-2041)

**Changes**:
- Defined image identifier: `time_picker_lesson`
- Fetches and encodes image from ActiveStorage using existing `fetch_and_encode_images` helper
- Added image fields to content_attributes:
  - `received_image_identifier`: Shows image in the received message bubble
  - `reply_image_identifier`: Shows image in the reply message bubble
  - `images`: Base64-encoded image data array

### 2. Image Upload Script Created
**File**: `script/upload_time_picker_image.rb`

**Purpose**: Uploads time_picker.png to ActiveStorage for all Apple Messages for Business inboxes

**Source Image**: `/Users/rhaps/LocalGit/chatwoot/_apple/Acoustic-House-Bot-origin/acoustichouse/images/time_picker.png`

**Image Identifier**: `time_picker_lesson`

## Implementation Details

The implementation follows the established patterns in the codebase:

1. **CaseTransformer Compliance**: All data uses snake_case internally, and `SendTimePickerService` will automatically transform to camelCase when sending to Apple MSP (as per CLAUDE.md AMB guidelines)

2. **Automatic Image Fallback**: `SendTimePickerService` has built-in logic to use `received_image_identifier` for `reply_image_identifier` if not explicitly set, but we're setting both explicitly for clarity

3. **Image Storage**: Uses `AppleListPickerImage` model for ActiveStorage (shared across all AMB interactive message types)

4. **Base64 Encoding**: The `fetch_and_encode_images` helper handles fetching from ActiveStorage and encoding to base64 format required by Apple MSP

## How to Deploy

### Step 1: Upload the Image to ActiveStorage

Run the upload script from your terminal (not Claude Code - database access restricted):

```bash
rails runner script/upload_time_picker_image.rb
```

This will:
- Find all Apple Messages for Business channels/inboxes
- Upload time_picker.png to ActiveStorage for each inbox
- Create `AppleListPickerImage` records with identifier `time_picker_lesson`
- Skip inboxes where the image already exists

### Step 2: Verify the Upload

Check that images were uploaded successfully:

```bash
rails runner "AppleListPickerImage.where(identifier: 'time_picker_lesson').each { |img| puts '✅ Inbox: ' + img.inbox.name + ' - Image attached: ' + img.image.attached?.to_s }"
```

### Step 3: Test the Feature

1. Start a conversation with the Acoustic House Bot
2. Progress through the flow to the lesson scheduling step
3. Verify that the time picker displays the time_picker.png image in both:
   - Received message bubble (before user selects a time)
   - Reply message bubble (after user selects a time)

## Code Architecture

### Data Flow

```
Frontend → API Controller (auto-normalizes camelCase → snake_case)
                ↓
         Database (snake_case)
                ↓
  AcousticHouseBotService (builds content_attributes with snake_case)
                ↓
    SendTimePickerService (reads snake_case, transforms to camelCase)
                ↓
         Apple MSP API (camelCase)
```

### Image Flow

```
time_picker.png (filesystem)
        ↓
upload_time_picker_image.rb script
        ↓
ActiveStorage (AppleListPickerImage model)
        ↓
fetch_and_encode_images([time_picker_image_id])
        ↓
Base64-encoded in content_attributes['images']
        ↓
SendTimePickerService includes in Apple MSP payload
        ↓
Apple MSP renders image in Messages app
```

## Related Files

- **Service**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`
- **Time Picker Service**: `app/services/apple_messages_for_business/send_time_picker_service.rb`
- **Image Model**: `app/models/apple_list_picker_image.rb`
- **Upload Script**: `script/upload_time_picker_image.rb`
- **Source Image**: `_apple/Acoustic-House-Bot-origin/acoustichouse/images/time_picker.png`

## Testing Checklist

- [ ] Run upload script successfully
- [ ] Verify image uploaded to ActiveStorage
- [ ] Test time picker displays image in received message
- [ ] Test time picker displays image in reply message
- [ ] Verify image loads correctly on iOS Messages app
- [ ] Check logs for any image encoding errors
- [ ] Confirm no performance degradation (base64 encoding is cached)

## Rollback Plan

If issues arise, you can:

1. **Remove image identifiers** from send_lesson_time_picker:
   ```ruby
   # Remove these lines:
   time_picker_image_id = 'time_picker_lesson'
   images = fetch_and_encode_images([time_picker_image_id])
   'received_image_identifier' => time_picker_image_id,
   'reply_image_identifier' => time_picker_image_id,
   'images' => images,
   ```

2. **Delete uploaded images** (if needed):
   ```bash
   rails runner "AppleListPickerImage.where(identifier: 'time_picker_lesson').destroy_all"
   ```

## Notes

- The time_picker.png image (22 KB) is small and won't significantly impact message payload size
- Image is fetched and encoded once per message send, then cached by Apple MSP
- The same image appears in both received and reply messages for visual consistency
- Image identifier `time_picker_lesson` is unique to avoid conflicts with other features
