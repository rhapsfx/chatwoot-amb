# Acoustic House Bot Service - UI Implementation Plan - V2

## Executive Summary

This document provides a revised, comprehensive implementation plan for exposing the Apple Messages for Business Acoustic House Bot Service through the Chatwoot UI. This version (V2) refines the original plan by **leveraging Chatwoot's existing bot infrastructure** and introducing a **Visual Bot Design Studio** to deliver a more scalable, unified, and user-friendly solution.

**Document Version**: 2.0  
**Last Updated**: 2025-11-24  
**Status**: Approved for Implementation

## Current Chatwoot Bot Architecture Analysis

### Existing Infrastructure

**Database Schema** (from `db/schema.rb`):
```ruby
create_table "agent_bots" do |t|
  t.string "name"
  t.string "description"
  t.string "outgoing_url"
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.bigint "account_id"
  t.integer "bot_type", default: 0        # enum: { webhook: 0 }
  t.jsonb "bot_config", default: {}       # ✅ Already exists!
  t.index ["account_id"], name: "index_agent_bots_on_account_id"
end

create_table "agent_bot_inboxes" do |t|
  t.integer "inbox_id"
  t.integer "agent_bot_id"
  t.integer "status", default: 0           # enum: { active: 0, inactive: 1 }
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.integer "account_id"
end
```

**Key Observations**:
1. ✅ `bot_config` JSONB column already exists - perfect for storing AMB configurations
2. ✅ `bot_type` enum exists but only has `webhook: 0` - we need to add `amb: 1`
3. ✅ `agent_bot_inboxes` junction table already handles bot-inbox relationships
4. ✅ Controller pattern established in `app/controllers/api/v1/accounts/agent_bots_controller.rb`
5. ✅ Frontend components exist in `app/javascript/dashboard/routes/dashboard/settings/agentBots/`

### Current Frontend Patterns

**Component Structure**:
- `Index.vue` - List view with table layout
- `AgentBotModal.vue` - Create/Edit modal using Dialog component
- Uses Vue 3 Composition API with `<script setup>`
- Uses Bricks UI components (Button, Input, TextArea, Avatar, Dialog)
- Vuex store module at `agentBots/`

**UI Patterns**:
- Settings layout with header and body sections
- Table-based list view with avatar, name, description, URL
- Modal-based create/edit forms
- Access token management built-in
- Avatar upload support

### Chatwoot's "Bricks" UI Framework

Throughout this document, references to "Bricks" or "Bricks UI components" refer to **Chatwoot's internal Vue.js component library**. This is not an external framework but rather Chatwoot's own design system and set of reusable UI elements.

**Location**: The majority of these components are located in `app/javascript/dashboard/components-next/`.

By using these components, we ensure that all new features maintain a consistent look, feel, and user experience with the rest of the Chatwoot application.
---

## Core Architectural Principles

This plan is guided by the following principles:

1. **Leverage Existing Infrastructure**: Use the existing `agent_bots` table and `bot_config` JSONB column
2. **Extend, Don't Replace**: Add AMB bot type to existing enum, don't create parallel systems
3. **Follow Chatwoot Patterns**: Match existing UI/UX patterns, component structure, and API conventions
4. **User-Centric Design**: Provide both simple form-based and advanced visual configuration options
5. **Backward Compatibility**: Ensure existing webhook bots continue to work unchanged
6. **Version Control**: Support multiple versions of bot flows with complete history tracking
7. **Flexible Association**: Allow bots to be assigned to multiple inboxes with independent configurations

---

## Key Features

### 1. **Bot Flow Versioning**
- Create multiple versions of the same bot flow
- Track complete history of all changes
- Compare versions side-by-side
- Rollback to previous versions
- Version naming and tagging

### 2. **Inbox Association Management**
- Assign bots to multiple inboxes
- Independent configuration per inbox
- Enable/disable per inbox
- Priority ordering for multiple bots
- Bulk assignment operations

### 3. **Bot Lifecycle Management**
- Rename bots
- Duplicate bots (create new version)
- Archive/delete bots
- Restore archived bots
- Export/import bot configurations

---

## Implementation Plan

### Phase 1: Backend Enhancements

#### 1.1. Add Bot Version History Table

Create a new table to track all bot configuration versions:

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_agent_bot_versions.rb
class CreateAgentBotVersions < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_bot_versions do |t|
      t.references :agent_bot, null: false, foreign_key: true, index: true
      t.references :account, null: false, foreign_key: true, index: true
      
      # Version metadata
      t.integer :version_number, null: false
      t.string :version_name
      t.text :version_description
      t.string :version_tag # e.g., 'production', 'staging', 'draft'
      
      # Snapshot of bot configuration at this version
      t.string :name, null: false
      t.text :description
      t.jsonb :bot_config, default: {}, null: false
      
      # Audit trail
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :change_summary
      t.jsonb :change_details, default: {}
      
      # Status
      t.boolean :is_active, default: false, null: false
      t.boolean :is_archived, default: false, null: false
      
      t.timestamps
    end
    
    # Ensure version numbers are unique per bot
    add_index :agent_bot_versions, [:agent_bot_id, :version_number],
              unique: true, name: 'index_bot_versions_on_bot_and_version'
    
    # Index for finding active versions
    add_index :agent_bot_versions, [:agent_bot_id, :is_active],
              name: 'index_bot_versions_on_bot_and_active'
    
    # Index for version tags
    add_index :agent_bot_versions, :version_tag
  end
end
```

#### 1.2. Enhance Agent Bot Inboxes for Per-Inbox Configuration

Add configuration overrides per inbox:

```ruby
# db/migrate/YYYYMMDDHHMMSS_enhance_agent_bot_inboxes.rb
class EnhanceAgentBotInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :agent_bot_inboxes, :priority, :integer, default: 0, null: false
    add_column :agent_bot_inboxes, :config_overrides, :jsonb, default: {}
    add_column :agent_bot_inboxes, :version_id, :bigint
    add_column :agent_bot_inboxes, :notes, :text
    
    add_foreign_key :agent_bot_inboxes, :agent_bot_versions, column: :version_id
    add_index :agent_bot_inboxes, :version_id
    add_index :agent_bot_inboxes, [:inbox_id, :priority], name: 'index_bot_inboxes_on_inbox_and_priority'
  end
end
```

#### 1.3. Extend `bot_type` Enum

Add AMB bot type to the existing enum:

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_amb_bot_type.rb
class AddAmbBotType < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL
      ALTER TYPE agent_bot_bot_type ADD VALUE IF NOT EXISTS 'amb';
    SQL
  end

  def down
    # Note: PostgreSQL doesn't support removing enum values
    # This is a one-way migration
  end
end
```

Update the model:

```ruby
# app/models/agent_bot.rb
class AgentBot < ApplicationRecord
  # ... existing code ...
  
  enum bot_type: { webhook: 0, amb: 1 }  # Add amb type
  
  # Scopes for AMB bots
  scope :amb_bots, -> { where(bot_type: :amb) }
  scope :webhook_bots, -> { where(bot_type: :webhook) }
  
  # Validations for AMB bots
  validates :bot_config, presence: true, if: :amb?
  validate :validate_amb_config, if: :amb?
  
  # Method to delegate to the appropriate service
  def process_message(conversation, message)
    case bot_type.to_sym
    when :amb
      AppleMessagesForBusiness::AcousticHouseBotService.new(conversation, message, self).perform
    when :webhook
      # Existing webhook logic
      Webhook::Trigger.new(outgoing_url, conversation, message).execute
    end
  end
  
  private
  
  def validate_amb_config
    return if bot_config.blank?
    
    required_keys = %w[conversation_flow keyword_mappings]
    missing_keys = required_keys - bot_config.keys
    
    if missing_keys.any?
      errors.add(:bot_config, "missing required keys: #{missing_keys.join(', ')}")
    end
  end
end

#### 1.4. Add Versioning Support to AgentBot Model

Enhance the AgentBot model with comprehensive versioning capabilities:

```ruby
# app/models/agent_bot.rb (Enhanced with Versioning)
class AgentBot < ApplicationRecord
  # ... existing code ...
  
  # Associations for versioning
  has_many :versions, class_name: 'AgentBotVersion', dependent: :destroy
  has_one :active_version, -> { where(is_active: true) }, class_name: 'AgentBotVersion'
  
  enum bot_type: { webhook: 0, amb: 1 }
  
  # Scopes
  scope :amb_bots, -> { where(bot_type: :amb) }
  scope :webhook_bots, -> { where(bot_type: :webhook) }
  
  # Validations
  validates :bot_config, presence: true, if: :amb?
  validate :validate_amb_config, if: :amb?
  
  # Callbacks for automatic versioning
  after_create :create_initial_version, if: :amb?
  after_update :create_version_on_config_change, if: :should_version?
  
  # Process message with inbox-specific configuration
  def process_message(conversation, message, inbox = nil)
    case bot_type.to_sym
    when :amb
      config = inbox ? config_for_inbox(inbox) : bot_config
      AppleMessagesForBusiness::AcousticHouseBotService.new(conversation, message, self, config).perform
    when :webhook
      Webhook::Trigger.new(outgoing_url, conversation, message).execute
    end
  end
  
  # Version Management Methods
  
  def create_version!(version_name: nil, description: nil, user: nil, tag: nil)
    next_version = versions.maximum(:version_number).to_i + 1
    
    versions.create!(
      account: account,
      version_number: next_version,
      version_name: version_name || "Version #{next_version}",
      version_description: description,
      version_tag: tag,
      name: name,
      description: self.description,
      bot_config: bot_config,
      created_by: user,
      is_active: false
    )
  end
  
  def activate_version!(version_id, user: nil)
    transaction do
      versions.where(is_active: true).update_all(is_active: false)
      
      version = versions.find(version_id)
      version.update!(is_active: true)
      
      update!(
        name: version.name,
        description: version.description,
        bot_config: version.bot_config
      )
      
      create_version!(
        version_name: "Activated v#{version.version_number}",
        description: "Rolled back to version #{version.version_number}",
        user: user,
        tag: 'rollback'
      )
    end
  end
  
  def config_for_inbox(inbox)
    bot_inbox = agent_bot_inboxes.find_by(inbox: inbox)
    return bot_config unless bot_inbox
    
    config = if bot_inbox.version_id
      versions.find_by(id: bot_inbox.version_id)&.bot_config || bot_config
    else
      bot_config
    end
    
    config.deep_merge(bot_inbox.config_overrides || {})
  end
  
  def duplicate!(new_name:, user: nil)
    new_bot = dup
    new_bot.name = new_name
    new_bot.save!
    
    versions.each do |version|
      new_bot.versions.create!(
        account: account,
        version_number: version.version_number,
        version_name: version.version_name,
        version_description: version.version_description,
        version_tag: version.version_tag,
        name: version.name,
        description: version.description,
        bot_config: version.bot_config,
        created_by: user,
        is_active: version.is_active
      )
    end
    
    new_bot
  end
  
  private
  
  def validate_amb_config
    return if bot_config.blank?
    
    required_keys = %w[conversation_flow keyword_mappings]
    missing_keys = required_keys - bot_config.keys
    
    if missing_keys.any?
      errors.add(:bot_config, "missing required keys: #{missing_keys.join(', ')}")
    end
  end
  
  def create_initial_version
    create_version!(
      version_name: 'Initial Version',
      description: 'Initial bot configuration',
      user: Current.user,
      tag: 'initial'
    )
  end
  
  def should_version?
    amb? && saved_change_to_bot_config?
  end
  
  def create_version_on_config_change
    create_version!(
      version_name: "Auto-save #{Time.current.strftime('%Y-%m-%d %H:%M')}",
      description: 'Automatic version created on configuration change',
      user: Current.user,
      tag: 'auto'
    )
  end
end
```

#### 1.5. Create AgentBotVersion Model

```ruby
# app/models/agent_bot_version.rb
class AgentBotVersion < ApplicationRecord
  belongs_to :agent_bot
  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :agent_bot_inboxes, foreign_key: :version_id, dependent: :nullify
  
  validates :version_number, presence: true, uniqueness: { scope: :agent_bot_id }
  validates :name, presence: true
  validates :bot_config, presence: true
  
  scope :active, -> { where(is_active: true) }
  scope :archived, -> { where(is_archived: true) }
  scope :by_tag, ->(tag) { where(version_tag: tag) }
  scope :recent, -> { order(created_at: :desc) }
  
  def activate!(user: nil)
    agent_bot.activate_version!(id, user: user)
  end
  
  def archive!
    update!(is_archived: true, is_active: false)
  end
  
  def restore!
    update!(is_archived: false)
  end
  
  def compare_with(other_version)
    {
      config_diff: HashDiff.diff(bot_config, other_version.bot_config),
      name_changed: name != other_version.name,
      description_changed: description != other_version.description
    }
  end
end
```

#### 1.6. Enhance AgentBotInbox Model

```ruby
# app/models/agent_bot_inbox.rb (Enhanced)
class AgentBotInbox < ApplicationRecord
  validates :inbox_id, presence: true
  validates :agent_bot_id, presence: true
  before_validation :ensure_account_id

  belongs_to :inbox
  belongs_to :agent_bot
  belongs_to :account
  belongs_to :version, class_name: 'AgentBotVersion', optional: true
  
  enum status: { active: 0, inactive: 1 }
  
  scope :ordered_by_priority, -> { order(priority: :desc) }
  scope :for_inbox, ->(inbox_id) { where(inbox_id: inbox_id) }
  
  def effective_config
    base_config = version&.bot_config || agent_bot.bot_config
    base_config.deep_merge(config_overrides || {})
  end
  
  def update_config_override!(key_path, value)
    overrides = config_overrides || {}
    keys = key_path.split('.')
    
    current = overrides
    keys[0..-2].each do |key|
      current[key] ||= {}
      current = current[key]
    end
    
    current[keys.last] = value
    update!(config_overrides: overrides)
  end
  
  def assign_version!(version_id)
    update!(version_id: version_id)
  end
  
  def clear_version!
    update!(version_id: nil)
  end

  private

  def ensure_account_id
    self.account_id = inbox&.account_id
  end
end
```
```

#### 1.2. Create BotTemplate Model (Optional - For Future Enhancement)

This is optional for Phase 1 but recommended for Phase 2:

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_bot_templates.rb
class CreateBotTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :bot_templates do |t|
      t.string :name, null: false
      t.text :description
      t.string :bot_type, null: false, default: 'amb'
      t.jsonb :template_config, default: {}, null: false
      t.boolean :is_prebuilt, default: false, null: false
      t.references :account, foreign_key: true, index: true
      
      t.timestamps
    end
    
    add_index :bot_templates, [:account_id, :name], unique: true, where: 'account_id IS NOT NULL'
  end
end
```

```ruby
# app/models/bot_template.rb
class BotTemplate < ApplicationRecord
  belongs_to :account, optional: true
  
  validates :name, presence: true
  validates :bot_type, presence: true, inclusion: { in: %w[amb webhook] }
  validates :template_config, presence: true
  
  scope :prebuilt, -> { where(is_prebuilt: true) }
  scope :custom, -> { where(is_prebuilt: false) }
  scope :for_account, ->(account_id) { where(account_id: [nil, account_id]) }
  
  def apply_to_bot(agent_bot)
    agent_bot.bot_config = template_config.deep_dup
    agent_bot.bot_type = bot_type
  end
end
```

#### 1.3. Update AcousticHouseBotService to be Config-Driven

Refactor the service to read from `bot.bot_config`:

```ruby
# app/services/apple_messages_for_business/acoustic_house_bot_service.rb
class AppleMessagesForBusiness::AcousticHouseBotService
  def initialize(conversation, message, bot)
    @conversation = conversation
    @message = message
    @bot = bot
    @config = bot.bot_config.with_indifferent_access
    @state = conversation.custom_attributes['bot_state'] || initial_state
  end

  def perform
    return unless should_process_message?
    
    # Use @config instead of hardcoded values
    handle_message_based_on_config
  end

  private

  def initial_state
    @config.dig('conversation_flow', 'initial_state') || 'AHA1'
  end

  def keyword_mappings
    @config['keyword_mappings'] || {}
  end

  def conversation_flow
    @config['conversation_flow'] || {}
  end

  def interactive_handlers
    @config['interactive_handlers'] || {}
  end

  # ... rest of the service logic using @config
end
```

#### 1.4. Seed Default AMB Bot Template

Create a Rake task to seed the Acoustic House template:

```ruby
# lib/tasks/bot_templates.rake
namespace :bot_templates do
  desc 'Seed pre-built AMB bot templates'
  task seed: :environment do
    acoustic_house_config = {
      conversation_flow: {
        initial_state: 'AHA1',
        states: {
          'AHA1' => { name: 'Welcome', next_state: 'AHA2' },
          'AHA2' => { name: 'Region Selection', next_state: 'AHA3' },
          'AHA3' => { name: 'Guitar Selection', next_state: 'AHA4' },
          # ... more states
        }
      },
      keyword_mappings: {
        demo_keywords: {
          'list picker' => 'handle_list_picker_demo',
          'time picker' => 'handle_time_picker_demo',
          'quick reply' => 'handle_quick_reply_demo',
          'form' => 'handle_form_demo',
          'apple pay' => 'handle_apple_pay_demo',
          'rich link' => 'handle_rich_link_demo'
        },
        flow_control_keywords: {
          'menu' => 'handle_menu',
          'startover' => 'handle_start_over',
          'help' => 'handle_help'
        }
      },
      interactive_handlers: {
        'qr_travel' => 'handle_region_selection',
        'lp_guitar_0319' => 'handle_guitar_selection',
        # ... more handlers
      },
      idle_timeout_minutes: 30,
      typing_indicators_enabled: true
    }

    BotTemplate.find_or_create_by!(name: 'Acoustic House Demo', is_prebuilt: true) do |template|
      template.description = 'Showcase Apple Messages for Business interactive features'
      template.bot_type = 'amb'
      template.template_config = acoustic_house_config
      template.account_id = nil # Global template
    end
    
    puts "✅ Seeded Acoustic House bot template"
  end
end
```

---

### Phase 2: API Enhancements

#### 2.1. Update AgentBotsController

Enhance the existing controller to support AMB bot configurations:

```ruby
# app/controllers/api/v1/accounts/agent_bots_controller.rb
class Api::V1::Accounts::AgentBotsController < Api::V1::Accounts::BaseController
  # ... existing code ...

  private

  def permitted_params
    params.permit(
      :name, 
      :description, 
      :outgoing_url, 
      :avatar, 
      :avatar_url, 
      :bot_type,
      bot_config: [
        :idle_timeout_minutes,
        :typing_indicators_enabled,
        conversation_flow: {},
        keyword_mappings: {},
        interactive_handlers: {},
        response_templates: {},
        quick_reply_configs: {},
        form_configs: {}
      ]
    )
  end
end

#### 2.2. Add Version Management Endpoints

Create nested routes for bot version management:

```ruby
# app/controllers/api/v1/accounts/agent_bots/versions_controller.rb
class Api::V1::Accounts::AgentBots::VersionsController < Api::V1::Accounts::BaseController
  before_action :set_agent_bot
  before_action :set_version, only: [:show, :activate, :archive, :restore, :compare]
  before_action :check_authorization
  
  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/versions
  def index
    @versions = @agent_bot.versions.recent.includes(:created_by)
    @versions = @versions.where(is_archived: false) unless params[:include_archived]
  end
  
  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/versions/:id
  def show
  end
  
  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/versions
  def create
    @version = @agent_bot.create_version!(
      version_name: params[:version_name],
      version_description: params[:version_description],
      version_tag: params[:version_tag],
      user: Current.user
    )
    render :show, status: :created
  end
  
  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/versions/:id/activate
  def activate
    @agent_bot.activate_version!(@version.id, user: Current.user)
    @version.reload
    render :show
  end
  
  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/versions/:id/archive
  def archive
    @version.archive!
    render :show
  end
  
  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/versions/:id/restore
  def restore
    @version.restore!
    render :show
  end
  
  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/versions/:id/compare/:other_id
  def compare
    other_version = @agent_bot.versions.find(params[:other_id])
    @comparison = @version.compare_with(other_version)
    render json: @comparison
  end
  
  private
  
  def set_agent_bot
    @agent_bot = Current.account.agent_bots.find(params[:agent_bot_id])
  end
  
  def set_version
    @version = @agent_bot.versions.find(params[:id])
  end
end
```

#### 2.3. Add Inbox Association Management Endpoints

```ruby
# app/controllers/api/v1/accounts/agent_bots/inboxes_controller.rb
class Api::V1::Accounts::AgentBots::InboxesController < Api::V1::Accounts::BaseController
  before_action :set_agent_bot
  before_action :set_bot_inbox, only: [:show, :update, :destroy, :assign_version]
  before_action :check_authorization
  
  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes
  def index
    @bot_inboxes = @agent_bot.agent_bot_inboxes
                             .includes(:inbox, :version)
                             .ordered_by_priority
  end
  
  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes/:id
  def show
  end
  
  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes
  def create
    @bot_inbox = @agent_bot.agent_bot_inboxes.create!(inbox_params)
    render :show, status: :created
  end
  
  # PATCH /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes/:id
  def update
    @bot_inbox.update!(inbox_params)
    render :show
  end
  
  # DELETE /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes/:id
  def destroy
    @bot_inbox.destroy!
    head :ok
  end
  
  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes/:id/assign_version
  def assign_version
    @bot_inbox.assign_version!(params[:version_id])
    render :show
  end
  
  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes/:id/clear_version
  def clear_version
    @bot_inbox.clear_version!
    render :show
  end
  
  # PATCH /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes/:id/config_override
  def update_config_override
    @bot_inbox.update_config_override!(
      params[:key_path],
      params[:value]
    )
    render :show
  end
  
  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes/bulk_assign
  def bulk_assign
    inbox_ids = params[:inbox_ids]
    priority = params[:priority] || 0
    version_id = params[:version_id]
    
    inbox_ids.each do |inbox_id|
      @agent_bot.agent_bot_inboxes.find_or_create_by!(inbox_id: inbox_id) do |bot_inbox|
        bot_inbox.priority = priority
        bot_inbox.version_id = version_id if version_id
        bot_inbox.status = :active
      end
    end
    
    @bot_inboxes = @agent_bot.agent_bot_inboxes.reload
    render :index
  end
  
  private
  
  def set_agent_bot
    @agent_bot = Current.account.agent_bots.find(params[:agent_bot_id])
  end
  
  def set_bot_inbox
    @bot_inbox = @agent_bot.agent_bot_inboxes.find(params[:id])
  end
  
  def inbox_params
    params.permit(:inbox_id, :status, :priority, :version_id, :notes, config_overrides: {})
  end
end
```

#### 2.4. Update Routes

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    namespace :accounts, path: 'accounts/:account_id' do
      resources :agent_bots do
        member do
          post :reset_access_token
          delete :avatar
          post :duplicate  # New: Duplicate bot
        end
        
        # Nested version management
        resources :versions, controller: 'agent_bots/versions', only: [:index, :show, :create] do
          member do
            post :activate
            post :archive
            post :restore
            get 'compare/:other_id', action: :compare
          end
        end
        
        # Nested inbox association management
        resources :inboxes, controller: 'agent_bots/inboxes' do
          member do
            post :assign_version
            post :clear_version
            patch :config_override, action: :update_config_override
          end
          collection do
            post :bulk_assign
          end
        end
      end
      
      # Optional: Bot templates
      resources :bot_templates, only: [:index, :show, :create, :update, :destroy]
    end
  end
end
```
```

#### 2.2. Create BotTemplatesController (Optional)

```ruby
# app/controllers/api/v1/accounts/bot_templates_controller.rb
class Api::V1::Accounts::BotTemplatesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  
  def index
    @templates = BotTemplate.for_account(Current.account.id)
  end
  
  def show
    @template = BotTemplate.for_account(Current.account.id).find(params[:id])
  end
  
  def create
    @template = Current.account.bot_templates.create!(permitted_params)
  end
  
  def update
    @template = Current.account.bot_templates.find(params[:id])
    @template.update!(permitted_params)
  end
  
  def destroy
    @template = Current.account.bot_templates.find(params[:id])
    @template.destroy!
    head :ok
  end
  
  private
  
  def permitted_params
    params.require(:bot_template).permit(:name, :description, :bot_type, template_config: {})
  end
end
```

#### 2.3. Add Routes

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    namespace :accounts, path: 'accounts/:account_id' do
      # Existing routes...
      resources :agent_bots do
        member do
          post :reset_access_token
          delete :avatar
        end
      end
      
      # New routes for templates (optional)
      resources :bot_templates, only: [:index, :show, :create, :update, :destroy]
    end
  end
end
```

---

### Phase 3: Frontend Implementation

#### 3.1. Update AgentBotModal Component

Enhance the existing modal to support AMB bot type:

```vue
<!-- app/javascript/dashboard/routes/dashboard/settings/agentBots/components/AgentBotModal.vue -->
<script setup>
// ... existing imports ...
import Select from 'dashboard/components-next/select/Select.vue';
import JsonEditor from 'dashboard/components/widgets/JsonEditor.vue';

// ... existing code ...

const formState = reactive({
  botName: '',
  botDescription: '',
  botType: 'webhook',  // Add bot type
  botUrl: '',
  botConfig: {},       // Add bot config
  botAvatar: null,
  botAvatarUrl: '',
});

const botTypeOptions = computed(() => [
  { value: 'webhook', label: t('AGENT_BOTS.FORM.BOT_TYPE.WEBHOOK') },
  { value: 'amb', label: t('AGENT_BOTS.FORM.BOT_TYPE.AMB') },
]);

const showWebhookUrl = computed(() => formState.botType === 'webhook');
const showBotConfig = computed(() => formState.botType === 'amb');

const handleSubmit = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  const botData = {
    name: formState.botName,
    description: formState.botDescription,
    bot_type: formState.botType,
    avatar: formState.botAvatar,
  };

  // Add type-specific fields
  if (formState.botType === 'webhook') {
    botData.outgoing_url = formState.botUrl;
  } else if (formState.botType === 'amb') {
    botData.bot_config = formState.botConfig;
  }

  // ... rest of submit logic
};
</script>

<template>
  <Dialog>
    <form @submit.prevent="handleSubmit">
      <!-- Existing avatar, name, description fields -->
      
      <!-- Bot Type Selector -->
      <Select
        v-model="formState.botType"
        :label="$t('AGENT_BOTS.FORM.BOT_TYPE.LABEL')"
        :options="botTypeOptions"
      />
      
      <!-- Webhook URL (only for webhook type) -->
      <Input
        v-if="showWebhookUrl"
        v-model="formState.botUrl"
        :label="$t('AGENT_BOTS.FORM.WEBHOOK_URL.LABEL')"
      />
      
      <!-- Bot Config (only for AMB type) -->
      <div v-if="showBotConfig" class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('AGENT_BOTS.FORM.BOT_CONFIG.LABEL') }}
        </label>
        <JsonEditor
          v-model="formState.botConfig"
          :placeholder="$t('AGENT_BOTS.FORM.BOT_CONFIG.PLACEHOLDER')"
        />
      </div>
      
      <!-- Existing access token and buttons -->
    </form>
  </Dialog>
</template>
```

#### 3.2. Update Index View

Add bot type indicator to the list view:

```vue
<!-- app/javascript/dashboard/routes/dashboard/settings/agentBots/Index.vue -->
<template>
  <SettingsLayout>
    <template #body>
      <table>
        <tbody>
          <tr v-for="bot in agentBots" :key="bot.id">
            <td>
              <div class="flex flex-row items-center gap-4">
                <Avatar :name="bot.name" :src="bot.thumbnail" />
                <div>
                  <span class="block font-medium">
                    {{ bot.name }}
                    <!-- Bot Type Badge -->
                    <span
                      class="text-xs inline-block rounded-md py-0.5 px-1 ltr:ml-1 rtl:mr-1"
                      :class="{
                        'bg-n-blue-5 text-n-slate-12': bot.bot_type === 'amb',

#### 3.3. Create Version Management Components

Add version history and management UI:

```vue
<!-- app/javascript/dashboard/routes/dashboard/settings/agentBots/components/BotVersionHistory.vue -->
<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  botId: {
    type: Number,
    required: true,
  },
});

const store = useStore();
const { t } = useI18n();

const versions = ref([]);
const selectedVersion = ref(null);
const compareVersion = ref(null);
const showCompareDialog = ref(false);
const loading = ref(false);

const activeVersion = computed(() => 
  versions.value.find(v => v.is_active)
);

const loadVersions = async () => {
  loading.value = true;
  try {
    const response = await store.dispatch('agentBots/getVersions', props.botId);
    versions.value = response.data;
  } catch (error) {
    useAlert(t('AGENT_BOTS.VERSIONS.LOAD_ERROR'));
  } finally {
    loading.value = false;
  }
};

const createVersion = async (versionData) => {
  try {
    await store.dispatch('agentBots/createVersion', {
      botId: props.botId,
      ...versionData
    });
    useAlert(t('AGENT_BOTS.VERSIONS.CREATE_SUCCESS'));
    loadVersions();
  } catch (error) {
    useAlert(t('AGENT_BOTS.VERSIONS.CREATE_ERROR'));
  }
};

const activateVersion = async (versionId) => {
  try {
    await store.dispatch('agentBots/activateVersion', {
      botId: props.botId,
      versionId
    });
    useAlert(t('AGENT_BOTS.VERSIONS.ACTIVATE_SUCCESS'));
    loadVersions();
  } catch (error) {
    useAlert(t('AGENT_BOTS.VERSIONS.ACTIVATE_ERROR'));
  }
};

const archiveVersion = async (versionId) => {
  try {
    await store.dispatch('agentBots/archiveVersion', {
      botId: props.botId,
      versionId
    });
    useAlert(t('AGENT_BOTS.VERSIONS.ARCHIVE_SUCCESS'));
    loadVersions();
  } catch (error) {
    useAlert(t('AGENT_BOTS.VERSIONS.ARCHIVE_ERROR'));
  }
};

const compareVersions = async (v1Id, v2Id) => {
  try {
    const response = await store.dispatch('agentBots/compareVersions', {
      botId: props.botId,
      versionId: v1Id,
      otherVersionId: v2Id
    });
    // Show comparison dialog
    showCompareDialog.value = true;
  } catch (error) {
    useAlert(t('AGENT_BOTS.VERSIONS.COMPARE_ERROR'));
  }
};

onMounted(() => {
  loadVersions();
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex items-center justify-between">
      <h3 class="text-lg font-semibold">{{ $t('AGENT_BOTS.VERSIONS.TITLE') }}</h3>
      <Button
        icon="i-lucide-save"
        :label="$t('AGENT_BOTS.VERSIONS.CREATE_NEW')"
        @click="createVersion({ version_name: 'Manual Save' })"
      />
    </div>

    <div class="space-y-2">
      <div
        v-for="version in versions"
        :key="version.id"
        class="flex items-center justify-between p-4 border rounded-lg"
        :class="{
          'border-blue-500 bg-blue-50': version.is_active,
          'border-gray-200': !version.is_active
        }"
      >
        <div class="flex-1">
          <div class="flex items-center gap-2">
            <span class="font-medium">{{ version.version_name }}</span>
            <span
              v-if="version.is_active"
              class="px-2 py-0.5 text-xs bg-blue-500 text-white rounded"
            >
              {{ $t('AGENT_BOTS.VERSIONS.ACTIVE') }}
            </span>
            <span
              v-if="version.version_tag"
              class="px-2 py-0.5 text-xs bg-gray-200 rounded"
            >
              {{ version.version_tag }}
            </span>
          </div>
          <p class="text-sm text-gray-600">{{ version.version_description }}</p>
          <p class="text-xs text-gray-500">
            v{{ version.version_number }} • 
            {{ $t('AGENT_BOTS.VERSIONS.CREATED_BY') }} {{ version.created_by?.name }} • 
            {{ formatDate(version.created_at) }}
          </p>
        </div>

        <div class="flex gap-2">
          <Button
            v-if="!version.is_active"
            v-tooltip.top="$t('AGENT_BOTS.VERSIONS.ACTIVATE')"
            icon="i-lucide-check-circle"
            xs
            faded
            @click="activateVersion(version.id)"
          />
          <Button
            v-tooltip.top="$t('AGENT_BOTS.VERSIONS.COMPARE')"
            icon="i-lucide-git-compare"
            xs
            faded
            @click="selectedVersion = version"
          />
          <Button
            v-if="!version.is_active && !version.is_archived"
            v-tooltip.top="$t('AGENT_BOTS.VERSIONS.ARCHIVE')"
            icon="i-lucide-archive"
            xs
            faded
            @click="archiveVersion(version.id)"
          />
        </div>
      </div>
    </div>
  </div>
</template>
```

#### 3.4. Create Inbox Association Manager

```vue
<!-- app/javascript/dashboard/routes/dashboard/settings/agentBots/components/BotInboxManager.vue -->
<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  botId: {
    type: Number,
    required: true,
  },
});

const store = useStore();
const { t } = useI18n();

const inboxes = useMapGetter('inboxes/getInboxes');
const botInboxes = ref([]);
const versions = ref([]);
const showAssignDialog = ref(false);
const selectedInboxes = ref([]);
const selectedVersion = ref(null);
const loading = ref(false);

const availableInboxes = computed(() => {
  const assignedInboxIds = botInboxes.value.map(bi => bi.inbox_id);
  return inboxes.value.filter(inbox => 
    !assignedInboxIds.includes(inbox.id) &&
    inbox.channel_type === 'Channel::AppleMessagesForBusiness'
  );
});

const versionOptions = computed(() => [
  { value: null, label: t('AGENT_BOTS.INBOX_MANAGER.USE_CURRENT') },
  ...versions.value.map(v => ({
    value: v.id,
    label: `${v.version_name} (v${v.version_number})`
  }))
]);

const loadBotInboxes = async () => {
  loading.value = true;
  try {
    const response = await store.dispatch('agentBots/getBotInboxes', props.botId);
    botInboxes.value = response.data;
  } catch (error) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.LOAD_ERROR'));
  } finally {
    loading.value = false;
  }
};

const loadVersions = async () => {
  try {
    const response = await store.dispatch('agentBots/getVersions', props.botId);
    versions.value = response.data;
  } catch (error) {
    console.error('Failed to load versions:', error);
  }
};

const assignInboxes = async () => {
  try {
    await store.dispatch('agentBots/bulkAssignInboxes', {
      botId: props.botId,
      inboxIds: selectedInboxes.value,
      versionId: selectedVersion.value
    });
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.ASSIGN_SUCCESS'));
    showAssignDialog.value = false;
    selectedInboxes.value = [];
    selectedVersion.value = null;
    loadBotInboxes();
  } catch (error) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.ASSIGN_ERROR'));
  }
};

const unassignInbox = async (botInboxId) => {
  try {
    await store.dispatch('agentBots/unassignInbox', {
      botId: props.botId,
      botInboxId
    });
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.UNASSIGN_SUCCESS'));
    loadBotInboxes();
  } catch (error) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.UNASSIGN_ERROR'));
  }
};

const changeVersion = async (botInboxId, versionId) => {
  try {
    await store.dispatch('agentBots/assignInboxVersion', {
      botId: props.botId,
      botInboxId,
      versionId
    });
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.VERSION_CHANGED'));
    loadBotInboxes();
  } catch (error) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.VERSION_CHANGE_ERROR'));
  }
};

const toggleStatus = async (botInboxId, currentStatus) => {
  try {
    await store.dispatch('agentBots/updateBotInbox', {
      botId: props.botId,
      botInboxId,
      status: currentStatus === 'active' ? 'inactive' : 'active'
    });
    loadBotInboxes();
  } catch (error) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.STATUS_TOGGLE_ERROR'));
  }
};

onMounted(() => {
  loadBotInboxes();
  loadVersions();
  store.dispatch('inboxes/get');
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex items-center justify-between">
      <h3 class="text-lg font-semibold">
        {{ $t('AGENT_BOTS.INBOX_MANAGER.TITLE') }}
      </h3>
      <Button
        icon="i-lucide-plus"
        :label="$t('AGENT_BOTS.INBOX_MANAGER.ASSIGN_INBOXES')"
        :disabled="!availableInboxes.length"
        @click="showAssignDialog = true"
      />
    </div>

    <div class="space-y-2">
      <div
        v-for="botInbox in botInboxes"
        :key="botInbox.id"
        class="flex items-center justify-between p-4 border rounded-lg"
      >
        <div class="flex-1">
          <div class="flex items-center gap-2">
            <span class="font-medium">{{ botInbox.inbox.name }}</span>
            <span
              class="px-2 py-0.5 text-xs rounded"
              :class="{
                'bg-green-100 text-green-800': botInbox.status === 'active',
                'bg-gray-100 text-gray-800': botInbox.status === 'inactive'
              }"
            >
              {{ botInbox.status }}
            </span>
          </div>
          <p class="text-sm text-gray-600">
            {{ $t('AGENT_BOTS.INBOX_MANAGER.VERSION') }}: 
            {{ botInbox.version?.version_name || $t('AGENT_BOTS.INBOX_MANAGER.CURRENT') }}
          </p>
          <p class="text-xs text-gray-500">
            {{ $t('AGENT_BOTS.INBOX_MANAGER.PRIORITY') }}: {{ botInbox.priority }}
          </p>
        </div>

        <div class="flex gap-2">
          <Select
            :model-value="botInbox.version_id"
            :options="versionOptions"
            size="sm"
            @update:model-value="changeVersion(botInbox.id, $event)"
          />
          <Button
            v-tooltip.top="$t('AGENT_BOTS.INBOX_MANAGER.TOGGLE_STATUS')"
            :icon="botInbox.status === 'active' ? 'i-lucide-pause' : 'i-lucide-play'"
            xs
            faded
            @click="toggleStatus(botInbox.id, botInbox.status)"
          />
          <Button
            v-tooltip.top="$t('AGENT_BOTS.INBOX_MANAGER.UNASSIGN')"
            icon="i-lucide-x"
            xs
            ruby
            faded
            @click="unassignInbox(botInbox.id)"
          />
        </div>
      </div>

      <div v-if="!botInboxes.length" class="text-center py-8 text-gray-500">
        {{ $t('AGENT_BOTS.INBOX_MANAGER.NO_INBOXES') }}
      </div>
    </div>

    <!-- Assign Inboxes Dialog -->
    <Dialog
      v-model="showAssignDialog"
      :title="$t('AGENT_BOTS.INBOX_MANAGER.ASSIGN_DIALOG_TITLE')"
      @confirm="assignInboxes"
    >
      <div class="flex flex-col gap-4">
        <div>
          <label class="block text-sm font-medium mb-2">
            {{ $t('AGENT_BOTS.INBOX_MANAGER.SELECT_INBOXES') }}
          </label>
          <Select
            v-model="selectedInboxes"
            :options="availableInboxes.map(i => ({ value: i.id, label: i.name }))"
            multiple
          />
        </div>

        <div>
          <label class="block text-sm font-medium mb-2">
            {{ $t('AGENT_BOTS.INBOX_MANAGER.SELECT_VERSION') }}
          </label>
          <Select
            v-model="selectedVersion"
            :options="versionOptions"
          />
        </div>
      </div>
    </Dialog>
  </div>
</template>
```

#### 3.5. Update Main Bot Index to Show Version and Inbox Info

```vue
<!-- app/javascript/dashboard/routes/dashboard/settings/agentBots/Index.vue (Enhanced) -->
<template>
  <SettingsLayout>
    <template #body>
      <table>
        <tbody>
          <tr v-for="bot in agentBots" :key="bot.id">
            <td>
              <div class="flex flex-row items-center gap-4">
                <Avatar :name="bot.name" :src="bot.thumbnail" />
                <div>
                  <span class="block font-medium">
                    {{ bot.name }}
                    <!-- Bot Type Badge -->
                    <span
                      class="text-xs inline-block rounded-md py-0.5 px-1 ltr:ml-1 rtl:mr-1"
                      :class="{
                        'bg-n-blue-5 text-n-slate-12': bot.bot_type === 'amb',
                        'bg-n-slate-5 text-n-slate-11': bot.bot_type === 'webhook'
                      }"
                    >
                      {{ bot.bot_type === 'amb' ? 'AMB' : 'Webhook' }}
                    </span>
                  </span>
                  <span class="text-sm text-n-slate-11">
                    {{ bot.description }}
                  </span>
                  <!-- Version and Inbox Info -->
                  <div v-if="bot.bot_type === 'amb'" class="flex gap-2 mt-1 text-xs text-gray-500">
                    <span v-if="bot.active_version">
                      📌 v{{ bot.active_version.version_number }}
                    </span>
                    <span v-if="bot.inbox_count">
                      📥 {{ bot.inbox_count }} {{ $t('AGENT_BOTS.INBOXES') }}
                    </span>
                  </div>
                </div>
              </div>
            </td>
            <td>
              <!-- Actions including Version History and Inbox Management -->
              <div class="flex gap-1 justify-end">
                <Button
                  v-if="bot.bot_type === 'amb'"
                  v-tooltip.top="$t('AGENT_BOTS.VERSION_HISTORY')"
                  icon="i-lucide-history"
                  xs
                  faded
                  @click="openVersionHistory(bot)"
                />
                <Button
                  v-if="bot.bot_type === 'amb'"
                  v-tooltip.top="$t('AGENT_BOTS.MANAGE_INBOXES')"
                  icon="i-lucide-inbox"
                  xs
                  faded
                  @click="openInboxManager(bot)"
                />
                <Button
                  v-if="!bot.system_bot"
                  v-tooltip.top="$t('AGENT_BOTS.DUPLICATE')"
                  icon="i-lucide-copy"
                  xs
                  faded
                  @click="duplicateBot(bot)"
                />
                <!-- Existing edit and delete buttons -->
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </template>
  </SettingsLayout>
</template>
```
                        'bg-n-slate-5 text-n-slate-11': bot.bot_type === 'webhook'
                      }"
                    >
                      {{ bot.bot_type === 'amb' ? 'AMB' : 'Webhook' }}
                    </span>
                  </span>
                  <span class="text-sm text-n-slate-11">
                    {{ bot.description }}
                  </span>
                </div>
              </div>
            </td>
            <!-- ... rest of table -->
          </tr>
        </tbody>
      </table>
    </template>
  </SettingsLayout>
</template>
```

#### 3.3. Create Bot Design Studio (Phase 2 - Advanced Feature)

For Phase 2, create a visual bot designer:

```vue
<!-- app/javascript/dashboard/routes/dashboard/settings/agentBots/components/BotDesignStudio.vue -->
<script setup>
import { ref, computed } from 'vue';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import '@vue-flow/core/dist/style.css';

const props = defineProps({
  botConfig: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['update:botConfig']);

const nodes = ref([]);
const edges = ref([]);

// Convert bot_config to visual nodes
const initializeFlow = () => {
  // Transform conversation_flow into visual nodes
  const flow = props.botConfig.conversation_flow || {};
  // ... conversion logic
};

// Convert visual nodes back to bot_config
const exportConfig = () => {
  const config = {
    conversation_flow: {},
    keyword_mappings: {},
    // ... build from nodes/edges
  };
  emit('update:botConfig', config);
};
</script>

<template>
  <div class="h-screen">
    <VueFlow
      v-model:nodes="nodes"
      v-model:edges="edges"
      @nodes-change="exportConfig"
      @edges-change="exportConfig"
    >
      <!-- Custom node types for different bot actions -->
    </VueFlow>
  </div>
</template>
```

---

### Phase 4: Vuex Store Updates

Update the existing agentBots store module:

```javascript
// app/javascript/dashboard/store/modules/agentBots.js
export const actions = {
  // ... existing actions ...
  
  async create({ commit }, botData) {
    try {
      const response = await AgentBotsAPI.create(botData);
      commit(types.ADD_AGENT_BOT, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    }
  },
  
  async update({ commit }, { id, data }) {
    try {
      const response = await AgentBotsAPI.update(id, data);
      commit(types.EDIT_AGENT_BOT, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    }
  },
};
```

---

### Phase 5: Internationalization

Add new translation keys:

```javascript
// app/javascript/dashboard/i18n/locale/en/agentBots.json
{
  "AGENT_BOTS": {
    "FORM": {
      "BOT_TYPE": {
        "LABEL": "Bot Type",
        "WEBHOOK": "Webhook Bot",
        "AMB": "Apple Messages Bot"
      },
      "BOT_CONFIG": {
        "LABEL": "Bot Configuration",
        "PLACEHOLDER": "Enter bot configuration as JSON"
      }
    }
  }
}
```

---

## Migration Strategy

### Step 1: Database Migration
```bash
rails db:migrate
rake bot_templates:seed
```

### Step 2: Update Existing Bots
No changes needed - existing webhook bots continue to work as-is.

### Step 3: Create First AMB Bot
1. Navigate to Settings → Agent Bots
2. Click "Add Bot"
3. Select "Apple Messages Bot" type
4. Either:
   - Use JSON editor to paste Acoustic House config
   - Or use Bot Design Studio (Phase 2)
5. Assign to AMB inbox

---

## Testing Strategy

### Backend Tests

```ruby
# spec/models/agent_bot_spec.rb
RSpec.describe AgentBot, type: :model do
  describe 'validations' do
    context 'when bot_type is amb' do
      it 'requires bot_config' do
        bot = build(:agent_bot, bot_type: :amb, bot_config: nil)
        expect(bot).not_to be_valid
      end
      
      it 'validates bot_config structure' do
        bot = build(:agent_bot, bot_type: :amb, bot_config: {})
        expect(bot).not_to be_valid
        expect(bot.errors[:bot_config]).to include(/missing required keys/)
      end
    end
  end
  
  describe '#process_message' do
    it 'delegates to AcousticHouseBotService for AMB bots' do
      bot = create(:agent_bot, bot_type: :amb)
      expect(AppleMessagesForBusiness::AcousticHouseBotService)
        .to receive_message_chain(:new, :perform)
      
      bot.process_message(conversation, message)
    end
  end
end
```

### Frontend Tests

```javascript
// spec/javascript/dashboard/routes/dashboard/settings/agentBots/AgentBotModal.spec.js
describe('AgentBotModal', () => {
  it('shows webhook URL field for webhook type', () => {
    // Test implementation
  });
  
  it('shows bot config editor for AMB type', () => {
    // Test implementation
  });
  
  it('submits correct data for AMB bot', () => {
    // Test implementation
  });
});
```

---

## Deployment Checklist

- [ ] Run database migrations
- [ ] Seed bot templates
- [ ] Update environment variables (if needed)
- [ ] Deploy backend changes
- [ ] Deploy frontend changes
- [ ] Test AMB bot creation
- [ ] Test bot assignment to inbox
- [ ] Verify message processing
- [ ] Monitor error logs

---

## Future Enhancements (Phase 2+)

1. **Visual Bot Design Studio**
   - Drag-and-drop flow builder
   - Live preview
   - Template library

2. **Bot Analytics**
   - Conversation flow analytics
   - Drop-off points
   - Popular paths

3. **A/B Testing**
   - Test different flows
   - Compare performance
   - Auto-optimize

4. **Bot Marketplace**
   - Share templates
   - Community bots
   - Pre-built integrations

---

## Conclusion

This V2 plan leverages Chatwoot's existing infrastructure while adding powerful AMB bot capabilities. By extending the current `AgentBot` model and following established patterns, we can deliver a robust solution that:

- ✅ Integrates seamlessly with existing code
- ✅ Maintains backward compatibility
- ✅ Follows Chatwoot's UI/UX patterns
- ✅ Provides both simple and advanced configuration options
- ✅ Sets foundation for future enhancements

The implementation can be done incrementally, starting with basic JSON configuration and evolving to a visual designer in Phase 2.

---

## Summary of Version Control & Inbox Management Features

### ✅ Complete Version History System

**Database Layer:**
- `agent_bot_versions` table tracks every configuration change
- Automatic versioning on config updates
- Version metadata (name, description, tags)
- Audit trail with user tracking

**Key Features:**
1. **Automatic Versioning**: Every bot config change creates a new version
2. **Manual Snapshots**: Users can create named versions at any time
3. **Version Activation**: Rollback to any previous version with one click
4. **Version Comparison**: Side-by-side diff of any two versions
5. **Version Archiving**: Archive old versions without deleting
6. **Version Tags**: Tag versions as 'production', 'staging', 'draft', etc.

### ✅ Flexible Inbox Association Management

**Database Layer:**
- Enhanced `agent_bot_inboxes` with version assignment
- Per-inbox configuration overrides
- Priority ordering for multiple bots

**Key Features:**
1. **Multi-Inbox Assignment**: Assign one bot to multiple inboxes
2. **Version Per Inbox**: Each inbox can use a different bot version
3. **Config Overrides**: Override specific settings per inbox
4. **Priority Management**: Control bot execution order
5. **Bulk Operations**: Assign bot to multiple inboxes at once
6. **Enable/Disable**: Toggle bot per inbox without unassigning

### ✅ Bot Lifecycle Management

**Operations Supported:**
1. **Rename**: Change bot name while preserving history
2. **Duplicate**: Create a copy with all versions
3. **Archive**: Soft delete with restore capability
4. **Export/Import**: Share configurations between accounts
5. **Version Rollback**: Restore any previous configuration
6. **Inbox Reassignment**: Move bots between inboxes easily

### 🎯 User Workflows

#### Creating a New Bot Version
```
1. User edits bot configuration
2. System automatically creates version
3. User can add name/description
4. Version appears in history
```

#### Rolling Back to Previous Version
```
1. User opens version history
2. Selects previous version
3. Clicks "Activate"
4. Bot immediately uses old config
5. New version created for rollback
```

#### Assigning Bot to Multiple Inboxes
```
1. User opens inbox manager
2. Selects multiple inboxes
3. Optionally selects specific version
4. Clicks "Assign"
5. Bot active on all selected inboxes
```

#### Using Different Versions Per Inbox
```
1. Inbox A uses v1 (stable)
2. Inbox B uses v2 (testing)
3. Inbox C uses v3 (experimental)
4. All from same bot, different configs
```

---
