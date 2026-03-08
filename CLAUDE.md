# Chatwoot Development Guidelines

## Build / Test / Lint

- **Setup**: `bundle install && pnpm install`
- **Run Dev**: `./script/dev-server.sh start` (localhost only) or `./script/dev-server.sh start-public` (with public access)
- **Server Management**: `./script/dev-server.sh {start|start-public|stop|restart|status|help}`
- **Public Access Options**: Custom domain, Tailscale Funnel, or ngrok (configured in dev-server.sh)
- **Lint JS/Vue**: `pnpm eslint` / `pnpm eslint:fix`
- **Lint Ruby**: `bundle exec rubocop -a`
- **Test JS**: `pnpm test` or `pnpm test:watch`
- **Test Ruby**: `bundle exec rspec spec/path/to/file_spec.rb`
- **Single Test**: `bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER`
- **Legacy Run**: `overmind start -f Procfile.dev` (use dev-server.sh instead)

## Code Style

- **Ruby**: Follow RuboCop rules (150 character max line length)
- **Vue/JS**: Use ESLint (Airbnb base + Vue 3 recommended)
- **Vue Components**: Use PascalCase
- **Events**: Use camelCase
- **I18n**: No bare strings in templates; use i18n
- **Error Handling**: Use custom exceptions (`lib/custom_exceptions/`)
- **Models**: Validate presence/uniqueness, add proper indexes
- **Type Safety**: Use PropTypes in Vue, strong params in Rails
- **Naming**: Use clear, descriptive names with consistent casing
- **Vue API**: Always use Composition API with `<script setup>` at the top

## Styling

- **Tailwind Only**:  
  - Do not write custom CSS  
  - Do not use scoped CSS  
  - Do not use inline styles  
  - Always use Tailwind utility classes  
- **Colors**: Refer to `tailwind.config.js` for color definitions

## General Guidelines

- MVP focus: Least code change, happy-path only
- No unnecessary defensive programming
- Break down complex tasks into small, testable units
- Iterate after confirmation
- Avoid writing specs unless explicitly asked
- Remove dead/unreachable/unused code
- Don’t write multiple versions or backups for the same logic — pick the best approach and implement it
- Don't reference Claude in commit messages

## Project-Specific

- **Translations**:
  - Only update `en.yml` and `en.json`
  - Other languages are handled by the community
  - Backend i18n → `en.yml`, Frontend i18n → `en.json`
- **Frontend**:
  - Use `components-next/` for message bubbles (the rest is being deprecated)

## Ruby Best Practices

- Use compact `module/class` definitions; avoid nested styles

## Enterprise Edition Notes

- Chatwoot has an Enterprise overlay under `enterprise/` that extends/overrides OSS code.
- When you add or modify core functionality, always check for corresponding files in `enterprise/` and keep behavior compatible.
- Follow the Enterprise development practices documented here:
  - https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38

Practical checklist for any change impacting core logic or public APIs
- Search for related files in both trees before editing (e.g., `rg -n "FooService|ControllerName|ModelName" app enterprise`).
- If adding new endpoints, services, or models, consider whether Enterprise needs:
  - An override (e.g., `enterprise/app/...`), or
  - An extension point (e.g., `prepend_mod_with`, hooks, configuration) to avoid hard forks.
- Avoid hardcoding instance- or plan-specific behavior in OSS; prefer configuration, feature flags, or extension points consumed by Enterprise.
- Keep request/response contracts stable across OSS and Enterprise; update both sets of routes/controllers when introducing new APIs.
- When renaming/moving shared code, mirror the change in `enterprise/` to prevent drift.
- Tests: Add Enterprise-specific specs under `spec/enterprise`, mirroring OSS spec layout where applicable.
- Remember that any tailscale command as privilege Claude cannot use, please ask me diretly to execute them
- keep in memory the Vue configuration requirement

## Apple Messages for Business (AMB) - Critical Implementation Notes

### 📚 Complete Integration Documentation

**🎯 For comprehensive system overview, architecture, and all dependencies, see**:
- **`docs/apple-messages/AMB_INTEGRATION_STATUS_REPORT.md`** - Complete status report with:
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

- **`docs/apple-messages/AMB_DEPENDENCY_MAP.md`** - Visual dependency guide with:
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

### 🚨 MANDATORY: CaseTransformer for All AMB Features

**Status**: ✅ **Case normalization complete** (Phases 1-3 deployed Oct 2025)

**Critical Rule**: ALL Apple Messages for Business code MUST use `CaseTransformer` for case conversions.

#### System Architecture

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

#### Using CaseTransformer

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

#### Adding New AMB Features

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

#### Common Field Mappings

**Most frequently used**:
- `image_identifier` ↔ `imageIdentifier`
- `multiple_selection` ↔ `multipleSelection`
- `timezone_offset` ↔ `timezoneOffset`
- `start_time` ↔ `startTime`
- `received_image_identifier` ↔ `receivedImageIdentifier` (in received_message context → `imageIdentifier`)
- `reply_image_identifier` ↔ `replyImageIdentifier` (in reply_message context → `imageIdentifier`)

**See full mappings**: `app/services/apple_messages_for_business/case_transformer.rb`

#### Migration Status

✅ **Phase 1** (Oct 2025): CaseTransformer module + API normalization
✅ **Phase 2** (Oct 2025): Database migration (265 records normalized to 100%)
✅ **Phase 3** (Oct 2025): Service layer cleanup (all dual-checks removed)

**Current Services Using CaseTransformer**:
- ✅ SendListPickerService
- ✅ SendTimePickerService
- ✅ FormService
- ✅ SendRichLinkService (already clean)
- ✅ API Controller (messages_controller.rb)

#### Testing CaseTransformer

**Manual test script**: `test_case_transformer.rb` (project root)

```bash
# Run all transformation tests
ruby test_case_transformer.rb
```

**RSpec tests**: `spec/services/apple_messages_for_business/case_transformer_spec.rb`

#### Documentation

**🎯 START HERE - Comprehensive Status Reports**:
- `docs/apple-messages/AMB_INTEGRATION_STATUS_REPORT.md` - **Complete status report** with circular architecture view, all components, dependencies, and implementation details
- `docs/apple-messages/AMB_DEPENDENCY_MAP.md` - **Visual dependency guide** showing all component relationships and data flows

**Technical Specs**:
- `docs/apple-messages/case-normalization-specification.md` - Complete technical specification
- `docs/apple-messages/PHASE_1_COMPLETE.md` - Phase 1 implementation details
- `docs/apple-messages/MIGRATION_IMPLEMENTATION_COMPLETE.md` - Phase 2 migration guide
- `docs/apple-messages/MIGRATION_GUIDE.md` - Step-by-step migration procedures

**Scripts**:
- `docs/apple-messages/scripts/dry_run_normalization.rb` - Analyze normalization status
- `docs/apple-messages/scripts/verify_normalization.rb` - Verify database normalization
- `docs/apple-messages/scripts/rollback_normalization.rb` - Emergency rollback (if needed)

---

### Template Data Access & Image Loading Architecture

**Status**: ✅ **Active** (Deployed Jan 2025)

#### TemplateFacade - Unified Template Interface

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

#### ImageFetchService - Three-Tier Image Resolution

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

#### Architecture Integration

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

- Complete architecture: `docs/apple-messages/IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md`
- Migration guide: `docs/apple-messages/IMAGE_MIGRATION_GUIDE.md`
- TemplateFacade code: `app/services/apple_messages_for_business/template_facade.rb` (lines 1-148)
- ImageFetchService code: Referenced in IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md (lines 386-497)

---

### List Picker with Images

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

### Time Picker with Images

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

### Apple Messages Forms with Images

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

### Image Architecture

See **Apple Messages Image Architecture - Two-Tier System** section below for complete documentation on the hybrid image storage system.

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
- `docs/apple-messages/AMB_INTEGRATION_STATUS_REPORT.md` - **Complete status report** including image architecture, all components, and circular data flows
- `docs/apple-messages/AMB_DEPENDENCY_MAP.md` - **Visual dependency guide** with image system integration points

**Complete Documentation**:
- `docs/apple-messages/IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md` - Complete architecture plan
- `docs/apple-messages/IMAGE_MIGRATION_GUIDE.md` - Migration guide for existing installations
- `docs/apple-messages/SHARED_IMAGES_USAGE.md` - User guide for shared images
- `docs/api/shared_apple_images_api.md` - API documentation

### Deployment

The image architecture is deployed via standard deployment scripts:
- `./script/deploy-production-docker.sh` - Deploys models, services, controllers
- Frontend assets deployed via Vite build

**Database Migrations**:
- `20251119122654_create_shared_apple_images.rb` - Creates SharedAppleImage table
- `20251119122704_add_shared_override_to_apple_list_picker_images.rb` - Adds shared_override column

## Database Access - CRITICAL

**🚨 ABSOLUTE RULE: NEVER attempt direct PostgreSQL access via `psql` or connection strings**

Claude Code runs in a macOS sandbox that **ALWAYS BLOCKS** direct database connections. This will ALWAYS fail.

**✅ ONLY use these methods for ALL database operations**:

1. **`rails runner`** - For quick queries and scripts:
   ```bash
   rails runner "puts User.count"
   rails runner "puts Message.last.inspect"
   rails runner "Channel::AppleMessagesForBusiness.all.each { |c| puts c.inspect }"
   rails runner "script/some_script.rb"
   ```

2. **`rails console`** - For interactive exploration:
   ```bash
   rails console
   # Then run queries interactively
   ```

3. **Ruby scripts executed via `rails runner`** - For complex operations:
   ```ruby
   # Create script/my_query.rb, then:
   rails runner script/my_query.rb
   ```

**❌ NEVER do**:
- `/opt/homebrew/opt/postgresql@15/bin/psql` (WILL FAIL - sandbox blocks it)
- Direct database connections
- `ActiveRecord::Base.connection.execute` outside of rails runner context
- Any attempt to bypass Rails to access PostgreSQL

**📊 For database queries**:
- Simple count/check → `rails runner "puts Model.count"`
- Complex query → Create a script file, run via `rails runner`
- Interactive exploration → `rails console`
- Check logs → `tail -f log/development.log`

**Remember**: The sandbox restriction is PERMANENT and CANNOT be bypassed. Always work through Rails.

## Rails Command Execution Policy - CRITICAL

**🚨 ABSOLUTE RULE: NEVER run Rails commands directly without explicit user approval**

Rails commands can modify database state, trigger side effects, or perform operations that the user should review first.

**✅ ALWAYS follow this workflow**:

1. **For simple Rails commands** - Provide the command to the user:
   ```bash
   # Example: Tell the user to run
   rails runner "puts Message.where(message_type: :incoming).count"
   ```

2. **For complex Rails operations** - Create a script file and provide instructions:
   ```ruby
   # Create script/analyze_custom_payload.rb with the logic
   # Then tell the user: "Please run: rails runner script/analyze_custom_payload.rb"
   ```

3. **For multi-step operations** - Create a documented script:
   ```ruby
   # script/migrate_data.rb
   # Purpose: Migrate old format to new format
   # Usage: rails runner script/migrate_data.rb [--dry-run]

   # [Script implementation here]
   ```

**Exceptions (require user context/approval)**:
- ✅ Read-only queries that were explicitly requested
- ✅ Running tests (`bundle exec rspec`)
- ✅ Linting/formatting commands
- ✅ Log file inspection

**❌ NEVER run without approval**:
- Database modifications (`rails runner "Model.update_all(...)"`)
- Data migrations or transformations
- Service calls that trigger external APIs
- Any operation with side effects

**Why This Rule**:
- User maintains control over database changes
- Scripts can be reviewed before execution
- Operations can be run with appropriate timing
- User can verify preconditions are met
- Enables dry-run testing

**Best Practice**:
```
❌ BAD: Directly run rails runner "complex operation"
✅ GOOD: Create script/operation.rb and say "Please run: rails runner script/operation.rb"
```

## Remote Server Deployment

**Production Server**: msp.rhaps.net (Docker-based deployment)
**Development Server**: mac-studio.tail367da4.ts.net (Tailscale Funnel via `script/dev-server.sh`)

### 📖 Complete Deployment Documentation

**🎯 For comprehensive deployment workflows, troubleshooting, and best practices, see**:
- **[`docs/DEPLOYMENT_GUIDE.md`](docs/DEPLOYMENT_GUIDE.md)** - Complete deployment guide with:
  - When to use each deployment script (decision flowchart)
  - 5 real-world scenario examples
  - Common issues and solutions
  - Verification steps
  - Best practices
- **[`docs/DOCKER_BUILD_TROUBLESHOOTING.md`](docs/DOCKER_BUILD_TROUBLESHOOTING.md)** - Docker build troubleshooting
- **[`script/README.md`](script/README.md)** - Scripts directory documentation

### Deployment Scripts Overview

We have two primary deployment scripts for different scenarios:

#### 1. `script/deploy-production-docker.sh` - Full Docker Image Rebuild

**Use when:**
- ✅ Modified `Dockerfile.production` or Docker infrastructure
- ✅ Updated dependencies (`Gemfile`, `Gemfile.lock`)
- ✅ Changed frontend code (JavaScript/TypeScript/CSS)
- ✅ Modified Node.js or Ruby versions
- ✅ Initial deployment or major refactoring

**Usage:**
```bash
# Standard rebuild (uses cache)
./script/deploy-production-docker.sh

# Clean rebuild (no cache, for infrastructure changes)
./script/deploy-production-docker.sh --no-cache
```

**Time**: 5-15 minutes | **Requirements**: 4GB+ heap, 3.7GB RAM + 4GB swap

#### 2. `script/deploy-production-docker.sh` - Hot-Patch Backend Deployment

**Use when:**
- ✅ Modified Ruby code only (services, controllers, models, jobs)
- ✅ Updated routes or initializers
- ✅ Added/modified API endpoints
- ✅ Need to run database migrations
- ✅ Quick iteration on backend features

**Usage:**
```bash
./script/deploy-production-docker.sh
```

**Time**: 1-3 minutes | **Requirements**: Containers must be running

### Quick Reference - Common Scenarios

**Fix backend bug (Ruby code only):**
```bash
./script/deploy-production-docker.sh
```

**Add new gem dependency:**
```bash
./script/deploy-production-docker.sh
```

**Update frontend UI:**
```bash
./script/deploy-production-docker.sh
```

**Update Dockerfile configuration:**
```bash
./script/deploy-production-docker.sh --no-cache
```

**Deploy with database migration:**
```bash
./script/deploy-production-docker.sh  # Runs migrations automatically
```

### Deployment Workflow

1. **Make changes locally**
2. **Test thoroughly**:
   ```bash
   bundle exec rspec                    # Run tests
   bundle exec rubocop -a               # Check/fix Ruby style
   pnpm eslint:fix                      # Check/fix JS style
   ./script/dev-server.sh start         # Test locally
   ```
3. **Commit changes**:
   ```bash
   git add .
   git commit -m "Fix: Description of change"
   git push
   ```
4. **Choose appropriate deployment script** (see decision tree in [`docs/DEPLOYMENT_GUIDE.md`](docs/DEPLOYMENT_GUIDE.md))
5. **Verify deployment**:
   ```bash
   # Check container status
   ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps'
   
   # Check application health
   curl https://msp.rhaps.net/health
   
   # View logs
   ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs --tail=50 web'
   ```

### Important Notes

- **NEVER run deployment scripts through Claude** - SSH and rsync are blocked by sandbox
- **ALWAYS ask user to run deployment scripts manually** in their terminal
- **Always commit before deploying** - Version control is critical for rollbacks
- **Choose the right script** - Using `deploy-production-docker.sh` for simple code changes wastes 10+ minutes
- **Monitor during deployment** - Watch logs in separate terminal to catch issues early
- **Verify after deployment** - Check container health, application endpoints, and feature functionality
- **Environment-specific configs**:
  - Production uses `docker-compose.production.yml`
  - Local dev uses `script/dev-server.sh` with Tailscale Funnel
  - Sidekiq workers require `HOSTNAME` env var for proper identification

### Container Management

**Check running containers:**
```bash
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps'
```

**Restart specific service:**
```bash
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml restart worker'
```

**View service logs:**
```bash
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs -f web'
```

**Update and recreate service:**
```bash
# After updating docker-compose.production.yml
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml up -d --force-recreate worker'
```

### Local Development Server

**Script**: `script/dev-server.sh`
**Domain**: mac-studio.tail367da4.ts.net (Tailscale Funnel)
**Management**: `./script/dev-server.sh {start|start-public|stop|restart|status|help}`

The dev server automatically:
- Sets `HOSTNAME="liquid-m3-pro-dev"` for Sidekiq identification
- Manages Rails web server and Sidekiq worker
- Provides public access via Tailscale Funnel when using `start-public`

## Other Notes

- **Apple Messages for Business**: ALWAYS use CaseTransformer for case conversions (see AMB section above)
- Remember that any tailscale command requires privilege - ask user to execute them directly
- Do not push changes to git until user approves
- Keep tests fast and isolated
