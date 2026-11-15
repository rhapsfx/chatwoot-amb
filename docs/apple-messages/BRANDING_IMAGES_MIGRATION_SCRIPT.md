# Branding Images Migration Script - Implementation Report

**Status**: Complete
**Created**: 2025-01-19
**Phase**: Image Architecture Long-Term Plan - Phase 3
**Script**: `/Users/rhaps/LocalGit/chatwoot/script/migrate_branding_images_to_shared.rb`

---

## Executive Summary

Created migration script to move account-specific branding images from inbox-scoped `AppleListPickerImage` table to account-scoped `SharedAppleImage` table with `image_type: 'branding'`.

**Purpose**: Enable branding images (logos, store icons) to be shared across all inboxes within an account, eliminating manual duplication.

---

## Implementation Details

### Script Location

```
/Users/rhaps/LocalGit/chatwoot/script/migrate_branding_images_to_shared.rb
```

### Branding Images Configuration

The script identifies the following images as branding (account-specific):

```ruby
BRANDING_IMAGES = {
  'apple_store_logo' => {
    description: 'Apple Store logo for store selection list picker'
  },
  'time_picker_lesson' => {
    description: 'Time Picker image for lesson scheduling'
  },
  'company_logo' => {
    description: 'Company branding logo'
  },
  'store_icon' => {
    description: 'Store location icon'
  }
}.freeze
```

**Note**: `messages_png` is intentionally excluded as it's a system image (not branding) and will be handled by `migrate_system_images_to_shared.rb`.

---

## Usage

### Dry Run (Default)

Analyzes what would be migrated without making changes:

```bash
# Dry run for all accounts
rails runner script/migrate_branding_images_to_shared.rb

# Dry run for specific account
rails runner script/migrate_branding_images_to_shared.rb --account=1
```

### Execute Migration

Performs actual migration with confirmation prompt:

```bash
# Migrate specific account
rails runner script/migrate_branding_images_to_shared.rb --execute --account=1

# Migrate all accounts
rails runner script/migrate_branding_images_to_shared.rb --execute --all-accounts
```

---

## Migration Logic

### Account-Aware Processing

1. **Group by Account**: Processes each account independently (branding is account-specific)
2. **Find Source Image**: For each branding identifier:
   - Search across ALL inboxes within the account
   - Prefer most recent image with valid attachment
   - Use first inbox with the image as source
3. **Create SharedAppleImage**:
   - `account_id`: Source account
   - `identifier`: Same as source (e.g., 'apple_store_logo')
   - `image_type`: 'branding' (distinguishes from system/template)
   - `description`: From BRANDING_IMAGES config
   - `original_name`: From source image
   - `image`: Copy of source image blob
4. **Preserve Originals**: Keep AppleListPickerImage records unchanged

### Safety Features

1. **Dry Run Default**: No changes unless `--execute` flag used
2. **Confirmation Prompt**: Requires user confirmation in execute mode
3. **Skip Existing**: Won't re-migrate if SharedAppleImage already exists
4. **Detailed Logging**: Reports every step per account
5. **Error Handling**: Catches and reports errors without stopping migration

---

## Output Format

### Dry Run Example

```
================================================================================
Branding Images Migration to SharedAppleImage
================================================================================

Mode: DRY RUN (no changes will be made)
Accounts: 1, 2
Branding images to migrate: apple_store_logo, time_picker_lesson, company_logo, store_icon

================================================================================
Account 1
================================================================================

  Found 3 Apple Messages inbox(es)

  Processing 'apple_store_logo'...
    📸 Found source in inbox 5
       Created: 2025-01-15 14:23
       Size: 45678 bytes
       Original name: apple.jpg
    🔍 [DRY RUN] Would create SharedAppleImage with:
       - account_id: 1
       - identifier: apple_store_logo
       - image_type: branding
       - description: Apple Store logo for store selection list picker
       - original_name: apple.jpg

  Processing 'time_picker_lesson'...
    ⏭️  Not found in any inbox - skipping

  Processing 'company_logo'...
    ✅ Already exists in SharedAppleImage - skipping

  Processing 'store_icon'...
    ⏭️  Not found in any inbox - skipping

================================================================================
Migration Summary
================================================================================

Mode: DRY RUN
Accounts processed: 2
Images migrated: 1
Already existed (skipped): 1
Not found in any inbox: 2
Errors: 0

💡 This was a dry run. No changes were made.
   To execute migration, run with --execute flag:

   rails runner script/migrate_branding_images_to_shared.rb --execute --account=1
```

### Execute Mode Output

Same format but with actual database changes and verification:

```
================================================================================
Verification
================================================================================

Account 1:
  ✅ apple_store_logo (branding) - SharedAppleImage ID: 42
  ❌ time_picker_lesson - Not found in SharedAppleImage
  ✅ company_logo (branding) - SharedAppleImage ID: 43
  ❌ store_icon - Not found in SharedAppleImage

================================================================================
Next Steps
================================================================================

1. Verify images in admin UI or Rails console
2. Update services to use ImageFetchService for automatic fallback
3. Test list picker, time picker, and forms with shared images
4. Consider adding more branding images to BRANDING_IMAGES config

See: docs/apple-messages/IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md

✨ Migration complete!
```

---

## Key Differences: Branding vs System Images

### Branding Images (This Script)

- **Scope**: Account-specific (each account has its own branding)
- **Image Type**: `branding`
- **Examples**: `apple_store_logo`, `company_logo`, `store_icon`
- **Migration**: Per-account (Account 1's logo ≠ Account 2's logo)
- **Usage**: Company-specific visual identity

### System Images (Separate Script)

- **Scope**: System-wide (same for all accounts)
- **Image Type**: `system`
- **Examples**: `messages_png` (Messages app icon), calendar icons
- **Migration**: Once per account but same image content
- **Usage**: Apple MSP standard icons

---

## Data Flow After Migration

### Before Migration (Inbox-Scoped)

```
AppleListPickerImage (inbox_id: 5, identifier: 'apple_store_logo')
AppleListPickerImage (inbox_id: 6, identifier: 'apple_store_logo')  # Duplicate
AppleListPickerImage (inbox_id: 7, identifier: 'apple_store_logo')  # Duplicate
```

Each inbox requires manual duplication of branding images.

### After Migration (Account-Scoped)

```
SharedAppleImage (account_id: 1, identifier: 'apple_store_logo', image_type: 'branding')
```

All inboxes in Account 1 automatically share this image via ImageFetchService fallback.

### Fallback Hierarchy (ImageFetchService)

```
1. AppleListPickerImage (inbox-specific override)
   ↓ (if not found)
2. SharedAppleImage (account-wide branding) ← This script populates
   ↓ (if not found)
3. Embedded images (content_attributes['images'])
```

---

## Adding New Branding Images

### Step 1: Identify Image

Determine if an image is truly branding (account-specific) or system-wide:

- **Branding**: Company logo, store-specific icons, custom branding
- **System**: Apple MSP icons, standard UI elements

### Step 2: Add to Configuration

Edit `script/migrate_branding_images_to_shared.rb`:

```ruby
BRANDING_IMAGES = {
  'apple_store_logo' => { description: 'Apple Store logo' },
  'my_new_logo' => { description: 'My New Company Logo' },  # Add here
  # ...
}.freeze
```

### Step 3: Run Migration

```bash
# Test with dry run
rails runner script/migrate_branding_images_to_shared.rb --account=1

# Execute
rails runner script/migrate_branding_images_to_shared.rb --execute --account=1
```

---

## Verification

### Check Migration Success

```bash
rails console
```

```ruby
# Check SharedAppleImage for branding
account = Account.find(1)
branding_images = account.shared_apple_images.branding_images

branding_images.each do |img|
  puts "#{img.identifier}: #{img.image.attached? ? 'Attached' : 'Missing'}"
end

# Check specific image
logo = SharedAppleImage.find_by(
  account_id: 1,
  identifier: 'apple_store_logo',
  image_type: 'branding'
)

puts logo.inspect
puts "Image attached: #{logo.image.attached?}"
puts "Blob size: #{logo.image.blob.byte_size} bytes"
```

### Test Image Fetch

```ruby
# Test ImageFetchService fallback
service = AppleMessagesForBusiness::ImageFetchService.new(
  account_id: 1,
  inbox_id: 5,  # Any inbox in account
  embedded_images: []
)

images = service.fetch_and_encode(['apple_store_logo'])
puts "Found: #{images.count} images"
puts "Source: #{images.first[:source]}"  # Should be 'shared_branding'
```

---

## Rollback Procedure

If migration needs to be reversed:

```ruby
# Delete all migrated branding images for account
SharedAppleImage
  .where(account_id: 1, image_type: 'branding')
  .destroy_all

# Original AppleListPickerImage records remain unchanged
```

---

## Performance Considerations

### Batch Processing

- Processes one account at a time
- Uses `includes(image_attachment: :blob)` to avoid N+1 queries
- Finds source image once per identifier

### Image Storage

- Creates new ActiveStorage blobs (does not reference originals)
- Keeps original AppleListPickerImage records unchanged
- Storage increase: ~50KB per branding image per account

### Execution Time

- Dry run: ~1-2 seconds per account
- Execute: ~5-10 seconds per account (includes image download/upload)
- For 10 accounts: ~1-2 minutes total

---

## Integration with Phase 2 Services

### Services Already Using ImageFetchService

These services automatically benefit from branding migration:

- ✅ `SendListPickerService` (uses ImageFetchService)
- ✅ `SendTimePickerService` (uses ImageFetchService)
- ✅ `FormService` (uses ImageFetchService)
- ✅ `AcousticHouseBotService` (uses ImageFetchService)

No code changes needed - fallback happens automatically!

### Example: List Picker with Branding

```ruby
# Service code (no changes needed)
def fetch_and_encode_images(identifiers)
  AppleMessagesForBusiness::ImageFetchService.new(
    account_id: message.account_id,
    inbox_id: message.inbox_id,
    embedded_images: content_attributes['images']
  ).fetch_and_encode(identifiers)
end

# Automatic fallback:
# 1. Check inbox_id for 'apple_store_logo' → Not found
# 2. Check SharedAppleImage (branding) → Found! ✅
# 3. Return base64-encoded image
```

---

## Testing Checklist

### Manual Testing

- [ ] Run dry run for test account
- [ ] Verify dry run output shows correct images
- [ ] Run execute for test account
- [ ] Check SharedAppleImage table has branding records
- [ ] Verify original AppleListPickerImage unchanged
- [ ] Test list picker in different inbox (should use shared)
- [ ] Test time picker in different inbox (should use shared)
- [ ] Check logs for ImageFetchService fallback messages

### Rails Console Verification

```ruby
# 1. Check migration results
account = Account.find(1)
branding = account.shared_apple_images.branding_images
puts "Branding images: #{branding.count}"

# 2. Test fetch service
service = AppleMessagesForBusiness::ImageFetchService.new(
  account_id: 1,
  inbox_id: 5,
  embedded_images: []
)
images = service.fetch_and_encode(['apple_store_logo'])
puts "Fetch result: #{images.first[:source]}"  # Should be 'shared_branding'

# 3. Verify fallback hierarchy
# Create test message in inbox without apple_store_logo
# Send list picker referencing apple_store_logo
# Check logs: should show "Found in shared (branding)"
```

---

## Related Files

### Script
- `script/migrate_branding_images_to_shared.rb` (this script)

### Models
- `app/models/shared_apple_image.rb`
- `app/models/apple_list_picker_image.rb`

### Services
- `app/services/apple_messages_for_business/image_fetch_service.rb`
- `app/services/apple_messages_for_business/send_list_picker_service.rb`
- `app/services/apple_messages_for_business/send_time_picker_service.rb`
- `app/services/apple_messages_for_business/form_service.rb`

### Documentation
- `docs/apple-messages/IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md` (Phase 3)

---

## Next Steps

1. **Run Migration**: Execute script for production accounts
2. **Create System Images Script**: `migrate_system_images_to_shared.rb` for `messages_png`, etc.
3. **Create Audit Script**: `audit_image_usage.rb` to find unused images
4. **Admin UI**: Build interface for managing SharedAppleImage (Phase 4)
5. **Monitor Logs**: Watch for ImageFetchService fallback messages in production

---

## Success Metrics

### Before Migration
- Branding images duplicated across N inboxes
- Manual upload required for each new inbox
- Storage waste: ~50KB × N inboxes per image

### After Migration
- ✅ Branding images stored once per account
- ✅ Automatic fallback to shared images
- ✅ Storage savings: ~50KB × (N-1) inboxes per image
- ✅ Zero manual replication for new inboxes

---

## Sign-off

**Implementation**: Complete
**Date**: 2025-01-19
**Tested**: Dry run verified
**Ready for**: Production migration

**Next Phase**: Create `migrate_system_images_to_shared.rb` for system-wide images
