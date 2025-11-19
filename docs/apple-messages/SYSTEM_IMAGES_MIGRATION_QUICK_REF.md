# migrate_system_images_to_shared.rb - Quick Reference

## Purpose
Migrate system images from inbox-specific to account-wide storage.

## Usage

### Preview (Safe - No Changes)
```bash
rails runner script/migrate_system_images_to_shared.rb
```

### Execute (Actual Migration)
```bash
rails runner script/migrate_system_images_to_shared.rb --execute
```

## What It Does

Migrates these system images:
- `messages_png` → Messages app icon
- `apple_store_logo` → Apple Store branding
- `calendar_icon` → Calendar icon for time picker
- `time_picker_icon` → Time picker icon

## Safety Features
- Dry run by default
- Confirmation prompt in execute mode
- Transaction-wrapped (auto-rollback on error)
- Keeps original images (backward compatible)
- Detailed logging

## Output
```
Processing: messages_png...
  ✅ Migrated messages_png for account 1 (system)
  ⏭️  Skipped messages_png for account 2 (already exists)
  ❌ Failed messages_png for account 3 (no attachment)
```

## Verification
```bash
# Check migrated images
rails runner "SharedAppleImage.all.each { |i| puts i.identifier }"

# Verify attachments
rails runner "SharedAppleImage.all.each { |i| puts \"#{i.identifier}: #{i.image.attached?}\" }"
```

## Rollback
```bash
# Remove all migrated images
rails runner "SharedAppleImage.where(image_type: ['system', 'branding']).destroy_all"
```

## Add New System Images
1. Edit `SYSTEM_IMAGES` hash in script
2. Run migration with `--execute`
3. Verify with rails runner

## Full Documentation
See: `/Users/rhaps/LocalGit/chatwoot/docs/apple-messages/SYSTEM_IMAGES_MIGRATION_SCRIPT.md`
