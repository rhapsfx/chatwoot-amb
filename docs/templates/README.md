# MessageTemplate System Documentation

Complete documentation for the Chatwoot MessageTemplate system, including attachment implementation guidance for Apple Messages for Business and other channels.

## Quick Navigation

### Core Reference Documentation
Essential technical documentation for working with the MessageTemplate system:

1. **[MESSAGETEMPLATE_ARCHITECTURE.md](./MESSAGETEMPLATE_ARCHITECTURE.md)** - REQUIRED
   - Complete system architecture (12 sections)
   - Current attachment handling patterns
   - BotRendererService & BotMessagingService details
   - AppleMessagesTemplateAdapter implementation
   - Three attachment implementation options
   - Critical architecture patterns

2. **[MESSAGETEMPLATE_API_REFERENCE.md](./MESSAGETEMPLATE_API_REFERENCE.md)** - API Contracts
   - All API endpoints with examples
   - Content type specifications
   - Parameter formats and validation
   - Error response codes
   - Best practices for template usage

3. **[SENDING_FILES_VIA_BOT_API.md](./SENDING_FILES_VIA_BOT_API.md)** - File Attachments Guide
   - Current file attachment patterns
   - Implementation details
   - API usage examples

### Additional Documentation

#### Examples (`examples/`)
- **[GUITAR_FORM_TEMPLATE.md](./examples/GUITAR_FORM_TEMPLATE.md)** - Example template implementation

#### Fixes (`fixes/`)
- **[BLOCK_EDITOR_FIX.md](./fixes/BLOCK_EDITOR_FIX.md)** - Block editor bug fixes
- **[FIX_TEMPLATES_NOT_SHOWING.md](./fixes/FIX_TEMPLATES_NOT_SHOWING.md)** - Template visibility fixes
- **[GUITAR_FORM_FIXES.md](./fixes/GUITAR_FORM_FIXES.md)** - Guitar form specific fixes
- **[TEMPLATE_EDITOR_IMAGE_DISPLAY_FIX.md](./fixes/TEMPLATE_EDITOR_IMAGE_DISPLAY_FIX.md)** - Image display fixes
- **[TEMPLATE_MIGRATION_IMAGE_FORMAT_FIX.md](./fixes/TEMPLATE_MIGRATION_IMAGE_FORMAT_FIX.md)** - Migration image format fixes

#### Reports (`reports/`)
- **[PHASE_1_IMPLEMENTATION_SUMMARY.md](./reports/PHASE_1_IMPLEMENTATION_SUMMARY.md)** - Phase 1 completion details
- **[BOT_RENDERER_VERIFICATION_REPORT.md](./reports/BOT_RENDERER_VERIFICATION_REPORT.md)** - Template rendering verification

#### Testing (`testing/`)
- **[TEMPLATE_ATTACHMENT_TESTS.md](./testing/TEMPLATE_ATTACHMENT_TESTS.md)** - Comprehensive test documentation
- **[TEMPLATE_ATTACHMENT_TESTS_SUMMARY.md](./testing/TEMPLATE_ATTACHMENT_TESTS_SUMMARY.md)** - Test suite summary
- **[TEMPLATE_ATTACHMENT_TESTS_QUICK_REFERENCE.md](./testing/TEMPLATE_ATTACHMENT_TESTS_QUICK_REFERENCE.md)** - Quick test reference
- **[TEST_FILES_MANIFEST.txt](./testing/TEST_FILES_MANIFEST.txt)** - Test file inventory

### Related Documentation
- **[../bot-migration/COMPLETE_MIGRATION_SUMMARY.md](../bot-migration/COMPLETE_MIGRATION_SUMMARY.md)** - Bot migration toolkit
- **[../../CLAUDE.md](../../CLAUDE.md)** - Project development guidelines

---

## Architecture Overview

### MessageTemplate System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend UI                              │
│              (TemplateBuilder, ReplyBox)                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────┐
│         TemplatesController (API Layer)                     │
│  GET/POST/PUT/DELETE /api/v1/accounts/:id/templates         │
│  POST                /templates/:id/render                  │
│  POST                /templates/from_apple_message          │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ↓              ↓              ↓
   ┌─────────┐  ┌──────────┐  ┌─────────┐
   │ Message │  │ BotMsg   │  │Template │
   │Template │  │Svc       │  │ Content │
   │ Model   │  │          │  │ Block   │
   └────┬────┘  └────┬─────┘  └────┬────┘
        │            │             │
        └────────────┼─────────────┘
                     ↓
        ┌─────────────────────────────┐
        │ BotRendererService          │
        │ - Validate parameters       │
        │ - Load images               │
        │ - Process variables         │
        │ - Adapt for channel         │
        └────────────┬────────────────┘
                     │
                     ↓
        ┌─────────────────────────────┐
        │ AppleMessagesTemplateAdapter│
        │ - Transform content blocks  │
        │ - Format Apple MSP content  │
        │ - Handle image references   │
        └────────────┬────────────────┘
                     │
        ┌────────────┴────────────┐
        ↓                         ↓
   ┌──────────┐         ┌─────────────────┐
   │ Messages │         │ AppleMessagesFBS│
   │ Inbox    │         │SendMessageSvc   │
   └──────────┘         └─────────────────┘
        │                        │
        └────────────┬───────────┘
                     ↓
            ┌─────────────────┐
            │   Apple MSP     │
            │   REST API v4.1 │
            └─────────────────┘
```

### Data Storage Patterns

#### Pattern 1: Content Blocks (Generic Templates)
```
MessageTemplate
  └─ TemplateContentBlock (multiple)
       ├─ block_type: 'time_picker'
       ├─ properties: { title, event, timeslots, ... }
       └─ conditions: { if: "{{user_type}} == 'premium'" }
```

#### Pattern 2: Metadata (Migrated Bot Templates)
```
MessageTemplate.metadata = {
  apple_message_content: {
    content_type: 'apple_time_picker',
    content_attributes: { ... },
    images: [ ... ]
  }
}
```

#### Pattern 3: Images (Via AppleListPickerImage)
```
MessageTemplate
  └─ TemplateContentBlock (contains image_identifier reference)
       └─ "image_identifier": "img_123"
            ↓ Resolved at render time
       AppleListPickerImage (identifier: "img_123")
            └─ has_one_attached :image → ActiveStorage
```

---

## Key Files Reference

| File | Purpose | Key Responsibility |
|------|---------|-------------------|
| `app/models/message_template.rb` | Model & validations | Template lifecycle, scopes |
| `app/models/template_content_block.rb` | Content blocks | Block rendering, conditions |
| `app/models/template_channel_mapping.rb` | Channel mappings | Channel-specific adaptations |
| `app/models/template_usage_log.rb` | Analytics | Usage tracking |
| `app/models/apple_list_picker_image.rb` | Image storage | Current attachment pattern |
| `app/services/templates/bot_renderer_service.rb` | Template rendering | Render for bots |
| `app/services/templates/bot_messaging_service.rb` | Message sending | Send to conversations |
| `app/services/templates/adapters/apple_messages_template_adapter.rb` | Format conversion | Transform to Apple MSP |
| `app/controllers/api/v1/accounts/templates_controller.rb` | API endpoints | HTTP interface |

---

## Current Attachment Handling

### AppleListPickerImage Model (Current)
- Stores images for list pickers
- Inbox-scoped (not template-scoped)
- Identifier-based references
- ActiveStorage integration
- Base64 encoding at render time

### Message Attachments (Comparison)
- Stored in `Attachment` model
- Message-scoped
- Direct foreign key relationships
- ActiveStorage integration

### Limitations of Current Approach
1. Inbox-scoped (cannot reuse across inboxes)
2. Identifier-based (no foreign key relationships)
3. At-render-time encoding (performance consideration)
4. Limited to content_attributes storage

---

## Recommended Attachment Implementation

### Option 1: Extend Without Breaking (RECOMMENDED)
Add native attachment support while maintaining backward compatibility:

```ruby
class MessageTemplate < ApplicationRecord
  # New: native file support
  has_many_attached :attachments

  # Keep existing for backward compatibility
  has_many :content_blocks

  # Helpers to distinguish old vs new
  def uses_native_attachments?
    attachments.attached?
  end

  def uses_identifier_based_images?
    metadata['apple_message_content'].present? ||
    content_blocks.any? { |b| b.properties.dig('images').present? }
  end
end
```

**Advantages**:
- Backward compatible
- No migration of existing templates
- Gradual adoption path
- Works with existing services

**Implementation effort**: Medium (1-2 days)

### Option 2: Junction Model
Create `TemplateAttachment` model for flexible attachment sharing.

**Advantages**:
- Enable attachment sharing across templates
- Track attachment usage
- Flexible attachment sources

**Implementation effort**: Medium (1-2 days)

### Option 3: Extend Metadata
Store attachment references in metadata JSONB.

**Advantages**:
- No new tables
- Flexible schema
- Version-proof

**Implementation effort**: Low (1 day)

---

## API Endpoints

### Main Endpoints
```
GET    /api/v1/accounts/:account_id/templates
       List templates with filtering

POST   /api/v1/accounts/:account_id/templates
       Create new template

GET    /api/v1/accounts/:account_id/templates/:id
       Get template details

PUT    /api/v1/accounts/:account_id/templates/:id
       Update template

DELETE /api/v1/accounts/:account_id/templates/:id
       Soft delete (deprecate)

POST   /api/v1/accounts/:account_id/templates/:id/render
       Render template with parameters

POST   /api/v1/accounts/:account_id/templates/from_apple_message
       Create from Apple message
```

Full API reference: [MESSAGETEMPLATE_API_REFERENCE.md](./MESSAGETEMPLATE_API_REFERENCE.md)

---

## Critical Architecture Patterns

### Pattern 1: Identifier-Based References
Images referenced by custom identifiers, not foreign keys:
- Allows cross-template sharing
- Flexible image reuse
- No hard-coded relationships

### Pattern 2: Metadata for Legacy Content
Bot templates stored in `metadata['apple_message_content']`:
- Maintains backward compatibility
- Makes templates accessible in UI
- Gradual migration path

### Pattern 3: Channel Adapters
Generic content → Channel-specific format:
- Apple Messages, WhatsApp, Web Widget adapters
- Consistent pattern for new channels
- Decoupled from main template logic

### Pattern 4: CaseTransformer (MANDATORY)
All Apple Messages features use CaseTransformer:
- Internal storage: snake_case
- Apple MSP API: camelCase
- Automatic conversion at boundaries

---

## Implementation Checklist

### Before Starting
- [ ] Review MESSAGETEMPLATE_ARCHITECTURE.md (12 sections)
- [ ] Choose implementation approach
- [ ] Plan database schema changes
- [ ] Check enterprise overlay for customizations
- [ ] Verify CaseTransformer compatibility

### During Implementation
- [ ] Add `has_many_attached :attachments` to MessageTemplate
- [ ] Update BotRendererService for dual sources
- [ ] Update AppleMessagesTemplateAdapter
- [ ] Add controller endpoints for attachment management
- [ ] Update database schema (if needed)

### Testing Phase
- [ ] Unit tests for attachment handling
- [ ] Integration tests for full rendering
- [ ] Backward compatibility tests
- [ ] Multi-channel testing

### Migration & Deployment
- [ ] Create migration script (if needed)
- [ ] Document usage patterns
- [ ] Update project CLAUDE.md
- [ ] Deploy with feature flag (optional)

---

## Best Practices

1. **Parameters**: Define all expected parameters with types
2. **Channels**: Specify supported channels when creating
3. **Tags**: Use consistent tags for filtering
4. **Versioning**: Increment on breaking changes
5. **Testing**: Test with `render_template` endpoint first
6. **Images**: Use standard identifiers for references
7. **Conditions**: Keep conditions simple
8. **Blocks**: Order by importance
9. **Mappings**: Define for channel-specific customization
10. **Metadata**: Store extra data in metadata field

---

## Support & Questions

For questions about:
- **Architecture**: See MESSAGETEMPLATE_ARCHITECTURE.md (Section 8: Critical Patterns)
- **API Usage**: See MESSAGETEMPLATE_API_REFERENCE.md
- **Current Implementation**: See SENDING_FILES_VIA_BOT_API.md
- **Examples**: See examples/GUITAR_FORM_TEMPLATE.md
- **Testing**: See testing/ directory for comprehensive test documentation
- **Bug Fixes**: See fixes/ directory for known issues and solutions
- **Implementation Reports**: See reports/ directory for project summaries

---

## Document Maintenance

Last Updated: November 8, 2025
Organized by: Claude Code
Status: Restructured for clarity and maintainability

Documents should be updated when:
- New attachment features are added
- Channel adapters are modified
- API contracts change
- Schema changes occur
- Best practices evolve
