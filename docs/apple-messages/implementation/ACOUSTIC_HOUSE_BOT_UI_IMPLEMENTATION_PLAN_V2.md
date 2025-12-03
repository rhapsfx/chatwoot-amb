# Acoustic House Bot Service - UI Implementation Plan - V2.1

## Executive Summary

This document provides a revised, comprehensive implementation plan for exposing the Apple Messages for Business Acoustic House Bot Service through the Chatwoot UI. This version (V2.1) refines the original plan by **leveraging Chatwoot's existing bot infrastructure** and introducing a **Visual Bot Design Studio** to deliver a more scalable, unified, and user-friendly solution.

**Document Version**: 2.1
**Last Updated**: 2025-01-09
**Status**: Updated with current implementation details

**Key Changes in V2.1**:
- Added Phase 0: Bot Service Refactoring (prerequisite)
- Updated bot_config structure to match actual implementation
- Documented all discovered features (OAuth, Apple Maps, templates)
- Added template validation requirements
- Corrected service initialization signature
- Added idempotency and typing indicator configuration

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

### Current Bot Service Implementation

**Location**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

**Current Signature** (⚠️ Hardcoded, needs refactoring):
```ruby
def initialize(conversation, message)
  @conversation = conversation
  @message = message
  @contact = conversation.contact
  @bot_state = get_bot_state
  @lang = detect_language
end
```

**Key Features Discovered**:
1. **Required Templates** (lines 9-21):
   - `ah_guitar_list_picker` - Guitar selection list
   - `ah_guitar_info_form` - Customer information form
   - `ah_large_form_demo` - Large content form demo
   - `ah_main_menu` - Main menu list picker
   - `ah_ar_guitar` - AR guitar file
   - `ah_summary` - Summary list picker

2. **Keyword Routing** (lines 57-102):
   - Demo keywords: 'list picker', 'guitar', 'form', 'apple pay', 'ar', etc.
   - Flow control: 'menu', 'startover', 'stop', 'summary', 'skip'

3. **Interactive Handlers** (lines 104-123):
   - Quick replies: region, name preference, AR questions
   - List pickers: guitar selection, menu, store selection
   - Time pickers: lesson scheduling
   - Forms: guitar info, large content
   - Apple Pay: payment processing
   - OAuth: provider selection

4. **Apple Maps Integration** (lines 1050-1473):
   - Geocoding support
   - Store location search
   - Rich link generation for stores
   - Store selection via list picker or quick reply

5. **OAuth Integration** (lines 3666-3817):
   - LinkedIn OAuth (primary)
   - Google OAuth (disabled in current implementation)
   - Facebook OAuth (disabled in current implementation)

6. **Idempotency Guards** (lines 757-769, 1216-1228, 1629-1643):
   - Prevents duplicate processing of interactive responses
   - Uses Redis with 2-minute TTL
   - Applied to: guitar selection, time picker, menu selection, store selection

7. **Typing Indicators** (lines 51-55, 2901-3006):
   - Configurable enable/disable
   - 1.5 second delay
   - Automatic start/stop around message sends

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
8. **Config-Driven Architecture**: Refactor service to be fully configurable via `bot_config`

---

## Complete bot_config Structure

Based on the current implementation analysis, here's the complete configuration structure:

```json
{
  "conversation_flow": {
    "initial_state": "AHA1",
    "idle_timeout_minutes": 30,
    "states": {
      "AHA1": { "name": "Welcome", "handler": "handle_welcome" },
      "AHA2": { "name": "Region Selection", "handler": "handle_region_prompt" },
      "AHA3": { "name": "Form or Name Prompt", "handler": "handle_form_or_name_prompt" },
      "AHB1": { "name": "Form Response", "handler": "handle_form_response" },
      "AHB2": { "name": "Name Preference", "handler": "handle_name_preference_prompt" },
      "AHB3": { "name": "Guitar List Prompt", "handler": "handle_guitar_list_prompt" },
      "AHC1": { "name": "Guitar Selection", "handler": "handle_guitar_list_catcher" },
      "AHC2": { "name": "AR Introduction", "handler": "handle_ar_introduction" },
      "AHD1": { "name": "AR View Question", "handler": "handle_ar_view_catcher" },
      "AHE1": { "name": "AR Place Question", "handler": "handle_ar_place_catcher" },
      "AHE2": { "name": "Apple Pay Prompt", "handler": "handle_apple_pay_prompt" },
      "AHF1": { "name": "Apple Pay Catcher", "handler": "handle_apple_pay_catcher" },
      "AHF2": { "name": "Lesson Introduction", "handler": "handle_lesson_introduction" },
      "AHG1": { "name": "Location Response", "handler": "handle_location_response" },
      "AHG2": { "name": "Store Selection", "handler": "handle_store_selection" },
      "AHH1": { "name": "Time Picker", "handler": "handle_time_picker_catcher" },
      "AHH2": { "name": "Continue Prompt", "handler": "handle_continue_prompt" },
      "AHI1": { "name": "Continue Response", "handler": "handle_continue_response" },
      "AHJ1": { "name": "Photo Question", "handler": "handle_photo_response" },
      "AHJ2": { "name": "Documents Intro", "handler": "handle_documents_intro" },
      "AHJ3": { "name": "PDF Document", "handler": "handle_pdf_document" },
      "AHJ4": { "name": "Learn More Prompt", "handler": "handle_learn_more_prompt" },
      "AHK0": { "name": "Learn More Response", "handler": "handle_learn_more_response" },
      "AHK1": { "name": "Summary", "handler": "handle_summary" },
      "AHK2": { "name": "Final Message", "handler": "handle_final_message" },
      "AHK3": { "name": "Register Rich Link", "handler": "handle_register_rich_link" },
      "DEMO_MODE": { "name": "Demo Mode", "handler": "process_state" },
      "DEMO_MODE_LARGE_FORM": { "name": "Large Form Demo", "handler": "handle_large_form_response" }
    }
  },

  "keyword_mappings": {
    "demo_keywords": {
      "list picker": "handle_list_picker_demo",
      "listpicker": "handle_list_picker_demo",
      "guitar": "handle_list_picker_demo",
      "guitars": "handle_list_picker_demo",
      "time picker": "handle_time_picker_demo",
      "timepicker": "handle_time_picker_demo",
      "apple pay": "handle_apple_pay_demo",
      "payment": "handle_apple_pay_demo",
      "pay": "handle_apple_pay_demo",
      "form": "handle_form_demo",
      "help me decide": "handle_form_demo",
      "large form": "handle_large_form_demo",
      "big form": "handle_large_form_demo",
      "ar": "handle_ar_demo",
      "augmented reality": "handle_ar_demo",
      "imessage app": "handle_imessage_app",
      "imessage extension": "handle_imessage_app",
      "authentication": "handle_authentication_menu",
      "auth": "handle_authentication_menu",
      "shazam": "handle_imessage_app",
      "appclip": "handle_app_clip_demo"
    },
    "flow_control_keywords": {
      "menu": "handle_menu",
      "startover": "handle_start_over",
      "start over": "handle_start_over",
      "restart": "handle_start_over",
      "begin": "handle_start_over",
      "reset": "handle_start_over",
      "stop": "handle_stop",
      "summary": "handle_summary",
      "skip": "handle_skip_payment",
      "schedule": "handle_schedule_lesson",
      "schedule lesson": "handle_schedule_lesson",
      "lesson": "handle_schedule_lesson",
      "appointment": "handle_schedule_lesson",
      "time": "handle_schedule_lesson"
    }
  },

  "interactive_handlers": {
    "qr_travel": "handle_region_selection",
    "qr_name": "handle_name_preference_selection",
    "lp_guitar_0319": "handle_guitar_selection",
    "lp_store_selection": "handle_store_selection",
    "qr_store_selection": "handle_store_selection_qr",
    "applepay_1018": "handle_apple_pay_response",
    "qr_skip_payment": "handle_skip_payment",
    "time_0319": "handle_time_picker_response",
    "qr_view_ar": "handle_ar_view_response",
    "qr_place_ar": "handle_ar_place_response",
    "qr_continue": "handle_continue_response",
    "qr_photo": "handle_photo_response",
    "qr_learn_more": "handle_learn_more_response",
    "lp_menu_0319": "handle_menu_selection",
    "form_large_content": "handle_large_form_response",
    "act_imessage_app": "handle_imessage_app",
    "qr_oauth_provider": "handle_oauth_provider_selection"
  },

  "required_templates": {
    "list": [
      "ah_guitar_list_picker",
      "ah_guitar_info_form",
      "ah_large_form_demo",
      "ah_main_menu",
      "ah_ar_guitar",
      "ah_summary"
    ],
    "validation": {
      "enabled": true,
      "fail_on_missing": false
    }
  },

  "oauth_providers": {
    "linkedin": {
      "enabled": true,
      "default": true
    },
    "google": {
      "enabled": false
    },
    "facebook": {
      "enabled": false
    }
  },

  "apple_maps": {
    "geocoding": {
      "enabled": true,
      "fallback_location": "95014"
    },
    "search": {
      "radius_km": 10,
      "max_results": 6,
      "query": "Apple Store"
    },
    "ui_thresholds": {
      "single_store": 1,
      "quick_reply_max": 5,
      "list_picker_min": 6
    }
  },

  "location_database": {
    "95014": {
      "name": "Apple Park Visitor Center",
      "latitude": 37.332863,
      "longitude": -122.0053739,
      "timezone_offset": "-0800"
    },
    "94102": {
      "name": "Apple Union Square",
      "latitude": 37.788493,
      "longitude": -122.407074,
      "timezone_offset": "-0800"
    },
    "10019": {
      "name": "Apple Fifth Avenue",
      "latitude": 40.763829,
      "longitude": -73.972699,
      "timezone_offset": "-0500"
    },
    "10001": {
      "name": "Apple World Trade Center",
      "latitude": 40.711622,
      "longitude": -74.011765,
      "timezone_offset": "-0500"
    },
    "78701": {
      "name": "Apple Domain Northside",
      "latitude": 30.398798,
      "longitude": -97.720589,
      "timezone_offset": "-0600"
    },
    "60611": {
      "name": "Apple Michigan Avenue",
      "latitude": 41.892639,
      "longitude": -87.623734,
      "timezone_offset": "-0600"
    }
  },

  "typing_indicators": {
    "enabled": true,
    "delay_seconds": 1.5
  },

  "idempotency": {
    "enabled": true,
    "ttl_minutes": 2,
    "redis_key_prefix": "amb_bot"
  },

  "retry_logic": {
    "guitar_selection": {
      "max_retries": 5,
      "auto_select_threshold": 5,
      "auto_select_item": "Martin DC28E Dreadnought"
    },
    "time_picker": {
      "max_retries": 4,
      "skip_threshold": 4
    },
    "apple_pay": {
      "max_retries": 3,
      "reveal_demo_threshold": 3
    }
  },

  "messages": {
    "welcome": "Thank you for contacting Acoustic Bot Prod.",
    "welcome_subtitle": "Let's help you find your next guitar 🎸.",
    "demo_restart": "Type 'startover' to restart the conversation.",
    "timeout_reset": "Conversation timed out, resetting to welcome"
  },

  "features": {
    "ar_enabled": true,
    "apple_pay_enabled": true,
    "oauth_enabled": true,
    "apple_maps_enabled": true,
    "imessage_apps_enabled": true,
    "app_clips_enabled": true,
    "rich_links_enabled": true,
    "forms_enabled": true,
    "attachments_enabled": true
  }
}
```

---

## Implementation Plan

### Phase 0: Bot Service Refactoring (PREREQUISITE)

**Status**: ⚠️ Required before Phase 1

**Objective**: Transform the hardcoded `AcousticHouseBotService` into a fully config-driven service that reads all configuration from `agent_bot.bot_config`.

#### 0.1. Update Service Initialization

**Current**:
```ruby
def initialize(conversation, message)
  @conversation = conversation
  @message = message
  @contact = conversation.contact
  @bot_state = get_bot_state
  @lang = detect_language
end
```

**Target**:
```ruby
def initialize(conversation, message, bot, config = nil)
  @conversation = conversation
  @message = message
  @bot = bot
  @config = (config || bot.bot_config).with_indifferent_access
  @contact = conversation.contact
  @bot_state = get_bot_state
  @lang = detect_language

  # Validate config
  validate_config!
end

private

def validate_config!
  required_keys = %w[conversation_flow keyword_mappings interactive_handlers required_templates]
  missing_keys = required_keys - @config.keys

  if missing_keys.any?
    raise ConfigurationError, "Missing required config keys: #{missing_keys.join(', ')}"
  end
end
```

#### 0.2. Extract Hardcoded Constants to Config Methods

**Convert**:
```ruby
# FROM: Hardcoded constants
IDLE_TIMEOUT = 30.minutes
DEMO_KEYWORDS = { ... }.freeze
FLOW_CONTROL_KEYWORDS = { ... }.freeze
INTERACTIVE_HANDLERS = { ... }.freeze

# TO: Config-driven methods
def idle_timeout
  @config.dig('conversation_flow', 'idle_timeout_minutes')&.minutes || 30.minutes
end

def demo_keywords
  @config.dig('keyword_mappings', 'demo_keywords') || {}
end

def flow_control_keywords
  @config.dig('keyword_mappings', 'flow_control_keywords') || {}
end

def interactive_handlers
  @config['interactive_handlers'] || {}
end

def required_templates
  @config.dig('required_templates', 'list') || []
end

def typing_indicators_enabled?
  @config.dig('typing_indicators', 'enabled') != false
end

def typing_indicator_delay
  @config.dig('typing_indicators', 'delay_seconds') || 1.5
end
```

#### 0.3. Update All Config References

**Pattern to follow throughout service**:
```ruby
# OLD: KEYWORD_HANDLERS['guitar']
# NEW: keyword_mappings['demo_keywords']['guitar']

# OLD: INTERACTIVE_HANDLERS['qr_travel']
# NEW: interactive_handlers['qr_travel']

# OLD: REQUIRED_TEMPLATES
# NEW: required_templates
```

#### 0.4. Add Template Validation

```ruby
def validate_templates!
  return unless @config.dig('required_templates', 'validation', 'enabled')

  result = self.class.verify_templates_exist(@conversation.account_id)

  if !result[:all_present] && @config.dig('required_templates', 'validation', 'fail_on_missing')
    raise TemplateError, "Missing required templates: #{result[:missing].join(', ')}"
  end

  if result[:missing].any?
    Rails.logger.warn "[AcousticHouseBot] Missing templates: #{result[:missing].join(', ')}"
  end
end
```

#### 0.5. Update Spec File

**Update test setup**:
```ruby
# spec/services/apple_messages_for_business/acoustic_house_bot_service_spec.rb
let(:bot_config) do
  {
    conversation_flow: { initial_state: 'AHA1', idle_timeout_minutes: 30 },
    keyword_mappings: {
      demo_keywords: { 'guitar' => 'handle_list_picker_demo' },
      flow_control_keywords: { 'menu' => 'handle_menu' }
    },
    interactive_handlers: { 'qr_travel' => 'handle_region_selection' },
    required_templates: { list: [], validation: { enabled: false } }
  }
end

let(:agent_bot) do
  create(:agent_bot, bot_type: :amb, bot_config: bot_config, account: account)
end

let(:service) { described_class.new(conversation, message, agent_bot) }
```

#### 0.6. Maintain Backward Compatibility

**Add fallback mode**:
```ruby
def initialize(conversation, message, bot = nil, config = nil)
  @conversation = conversation
  @message = message

  if bot.nil?
    # Legacy mode: use hardcoded configuration
    Rails.logger.warn "[AcousticHouseBot] Running in legacy mode (hardcoded config)"
    @bot = nil
    @config = default_hardcoded_config
  else
    @bot = bot
    @config = (config || bot.bot_config).with_indifferent_access
  end

  # ... rest of initialization
end

private

def default_hardcoded_config
  {
    conversation_flow: { initial_state: 'AHA1', idle_timeout_minutes: 30 },
    # ... complete hardcoded config matching current implementation
  }
end
```

#### 0.7. Migration Tasks

**Create migration helper**:
```ruby
# lib/tasks/amb_bot.rake
namespace :amb_bot do
  desc 'Migrate hardcoded Acoustic House bot to config-driven version'
  task migrate_to_config: :environment do
    # Find all AMB bots without config
    AgentBot.where(bot_type: :amb).where("bot_config = '{}'::jsonb OR bot_config IS NULL").find_each do |bot|
      puts "Migrating bot: #{bot.name} (ID: #{bot.id})"

      bot.update!(
        bot_config: AcousticHouseBotService.default_config
      )

      puts "  ✅ Migrated successfully"
    end
  end

  desc 'Validate bot configurations'
  task validate_configs: :environment do
    AgentBot.where(bot_type: :amb).find_each do |bot|
      puts "Validating bot: #{bot.name} (ID: #{bot.id})"

      service = AppleMessagesForBusiness::AcousticHouseBotService.new(
        Conversation.new, Message.new, bot
      )

      puts "  ✅ Configuration valid"
    rescue StandardError => e
      puts "  ❌ Configuration invalid: #{e.message}"
    end
  end
end
```

**Phase 0 Deliverables**:
- [ ] Service accepts `bot` and `config` parameters
- [ ] All hardcoded constants converted to config methods
- [ ] All references updated throughout service
- [ ] Template validation implemented
- [ ] Backward compatibility maintained
- [ ] Tests updated and passing
- [ ] Migration rake tasks created
- [ ] Documentation updated

---

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

  # Associations for versioning
  has_many :versions, class_name: 'AgentBotVersion', dependent: :destroy
  has_one :active_version, -> { where(is_active: true) }, class_name: 'AgentBotVersion'

  # Scopes for AMB bots
  scope :amb_bots, -> { where(bot_type: :amb) }
  scope :webhook_bots, -> { where(bot_type: :webhook) }

  # Validations for AMB bots
  validates :bot_config, presence: true, if: :amb?
  validate :validate_amb_config, if: :amb?

  # Callbacks for automatic versioning
  after_create :create_initial_version, if: :amb?
  after_update :create_version_on_config_change, if: :should_version?

  # Method to delegate to the appropriate service
  def process_message(conversation, message, inbox = nil)
    case bot_type.to_sym
    when :amb
      config = inbox ? config_for_inbox(inbox) : bot_config
      AppleMessagesForBusiness::AcousticHouseBotService.new(conversation, message, self, config).perform
    when :webhook
      # Existing webhook logic
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

    required_keys = %w[conversation_flow keyword_mappings interactive_handlers required_templates]
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

#### 1.4. Create AgentBotVersion Model

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

#### 1.5. Enhance AgentBotInbox Model

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

#### 1.6. Seed Default AMB Bot Configuration

Create a Rake task to seed the Acoustic House template:

```ruby
# lib/tasks/bot_templates.rake
namespace :bot_templates do
  desc 'Seed pre-built AMB bot configuration'
  task seed: :environment do
    acoustic_house_config = {
      # Use the complete bot_config structure defined above
      # This would be too long to repeat here - reference the JSON above
    }

    puts "✅ Default Acoustic House bot configuration available"
    puts "Use this config when creating new AMB bots"
  end

  desc 'Create default Acoustic House bot for an account'
  task :create_default, [:account_id] => :environment do |_t, args|
    account = Account.find(args[:account_id])

    bot = account.agent_bots.create!(
      name: 'Acoustic House Demo',
      description: 'Showcase Apple Messages for Business interactive features',
      bot_type: :amb,
      bot_config: AppleMessagesForBusiness::AcousticHouseBotService.default_config
    )

    puts "✅ Created bot: #{bot.name} (ID: #{bot.id})"
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
      bot_config: {}  # Allow entire hash (validated by model)
    )
  end
end
```

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
        <p class="text-xs text-gray-500">
          {{ $t('AGENT_BOTS.FORM.BOT_CONFIG.HELP') }}
        </p>
      </div>

      <!-- Existing access token and buttons -->
    </form>
  </Dialog>
</template>
```

#### 3.2. Update Index View

Add bot type indicator and version/inbox info to the list view:

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

#### 3.3. Create Version Management Component

(Component code remains the same as in original plan - see lines 1062-1236)

#### 3.4. Create Inbox Association Manager

(Component code remains the same as in original plan - see lines 1241-1473)

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

  // Version management actions
  async getVersions({ commit }, botId) {
    const response = await AgentBotsAPI.getVersions(botId);
    return response;
  },

  async createVersion({ commit }, { botId, ...versionData }) {
    const response = await AgentBotsAPI.createVersion(botId, versionData);
    return response;
  },

  async activateVersion({ commit }, { botId, versionId }) {
    const response = await AgentBotsAPI.activateVersion(botId, versionId);
    return response;
  },

  // Inbox management actions
  async getBotInboxes({ commit }, botId) {
    const response = await AgentBotsAPI.getBotInboxes(botId);
    return response;
  },

  async bulkAssignInboxes({ commit }, { botId, inboxIds, versionId }) {
    const response = await AgentBotsAPI.bulkAssignInboxes(botId, { inboxIds, versionId });
    return response;
  },
};
```

---

### Phase 5: Internationalization

Add new translation keys:

```json
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
        "PLACEHOLDER": "Enter bot configuration as JSON",
        "HELP": "Advanced configuration for Apple Messages bot behavior"
      }
    },
    "VERSION_HISTORY": "Version History",
    "MANAGE_INBOXES": "Manage Inboxes",
    "DUPLICATE": "Duplicate Bot",
    "INBOXES": "inboxes",
    "VERSIONS": {
      "TITLE": "Bot Versions",
      "CREATE_NEW": "Save New Version",
      "CREATE_SUCCESS": "Version created successfully",
      "CREATE_ERROR": "Failed to create version",
      "ACTIVATE": "Activate This Version",
      "ACTIVATE_SUCCESS": "Version activated successfully",
      "ACTIVATE_ERROR": "Failed to activate version",
      "COMPARE": "Compare Versions",
      "ARCHIVE": "Archive Version",
      "ARCHIVE_SUCCESS": "Version archived successfully",
      "ARCHIVE_ERROR": "Failed to archive version",
      "ACTIVE": "Active",
      "CREATED_BY": "Created by",
      "LOAD_ERROR": "Failed to load versions",
      "COMPARE_ERROR": "Failed to compare versions"
    },
    "INBOX_MANAGER": {
      "TITLE": "Inbox Assignments",
      "ASSIGN_INBOXES": "Assign to Inboxes",
      "ASSIGN_DIALOG_TITLE": "Assign Bot to Inboxes",
      "SELECT_INBOXES": "Select Inboxes",
      "SELECT_VERSION": "Select Version",
      "USE_CURRENT": "Use Current Version",
      "VERSION": "Version",
      "CURRENT": "Current",
      "PRIORITY": "Priority",
      "TOGGLE_STATUS": "Toggle Status",
      "UNASSIGN": "Remove Assignment",
      "NO_INBOXES": "This bot is not assigned to any inboxes yet",
      "ASSIGN_SUCCESS": "Bot assigned to inboxes successfully",
      "ASSIGN_ERROR": "Failed to assign bot to inboxes",
      "UNASSIGN_SUCCESS": "Bot removed from inbox successfully",
      "UNASSIGN_ERROR": "Failed to remove bot from inbox",
      "VERSION_CHANGED": "Inbox version changed successfully",
      "VERSION_CHANGE_ERROR": "Failed to change inbox version",
      "STATUS_TOGGLE_ERROR": "Failed to toggle bot status",
      "LOAD_ERROR": "Failed to load inbox assignments"
    }
  }
}
```

---

## Migration Strategy

### Step 1: Phase 0 - Bot Service Refactoring
```bash
# Complete Phase 0 first
rails runner "AppleMessagesForBusiness::AcousticHouseBotService.validate_refactoring"
bundle exec rspec spec/services/apple_messages_for_business/acoustic_house_bot_service_spec.rb
```

### Step 2: Database Migration
```bash
rails db:migrate
rails bot_templates:seed
```

### Step 3: Migrate Existing Bots (if any)
```bash
rails amb_bot:migrate_to_config
rails amb_bot:validate_configs
```

### Step 4: Create First AMB Bot
1. Navigate to Settings → Agent Bots
2. Click "Add Bot"
3. Select "Apple Messages Bot" type
4. Use JSON editor to paste Acoustic House config (or use default)
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
      bot = create(:agent_bot, bot_type: :amb, bot_config: valid_config)
      conversation = create(:conversation)
      message = create(:message)

      expect(AppleMessagesForBusiness::AcousticHouseBotService)
        .to receive(:new).with(conversation, message, bot, bot.bot_config)
        .and_return(double(perform: true))

      bot.process_message(conversation, message)
    end
  end

  describe 'versioning' do
    let(:bot) { create(:agent_bot, bot_type: :amb, bot_config: valid_config) }

    it 'creates initial version on creation' do
      expect(bot.versions.count).to eq(1)
      expect(bot.versions.first.version_tag).to eq('initial')
    end

    it 'creates new version on config change' do
      expect {
        bot.update!(bot_config: updated_config)
      }.to change(bot.versions, :count).by(1)
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

  it('validates bot config JSON', () => {
    // Test implementation
  });

  it('submits correct data for AMB bot', () => {
    // Test implementation
  });
});
```

---

## Deployment Checklist

- [ ] **Phase 0 Complete**: Bot service refactored and tested
- [ ] Run database migrations
- [ ] Migrate existing bots (if any)
- [ ] Validate all bot configurations
- [ ] Update environment variables (if needed)
- [ ] Deploy backend changes
- [ ] Deploy frontend changes
- [ ] Test AMB bot creation
- [ ] Test bot assignment to inbox
- [ ] Verify message processing
- [ ] Test version management
- [ ] Test inbox association management
- [ ] Monitor error logs
- [ ] Verify template validation

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

5. **Advanced Configuration UI**
   - Form-based config editor (alternative to JSON)
   - Validation with real-time feedback
   - Config templates for common scenarios

---

## Conclusion

This V2.1 plan provides a complete, accurate implementation roadmap based on the current Acoustic House Bot Service implementation. By:

- ✅ Adding Phase 0 refactoring as prerequisite
- ✅ Documenting complete bot_config structure
- ✅ Including all discovered features (OAuth, Maps, templates)
- ✅ Providing accurate service signatures
- ✅ Maintaining backward compatibility
- ✅ Following Chatwoot's established patterns

The implementation can be done incrementally, with Phase 0 (refactoring) being essential before UI development begins.

---

## Summary of Key Features

### ✅ Complete Version History System
- Automatic versioning on config updates
- Manual snapshot creation
- Version activation/rollback
- Version comparison
- Version archiving
- Version tagging

### ✅ Flexible Inbox Association Management
- Multi-inbox assignment
- Version per inbox
- Config overrides per inbox
- Priority management
- Bulk operations
- Enable/disable per inbox

### ✅ Bot Lifecycle Management
- Rename bots
- Duplicate bots with versions
- Archive/restore bots
- Export/import configurations
- Template validation
- OAuth provider configuration
- Apple Maps integration

### ✅ Config-Driven Architecture
- All hardcoded values moved to config
- Template requirements validated
- Feature flags supported
- Typing indicators configurable
- Idempotency configurable
- Retry logic customizable
