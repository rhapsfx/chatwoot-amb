# Apple List Picker Images Controller Rename Plan

**Date**: November 14, 2025  
**Status**: Planning Phase  
**Objective**: Rename `apple_list_picker_images_controller.rb` to `apple_amb_images_controller.rb` to better reflect its broader usage across Apple Messages for Business features

---

## Executive Summary

The `AppleListPickerImagesController` currently serves multiple Apple Messages for Business (AMB) interactive message types beyond just list pickers, including time pickers, forms, and other AMB features. This document provides a complete analysis and step-by-step plan for renaming it to `AppleAmbImagesController`.

---

## Current Analysis

### Controller Scope

**Current Name**: `AppleListPickerImagesController`  
**Current Path**: [`app/controllers/api/v1/accounts/inboxes/apple_list_picker_images_controller.rb`](app/controllers/api/v1/accounts/inboxes/apple_list_picker_images_controller.rb:1)  
**Full Class Name**: `Api::V1::Accounts::Inboxes::AppleListPickerImagesController`

### Actual Usage Scope

The controller manages images for **multiple AMB features**, not just list pickers:

1. **List Pickers** - Original purpose
2. **Time Pickers** - Uses [`AppleListPickerImage`](app/services/apple_messages_for_business/send_time_picker_service.rb:83-87) for event images
3. **Forms** - Uses [`AppleListPickerImage`](app/services/apple_messages_for_business/send_time_picker_service.rb:63-66) for form field images
4. **General AMB Messages** - Used by [`send_message_service.rb`](app/services/apple_messages_for_business/send_message_service.rb:194-197)
5. **Bot Service** - Used by [`acoustic_house_bot_service.rb`](app/services/apple_messages_for_business/acoustic_house_bot_service.rb:1328)

### Why Rename?

The current name `apple_list_picker_images` is **misleading** because:
- ❌ Suggests it's specific to list pickers only
- ❌ Doesn't reflect actual usage across multiple AMB features
- ✅ Should indicate it's a general AMB image storage mechanism

---

## Complete Dependency Map

### 1. Backend Files (Ruby)

#### Controller File
- **File**: [`app/controllers/api/v1/accounts/inboxes/apple_list_picker_images_controller.rb`](app/controllers/api/v1/accounts/inboxes/apple_list_picker_images_controller.rb:1)
- **Class**: `Api::V1::Accounts::Inboxes::AppleListPickerImagesController`
- **Actions**: `index`, `create`, `destroy`, `copy_from`, `bulk_upload`
- **Impact**: ⚠️ **HIGH** - File rename + class rename

#### Routes
- **File**: [`config/routes.rb:247-252`](config/routes.rb:247-252)
- **Current**:
  ```ruby
  resources :apple_list_picker_images, only: [:index, :create, :destroy], module: :inboxes do
    collection do
      post :copy_from
      post :bulk_upload
    end
  end
  ```
- **Impact**: ⚠️ **CRITICAL** - URL changes break API consumers

#### Model (No Changes Needed)
- **File**: [`app/models/apple_list_picker_image.rb`](app/models/apple_list_picker_image.rb)
- **Association**: [`app/models/inbox.rb:76`](app/models/inbox.rb:76) - `has_many :apple_list_picker_images`
- **Impact**: ✅ **NONE** - Model name remains unchanged

#### Services Using the Model (No Changes Needed)
- [`send_list_picker_service.rb`](app/services/apple_messages_for_business/send_list_picker_service.rb:40-43)
- [`send_time_picker_service.rb`](app/services/apple_messages_for_business/send_time_picker_service.rb:63-66)
- [`send_message_service.rb`](app/services/apple_messages_for_business/send_message_service.rb:194-197)
- [`acoustic_house_bot_service.rb`](app/services/apple_messages_for_business/acoustic_house_bot_service.rb:1328)
- [`bot_renderer_service.rb`](app/services/templates/bot_renderer_service.rb:146-150)
- **Impact**: ✅ **NONE** - Services use model, not controller

#### Other Controllers
- [`app/controllers/api/v1/accounts/templates_controller.rb:66`](app/controllers/api/v1/accounts/templates_controller.rb:66)
- **Impact**: ✅ **NONE** - Uses model directly

#### Scripts (No Changes Needed)
- 20+ scripts in [`script/`](script/) directory use `AppleListPickerImage` model
- **Impact**: ✅ **NONE** - Scripts use model, not controller

### 2. Frontend Files (JavaScript/Vue)

#### API Client
- **File**: [`app/javascript/dashboard/api/appleListPickerImages.js`](app/javascript/dashboard/api/appleListPickerImages.js:1-68)
- **Class**: `AppleListPickerImagesAPI`
- **Resource Name**: `'apple_list_picker_images'` (line 6)
- **Methods**: All construct URLs with `/apple_list_picker_images` path
- **Impact**: ⚠️ **HIGH** - File rename + class rename + URL updates

#### Vue Components
- **File**: [`app/javascript/dashboard/routes/dashboard/settings/templates/components/ImageValidationModal.vue:6`](app/javascript/dashboard/routes/dashboard/settings/templates/components/ImageValidationModal.vue:6)
- **Import**: `import AppleListPickerImagesAPI from 'dashboard/api/appleListPickerImages'`
- **Impact**: ⚠️ **MEDIUM** - Import path update

### 3. Database (No Changes)
- **Table**: `apple_list_picker_images`
- **Migration**: [`db/migrate/20251002131046_create_apple_list_picker_images.rb`](db/migrate/20251002131046_create_apple_list_picker_images.rb)
- **Impact**: ✅ **NONE** - Table name remains unchanged

### 4. Tests
- **Factory**: [`spec/factories/apple_list_picker_images.rb`](spec/factories/apple_list_picker_images.rb)
- **Controller Tests**: None found
- **Impact**: ✅ **NONE** - Factory uses model name

### 5. Documentation
- [`CLAUDE.md:263-266`](CLAUDE.md:263-266) - References controller path
- Multiple docs in [`docs/`](docs/) directory
- **Impact**: ⚠️ **LOW** - Documentation updates needed

---

## Breaking Changes Analysis

### ⚠️ CRITICAL: API Endpoint Changes

**Current URLs**:
```
GET    /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images
POST   /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images
DELETE /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images/:id
POST   /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images/copy_from
POST   /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images/bulk_upload
```

**New URLs** (after rename):
```
GET    /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images
POST   /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images
DELETE /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images/:id
POST   /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images/copy_from
POST   /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images/bulk_upload
```

**Impact**:
- ❌ All frontend API calls will fail
- ❌ Any external integrations calling these endpoints will break
- ❌ Requires coordinated deployment

---

## Recommended Rename Plan

### Phase 1: Preparation (Non-Breaking) ✅

**Goal**: Add new endpoints alongside old ones

**Steps**:

1. **Create New Controller** (alongside existing)
   ```bash
   # File: app/controllers/api/v1/accounts/inboxes/apple_amb_images_controller.rb
   ```
   - Copy existing controller
   - Rename class to `AppleAmbImagesController`
   - Keep all functionality identical

2. **Add New Routes** (aliasing)
   ```ruby
   # config/routes.rb
   resources :inboxes, only: [:index, :show, :create, :update, :destroy] do
     # OLD routes (keep for backward compatibility)
     resources :apple_list_picker_images, only: [:index, :create, :destroy], module: :inboxes do
       collection do
         post :copy_from
         post :bulk_upload
       end
     end
     
     # NEW routes (add alongside)
     resources :apple_amb_images, only: [:index, :create, :destroy], module: :inboxes do
       collection do
         post :copy_from
         post :bulk_upload
       end
     end
   end
   ```

3. **Create New Frontend API Client**
   ```bash
   # File: app/javascript/dashboard/api/appleAmbImages.js
   ```
   - Copy existing API client
   - Rename class to `AppleAmbImagesAPI`
   - Update resource name to `'apple_amb_images'`

4. **Update Vue Components**
   ```vue
   <!-- ImageValidationModal.vue -->
   <script>
   import AppleAmbImagesAPI from 'dashboard/api/appleAmbImages';
   // Use new API client
   </script>
   ```

5. **Add Deprecation Warnings**
   ```ruby
   # In old controller
   before_action :log_deprecation_warning
   
   def log_deprecation_warning
     Rails.logger.warn "[DEPRECATED] apple_list_picker_images endpoint used. Please migrate to apple_amb_images"
   end
   ```

6. **Update Documentation**
   - Update all docs to reference new endpoint
   - Add migration guide

**Estimated Time**: 4-6 hours  
**Risk**: ✅ **LOW** - No breaking changes

---

### Phase 2: Migration Period (Coordinated) ⚠️

**Goal**: Transition all consumers to new endpoints

**Steps**:

1. **Deploy Phase 1 Changes**
   - Both old and new endpoints active
   - Monitor usage of old endpoints

2. **Update Internal Consumers**
   - Frontend uses new API client
   - Any internal scripts updated

3. **Notify External Integrations**
   - Email notification about deprecation
   - Provide migration timeline (e.g., 2-4 weeks)

4. **Monitor Old Endpoint Usage**
   ```ruby
   # Add metrics tracking
   def log_deprecation_warning
     Rails.logger.warn "[DEPRECATED] apple_list_picker_images used by #{request.remote_ip}"
     # Track in metrics system
   end
   ```

**Duration**: 2-4 weeks  
**Risk**: ⚠️ **MEDIUM** - Requires coordination

---

### Phase 3: Cleanup (Breaking) ❌

**Goal**: Remove old endpoints

**Steps**:

1. **Remove Old Controller**
   ```bash
   rm app/controllers/api/v1/accounts/inboxes/apple_list_picker_images_controller.rb
   ```

2. **Remove Old Routes**
   ```ruby
   # config/routes.rb
   # Delete old apple_list_picker_images routes
   ```

3. **Remove Old Frontend API Client**
   ```bash
   rm app/javascript/dashboard/api/appleListPickerImages.js
   ```

4. **Remove Deprecation Warnings**
   - Clean up logging code

**Estimated Time**: 1-2 hours  
**Risk**: ❌ **HIGH** - Breaks any remaining old consumers

---

## Alternative: Keep Current Name ✅

### Recommendation: **DO NOT RENAME**

**Reasons**:

1. ✅ **No Breaking Changes** - All existing integrations continue working
2. ✅ **Historical Context** - Name reflects original purpose
3. ✅ **Semantic Meaning** - "List picker images" is more specific than "AMB images"
4. ✅ **Model Alignment** - Controller name matches model name (`AppleListPickerImage`)
5. ✅ **Low Risk** - No deployment coordination needed

### If Rename is Required

**Estimated Total Effort**: 3-5 days
- Backend changes: 4-6 hours
- Frontend changes: 2-3 hours
- Testing: 4-6 hours
- Documentation: 2-3 hours
- Deployment coordination: 1-2 days
- Migration monitoring: 1-2 weeks

**Risk Level**: ❌ **HIGH** - Breaks all API consumers

---

## Files Requiring Changes (If Rename Proceeds)

### Backend (4 files)
1. ✅ `app/controllers/api/v1/accounts/inboxes/apple_list_picker_images_controller.rb` → `apple_amb_images_controller.rb`
2. ✅ `config/routes.rb` - Update resource name
3. ✅ `CLAUDE.md` - Update documentation
4. ✅ `docs/` - Update all documentation references

### Frontend (2 files)
1. ✅ `app/javascript/dashboard/api/appleListPickerImages.js` → `appleAmbImages.js`
2. ✅ `app/javascript/dashboard/routes/dashboard/settings/templates/components/ImageValidationModal.vue` - Update import

### No Changes Needed
- ✅ Model: `AppleListPickerImage` (keep as-is)
- ✅ Database table: `apple_list_picker_images` (keep as-is)
- ✅ All service files (they use the model, not controller)
- ✅ All script files (they use the model, not controller)

---

## Decision Matrix

| Factor | Keep Current Name | Rename to AMB Images |
|--------|------------------|---------------------|
| **Breaking Changes** | ✅ None | ❌ All API endpoints |
| **Deployment Risk** | ✅ Zero | ❌ High |
| **Effort Required** | ✅ Zero | ❌ 3-5 days |
| **Semantic Clarity** | ⚠️ Specific but misleading | ✅ Accurate but generic |
| **Model Alignment** | ✅ Matches model name | ❌ Diverges from model |
| **Historical Context** | ✅ Preserved | ❌ Lost |

---

## Final Recommendation

### ✅ **KEEP CURRENT NAME: `apple_list_picker_images`**

**Rationale**:
1. The controller name matches the model name (`AppleListPickerImage`)
2. No breaking changes to API consumers
3. "List picker images" is semantically meaningful (images used in interactive messages)
4. The fact that it serves multiple AMB features is an implementation detail
5. Renaming provides minimal benefit vs. high risk and effort

### If Business Requirements Mandate Rename

Follow the **3-Phase Migration Plan** above:
1. **Phase 1**: Add new endpoints (non-breaking)
2. **Phase 2**: Migrate consumers (2-4 weeks)
3. **Phase 3**: Remove old endpoints (breaking)

**Total Timeline**: 4-6 weeks  
**Total Effort**: 3-5 days of development + coordination overhead

---

## Conclusion

The rename is **technically feasible** but carries **significant risk** due to API breaking changes. The current name, while originally specific to list pickers, has become the de facto standard for all AMB image management.

**Recommendation**: Keep the current name unless there's a compelling business reason that justifies the migration effort and risk.

---

**Document Version**: 1.0  
**Last Updated**: November 14, 2025  
**Author**: Technical Analysis Team