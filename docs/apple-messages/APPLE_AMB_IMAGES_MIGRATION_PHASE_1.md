# Apple AMB Images Controller Migration Guide

**Date**: November 14, 2025
**Status**: Phase 1 Complete (Non-Breaking)
**Migration Phase**: 1 of 3

## Overview

The `apple_list_picker_images` controller and endpoints have been renamed to `apple_amb_images` to better reflect their broader usage across Apple Messages for Business features (list pickers, time pickers, forms, etc.).

## Current State: Phase 1 (Non-Breaking)

Both old and new endpoints are **active and working simultaneously**:

### Old Endpoints (Deprecated but Working)
```
GET    /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images
POST   /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images
DELETE /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images/:id
POST   /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images/copy_from
POST   /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images/bulk_upload
```

**Status**: ⚠️ Deprecated - Logs warning when used
**Action**: Will be removed in Phase 3 (timeline TBD)

### New Endpoints (Recommended)
```
GET    /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images
POST   /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images
DELETE /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images/:id
POST   /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images/copy_from
POST   /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images/bulk_upload
```

**Status**: ✅ Recommended for all new integrations
**Action**: Use this for all new code

## What Changed

### Backend Files

1. **New Controller Created**:
   - `app/controllers/api/v1/accounts/inboxes/apple_amb_images_controller.rb`
   - Identical functionality to old controller
   - Class name: `AppleAmbImagesController`

2. **Old Controller Updated**:
   - `app/controllers/api/v1/accounts/inboxes/apple_list_picker_images_controller.rb`
   - Added deprecation warning: Logs warning on each request
   - Still fully functional

3. **Routes Updated**:
   - `config/routes.rb` lines 247-260
   - Both route sets exist side-by-side

### Frontend Files

1. **New API Client Created**:
   - `app/javascript/dashboard/api/appleAmbImages.js`
   - Class name: `AppleAmbImagesAPI`
   - Resource name: `'apple_amb_images'`

2. **Old API Client**:
   - `app/javascript/dashboard/api/appleListPickerImages.js`
   - Still exists and works
   - Not deprecated yet

3. **Component Updated**:
   - `ImageValidationModal.vue` now uses `AppleAmbImagesAPI`
   - Old import commented out for easy rollback

4. **Second API Client Created** (Simplified version for AppleMessagesComposer):
   - `app/javascript/dashboard/api/appleAmbMessagesImages.js`
   - Class name: `AppleAmbMessagesImagesAPI`
   - Used by: `AppleMessagesComposer.vue`

5. **Second Old API Client** (Deprecated):
   - `app/javascript/dashboard/api/appleMessagesImages.js`
   - Still exists with console deprecation warning
   - Used by: **NONE** (migrated to new client)

### What Did NOT Change

- ✅ **Model**: `AppleListPickerImage` - unchanged
- ✅ **Database Table**: `apple_list_picker_images` - unchanged
- ✅ **Service Layer**: All services still use model, not controller
- ✅ **Scripts**: All scripts use model, not controller

## Migration Instructions

### For New Code

Use the new `apple_amb_images` endpoints:

**Frontend**:
```javascript
// Option 1: Full-featured API client (for image validation, bulk operations)
import AppleAmbImagesAPI from 'dashboard/api/appleAmbImages';

// Upload image
await AppleAmbImagesAPI.uploadImage(inboxId, {
  identifier: 'img_0',
  imageData: base64Data,
  filename: 'image.png'
});

// Copy images
await AppleAmbImagesAPI.copyFromInbox(targetInboxId, sourceInboxId, ['img_0', 'img_1']);

// Option 2: Simplified API client (for AppleMessagesComposer)
import AppleAmbMessagesImagesAPI from 'dashboard/api/appleAmbMessagesImages';

// Get images
const response = await AppleAmbMessagesImagesAPI.get({ inboxId });

// Create image
await AppleAmbMessagesImagesAPI.create({
  inboxId,
  identifier: 'img_0',
  image_data: base64Data,
  description: 'My image',
  original_name: 'image.png'
});
```

**Backend**:
```ruby
# Routes automatically resolve to AppleAmbImagesController
POST /api/v1/accounts/1/inboxes/5/apple_amb_images
```

### For Existing Code

**No immediate action required.** Old endpoints will continue working.

**Recommended**: Migrate at your convenience during Phase 2 (timeline TBD).

### Checking Deprecation Logs

Old endpoint usage is logged:
```bash
# Check Rails logs for deprecation warnings
tail -f log/development.log | grep DEPRECATED
tail -f log/production.log | grep DEPRECATED
```

Log format:
```
[DEPRECATED] apple_list_picker_images endpoint used. Please migrate to apple_amb_images.
Endpoint: index, IP: 127.0.0.1, Account: 1, Inbox: 5
```

## Rollback Capability

### If Issues Arise with New Endpoints

1. **Frontend**: Uncomment old import in `ImageValidationModal.vue`:
   ```javascript
   // Revert to:
   import AppleListPickerImagesAPI from 'dashboard/api/appleListPickerImages';
   // And update usage back to AppleListPickerImagesAPI
   ```

2. **Routes**: Comment out new routes in `config/routes.rb` (lines 254-260)

3. **Restart Server**: `bundle exec rails restart` or restart via dev-server.sh

Old endpoints remain fully functional - no data loss or breaking changes.

## Testing Both Endpoints

### Test Old Endpoint (Should See Deprecation Warning)
```bash
# Check that it works and logs deprecation
rails runner "
  account = Account.first
  inbox = account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').first
  puts 'Testing old endpoint via model (works as before)'
  puts inbox.apple_list_picker_images.count
"

# Check logs
tail -f log/development.log | grep DEPRECATED
```

### Test New Endpoint
```bash
# Via Rails console
rails console
> account = Account.first
> inbox = account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').first
> puts "Image count: #{inbox.apple_list_picker_images.count}"
```

**Frontend Testing**:
1. Open Image Validation Modal
2. Check browser console for API calls
3. Should see requests to `/apple_amb_images` (new endpoint)
4. Should NOT see deprecation warnings

## Timeline

### Phase 1: Complete ✅ (Nov 14, 2025)
- New endpoints added
- Both old and new work simultaneously
- Deprecation warnings active
- No breaking changes

### Phase 2: Migration Period (TBD)
- Duration: 2-4 weeks
- Goal: Migrate all consumers to new endpoints
- Monitor old endpoint usage via logs
- Update internal code and notify external integrations

### Phase 3: Cleanup (TBD)
- Remove old controller
- Remove old routes
- Remove old frontend API client
- **BREAKING**: Old endpoints stop working

## Benefits of This Approach

✅ **Zero Downtime**: Both endpoints work during migration
✅ **No Breaking Changes**: All existing code continues working
✅ **Gradual Migration**: Teams can migrate at their own pace
✅ **Easy Rollback**: Can revert frontend immediately if issues arise
✅ **Transparent Monitoring**: Deprecation logs show usage patterns

## Questions?

**Why rename?**
The controller serves all AMB interactive messages (list pickers, time pickers, forms), not just list pickers. The new name reflects this broader scope.

**Why keep the old model name?**
The model name (`AppleListPickerImage`) is accurate - these are images used in interactive messages. The database table name matches. Only the controller/endpoint name changed for API clarity.

**When will old endpoints be removed?**
Timeline for Phase 3 is TBD. Minimum 2-4 weeks after all internal consumers migrate. External integrations will receive advance notice.

**What if I have external integrations?**
They will continue working indefinitely during Phase 1-2. We'll provide advance notice before Phase 3 (removal).

---

**Document Version**: 1.0
**Last Updated**: November 14, 2025
**Status**: Phase 1 Complete
