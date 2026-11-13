
# Acoustic House Bot Service - UI Implementation Plan

## Executive Summary

This document provides a comprehensive implementation plan for exposing the Apple Messages for Business Acoustic House Bot Service through the Chatwoot UI with full CRUD capabilities. Currently, the bot service (`app/services/apple_messages_for_business/acoustic_house_bot_service.rb`) operates programmatically via code and command-line scripts, lacking any visual representation or management interface.

**Document Version**: 1.0
**Last Updated**: 2025-11-18
**Status**: Implementation Ready

## Current State Analysis

### Existing Bot Service Architecture

**Service Location**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

**Key Features**:
- State machine-based conversation flow (AHA1 → AHK3 states)
- Interactive message handling (Quick Replies, List Pickers, Time Pickers, Forms, Apple Pay)
- Keyword-based routing (demo keywords + flow control keywords)
- Typing indicators and rich media support
- Bot state persistence in conversation custom_attributes
- 30-minute idle timeout with automatic reset

**Current Limitations**:
- No UI for bot configuration
- Bot behavior hardcoded in service class
- No visual representation of bot instances
- Configuration changes require code modifications
- No audit trail for bot changes
- Difficult to manage multiple bot configurations

### Existing Infrastructure

**Database Models**:
- `AgentBot` - Generic bot model with webhook support
- `AgentBotInbox` - Junction table linking bots to inboxes
- `Channel::AppleMessagesForBusiness` - AMB channel model
- `Inbox` - Inbox model with channel association

**API Patterns**:
- RESTful controllers in `app/controllers/api/v1/accounts/`
- Authorization via Pundit policies
- JSON API responses with jbuilder views

---

## Implementation Plan

### Phase 1: Database Schema Design

#### 1.1 New Table: `apple_messages_bots`

Create a dedicated table for Apple Messages bot configurations:

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_apple_messages_bots.rb
class CreateAppleMessagesBots < ActiveRecord::Migration[7.0]
  def change
    create_table :apple_messages_bots do |t|
      # Basic Information
      t.string :name, null: false, limit: 255
      t.text :description
      t.boolean :enabled, default: true, null: false
      
      # Bot Type & Configuration
      t.string :bot_type, default: 'acoustic_house', null: false
      t.jsonb :bot_config, default: {}, null: false
      
      # Flow Configuration
      t.jsonb :conversation_flow, default: {}, null: false
      t.jsonb :keyword_mappings, default: {}, null: false
      t.jsonb :interactive_handlers, default: {}, null: false
      
      # Behavior Settings
      t.integer :idle_timeout_minutes, default: 30, null: false
      t.boolean :typing_indicators_enabled, default: true, null: false
      t.float :typing_indicator_delay, default: 1.5, null: false
      
      # Template & Response Configuration
      t.jsonb :response_templates, default: {}, null: false
      t.jsonb :quick_reply_configs, default: {}, null: false
      t.jsonb :form_configs, default: {}, null: false
      
      # Webhook Configuration
      t.string :webhook_url, limit: 2048
      t.jsonb :webhook_config, default: {}, null: false
      
      # Multi-tenancy
      t.references :account, null: false, foreign_key: true, index: true
      
      # Audit Fields
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :updated_by, foreign_key: { to_table: :users }
      
      t.timestamps
      
      # Soft delete support
      t.datetime :deleted_at
    end
    
    add_index :apple_messages_bots, [:account_id, :name], unique: true, where: 'deleted_at IS NULL'
    add_index :apple_messages_bots, :deleted_at
    add_index :apple_messages_bots, :bot_type
    add_index :apple_messages_bots, :enabled
  end
end
```

#### 1.2 Junction Table: `apple_messages_bot_inboxes`

Link bots to specific inboxes:

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_apple_messages_bot_inboxes.rb
class CreateAppleMessagesBotInboxes < ActiveRecord::Migration[7.0]
  def change
    create_table :apple_messages_bot_inboxes do |t|
      t.references :apple_messages_bot, null: false, foreign_key: true, index: true
      t.references :inbox, null: false, foreign_key: true, index: true
      
      # Bot-specific inbox configuration
      t.boolean :enabled, default: true, null: false
      t.jsonb :inbox_specific_config, default: {}, null: false
      
      # Priority for multiple bots on same inbox
      t.integer :priority, default: 0, null: false
      
      t.timestamps
    end
    
    add_index :apple_messages_bot_inboxes, [:inbox_id, :apple_messages_bot_id], 
              unique: true, name: 'index_amb_bot_inboxes_on_inbox_and_bot'
    add_index :apple_messages_bot_inboxes, :enabled
  end
end
```

#### 1.3 Audit Trail Table: `apple_messages_bot_audit_logs`

Track all configuration changes:

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_apple_messages_bot_audit_logs.rb
class CreateAppleMessagesBotAuditLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :apple_messages_bot_audit_logs do |t|
      t.references :apple_messages_bot, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true
      
      t.string :action, null: false # created, updated, deleted, enabled, disabled
      t.jsonb :changes, default: {}, null: false
      t.jsonb :metadata, default: {}, null: false
      t.inet :ip_address
      t.string :user_agent
      
      t.timestamp :created_at, null: false
    end
    
    add_index :apple_messages_bot_audit_logs, :action
    add_index :apple_messages_bot_audit_logs, :created_at
  end
end
```

---

### Phase 2: ActiveRecord Models

#### 2.1 AppleMessagesBot Model

```ruby
# app/models/apple_messages_bot.rb
# == Schema Information
#
# Table name: apple_messages_bots
#
#  id                          :bigint           not null, primary key
#  name                        :string(255)      not null
#  description                 :text
#  enabled                     :boolean          default(TRUE), not null
#  bot_type                    :string           default("acoustic_house"), not null
#  bot_config                  :jsonb            default({}), not null
#  conversation_flow           :jsonb            default({}), not null
#  keyword_mappings            :jsonb            default({}), not null
#  interactive_handlers        :jsonb            default({}), not null
#  idle_timeout_minutes        :integer          default(30), not null
#  typing_indicators_enabled   :boolean          default(TRUE), not null
#  typing_indicator_delay      :float            default(1.5), not null
#  response_templates          :jsonb            default({}), not null
#  quick_reply_configs         :jsonb            default({}), not null
#  form_configs                :jsonb            default({}), not null
#  webhook_url                 :string(2048)
#  webhook_config              :jsonb            default({}), not null
#  account_id                  :bigint           not null
#  created_by_id               :bigint
#  updated_by_id               :bigint
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  deleted_at                  :datetime
#

class AppleMessagesBot < ApplicationRecord
  include Auditable
  
  # Associations
  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true
  
  has_many :apple_messages_bot_inboxes, dependent: :destroy
  has_many :inboxes, through: :apple_messages_bot_inboxes
  has_many :audit_logs, class_name: 'AppleMessagesBotAuditLog', dependent: :destroy
  
  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  scope :active, -> { where(deleted_at: nil) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  
  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :account_id, conditions: -> { where(deleted_at: nil) } }
  validates :bot_type, presence: true, inclusion: { in: %w[acoustic_house custom webhook] }
  validates :idle_timeout_minutes, numericality: { greater_than: 0, less_than_or_equal_to: 1440 }
  validates :typing_indicator_delay, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }
  validates :webhook_url, url: true, allow_blank: true, length: { maximum: 2048 }
  
  validate :validate_conversation_flow_structure
  validate :validate_keyword_mappings_structure
  validate :validate_response_templates_structure
  
  # Callbacks
  before_validation :set_defaults, on: :create
  after_create :log_creation
  after_update :log_update
  before_destroy :log_deletion
  
  # Soft delete
  def soft_delete
    update(deleted_at: Time.current, enabled: false)
  end
  
  def restore
    update(deleted_at: nil)
  end
  
  # Bot instance methods
  def process_message(conversation, message)
    service_class.new(conversation, message, self).process_message
  end
  
  def service_class
    case bot_type
    when 'acoustic_house'
      AppleMessagesForBusiness::AcousticHouseBotService
    when 'custom'
      AppleMessagesForBusiness::CustomBotService
    when 'webhook'
      AppleMessagesForBusiness::WebhookBotService
    else
      raise "Unknown bot type: #{bot_type}"
    end
  end
  
  def active_inbox_count
    apple_messages_bot_inboxes.where(enabled: true).count
  end
  
  def export_configuration
    {
      name: name,
      description: description,
      bot_type: bot_type,
      bot_config: bot_config,
      conversation_flow: conversation_flow,
      keyword_mappings: keyword_mappings,
      interactive_handlers: interactive_handlers,
      idle_timeout_minutes: idle_timeout_minutes,
      typing_indicators_enabled: typing_indicators_enabled,
      typing_indicator_delay: typing_indicator_delay,
      response_templates: response_templates,
      quick_reply_configs: quick_reply_configs,
      form_configs: form_configs,
      webhook_url: webhook_url,
      webhook_config: webhook_config
    }
  end
  
  def import_configuration(config_hash)
    update(config_hash.slice(
      :description, :bot_config, :conversation_flow, :keyword_mappings,
      :interactive_handlers, :idle_timeout_minutes, :typing_indicators_enabled,
      :typing_indicator_delay, :response_templates, :quick_reply_configs,
      :form_configs, :webhook_url, :webhook_config
    ))
  end
  
  private
  
  def set_defaults
    self.conversation_flow ||= default_conversation_flow
    self.keyword_mappings ||= default_keyword_mappings
    self.interactive_handlers ||= default_interactive_handlers
  end
  
  def default_conversation_flow
    # Load default Acoustic House flow structure
    {
      states: {
        'AHA1' => { name: 'Welcome', next_state: 'AHA2' },
        'AHA2' => { name: 'Region Selection', next_state: 'AHA3' },
        # ... more states
      }
    }
  end
  
  def default_keyword_mappings
    {
      demo_keywords: {
        'list picker' => 'handle_list_picker_demo',
        'time picker' => 'handle_time_picker_demo',
        # ... more keywords
      },
      flow_control_keywords: {
        'menu' => 'handle_menu',
        'startover' => 'handle_start_over',
        # ... more keywords
      }
    }
  end
  
  def default_interactive_handlers
    {
      'qr_travel' => 'handle_region_selection',
      'lp_guitar_0319' => 'handle_guitar_selection',
      # ... more handlers
    }
  end
  
  def validate_conversation_flow_structure
    return if conversation_flow.blank?
    
    unless conversation_flow.is_a?(Hash) && conversation_flow['states'].is_a?(Hash)
      errors.add(:conversation_flow, 'must have a valid states structure')
    end
  end
  
  def validate_keyword_mappings_structure
    return if keyword_mappings.blank?
    
    unless keyword_mappings.is_a?(Hash)
      errors.add(:keyword_mappings, 'must be a valid hash')
    end
  end
  
  def validate_response_templates_structure
    return if response_templates.blank?
    
    unless response_templates.is_a?(Hash)
      errors.add(:response_templates, 'must be a valid hash')
    end
  end
  
  def log_creation
    audit_logs.create!(
      user: created_by,
      action: 'created',
      changes: attributes.except('id', 'created_at', 'updated_at'),
      metadata: { source: 'ui' }
    )
  end
  
  def log_update
    return unless saved_changes.any?
    
    audit_logs.create!(
      user: updated_by || Current.user,
      action: 'updated',
      changes: saved_changes,
      metadata: { source: 'ui' }
    )
  end
  
  def log_deletion
    audit_logs.create!(
      user: Current.user,
      action: 'deleted',
      changes: {},
      metadata: { source: 'ui' }
    )
  end
end
```

#### 2.2 AppleMessagesBotInbox Model

```ruby
# app/models/apple_messages_bot_inbox.rb
class AppleMessagesBotInbox < ApplicationRecord
  # Associations
  belongs_to :apple_messages_bot
  belongs_to :inbox
  
  # Validations
  validates :inbox_id, uniqueness: { scope: :apple_messages_bot_id }
  validates :priority, numericality: { greater_than_or_equal_to: 0 }
  
  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :ordered_by_priority, -> { order(priority: :desc) }
  
  # Callbacks
  after_create :notify_bot_assignment
  after_destroy :notify_bot_removal
  
  def toggle_enabled!
    update!(enabled: !enabled)
  end
  
  private
  
  def notify_bot_assignment
    # Trigger webhook or notification
    Rails.logger.info "[Bot Assignment] Bot #{apple_messages_bot.name} assigned to Inbox #{inbox.name}"
  end
  
  def notify_bot_removal
    Rails.logger.info "[Bot Removal] Bot #{apple_messages_bot.name} removed from Inbox #{inbox.name}"
  end
end
```

#### 2.3 AppleMessagesBotAuditLog Model

```ruby
# app/models/apple_messages_bot_audit_log.rb
class AppleMessagesBotAuditLog < ApplicationRecord
  # Associations
  belongs_to :apple_messages_bot
  belongs_to :user
  
  # Validations
  validates :action, presence: true, inclusion: { 
    in: %w[created updated deleted enabled disabled inbox_assigned inbox_removed] 
  }
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_bot, ->(bot_id) { where(apple_messages_bot_id: bot_id) }
  scope :by_action, ->(action) { where(action: action) }
  
  def formatted_changes
    changes.map do |key, value|
      if value.is_a?(Array) && value.length == 2
        "#{key}: #{value[0]} → #{value[1]}"
      else
        "#{key}: #{value}"
      end
    end.join(', ')
  end
end
```

---

### Phase 3: API Controllers

#### 3.1 Main Bot Controller

```ruby
# app/controllers/api/v1/accounts/apple_messages_bots_controller.rb
class Api::V1::Accounts::AppleMessagesBotsController < Api::V1::Accounts::BaseController
  before_action :set_bot, only: [:show, :update, :destroy, :enable, :disable, :export, :test]
  before_action :check_authorization
  
  # GET /api/v1/accounts/:account_id/apple_messages_bots
  def index
    @bots = Current.account.apple_messages_bots.active.includes(:inboxes, :created_by)
    @bots = @bots.enabled if params[:enabled] == 'true'
    @bots = @bots.disabled if params[:enabled] == 'false'
  end
  
  # GET /api/v1/accounts/:account_id/apple_messages_bots/:id
  def show
    @audit_logs = @bot.audit_logs.recent.limit(50).includes(:user) if params[:include_audit_logs]
  end
  
  # POST /api/v1/accounts/:account_id/apple_messages_bots
  def create
    @bot = Current.account.apple_messages_bots.new(bot_params)
    @bot.created_by = Current.user
    @bot.updated_by = Current.user
    
    if @bot.save
      track_event('bot_created', bot_id: @bot.id, bot_type: @bot.bot_type)
      render :show, status: :created
    else
      render json: { errors: @bot.errors }, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/v1/accounts/:account_id/apple_messages_bots/:id
  def update
    @bot.updated_by = Current.user
    
    if @bot.update(bot_params)
      track_event('bot_updated', bot_id: @bot.id, changes: @bot.saved_changes.keys)
      render :show
    else
      render json: { errors: @bot.errors }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/v1/accounts/:account_id/apple_messages_bots/:id
  def destroy
    if @bot.soft_delete
      track_event('bot_deleted', bot_id: @bot.id)
      head :no_content
    else
      render json: { errors: @bot.errors }, status: :unprocessable_entity
    end
  end
  
  # POST /api/v1/accounts/:account_id/apple_messages_bots/:id/enable
  def enable
    if @bot.update(enabled: true, updated_by: Current.user)
      track_event('bot_enabled', bot_id: @bot.id)
      render :show
    else
      render json: { errors: @bot.errors }, status: :unprocessable_entity
    end
  end
  
  # POST /api/v1/accounts/:account_id/apple_messages_bots/:id/disable
  def disable
    if @bot.update(enabled: false, updated_by: Current.user)
      track_event('bot_disabled', bot_id: @bot.id)
      render :show
    else
      render json: { errors: @bot.errors }, status: :unprocessable_entity
    end
  end
  
  # GET /api/v1/accounts/:account_id/apple_messages_bots/:id/export
  def export
    send_data @bot.export_configuration.to_json,
              filename: "bot_#{@bot.id}_config_#{Time.current.to_i}.json",
              type: 'application/json'
  end
  
  # POST /api/v1/accounts/:account_id/apple_messages_bots/import
  def import
    config = JSON.parse(params[:config_file].read)
    @bot = Current.account.apple_messages_bots.new(name: config['name'])
    @bot.import_configuration(config)
    @bot.created_by = Current.user
    @bot.updated_by = Current.user
    
    if @bot.save
      track_event('bot_imported', bot_id: @bot.id)
      render :show, status: :created
    else
      render json: { errors: @bot.errors }, status: :unprocessable_entity
    end
  rescue JSON::ParserError => e
    render json: { error: 'Invalid JSON file' }, status: :unprocessable_entity
  end
  
  # POST /api/v1/accounts/:account_id/apple_messages_bots/:id/test
  def test
    # Create a test conversation and message to validate bot behavior
    result = AppleMessagesForBusiness::BotTestService.new(@bot, params[:test_message]).perform
    render json: result
  end
  
  private
  
  def set_bot
    @bot = Current.account.apple_messages_bots.active.find(params[:id])
  end
  
  def bot_params
    params.require(:apple_messages_bot).permit(
      :name, :description, :enabled, :bot_type,
      :idle_timeout_minutes, :typing_indicators_enabled, :typing_indicator_delay,
      :webhook_url,
      bot_config: {},
      conversation_flow: {},
      keyword_mappings: {},
      interactive_handlers: {},
      response_templates: {},
      quick_reply_configs: {},
      form_configs: {},
      webhook_config: {}
    )
  end
  
  def check_authorization
    authorize :apple_messages_bot, :manage?
  end
  
  def track_event(event_name, properties = {})
    # Integration with analytics/tracking system
    Rails.logger.info "[Bot Event] #{event_name}: #{properties.inspect}"
  end
end
```

#### 3.2 Bot-Inbox Association Controller

```ruby
# app/controllers/api/v1/accounts/apple_messages_bots/inboxes_controller.rb
class Api::V1::Accounts::AppleMessagesBots::InboxesController < Api::V1::Accounts::BaseController
  before_action :set_bot
  before_action :set_bot_inbox, only: [:update, :destroy, :toggle]
  before_action :check_authorization
  
  # GET /api/v1/accounts/:account_id/apple_messages_bots/:bot_id/inboxes
  def index
    @bot_inboxes = @bot.apple_messages_bot_inboxes.includes(:inbox).ordered_by_priority
  end
  
  # POST /api/v1/accounts/:account_id/apple_messages_bots/:bot_id/inboxes
  def create
    @bot_inbox = @bot.apple_messages_bot_inboxes.new(bot_inbox_params)
    
    if @bot_inbox.save
      render :show, status: :created
    else
      render json: { errors: @bot_inbox.errors }, status: :unprocessable_entity
    end
  end
  
  # PATCH /api/v1/accounts/:account_id/apple_messages_bots/:bot_id/inboxes/:id
  def update
    if @bot_inbox.update(bot_inbox_params)
      render :show
    else
      render json: { errors: @bot_inbox.errors }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/v1/accounts/:account_id/apple_messages_bots/:bot_id/inboxes/:id
  def destroy
    @bot_inbox.destroy
    head :no_content
  end
  
  # POST /api/v1/accounts/:account_id/apple_messages_bots/:bot_id/inboxes/:id/toggle
  def toggle
    @bot_inbox.toggle_enabled!
    render :show
  end
  
  private
  
  def set_bot
    @bot = Current.account.apple_messages_bots.active.find(params[:apple_messages_bot_id])
  end
  
  def set_bot_inbox
    @bot_inbox = @bot.apple_messages_bot_inboxes.find(params[:id])
  end
  
  def bot_inbox_params
    params.require(:bot_inbox).permit(:inbox_id, :enabled, :priority, inbox_specific_config: {})
  end
  
  def check_authorization
    authorize :apple_messages_bot, :manage?
  end
end
```

#### 3.3 Audit Logs Controller

```ruby
# app/controllers/api/v1/accounts/apple_messages_bots/audit_logs_controller.rb
class Api::V1::Accounts::AppleMessagesBots::AuditLogsController < Api::V1::Accounts::BaseController
  before_action :set_bot
  before_action :check_authorization
  
  # GET /api/v1/accounts/:account_id/apple_messages_bots/:bot_id/audit_logs
  def index
    @audit_logs = @bot.audit_logs.recent.includes(:user)
    @audit_logs = @audit_logs.by_action(params[:action]) if params[:action].present?
    @audit_logs = @audit_logs.page(params[:page]).per(params[:per_page] || 25)
  end
  
  private
  
  def set_bot
    @bot = Current.account.apple_messages_bots.active.find(params[:apple_messages_bot_id])
  end
  
  def check_authorization
    authorize :apple_messages_bot, :view_audit_logs?
  end
end
```

---

### Phase 4: API Routes

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    namespace :accounts do
      resources :apple_messages_bots do
        member do
          post :enable
          post :disable
          get :export
          post :test
        end
        
        collection do
          post :import
        end
        
        resources :inboxes, controller: 'apple_messages_bots/inboxes', only: [:index, :create, :update, :destroy] do
          member do
            post :toggle
          end
        end
        
        resources :audit_logs, controller: 'apple_messages_bots/audit_logs', only: [:index]
      end
    end
  end
end
```

---

### Phase 5: Jbuilder Views

#### 5.1 Bot Index View

```ruby
# app/views/api/v1/accounts/apple_messages_bots/index.json.jbuilder
json.array! @bots do |bot|
  json.partial! 'api/v1/accounts/apple_messages_bots/bot', bot: bot
  json.inbox_count bot.active_inbox_count
end
```

#### 5.2 Bot Show View

```ruby
# app/views/api/v1/accounts/apple_messages_bots/show.json.jbuilder
json.partial! 'api/v1/accounts/apple_messages_bots/bot', bot: @bot
json.inboxes @bot.inboxes do |inbox|
  json.id inbox.id
  json.name inbox.name
  json.channel_type inbox.channel_type
end

if @audit_logs
  json.audit_logs @audit_logs do |log|
    json.partial! 'api/v1/accounts/apple_messages_bots/audit_log', audit_log: log
  end
end
```

#### 5.3 Bot Partial

```ruby
# app/views/api/v1/accounts/apple_messages_bots/_bot.json.jbuilder
json.id bot.id
json.name bot.name
json.description bot.description
json.enabled bot.enabled
json.bot_type bot.bot_type
json.idle_timeout_minutes bot.idle_timeout_minutes
json.typing_indicators_enabled bot.typing_indicators_enabled
json.typing_indicator_delay bot.typing_indicator_delay
json.webhook_url bot.webhook_url

json.bot_config bot.bot_config
json.conversation_flow bot.conversation_flow
json.keyword_mappings bot.keyword_mappings
json.interactive_handlers bot.interactive_handlers
json.response_templates bot.response_templates
json.quick_reply_configs bot.quick_reply_configs
json.form_configs bot.form_configs
json.webhook_config bot.webhook_config

json.created_at bot.created_at
json.updated_at bot.updated_at

if bot.created_by
  json.created_by do
    json.id bot.created_by.id
    json.name bot.created_by.name
  end
end

if bot.updated_by
  json.updated_by do
    json.id bot.updated_by.id
    json.name bot.updated_by.name
  end
end
```

#### 5.4 Audit Log Partial

```ruby
# app/views/api/v1/accounts/apple_messages_bots/_audit_log.json.jbuilder
json.id audit_log.id
json.action audit_log.action
json.changes audit_log.changes
json.metadata audit_log.metadata
json.ip_address audit_log.ip_address
json.created_at audit_log.created_at

json.user do
  json.id audit_log.user.id
  json.name audit_log.user.name
  json.email audit_log.user.email
end
```

---

### Phase 6: Authorization Policies

```ruby
# app/policies/apple_messages_bot_policy.rb
class AppleMessagesBotPolicy < ApplicationPolicy
  def manage?
    @user.administrator? || @user.has_permission?('manage_bots')
  end
  
  def view_audit_logs?
    @user.administrator?
  end
  
  def create?
    manage?
  end
  
  def update?
    manage?
  end
  
  def destroy?
    @user.administrator?
  end
end
```

---

### Phase 7: Frontend Implementation

#### 7.1 Vue.js Store Module

```javascript
// app/javascript/dashboard/store/modules/appleMessagesBots.js
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import AppleMessagesBotsAPI from '../../api/appleMessagesBots';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,

    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getBots($state) {
    return $state.records;
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
  getBot: $state => id => {
    return $state.records.find(record => record.id === id);
  },
  getEnabledBots($state) {
    return $state.records.filter(bot => bot.enabled);
  },
};

export const actions = {
  get: async function getBots({ commit }) {
    commit(types.SET_APPLE_MESSAGES_BOTS_UI_FLAG, { isFetching: true });
    try {
      const response = await AppleMessagesBotsAPI.get();
      commit(types.SET_APPLE_MESSAGES_BOTS, response.data);
    } catch (error) {
      // Handle error
    } finally {
      commit(types.SET_APPLE_MESSAGES_BOTS_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createBot({ commit }, botData) {
    commit(types.SET_APPLE_MESSAGES_BOTS_UI_FLAG, { isCreating: true });
    try {
      const response = await AppleMessagesBotsAPI.create(botData);
      commit(types.ADD_APPLE_MESSAGES_BOT, response.data);
      return response.data;
    } catch (error) {
      throw error;
    } finally {
      commit(types.SET_APPLE_MESSAGES_BOTS_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateBot({ commit }, { id, ...botData }) {
    commit(types.SET_APPLE_MESSAGES_BOTS_UI_FLAG, { isUpdating: true });
    try {
      const response = await AppleMessagesBotsAPI.update(id, botData);
      commit(types.EDIT_APPLE_MESSAGES_BOT, response.data);
      return response.data;
    } catch (error) {
      throw error;
    } finally {
      commit(types.SET_APPLE_MESSAGES_BOTS_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteBot({ commit }, id) {
    commit(types.SET_APPLE_MESSAGES_BOTS_UI_FLAG, { isDeleting: true });
    try {
      await AppleMessagesBotsAPI.delete(id);
      commit(types.DELETE_APPLE_MESSAGES_BOT, id);
    } catch (error) {
      throw error;
    } finally {
      commit(types.SET_APPLE_MESSAGES_BOTS_UI_FLAG, { isDeleting: false });
    }
  },

  enable: async function enableBot({ commit }, id) {
    try {
      const response = await AppleMessagesBotsAPI.enable(id);
      commit(types.EDIT_APPLE_MESSAGES_BOT, response.data);
    } catch (error) {
      throw error;
    }
  },

  disable: async function disableBot({ commit }, id) {
    try {
      const response = await AppleMessagesBotsAPI.disable(id);
      commit(types.EDIT_APPLE_MESSAGES_BOT, response.data);
    } catch (error) {
      throw error;
    }
  },
};

export const mutations = {
  [types.SET_APPLE_MESSAGES_BOTS_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },

  [types.SET_APPLE_MESSAGES_BOTS]: MutationHelpers.set,
  [types.ADD_APPLE_MESSAGES_BOT]: MutationHelpers.create,
  [types.EDIT_APPLE_MESSAGES_BOT]: MutationHelpers.update,
  [types.DELETE_APPLE_MESSAGES_BOT]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
```

#### 7.2 API Client

```javascript
// app/javascript/dashboard/api/appleMessagesBots.js
import ApiClient from './ApiClient';

class AppleMessagesBotsAPI extends ApiClient {
  constructor() {
    super('apple_messages_bots', { accountScoped: true });
  }

  enable(id) {
    return axios.post(`${this.url}/${id}/enable`);
  }

  disable(id) {
    return axios.post(`${this.url}/${id}/disable`);
  }

  export(id) {
    return axios.get(`${this.url}/${id}/export`, {
      responseType: 'blob',
    });
  }

  import(file) {
    const formData = new FormData();
    formData.append('config_file', file);
    return axios.post(`${this.url}/import`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  test(id, testMessage) {
    return axios.post(`${this.url}/${id}/test`, { test_message: testMessage });
  }

  getInboxes(botId) {
    return axios.get(`${this.url}/${botId}/inboxes`);
  }

  assignInbox(botId, inboxData) {
    return axios.post(`${this.url}/${botId}/inboxes`, inboxData);
  }

  updateInboxAssignment(botId, inboxId, data) {
    return axios.patch(`${this.url}/${botId}/inboxes/${inboxId}`, data);
  }

  removeInbox(botId, inboxId) {
    return axios.delete(`${this.url}/${botId}/inboxes/${inboxId}`);
  }

  toggleInbox(botId, inboxId) {
    return axios.post(`${this.url}/${botId}/inboxes/${inboxId}/toggle`);
  }

  getAuditLogs(botId, params = {}) {
    return axios.get(`${this.url}/${botId}/audit_logs`, { params });
  }
}

export default new AppleMessagesBotsAPI();
```

#### 7.3 Main Bot Management Component

```vue
<!-- app/javascript/dashboard/routes/dashboard/settings/appleMessagesBots/Index.vue -->
<template>
  <div class="apple-messages-bots-container">
    <woot-page-header
      :header-title="$t('APPLE_MESSAGES_BOTS.HEADER')"
      :header-content="$t('APPLE_MESSAGES_BOTS.DESCRIPTION')"
    >
      <template #actions>
        <woot-button
          color-scheme="success"
          icon="add-circle"
          @click="openCreateModal"
        >
          {{ $t('APPLE_MESSAGES_BOTS.CREATE.BUTTON') }}
        </woot-button>
      </template>
    </woot-page-header>

    <div class="bots-list">
      <woot-loading-state
        v-if="uiFlags.isFetching"
        :message="$t('APPLE_MESSAGES_BOTS.LOADING')"
      />

      <div v-else-if="bots.length === 0" class="empty-state">
        <fluent-icon icon="bot" size="64" />
        <h3>{{ $t('APPLE_MESSAGES_BOTS.EMPTY_STATE.TITLE') }}</h3>
        <p>{{ $t('APPLE_MESSAGES_BOTS.EMPTY_STATE.MESSAGE') }}</p>
        <woot-button
          color-scheme="primary"
          icon="add-circle"
          @click="openCreateModal"
        >
          {{ $t('APPLE_MESSAGES_BOTS.CREATE.BUTTON') }}
        </woot-button>
      </div>

      <div v-else class="bots-grid">
        <bot-card
          v-for="bot in bots"
          :key="bot.id"
          :bot="bot"
          @edit="openEditModal"
          @delete="confirmDelete"
          @toggle="toggleBot"
          @view-details="viewBotDetails"
        />
      </div>
    </div>

    <!-- Create/Edit Modal -->
    <woot-modal
      :show.sync="showBotModal"
      :on-close="closeBotModal"
      size="large"
    >
      <bot-form
        :bot="selectedBot"
        :is-editing="isEditing"
        @submit="handleBotSubmit"
        @cancel="closeBotModal"
      />
    </woot-modal>

    <!-- Delete Confirmation -->
    <woot-delete-modal
      :show.sync="showDeleteConfirmation"
      :on-close="closeDeleteModal"
      :on-confirm="deleteBot"
      :title="$t('APPLE_MESSAGES_BOTS.DELETE.CONFIRM.TITLE')"
      :message="$t('APPLE_MESSAGES_BOTS.DELETE.CONFIRM.MESSAGE')"
      :confirm-text="$t('APPLE_MESSAGES_BOTS.DELETE.CONFIRM.YES')"
      :reject-text="$t('APPLE_MESSAGES_BOTS.DELETE.CONFIRM.NO')"
    />
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import BotCard from './components/BotCard.vue';
import BotForm from './components/BotForm.vue';
import alertMixin from 'shared/mixins/alertMixin';

export default {
  components: {
    BotCard,
    BotForm,
  },
  mixins: [alertMixin],
  data() {
    return {
      showBotModal: false,
      showDeleteConfirmation: false,
      selectedBot: null,
      isEditing: false,
      botToDelete: null,
    };
  },
  computed: {
    ...mapGetters({
      bots: 'appleMessagesBots/getBots',
      uiFlags: 'appleMessagesBots/getUIFlags',
    }),
  },
  mounted() {
    this.$store.dispatch('appleMessagesBots/get');
  },
  methods: {
    openCreateModal() {
      this.selectedBot = null;
      this.isEditing = false;
      this.showBotModal = true;
    },
    openEditModal(bot) {
      this.selectedBot = bot;
      this.isEditing = true;
      this.showBotModal = true;
    },
    closeBotModal() {
      this.showBotModal = false;
      this.selectedBot = null;
      this.isEditing = false;
    },
    async handleBotSubmit(botData) {
      try {
        if (this.isEditing) {
          await this.$store.dispatch('appleMessagesBots/update', {
            id: this.selectedBot.id,
            ...botData,
          });
          this.showAlert(this.$t('APPLE_MESSAGES_BOTS.EDIT.API.SUCCESS_MESSAGE'));
        } else {
          await this.$store.dispatch('appleMessagesBots/create', botData);
          this.showAlert(this.$t('APPLE_MESSAGES_BOTS.CREATE.API.SUCCESS_MESSAGE'));
        }
        this.closeBotModal();
      } catch (error) {
        this.showAlert(
          this.$t('APPLE_MESSAGES_BOTS.API.ERROR_MESSAGE'),
          'error'
        );
      }
    },
    confirmDelete(bot) {
      this.botToDelete = bot;
      this.showDeleteConfirmation = true;
    },
    closeDeleteModal() {
      this.showDeleteConfirmation = false;
      this.botToDelete = null;
    },
    async deleteBot() {
      try {
        await this.$store.dispatch('appleMessagesBots/delete', this.botToDelete.id);
        this.showAlert(this.$t('APPLE_MESSAGES_BOTS.DELETE.API.SUCCESS_MESSAGE'));
        this.closeDeleteModal();
      } catch (error) {
        this.showAlert(
          this.$t('APPLE_MESSAGES_BOTS.DELETE.API.ERROR_MESSAGE'),
          'error'
        );
      }
    },
    async toggleBot(bot) {
      try {
        if (bot.enabled) {
          await this.$store.dispatch('appleMessagesBots/disable', bot.id);
          this.showAlert(this.$t('APPLE_MESSAGES_BOTS.DISABLE.SUCCESS'));
        } else {
          await this.$store.dispatch('appleMessagesBots/enable', bot.id);
          this.showAlert(this.$t('APPLE_MESSAGES_BOTS.ENABLE.SUCCESS'));
        }
      } catch (error) {
        this.showAlert(
          this.$t('APPLE_MESSAGES_BOTS.TOGGLE.ERROR'),
          'error'
        );
      }
    },
    viewBotDetails(bot) {
      this.$router.push({
        name: 'apple_messages_bot_details',
        params: { botId: bot.id },
      });
    },
  },
};
</script>

<style lang="scss" scoped>
.apple-messages-bots-container {
  padding: var(--space-normal);
}

.bots-list {
  margin-top: var(--space-large);
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--space-mega);
  text-align: center;

  h3 {
    margin-top: var(--space-normal);
    font-size: var(--font-size-large);
  }

  p {
    margin: var(--space-small) 0 var(--space-normal);
    color: var(--s-600);
  }
}

.bots-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: var(--space-normal);
}
</style>
```

#### 7.4 Bot Card Component

```vue
<!-- app/javascript/dashboard/routes/dashboard/settings/appleMessagesBots/components/BotCard.vue -->
<template>
  <div class="bot-card" :class="{ 'bot-card--disabled': !bot.enabled }">
    <div class="bot-card__header">
      <div class="bot-card__title-section">
        <h3 class="bot-card__title">{{ bot.name }}</h3>
        <woot-label
          :title="bot.enabled ? $t('APPLE_MESSAGES_BOTS.STATUS.ENABLED') : $t('APPLE_MESSAGES_BOTS.STATUS.DISABLED')"
          :color-scheme="bot.enabled ? 'success' : 'secondary'"
          small
        />
      </div>
      <div class="bot-card__actions">
        <woot-button
          variant="smooth"
          size="tiny"
          color-scheme="secondary"
          icon="settings"
          @click="$emit('edit', bot)"
        />
        <woot-button
          variant="smooth"
          size="tiny"
          color-scheme="alert"
          icon="delete"
          @click="$emit('delete', bot)"
        />
      </div>
    </div>

    <p v-if="bot.description" class="bot-card__description">
      {{ bot.description }}
    </p>

    <div class="bot-card__meta">
      <div class="bot-card__meta-item">
        <fluent-icon icon="bot" size="16" />
        <span>{{ bot.bot_type }}</span>
      </div>
      <div class="bot-card__meta-item">
        <fluent-icon icon="inbox" size="16" />
        <span>{{ bot.inbox_count }} {{ $t('APPLE_MESSAGES_BOTS.INBOXES') }}</span>
      </div>
      <div class="bot-card__meta-item">
        <fluent-icon icon="clock" size="16" />
        <span>{{ bot.idle_timeout_minutes }}m timeout</span>
      </div>
    </div>

    <div class="bot-card__footer">
      <woot-button
        variant="smooth"
        size="small"
        @click="$emit('view-details', bot)"
      >
        {{ $t('APPLE_MESSAGES_BOTS.VIEW_DETAILS') }}
      </woot-button>
      <woot-button
        variant="smooth"
        size="small"
        :color-scheme="bot.enabled ? 'alert' : 'success'"
        @click="$emit('toggle', bot)"
      >
        {{ bot.enabled ? $t('APPLE_MESSAGES_BOTS.DISABLE') : $t('APPLE_MESSAGES_BOTS.ENABLE') }}
      </woot-button>
    </div>
  </div>
</template>

<script>
export default {
  props: {
    bot: {
      type: Object,
      required: true,
    },
  },
};
</script>

<style lang="scss" scoped>
.bot-card {
  background: var(--white);
  border: 1px solid var(--s-100);
  border-radius: var(--border-radius-medium);
  padding: var(--space-normal);
  transition: all 0.3s ease;

  &:hover {
    box-shadow: var(--shadow-medium);
  }

  &--disabled {
    opacity: 0.6;
  }

  &__header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: var(--space-small);
  }

  &__title-section {
    display: flex;
    align-items: center;
    gap: var(--space-small);
  }

  &__title {
    font-size: var(--font-size-default);
    font-weight: var(--font-weight-medium);
    margin: 0;
  }

  &__actions {
    display: flex;
    gap: var(--space-smaller);
  }

  &__description {
    color: var(--s-600);
    font-size: var(--font-size-small);
    margin: var(--space-small) 0;
    line-height: 1.5;
  }

  &__meta {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-normal);
    margin: var(--space-normal) 0;
    padding: var(--space-small) 0;
    border-top: 1px solid var(--s-50);
    border-bottom: 1px solid var(--s-50);
  }

  &__meta-item {
    display: flex;
    align-items: center;
    gap: var(--space-smaller);
    font-size: var(--font-size-mini);
    color: var(--s-600);
  }

  &__footer {
    display: flex;
    justify-content: space-between;
    margin-top: var(--space-normal);
  }
}
</style>
```

---

### Phase 8: Migration Strategy

#### 8.1 Data Migration Script

```ruby
# lib/tasks/apple_messages_bots.rake
namespace :apple_messages_bots do
  desc 'Migrate existing Acoustic House Bot configurations to database'
  task migrate_existing_configs: :environment do
    puts '🔄 Starting migration of existing bot configurations...'
    
    Account.find_each do |account|
      # Find all Apple Messages for Business inboxes for this account
      amb_inboxes = account.inboxes.joins(:channel)
                          .where(channels: { type: 'Channel::AppleMessagesForBusiness' })
      
      next if amb_inboxes.empty?
      
      puts "\n📦 Processing account: #{account.name} (ID: #{account.id})"
      puts "   Found #{amb_inboxes.count} Apple Messages inbox(es)"
      
      # Create default Acoustic House bot for this account
      bot = account.apple_messages_bots.find_or_create_by!(
        name: 'Acoustic House Bot (Migrated)',
        bot_type: 'acoustic_house'
      ) do |b|
        b.description = 'Automatically migrated from existing configuration'
        b.enabled = true
        b.created_by = account.administrators.first
        b.updated_by = account.administrators.first
        
        # Set default configuration from service class
        b.conversation_flow = load_default_conversation_flow
        b.keyword_mappings = load_default_keyword_mappings
        b.interactive_handlers = load_default_interactive_handlers
        b.response_templates = {}
        b.quick_reply_configs = {}
        b.form_configs = {}
      end
      
      puts "   ✅ Created bot: #{bot.name} (ID: #{bot.id})"
      
      # Associate bot with all AMB inboxes
      amb_inboxes.each do |inbox|
        bot_inbox = bot.apple_messages_bot_inboxes.find_or_create_by!(inbox: inbox) do |bi|
          bi.enabled = true
          bi.priority = 0
        end
        puts "      ✓ Associated with inbox: #{inbox.name}"
      end
    end
    
    puts "\n✅ Migration completed successfully!"
  end
  
  desc 'Export bot configuration to JSON'
  task :export, [:bot_id] => :environment do |_t, args|
    bot = AppleMessagesBot.find(args[:bot_id])
    config = bot.export_configuration
    
    filename = "bot_#{bot.id}_config_#{Time.current.to_i}.json"
    File.write(filename, JSON.pretty_generate(config))
    
    puts "✅ Configuration exported to: #{filename}"
  end
  
  desc 'Import bot configuration from JSON'
  task :import, [:account_id, :file_path] => :environment do |_t, args|
    account = Account.find(args[:account_id])
    config = JSON.parse(File.read(args[:file_path]))
    
    bot = account.apple_messages_bots.create!(name: config['name'])
    bot.import_configuration(config)
    
    puts "✅ Bot imported successfully: #{bot.name} (ID: #{bot.id})"
  end
  
  private
  
  def load_default_conversation_flow
    # Extract from AcousticHouseBotService
    {
      states: {
        'AHA1' => { name: 'Welcome', handler: 'handle_welcome' },
        'AHA2' => { name: 'Region Selection', handler: 'handle_region_prompt' },
        'AHA3' => { name: 'Form or Name Prompt', handler: 'handle_form_or_name_prompt' },
        # ... more states
      }
    }
  end
  
  def load_default_keyword_mappings
    {
      demo_keywords: AppleMessagesForBusiness::AcousticHouseBotService::DEMO_KEYWORDS,
      flow_control_keywords: AppleMessagesForBusiness::AcousticHouseBotService::FLOW_CONTROL_KEYWORDS
    }
  end
  
  def load_default_interactive_handlers
    AppleMessagesForBusiness::AcousticHouseBotService::INTERACTIVE_HANDLERS
  end
end
```

---

### Phase 9: Service Integration

#### 9.1 Updated Bot Service

```ruby
# app/services/apple_messages_for_business/acoustic_house_bot_service.rb
class AppleMessagesForBusiness::AcousticHouseBotService
  # ... existing constants ...
  
  def initialize(conversation, message, bot_config = nil)
    @conversation = conversation
    @message = message
    @contact = conversation.contact
    @bot_config = bot_config || load_bot_config
    @bot_state = get_bot_state
    @lang = detect_language
  end
  
  private
  
  def load_bot_config
    # Try to load bot configuration from database
    inbox = @conversation.inbox
    bot_inbox = AppleMessagesBotInbox.joins(:apple_messages_bot)
                                     .where(inbox: inbox, enabled: true)
                                     .where(apple_messages_bots: { enabled: true })
                                     .order(priority: :desc)
                                     .first
    
    return bot_inbox.apple_messages_bot if bot_inbox
    
    # Fallback to default configuration
    Rails.logger.warn "[Bot] No bot configuration found for inbox #{inbox.id}, using defaults"
    nil
  end
  
  def idle_timeout
    @bot_config&.idle_timeout_minutes&.minutes || IDLE_TIMEOUT
  end
  
  def typing_indicators_enabled?
    return TYPING_INDICATORS_ENABLED if @bot_config.nil?
    @bot_config.typing_indicators_enabled
  end
  
  def typing_indicator_delay
    @bot_config&.typing_indicator_delay || TYPING_INDICATOR_DELAY
  end
  
  # ... rest of the service methods ...
end
```

---

### Phase 10: Testing Strategy

#### 10.1 Model Specs

```ruby
# spec/models/apple_messages_bot_spec.rb
require 'rails_helper'

RSpec.describe AppleMessagesBot, type: :model do
  describe 'associations' do
    it { should belong_to(:account) }
    it { should belong_to(:created_by).class_name('User').optional }
    it { should belong_to(:updated_by).class_name('User').optional }
    it { should have_many(:apple_messages_bot_inboxes).dependent(:destroy) }
    it { should have_many(:inboxes).through(:apple_messages_bot_inboxes) }
    it { should have_many(:audit_logs).dependent(:destroy) }
  end
  
  describe 'validations' do
    subject { create(:apple_messages_bot) }
    
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(255) }
    it { should validate_presence_of(:bot_type) }
    it { should validate_inclusion_of(:bot_type).in_array(%w[acoustic_house custom webhook]) }
    it { should validate_numericality_of(:idle_timeout_minutes).is_greater_than(0) }
  end
  
  describe 'scopes' do
    let!(:enabled_bot) { create(:apple_messages_bot, enabled: true) }
    let!(:disabled_bot) { create(:apple_messages_bot, enabled: false) }
    let!(:deleted_bot) { create(:apple_messages_bot, deleted_at: Time.current) }
    
    it 'returns enabled bots' do
      expect(AppleMessagesBot.enabled).to include(enabled_bot)
      expect(AppleMessagesBot.enabled).not_to include(disabled_bot)
    end
    
    it 'returns active bots' do
      expect(AppleMessagesBot.active).to include(enabled_bot, disabled_bot)
      expect(AppleMessagesBot.active).not_to include(deleted_bot)
    end
  end
  
  describe '#soft_delete' do
    let(:bot) { create(:apple_messages_bot, enabled: true) }
    
    it 'marks bot as deleted and disabled' do
      bot.soft_delete
      expect(bot.deleted_at).not_to be_nil
      expect(bot.enabled).to be false
    end
  end
  
  describe '#export_configuration' do
    let(:bot) { create(:apple_messages_bot) }
    
    it 'exports bot configuration as hash' do
      config = bot.export_configuration
      expect(config).to include(:name, :bot_type, :conversation_flow)
    end
  end
end
```

#### 10.2 Controller Specs

```ruby
# spec/controllers/api/v1/accounts/apple_messages_bots_controller_spec.rb
require 'rails_helper'

RSpec.describe Api::V1::Accounts::AppleMessagesBotsController, type: :controller do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  
  before do
    sign_in administrator
  end
  
  describe 'GET #index' do
    let!(:bot1) { create(:apple_messages_bot, account: account) }
    let!(:bot2) { create(:apple_messages_bot, account: account, enabled: false) }
    
    it 'returns all bots for the account' do
      get :index, params: { account_id: account.id }
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).length).to eq(2)
    end
    
    it 'filters by enabled status' do
      get :index, params: { account_id: account.id, enabled: 'true' }
      expect(JSON.parse(response.body).length).to eq(1)
    end
  end
  
  describe 'POST #create' do
    let(:valid_params) do
      {
        account_id: account.id,
        apple_messages_bot: {
          name: 'Test Bot',
          description: 'Test Description',
          bot_type: 'acoustic_house'
        }
      }
    end
    
    it 'creates a new bot' do
      expect {
        post :create, params: valid_params
      }.to change(AppleMessagesBot, :count).by(1)
      
      expect(response).to have_http_status(:created)
    end
    
    it 'sets created_by and updated_by' do
      post :create, params: valid_params
      bot = AppleMessagesBot.last
      expect(bot.created_by).to eq(administrator)
      expect(bot.updated_by).to eq(administrator)
    end
  end
  
  describe 'PATCH #update' do
    let(:bot) { create(:apple_messages_bot, account: account) }
    
    it 'updates the bot' do
      patch :update, params: {
        account_id: account.id,
        id: bot.id,
        apple_messages_bot: { name: 'Updated Name' }
      }
      
      expect(response).to have_http_status(:success)
      expect(bot.reload.name).to eq('Updated Name')
    end
  end
  
  describe 'DELETE #destroy' do
    let(:bot) { create(:apple_messages_bot, account: account) }
    
    it 'soft deletes the bot' do
      delete :destroy, params: { account_id: account.id, id: bot.id }
      expect(response).to have_http_status(:no_content)
      expect(bot.reload.deleted_at).not_to be_nil
    end
  end
end
```

---

### Phase 11: Documentation

#### 11.1 User Documentation

```markdown
# Apple Messages Bot Management - User Guide

## Overview

The Apple Messages Bot Management interface allows you to create, configure, and manage conversational bots for your Apple Messages for Business channels.

## Creating a Bot

1. Navigate to **Settings** → **Apple Messages Bots**
2. Click **Create Bot**
3. Fill in the required information:
   - **Name**: A descriptive name for your bot
   - **Description**:
 Optional details about the bot's purpose
   - **Bot Type**: Select the bot type (Acoustic House, Custom, or Webhook)
   - **Timeout**: Set the idle timeout in minutes (default: 30)
   - **Typing Indicators**: Enable/disable typing indicators

4. Configure conversation flow and keywords
5. Click **Create Bot**

## Assigning Bots to Inboxes

1. Open the bot details page
2. Click **Assign to Inbox**
3. Select the inbox from the dropdown
4. Set priority (higher priority bots are triggered first)
5. Click **Assign**

## Enabling/Disabling Bots

- Use the toggle switch on the bot card to enable/disable
- Disabled bots will not process any messages
- Bot assignments remain intact when disabled

## Exporting/Importing Configurations

### Export
1. Open bot details
2. Click **Export Configuration**
3. Save the JSON file

### Import
1. Click **Import Bot**
2. Select the JSON configuration file
3. Review and confirm

## Testing Bots

1. Open bot details
2. Click **Test Bot**
3. Enter a test message
4. Review the bot's response

## Audit Trail

View all configuration changes in the **Audit Logs** tab:
- Who made the change
- What was changed
- When it was changed
- IP address and user agent
```

#### 11.2 Developer Documentation

```markdown
# Apple Messages Bot Management - Developer Guide

## Architecture Overview

The bot management system consists of three main layers:

1. **Database Layer**: PostgreSQL tables with JSONB columns for flexible configuration
2. **API Layer**: RESTful controllers with Pundit authorization
3. **Frontend Layer**: Vue.js components with Vuex state management

## Database Schema

### apple_messages_bots
Primary table storing bot configurations with JSONB fields for flexible data structures.

### apple_messages_bot_inboxes
Junction table linking bots to inboxes with priority support.

### apple_messages_bot_audit_logs
Audit trail for all bot configuration changes.

## API Endpoints

### Bot Management
- `GET /api/v1/accounts/:account_id/apple_messages_bots` - List all bots
- `POST /api/v1/accounts/:account_id/apple_messages_bots` - Create bot
- `GET /api/v1/accounts/:account_id/apple_messages_bots/:id` - Get bot details
- `PATCH /api/v1/accounts/:account_id/apple_messages_bots/:id` - Update bot
- `DELETE /api/v1/accounts/:account_id/apple_messages_bots/:id` - Delete bot (soft)
- `POST /api/v1/accounts/:account_id/apple_messages_bots/:id/enable` - Enable bot
- `POST /api/v1/accounts/:account_id/apple_messages_bots/:id/disable` - Disable bot
- `GET /api/v1/accounts/:account_id/apple_messages_bots/:id/export` - Export config
- `POST /api/v1/accounts/:account_id/apple_messages_bots/import` - Import config
- `POST /api/v1/accounts/:account_id/apple_messages_bots/:id/test` - Test bot

### Inbox Assignments
- `GET /api/v1/accounts/:account_id/apple_messages_bots/:bot_id/inboxes` - List assignments
- `POST /api/v1/accounts/:account_id/apple_messages_bots/:bot_id/inboxes` - Assign inbox
- `PATCH /api/v1/accounts/:account_id/apple_messages_bots/:bot_id/inboxes/:id` - Update assignment
- `DELETE /api/v1/accounts/:account_id/apple_messages_bots/:bot_id/inboxes/:id` - Remove assignment
- `POST /api/v1/accounts/:account_id/apple_messages_bots/:bot_id/inboxes/:id/toggle` - Toggle assignment

### Audit Logs
- `GET /api/v1/accounts/:account_id/apple_messages_bots/:bot_id/audit_logs` - Get audit logs

## Creating Custom Bot Types

1. Create a new service class inheriting from base bot service
2. Implement required methods: `process_message`, `process_interactive_response`
3. Add bot type to `AppleMessagesBot::BOT_TYPES` constant
4. Update frontend to support new bot type

## Configuration Structure

### conversation_flow
```json
{
  "states": {
    "STATE_ID": {
      "name": "State Name",
      "handler": "method_name",
      "next_state": "NEXT_STATE_ID"
    }
  }
}
```

### keyword_mappings
```json
{
  "demo_keywords": {
    "keyword": "handler_method"
  },
  "flow_control_keywords": {
    "keyword": "handler_method"
  }
}
```

### interactive_handlers
```json
{
  "request_id": "handler_method"
}
```

## Testing

Run the test suite:
```bash
bundle exec rspec spec/models/apple_messages_bot_spec.rb
bundle exec rspec spec/controllers/api/v1/accounts/apple_messages_bots_controller_spec.rb
```

## Migration

Migrate existing configurations:
```bash
bundle exec rake apple_messages_bots:migrate_existing_configs
```

Export bot configuration:
```bash
bundle exec rake apple_messages_bots:export[bot_id]
```

Import bot configuration:
```bash
bundle exec rake apple_messages_bots:import[account_id,file_path]
```
```

---

### Phase 12: Implementation Roadmap

#### 12.1 Sprint 1: Database & Models (Week 1)
- [ ] Create database migrations
- [ ] Implement ActiveRecord models
- [ ] Write model tests
- [ ] Create seed data for development

#### 12.2 Sprint 2: API Layer (Week 2)
- [ ] Implement controllers
- [ ] Create Jbuilder views
- [ ] Add routes
- [ ] Implement authorization policies
- [ ] Write controller tests

#### 12.3 Sprint 3: Frontend - Core (Week 3)
- [ ] Create Vuex store module
- [ ] Implement API client
- [ ] Build main bot list component
- [ ] Create bot card component
- [ ] Add routing

#### 12.4 Sprint 4: Frontend - Forms (Week 4)
- [ ] Build bot creation form
- [ ] Implement bot edit form
- [ ] Add inbox assignment interface
- [ ] Create validation logic

#### 12.5 Sprint 5: Advanced Features (Week 5)
- [ ] Implement export/import functionality
- [ ] Add bot testing interface
- [ ] Create audit log viewer
- [ ] Build webhook configuration UI

#### 12.6 Sprint 6: Migration & Polish (Week 6)
- [ ] Create migration scripts
- [ ] Test migration with production data
- [ ] Add i18n translations
- [ ] Polish UI/UX
- [ ] Performance optimization

#### 12.7 Sprint 7: Documentation & Testing (Week 7)
- [ ] Write user documentation
- [ ] Create developer guides
- [ ] End-to-end testing
- [ ] Security audit
- [ ] Accessibility review

#### 12.8 Sprint 8: Deployment (Week 8)
- [ ] Staging deployment
- [ ] User acceptance testing
- [ ] Production deployment
- [ ] Monitor and fix issues
- [ ] Gather user feedback

---

### Phase 13: Security Considerations

#### 13.1 Authorization
- Only administrators can create/edit/delete bots
- Account-scoped access (users can only see their account's bots)
- Audit trail for all changes

#### 13.2 Data Validation
- Sanitize all user inputs
- Validate JSONB structure
- Prevent XSS attacks in bot responses
- Rate limiting on API endpoints

#### 13.3 Webhook Security
- Validate webhook URLs
- Support webhook authentication
- Implement retry logic with exponential backoff
- Log all webhook calls

---

### Phase 14: Performance Optimization

#### 14.1 Database Optimization
- Add appropriate indexes
- Use JSONB GIN indexes for configuration searches
- Implement pagination for large datasets
- Cache frequently accessed bot configurations

#### 14.2 API Optimization
- Implement eager loading for associations
- Use jbuilder caching
- Add API response caching
- Implement rate limiting

#### 14.3 Frontend Optimization
- Lazy load bot details
- Implement virtual scrolling for large lists
- Cache bot configurations in Vuex
- Optimize bundle size

---

### Phase 15: Monitoring & Analytics

#### 15.1 Metrics to Track
- Number of active bots per account
- Bot message processing time
- Bot error rates
- Configuration change frequency
- Inbox assignment distribution

#### 15.2 Logging
- Log all bot interactions
- Track configuration changes
- Monitor webhook failures
- Alert on critical errors

#### 15.3 Analytics Dashboard
- Bot usage statistics
- Performance metrics
- Error trends
- User engagement metrics

---

## Appendix A: Configuration Examples

### Example 1: Basic Acoustic House Bot

```json
{
  "name": "Guitar Shop Assistant",
  "description": "Helps customers find and purchase guitars",
  "bot_type": "acoustic_house",
  "enabled": true,
  "idle_timeout_minutes": 30,
  "typing_indicators_enabled": true,
  "typing_indicator_delay": 1.5,
  "conversation_flow": {
    "states": {
      "AHA1": {
        "name": "Welcome",
        "handler": "handle_welcome",
        "next_state": "AHA2"
      },
      "AHA2": {
        "name": "Region Selection",
        "handler": "handle_region_prompt",
        "next_state": "AHA3"
      }
    }
  },
  "keyword_mappings": {
    "demo_keywords": {
      "list picker": "handle_list_picker_demo",
      "guitar": "handle_list_picker_demo"
    },
    "flow_control_keywords": {
      "menu": "handle_menu",
      "startover": "handle_start_over"
    }
  }
}
```

### Example 2: Webhook Bot

```json
{
  "name": "Custom Support Bot",
  "description": "Routes to external AI service",
  "bot_type": "webhook",
  "enabled": true,
  "webhook_url": "https://api.example.com/bot/webhook",
  "webhook_config": {
    "method": "POST",
    "headers": {
      "Authorization": "Bearer token123",
      "Content-Type": "application/json"
    },
    "timeout": 30,
    "retry_attempts": 3
  }
}
```

---

## Appendix B: API Request/Response Examples

### Create Bot Request
```http
POST /api/v1/accounts/1/apple_messages_bots
Content-Type: application/json

{
  "apple_messages_bot": {
    "name": "My Bot",
    "description": "A helpful bot",
    "bot_type": "acoustic_house",
    "enabled": true,
    "idle_timeout_minutes": 30,
    "typing_indicators_enabled": true,
    "conversation_flow": {},
    "keyword_mappings": {}
  }
}
```

### Create Bot Response
```json
{
  "id": 1,
  "name": "My Bot",
  "description": "A helpful bot",
  "enabled": true,
  "bot_type": "acoustic_house",
  "idle_timeout_minutes": 30,
  "typing_indicators_enabled": true,
  "typing_indicator_delay": 1.5,
  "webhook_url": null,
  "bot_config": {},
  "conversation_flow": {},
  "keyword_mappings": {},
  "interactive_handlers": {},
  "response_templates": {},
  "quick_reply_configs": {},
  "form_configs": {},
  "webhook_config": {},
  "created_at": "2025-11-18T06:00:00.000Z",
  "updated_at": "2025-11-18T06:00:00.000Z",
  "created_by": {
    "id": 1,
    "name": "Admin User"
  },
  "updated_by": {
    "id": 1,
    "name": "Admin User"
  }
}
```

---

## Appendix C: Database Indexes

```sql
-- Performance indexes
CREATE INDEX idx_amb_bots_account_enabled ON apple_messages_bots(account_id, enabled) WHERE deleted_at IS NULL;
CREATE INDEX idx_amb_bots_type ON apple_messages_bots(bot_type) WHERE deleted_at IS NULL;
CREATE INDEX idx_amb_bot_inboxes_enabled ON apple_messages_bot_inboxes(enabled);
CREATE INDEX idx_amb_bot_inboxes_priority ON apple_messages_bot_inboxes(inbox_id, priority DESC);

-- JSONB indexes for configuration searches
CREATE INDEX idx_amb_bots_conversation_flow ON apple_messages_bots USING GIN (conversation_flow);
CREATE INDEX idx_amb_bots_keyword_mappings ON apple_messages_bots USING GIN (keyword_mappings);
CREATE INDEX idx_amb_bots_interactive_handlers ON apple_messages_bots USING GIN (interactive_handlers);

-- Audit log indexes
CREATE INDEX idx_amb_audit_logs_bot_action ON apple_messages_bot_audit_logs(apple_messages_bot_id, action);
CREATE INDEX idx_amb_audit_logs_created_at ON apple_messages_bot_audit_logs(created_at DESC);
```

---

## Appendix D: Troubleshooting Guide

### Common Issues

#### Bot Not Responding
1. Check if bot is enabled
2. Verify inbox assignment
3. Check audit logs for errors
4. Review bot configuration

#### Configuration Not Saving
1. Validate JSON structure
2. Check field length limits
3. Review validation errors
4. Check user permissions

#### Webhook Failures
1. Verify webhook URL is accessible
2. Check authentication headers
3. Review webhook timeout settings
4. Check webhook response format

---

## Conclusion

This implementation plan provides a comprehensive roadmap for exposing the Acoustic House Bot Service through the Chatwoot UI. The solution includes:

✅ **Database Schema**: Three tables with proper indexing and relationships  
✅ **ActiveRecord Models**: Full CRUD support with validations and callbacks  
✅ **API Layer**: RESTful endpoints with authorization and audit logging  
✅ **Frontend UI**: Vue.js components for bot management  
✅ **Migration Strategy**: Scripts to migrate existing configurations  
✅ **Testing**: Comprehensive test coverage  
✅ **Documentation**: User and developer guides  
✅ **Security**: Authorization, validation, and audit trails  
✅ **Performance**: Optimized queries and caching  
✅ **Monitoring**: Logging and analytics  

The implementation follows Chatwoot's existing patterns and best practices, ensuring seamless integration with the current codebase. The modular design allows for future extensibility and supports multiple bot types beyond the initial Acoustic House implementation.

**Estimated Timeline**: 8 weeks  
**Team Size**: 2-3 developers  
**Risk Level**: Medium (requires careful migration of existing configurations)

---

## Next Steps

1. Review and approve this implementation plan
2. Set up development environment
3. Create feature branch
4. Begin Sprint 1 (Database & Models)
5. Schedule regular progress reviews
6. Plan user acceptance testing
7. Prepare deployment strategy

---

**Document Prepared By**: Roo AI Assistant  
**Date**: November 18, 2025  
**Version**: 1.0  
**Status**: Ready for Review