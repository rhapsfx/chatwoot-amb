# Apple Messages for Business (AMB) - Complete Development Guide

## 📚 Complete Integration Documentation

**🎯 For comprehensive system overview, architecture, and all dependencies, see**:
- **`AMB_INTEGRATION_STATUS_REPORT.md`** - Complete status report with:
  - 40+ backend services inventory
  - 25+ frontend components
  - Complete circular system architecture (15-step data flow)
  - Database schema (5 tables)
  - All API endpoints (15+)
  - Interactive message types (10+)
  - Case normalization system
  - Image architecture (two-tier hybrid)
  - Template system
  - All dependencies (Apple Pay, Apple Maps, OAuth2, etc.)
  - Security & compliance
  - Performance optimizations
  - Testing coverage
  - Deployment guide

- **`AMB_DEPENDENCY_MAP.md`** - Visual dependency guide with:
  - Component dependency graph
  - Message flow dependencies (outgoing & incoming)
  - Template system dependencies
  - Image system dependencies
  - Bot service dependencies
  - Validation chain
  - Cross-cutting concerns
  - Environment variable dependencies
  - Critical path analysis
  - Testing dependencies

**These documents serve as the definitive reference for the entire AMB integration.**

---

## 🚨 MANDATORY: CaseTransformer for All AMB Features

**Status**: ✅ **Case normalization complete** (Phases 1-3 deployed Oct 2025)

**Critical Rule**: ALL Apple Messages for Business code MUST use `CaseTransformer` for case conversions.

### System Architecture

**Data Flow**:
```
Frontend (camelCase)
  → API Controller (auto-normalizes to snake_case via before_action)
  → Database (snake_case storage)
  → Services (snake_case internally)
  → CaseTransformer (converts to camelCase for Apple MSP)
  → Apple MSP API (camelCase)
```

**Key Principles**:
1. **Internal storage**: Always snake_case (Rails convention)
2. **Frontend**: Naturally sends camelCase (JavaScript convention)
3. **API boundary**: Automatic normalization (camelCase → snake_case)
4. **Apple MSP boundary**: CaseTransformer (snake_case → camelCase)
5. **NEVER use dual-checks**: `field['snake_case'] || field['camelCase']` ❌

### Using CaseTransformer

**Module**: `AppleMessagesForBusiness::CaseTransformer`
**Location**: `app/services/apple_messages_for_business/case_transformer.rb`

**Basic Usage**:
```ruby
# Convert internal snake_case → Apple MSP camelCase
apple_format = AppleMessagesForBusiness::CaseTransformer.to_apple_format(internal_data)

# Convert Apple/frontend camelCase → internal snake_case
internal_format = AppleMessagesForBusiness::CaseTransformer.from_apple_format(apple_data)

# Normalize mixed-case data → snake_case
normalized = AppleMessagesForBusiness::CaseTransformer.normalize_content_attributes(mixed_data)
```

**Context-Aware Transformations**:
```ruby
# For received_message (strips received_ prefix)
AppleMessagesForBusiness::CaseTransformer.to_apple_format(
  { 'received_title' => 'Hello', 'received_image_identifier' => 'img1' },
  context: :received_message
)
# Returns: { 'title' => 'Hello', 'imageIdentifier' => 'img1' }

# For reply_message (strips reply_ prefix)
AppleMessagesForBusiness::CaseTransformer.to_apple_format(
  { 'reply_title' => 'Thanks', 'reply_image_identifier' => 'img2' },
  context: :reply_message
)
# Returns: { 'title' => 'Thanks', 'imageIdentifier' => 'img2' }
```

### Adding New AMB Features

**When adding new Apple Messages features, ALWAYS**:

1. **Store data in snake_case**:
   ```ruby
   content_attributes: {
     'image_identifier' => 'img_123',
     'timezone_offset' => 28800,
     'multiple_selection' => true
   }
   ```

2. **Use CaseTransformer in services**:
   ```ruby
   def build_my_feature_data
     data = {
       'my_field_name' => value,
       'another_field' => value2
     }

     # Transform to Apple format
     AppleMessagesForBusiness::CaseTransformer.to_apple_format(data)
   end
   ```

3. **Add new fields to CaseTransformer mappings** if needed:
   ```ruby
   # In case_transformer.rb
   TO_APPLE_MAPPINGS = {
     'my_new_field' => 'myNewField',
     # ... existing mappings
   }.freeze
   ```

4. **API controller auto-normalizes** (no code changes needed):
   - Frontend sends: `{ imageIdentifier: 'img1', timezoneOffset: 3600 }`
   - API receives and auto-converts to: `{ image_identifier: 'img1', timezone_offset: 3600 }`
   - Database stores snake_case

### Common Field Mappings

**Most frequently used**:
- `image_identifier` ↔ `imageIdentifier`
- `multiple_selection` ↔ `multipleSelection`
- `timezone_offset` ↔ `timezoneOffset`
- `start_time` ↔ `startTime`
- `received_image_identifier` ↔ `receivedImageIdentifier` (in received_message context → `imageIdentifier`)
- `reply_image_identifier` ↔ `replyImageIdentifier` (in reply_message context → `imageIdentifier`)

**See full mappings**: `app/services/apple_messages_for_business/case_transformer.rb`

### Migration Status

✅ **Phase 1** (Oct 2025): CaseTransformer module + API normalization
✅ **Phase 2** (Oct 2025): Database migration (265 records normalized to 100%)
✅ **Phase 3** (Oct 2025): Service layer cleanup (all dual-checks removed)

**Current Services Using CaseTransformer**:
- ✅ SendListPickerService
- ✅ SendTimePickerService
- ✅ FormService
- ✅ SendRichLinkService (already clean)
- ✅ API Controller (messages_controller.rb)

### Testing CaseTransformer

**Manual test script**: `test_case_transformer.rb` (project root)

```bash
# Run all transformation tests
ruby test_case_transformer.rb
```

**RSpec tests**: `spec/services/apple_messages_for_business/case_transformer_spec.rb`

### Documentation

**🎯 START HERE - Comprehensive Status Reports**:
- `AMB_INTEGRATION_STATUS_REPORT.md` - **Complete status report** with circular architecture view, all components, dependencies, and implementation details
- `AMB_DEPENDENCY_MAP.md` - **Visual dependency guide** showing all component relationships and data flows

**Technical Specs**:
- `case-normalization-specification.md` - Complete technical specification
- `PHASE_1_COMPLETE.md` - Phase 1 implementation details
- `MIGRATION_IMPLEMENTATION_COMPLETE.md` - Phase 2 migration guide
- `MIGRATION_GUIDE.md` - Step-by-step migration procedures

**Scripts**:
- `scripts/dry_run_normalization.rb` - Analyze normalization status
- `scripts/verify_normalization.rb` - Verify database normalization
- `scripts/rollback_normalization.rb` - Emergency rollback (if needed)

---

## Template Data Access & Image Loading Architecture

**Status**: ✅ **Active** (Deployed Jan 2025)

### TemplateFacade - Unified Template Interface

**Purpose**: Single entry point for all template data access, automatically routing to optimal storage strategy.

**Location**: `app/services/apple_messages_for_business/template_facade.rb`

**Key Concept**: Templates can store data in two ways:
- **Metadata storage**: For simple templates (≤2 blocks) - stored in `message_templates.metadata`
- **Content blocks storage**: For complex templates (>2 blocks) - stored in separate `content_blocks` table

**Critical Methods**:

```ruby
# Initialize facade for a template
facade = AppleMessagesForBusiness::TemplateFacade.new(template)

# Load template data (snake_case, NO images)
data = facade.load_data(block_type)

# Load template data WITH images (for bot sends) ✅ RECOMMENDED FOR BOTS
data_with_images = facade.load_data_with_images(block_type)

# Save template data
facade.save_data(block_type, properties)

# Get all blocks
all_blocks = facade.all_blocks

# Get image identifiers
identifiers = facade.image_identifiers
```

**When to Use Each Method**:

- **`load_data`**: Template editing, UI display (images loaded separately)
- **`load_data_with_images`**: Bot sends, automated messages (images embedded in response)

**Example - Bot Service Using Facade**:

```ruby
class AcousticHouseBotService
  def send_list_picker_to_customer
    # Load template with images automatically included
    facade = AppleMessagesForBusiness::TemplateFacade.new(template)
    data = facade.load_data_with_images('list_picker')

    # Data now contains 'images' array with base64-encoded images
    # Ready to send to Apple MSP
    send_to_apple_msp(data)
  end
end
```

**Storage Strategy Selection** (automatic):
1. Check explicit preference: `template.metadata['storage_strategy']`
2. Check existing data: Use format where data exists
3. Default: Metadata for new templates

### ImageFetchService - Three-Tier Image Resolution

**Purpose**: Fetch images with automatic fallback across three storage tiers.

**Location**: `app/services/apple_messages_for_business/image_fetch_service.rb`

**Three-Tier Fallback Priority**:
1. **Tier 1**: Inbox-specific images (AppleListPickerImage) - Highest priority
2. **Tier 2**: Account-wide shared images (SharedAppleImage) - Fallback
3. **Tier 3**: Embedded template images (content_attributes['images']) - Final fallback

**Usage Pattern**:

```ruby
# Initialize service
service = AppleMessagesForBusiness::ImageFetchService.new(
  account_id: account.id,
  inbox_id: inbox.id,           # Can be nil for bot sends
  embedded_images: template_images  # Optional: images from template
)

# Fetch and encode images
identifiers = ['messages_png', 'menu_icon', 'custom_logo']
images = service.fetch_and_encode(identifiers)

# Returns array of hashes:
# [
#   { identifier: 'messages_png', data: 'base64...', description: '...', source: 'shared_system' },
#   { identifier: 'menu_icon', data: 'base64...', description: '...', source: 'inbox' },
#   { identifier: 'custom_logo', data: 'base64...', description: '...', source: 'embedded' }
# ]
```

**Bot Service Pattern** (No Specific Inbox):

```ruby
# Bot sends to any inbox - use nil for inbox_id
service = AppleMessagesForBusiness::ImageFetchService.new(
  account_id: template.account_id,
  inbox_id: nil,                    # Bot doesn't target specific inbox
  embedded_images: []
)

# Service automatically falls back to shared images
images = service.fetch_and_encode(['messages_png', 'menu_icon'])
# Will find images in SharedAppleImage (account-wide)
```

**Integration Points**:

✅ Used by TemplateFacade's `load_data_with_images` method
✅ Used by SendListPickerService
✅ Used by SendTimePickerService
✅ Used by FormService
✅ Used by AcousticHouseBotService

**Logging**:

ImageFetchService provides comprehensive logging:
- `[ImageFetch] Looking for N images` - Start of fetch
- `[ImageFetch] ✅ Found in inbox/shared/embedded` - Success per tier
- `[ImageFetch] ⚠️ Image not found: identifier` - Missing image warning
- `[ImageFetch] Found N/M images` - Final summary

**Best Practices**:

1. **For User Sends** (known inbox):
   ```ruby
   ImageFetchService.new(
     account_id: message.account_id,
     inbox_id: message.inbox_id,
     embedded_images: content_attributes['images']
   )
   ```

2. **For Bot Sends** (any inbox):
   ```ruby
   ImageFetchService.new(
     account_id: template.account_id,
     inbox_id: nil,  # No specific inbox
     embedded_images: []
   )
   ```

3. **Always provide embedded_images** from template/message if available:
   ```ruby
   embedded_images: content_attributes['images'] || []
   ```

**Error Handling**:

- Missing images are logged but don't raise errors
- Returns empty array if no images found
- Continues processing remaining images if one fails

### Architecture Integration

**Complete Data Flow for Bot Sends**:

```
1. Bot Trigger
   ↓
2. TemplateFacade.new(template)
   ↓
3. facade.load_data_with_images('list_picker')
   ↓
4. ImageFetchService.new(account_id, nil, [])
   ↓
5. Three-tier fallback: inbox(nil) → shared(✅) → embedded
   ↓
6. Images base64-encoded and added to data
   ↓
7. CaseTransformer.to_apple_format(data)
   ↓
8. Send to Apple MSP
```

**Key Architectural Benefits**:

- ✅ **Single entry point**: TemplateFacade for all template access
- ✅ **Automatic storage**: Facades routes to optimal storage
- ✅ **Automatic images**: Bot services get images without explicit code
- ✅ **Flexible fallback**: Works with or without specific inbox
- ✅ **Clean separation**: Template storage vs image storage vs case conversion

**Documentation**:

- Complete architecture: `IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md`
- Migration guide: `IMAGE_MIGRATION_GUIDE.md`
- TemplateFacade code: `app/services/apple_messages_for_business/template_facade.rb` (lines 1-148)
- ImageFetchService code: Referenced in IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md (lines 386-497)

---

## List Picker with Images

**Current Implementation**: Uses CaseTransformer for all case conversions.

**Service Architecture**:
- Parent: `AppleMessagesForBusiness::SendMessageService` (base class)
- Child: `AppleMessagesForBusiness::SendListPickerService` (overrides `build_list_picker_data`)

**Implementation Pattern**:
```ruby
def build_list_picker_data
  sections = content_attributes['sections'] || []

  transformed_sections = sections.map do |section|
    # Use CaseTransformer to convert snake_case → camelCase
    AppleMessagesForBusiness::CaseTransformer.to_apple_format(section)
  end

  { sections: transformed_sections }
end
```

**Image Storage Flow**:
- Images are base64-encoded on frontend
- Sent to backend in `content_attributes['images']`
- Stored in ActiveStorage via `AppleListPickerImage` model
- Retrieved and re-encoded when sending to Apple MSP
- Items reference images via `image_identifier` (snake_case internally)

**Related Files**:
- Service: `app/services/apple_messages_for_business/send_list_picker_service.rb`
- Model: `app/models/apple_list_picker_image.rb`
- Controllers:
  - **NEW (recommended)**: `app/controllers/api/v1/accounts/inboxes/apple_amb_images_controller.rb`
  - OLD (deprecated): `app/controllers/api/v1/accounts/inboxes/apple_list_picker_images_controller.rb`
- **Note**: Both endpoints work during Phase 1 migration. Prefer `apple_amb_images` for new integrations.

## Time Picker with Images

**Current Implementation**: Uses CaseTransformer for all case conversions.

**Automatic Image Fallback**:
```ruby
# In SendTimePickerService#build_reply_message
reply_image_id = content_attributes['reply_image_identifier']

# If reply image is not specified, reuse the received image identifier
if reply_image_id.blank?
  reply_image_id = content_attributes['received_image_identifier']
end
```

**Why This Matters**:
- Apple MSP best practice: reply message should display the same image as received message
- Frontend may not always explicitly set `reply_image_identifier`
- Automatic fallback ensures visual consistency in the time picker flow

**Related Files**:
- Service: `app/services/apple_messages_for_business/send_time_picker_service.rb`
- Frontend Modal: `app/javascript/dashboard/components-next/message/modals/EnhancedTimePickerModal.vue`
- Frontend Composer: `app/javascript/dashboard/components/widgets/conversation/ReplyBox/AppleMessagesComposer.vue`

## Apple Messages Forms with Images

**Current Implementation**: Uses CaseTransformer for all case conversions.

**Automatic Image Fallback**:
```ruby
# In FormService#build_reply_message
reply_image_id = reply_msg['image_identifier']

# If reply image is not specified, reuse the received image identifier
if reply_image_id.blank?
  received_msg = @form_config['received_message'] || {}
  reply_image_id = received_msg['image_identifier']
end
```

**Frontend Integration**:
- AppleFormBuilder.vue has a "Messages" tab for configuring receivedMessage and replyMessage
- Image selector with preview similar to Time Picker
- Auto-sync: reply image automatically uses received image if not explicitly set

**Related Files**:
- Service: `app/services/apple_messages_for_business/form_service.rb`
- Frontend Modal: `app/javascript/dashboard/components-next/message/modals/AppleFormBuilder.vue`
- Frontend Composer: `app/javascript/dashboard/components/widgets/conversation/ReplyBox/AppleMessagesComposer.vue`

---

## Apple Messages Image Architecture - Two-Tier System

**Status**: ✅ **Phase 5 Complete** (Deployed Jan 2025)

### System Overview

The Apple Messages image system uses a **two-tier hybrid architecture** to solve the inbox-scoping issue where shared images must be manually replicated across inboxes.

**Architecture**:
```
TIER 1: Inbox-Specific Images (AppleListPickerImage)
  ├── Local images uploaded for specific inbox
  └── Can override shared images

TIER 2: Account-Wide Shared Images (SharedAppleImage)
  ├── system: System icons (messages_png, calendar icons)
  ├── branding: Company branding (logos, store icons)
  └── template: Reusable template images
```

### Three-Tier Fallback

When fetching images, the system follows this priority:

1. **Inbox-specific** (AppleListPickerImage) - Highest priority
2. **Account-wide shared** (SharedAppleImage) - Fallback
3. **Embedded template** (content_attributes['images']) - Final fallback

**Implementation**: `AppleMessagesForBusiness::ImageFetchService`

### Models

**SharedAppleImage** (Account-scoped):
- `account_id` - Belongs to Account
- `identifier` - Unique identifier (snake_case)
- `image_type` - 'system', 'branding', or 'template'
- `description` - Human-readable description
- `original_name` - Original filename
- `metadata` - JSONB for additional data
- `image` - ActiveStorage attachment

**AppleListPickerImage** (Inbox-scoped):
- Existing model, now with `shared_override` boolean
- `shared_override: true` - Indicates inbox-specific override of shared image
- `shared_override: false/nil` - Truly inbox-specific image

### API Endpoints

**Base URL**: `/api/v1/accounts/:account_id/shared_apple_images`

**Endpoints**:
- `GET /` - List all shared images (paginated)
- `GET /system_images` - Filter by system type
- `GET /branding_images` - Filter by branding type
- `GET /template_images` - Filter by template type
- `POST /` - Create new shared image
- `GET /:id` - Show specific image
- `PATCH /:id` - Update image
- `DELETE /:id` - Delete image
- `POST /:id/upload` - Upload image file
- `DELETE /:id/remove_image` - Remove image attachment

### Frontend Integration

**Components**:
- `SharedImageSelector.vue` - Reusable image selector component
- `useSharedAppleImages.js` - Composable for API integration

**Integrated Into**:
- ✅ List Picker Editor (ListPickerBlockEditor.vue)
- ✅ Time Picker Modal (EnhancedTimePickerModal.vue)
- ✅ Forms Editor (AppleFormBuilder.vue)

**Usage Pattern**:
```vue
<SharedImageSelector
  v-model="imageIdentifier"
  :account-id="currentAccountId"
  image-type="system"
  @image-selected="handleImageSelected"
/>
```

### Migration Scripts

**Available Scripts** (in `script/` directory):
- `audit_image_usage.rb` - Analyze current image usage
- `migrate_system_images_to_shared.rb` - Migrate system images (messages_png, etc.)
- `migrate_branding_images_to_shared.rb` - Migrate branding images
- `verify_image_migration.rb` - Verify migration success

**Usage**:
```bash
# Dry run (default)
rails runner script/migrate_system_images_to_shared.rb

# Execute migration
rails runner script/migrate_system_images_to_shared.rb --execute

# Verify
rails runner script/verify_image_migration.rb
```

### Best Practices

**When to Use Shared Images**:
- ✅ System icons (messages app icon, calendar icons)
- ✅ Company branding (logos, store identifiers)
- ✅ Reusable template images (form headers, menu icons)

**When to Use Inbox-Specific Images**:
- ✅ Custom inbox branding
- ✅ Temporary campaign images
- ✅ Inbox-specific overrides of shared images

**Storage Recommendations**:
1. Upload system images once per account → `image_type: 'system'`
2. Upload company branding once per account → `image_type: 'branding'`
3. Use inbox-specific only for true customization

### Case Convention

**Critical**: All image identifiers are stored in **snake_case** internally.

**Data Flow**:
```
Frontend (camelCase)
  → API Controller (auto-normalizes to snake_case)
  → Database (snake_case storage)
  → ImageFetchService (queries snake_case)
  → CaseTransformer (converts to camelCase for Apple MSP)
  → Apple MSP API (camelCase)
```

### Documentation

**🎯 Complete System Documentation**:
- `AMB_INTEGRATION_STATUS_REPORT.md` - **Complete status report** including image architecture, all components, and circular data flows
- `AMB_DEPENDENCY_MAP.md` - **Visual dependency guide** with image system integration points

**Complete Documentation**:
- `IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md` - Complete architecture plan
- `IMAGE_MIGRATION_GUIDE.md` - Migration guide for existing installations
- `SHARED_IMAGES_USAGE.md` - User guide for shared images
- `../api/shared_apple_images_api.md` - API documentation

### Deployment

The image architecture is deployed via standard deployment scripts:
- `./script/deploy-backend-changes-safe.sh` - Deploys models, services, controllers
- Frontend assets deployed via Vite build

**Database Migrations**:
- `20251119122654_create_shared_apple_images.rb` - Creates SharedAppleImage table
- `20251119122704_add_shared_override_to_apple_list_picker_images.rb` - Adds shared_override column