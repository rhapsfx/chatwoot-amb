# MessageTemplate Model Architecture Analysis

## Executive Summary

The MessageTemplate system is a sophisticated unified template framework for Apple Messages for Business and other channels. It currently handles rich interactive content (time pickers, list pickers, forms, payments) with image attachments through a specialized `AppleListPickerImage` model. Implementing direct attachment support requires careful consideration of the existing architecture to avoid breaking functionality.

---

## 1. MessageTemplate Model Structure

### Current Schema (Schema Information)
```
message_templates table:
├── id (bigint, primary key)
├── account_id (bigint, NOT NULL, FK → accounts)
├── name (string, NOT NULL, UNIQUE per account)
├── category (string) - One of: general, payment, scheduling, support, marketing, feedback, notification, confirmation, sales
├── description (text)
├── status (string, DEFAULT 'active') - One of: active, draft, deprecated
├── version (integer, DEFAULT 1)
├── parameters (jsonb) - Parameter definitions for bots
├── metadata (jsonb) - Flexible storage for Apple content, bot config
├── supported_channels (text[]) - Array of channel types (e.g., ['apple_messages_for_business'])
├── tags (text[]) - Array for categorization (e.g., ['acoustic-house', 'wismo'])
├── use_cases (text[]) - Array for use case filtering (e.g., ['agent_ui'])
├── created_at (datetime, NOT NULL)
└── updated_at (datetime, NOT NULL)

Indexes:
- account_id
- category
- status
- tags (GIN)
- supported_channels (GIN)
- metadata (GIN)
- [account_id, category]
- [account_id, status]
```

### Key Associations
```ruby
has_many :content_blocks, class_name: 'TemplateContentBlock', dependent: :destroy
has_many :channel_mappings, class_name: 'TemplateChannelMapping', dependent: :destroy
has_many :usage_logs, class_name: 'TemplateUsageLog', dependent: :destroy
belongs_to :account
```

### Current Data Storage Patterns

#### Pattern 1: Content via Content Blocks
```ruby
# Templates use nested TemplateContentBlock records
template.content_blocks.each do |block|
  block.block_type  # e.g., 'time_picker', 'list_picker', 'form'
  block.properties  # jsonb with block-specific data
  block.conditions  # jsonb for conditional display
end
```

#### Pattern 2: Apple Messages Content in Metadata
```ruby
# For migrated bot templates, entire Apple content stored in metadata
template.metadata['apple_message_content'] = {
  content: "Message text",
  content_type: "apple_time_picker",
  content_attributes: {
    event: { timeslots: [...] },
    received_title: "...",
    reply_title: "..."
  }
}
```

#### Pattern 3: Images via AppleListPickerImage
```ruby
# Separate model for list picker images (inbox-scoped)
apple_list_picker_images table:
├── id
├── identifier (string, UNIQUE per inbox) - Reference in template data
├── account_id
├── inbox_id (specific inbox)
├── original_name
├── description
├── image (has_one_attached to ActiveStorage)
└── created_at, updated_at

# Usage in templates:
content_attributes = {
  sections: [
    {
      items: [
        { identifier: "item_1", image_identifier: "img_123" }
      ]
    }
  ]
}
```

---

## 2. Current Attachment Handling

### How Images Are Currently Managed

#### For Apple Messages List Pickers
```ruby
# Images uploaded separately to AppleListPickerImage
class AppleListPickerImage < ApplicationRecord
  belongs_to :account
  belongs_to :inbox  # CRITICAL: Scoped per inbox
  has_one_attached :image  # ActiveStorage
  validates :identifier, uniqueness: { scope: :inbox_id }
end

# Images referenced by identifier in templates:
{
  image_identifier: "img_123"  # Looks up AppleListPickerImage.find_by(identifier: "img_123")
}
```

#### For Message Attachments
```ruby
# Message attachments use Attachment model:
class Attachment < ApplicationRecord
  belongs_to :account
  belongs_to :message  # Scoped per message
  has_one_attached :file
  enum file_type: { image: 0, audio: 1, video: 2, file: 3, ... }
end
```

#### For Templates with Images (BotRendererService)
```ruby
# When rendering templates from bot config:
def load_images_from_storage(attrs)
  image_identifiers = collect_image_identifiers(attrs)
  
  # Load from AppleListPickerImage (account-scoped)
  images = AppleListPickerImage
           .where(account_id: template.account_id, identifier: image_identifiers)
           .includes(image_attachment: :blob)
           .group_by(&:identifier)
           .transform_values(&:first)
  
  # Convert to base64 for rendering
  images_array = image_identifiers.filter_map do |identifier|
    img = images[identifier]
    next unless img&.image&.attached?
    
    {
      'identifier' => img.identifier,
      'data' => Base64.strict_encode64(img.image.download),
      'description' => img.description
    }
  end
  
  attrs['images'] = images_array
end
```

### Current Limitations
1. **Inbox-scoped storage** - AppleListPickerImage requires `inbox_id`, limiting reuse
2. **Identifier-based references** - Templates reference images by custom identifiers, not direct associations
3. **Base64 encoding at render time** - Images loaded and encoded every time template is rendered
4. **Limited to content_attributes** - Images stored in jsonb, not as proper attachments

---

## 3. BotRendererService Implementation

### Purpose
Renders MessageTemplate for bot consumption with parameter substitution and channel adaptation.

### Flow
```
Input: template_id, parameters, channel_type
  ↓
Validation:
  ├─ Parameter validation (types, required fields)
  ├─ Channel compatibility check
  └─ Template existence
  ↓
Rendering Path:
  ├─ IF template.metadata['apple_message_content'] exists (migrated bot templates):
  │   └─ render_from_metadata()
  │       ├─ Detect content type from structure
  │       ├─ Transform bot format to Chatwoot format
  │       ├─ Load images from AppleListPickerImage
  │       └─ Merge parameters
  │
  └─ ELSE (standard templates with content blocks):
      ├─ Process template variables
      │   └─ Replace {{variable}} placeholders
      ├─ Evaluate block conditions
      └─ Adapt for channel
          └─ Use channel-specific adapter
  ↓
Output: {
  template_id,
  template_name,
  content_type: 'apple_time_picker',
  content: 'User-facing text',
  content_attributes: { event: {...}, images: [...] },
  webhook_data: {...}
}
```

### Key Methods
- `render_for_bot()` - Main entry point
- `render_from_metadata()` - For migrated bot templates
- `load_images_from_storage()` - Retrieves images from AppleListPickerImage
- `process_template_variables()` - Variable substitution
- `adapt_for_channel()` - Channel adaptation via adapters

### Image Loading in BotRendererService
```ruby
def load_images_from_storage(attrs)
  # 1. Collect all image identifiers from sections, received_message, reply_message
  image_identifiers = collect_image_identifiers(attrs)
  
  # 2. Query AppleListPickerImage for account (NOT inbox-scoped here\!)
  images = AppleListPickerImage
           .where(account_id: template.account_id, identifier: image_identifiers)
           .includes(image_attachment: :blob)
           .group_by(&:identifier)
  
  # 3. Download and base64 encode
  images_array = image_identifiers.filter_map do |identifier|
    img = images[identifier]
    next unless img&.image&.attached?
    
    {
      'identifier' => img.identifier,
      'data' => Base64.strict_encode64(img.image.download),
      'description' => img.description
    }
  end
  
  # 4. Add to content_attributes
  attrs['images'] = images_array
end
```

---

## 4. BotMessagingService Implementation

### Purpose
Sends rendered templates as messages to conversations.

### Flow
```
Input: conversation, template, parameters, sender
  ↓
Render template via BotRendererService
  ↓
For Apple Messages:
  ├─ Show typing indicator (1.5 seconds)
  └─ IF should_use_message_processor? (text messages):
  │   └─ Use MessageProcessorService (auto URL-to-Rich Link conversion)
  │
  └─ ELSE:
      └─ Create message directly with content_type & content_attributes
  ↓
Trigger Rails events (for webhooks, etc.)
  ↓
Return created message
```

### Key Methods
- `send_template_message()` - Main entry point
- `should_use_message_processor?()` - Decide which processing path
- `build_message_params()` - Format for message creation
- `create_message()` - Create Message record with content_attributes
- `send_typing_indicator()` - Apple MSP typing indicator

### Message Creation
```ruby
def create_message(rendered)
  message_params = {
    account_id: @conversation.account_id,
    inbox_id: @conversation.inbox_id,
    message_type: :outgoing,
    content: rendered[:content],
    content_type: rendered[:content_type],  # e.g., 'apple_time_picker'
    content_attributes: rendered[:content_attributes],  # e.g., { event: {...}, images: [...] }
    sender_type: @sender.class.name,
    sender_id: @sender.id,
    additional_attributes: {
      template_id: @template.id,
      template_name: @template.name,
      rendered_at: Time.current.iso8601
    }
  }
  
  @conversation.messages.create\!(message_params)
end
```

---

## 5. AppleMessagesTemplateAdapter

### Purpose
Converts unified template content blocks to Apple Messages for Business format.

### Flow
```
Input: content_blocks, template, parameters
  ↓
Check for channel-specific mapping:
  ├─ IF channel_mapping exists with field_mappings:
  │   └─ Use custom field mappings
  │
  └─ ELSE:
      └─ Auto-adapt based on block_type
  ↓
Block Type Handling:
  ├─ time_picker → apple_time_picker
  │   └─ Format timeslots, merge received/reply messages
  ├─ list_picker → apple_list_picker
  │   └─ Format sections, merge images
  ├─ quick_reply → apple_quick_reply
  ├─ form → apple_form
  ├─ payment_request → apple_pay
  ├─ oauth → apple_auth
  └─ text → text
  ↓
Output: {
  content_type: 'apple_time_picker',
  content: 'Message text',
  content_attributes: { event: {...}, received_title: "...", images: [...] }
}
```

### Key Image Handling in Adapter
```ruby
def adapt_time_picker(block)
  properties = block[:properties]
  
  # Extract image identifiers (support both camelCase and snake_case)
  event_image_id = properties['imageIdentifier'] || properties['image_identifier']
  received_image_id = properties['receivedImageIdentifier'] || properties['received_image_identifier']
  reply_image_id = properties['replyImageIdentifier'] || properties['reply_image_identifier']
  
  # Auto-fallback: if reply image not specified, reuse received image
  reply_image_id = received_image_id if reply_image_id.blank?
  
  # Build output with image identifiers
  result = {
    content_type: 'apple_time_picker',
    content: properties['title'] || 'Select a time',
    content_attributes: {
      'event' => {
        # timeslots, title, etc.
        'image_identifier' => event_image_id  # Reference, not actual image
      },
      'received_image_identifier' => received_image_id,
      'reply_image_identifier' => reply_image_id
    }
  }
  result
end
```

### Important: Image Identifiers Are References
- Adapter outputs image **identifiers**, not actual image data
- Images stored via `AppleListPickerImage` or embedded as base64 in `content_attributes['images']`
- At render time (BotRendererService), identifiers are resolved to actual images

---

## 6. Route Endpoints for message_templates

### API Endpoints (Api::V1::Accounts::TemplatesController)
```ruby
# Templated as config/routes.rb:
# resources :templates, controller: 'templates'

GET    /api/v1/accounts/:account_id/templates
       # List templates with filtering:
       # ?category=scheduling&status=active&channel=apple_messages_for_business&search=guitar

POST   /api/v1/accounts/:account_id/templates
       # Create new template

GET    /api/v1/accounts/:account_id/templates/:id
       # Show template with content blocks

PUT    /api/v1/accounts/:account_id/templates/:id
       # Update template

DELETE /api/v1/accounts/:account_id/templates/:id
       # Soft delete (sets status='deprecated')

POST   /api/v1/accounts/:account_id/templates/:id/render
       # Render template with parameters
       # Requires: parameters, channel_type

POST   /api/v1/accounts/:account_id/templates/from_apple_message
       # Create template from Apple Messages conversation
       # Requires: messageType, messageData, templateName (optional)
```

### Controller Methods
- `index()` - List with filtering (category, status, channel, search, pagination)
- `show()` - Get template detail with content blocks
- `create()` - Create with content blocks and channel mappings
- `update()` - Update with nested attributes
- `destroy()` - Soft delete
- `render_template()` - Render for bot consumption
- `from_apple_message()` - Create from conversation message

### Parameter Handling
```ruby
def template_params
  # Auto-normalizes camelCase from frontend to snake_case for Rails
  normalized_params = params[:template].to_unsafe_h.deep_transform_keys do |key|
    key.to_s.underscore.to_sym
  end
  
  # Permit whitelist
  ActionController::Parameters.new(normalized_params).permit(
    :name,
    :category,
    :description,
    :status,
    :version,
    :content,
    :metadata,
    parameters: {},        # Hash of param definitions
    supported_channels: [], # Array
    tags: [],              # Array
    use_cases: []           # Array
  )
end
```

---

## 7. Enterprise Edition Considerations

### Files to Review
- `enterprise/app/policies/message_template_policy.rb` - May have additional authorization

### Potential Extensions
- Custom fields in templates
- Enterprise-specific channels
- Advanced filtering/segmentation
- Template versioning and approval workflows

---

## 8. Critical Architecture Patterns

### Pattern 1: Image Identifier-Based References
```
Content Blocks store:
  {
    image_identifier: "img_123"  (string identifier, NOT foreign key)
  }

AppleListPickerImage stores:
  {
    identifier: "img_123",  (matches the reference)
    image: <ActiveStorage attachment>
  }

At render time:
  BotRendererService resolves "img_123" → AppleListPickerImage → loads from storage
```

**Why**: Allows same images to be referenced across multiple templates without hard-coded relationships.

### Pattern 2: Metadata for Bot Config
```
Old Bot Templates stored in:
  AgentBot.bot_config['templates'] = [...]

Migrated to:
  MessageTemplate.metadata['apple_message_content'] = {
    content_type: '...',
    content_attributes: {...},
    ...
  }

Reason: Maintains backward compatibility while making templates accessible in UI.
```

### Pattern 3: Channel Adapters
```
Generic template structure → Channel-specific adapter → Channel-specific format

TemplateContentBlock (generic):
  { block_type: 'time_picker', properties: {...} }
    ↓
AppleMessagesTemplateAdapter:
  Transforms to apple_time_picker with Apple MSP-compatible structure
    ↓
Message.content_attributes:
  { event: {...}, received_message: {...} }
```

### Pattern 4: CaseTransformer for Consistency
```
All Apple Messages features MUST use CaseTransformer for case normalization:
  
  Internal (snake_case):
    { image_identifier: "img_123", timezone_offset: 3600 }
  
  Apple MSP (camelCase):
    { imageIdentifier: "img_123", timezoneOffset: 3600 }
  
  CaseTransformer handles conversion:
    to_apple_format(internal_data) → camelCase
    from_apple_format(apple_data) → snake_case
```

---

## 9. Key Dependencies & Data Flows

### Template Creation Flow
```
Frontend (TemplateBuilder)
  ↓
POST /api/v1/accounts/:id/templates
  ↓
TemplatesController#create
  ├─ Create MessageTemplate
  ├─ Create TemplateContentBlock(s) - nested attributes
  └─ Create TemplateChannelMapping(s) - nested attributes
  ↓
Database: message_templates, template_content_blocks, template_channel_mappings
```

### Template Usage Flow
```
Frontend (ReplyBox / "/" command)
  ↓
POST /api/v1/accounts/:id/templates/:id/render
  ↓
TemplatesController#render_template
  ↓
BotRendererService#render_for_bot
  ├─ Validate parameters
  ├─ IF migrated bot template:
  │   └─ load_images_from_storage()
  │       └─ Query AppleListPickerImage, download & base64 encode
  │   └─ transform_bot_format_to_chatwoot()
  │
  └─ ELSE:
      ├─ Process content blocks
      ├─ Replace variables
      └─ Adapt via AppleMessagesTemplateAdapter
  ↓
Return rendered content with images embedded as base64
  ↓
Frontend receives complete rendered message ready to send
```

### Message Sending Flow
```
Frontend (ReplyBox / Template selection)
  ↓
POST /api/v1/accounts/:id/conversations/:id/messages
  ├─ content_type: 'apple_time_picker'
  ├─ content_attributes: { event: {...}, images: [...] }
  └─ (or rendered via above flow first)
  ↓
BotMessagingService#send_template_message (if template-based)
  ├─ Render via BotRendererService
  ├─ Send typing indicator
  └─ Create message via MessageProcessorService or directly
  ↓
Message#create\!
  ├─ Store in database with content_type & content_attributes
  └─ No separate Attachment records (unlike regular messages)
  ↓
AppleMessagesForBusiness::SendMessageService
  ├─ Extract images from content_attributes['images']
  ├─ Upload to Apple MSP
  └─ Send message
```

---

## 10. Attachment Implementation Roadmap

### Current State
- Images stored in `AppleListPickerImage` with custom identifiers
- Images referenced in `content_attributes` by identifier or base64 data
- No direct `has_many_attached` relationship on MessageTemplate

### Proposed Implementation (Safe Approach)

#### Option 1: Extend Without Breaking (Recommended)
```ruby
# Keep AppleListPickerImage for backward compatibility
# Add new native attachment support in parallel

class MessageTemplate < ApplicationRecord
  # New relationship (optional, for new templates)
  has_many_attached :attachments  # Generic file support
  
  # Keep existing
  has_many :content_blocks
  
  # Helper to distinguish old vs new
  def uses_native_attachments?
    attachments.attached?
  end
  
  def uses_identifier_based_images?
    metadata['apple_message_content'].present? ||
    content_blocks.any? { |b| b.properties.dig('images').present? }
  end
end
```

#### Option 2: Create TemplateAttachment Junction Model
```ruby
class TemplateAttachment < ApplicationRecord
  belongs_to :message_template
  belongs_to :attachment_record, class_name: 'Attachment'  # or use ActiveStorage
  
  # Allows templates to reference attachments
  # Enables sharing attachments across templates
end
```

#### Option 3: Extend Metadata Schema
```ruby
# Store attachment references in metadata
template.metadata = {
  apple_message_content: {...},
  attachments: [
    {
      key: 'img_hero',
      type: 'image',
      size: 12345,
      content_type: 'image/png',
      storage_path: 'templates/acme/hero.png'
    }
  ]
}
```

---

## 11. Recommended Next Steps

### Before Implementation
1. **Review existing attachment usage** across templates
2. **Audit AppleListPickerImage** current adoption
3. **Verify CaseTransformer compatibility** with new attachment fields
4. **Check Enterprise overlay** for custom template handling

### During Implementation
1. **Add migration** for new `template_attachments` table (if using junction model)
2. **Update MessageTemplate#detailed_json** to include attachment URLs
3. **Modify BotRendererService** to load native attachments
4. **Update AppleMessagesTemplateAdapter** to handle attachment references
5. **Add validation** to ensure attachment limits per channel

### After Implementation
1. **Create migration script** to convert AppleListPickerImage references to native attachments
2. **Add API endpoints** for template attachment upload/management
3. **Update documentation** with attachment usage examples
4. **Add tests** for attachment handling across channels

---

## 12. Key Files Summary

| File | Purpose | Key Methods |
|------|---------|-------------|
| `message_template.rb` | Model, validations, scopes | `bot_summary`, `compatible_with?`, `mapping_for_channel`, `create_new_version`, `detailed_json`, `build_content` |
| `bot_renderer_service.rb` | Render templates for bots | `render_for_bot`, `load_images_from_storage`, `transform_bot_format_to_chatwoot`, `adapt_for_channel` |
| `bot_messaging_service.rb` | Send template messages to conversations | `send_template_message`, `build_message_params` |
| `apple_messages_template_adapter.rb` | Transform to Apple MSP format | `adapt`, `adapt_time_picker`, `adapt_list_picker`, `format_list_picker_sections` |
| `templates_controller.rb` | API endpoints | `index`, `show`, `create`, `update`, `destroy`, `render_template`, `from_apple_message` |
| `apple_list_picker_image.rb` | Image storage model | `image_data_base64`, `image_url` |
| `template_content_block.rb` | Content building blocks | `render_for_channel`, `conditions_met?`, `process_properties` |
| `template_channel_mapping.rb` | Channel-specific adaptations | `apply_mappings` |
| `template_usage_log.rb` | Analytics | `template_stats`, `account_stats`, `popular_parameters` |

