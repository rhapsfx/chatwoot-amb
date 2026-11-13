# Apple Messages Image Architecture - Long-Term Fix Plan

**Status**: Planning Phase
**Created**: 2025-01-19
**Target Implementation**: Q2 2025

## Executive Summary

This document outlines a comprehensive architectural redesign of the Apple Messages for Business image storage system to solve the current inbox-scoping issue where shared images (like `messages_png`) must be manually replicated across all inboxes.

**Current Problem**: Images are inbox-specific, requiring manual duplication of shared system images across every Apple Messages inbox.

**Proposed Solution**: Implement a hybrid two-tier architecture with account-wide shared images and inbox-specific template images.

---

## Current Architecture Analysis

### Current System (Inbox-Scoped Images)

```
AppleListPickerImage Model
├── account_id (belongs to Account)
├── inbox_id (belongs to Inbox) ← PROBLEM: All images are inbox-scoped
├── identifier (string)
├── description (text)
├── original_name (string)
└── image (ActiveStorage attachment)

Constraints:
- unique index on [inbox_id, identifier]
- All images must exist in specific inbox
- No sharing mechanism between inboxes
```

### Current Flow

```
Template Embedded Images        Manual Upload Scripts
        ↓                              ↓
    Message Created              Hardcoded inbox_id
        ↓                              ↓
SendListPickerService.perform    AppleListPickerImage.create
        ↓                              ↓
save_images_to_storage           Uses specific inbox_id
        ↓                              ↓
Uses message.inbox_id ← PROBLEM: Dynamic inbox determination
        ↓
AppleListPickerImage.create(inbox_id: message.inbox_id)
```

**Issues**:
1. Embedded template images go to whichever inbox first sends them
2. Manual scripts hardcode inbox_id (often wrong inbox)
3. No way to share system images (messages_png, etc.) across inboxes
4. Bot service can't find images if conversation is in different inbox
5. Manual replication required for every new inbox

---

## Proposed Architecture: Hybrid Two-Tier System

### Design Principles

1. **Separation of Concerns**: System images vs template-specific images
2. **Minimal Code Changes**: Preserve existing behavior where possible
3. **Backward Compatibility**: Existing images continue to work
4. **Performance**: Efficient queries, no N+1 problems
5. **Flexibility**: Support both shared and inbox-specific use cases

### New Models

#### 1. SharedAppleImage (Account-Wide)

```ruby
# app/models/shared_apple_image.rb
class SharedAppleImage < ApplicationRecord
  belongs_to :account
  has_one_attached :image

  validates :account_id, presence: true
  validates :identifier, presence: true, uniqueness: { scope: :account_id }
  validates :image_type, presence: true, inclusion: { in: %w[system branding template] }

  # Scopes
  scope :system_images, -> { where(image_type: 'system') }
  scope :branding_images, -> { where(image_type: 'branding') }
  scope :template_images, -> { where(image_type: 'template') }
end
```

**Database Schema**:
```ruby
create_table :shared_apple_images do |t|
  t.references :account, null: false, foreign_key: true, index: true
  t.string :identifier, null: false
  t.string :image_type, null: false, default: 'system'
  t.text :description
  t.string :original_name
  t.jsonb :metadata, default: {}
  t.timestamps

  t.index [:account_id, :identifier], unique: true
  t.index :image_type
end
```

**Image Types**:
- `system`: System-wide icons (messages_png, calendar icons, etc.)
- `branding`: Company branding (logos, colors, etc.)
- `template`: Reusable template images (form headers, generic icons)

#### 2. AppleListPickerImage (Inbox-Specific) - Modified

```ruby
# app/models/apple_list_picker_image.rb
class AppleListPickerImage < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  has_one_attached :image

  validates :account_id, presence: true
  validates :inbox_id, presence: true
  validates :identifier, presence: true, uniqueness: { scope: :inbox_id }

  # NEW: Indicate if this is a local override of a shared image
  validates :shared_override, inclusion: { in: [true, false] }, allow_nil: true

  # Scopes
  scope :local_only, -> { where(shared_override: [false, nil]) }
  scope :shared_overrides, -> { where(shared_override: true) }
end
```

**Migration**:
```ruby
class AddSharedOverrideToAppleListPickerImages < ActiveRecord::Migration[7.0]
  def change
    add_column :apple_list_picker_images, :shared_override, :boolean, default: false
    add_index :apple_list_picker_images, [:inbox_id, :shared_override]
  end
end
```

### Fallback Hierarchy

When fetching images, the system follows this priority:

```
1. AppleListPickerImage (inbox-specific)
   ├── shared_override: true → Inbox-specific override of shared image
   └── shared_override: false → Truly inbox-specific image

2. SharedAppleImage (account-wide)
   ├── image_type: 'system' → System icons (messages_png, etc.)
   ├── image_type: 'branding' → Company branding
   └── image_type: 'template' → Reusable templates

3. Embedded images (content_attributes['images'])
   └── Template-specific base64 images
```

---

## Implementation Plan

### Phase 1: Foundation (Week 1-2)

**Goal**: Create new models and migration without breaking existing functionality

#### Tasks:
1. **Create SharedAppleImage model**
   - Generate migration
   - Create model with validations
   - Add ActiveStorage attachment
   - Write RSpec tests

2. **Update AppleListPickerImage model**
   - Add `shared_override` column
   - Add scopes for local vs override
   - Update validations
   - Write migration tests

3. **Create ImageFetchService**
   - New service to implement fallback hierarchy
   - Handles three-tier lookup (inbox → shared → embedded)
   - Comprehensive logging
   - RSpec tests with all scenarios

#### Deliverables:
- [x] ✅ `db/migrate/20251119122654_create_shared_apple_images.rb`
- [x] ✅ `db/migrate/20251119122704_add_shared_override_to_apple_list_picker_images.rb`
- [x] ✅ `app/models/shared_apple_image.rb`
- [x] ✅ `app/models/apple_list_picker_image.rb` (updated)
- [x] ✅ `app/services/apple_messages_for_business/image_fetch_service.rb`
- [x] ✅ `spec/models/shared_apple_image_spec.rb`
- [x] ✅ `spec/services/apple_messages_for_business/image_fetch_service_spec.rb`

### Phase 2: Service Integration (Week 3)

**Goal**: Integrate ImageFetchService into existing send services

#### Tasks:
1. **Update SendListPickerService**
   - Replace `fetch_and_encode_images` with `ImageFetchService`
   - Preserve existing behavior
   - Add fallback logging
   - Update tests

2. **Update SendTimePickerService**
   - Same as SendListPickerService
   - Ensure received/reply image fallback works

3. **Update FormService**
   - Same pattern
   - Handle form-specific images

4. **Update Authentication Service**
   - Same pattern
   - Handle auth-specific images

5. **Update AcousticHouseBotService**
   - Use ImageFetchService for bot sends
   - Remove redundant image fetching code

#### Code Example:

```ruby
# app/services/apple_messages_for_business/send_list_picker_service.rb

def fetch_and_encode_images(identifiers)
  return [] if identifiers.empty?

  # Use new ImageFetchService with three-tier fallback
  AppleMessagesForBusiness::ImageFetchService.new(
    account_id: message.account_id,
    inbox_id: message.inbox_id,
    embedded_images: content_attributes['images']
  ).fetch_and_encode(identifiers)
end
```

#### Deliverables:
- [x] ✅ Updated `send_list_picker_service.rb`
- [x] ✅ Updated `send_time_picker_service.rb`
- [x] ✅ Updated `form_service.rb`
- [x] ✅ Updated `acoustic_house_bot_service.rb`
- [x] ✅ Integration tests for all services (via comprehensive RSpec tests)

### Phase 3: Migration Utilities (Week 4)

**Goal**: Create tools to migrate existing images to new architecture

#### Tasks:
1. **Create migration script: `migrate_system_images.rb`**
   - Identify system images (messages_png, calendar icons)
   - Copy to SharedAppleImage table with `image_type: 'system'`
   - Keep originals for backward compatibility

2. **Create migration script: `migrate_branding_images.rb`**
   - Identify branding images (logos, store icons)
   - Copy to SharedAppleImage with `image_type: 'branding'`

3. **Create admin UI for SharedAppleImage management**
   - Upload system images once
   - Manage branding per account
   - Mark images as shared or inbox-specific

#### Deliverables:
- [x] ✅ `script/migrate_system_images_to_shared.rb` (Completed 2025-01-19)
- [x] ✅ `script/migrate_branding_images_to_shared.rb` (Completed 2025-01-19)
- [x] ✅ `script/audit_image_usage.rb` (Completed 2025-01-19)
- [x] ✅ `script/verify_image_migration.rb` (Completed 2025-01-19)
- [ ] Admin UI component for SharedAppleImage management (Phase 4+)

### Phase 4: API Endpoints (Week 5)

**Goal**: Create API endpoints for frontend to upload/manage shared images

#### Endpoints:

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    namespace :accounts do
      resources :shared_apple_images, only: [:index, :create, :update, :destroy] do
        member do
          post :upload
          delete :remove_image
        end
        collection do
          get :system_images
          get :branding_images
          get :template_images
        end
      end
    end
  end
end
```

#### Controller:

```ruby
# app/controllers/api/v1/accounts/shared_apple_images_controller.rb
class Api::V1::Accounts::SharedAppleImagesController < Api::V1::Accounts::BaseController
  before_action :set_account

  def index
    @images = @account.shared_apple_images.order(created_at: :desc)
    render json: @images
  end

  def create
    @image = @account.shared_apple_images.build(shared_image_params)
    if @image.save
      render json: @image, status: :created
    else
      render json: { errors: @image.errors }, status: :unprocessable_entity
    end
  end

  # ... other CRUD methods
end
```

#### Deliverables:
- [ ] `app/controllers/api/v1/accounts/shared_apple_images_controller.rb`
- [ ] API documentation
- [ ] Frontend Vue component for shared image upload
- [ ] Integration tests

### Phase 5: Frontend Integration (Week 6)

**Goal**: Update frontend to use shared images

#### Tasks:
1. **Update ListPickerBlockEditor.vue**
   - Add tab for "Shared Images"
   - Show system images (read-only)
   - Show branding images (account-specific)
   - Allow selection of shared vs inbox-specific

2. **Update TimePickerModal.vue**
   - Same pattern as ListPickerBlockEditor

3. **Update AppleFormBuilder.vue**
   - Same pattern

#### Deliverables:
- [x] ✅ Updated Vue components (ListPickerBlockEditor.vue, EnhancedTimePickerModal.vue, AppleFormBuilder.vue)
- [x] ✅ Shared image selector component (SharedImageSelector.vue + useSharedAppleImages.js composable)
- [x] ✅ Component documentation (SHARED_IMAGE_SELECTOR_COMPONENT.md, integration guides)
- [ ] E2E tests (deferred to testing phase)

### Phase 6: Documentation & Cleanup (Week 7)

**Goal**: Document new architecture and deprecate old patterns

#### Tasks:
1. **Update CLAUDE.md**
   - Document new two-tier architecture
   - Update image upload guidelines
   - Deprecation notices

2. **Create migration guide**
   - For existing installations
   - For new installations
   - Rollback procedures

3. **Cleanup deprecated code**
   - Mark old upload scripts as deprecated
   - Add warnings to old APIs
   - Create deprecation timeline

#### Deliverables:
- [x] ✅ Updated `CLAUDE.md` (comprehensive two-tier architecture documentation)
- [x] ✅ `docs/apple-messages/IMAGE_MIGRATION_GUIDE.md` (complete migration guide)
- [x] ✅ `docs/apple-messages/SHARED_IMAGES_USAGE.md` (end-user guide)
- [x] ✅ `docs/apple-messages/DEPRECATION_TIMELINE.md` (deprecation schedule)
- [x] ✅ Deprecation warnings in code (8 scripts + 1 controller updated)

---

## ImageFetchService Detailed Design

### Core Logic

```ruby
# app/services/apple_messages_for_business/image_fetch_service.rb
module AppleMessagesForBusiness
  class ImageFetchService
    def initialize(account_id:, inbox_id:, embedded_images: [])
      @account_id = account_id
      @inbox_id = inbox_id
      @embedded_images = embedded_images || []
    end

    def fetch_and_encode(identifiers)
      return [] if identifiers.blank?

      Rails.logger.info "[ImageFetch] Looking for #{identifiers.count} images"
      Rails.logger.info "[ImageFetch] Account: #{@account_id}, Inbox: #{@inbox_id}"

      result = []

      identifiers.each do |identifier|
        image = fetch_single_image(identifier)
        result << image if image.present?
      end

      Rails.logger.info "[ImageFetch] Found #{result.count}/#{identifiers.count} images"
      result
    end

    private

    def fetch_single_image(identifier)
      # TIER 1: Check inbox-specific images first (highest priority)
      inbox_image = fetch_from_inbox(identifier)
      return inbox_image if inbox_image.present?

      # TIER 2: Check shared account-wide images
      shared_image = fetch_from_shared(identifier)
      return shared_image if shared_image.present?

      # TIER 3: Check embedded images
      embedded_image = fetch_from_embedded(identifier)
      return embedded_image if embedded_image.present?

      Rails.logger.warn "[ImageFetch] ⚠️  Image not found: #{identifier}"
      nil
    end

    def fetch_from_inbox(identifier)
      picker_image = AppleListPickerImage
                     .where(inbox_id: @inbox_id, identifier: identifier)
                     .includes(image_attachment: :blob)
                     .first

      return nil unless picker_image&.image&.attached?

      Rails.logger.info "[ImageFetch] ✅ Found in inbox #{@inbox_id}: #{identifier}"

      {
        identifier: identifier,
        data: Base64.strict_encode64(picker_image.image.download),
        description: picker_image.description || identifier,
        source: 'inbox'
      }
    rescue StandardError => e
      Rails.logger.error "[ImageFetch] Error fetching inbox image #{identifier}: #{e.message}"
      nil
    end

    def fetch_from_shared(identifier)
      shared_image = SharedAppleImage
                     .where(account_id: @account_id, identifier: identifier)
                     .includes(image_attachment: :blob)
                     .first

      return nil unless shared_image&.image&.attached?

      Rails.logger.info "[ImageFetch] ✅ Found in shared (#{shared_image.image_type}): #{identifier}"

      {
        identifier: identifier,
        data: Base64.strict_encode64(shared_image.image.download),
        description: shared_image.description || identifier,
        source: "shared_#{shared_image.image_type}"
      }
    rescue StandardError => e
      Rails.logger.error "[ImageFetch] Error fetching shared image #{identifier}: #{e.message}"
      nil
    end

    def fetch_from_embedded(identifier)
      embedded = @embedded_images.find { |img| img['identifier'] == identifier }

      return nil unless embedded && embedded['data'].present?

      Rails.logger.info "[ImageFetch] ✅ Found in embedded: #{identifier}"

      {
        identifier: identifier,
        data: embedded['data'], # Already base64
        description: embedded['description'] || identifier,
        source: 'embedded'
      }
    rescue StandardError => e
      Rails.logger.error "[ImageFetch] Error fetching embedded image #{identifier}: #{e.message}"
      nil
    end
  end
end
```

---

## Migration Strategy

### Step 1: Identify System Images

Run audit script to identify images that should be shared:

```ruby
# script/audit_system_images.rb

SYSTEM_IMAGE_PATTERNS = [
  /^messages_png$/,
  /^calendar_/,
  /^time_picker_/,
  /^apple_store_logo$/
].freeze

system_candidates = AppleListPickerImage
                    .select('identifier, COUNT(DISTINCT inbox_id) as inbox_count')
                    .group(:identifier)
                    .having('COUNT(DISTINCT inbox_id) > 1')
                    .where('identifier ~ ?', SYSTEM_IMAGE_PATTERNS.map(&:source).join('|'))
```

### Step 2: Migrate System Images

```ruby
# script/migrate_system_images_to_shared.rb

SYSTEM_IMAGES = {
  'messages_png' => { type: 'system', description: 'Messages app icon for received message' },
  'apple_store_logo' => { type: 'branding', description: 'Apple Store logo' }
  # ... add more
}.freeze

SYSTEM_IMAGES.each do |identifier, config|
  # Find a source image (prefer one with attachment)
  source = AppleListPickerImage
           .where(identifier: identifier)
           .includes(image_attachment: :blob)
           .find { |img| img.image.attached? }

  next unless source

  # Create shared image
  SharedAppleImage.create!(
    account_id: source.account_id,
    identifier: identifier,
    image_type: config[:type],
    description: config[:description],
    original_name: source.original_name,
    image: source.image.blob
  )

  puts "✅ Migrated #{identifier} to SharedAppleImage"
end
```

### Step 3: Gradual Rollout

1. **Week 1**: Deploy Phase 1 (models only)
2. **Week 2**: Deploy Phase 2 (service integration)
3. **Week 3**: Run migration scripts (system images)
4. **Week 4**: Monitor logs, verify fallback working
5. **Week 5**: Deploy API endpoints
6. **Week 6**: Deploy frontend updates
7. **Week 7**: Full documentation

---

## Testing Strategy

### Unit Tests

```ruby
# spec/services/apple_messages_for_business/image_fetch_service_spec.rb
RSpec.describe AppleMessagesForBusiness::ImageFetchService do
  describe '#fetch_and_encode' do
    context 'when image exists in inbox' do
      it 'returns inbox image (highest priority)' do
        # Test inbox-specific image found
      end
    end

    context 'when image exists in shared only' do
      it 'falls back to shared image' do
        # Test shared fallback
      end
    end

    context 'when image exists in embedded only' do
      it 'falls back to embedded image' do
        # Test embedded fallback
      end
    end

    context 'when inbox has override of shared image' do
      it 'prefers inbox override over shared' do
        # Test priority system
      end
    end
  end
end
```

### Integration Tests

```ruby
# spec/services/apple_messages_for_business/send_list_picker_service_spec.rb
RSpec.describe AppleMessagesForBusiness::SendListPickerService do
  describe 'image fetching with shared images' do
    it 'uses shared system images when inbox-specific not available' do
      # End-to-end test
    end
  end
end
```

### E2E Tests

```ruby
# spec/requests/api/v1/accounts/shared_apple_images_spec.rb
RSpec.describe 'SharedAppleImages API' do
  describe 'POST /api/v1/accounts/:account_id/shared_apple_images' do
    it 'creates shared image available to all inboxes' do
      # Test API endpoint
    end
  end
end
```

---

## Rollback Plan

If issues are discovered during rollout:

### Emergency Rollback (< 1 hour)

1. **Revert service changes**
   ```bash
   git revert <commit-hash>
   bundle exec rails db:rollback STEP=2
   ```

2. **Keep data**
   - SharedAppleImage table can remain (no harm)
   - AppleListPickerImage unchanged
   - No data loss

### Partial Rollback (Keep new models)

1. Keep SharedAppleImage model deployed
2. Revert service integration only
3. Continue using inbox-specific images
4. Fix issues, redeploy services

---

## Performance Considerations

### Query Optimization

```ruby
# Batch fetch to avoid N+1
def fetch_and_encode(identifiers)
  # Pre-load inbox images
  inbox_images = AppleListPickerImage
                 .where(inbox_id: @inbox_id, identifier: identifiers)
                 .includes(image_attachment: :blob)
                 .index_by(&:identifier)

  # Pre-load shared images
  shared_images = SharedAppleImage
                  .where(account_id: @account_id, identifier: identifiers)
                  .includes(image_attachment: :blob)
                  .index_by(&:identifier)

  # Single loop through identifiers
  identifiers.map { |id| fetch_with_caches(id, inbox_images, shared_images) }.compact
end
```

### Caching Strategy

```ruby
# Cache shared images (they rarely change)
def fetch_from_shared(identifier)
  Rails.cache.fetch("shared_image:#{@account_id}:#{identifier}", expires_in: 1.hour) do
    # Fetch and encode
  end
end
```

---

## Success Metrics

### Pre-Implementation Metrics (Baseline)

- [ ] Count of duplicate images across inboxes
- [ ] Time spent on manual image uploads
- [ ] Number of "image not found" errors in logs
- [ ] Storage usage for duplicate images

### Post-Implementation Metrics (Goals)

- [ ] 80% reduction in duplicate images
- [ ] Zero manual replication needed for system images
- [ ] 90% reduction in "image not found" errors
- [ ] 50% reduction in image storage usage

---

## Timeline

```
Week 1-2:  Phase 1 - Foundation
Week 3:    Phase 2 - Service Integration
Week 4:    Phase 3 - Migration Utilities
Week 5:    Phase 4 - API Endpoints
Week 6:    Phase 5 - Frontend Integration
Week 7:    Phase 6 - Documentation & Cleanup

Total: 7 weeks (1.75 months)
```

---

## Appendix A: Database Schema

### SharedAppleImage

```sql
CREATE TABLE shared_apple_images (
  id BIGSERIAL PRIMARY KEY,
  account_id BIGINT NOT NULL REFERENCES accounts(id),
  identifier VARCHAR NOT NULL,
  image_type VARCHAR NOT NULL DEFAULT 'system',
  description TEXT,
  original_name VARCHAR,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  CONSTRAINT unique_account_identifier UNIQUE (account_id, identifier)
);

CREATE INDEX index_shared_apple_images_on_account_id ON shared_apple_images(account_id);
CREATE INDEX index_shared_apple_images_on_image_type ON shared_apple_images(image_type);
```

### AppleListPickerImage (Modified)

```sql
ALTER TABLE apple_list_picker_images
  ADD COLUMN shared_override BOOLEAN DEFAULT false;

CREATE INDEX index_apple_list_picker_images_on_inbox_shared
  ON apple_list_picker_images(inbox_id, shared_override);
```

---

## Appendix B: Example Usage

### Upload System Image Once

```ruby
# In Rails console or script
SharedAppleImage.create!(
  account_id: 1,
  identifier: 'messages_png',
  image_type: 'system',
  description: 'Messages app icon for received message',
  original_name: 'Messages.png',
  image: File.open('path/to/Messages.png')
)
```

### Override Shared Image for Specific Inbox

```ruby
# Inbox 5 wants custom messages icon
AppleListPickerImage.create!(
  account_id: 1,
  inbox_id: 5,
  identifier: 'messages_png',
  shared_override: true,  # Indicates this overrides shared
  description: 'Custom Messages icon for Rhaps AMB inbox',
  original_name: 'CustomMessages.png',
  image: File.open('path/to/CustomMessages.png')
)
```

### Fetch with Automatic Fallback

```ruby
# Service automatically checks:
# 1. Inbox 5 custom override → Found! Use it.
# 2. (If not found) Shared system image
# 3. (If not found) Embedded image

service = AppleMessagesForBusiness::ImageFetchService.new(
  account_id: 1,
  inbox_id: 5,
  embedded_images: []
)

images = service.fetch_and_encode(['messages_png'])
# Returns inbox-specific override for inbox 5
```

---

## Sign-off

**Prepared by**: Claude Code Assistant
**Date**: 2025-01-19
**Review Required**: Engineering Lead, Product Manager
**Approval Required**: CTO, Head of Engineering

**Next Steps**:
1. Review this plan with engineering team
2. Estimate effort for each phase
3. Assign team members to phases
4. Schedule kick-off meeting
5. Begin Phase 1 implementation
