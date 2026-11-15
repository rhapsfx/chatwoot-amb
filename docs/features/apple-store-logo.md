# Apple Store Logo Upload Guide

## Overview

This guide explains how to add the Apple Store logo image to the store selection list picker in the Acoustic House Bot.

## What Changed

The `send_store_selection_list_picker` method has been enhanced to display an Apple logo on each store item in the list picker. This provides better visual consistency and branding.

### Modified Method

**File**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

**Method**: `send_store_selection_list_picker` (lines 2130-2204)

**Changes**:
1. Added `image_identifier: 'apple_store_logo'` to each list picker item
2. Added `images` array with base64-encoded Apple logo
3. Added `received_image_identifier` and `reply_image_identifier` fields
4. Image is fetched using the existing `fetch_and_encode_images` method

## Image Upload Script

A script has been created to upload the Apple logo to all Apple Messages for Business inboxes.

**File**: `script/upload_apple_store_logo.rb`

### Usage

Run the script to upload the image:

```bash
# Using rails runner (RECOMMENDED)
rails runner script/upload_apple_store_logo.rb

# Or directly with Ruby (must be in project root)
ruby script/upload_apple_store_logo.rb
```

### What the Script Does

1. Locates the `apple.jpg` file at `_apple/Acoustic-House-Bot-origin/acoustichouse/images/apple.jpg`
2. Finds all Apple Messages for Business inboxes
3. Creates an `AppleListPickerImage` record with identifier `apple_store_logo`
4. Attaches the image to ActiveStorage
5. Skips inboxes that already have the image

### Output

```
📸 Found apple.jpg (17346 bytes)
📥 Found 1 Apple Messages inbox(es)

🔄 Processing inbox: Apple Messages Demo (ID: 123)
  ✅ Successfully uploaded apple_store_logo to inbox 123

✨ Upload complete!
```

## Implementation Details

### Image Identifier

- **Identifier**: `apple_store_logo`
- **Purpose**: Display Apple logo on store selection list picker items
- **Format**: JPEG
- **Source**: `_apple/Acoustic-House-Bot-origin/acoustichouse/images/apple.jpg`

### Database Storage

Images are stored using ActiveStorage via the `AppleListPickerImage` model:

```ruby
AppleListPickerImage.create!(
  inbox_id: inbox.id,
  account_id: inbox.account_id,
  identifier: 'apple_store_logo',
  description: 'Apple Store logo for store selection list picker',
  original_name: 'apple.jpg'
)
```

### CaseTransformer Integration

The implementation follows the CLAUDE.md AMB guidelines and uses CaseTransformer:

- Internal storage: `image_identifier`, `received_image_identifier`, `reply_image_identifier` (snake_case)
- Apple MSP API: Automatically converted to `imageIdentifier`, `receivedImageIdentifier`, `replyImageIdentifier` (camelCase)
- Transformation handled by `AppleMessagesForBusiness::SendListPickerService`

## Testing

After uploading the image, test the store selection flow:

1. Start a conversation with the bot
2. Progress to the location/store selection step (state AHG2)
3. Provide a location that returns 6+ Apple Stores
4. The list picker should now display the Apple logo on each store item
5. Both receivedMessage and replyMessage should also show the Apple logo

## Verification

Check if the image was uploaded successfully:

```bash
# Using rails console
rails console

# Check if image exists
AppleListPickerImage.where(identifier: 'apple_store_logo').each do |img|
  puts "Inbox: #{img.inbox.name}, Image attached: #{img.image.attached?}"
end
```

## Troubleshooting

### Image Not Displaying

1. Verify image was uploaded:
   ```bash
   rails runner "puts AppleListPickerImage.where(identifier: 'apple_store_logo').count"
   ```

2. Check logs for encoding errors:
   ```bash
   tail -f log/development.log | grep "apple_store_logo"
   ```

3. Ensure the inbox has the image:
   ```bash
   rails runner "inbox_id = YOUR_INBOX_ID; img = AppleListPickerImage.find_by(inbox_id: inbox_id, identifier: 'apple_store_logo'); puts img.inspect"
   ```

### Upload Script Fails

- **File not found**: Verify `_apple/Acoustic-House-Bot-origin/acoustichouse/images/apple.jpg` exists
- **Permission denied**: Run with `rails runner` instead of direct ruby execution
- **Database error**: Ensure database is running and accessible

## Architecture

This implementation follows the established pattern used in `send_guitar_list_picker`:

1. **Image Storage**: AppleListPickerImage model with ActiveStorage
2. **Image Retrieval**: `fetch_and_encode_images` method
3. **Format Conversion**: Base64 encoding for Apple MSP API
4. **Case Transformation**: Automatic via SendListPickerService
5. **Template Pattern**: Consistent with other list picker implementations

## Related Files

- **Service**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`
- **Model**: `app/models/apple_list_picker_image.rb`
- **Upload Script**: `script/upload_apple_store_logo.rb`
- **Case Transformer**: `app/services/apple_messages_for_business/case_transformer.rb`
- **Send Service**: `app/services/apple_messages_for_business/send_list_picker_service.rb`
