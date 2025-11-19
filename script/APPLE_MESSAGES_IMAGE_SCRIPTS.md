# Apple Messages Image Migration Scripts

This directory contains scripts for auditing and migrating Apple Messages images as part of the two-tier image architecture implementation (Phase 3 of IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md).

## Overview

The image architecture uses a hybrid two-tier system:

1. **SharedAppleImage** - Account-wide shared images (system icons, branding)
2. **AppleListPickerImage** - Inbox-specific images (template-specific, custom images)

## Scripts

### 1. audit_image_usage.rb

**Purpose**: Comprehensive audit of all Apple Messages images to identify migration candidates.

**Usage**:
```bash
rails runner script/audit_image_usage.rb
```

**Output**:
- Total image counts and statistics
- System images (messages_png, calendar icons, etc.)
- Branding images (logos, store icons)
- Inbox-specific images
- Duplicate image analysis
- Storage usage and potential savings
- Unused images report
- Migration recommendations

**Categories**:
- **System Images**: Icons used across all inboxes (should be migrated)
- **Branding Images**: Company logos and branding (should be migrated)
- **Inbox-Specific**: Template-specific images (remain in AppleListPickerImage)
- **Duplicates**: Images appearing in multiple inboxes (migration candidates)

**Example Output**:
```
================================ 80 chars ===================================
Apple Messages Image Usage Audit
================================ 80 chars ===================================

Overview:
  Total AppleListPickerImage records: 142
  Total SharedAppleImage records: 5
  Total accounts with images: 2
  Total inboxes with images: 4

System Images (candidates for SharedAppleImage - type: system):
--------------------------------------------------------------------------------
  messages_png                             | Inboxes:  3 | Records:  3 | ⚠️  DUPLICATE
  calendar_filled                          | Inboxes:  2 | Records:  2 | ⚠️  DUPLICATE
  Total system images: 2

Branding Images (candidates for SharedAppleImage - type: branding):
--------------------------------------------------------------------------------
  apple_store_logo                         | Inboxes:  3 | Records:  3 | ⚠️  DUPLICATE
  Total branding images: 1

Storage Analysis:
--------------------------------------------------------------------------------
  Total images with attachments: 140
  Total storage used: 15.42 MB
  Storage in duplicated images: 3.87 MB
  Potential savings: 3.87 MB (25.1%)

Migration Recommendations:
================================ 80 chars ===================================

System Images (image_type: "system"):
  - messages_png (appears in 3 inbox(es))
  - calendar_filled (appears in 2 inbox(es))

Branding Images (image_type: "branding"):
  - apple_store_logo (appears in 3 inbox(es))

Total migration candidates: 3

Next Steps:
  1. Review the migration candidates above
  2. Run: rails runner script/migrate_system_images_to_shared.rb
  3. Verify migration with: rails runner script/verify_shared_images.rb
```

---

### 2. migrate_system_images_to_shared.rb

**Purpose**: Migrate system images (messages_png, calendar icons, etc.) from AppleListPickerImage to SharedAppleImage.

**Usage**:
```bash
# Dry run (preview only)
rails runner script/migrate_system_images_to_shared.rb

# Actual migration
rails runner script/migrate_system_images_to_shared.rb --execute
```

**What it does**:
1. Identifies system images defined in SYSTEM_IMAGES configuration
2. Finds source images from AppleListPickerImage (one per account)
3. Creates SharedAppleImage records with `image_type: 'system'`
4. Attaches the same blob (no duplication)
5. Preserves original AppleListPickerImage for backward compatibility
6. Records migration metadata

**Configuration**:
Edit `SYSTEM_IMAGES` hash in the script to add/remove system images:
```ruby
SYSTEM_IMAGES = {
  'messages_png' => {
    type: 'system',
    description: 'Messages app icon for received message'
  },
  'calendar_icon' => {
    type: 'system',
    description: 'Calendar icon for time picker'
  }
  # Add more...
}.freeze
```

**Safety**:
- Dry run by default (requires `--execute` flag)
- Confirmation prompt in execute mode
- Transaction-safe (rolls back on error)
- Original images preserved
- Skips if already exists

---

### 3. migrate_branding_images_to_shared.rb

**Purpose**: Migrate branding images (logos, store icons) from AppleListPickerImage to SharedAppleImage.

**Usage**:
```bash
# Dry run for all accounts
rails runner script/migrate_branding_images_to_shared.rb

# Execute for specific account
rails runner script/migrate_branding_images_to_shared.rb --execute --account=1

# Execute for all accounts
rails runner script/migrate_branding_images_to_shared.rb --execute --all-accounts
```

**What it does**:
1. Identifies branding images defined in BRANDING_IMAGES configuration
2. Finds source images from AppleListPickerImage (one per account)
3. Creates SharedAppleImage records with `image_type: 'branding'`
4. Attaches the same blob (no duplication)
5. Preserves original AppleListPickerImage for backward compatibility

**Configuration**:
Edit `BRANDING_IMAGES` hash in the script:
```ruby
BRANDING_IMAGES = {
  'apple_store_logo' => {
    description: 'Apple Store logo for store selection'
  },
  'company_logo' => {
    description: 'Company branding logo'
  }
  # Add more...
}.freeze
```

**Safety**:
- Dry run by default
- Requires account specification in execute mode
- Confirmation prompt
- Original images preserved
- Includes verification step

---

### 4. verify_shared_images.rb

**Purpose**: Verify SharedAppleImage migration and check image attachments.

**Usage**:
```bash
rails runner script/verify_shared_images.rb
```

**What it checks**:
1. SharedAppleImage record counts by type
2. Attachment status (with/without attachments)
3. Lists all shared images by account
4. Tests ImageFetchService fallback logic
5. Identifies issues (missing attachments, etc.)

**Example Output**:
```
================================ 80 chars ===================================
Verify SharedAppleImage Migration
================================ 80 chars ===================================

SharedAppleImage Overview:
  Total records: 5
  System images: 3
  Branding images: 2
  Template images: 0

Attachment Status:
  ✅ With attachments: 5
  ❌ Without attachments: 0

Shared Images by Account:
--------------------------------------------------------------------------------
  Account 1:
    ✅ [SYSTEM    ] messages_png - Messages app icon for received message
    ✅ [SYSTEM    ] calendar_filled - Calendar icon (filled)
    ✅ [BRANDING  ] apple_store_logo - Apple Store logo

Fallback Logic Test:
--------------------------------------------------------------------------------
Testing if ImageFetchService can find shared images...

  Testing identifier: messages_png
  Account: 1

  Using inbox: 5 (Rhaps AMB)

  ✅ No inbox-specific image (will fallback to shared)

  ImageFetchService fallback priority:
    1. Inbox-specific (AppleListPickerImage)
    2. Shared account-wide (SharedAppleImage) ← Would use this
    3. Embedded images (content_attributes)

================================ 80 chars ===================================
Verification Complete
================================ 80 chars ===================================

✅ All shared images are properly configured
   Migration successful!
```

---

## Migration Workflow

### Recommended Process

1. **Audit current images**:
   ```bash
   rails runner script/audit_image_usage.rb > /tmp/image_audit.txt
   ```
   Review the output to understand duplication and migration candidates.

2. **Migrate system images** (dry run first):
   ```bash
   # Preview
   rails runner script/migrate_system_images_to_shared.rb

   # Execute
   rails runner script/migrate_system_images_to_shared.rb --execute
   ```

3. **Migrate branding images** (dry run first):
   ```bash
   # Preview
   rails runner script/migrate_branding_images_to_shared.rb

   # Execute for account 1
   rails runner script/migrate_branding_images_to_shared.rb --execute --account=1

   # Or execute for all accounts
   rails runner script/migrate_branding_images_to_shared.rb --execute --all-accounts
   ```

4. **Verify migration**:
   ```bash
   rails runner script/verify_shared_images.rb
   ```

5. **Test in application**:
   - Send list picker with system images
   - Send time picker with calendar icon
   - Verify ImageFetchService logs show "Found in shared"

---

## Image Categories

### System Images (image_type: 'system')

**Definition**: Icons and UI elements used across all Apple Messages features, independent of account or template.

**Examples**:
- `messages_png` - Messages app icon for received messages
- `calendar_filled` - Calendar icon (filled)
- `calendar_outline` - Calendar icon (outline)
- `time_picker_icon` - Time picker icon

**Should be migrated**: YES - These appear in all inboxes and should be shared.

---

### Branding Images (image_type: 'branding')

**Definition**: Company-specific logos, store icons, and brand assets used across multiple templates.

**Examples**:
- `apple_store_logo` - Apple Store logo
- `company_logo` - Company branding logo
- `store_icon` - Store location icon

**Should be migrated**: YES - These are company-specific but used across all inboxes in the account.

---

### Inbox-Specific Images

**Definition**: Template-specific images that are unique to a particular conversation flow or inbox.

**Examples**:
- Guitar lesson images (specific to music store template)
- Product photos (specific to product templates)
- Custom form headers

**Should be migrated**: NO - These remain in AppleListPickerImage.

---

## Storage Patterns

### System Image Patterns

```ruby
SYSTEM_IMAGE_PATTERNS = [
  /^messages_png$/,
  /^calendar_/,
  /^time_picker_/
].freeze
```

### Branding Image Patterns

```ruby
BRANDING_IMAGE_PATTERNS = [
  /^apple_store_logo$/,
  /^company_logo$/,
  /^brand_/,
  /_logo$/
].freeze
```

---

## Fallback Hierarchy

When ImageFetchService fetches an image, it follows this priority:

1. **AppleListPickerImage** (inbox-specific) - Highest priority
   - Includes `shared_override: true` (inbox-specific override of shared image)
   - Includes `shared_override: false` (truly inbox-specific image)

2. **SharedAppleImage** (account-wide) - Fallback
   - `image_type: 'system'` - System icons
   - `image_type: 'branding'` - Company branding
   - `image_type: 'template'` - Reusable templates

3. **Embedded images** (content_attributes['images']) - Last resort
   - Template-specific base64 images

---

## Troubleshooting

### Image not found after migration

**Check**:
```bash
rails runner "
  img = SharedAppleImage.find_by(identifier: 'messages_png')
  puts img.inspect
  puts 'Attached: ' + img.image.attached?.to_s
"
```

**Solution**: Re-run migration script or manually create SharedAppleImage.

---

### Duplicate images still showing

**Check**:
```bash
rails runner script/audit_image_usage.rb | grep DUPLICATE
```

**Solution**: Migration scripts preserve originals. This is intentional for backward compatibility. Images will be automatically cleaned up in future phase.

---

### ImageFetchService not finding shared images

**Check logs**:
```bash
tail -f log/development.log | grep ImageFetch
```

**Look for**:
- `[ImageFetch] ✅ Found in shared (system): messages_png`
- `[ImageFetch] ⚠️  Image not found: messages_png`

**Solution**: Ensure ImageFetchService is integrated into send services (Phase 2 complete).

---

## Documentation

- **Architecture Plan**: `/docs/apple-messages/IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md`
- **Phase 1**: Model creation and ImageFetchService (COMPLETE)
- **Phase 2**: Service integration (COMPLETE)
- **Phase 3**: Migration utilities (THIS PHASE)
- **Phase 4**: API endpoints (PLANNED)
- **Phase 5**: Frontend integration (PLANNED)

---

## Adding New Image Types

### To add a new system image:

1. Edit `script/migrate_system_images_to_shared.rb`:
   ```ruby
   SYSTEM_IMAGES = {
     # ... existing images
     'new_system_icon' => {
       type: 'system',
       description: 'Description of new icon'
     }
   }.freeze
   ```

2. Re-run migration:
   ```bash
   rails runner script/migrate_system_images_to_shared.rb --execute
   ```

### To add a new branding image:

1. Edit `script/migrate_branding_images_to_shared.rb`:
   ```ruby
   BRANDING_IMAGES = {
     # ... existing images
     'new_brand_logo' => {
       description: 'Description of new logo'
     }
   }.freeze
   ```

2. Re-run migration:
   ```bash
   rails runner script/migrate_branding_images_to_shared.rb --execute --account=YOUR_ACCOUNT_ID
   ```

---

## Safety & Rollback

### Safety Features

- Dry run by default (both migration scripts)
- Confirmation prompts in execute mode
- Transaction-safe (atomic operations)
- Original images preserved (no deletion)
- Comprehensive error handling and logging

### Rollback

If you need to rollback:

1. **Delete SharedAppleImage records**:
   ```bash
   rails runner "
     SharedAppleImage.where(identifier: ['messages_png', 'apple_store_logo']).destroy_all
   "
   ```

2. **Original AppleListPickerImage records remain** - No data loss.

3. **ImageFetchService will fallback** to inbox-specific images automatically.

---

## Performance Considerations

### Query Optimization

Migration scripts use:
- `includes(image_attachment: :blob)` to avoid N+1 queries
- `distinct.pluck(:account_id)` for efficient account grouping
- Batch processing per account

### Storage Efficiency

- Shared images reference same blob (no duplication)
- ActiveStorage handles blob lifecycle
- Potential storage savings: 25-50% for duplicated images

---

## Questions?

See the full architecture plan:
- `/docs/apple-messages/IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md`

Or contact the development team.
