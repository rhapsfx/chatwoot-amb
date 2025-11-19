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

## Deployment Scripts

- **NEVER run deployment scripts through Claude Code** - SSH and rsync are blocked by sandbox
- **ALWAYS ask user to run deployment scripts manually** in their terminal:
  - `./script/deploy-backend-changes-safe.sh` - Deploy backend code to production
  - `./script/deploy-assets-only.sh` - Build and deploy frontend assets
  - `./script/enable_custom_roles_production.sh` - Enable feature flags on production
- **Claude Code can**: Prepare code, create commits, push to git
- **User must**: Run deployment and server management scripts directly

## Other Notes

- **Apple Messages for Business**: ALWAYS use CaseTransformer for case conversions (see AMB section above)
- Remember that any tailscale command requires privilege - ask user to execute them directly
- Do not push changes to git until user approves