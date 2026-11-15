# System Images Migration Script

**File**: `/Users/rhaps/LocalGit/chatwoot/script/migrate_system_images_to_shared.rb`
**Purpose**: Migrate system images from inbox-specific AppleListPickerImage to account-wide SharedAppleImage
**Phase**: Phase 3 of IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md

## Overview

This script migrates system-wide images (like `messages_png`, `apple_store_logo`, etc.) from the inbox-scoped `AppleListPickerImage` table to the account-wide `SharedAppleImage` table. This eliminates the need to manually replicate system images across every Apple Messages inbox.

## Architecture Context

### Current Problem
- All images are inbox-specific (`AppleListPickerImage`)
- System images must be manually copied to every inbox
- Bot service fails if images aren't in the exact inbox being used
- Storage waste from duplicate images

### Solution
Two-tier image architecture:
1. **SharedAppleImage** (account-wide) - System icons, branding, reusable templates
2. **AppleListPickerImage** (inbox-specific) - Inbox-specific overrides and custom images

### Fallback Hierarchy
```
ImageFetchService checks in order:
1. AppleListPickerImage (inbox-specific, highest priority)
2. SharedAppleImage (account-wide, fallback)
3. Embedded images (template-specific, last resort)
```

## System Images Configuration

The script migrates these predefined system images:

```ruby
SYSTEM_IMAGES = {
  'messages_png' => {
    type: 'system',
    description: 'Messages app icon for received message'
  },
  'apple_store_logo' => {
    type: 'branding',
    description: 'Apple Store logo'
  },
  'calendar_icon' => {
    type: 'system',
    description: 'Calendar icon for time picker'
  },
  'time_picker_icon' => {
    type: 'system',
    description: 'Time picker icon'
  }
}
```

### Image Types
- **system**: System-wide icons (messages_png, calendar icons)
- **branding**: Company branding (logos, colors)
- **template**: Reusable template images

## Usage

### Dry Run (Preview)
```bash
# Preview migration without making changes
rails runner script/migrate_system_images_to_shared.rb
```

**Output Example**:
```
================================================================================
System Images Migration to SharedAppleImage
================================================================================

Mode: DRY RUN (Preview Only)

This script will migrate the following system images:
  - messages_png (system): Messages app icon for received message
  - apple_store_logo (branding): Apple Store logo
  - calendar_icon (system): Calendar icon for time picker
  - time_picker_icon (system): Time picker icon

Processing: messages_png...
  🔍 Would migrate messages_png for account 1 (system)
      Source: AppleListPickerImage ID 42 from inbox 4
      Image: Messages.png (2048 bytes)
  ⏭️  Skipped messages_png for account 2 (already exists in SharedAppleImage)

Processing: apple_store_logo...
  🔍 Would migrate apple_store_logo for account 1 (branding)
      Source: AppleListPickerImage ID 58 from inbox 5
      Image: apple.jpg (4096 bytes)

================================================================================
Migration Summary
================================================================================

Mode: DRY RUN
Total images processed: 4
✅ Successfully migrated: 2
⏭️  Skipped (already exist): 1
❌ Failed: 1

This was a DRY RUN. No changes were made.
Run with --execute flag to perform actual migration:
  rails runner script/migrate_system_images_to_shared.rb --execute
```

### Actual Migration
```bash
# Perform actual migration
rails runner script/migrate_system_images_to_shared.rb --execute
```

**You will be prompted to confirm**:
```
WARNING: This will migrate images from AppleListPickerImage to SharedAppleImage.
Original images will be kept for backward compatibility.

Type "yes" to confirm: yes
```

## Safety Features

### 1. Dry Run by Default
- Script defaults to preview mode
- Must explicitly pass `--execute` to make changes
- Shows exactly what will happen before execution

### 2. Confirmation Prompt
- Interactive confirmation required in execute mode
- Type "yes" to proceed, anything else cancels

### 3. Transaction Wrapping
- Each migration wrapped in database transaction
- Automatic rollback on error
- No partial migrations

### 4. Detailed Logging
- Logs every operation with context
- Shows source inbox, image size, IDs
- Comprehensive error messages

### 5. Error Handling
- Graceful handling of missing images
- Continues processing even if one fails
- Collects all errors for summary

### 6. Backward Compatibility
- Original `AppleListPickerImage` records kept intact
- No data loss, only additions
- Can rollback by deleting SharedAppleImage records

### 7. Metadata Tracking
```ruby
# Each migrated image includes metadata
metadata: {
  migrated_from_inbox_id: source_image.inbox_id,
  migrated_from_picker_image_id: source_image.id,
  migrated_at: Time.current.iso8601,
  original_description: source_image.description
}
```

## Migration Logic

### Per-Account Processing
```ruby
# For each system image:
1. Find all accounts that have this image in any inbox
2. For each account:
   a. Check if already exists in SharedAppleImage → Skip
   b. Find source AppleListPickerImage with attachment
   c. Create SharedAppleImage with same blob (no duplication)
   d. Log result
```

### Blob Attachment Strategy
```ruby
# Reuses existing blob, no data duplication
shared_image.image.attach(source_image.image.blob)
```

**Benefits**:
- No storage duplication
- Instant migration (no file copying)
- Same binary data, just new reference

## Status Indicators

- **✅** Successfully migrated
- **⏭️** Skipped (already exists)
- **❌** Failed (error occurred)
- **⚠️** Warning (no attachment)
- **🔍** Preview (dry run)

## Verification

### After Migration
```bash
# Check migrated images
rails runner "SharedAppleImage.all.each { |i| puts \"#{i.identifier} (#{i.image_type}) - Account #{i.account_id}\" }"

# Verify image attachments
rails runner "SharedAppleImage.all.each { |i| puts \"#{i.identifier}: #{i.image.attached? ? 'Attached' : 'Missing'}\" }"

# Check metadata
rails runner "SharedAppleImage.first.metadata"
```

### Test Image Fetching
```ruby
# Test three-tier fallback
service = AppleMessagesForBusiness::ImageFetchService.new(
  account_id: 1,
  inbox_id: 5,
  embedded_images: []
)

images = service.fetch_and_encode(['messages_png'])
puts "Found: #{images.first[:source]}"  # Should show "shared_system"
```

## Common Scenarios

### Scenario 1: Fresh Migration
```
- All system images exist in AppleListPickerImage
- No SharedAppleImage records yet
- Result: All images migrated successfully
```

### Scenario 2: Partial Migration
```
- Some images already migrated
- Script skips existing, migrates new
- Result: Only new images migrated, existing unchanged
```

### Scenario 3: Multi-Account Setup
```
- Same image in multiple accounts
- Script migrates once per account
- Result: Each account has its own SharedAppleImage
```

### Scenario 4: Missing Attachments
```
- AppleListPickerImage exists but no blob
- Script logs warning, continues
- Result: Skipped, requires manual fix
```

## Rollback

### Emergency Rollback
```bash
# Delete all migrated images
rails runner "SharedAppleImage.where(image_type: ['system', 'branding']).destroy_all"
```

### Selective Rollback
```bash
# Delete specific image
rails runner "SharedAppleImage.where(identifier: 'messages_png').destroy_all"
```

**Note**: Original AppleListPickerImage records remain, so services continue working.

## Adding New System Images

### Step 1: Update Configuration
Edit the script's `SYSTEM_IMAGES` hash:

```ruby
SYSTEM_IMAGES = {
  # ... existing images ...
  'new_icon' => {
    type: 'system',
    description: 'Description of new icon'
  }
}
```

### Step 2: Run Migration
```bash
rails runner script/migrate_system_images_to_shared.rb --execute
```

### Step 3: Verify
```bash
rails runner "SharedAppleImage.where(identifier: 'new_icon').count"
```

## Integration with ImageFetchService

After migration, `ImageFetchService` automatically uses the three-tier fallback:

```ruby
# In AppleMessagesForBusiness::ImageFetchService

def fetch_single_image(identifier)
  # TIER 1: Check inbox-specific (highest priority)
  inbox_image = fetch_from_inbox(identifier)
  return inbox_image if inbox_image.present?

  # TIER 2: Check shared (NEW - uses migrated images)
  shared_image = fetch_from_shared(identifier)
  return shared_image if shared_image.present?

  # TIER 3: Check embedded (fallback)
  embedded_image = fetch_from_embedded(identifier)
  return embedded_image if embedded_image.present?

  Rails.logger.warn "Image not found: #{identifier}"
  nil
end
```

## Performance Considerations

### Efficient Blob Reuse
- No file copying or downloads
- Reuses existing ActiveStorage blobs
- Instant migration

### Batch Processing
- Processes all accounts in memory
- Single query per image identifier
- Minimal database round trips

### Transaction Safety
- Each account migration in own transaction
- Failure doesn't affect other accounts
- Clean rollback on errors

## Troubleshooting

### "No source image found"
**Cause**: Image identifier doesn't exist in any AppleListPickerImage
**Solution**: Upload image first, then run migration

### "No attachment found"
**Cause**: AppleListPickerImage record exists but blob is missing
**Solution**: Re-upload image to AppleListPickerImage

### "Already exists in SharedAppleImage"
**Cause**: Image already migrated
**Solution**: Normal, script skips automatically

### "Validation failed"
**Cause**: Duplicate identifier or missing required fields
**Solution**: Check SharedAppleImage uniqueness constraints

## Timeline Integration

This script is **Phase 3** of the long-term image architecture plan:

- **Phase 1** (Week 1-2): Foundation ✅ Complete
  - Created SharedAppleImage model
  - Added shared_override column
  - Created ImageFetchService

- **Phase 2** (Week 3): Service Integration ✅ Complete
  - Updated all send services
  - Integrated three-tier fallback

- **Phase 3** (Week 4): Migration Utilities ← **You Are Here**
  - **migrate_system_images_to_shared.rb** ← This script
  - migrate_branding_images_to_shared.rb (optional)
  - audit_image_usage.rb (optional)

- **Phase 4** (Week 5): API Endpoints
  - SharedAppleImagesController
  - Frontend integration

## Related Files

### Models
- `/Users/rhaps/LocalGit/chatwoot/app/models/shared_apple_image.rb`
- `/Users/rhaps/LocalGit/chatwoot/app/models/apple_list_picker_image.rb`

### Services
- `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/image_fetch_service.rb`

### Documentation
- `/Users/rhaps/LocalGit/chatwoot/docs/apple-messages/IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md`

### Migrations
- `db/migrate/20251119122654_create_shared_apple_images.rb`
- `db/migrate/20251119122704_add_shared_override_to_apple_list_picker_images.rb`

## Success Metrics

After running this script:

- [ ] System images accessible from any inbox
- [ ] No manual replication needed
- [ ] Storage reduction from deduplicated images
- [ ] "Image not found" errors reduced
- [ ] Bot service works across all inboxes

## Next Steps

1. **Run dry run** to preview migration
2. **Review output** to ensure expected behavior
3. **Run with --execute** to perform migration
4. **Verify** with rails runner commands
5. **Test** ImageFetchService in production
6. **Monitor** logs for "shared_system" source indicators

---

**Created**: 2025-01-19
**Phase**: Phase 3 - Migration Utilities
**Status**: Ready for Testing
