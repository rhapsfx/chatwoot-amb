# Guitar List Picker Image Fix Summary

## Problem
The Acoustic House Bot sends a guitar list picker (template ID 321) but images are incorrect:
- Wrong images are displayed for some guitars
- One image is completely missing
- receivedMessage and replyMessage have no images

## Root Cause
**Image Identifier Mismatch**:
- Template expects image identifiers: `["0", "1", "2", "3", "4"]`
- ActiveStorage only has: `["1", "2", "3", "4"]`
- **Missing identifier**: `"0"`

This means:
- Items using identifier `"0"` show no image (or wrong fallback)
- The bot successfully encodes 4 images but template references 5 identifiers
- receivedMessage/replyMessage may be using the missing identifier `"0"`

## Evidence from Logs
```
[Bot] 🎸 Item image identifiers from template: ["0", "1", "2", "3"]
[Bot] 🎸 All image identifiers: ["0", "1", "2", "3", "4"]
[Bot] 🖼️ Looking for images with identifiers: ["0", "1", "2", "3", "4"]
[Bot] 🖼️ Found 4 images in ActiveStorage: ["3", "1", "2", "4"]
[Bot] 🖼️ Encoded 4 images
```

## Solution

### Automated Fix
Run the fix script to remap template identifiers to match ActiveStorage:

```bash
cd /Users/rhaps/LocalGit/chatwoot
rails runner script/fix_guitar_list_picker_321_images.rb
```

This will:
1. Detect missing identifier `"0"`
2. Remap it to existing identifier `"1"` (duplicate first guitar image)
3. Update template 321 in the database
4. Verify all identifiers now exist

### Diagnosis (Optional)
To see the full diagnostic report before fixing:

```bash
rails runner script/diagnose_guitar_list_picker_images.rb
```

## Alternative Solutions

If the automated fix doesn't work as expected:

### Option 1: Create Missing Image
Upload the missing guitar image with identifier `"0"`:

```ruby
# In rails console or script
inbox = Inbox.where(channel_type: 'Channel::AppleMessagesForBusiness').first
account = inbox.account

# Create AppleListPickerImage with identifier "0"
picker_image = AppleListPickerImage.create!(
  account_id: account.id,
  inbox_id: inbox.id,
  identifier: '0',
  original_name: 'first_guitar.jpg',
  description: 'First Guitar'
)

# Attach image file
picker_image.image.attach(
  io: File.open('/path/to/guitar_image.jpg'),
  filename: 'first_guitar.jpg',
  content_type: 'image/jpeg'
)
```

### Option 2: Manual Template Update
If you want specific control over which guitar uses which image, manually update template 321:

1. Open Rails console: `rails console`
2. Load template: `template = MessageTemplate.find(321)`
3. Inspect current mapping: `template.metadata.dig('apple_message_content', 'content_attributes', 'list_picker', 'sections')`
4. Update image identifiers as needed
5. Save: `template.save!`

## Testing

After applying the fix, test the bot:

1. Send a test message to trigger the bot
2. Complete the form
3. Verify guitar list picker displays with all images correctly
4. Check that receivedMessage and replyMessage show images

## Files Modified/Created

**New Scripts**:
- `script/diagnose_guitar_list_picker_images.rb` - Diagnostic tool
- `script/fix_guitar_list_picker_321_images.rb` - Automated fix

**Service Files** (already updated):
- `app/services/apple_messages_for_business/acoustic_house_bot_service.rb` - Enhanced image fetching with logging

## Next Steps

1. Run the fix script to update template 321
2. Test the bot flow end-to-end
3. Verify all 4 guitar images display correctly
4. Check receivedMessage/replyMessage images
5. If issues persist, run diagnostic script and review output
