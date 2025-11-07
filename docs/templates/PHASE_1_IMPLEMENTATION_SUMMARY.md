# Phase 1 Implementation: Database & Model Setup for Message Template Attachments

## Implementation Summary

Phase 1 has been completed, adding ActiveStorage attachment support to the MessageTemplate model with comprehensive validation and metadata management.

## Files Created/Modified

### 1. Migration File
**File**: `db/migrate/20251107141219_add_attachment_metadata_to_message_templates.rb`

- Adds `attachment_metadata` JSONB column to `message_templates` table
- Creates GIN index for efficient querying of attachment metadata
- Default value: `{}`

**To run**: `bundle exec rails db:migrate`

### 2. MessageTemplate Model
**File**: `app/models/message_template.rb`

#### Constants Added
```ruby
MAX_ATTACHMENTS = 5                    # Maximum 5 files per template
MAX_ATTACHMENT_SIZE = 100.megabytes    # 100MB limit (Apple Messages compatible)
ALLOWED_ATTACHMENT_TYPES = [...]       # Comprehensive list of allowed MIME types
```

Supported file types include:
- Images: JPEG, PNG, GIF, WebP, HEIC
- Videos: MP4, QuickTime, MPEG
- Audio: MP3, MP4, WAV, AAC
- Documents: PDF, Word, Excel, PowerPoint, Text, CSV
- Archives: ZIP, 7Z, RAR

#### ActiveStorage Association
```ruby
has_many_attached :attachments
```

#### Validations Added
- `validate_attachments_count`: Enforces MAX_ATTACHMENTS limit
- `validate_attachments_size`: Enforces MAX_ATTACHMENT_SIZE per file
- `validate_attachments_content_type`: Enforces ALLOWED_ATTACHMENT_TYPES

#### Public Methods Added

##### `attachments_summary`
Returns array of attachment metadata with details.

**Returns**:
```ruby
[
  {
    id: 123,
    filename: "document.pdf",
    content_type: "application/pdf",
    byte_size: 1048576,
    url: "https://...",
    created_at: Time,
    display_order: 0,
    description: "Optional description",
    metadata: {...}
  },
  ...
]
```

##### `attach_files(files)`
Attaches multiple files and updates metadata.

**Parameters**:
- `files`: Single file or array of files (ActiveStorage compatible)

**Returns**: `true` on success, `false` on failure

**Example**:
```ruby
template = MessageTemplate.find(1)
template.attach_files([file1, file2, file3])
```

##### `remove_attachment(attachment_id)`
Removes a specific attachment by ID and cleans up metadata.

**Parameters**:
- `attachment_id`: ID of the attachment to remove

**Returns**: `true` on success, `false` on failure

**Example**:
```ruby
template.remove_attachment(123)
```

##### `reorder_attachments(ordered_ids)`
Reorders attachments by providing ordered array of IDs.

**Parameters**:
- `ordered_ids`: Array of attachment IDs in desired order

**Returns**: `true` on success, `false` on failure

**Example**:
```ruby
template.reorder_attachments([123, 125, 124])
```

#### Private Methods Added

##### Metadata Management
- `initialize_attachment_metadata`: Ensures attachment_metadata structure exists
- `find_attachment_metadata(attachment_id)`: Retrieves metadata for specific attachment
- `update_attachment_metadata(attachment_id, additional_metadata)`: Updates/creates metadata entry
- `remove_attachment_metadata(attachment_id)`: Removes metadata entry
- `reindex_attachment_display_order`: Reindexes display order for all attachments

#### Metadata Structure

The `attachment_metadata` JSONB field stores:
```json
{
  "attachments": [
    {
      "id": "123",
      "display_order": 0,
      "description": "Optional description",
      "attached_at": "2025-11-07T14:12:00Z",
      "updated_at": "2025-11-07T14:12:00Z"
    }
  ]
}
```

## Features & Benefits

### 1. Thread Safety
- All attachment operations wrapped in `ActiveRecord::Base.transaction`
- Metadata updates are atomic with attachment operations
- Prevents race conditions in concurrent environments

### 2. Error Handling
- Comprehensive error messages for validation failures
- Proper exception handling with rollback on failures
- Errors added to ActiveRecord errors collection for form display

### 3. Validation
- File count limit (5 files max)
- File size limit (100MB per file)
- Content type validation (comprehensive MIME type allowlist)
- Validation runs on save, preventing invalid data

### 4. Metadata Management
- Separate JSONB field for attachment metadata
- Display order tracking
- Attachment descriptions
- Timestamps for tracking
- GIN index for efficient querying

### 5. Rails Conventions
- Follows ActiveStorage patterns
- Uses Rails URL helpers for attachment URLs
- Proper association configuration
- Consistent with existing codebase patterns

## Testing

### Test Script
**File**: `test_message_template_attachments.rb`

Run with: `rails runner test_message_template_attachments.rb`

This script verifies:
- Constants are defined
- ActiveStorage association is configured
- Database column exists
- All public methods exist
- All private methods exist
- All validation methods exist

### Manual Testing (Rails Console)

```ruby
# Get or create a template
template = MessageTemplate.first
# or
template = MessageTemplate.create!(
  name: "Test Template",
  account: Account.first,
  status: "active"
)

# Attach a file
file = File.open('path/to/document.pdf')
template.attach_files([file])

# View attachments
template.attachments_summary
# => [{id: 123, filename: "document.pdf", ...}]

# Check attachment metadata
template.attachment_metadata
# => {"attachments" => [{"id" => "123", "display_order" => 0, ...}]}

# Reorder attachments
template.reorder_attachments([123, 125, 124])

# Remove an attachment
template.remove_attachment(123)

# Validate file limits
template.attachments.count
# => Should be <= 5

# Test validations
template.valid?
template.errors.full_messages
```

## Integration Considerations

### For Phase 2 (API Endpoints)

The following API endpoints can now be implemented:

1. **Attach Files**
   - Endpoint: `POST /api/v1/accounts/:account_id/message_templates/:id/attach_files`
   - Controller action will call: `@template.attach_files(params[:files])`

2. **Remove Attachment**
   - Endpoint: `DELETE /api/v1/accounts/:account_id/message_templates/:id/attachments/:attachment_id`
   - Controller action will call: `@template.remove_attachment(params[:attachment_id])`

3. **Reorder Attachments**
   - Endpoint: `PUT /api/v1/accounts/:account_id/message_templates/:id/reorder_attachments`
   - Controller action will call: `@template.reorder_attachments(params[:ordered_ids])`

4. **Get Attachments**
   - Endpoint: `GET /api/v1/accounts/:account_id/message_templates/:id`
   - Response will include: `@template.attachments_summary`

### For Phase 3 (Bot API Integration)

The attachment data is available in the `detailed_json` method output:

```ruby
template.detailed_json(include_content_blocks: true)
# Can be extended to include:
# attachments: template.attachments_summary
```

### For Phase 4 (Frontend UI)

The frontend will interact with:
- `attachments_summary` for displaying current attachments
- File upload API for attaching new files
- Delete API for removing attachments
- Reorder API for drag-and-drop functionality

## RuboCop Compliance

The implementation has been linted with RuboCop. Remaining warnings are:
- `Metrics/ClassLength`: Pre-existing (MessageTemplate is a large model)
- `Rails/UniqueValidationWithoutIndex`: Pre-existing validation
- Method complexity warnings: Pre-existing methods
- `Style/MultilineBlockChain`: Minor style preference (acceptable in Rails)

All new code follows Rails and RuboCop conventions.

## Database Migration

**IMPORTANT**: Before proceeding to Phase 2, run the migration:

```bash
bundle exec rails db:migrate
```

This will:
1. Add the `attachment_metadata` JSONB column
2. Create the GIN index for efficient querying
3. Set default value to `{}`

## Next Steps

### Phase 2: API Endpoints (Week 2)
- [ ] Add routes for attachment management
- [ ] Update MessageTemplatesController with new actions
- [ ] Add controller specs
- [ ] Add request specs
- [ ] Handle file upload parameters
- [ ] Implement proper authorization (Pundit policy updates)

### Phase 3: Bot API Integration (Week 3)
- [ ] Extend BotRendererService to include attachments
- [ ] Update bot API serialization
- [ ] Add attachment delivery logic
- [ ] Test with actual bot workflows

### Phase 4: Frontend UI (Week 4)
- [ ] Create attachment upload component
- [ ] Add attachment preview/list component
- [ ] Implement drag-and-drop reordering
- [ ] Add delete confirmation
- [ ] Show file size and type validation errors
- [ ] Display upload progress

## Rollback Plan

If issues are discovered, rollback with:

```ruby
# Generate rollback migration
rails generate migration RemoveAttachmentMetadataFromMessageTemplates

# In the migration:
class RemoveAttachmentMetadataFromMessageTemplates < ActiveRecord::Migration[7.1]
  def change
    remove_index :message_templates, :attachment_metadata if index_exists?(:message_templates, :attachment_metadata)
    remove_column :message_templates, :attachment_metadata, :jsonb
  end
end

# Then remove the model code changes
```

Note: ActiveStorage attachments will remain in the database (handled by Rails) but will become orphaned if the model association is removed.

## Compatibility

- **Rails Version**: 7.1+
- **PostgreSQL**: 9.4+ (JSONB support required)
- **ActiveStorage**: Configured and working
- **Ruby Version**: 3.x

## Performance Considerations

1. **GIN Index**: Enables efficient querying of attachment metadata
2. **Lazy Loading**: Attachments are not loaded unless accessed
3. **Metadata Caching**: Attachment metadata stored in single JSONB column
4. **Transaction Safety**: All operations wrapped in transactions

## Security Considerations

1. **File Type Validation**: Only allowed MIME types can be uploaded
2. **File Size Validation**: Maximum 100MB per file (configurable)
3. **Count Validation**: Maximum 5 files per template
4. **Authorization**: To be implemented in Phase 2 (controller level)

## Documentation Files

- This file: `docs/templates/PHASE_1_IMPLEMENTATION_SUMMARY.md`
- Test script: `test_message_template_attachments.rb`
- Specification: `docs/templates/SENDING_FILES_VIA_BOT_API.md`

---

**Implementation Date**: November 7, 2025
**Rails Version**: 7.1
**Status**: ✅ Phase 1 Complete
