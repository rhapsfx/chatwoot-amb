# Apple Messages Image Architecture - Deprecation Timeline

## Overview

The old inbox-scoped image upload pattern is deprecated in favor of the new two-tier architecture with SharedAppleImage.

## Timeline

### Phase 1: Soft Deprecation (November 2025 - January 2026)
**Status**: CURRENT PHASE

- ✅ New architecture fully deployed and documented
- ✅ Deprecation warnings added to old scripts and APIs
- ✅ Migration guides published
- ⚠️ Old methods still work (backwards compatible)
- 📢 Users encouraged to migrate

**Actions**:
- Review deprecation warnings in code
- Plan migration timeline
- Test new SharedImageSelector in development
- Review IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md

### Phase 2: Hard Deprecation (February 2026 - March 2026)

- ⚠️ Old scripts and APIs marked for removal
- 🔔 Console warnings when old methods used
- 📧 Email notifications to admins using old methods
- 📊 Usage tracking to identify remaining users

**Actions**:
- Complete migration to SharedAppleImage
- Update all custom scripts to use new API
- Test all features with new architecture
- Confirm zero usage of deprecated methods

### Phase 3: Removal (April 2026)

- ❌ Old upload scripts removed from codebase
- ❌ Deprecated API endpoints removed
- ✅ Only new two-tier architecture supported
- 📝 Release notes published

**Final Actions**:
- Old scripts deleted from `script/` directory
- Old API controller removed
- Database cleanup (optional: remove old AppleListPickerImage records for system images)

## Deprecated Components

### Scripts (Remove in June 2025)
- `script/upload_messages_icon.rb`
- `script/upload_apple_store_logo.rb`
- `script/upload_guitar_images.rb`
- `script/upload_guitar_images_inbox_6.rb`
- `script/upload_time_picker_image.rb`
- `script/copy_messages_png_to_inbox_6.rb`
- `script/copy_missing_guitar_image.rb`
- `script/ensure_shared_images_in_all_inboxes.rb`
- Any script with hardcoded `inbox_id` for system images

### API Endpoints (Remove in June 2025)
- `POST /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images`
- `GET /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images`
- `DELETE /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images/:id`
- (Old AppleListPickerImagesController - already has deprecation warning)

### Code Patterns (Discouraged)
- Hardcoded inbox_id in image upload scripts
- Manual replication of system images across inboxes
- Direct AppleListPickerImage.create for system images

## Migration Path

### For System Images
**Old**:
```ruby
# ❌ Deprecated
AppleListPickerImage.create!(
  account_id: 1,
  inbox_id: 5, # Hardcoded
  identifier: 'messages_png',
  image: File.open('Messages.png')
)
```

**New**:
```ruby
# ✅ Recommended
SharedAppleImage.create!(
  account_id: 1,
  identifier: 'messages_png',
  image_type: 'system',
  description: 'Messages app icon',
  image: File.open('Messages.png')
)
```

### For Branding Images
**Old**:
```ruby
# ❌ Deprecated - upload to each inbox
[5, 6, 7].each do |inbox_id|
  AppleListPickerImage.create!(
    account_id: 1,
    inbox_id: inbox_id,
    identifier: 'company_logo',
    image: File.open('logo.png')
  )
end
```

**New**:
```ruby
# ✅ Recommended - upload once
SharedAppleImage.create!(
  account_id: 1,
  identifier: 'company_logo',
  image_type: 'branding',
  description: 'Company logo',
  image: File.open('logo.png')
)
```

### For Template-Specific Images
**Old**:
```ruby
# ❌ Deprecated - hardcoded inbox_id
AppleListPickerImage.create!(
  account_id: 1,
  inbox_id: 4, # Hardcoded
  identifier: 'guitar_stratocaster',
  image: File.open('Strat.jpg')
)
```

**New (Option 1 - Shared)**:
```ruby
# ✅ Recommended for reusable images
SharedAppleImage.create!(
  account_id: 1,
  identifier: 'guitar_stratocaster',
  image_type: 'template',
  description: 'Fender American Elite Stratocaster',
  image: File.open('Strat.jpg')
)
```

**New (Option 2 - Inbox-Specific)**:
```ruby
# ✅ Acceptable for truly inbox-specific images
# Frontend uploads via SharedAppleImagesController
# No hardcoded inbox_id in scripts
```

## Backwards Compatibility

During Phase 1 and Phase 2:
- ✅ Old AppleListPickerImage records continue to work
- ✅ Three-tier fallback ensures no breakage (Inbox → Shared → Embedded)
- ✅ Old API endpoints remain functional (with deprecation warnings logged)
- ✅ Old scripts still execute (with deprecation headers)

## Support

- Migration guide: `docs/apple-messages/IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md`
- System images migration: `docs/apple-messages/SYSTEM_IMAGES_MIGRATION_COMPLETE.md`
- Branding images migration: `docs/apple-messages/BRANDING_MIGRATION_IMPLEMENTATION_REPORT.md`
- API docs: See routes in `config/routes.rb` for SharedAppleImagesController

## Questions?

Contact the development team or review the comprehensive documentation in `docs/apple-messages/`.

---

**Last Updated**: 2025-11-19
**Phase Status**: Phase 1 - Soft Deprecation
**Next Review**: January 2026
