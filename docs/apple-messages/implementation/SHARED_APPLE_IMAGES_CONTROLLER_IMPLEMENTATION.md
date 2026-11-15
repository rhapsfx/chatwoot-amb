# Backend Feature Delivered - SharedAppleImagesController (2025-11-19)

## Stack Detected

**Language**: Ruby 3.3.9
**Framework**: Ruby on Rails 7.1.5.2
**Architecture**: MVC with Pundit authorization

## Files Added

- `/Users/rhaps/LocalGit/chatwoot/app/controllers/api/v1/accounts/shared_apple_images_controller.rb`
- `/Users/rhaps/LocalGit/chatwoot/app/policies/shared_apple_image_policy.rb`
- `/Users/rhaps/LocalGit/chatwoot/script/validate_shared_apple_images_controller.rb`

## Files Modified

- `/Users/rhaps/LocalGit/chatwoot/app/models/shared_apple_image.rb` - Added `image_url` and `image_data_base64` helper methods
- `/Users/rhaps/LocalGit/chatwoot/config/routes.rb` - Added resource routes for shared_apple_images

## Key Endpoints/APIs

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/v1/accounts/:account_id/shared_apple_images` | List all shared images (paginated) |
| GET | `/api/v1/accounts/:account_id/shared_apple_images/:id` | Get single image details (with base64 data) |
| POST | `/api/v1/accounts/:account_id/shared_apple_images` | Create new shared image |
| PATCH/PUT | `/api/v1/accounts/:account_id/shared_apple_images/:id` | Update image metadata |
| DELETE | `/api/v1/accounts/:account_id/shared_apple_images/:id` | Delete shared image |
| GET | `/api/v1/accounts/:account_id/shared_apple_images/system_images` | List system images only (paginated) |
| GET | `/api/v1/accounts/:account_id/shared_apple_images/branding_images` | List branding images only (paginated) |
| GET | `/api/v1/accounts/:account_id/shared_apple_images/template_images` | List template images only (paginated) |
| POST | `/api/v1/accounts/:account_id/shared_apple_images/:id/upload` | Upload/replace image file |
| DELETE | `/api/v1/accounts/:account_id/shared_apple_images/:id/remove_image` | Remove attached image (keep record) |

## Design Notes

### Pattern Chosen
- **RESTful Resource Controller** with custom collection and member actions
- Inherits from `Api::V1::Accounts::BaseController`
- Follows established Chatwoot API patterns (similar to `LabelsController`, `CannedResponsesController`)

### Authorization
- **Pundit-based authorization** via `SharedAppleImagePolicy`
- **Read access** (index, show, system_images, branding_images, template_images): Administrators and Agents
- **Write access** (create, update, destroy, upload, remove_image): Administrators only
- Authorization enforced via `before_action :check_authorization`

### Data Handling
- **Image uploads** support two formats:
  1. Direct file upload via `image_file` parameter
  2. Base64-encoded data via `image_data` parameter (with filename and content_type)
- **Response format**: JSON with proper HTTP status codes (200, 201, 204, 404, 422, 500)
- **Pagination**: Supports `page` and `per_page` params (default: 25 results per page)
- **Image data**: `show` action includes base64-encoded image data, `index` actions only return URLs for performance

### Strong Parameters
```ruby
params.require(:shared_apple_image).permit(
  :identifier,
  :image_type,
  :description,
  :original_name,
  metadata: {}
)
```

### Error Handling
- Proper error responses with descriptive messages
- Logging of errors via `Rails.logger.error`
- Graceful handling of missing records (404), validation failures (422), and server errors (500)

### Model Enhancements
Added helper methods to `SharedAppleImage` model:
- `image_url` - Returns Rails blob URL for image preview
- `image_data_base64` - Returns base64-encoded image data for API responses
- Both methods safely handle cases where image is not attached

## Tests

### Validation Script
Created `script/validate_shared_apple_images_controller.rb` to verify:
- Controller class loads successfully
- All 10 actions are present (index, show, create, update, destroy, upload, remove_image, system_images, branding_images, template_images)
- Policy class loads successfully
- All 10 policy methods are present (with ? suffix)
- Model has required helper methods and scopes

**Validation Result**: All checks passed ✓

### Route Registration
Verified via `bundle exec rails routes | grep shared_apple_images`:
- All standard CRUD routes registered
- All custom collection routes registered (system_images, branding_images, template_images)
- All custom member routes registered (upload, remove_image)
- Routes properly namespaced under `/api/v1/accounts/:account_id/shared_apple_images`

### Code Quality
- **RuboCop**: All files pass with 0 offenses
- **Ruby Style**: Compact class definitions, proper indentation
- **Rails Best Practices**: Strong params, proper error handling, scoped queries

## Performance

- **Pagination**: Default 25 results per page, configurable via `per_page` param
- **Efficient queries**: Uses ActiveRecord scopes for filtering (system_images, branding_images, template_images)
- **Lazy loading**: Base64 image data only included in `show` action, not `index` actions
- **Ordering**: Images ordered by `created_at DESC` for most recent first

## Security

- **Authorization**: Enforced via Pundit policy on all actions
- **Scope isolation**: All queries scoped to `Current.account.shared_apple_images`
- **Strong parameters**: Only allowed fields can be mass-assigned
- **Base64 validation**: Catches invalid base64 data with proper error handling
- **CSRF protection**: Inherited from `Api::BaseController`

## API Usage Examples

### Create Image with Base64 Data
```bash
POST /api/v1/accounts/1/shared_apple_images
Content-Type: application/json

{
  "shared_apple_image": {
    "identifier": "apple-logo",
    "image_type": "branding",
    "description": "Apple Messages logo",
    "original_name": "apple_logo.png"
  },
  "image_data": "iVBORw0KGgoAAAANSUhEUgAA...",
  "filename": "apple_logo.png",
  "content_type": "image/png"
}
```

### List System Images (Paginated)
```bash
GET /api/v1/accounts/1/shared_apple_images/system_images?page=1&per_page=10
```

### Upload/Replace Image
```bash
POST /api/v1/accounts/1/shared_apple_images/123/upload
Content-Type: multipart/form-data

image_file: [binary data]
```

### Get Image with Base64 Data
```bash
GET /api/v1/accounts/1/shared_apple_images/123
# Response includes "image_data_base64" field
```

## Integration with Phase 4

This controller implements the API layer for **Phase 4** of the **IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md**:
- Provides CRUD operations for shared Apple Messages images
- Supports filtering by image type (system, branding, template)
- Enables bulk operations via standard REST patterns
- Ready for frontend integration in `SharedAppleImagesManager.vue`

## Next Steps

1. **Frontend Integration**: Create `SharedAppleImagesManager.vue` component (Phase 4)
2. **Fallback Service**: Implement `SharedAppleImagesFallbackService` (Phase 4)
3. **Template Migration**: Migrate existing templates to use shared images (Phase 5)
4. **Inbox Migration**: Migrate inbox-specific images to shared images (Phase 6)

## Definition of Done

- ✓ All acceptance criteria satisfied
- ✓ Controller implements all required CRUD operations
- ✓ Custom collection actions implemented (system_images, branding_images, template_images)
- ✓ Custom member actions implemented (upload, remove_image)
- ✓ Authorization properly configured
- ✓ Strong parameters validated
- ✓ Routes registered correctly
- ✓ RuboCop passes with 0 offenses
- ✓ Validation script confirms all components present
- ✓ Follows Chatwoot coding standards
- ✓ Error handling implemented
- ✓ Logging configured
- ✓ Documentation complete

## Notes

- **Database access not tested**: Per CLAUDE.md guidelines, direct database access not available in sandbox
- **Manual testing recommended**: Use Postman/curl to test endpoints after server restart
- **Enterprise compatibility**: No Enterprise-specific overrides needed; standard resource controller pattern
