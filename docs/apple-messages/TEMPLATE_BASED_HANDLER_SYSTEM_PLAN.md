# Template-Based Handler System - Implementation Plan

## 🎯 Executive Summary

**Goal**: Replace hardcoded handler methods in `acoustic_house_bot_service.rb` with configurable template-based actions that can be fully edited in the Bot Studio UI.

**Current Problem**: Handlers like `handle_welcome`, `handle_menu`, etc. are Ruby methods that can only be modified by editing service files. This requires developer intervention for every bot behavior change.

**Solution**: Create a template-based action system where common bot patterns (send message, send list picker, update state, etc.) are pre-built templates with configurable parameters in the UI.

**Estimated Total Effort**: 6-8 days

**Status**: 📋 Planning Phase - Awaiting Approval

---

## 📋 Template Types & Parameters

Based on analysis of existing handlers in `acoustic_house_bot_service.rb`, we need these 12 template types:

### 1. Send Text Message
```yaml
Parameters:
  - message: string (required)
  - delay_seconds: number (optional, default: 0)

Use Cases:
  - Simple text responses
  - Confirmations
  - Instructions

Example:
  "Thank you for contacting Acoustic Bot Prod."
```

### 2. Send List Picker
```yaml
Parameters:
  - template_id: integer (required) - MessageTemplate reference
  - wait_for_response: boolean (default: true)

Use Cases:
  - Menu selection
  - Product selection
  - Region selection

Example:
  Main menu, guitar selection, store selection
```

### 3. Send Time Picker
```yaml
Parameters:
  - template_id: integer (required) - MessageTemplate reference
  - timezone_offset: integer (optional)
  - location_data: object (optional)

Use Cases:
  - Appointment booking
  - Lesson scheduling

Example:
  Schedule guitar lesson
```

### 4. Send Form
```yaml
Parameters:
  - template_id: integer (required) - MessageTemplate reference
  - pre_fill_data: object (optional)

Use Cases:
  - Data collection
  - Preferences
  - Contact forms

Example:
  Guitar information form, contact form
```

### 5. Send Rich Link
```yaml
Parameters:
  - url: string (required)
  - title: string (required)
  - subtitle: string (optional)
  - image_url: string (optional)

Use Cases:
  - External links
  - Resources
  - Documentation

Example:
  AR experience link, product links
```

### 6. Send Quick Reply
```yaml
Parameters:
  - message: string (required)
  - request_id: string (required)
  - items: array (required)
    - title: string
    - value: string

Use Cases:
  - Yes/No questions
  - Simple choices

Example:
  "Continue?", "View AR?", "Place in your space?"
```

### 7. Update Conversation Attributes
```yaml
Parameters:
  - attributes: object (required)
    - key: value pairs

Use Cases:
  - Store user preferences
  - Track selections

Example:
  Store selected region, guitar choice, name preference
```

### 8. Conditional Branch
```yaml
Parameters:
  - condition_type: enum (required)
    - attribute_equals
    - attribute_contains
    - message_contains
    - custom_expression
  - condition_value: string/object (required)
  - true_action: template_reference
  - false_action: template_reference

Use Cases:
  - Different responses based on user data

Example:
  Check if region is set, check if form is complete
```

### 9. Send Apple Pay Request
```yaml
Parameters:
  - merchant_id: string (required)
  - item_name: string (required)
  - amount: decimal (required)
  - currency: string (default: "USD")

Use Cases:
  - Payment collection

Example:
  Guitar purchase payment
```

### 10. API Call
```yaml
Parameters:
  - url: string (required)
  - method: enum (GET, POST, PUT, DELETE)
  - headers: object (optional)
  - body: object (optional)
  - store_response_in: string (optional) - attribute name

Use Cases:
  - External API integration
  - Data fetching

Example:
  Fetch store locations, check order status
```

### 11. Send iMessage App
```yaml
Parameters:
  - app_id: string (required) - iMessage app bundle identifier
  - app_name: string (required) - Display name
  - app_icon_url: string (optional) - App icon URL
  - launch_url: string (optional) - Deep link URL
  - data: object (optional) - Data to pass to the app

Use Cases:
  - Launch iMessage extensions
  - Shazam integration
  - Custom iMessage apps

Example:
  "Open Shazam to identify this song", "Use our guitar tuner app"
```

### 12. Send App Clip
```yaml
Parameters:
  - app_clip_url: string (required) - App Clip invocation URL
  - title: string (required) - App Clip title
  - subtitle: string (optional) - App Clip description
  - image_url: string (optional) - Hero image URL
  - action_title: string (optional) - Button text (default: "Open")

Use Cases:
  - App Clip experiences
  - Temporary app installations

Example:
  "Try our guitar tuner without installing", "Book appointment via App Clip"
```

### Template Type Comparison

| Feature | Rich Link | App Clip | iMessage App |
|---------|-----------|----------|--------------|
| Opens | External URL in Safari | Lightweight app experience | iMessage extension |
| Installation | None required | Temporary iOS app card | Must be installed |
| Experience | Web page | Native-like app | Full iMessage integration |
| Size Limit | N/A | 10MB max | N/A |
| Use Case | Articles, websites | Mini-app experiences | Message extensions |

---

## 📐 Implementation Plan

### **Phase 1: Template System Foundation** (3-4 days)

#### 1.1 Backend - Template Schema & Models (Day 1)

**Create**: `app/models/bot_action_template.rb`

```ruby
# frozen_string_literal: true

# Represents a reusable action template for bot flows
# Replaces hardcoded handler methods with configurable UI-based templates
#
# @attr account_id [Integer] Account this template belongs to
# @attr name [String] Human-readable template name
# @attr template_type [String] Type of action (send_text_message, send_list_picker, etc.)
# @attr parameters [Hash] Template-specific configuration parameters
# @attr metadata [Hash] Additional metadata (description, tags, etc.)
# @attr execution_order [Integer] Order when multiple templates in sequence
#
class BotActionTemplate < ApplicationRecord
  belongs_to :account

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :template_type, presence: true, inclusion: { in: TEMPLATE_TYPES }
  validates :parameters, presence: true

  # Validate parameters based on template type
  validate :validate_template_parameters

  TEMPLATE_TYPES = %w[
    send_text_message
    send_list_picker
    send_time_picker
    send_form
    send_rich_link
    send_quick_reply
    update_attributes
    conditional_branch
    send_apple_pay
    api_call
    send_imessage_app
    send_app_clip
  ].freeze

  # Parameter schemas for each template type
  PARAMETER_SCHEMAS = {
    'send_text_message' => {
      required: %w[message],
      optional: %w[delay_seconds]
    },
    'send_list_picker' => {
      required: %w[template_id],
      optional: %w[wait_for_response]
    },
    'send_time_picker' => {
      required: %w[template_id],
      optional: %w[timezone_offset location_data]
    },
    'send_form' => {
      required: %w[template_id],
      optional: %w[pre_fill_data]
    },
    'send_rich_link' => {
      required: %w[url title],
      optional: %w[subtitle image_url]
    },
    'send_quick_reply' => {
      required: %w[message request_id items],
      optional: []
    },
    'update_attributes' => {
      required: %w[attributes],
      optional: []
    },
    'conditional_branch' => {
      required: %w[condition_type condition_value],
      optional: %w[true_action false_action]
    },
    'send_apple_pay' => {
      required: %w[merchant_id item_name amount],
      optional: %w[currency]
    },
    'api_call' => {
      required: %w[url method],
      optional: %w[headers body store_response_in]
    },
    'send_imessage_app' => {
      required: %w[app_id app_name],
      optional: %w[app_icon_url launch_url data]
    },
    'send_app_clip' => {
      required: %w[app_clip_url title],
      optional: %w[subtitle image_url action_title]
    }
  }.freeze

  private

  def validate_template_parameters
    schema = PARAMETER_SCHEMAS[template_type]
    return if schema.nil?

    # Check required parameters
    schema[:required].each do |param|
      if parameters[param].blank?
        errors.add(:parameters, "missing required parameter: #{param}")
      end
    end

    # Check for unknown parameters
    known_params = schema[:required] + schema[:optional]
    unknown = parameters.keys - known_params
    if unknown.any?
      errors.add(:parameters, "unknown parameters: #{unknown.join(', ')}")
    end
  end
end
```

**Migration**: `db/migrate/XXXXXX_create_bot_action_templates.rb`

```ruby
class CreateBotActionTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :bot_action_templates do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :template_type, null: false
      t.jsonb :parameters, null: false, default: {}
      t.jsonb :metadata, default: {}
      t.integer :execution_order, default: 0

      t.timestamps

      t.index [:account_id, :name], unique: true
      t.index :template_type
    end
  end
end
```

---

#### 1.2 Backend - Template Executor Service (Day 2)

**Create**: `app/services/apple_messages_for_business/template_executor_service.rb`

```ruby
# frozen_string_literal: true

# Executes bot action templates by routing to appropriate service methods
# Replaces direct handler method calls with template-based execution
#
# @example Execute a send_text_message template
#   template = BotActionTemplate.find_by(name: 'welcome_message')
#   executor = AppleMessagesForBusiness::TemplateExecutorService.new(
#     template,
#     conversation,
#     message
#   )
#   result = executor.execute
#
class AppleMessagesForBusiness::TemplateExecutorService
  attr_reader :template, :conversation, :message

  def initialize(template, conversation, message)
    @template = template
    @conversation = conversation
    @message = message
    @inbox = conversation.inbox
    @account = conversation.account
  end

  # Execute the template
  # @return [Integer] Number of messages sent
  def execute
    log_info "[TemplateExecutor] Executing template: #{@template.name} (type: #{@template.template_type})"

    case @template.template_type
    when 'send_text_message'
      execute_send_text_message
    when 'send_list_picker'
      execute_send_list_picker
    when 'send_time_picker'
      execute_send_time_picker
    when 'send_form'
      execute_send_form
    when 'send_rich_link'
      execute_send_rich_link
    when 'send_quick_reply'
      execute_send_quick_reply
    when 'update_attributes'
      execute_update_attributes
    when 'conditional_branch'
      execute_conditional_branch
    when 'send_apple_pay'
      execute_send_apple_pay
    when 'api_call'
      execute_api_call
    when 'send_imessage_app'
      execute_send_imessage_app
    when 'send_app_clip'
      execute_send_app_clip
    else
      log_error "[TemplateExecutor] Unknown template type: #{@template.template_type}"
      0
    end
  rescue StandardError => e
    log_error "[TemplateExecutor] Error executing template: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    0
  end

  private

  def execute_send_text_message
    params = @template.parameters

    # Add delay if specified
    sleep(params['delay_seconds']) if params['delay_seconds'].to_i > 0

    # Use existing message sending infrastructure
    AppleMessagesForBusiness::SendMessageService.new(
      conversation: @conversation,
      message: params['message']
    ).send

    1 # Return number of messages sent
  end

  def execute_send_list_picker
    params = @template.parameters

    # Find the list picker template
    list_picker_template = MessageTemplate.find_by(
      id: params['template_id'],
      account: @account
    )

    unless list_picker_template
      log_error "[TemplateExecutor] List picker template not found: #{params['template_id']}"
      return 0
    end

    # Use existing list picker service
    AppleMessagesForBusiness::SendListPickerService.new(
      conversation: @conversation,
      template: list_picker_template
    ).send

    1
  end

  def execute_send_time_picker
    params = @template.parameters

    # Find the time picker template
    time_picker_template = MessageTemplate.find_by(
      id: params['template_id'],
      account: @account
    )

    unless time_picker_template
      log_error "[TemplateExecutor] Time picker template not found: #{params['template_id']}"
      return 0
    end

    # Use existing time picker service
    AppleMessagesForBusiness::SendTimePickerService.new(
      conversation: @conversation,
      template: time_picker_template,
      timezone_offset: params['timezone_offset'],
      location_data: params['location_data']
    ).send

    1
  end

  def execute_send_form
    params = @template.parameters

    # Find the form template
    form_template = MessageTemplate.find_by(
      id: params['template_id'],
      account: @account
    )

    unless form_template
      log_error "[TemplateExecutor] Form template not found: #{params['template_id']}"
      return 0
    end

    # Use existing form service
    AppleMessagesForBusiness::FormService.new(
      conversation: @conversation,
      template: form_template,
      pre_fill_data: params['pre_fill_data']
    ).send

    1
  end

  def execute_send_rich_link
    params = @template.parameters

    # Use existing rich link service
    AppleMessagesForBusiness::SendRichLinkService.new(
      conversation: @conversation,
      url: params['url'],
      title: params['title'],
      subtitle: params['subtitle'],
      image_url: params['image_url']
    ).send

    1
  end

  def execute_send_quick_reply
    params = @template.parameters

    # Build quick reply items
    items = params['items'].map do |item|
      { title: item['title'], value: item['value'] }
    end

    # Send quick reply
    send_quick_reply_message(
      message: params['message'],
      request_id: params['request_id'],
      items: items
    )

    1
  end

  def execute_update_attributes
    params = @template.parameters

    # Update conversation custom attributes
    current_attrs = @conversation.custom_attributes || {}
    updated_attrs = current_attrs.merge(params['attributes'])

    @conversation.update!(custom_attributes: updated_attrs)

    log_info "[TemplateExecutor] Updated attributes: #{params['attributes'].keys.join(', ')}"

    0 # No messages sent
  end

  def execute_conditional_branch
    params = @template.parameters

    # Evaluate condition
    condition_met = evaluate_condition(
      params['condition_type'],
      params['condition_value']
    )

    # Execute appropriate action
    action_template_id = condition_met ? params['true_action'] : params['false_action']

    if action_template_id.present?
      action_template = BotActionTemplate.find_by(id: action_template_id, account: @account)
      if action_template
        # Recursively execute the action template
        self.class.new(action_template, @conversation, @message).execute
      end
    end

    0 # Condition itself doesn't send messages
  end

  def execute_send_apple_pay
    params = @template.parameters

    # Use existing Apple Pay service
    AppleMessagesForBusiness::SendApplePayService.new(
      conversation: @conversation,
      merchant_id: params['merchant_id'],
      item_name: params['item_name'],
      amount: params['amount'],
      currency: params['currency'] || 'USD'
    ).send

    1
  end

  def execute_api_call
    params = @template.parameters

    # Make HTTP request
    response = make_http_request(
      url: params['url'],
      method: params['method'],
      headers: params['headers'],
      body: params['body']
    )

    # Store response if requested
    if params['store_response_in'].present?
      current_attrs = @conversation.custom_attributes || {}
      current_attrs[params['store_response_in']] = response
      @conversation.update!(custom_attributes: current_attrs)
    end

    0 # API call doesn't send messages
  end

  def execute_send_imessage_app
    params = @template.parameters

    # Send iMessage app invocation
    send_imessage_app_message(
      app_id: params['app_id'],
      app_name: params['app_name'],
      app_icon_url: params['app_icon_url'],
      launch_url: params['launch_url'],
      data: params['data']
    )

    1
  end

  def execute_send_app_clip
    params = @template.parameters

    # Send App Clip invocation (uses rich link format with Apple metadata)
    send_app_clip_message(
      app_clip_url: params['app_clip_url'],
      title: params['title'],
      subtitle: params['subtitle'],
      image_url: params['image_url'],
      action_title: params['action_title'] || 'Open'
    )

    1
  end

  # Helper methods

  def evaluate_condition(condition_type, condition_value)
    case condition_type
    when 'attribute_equals'
      attr_name = condition_value['attribute']
      expected_value = condition_value['value']
      @conversation.custom_attributes&.dig(attr_name) == expected_value
    when 'attribute_contains'
      attr_name = condition_value['attribute']
      search_value = condition_value['value']
      @conversation.custom_attributes&.dig(attr_name)&.include?(search_value)
    when 'message_contains'
      search_text = condition_value['text']
      @message.content&.downcase&.include?(search_text.downcase)
    when 'custom_expression'
      # Evaluate Ruby expression (use with caution!)
      eval(condition_value['expression'])
    else
      false
    end
  rescue StandardError => e
    log_error "[TemplateExecutor] Error evaluating condition: #{e.message}"
    false
  end

  def make_http_request(url:, method:, headers: {}, body: nil)
    # TODO: Implement HTTP request logic
    # Use HTTParty or similar gem
    {}
  end

  def send_quick_reply_message(message:, request_id:, items:)
    # TODO: Implement quick reply sending
    # Use existing Apple Messages infrastructure
  end

  def send_imessage_app_message(app_id:, app_name:, app_icon_url: nil, launch_url: nil, data: nil)
    # TODO: Implement iMessage app invocation
    # Use Apple Business Chat iMessage app protocol
  end

  def send_app_clip_message(app_clip_url:, title:, subtitle: nil, image_url: nil, action_title: 'Open')
    # TODO: Implement App Clip invocation
    # Use rich link format with Apple-specific metadata
  end

  def log_info(message)
    Rails.logger.info message
  end

  def log_error(message)
    Rails.logger.error message
  end
end
```

---

#### 1.3 Backend - Update FlowExecutorService (Day 2)

**Modify**: `app/services/apple_messages_for_business/flow_executor_service.rb`

Add template execution support to the existing handler method execution:

```ruby
# Execute handler method (updated to support templates)
def execute_handler_method(handler_name)
  log_info "[FlowExecutor] 🔍 Looking for handler: #{handler_name}"

  # PRIORITY 1: Check if handler is a template reference (format: "template:123")
  if handler_name.to_s.start_with?('template:')
    template_id = handler_name.sub('template:', '').to_i
    template = BotActionTemplate.find_by(id: template_id, account: @account)

    if template
      log_info "[FlowExecutor] 📋 Found template: #{template.name}"
      return execute_template(template)
    else
      log_error "[FlowExecutor] ❌ Template not found: #{template_id}"
    end
  end

  # PRIORITY 2: Check for template by name
  template = BotActionTemplate.find_by(account: @account, name: handler_name)
  if template
    log_info "[FlowExecutor] 📋 Found template by name: #{template.name}"
    return execute_template(template)
  end

  # PRIORITY 3: Check for handler metadata (existing system)
  handler_metadata = AppleMessagesForBusiness::AcousticHouseBotService.handler_methods_metadata[handler_name.to_sym]
  if handler_metadata
    log_info "[FlowExecutor] 📋 Handler metadata found (legacy)"
    return execute_handler_via_metadata(handler_name, handler_metadata)
  end

  # PRIORITY 4: Fallback to direct service call (deprecated)
  log_warn "[FlowExecutor] ⚠️  Using deprecated handler method: #{handler_name}"
  execute_handler_via_service(handler_name)
end

# Execute template using TemplateExecutorService
def execute_template(template)
  executor = AppleMessagesForBusiness::TemplateExecutorService.new(
    template,
    @conversation,
    @message
  )

  messages_sent = executor.execute
  log_info "[FlowExecutor] ✅ Template executed, messages sent: #{messages_sent}"

  messages_sent
end
```

---

#### 1.4 Frontend - Template Configuration UI (Days 3-4)

**Create**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/ActionTemplateEditor.vue`

```vue
<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

// Template type editors
import SendTextMessageTemplate from './editors/templates/SendTextMessageTemplate.vue';
import SendListPickerTemplate from './editors/templates/SendListPickerTemplate.vue';
import SendTimePickerTemplate from './editors/templates/SendTimePickerTemplate.vue';
import SendFormTemplate from './editors/templates/SendFormTemplate.vue';
import SendRichLinkTemplate from './editors/templates/SendRichLinkTemplate.vue';
import SendQuickReplyTemplate from './editors/templates/SendQuickReplyTemplate.vue';
import UpdateAttributesTemplate from './editors/templates/UpdateAttributesTemplate.vue';
import ConditionalBranchTemplate from './editors/templates/ConditionalBranchTemplate.vue';
import SendApplePayTemplate from './editors/templates/SendApplePayTemplate.vue';
import ApiCallTemplate from './editors/templates/ApiCallTemplate.vue';
import SendIMessageAppTemplate from './editors/templates/SendIMessageAppTemplate.vue';
import SendAppClipTemplate from './editors/templates/SendAppClipTemplate.vue';

const props = defineProps({
  accountId: {
    type: Number,
    required: true,
  },
  template: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['save', 'close']);

const { t } = useI18n();

const dialogRef = ref(null);
const templateName = ref('');
const templateType = ref('');
const templateParameters = ref({});
const isLoading = ref(false);

// Template type options
const templateTypes = computed(() => [
  {
    value: 'send_text_message',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TEXT_MESSAGE.NAME'),
    description: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TEXT_MESSAGE.DESCRIPTION'),
    icon: 'i-lucide-message-square',
  },
  {
    value: 'send_list_picker',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_LIST_PICKER.NAME'),
    description: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_LIST_PICKER.DESCRIPTION'),
    icon: 'i-lucide-list',
  },
  {
    value: 'send_time_picker',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.NAME'),
    description: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.DESCRIPTION'),
    icon: 'i-lucide-clock',
  },
  {
    value: 'send_form',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.NAME'),
    description: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_FORM.DESCRIPTION'),
    icon: 'i-lucide-file-text',
  },
  {
    value: 'send_rich_link',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_RICH_LINK.NAME'),
    description: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_RICH_LINK.DESCRIPTION'),
    icon: 'i-lucide-link',
  },
  {
    value: 'send_quick_reply',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.NAME'),
    description: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.DESCRIPTION'),
    icon: 'i-lucide-message-circle',
  },
  {
    value: 'update_attributes',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.UPDATE_ATTRIBUTES.NAME'),
    description: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.UPDATE_ATTRIBUTES.DESCRIPTION'),
    icon: 'i-lucide-database',
  },
  {
    value: 'conditional_branch',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.NAME'),
    description: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.DESCRIPTION'),
    icon: 'i-lucide-git-branch',
  },
  {
    value: 'send_apple_pay',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.NAME'),
    description: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.DESCRIPTION'),
    icon: 'i-lucide-credit-card',
  },
  {
    value: 'api_call',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.NAME'),
    description: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.DESCRIPTION'),
    icon: 'i-lucide-globe',
  },
  {
    value: 'send_imessage_app',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.NAME'),
    description: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.DESCRIPTION'),
    icon: 'i-lucide-smartphone',
  },
  {
    value: 'send_app_clip',
    label: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.NAME'),
    description: t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.DESCRIPTION'),
    icon: 'i-lucide-app-window',
  },
]);

// Component map for template type editors
const editorComponentMap = {
  send_text_message: SendTextMessageTemplate,
  send_list_picker: SendListPickerTemplate,
  send_time_picker: SendTimePickerTemplate,
  send_form: SendFormTemplate,
  send_rich_link: SendRichLinkTemplate,
  send_quick_reply: SendQuickReplyTemplate,
  update_attributes: UpdateAttributesTemplate,
  conditional_branch: ConditionalBranchTemplate,
  send_apple_pay: SendApplePayTemplate,
  api_call: ApiCallTemplate,
  send_imessage_app: SendIMessageAppTemplate,
  send_app_clip: SendAppClipTemplate,
};

const selectedTypeInfo = computed(() => {
  return templateTypes.value.find(t => t.value === templateType.value);
});

const editorComponent = computed(() => {
  return editorComponentMap[templateType.value];
});

// Initialize from existing template
watch(() => props.template, (newTemplate) => {
  if (newTemplate) {
    templateName.value = newTemplate.name;
    templateType.value = newTemplate.template_type;
    templateParameters.value = newTemplate.parameters || {};
  }
}, { immediate: true });

// Reset parameters when template type changes
watch(templateType, () => {
  templateParameters.value = {};
});

const open = () => {
  dialogRef.value?.open();
};

const close = () => {
  dialogRef.value?.close();
  emit('close');
};

const save = async () => {
  if (!templateName.value || !templateType.value) {
    return;
  }

  isLoading.value = true;

  try {
    const templateData = {
      name: templateName.value,
      template_type: templateType.value,
      parameters: templateParameters.value,
    };

    emit('save', templateData);
    close();
  } catch (error) {
    console.error('[ActionTemplateEditor] Save error:', error);
  } finally {
    isLoading.value = false;
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="template ? t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.EDIT') : t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.CREATE')"
    width="7xl"
    overflow-y-auto
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="close"
  >
    <div class="flex flex-col gap-6">
      <!-- Template Name -->
      <div>
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.NAME') }} *
        </label>
        <input
          v-model="templateName"
          type="text"
          class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
          :placeholder="t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.NAME_PLACEHOLDER')"
        />
      </div>

      <!-- Template Type Selector -->
      <div>
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.SELECT_TYPE') }} *
        </label>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          <button
            v-for="type in templateTypes"
            :key="type.value"
            class="flex items-start gap-3 p-4 rounded-lg border-2 text-left transition-all"
            :class="[
              templateType === type.value
                ? 'border-n-blue-8 bg-n-blue-1'
                : 'border-n-weak hover:border-n-strong bg-n-white',
            ]"
            @click="templateType = type.value"
          >
            <div
              class="flex items-center justify-center w-10 h-10 rounded-lg transition-colors"
              :class="[
                templateType === type.value
                  ? 'bg-n-blue-8 text-white'
                  : 'bg-n-slate-2 text-n-slate-11',
              ]"
            >
              <i class="w-5 h-5" :class="[type.icon]" />
            </div>
            <div class="flex-1 min-w-0">
              <h4 class="font-semibold text-n-slate-12 mb-1">
                {{ type.label }}
              </h4>
              <p class="text-xs text-n-slate-11">
                {{ type.description }}
              </p>
            </div>
          </button>
        </div>
      </div>

      <!-- Template Parameters Editor -->
      <div v-if="templateType" class="border border-n-weak rounded-lg p-6">
        <h3 class="text-sm font-semibold text-n-slate-12 mb-4">
          {{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.PARAMETERS') }}
        </h3>

        <component
          :is="editorComponent"
          v-model="templateParameters"
          :account-id="accountId"
        />
      </div>

      <!-- Preview -->
      <div v-if="templateType" class="border border-n-weak rounded-lg p-6 bg-n-slate-1">
        <h3 class="text-sm font-semibold text-n-slate-12 mb-4">
          {{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.PREVIEW') }}
        </h3>
        <div class="text-sm text-n-slate-11">
          <p class="mb-2">
            <strong>{{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPE') }}:</strong>
            {{ selectedTypeInfo?.label }}
          </p>
          <p>
            <strong>{{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.ACTION') }}:</strong>
            {{ selectedTypeInfo?.description }}
          </p>
        </div>
      </div>

      <!-- Footer Actions -->
      <div class="flex justify-end gap-2 pt-4 border-t border-n-weak">
        <Button
          faded
          slate
          :label="t('AGENT_BOTS.FORM.CANCEL')"
          @click="close"
        />
        <Button
          :label="template ? t('AGENT_BOTS.FORM.SAVE') : t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.CREATE')"
          :disabled="!templateName || !templateType"
          :is-loading="isLoading"
          @click="save"
        />
      </div>
    </div>
  </Dialog>
</template>
```

**Create template type editor components** (simplified example):

`app/javascript/dashboard/routes/dashboard/settings/agentBots/components/editors/templates/SendTextMessageTemplate.vue`

```vue
<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: {
    type: Object,
    default: () => ({}),
  },
  accountId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const message = computed({
  get: () => props.modelValue.message || '',
  set: (value) => emit('update:modelValue', { ...props.modelValue, message: value }),
});

const delaySeconds = computed({
  get: () => props.modelValue.delay_seconds || 0,
  set: (value) => emit('update:modelValue', { ...props.modelValue, delay_seconds: value }),
});
</script>

<template>
  <div class="space-y-4">
    <!-- Message Text -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TEXT_MESSAGE.PARAMETERS.MESSAGE') }} *
      </label>
      <textarea
        v-model="message"
        rows="4"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TEXT_MESSAGE.PARAMETERS.MESSAGE_PLACEHOLDER')"
      />
    </div>

    <!-- Delay -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TEXT_MESSAGE.PARAMETERS.DELAY_SECONDS') }}
      </label>
      <input
        v-model.number="delaySeconds"
        type="number"
        min="0"
        step="0.5"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TEXT_MESSAGE.PARAMETERS.DELAY_PLACEHOLDER')"
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{ t('AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TEXT_MESSAGE.PARAMETERS.DELAY_HELP') }}
      </p>
    </div>
  </div>
</template>
```

**Note**: Similar editor components would be created for each of the 12 template types.

---

#### 1.5 I18n - Translation Keys (Day 4)

**Add to**: `app/javascript/dashboard/i18n/locale/en/agentBots.json`

```json
{
  "AGENT_BOTS": {
    "TEMPLATES": {
      "ACTION_TEMPLATES": {
        "TITLE": "Action Templates",
        "CREATE": "Create Action Template",
        "EDIT": "Edit Action Template",
        "DELETE": "Delete Action Template",
        "NAME": "Template Name",
        "NAME_PLACEHOLDER": "Enter template name...",
        "SELECT_TYPE": "Select Template Type",
        "TYPE": "Type",
        "ACTION": "Action",
        "PARAMETERS": "Parameters",
        "PREVIEW": "Preview",
        "TYPES": {
          "SEND_TEXT_MESSAGE": {
            "NAME": "Send Text Message",
            "DESCRIPTION": "Send a simple text message to the user",
            "PARAMETERS": {
              "MESSAGE": "Message",
              "MESSAGE_PLACEHOLDER": "Enter message text...",
              "DELAY_SECONDS": "Delay (seconds)",
              "DELAY_PLACEHOLDER": "0",
              "DELAY_HELP": "Optional delay before sending the message"
            }
          },
          "SEND_LIST_PICKER": {
            "NAME": "Send List Picker",
            "DESCRIPTION": "Send an interactive list picker to the user",
            "PARAMETERS": {
              "TEMPLATE_ID": "List Picker Template",
              "TEMPLATE_SELECT": "Select a list picker template",
              "WAIT_FOR_RESPONSE": "Wait for user response"
            }
          },
          "SEND_TIME_PICKER": {
            "NAME": "Send Time Picker",
            "DESCRIPTION": "Send an interactive time picker to the user",
            "PARAMETERS": {
              "TEMPLATE_ID": "Time Picker Template",
              "TEMPLATE_SELECT": "Select a time picker template",
              "TIMEZONE_OFFSET": "Timezone Offset",
              "LOCATION_DATA": "Location Data"
            }
          },
          "SEND_FORM": {
            "NAME": "Send Form",
            "DESCRIPTION": "Send an interactive form to collect user data",
            "PARAMETERS": {
              "TEMPLATE_ID": "Form Template",
              "TEMPLATE_SELECT": "Select a form template",
              "PRE_FILL_DATA": "Pre-fill Data (JSON)"
            }
          },
          "SEND_RICH_LINK": {
            "NAME": "Send Rich Link",
            "DESCRIPTION": "Send a rich link with preview image and description",
            "PARAMETERS": {
              "URL": "URL",
              "URL_PLACEHOLDER": "https://example.com",
              "TITLE": "Title",
              "TITLE_PLACEHOLDER": "Link title",
              "SUBTITLE": "Subtitle",
              "SUBTITLE_PLACEHOLDER": "Link description",
              "IMAGE_URL": "Image URL",
              "IMAGE_URL_PLACEHOLDER": "https://example.com/image.png"
            }
          },
          "SEND_QUICK_REPLY": {
            "NAME": "Send Quick Reply",
            "DESCRIPTION": "Send a message with quick reply buttons",
            "PARAMETERS": {
              "MESSAGE": "Message",
              "MESSAGE_PLACEHOLDER": "Enter message text...",
              "REQUEST_ID": "Request ID",
              "REQUEST_ID_PLACEHOLDER": "qr_example",
              "ITEMS": "Reply Items",
              "ADD_ITEM": "Add Item",
              "ITEM_TITLE": "Title",
              "ITEM_VALUE": "Value"
            }
          },
          "UPDATE_ATTRIBUTES": {
            "NAME": "Update Conversation Attributes",
            "DESCRIPTION": "Store or update data in the conversation",
            "PARAMETERS": {
              "ATTRIBUTES": "Attributes (JSON)",
              "ATTRIBUTES_PLACEHOLDER": "{\"key\": \"value\"}"
            }
          },
          "CONDITIONAL_BRANCH": {
            "NAME": "Conditional Branch",
            "DESCRIPTION": "Execute different actions based on a condition",
            "PARAMETERS": {
              "CONDITION_TYPE": "Condition Type",
              "CONDITION_VALUE": "Condition Value",
              "TRUE_ACTION": "Action if True",
              "FALSE_ACTION": "Action if False"
            }
          },
          "SEND_APPLE_PAY": {
            "NAME": "Send Apple Pay Request",
            "DESCRIPTION": "Request payment via Apple Pay",
            "PARAMETERS": {
              "MERCHANT_ID": "Merchant ID",
              "MERCHANT_ID_PLACEHOLDER": "merchant.com.example",
              "ITEM_NAME": "Item Name",
              "ITEM_NAME_PLACEHOLDER": "Guitar Lesson",
              "AMOUNT": "Amount",
              "AMOUNT_PLACEHOLDER": "99.99",
              "CURRENCY": "Currency",
              "CURRENCY_PLACEHOLDER": "USD"
            }
          },
          "API_CALL": {
            "NAME": "API Call",
            "DESCRIPTION": "Make an HTTP request to an external API",
            "PARAMETERS": {
              "URL": "URL",
              "URL_PLACEHOLDER": "https://api.example.com/endpoint",
              "METHOD": "HTTP Method",
              "HEADERS": "Headers (JSON)",
              "HEADERS_PLACEHOLDER": "{\"Authorization\": \"Bearer token\"}",
              "BODY": "Request Body (JSON)",
              "BODY_PLACEHOLDER": "{\"key\": \"value\"}",
              "STORE_RESPONSE_IN": "Store Response In",
              "STORE_RESPONSE_IN_PLACEHOLDER": "api_response"
            }
          },
          "SEND_IMESSAGE_APP": {
            "NAME": "Send iMessage App",
            "DESCRIPTION": "Launch an iMessage app or extension",
            "PARAMETERS": {
              "APP_ID": "App Bundle ID",
              "APP_ID_PLACEHOLDER": "com.example.app.MessagesExtension",
              "APP_NAME": "App Name",
              "APP_NAME_PLACEHOLDER": "Guitar Tuner",
              "APP_ICON_URL": "App Icon URL",
              "APP_ICON_URL_PLACEHOLDER": "https://example.com/icon.png",
              "LAUNCH_URL": "Launch URL (optional)",
              "LAUNCH_URL_PLACEHOLDER": "imessage-app://open?feature=tuner",
              "DATA": "App Data (JSON)",
              "DATA_PLACEHOLDER": "{\"mode\": \"tune\", \"instrument\": \"guitar\"}"
            }
          },
          "SEND_APP_CLIP": {
            "NAME": "Send App Clip",
            "DESCRIPTION": "Send an App Clip invocation link for lightweight app experience",
            "PARAMETERS": {
              "APP_CLIP_URL": "App Clip URL",
              "APP_CLIP_URL_PLACEHOLDER": "https://example.com/clips/guitar-tuner",
              "TITLE": "Title",
              "TITLE_PLACEHOLDER": "Try our Guitar Tuner",
              "SUBTITLE": "Subtitle",
              "SUBTITLE_PLACEHOLDER": "Tune your guitar without installing an app",
              "IMAGE_URL": "Hero Image URL",
              "IMAGE_URL_PLACEHOLDER": "https://example.com/hero.png",
              "ACTION_TITLE": "Button Text",
              "ACTION_TITLE_PLACEHOLDER": "Open"
            }
          }
        }
      }
    }
  }
}
```

**Add to**: `config/locales/en.yml`

```yaml
en:
  agent_bots:
    action_templates:
      created: "Action template created successfully"
      updated: "Action template updated successfully"
      deleted: "Action template deleted successfully"
      errors:
        invalid_template_type: "Invalid template type"
        missing_parameters: "Missing required parameters: %{params}"
        template_not_found: "Template not found"
        invalid_parameters: "Invalid parameters for template type %{type}"
```

---

### **Phase 2: Migration from Existing Handlers** (2-3 days)

#### 2.1 Handler Analysis & Template Creation (Day 5)

**Create migration script**: `script/migrate_handlers_to_templates.rb`

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# Migration script to convert existing handlers to action templates
# Usage: rails runner script/migrate_handlers_to_templates.rb [--execute]
#
# By default runs in dry-run mode. Pass --execute to actually create templates.

require 'json'

# Handler to template mappings
# Each handler maps to one or more action templates that execute in sequence
HANDLER_MAPPINGS = {
  handle_welcome: [
    {
      name: 'welcome_message_1',
      template_type: 'send_text_message',
      parameters: {
        'message' => 'Thank you for contacting Acoustic Bot Prod.'
      },
      execution_order: 0
    },
    {
      name: 'welcome_message_2',
      template_type: 'send_text_message',
      parameters: {
        'message' => "Let's help you find your next guitar 🎸."
      },
      execution_order: 1
    },
    {
      name: 'welcome_region_prompt',
      template_type: 'send_quick_reply',
      parameters: {
        'message' => 'Which region are you traveling from?',
        'request_id' => 'qr_travel',
        'items' => [
          { 'title' => 'Americas', 'value' => 'Americas' },
          { 'title' => 'EMEA', 'value' => 'EMEA' },
          { 'title' => 'APAC', 'value' => 'APAC' }
        ]
      },
      execution_order: 2
    }
  ],

  handle_menu: [
    {
      name: 'menu_list_picker',
      template_type: 'send_list_picker',
      parameters: {
        # Will be filled in with actual template ID during migration
        'template_id' => 'PLACEHOLDER_ah_main_menu',
        'wait_for_response' => true
      },
      execution_order: 0
    }
  ],

  handle_list_picker_demo: [
    {
      name: 'list_picker_demo_intro',
      template_type: 'send_text_message',
      parameters: {
        'message' => 'Here are some amazing guitars:'
      },
      execution_order: 0
    },
    {
      name: 'list_picker_demo_picker',
      template_type: 'send_list_picker',
      parameters: {
        'template_id' => 'PLACEHOLDER_ah_guitar_list_picker',
        'wait_for_response' => true
      },
      execution_order: 1
    }
  ],

  handle_time_picker_demo: [
    {
      name: 'time_picker_demo_intro',
      template_type: 'send_text_message',
      parameters: {
        'message' => "Here's a time picker demo:"
      },
      execution_order: 0
    },
    {
      name: 'time_picker_demo_picker',
      template_type: 'send_time_picker',
      parameters: {
        'template_id' => 'PLACEHOLDER_time_picker_template',
        'timezone_offset' => -28800, # Pacific Time
        'location_data' => {
          'name' => 'Apple Park',
          'latitude' => 37.334606,
          'longitude' => -122.009102
        }
      },
      execution_order: 1
    }
  ],

  handle_form_demo: [
    {
      name: 'form_demo_intro',
      template_type: 'send_text_message',
      parameters: {
        'message' => "Here's our guitar information form:"
      },
      execution_order: 0
    },
    {
      name: 'form_demo_form',
      template_type: 'send_form',
      parameters: {
        'template_id' => 'PLACEHOLDER_ah_guitar_info_form'
      },
      execution_order: 1
    }
  ],

  handle_apple_pay_demo: [
    {
      name: 'apple_pay_demo_intro',
      template_type: 'send_text_message',
      parameters: {
        'message' => "Here's an Apple Pay payment request:"
      },
      execution_order: 0
    },
    {
      name: 'apple_pay_demo_request',
      template_type: 'send_apple_pay',
      parameters: {
        'merchant_id' => 'merchant.com.example',
        'item_name' => 'Demo Guitar - Fender Stratocaster',
        'amount' => 1299.99,
        'currency' => 'USD'
      },
      execution_order: 1
    }
  ],

  handle_ar_demo: [
    {
      name: 'ar_demo_intro',
      template_type: 'send_text_message',
      parameters: {
        'message' => 'Check out our AR experience:'
      },
      execution_order: 0
    },
    {
      name: 'ar_demo_link',
      template_type: 'send_rich_link',
      parameters: {
        'url' => 'https://example.com/ar/guitar',
        'title' => 'View Guitar in AR',
        'subtitle' => 'See the guitar in your space',
        'image_url' => 'https://example.com/ar-preview.png'
      },
      execution_order: 1
    }
  ],

  handle_imessage_app: [
    {
      name: 'imessage_app_intro',
      template_type: 'send_text_message',
      parameters: {
        'message' => 'Here are some iMessage apps you can try:'
      },
      execution_order: 0
    },
    {
      name: 'imessage_app_shazam',
      template_type: 'send_imessage_app',
      parameters: {
        'app_id' => 'com.shazam.Shazam.MessagesExtension',
        'app_name' => 'Shazam',
        'app_icon_url' => 'https://example.com/shazam-icon.png',
        'launch_url' => 'shazam://identify'
      },
      execution_order: 1
    }
  ],

  handle_app_clip_demo: [
    {
      name: 'app_clip_demo_intro',
      template_type: 'send_text_message',
      parameters: {
        'message' => 'Try our App Clip experience:'
      },
      execution_order: 0
    },
    {
      name: 'app_clip_demo_clip',
      template_type: 'send_app_clip',
      parameters: {
        'app_clip_url' => 'https://acoustichouse.example.com/clips/guitar-tuner',
        'title' => 'Acoustic House Guitar Tuner',
        'subtitle' => 'Tune your guitar without installing an app',
        'image_url' => 'https://example.com/tuner-hero.png',
        'action_title' => 'Try Now'
      },
      execution_order: 1
    }
  ],

  handle_region_selection: [
    {
      name: 'region_store_attribute',
      template_type: 'update_attributes',
      parameters: {
        'attributes' => {
          'selected_region' => '{{user_selection}}'
        }
      },
      execution_order: 0
    },
    {
      name: 'region_confirmation',
      template_type: 'send_text_message',
      parameters: {
        'message' => "Great! You're traveling from {{region}}."
      },
      execution_order: 1
    }
  ],

  handle_guitar_selection: [
    {
      name: 'guitar_store_attribute',
      template_type: 'update_attributes',
      parameters: {
        'attributes' => {
          'selected_guitar' => '{{user_selection}}'
        }
      },
      execution_order: 0
    },
    {
      name: 'guitar_confirmation',
      template_type: 'send_text_message',
      parameters: {
        'message' => "Excellent choice! The {{guitar}} is a fantastic instrument."
      },
      execution_order: 1
    }
  ],

  handle_store_selection: [
    {
      name: 'store_save_attribute',
      template_type: 'update_attributes',
      parameters: {
        'attributes' => {
          'selected_store' => '{{user_selection}}'
        }
      },
      execution_order: 0
    },
    {
      name: 'store_send_time_picker',
      template_type: 'send_time_picker',
      parameters: {
        'template_id' => 'PLACEHOLDER_time_picker_template',
        'timezone_offset' => '{{store_timezone}}'
      },
      execution_order: 1
    }
  ]
}.freeze

class HandlerToTemplateMigration
  def initialize(dry_run: true)
    @dry_run = dry_run
    @stats = {
      accounts_processed: 0,
      templates_created: 0,
      templates_skipped: 0,
      errors: []
    }
  end

  def run
    puts "=" * 80
    puts "Handler to Template Migration"
    puts "=" * 80
    puts "Mode: #{@dry_run ? 'DRY RUN' : 'EXECUTE'}"
    puts

    Account.find_each do |account|
      process_account(account)
    end

    print_summary
  end

  private

  def process_account(account)
    puts "\n--- Processing Account: #{account.name} (ID: #{account.id}) ---"

    # Resolve template placeholders
    template_map = resolve_template_placeholders(account)

    HANDLER_MAPPINGS.each do |handler_name, template_configs|
      template_configs.each do |config|
        process_template(account, handler_name, config, template_map)
      end
    end

    @stats[:accounts_processed] += 1
  end

  def resolve_template_placeholders(account)
    # Map placeholder names to actual template IDs for this account
    template_names = %w[
      ah_main_menu
      ah_guitar_list_picker
      ah_guitar_info_form
      time_picker_template
    ]

    map = {}
    template_names.each do |name|
      template = MessageTemplate.find_by(account: account, name: name)
      if template
        map["PLACEHOLDER_#{name}"] = template.id
      else
        puts "  ⚠️  Warning: Template '#{name}' not found for account #{account.id}"
      end
    end

    map
  end

  def process_template(account, handler_name, config, template_map)
    template_name = "#{handler_name}_#{config[:name]}"

    # Check if template already exists
    existing = BotActionTemplate.find_by(account: account, name: template_name)
    if existing
      puts "  ⏭️  Skipping #{template_name} (already exists)"
      @stats[:templates_skipped] += 1
      return
    end

    # Replace placeholders with actual template IDs
    parameters = deep_replace_placeholders(config[:parameters], template_map)

    if @dry_run
      puts "  📋 Would create: #{template_name}"
      puts "     Type: #{config[:template_type]}"
      puts "     Parameters: #{parameters.inspect}"
    else
      begin
        BotActionTemplate.create!(
          account: account,
          name: template_name,
          template_type: config[:template_type],
          parameters: parameters,
          execution_order: config[:execution_order],
          metadata: {
            migrated_from: handler_name.to_s,
            migration_date: Time.current.iso8601
          }
        )
        puts "  ✅ Created: #{template_name}"
        @stats[:templates_created] += 1
      rescue StandardError => e
        error_msg = "Failed to create #{template_name}: #{e.message}"
        puts "  ❌ #{error_msg}"
        @stats[:errors] << error_msg
      end
    end
  end

  def deep_replace_placeholders(obj, template_map)
    case obj
    when Hash
      obj.transform_values { |v| deep_replace_placeholders(v, template_map) }
    when Array
      obj.map { |v| deep_replace_placeholders(v, template_map) }
    when String
      template_map[obj] || obj
    else
      obj
    end
  end

  def print_summary
    puts "\n" + "=" * 80
    puts "Migration Summary"
    puts "=" * 80
    puts "Accounts processed: #{@stats[:accounts_processed]}"
    puts "Templates created: #{@stats[:templates_created]}"
    puts "Templates skipped: #{@stats[:templates_skipped]}"
    puts "Errors: #{@stats[:errors].count}"

    if @stats[:errors].any?
      puts "\nErrors:"
      @stats[:errors].each do |error|
        puts "  - #{error}"
      end
    end

    if @dry_run
      puts "\n⚠️  This was a DRY RUN. No changes were made."
      puts "   Run with --execute to apply changes."
    else
      puts "\n✅ Migration complete!"
    end
    puts "=" * 80
  end
end

# Run migration
dry_run = !ARGV.include?('--execute')
migration = HandlerToTemplateMigration.new(dry_run: dry_run)
migration.run
```

---

#### 2.2 Create Master Reference Bot (Day 5)

**Create**: `script/create_acoustic_house_master_bot.rb`

This script creates the "Acoustic House - Demo - Master" bot with the complete visual flow converted from `acoustic_house_bot_service.rb`.

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# Creates the "Acoustic House - Demo - Master" reference bot
# This bot demonstrates the full template-based handler system
# and serves as a reference for creating new bots
#
# Usage: rails runner script/create_acoustic_house_master_bot.rb [account_id]
#
# The bot will be accessible via: /app/accounts/{account_id}/settings/agent-bots

class AcousticHouseMasterBotCreator
  attr_reader :account, :agent_bot, :bot_flow, :templates, :nodes, :edges

  def initialize(account_id)
    @account = Account.find(account_id)
    @templates = {}
    @nodes = {}
    @edges = []
    @node_id_counter = 0
  end

  def create
    puts "=" * 80
    puts "Creating Acoustic House - Demo - Master Bot"
    puts "=" * 80
    puts "Account: #{@account.name} (ID: #{@account.id})"
    puts

    ActiveRecord::Base.transaction do
      create_agent_bot
      create_action_templates
      create_bot_flow
      create_flow_nodes_and_edges
      save_flow

      print_summary
    end

    puts "\n✅ Bot created successfully!"
    puts "   Access at: /app/accounts/#{@account.id}/settings/agent-bots"
    puts "=" * 80

    @agent_bot
  rescue StandardError => e
    puts "\n❌ Error creating bot: #{e.message}"
    puts e.backtrace.join("\n")
    raise
  end

  private

  # Step 1: Create the AgentBot record
  def create_agent_bot
    puts "📝 Creating AgentBot record..."

    @agent_bot = AgentBot.create!(
      account: @account,
      name: 'Acoustic House - Demo - Master',
      description: 'Reference implementation of template-based bot system. Demonstrates all 12 template types and complete visual flow architecture.',
      outgoing_url: nil,
      bot_type: :apple_messages,
      bot_config: {
        conversation_flow: {
          initial_state: 'AHA1',
          idle_timeout_minutes: 30
        },
        features: {
          typing_indicators: true,
          typing_delay_seconds: 1.5,
          auto_resolve: false
        },
        metadata: {
          version: '2.0',
          architecture: 'template_based',
          created_by: 'migration_script',
          reference_bot: true
        }
      }
    )

    puts "   ✅ AgentBot created (ID: #{@agent_bot.id})"
  end

  # Step 2: Create all action templates for handlers
  def create_action_templates
    puts "\n📋 Creating action templates..."

    # Welcome flow templates
    create_template('welcome_message_1', 'send_text_message',
                    { 'message' => 'Thank you for contacting Acoustic Bot Prod.' })

    create_template('welcome_message_2', 'send_text_message',
                    { 'message' => "Let's help you find your next guitar 🎸." })

    create_template('region_prompt', 'send_quick_reply',
                    {
                      'message' => 'Which region are you traveling from?',
                      'request_id' => 'qr_travel',
                      'items' => [
                        { 'title' => 'Americas', 'value' => 'Americas' },
                        { 'title' => 'EMEA', 'value' => 'EMEA' },
                        { 'title' => 'APAC', 'value' => 'APAC' }
                      ]
                    })

    # Region selection templates
    create_template('save_region', 'update_attributes',
                    { 'attributes' => { 'selected_region' => '{{user_selection}}' } })

    create_template('region_confirmation', 'send_text_message',
                    { 'message' => "Great! You're traveling from {{region}}." })

    create_template('name_preference_prompt', 'send_quick_reply',
                    {
                      'message' => 'How should we address you?',
                      'request_id' => 'qr_name',
                      'items' => [
                        { 'title' => 'First Name', 'value' => 'first_name' },
                        { 'title' => 'Full Name', 'value' => 'full_name' },
                        { 'title' => 'Preferred Name', 'value' => 'preferred_name' }
                      ]
                    })

    # Guitar selection templates
    create_template('guitar_list_picker', 'send_list_picker',
                    { 'template_id' => find_template_id('ah_guitar_list_picker') })

    create_template('save_guitar', 'update_attributes',
                    { 'attributes' => { 'selected_guitar' => '{{user_selection}}' } })

    create_template('guitar_confirmation', 'send_text_message',
                    { 'message' => "Excellent choice! The {{guitar}} is a fantastic instrument." })

    # AR experience templates
    create_template('ar_view_prompt', 'send_quick_reply',
                    {
                      'message' => 'Would you like to see the guitar in AR?',
                      'request_id' => 'qr_view_ar',
                      'items' => [
                        { 'title' => 'Yes, view in AR', 'value' => 'yes' },
                        { 'title' => 'No, continue', 'value' => 'no' }
                      ]
                    })

    create_template('send_ar_file', 'send_rich_link',
                    {
                      'url' => 'https://example.com/ar/guitar.usdz',
                      'title' => 'View Guitar in AR',
                      'subtitle' => 'See the guitar in your space',
                      'image_url' => 'https://example.com/ar-preview.png'
                    })

    create_template('ar_place_prompt', 'send_quick_reply',
                    {
                      'message' => 'Would you like to place it in your space?',
                      'request_id' => 'qr_place_ar',
                      'items' => [
                        { 'title' => 'Yes, place it', 'value' => 'yes' },
                        { 'title' => 'No, thanks', 'value' => 'no' }
                      ]
                    })

    # Guitar info form templates
    create_template('guitar_info_form', 'send_form',
                    { 'template_id' => find_template_id('ah_guitar_info_form') })

    create_template('form_received_message', 'send_text_message',
                    { 'message' => "Thanks! We've received your information." })

    # Store selection templates
    create_template('store_selection_list', 'send_list_picker',
                    { 'template_id' => find_template_id('ah_main_menu') })

    create_template('save_store', 'update_attributes',
                    { 'attributes' => { 'selected_store' => '{{user_selection}}' } })

    # Time picker templates
    create_template('lesson_time_picker', 'send_time_picker',
                    {
                      'template_id' => find_template_id('time_picker_template'),
                      'timezone_offset' => -28800
                    })

    create_template('save_appointment', 'update_attributes',
                    { 'attributes' => { 'appointment_time' => '{{selected_time}}' } })

    create_template('appointment_confirmation', 'send_text_message',
                    { 'message' => "Perfect! Your lesson is scheduled for {{time}}." })

    # Continue prompt templates
    create_template('continue_prompt', 'send_quick_reply',
                    {
                      'message' => 'Would you like to continue to payment?',
                      'request_id' => 'qr_continue',
                      'items' => [
                        { 'title' => 'Yes, continue', 'value' => 'yes' },
                        { 'title' => 'Skip for now', 'value' => 'skip' }
                      ]
                    })

    # Photo prompt templates
    create_template('photo_prompt', 'send_quick_reply',
                    {
                      'message' => 'Would you like to share a photo of yourself?',
                      'request_id' => 'qr_photo',
                      'items' => [
                        { 'title' => 'Yes, upload photo', 'value' => 'yes' },
                        { 'title' => 'Skip', 'value' => 'skip' }
                      ]
                    })

    # Apple Pay templates
    create_template('apple_pay_request', 'send_apple_pay',
                    {
                      'merchant_id' => 'merchant.com.example',
                      'item_name' => 'Guitar Lesson - {{guitar}}',
                      'amount' => 149.99,
                      'currency' => 'USD'
                    })

    create_template('payment_success', 'send_text_message',
                    { 'message' => '✅ Payment received! Thank you for your purchase.' })

    create_template('payment_skipped', 'send_text_message',
                    { 'message' => "No problem! You can complete payment later." })

    # Learn more templates
    create_template('learn_more_prompt', 'send_quick_reply',
                    {
                      'message' => 'Would you like to learn more about our services?',
                      'request_id' => 'qr_learn_more',
                      'items' => [
                        { 'title' => 'Yes, tell me more', 'value' => 'yes' },
                        { 'title' => 'No, thanks', 'value' => 'no' }
                      ]
                    })

    # Summary templates
    create_template('send_summary', 'send_list_picker',
                    { 'template_id' => find_template_id('ah_summary') })

    create_template('final_message', 'send_text_message',
                    { 'message' => "Thank you! We'll see you soon at {{store}} for your {{guitar}} lesson!" })

    # Demo mode templates
    create_template('menu_list_picker', 'send_list_picker',
                    { 'template_id' => find_template_id('ah_main_menu') })

    create_template('list_picker_demo_intro', 'send_text_message',
                    { 'message' => 'Here are some amazing guitars:' })

    create_template('time_picker_demo_intro', 'send_text_message',
                    { 'message' => "Here's a time picker demo:" })

    create_template('form_demo_intro', 'send_text_message',
                    { 'message' => "Here's our guitar information form:" })

    create_template('apple_pay_demo_intro', 'send_text_message',
                    { 'message' => "Here's an Apple Pay payment request:" })

    create_template('ar_demo_intro', 'send_text_message',
                    { 'message' => 'Check out our AR experience:' })

    create_template('imessage_app_intro', 'send_text_message',
                    { 'message' => 'Here are some iMessage apps you can try:' })

    create_template('imessage_app_shazam', 'send_imessage_app',
                    {
                      'app_id' => 'com.shazam.Shazam.MessagesExtension',
                      'app_name' => 'Shazam',
                      'launch_url' => 'shazam://identify'
                    })

    create_template('app_clip_intro', 'send_text_message',
                    { 'message' => 'Try our App Clip experience:' })

    create_template('app_clip_tuner', 'send_app_clip',
                    {
                      'app_clip_url' => 'https://acoustichouse.example.com/clips/tuner',
                      'title' => 'Acoustic House Guitar Tuner',
                      'subtitle' => 'Tune your guitar without installing an app',
                      'action_title' => 'Try Now'
                    })

    create_template('large_form_intro', 'send_text_message',
                    { 'message' => "Here's a larger form example:" })

    create_template('large_form', 'send_form',
                    { 'template_id' => find_template_id('ah_large_form_demo') })

    puts "   ✅ Created #{@templates.size} action templates"
  end

  # Step 3: Create the BotFlow record
  def create_bot_flow
    puts "\n🔄 Creating BotFlow..."

    @bot_flow = BotFlow.create!(
      account: @account,
      agent_bot: @agent_bot,
      name: 'Main Flow',
      description: 'Complete Acoustic House bot flow with all states and transitions',
      flow_data: { nodes: [], edges: [] }, # Will be populated later
      is_active: true
    )

    puts "   ✅ BotFlow created (ID: #{@bot_flow.id})"
  end

  # Step 4: Create all flow nodes and edges
  def create_flow_nodes_and_edges
    puts "\n🎨 Creating flow nodes and edges..."

    # Create all state nodes
    create_state_nodes
    create_intent_nodes
    create_action_nodes

    # Create edges (connections)
    create_flow_edges

    puts "   ✅ Created #{@nodes.size} nodes and #{@edges.size} edges"
  end

  # Create all state nodes from the bot state machine
  def create_state_nodes
    # AHA1: Initial welcome state
    create_node('state_aha1', 'state', {
                  state_id: 'AHA1',
                  label: 'Welcome',
                  description: 'Initial greeting and setup',
                  is_initial: true,
                  actions: [
                    { type: 'execute_template', template_id: @templates['welcome_message_1'].id },
                    { type: 'execute_template', template_id: @templates['welcome_message_2'].id }
                  ]
                }, 100, 100)

    # AHA2: Region selection
    create_node('state_aha2', 'state', {
                  state_id: 'AHA2',
                  label: 'Region Prompt',
                  description: 'Ask for travel region',
                  actions: [
                    { type: 'execute_template', template_id: @templates['region_prompt'].id }
                  ]
                }, 400, 100)

    # AHB1: Name preference (after region selection)
    create_node('state_ahb1', 'state', {
                  state_id: 'AHB1',
                  label: 'Name Preference',
                  description: 'Ask for name preference',
                  actions: [
                    { type: 'execute_template', template_id: @templates['save_region'].id },
                    { type: 'execute_template', template_id: @templates['region_confirmation'].id },
                    { type: 'execute_template', template_id: @templates['name_preference_prompt'].id }
                  ]
                }, 700, 100)

    # AHC1: Guitar selection
    create_node('state_ahc1', 'state', {
                  state_id: 'AHC1',
                  label: 'Guitar Selection',
                  description: 'Show guitar list picker',
                  actions: [
                    { type: 'execute_template', template_id: @templates['guitar_list_picker'].id }
                  ]
                }, 1000, 100)

    # AHD1: AR View prompt
    create_node('state_ahd1', 'state', {
                  state_id: 'AHD1',
                  label: 'AR View Prompt',
                  description: 'Ask if user wants AR view',
                  actions: [
                    { type: 'execute_template', template_id: @templates['save_guitar'].id },
                    { type: 'execute_template', template_id: @templates['guitar_confirmation'].id },
                    { type: 'execute_template', template_id: @templates['ar_view_prompt'].id }
                  ]
                }, 1300, 100)

    # AHE1: AR Place prompt
    create_node('state_ahe1', 'state', {
                  state_id: 'AHE1',
                  label: 'AR Place Prompt',
                  description: 'Ask if user wants to place in space',
                  actions: [
                    { type: 'execute_template', template_id: @templates['send_ar_file'].id },
                    { type: 'execute_template', template_id: @templates['ar_place_prompt'].id }
                  ]
                }, 1600, 100)

    # AHB1_2: Guitar info form
    create_node('state_ahb1_2', 'state', {
                  state_id: 'AHB1_2',
                  label: 'Guitar Info Form',
                  description: 'Collect additional information',
                  actions: [
                    { type: 'execute_template', template_id: @templates['guitar_info_form'].id }
                  ]
                }, 1900, 100)

    # AHG1: Store selection
    create_node('state_ahg1', 'state', {
                  state_id: 'AHG1',
                  label: 'Store Selection',
                  description: 'Choose store location',
                  actions: [
                    { type: 'execute_template', template_id: @templates['form_received_message'].id },
                    { type: 'execute_template', template_id: @templates['store_selection_list'].id }
                  ]
                }, 2200, 100)

    # AHH1: Lesson time picker
    create_node('state_ahh1', 'state', {
                  state_id: 'AHH1',
                  label: 'Schedule Lesson',
                  description: 'Pick lesson time',
                  actions: [
                    { type: 'execute_template', template_id: @templates['save_store'].id },
                    { type: 'execute_template', template_id: @templates['lesson_time_picker'].id }
                  ]
                }, 2500, 100)

    # AHI1: Continue to payment
    create_node('state_ahi1', 'state', {
                  state_id: 'AHI1',
                  label: 'Continue Prompt',
                  description: 'Ask to continue to payment',
                  actions: [
                    { type: 'execute_template', template_id: @templates['save_appointment'].id },
                    { type: 'execute_template', template_id: @templates['appointment_confirmation'].id },
                    { type: 'execute_template', template_id: @templates['continue_prompt'].id }
                  ]
                }, 2800, 100)

    # AHJ1: Photo prompt
    create_node('state_ahj1', 'state', {
                  state_id: 'AHJ1',
                  label: 'Photo Upload',
                  description: 'Ask for photo upload',
                  actions: [
                    { type: 'execute_template', template_id: @templates['photo_prompt'].id }
                  ]
                }, 3100, 100)

    # AHF1: Apple Pay
    create_node('state_ahf1', 'state', {
                  state_id: 'AHF1',
                  label: 'Payment',
                  description: 'Apple Pay request',
                  actions: [
                    { type: 'execute_template', template_id: @templates['apple_pay_request'].id }
                  ]
                }, 3400, 100)

    # AHK1: Learn more prompt
    create_node('state_ahk1', 'state', {
                  state_id: 'AHK1',
                  label: 'Learn More',
                  description: 'Offer additional information',
                  actions: [
                    { type: 'execute_template', template_id: @templates['payment_success'].id },
                    { type: 'execute_template', template_id: @templates['learn_more_prompt'].id }
                  ]
                }, 3700, 100)

    # AHL1: Summary
    create_node('state_ahl1', 'state', {
                  state_id: 'AHL1',
                  label: 'Summary',
                  description: 'Show summary and finish',
                  actions: [
                    { type: 'execute_template', template_id: @templates['send_summary'].id },
                    { type: 'execute_template', template_id: @templates['final_message'].id }
                  ]
                }, 4000, 100)

    # Demo mode states
    create_node('state_demo', 'state', {
                  state_id: 'DEMO_MODE',
                  label: 'Demo Mode',
                  description: 'Standalone demo state',
                  actions: []
                }, 2000, 400)

    create_node('state_demo_large_form', 'state', {
                  state_id: 'DEMO_MODE_LARGE_FORM',
                  label: 'Large Form Demo',
                  description: 'Large form demo state',
                  actions: [
                    { type: 'execute_template', template_id: @templates['large_form_intro'].id },
                    { type: 'execute_template', template_id: @templates['large_form'].id }
                  ]
                }, 2300, 400)
  end

  # Create intent nodes for keywords
  def create_intent_nodes
    # Global intents
    create_node('intent_menu', 'intent', {
                  label: 'Show Menu',
                  keywords: ['menu'],
                  scope: 'global',
                  exact_match: false,
                  case_sensitive: false
                }, 500, 500)

    create_node('intent_start_over', 'intent', {
                  label: 'Start Over',
                  keywords: ['start', 'startover', 'start over', 'restart', 'begin', 'reset'],
                  scope: 'global',
                  exact_match: false,
                  case_sensitive: false
                }, 800, 500)

    create_node('intent_stop', 'intent', {
                  label: 'Stop Bot',
                  keywords: ['stop'],
                  scope: 'global',
                  exact_match: false,
                  case_sensitive: false
                }, 1100, 500)

    create_node('intent_summary', 'intent', {
                  label: 'Show Summary',
                  keywords: ['summary'],
                  scope: 'global',
                  exact_match: false,
                  case_sensitive: false
                }, 1400, 500)

    # Demo mode intents
    create_node('intent_list_picker_demo', 'intent', {
                  label: 'List Picker Demo',
                  keywords: ['list picker', 'listpicker', 'guitar', 'guitars'],
                  scope: 'global',
                  exact_match: false,
                  case_sensitive: false
                }, 1700, 500)

    create_node('intent_time_picker_demo', 'intent', {
                  label: 'Time Picker Demo',
                  keywords: ['time picker', 'timepicker'],
                  scope: 'global',
                  exact_match: false,
                  case_sensitive: false
                }, 2000, 500)

    create_node('intent_form_demo', 'intent', {
                  label: 'Form Demo',
                  keywords: ['form', 'help me decide'],
                  scope: 'global',
                  exact_match: false,
                  case_sensitive: false
                }, 2300, 500)

    create_node('intent_apple_pay_demo', 'intent', {
                  label: 'Apple Pay Demo',
                  keywords: ['apple pay', 'payment', 'pay'],
                  scope: 'global',
                  exact_match: false,
                  case_sensitive: false
                }, 2600, 500)

    create_node('intent_ar_demo', 'intent', {
                  label: 'AR Demo',
                  keywords: ['ar', 'augmented reality'],
                  scope: 'global',
                  exact_match: false,
                  case_sensitive: false
                }, 2900, 500)

    create_node('intent_imessage_app', 'intent', {
                  label: 'iMessage App Demo',
                  keywords: ['imessage app', 'imessage extension', 'shazam'],
                  scope: 'global',
                  exact_match: false,
                  case_sensitive: false
                }, 3200, 500)

    create_node('intent_app_clip', 'intent', {
                  label: 'App Clip Demo',
                  keywords: ['appclip', 'app clip'],
                  scope: 'global',
                  exact_match: false,
                  case_sensitive: false
                }, 3500, 500)

    create_node('intent_large_form', 'intent', {
                  label: 'Large Form Demo',
                  keywords: ['large form', 'big form'],
                  scope: 'global',
                  exact_match: false,
                  case_sensitive: false
                }, 3800, 500)
  end

  # Create action nodes for demo modes
  def create_action_nodes
    # Menu action
    create_node('action_menu', 'action', {
                  label: 'Send Menu',
                  action_type: 'execute_template',
                  template_id: @templates['menu_list_picker'].id
                }, 500, 700)

    # Demo mode actions
    create_node('action_list_picker_demo', 'action', {
                  label: 'List Picker Demo',
                  action_type: 'execute_templates',
                  template_ids: [
                    @templates['list_picker_demo_intro'].id,
                    @templates['guitar_list_picker'].id
                  ]
                }, 1700, 700)

    create_node('action_time_picker_demo', 'action', {
                  label: 'Time Picker Demo',
                  action_type: 'execute_templates',
                  template_ids: [
                    @templates['time_picker_demo_intro'].id,
                    @templates['lesson_time_picker'].id
                  ]
                }, 2000, 700)

    create_node('action_form_demo', 'action', {
                  label: 'Form Demo',
                  action_type: 'execute_templates',
                  template_ids: [
                    @templates['form_demo_intro'].id,
                    @templates['guitar_info_form'].id
                  ]
                }, 2300, 700)

    create_node('action_apple_pay_demo', 'action', {
                  label: 'Apple Pay Demo',
                  action_type: 'execute_templates',
                  template_ids: [
                    @templates['apple_pay_demo_intro'].id,
                    @templates['apple_pay_request'].id
                  ]
                }, 2600, 700)

    create_node('action_ar_demo', 'action', {
                  label: 'AR Demo',
                  action_type: 'execute_templates',
                  template_ids: [
                    @templates['ar_demo_intro'].id,
                    @templates['send_ar_file'].id
                  ]
                }, 2900, 700)

    create_node('action_imessage_app', 'action', {
                  label: 'iMessage App Demo',
                  action_type: 'execute_templates',
                  template_ids: [
                    @templates['imessage_app_intro'].id,
                    @templates['imessage_app_shazam'].id
                  ]
                }, 3200, 700)

    create_node('action_app_clip', 'action', {
                  label: 'App Clip Demo',
                  action_type: 'execute_templates',
                  template_ids: [
                    @templates['app_clip_intro'].id,
                    @templates['app_clip_tuner'].id
                  ]
                }, 3500, 700)
  end

  # Create flow edges (connections between nodes)
  def create_flow_edges
    # Main flow progression
    create_edge(@nodes['state_aha1'], @nodes['state_aha2'], 'default')
    create_edge(@nodes['state_aha2'], @nodes['state_ahb1'], 'default')
    create_edge(@nodes['state_ahb1'], @nodes['state_ahc1'], 'default')
    create_edge(@nodes['state_ahc1'], @nodes['state_ahd1'], 'default')
    create_edge(@nodes['state_ahd1'], @nodes['state_ahe1'], 'default', 'AR View: Yes')
    create_edge(@nodes['state_ahd1'], @nodes['state_ahb1_2'], 'default', 'AR View: No')
    create_edge(@nodes['state_ahe1'], @nodes['state_ahb1_2'], 'default')
    create_edge(@nodes['state_ahb1_2'], @nodes['state_ahg1'], 'default')
    create_edge(@nodes['state_ahg1'], @nodes['state_ahh1'], 'default')
    create_edge(@nodes['state_ahh1'], @nodes['state_ahi1'], 'default')
    create_edge(@nodes['state_ahi1'], @nodes['state_ahj1'], 'default', 'Continue: Yes')
    create_edge(@nodes['state_ahi1'], @nodes['state_ahl1'], 'default', 'Skip Payment')
    create_edge(@nodes['state_ahj1'], @nodes['state_ahf1'], 'default')
    create_edge(@nodes['state_ahf1'], @nodes['state_ahk1'], 'default')
    create_edge(@nodes['state_ahk1'], @nodes['state_ahl1'], 'default')

    # Intent to action edges
    create_edge(@nodes['intent_menu'], @nodes['action_menu'], 'default')
    create_edge(@nodes['intent_start_over'], @nodes['state_aha1'], 'default')
    create_edge(@nodes['intent_summary'], @nodes['state_ahl1'], 'default')
    create_edge(@nodes['intent_list_picker_demo'], @nodes['action_list_picker_demo'], 'default')
    create_edge(@nodes['intent_time_picker_demo'], @nodes['action_time_picker_demo'], 'default')
    create_edge(@nodes['intent_form_demo'], @nodes['action_form_demo'], 'default')
    create_edge(@nodes['intent_apple_pay_demo'], @nodes['action_apple_pay_demo'], 'default')
    create_edge(@nodes['intent_ar_demo'], @nodes['action_ar_demo'], 'default')
    create_edge(@nodes['intent_imessage_app'], @nodes['action_imessage_app'], 'default')
    create_edge(@nodes['intent_app_clip'], @nodes['action_app_clip'], 'default')
    create_edge(@nodes['intent_large_form'], @nodes['state_demo_large_form'], 'default')

    # Demo actions to demo mode state
    create_edge(@nodes['action_menu'], @nodes['state_demo'], 'default')
    create_edge(@nodes['action_list_picker_demo'], @nodes['state_demo'], 'default')
    create_edge(@nodes['action_time_picker_demo'], @nodes['state_demo'], 'default')
    create_edge(@nodes['action_form_demo'], @nodes['state_demo'], 'default')
    create_edge(@nodes['action_apple_pay_demo'], @nodes['state_demo'], 'default')
    create_edge(@nodes['action_ar_demo'], @nodes['state_demo'], 'default')
    create_edge(@nodes['action_imessage_app'], @nodes['state_demo'], 'default')
    create_edge(@nodes['action_app_clip'], @nodes['state_demo'], 'default')
  end

  # Step 5: Save flow to database
  def save_flow
    puts "\n💾 Saving flow to database..."

    # Convert nodes hash to array
    nodes_array = @nodes.values.map do |node|
      {
        id: node[:id],
        type: node[:type],
        position: node[:position],
        data: node[:data]
      }
    end

    # Update flow data
    @bot_flow.update!(
      flow_data: {
        nodes: nodes_array,
        edges: @edges
      }
    )

    puts "   ✅ Flow saved with #{nodes_array.size} nodes and #{@edges.size} edges"
  end

  # Helper methods

  def create_template(name, template_type, parameters)
    template = BotActionTemplate.create!(
      account: @account,
      name: name,
      template_type: template_type,
      parameters: parameters,
      metadata: {
        created_by: 'master_bot_creator',
        bot_id: @agent_bot&.id
      }
    )

    @templates[name] = template
    template
  end

  def find_template_id(template_name)
    template = MessageTemplate.find_by(account: @account, name: template_name)
    if template
      template.id
    else
      puts "   ⚠️  Template '#{template_name}' not found, using placeholder"
      'PLACEHOLDER'
    end
  end

  def create_node(id, type, data, x, y)
    @node_id_counter += 1
    node = {
      id: id,
      type: type,
      position: { x: x, y: y },
      data: data
    }
    @nodes[id] = node
    node
  end

  def create_edge(source, target, type, label = nil)
    edge_id = "edge_#{@edges.size + 1}"
    edge = {
      id: edge_id,
      source: source[:id],
      target: target[:id],
      type: type
    }
    edge[:label] = label if label
    @edges << edge
    edge
  end

  def print_summary
    puts "\n" + "=" * 80
    puts "Bot Creation Summary"
    puts "=" * 80
    puts "Agent Bot ID: #{@agent_bot.id}"
    puts "Bot Flow ID: #{@bot_flow.id}"
    puts "Templates created: #{@templates.size}"
    puts "Nodes created: #{@nodes.size}"
    puts "  - State nodes: #{@nodes.values.count { |n| n[:type] == 'state' }}"
    puts "  - Intent nodes: #{@nodes.values.count { |n| n[:type] == 'intent' }}"
    puts "  - Action nodes: #{@nodes.values.count { |n| n[:type] == 'action' }}"
    puts "Edges created: #{@edges.size}"
    puts "=" * 80
  end
end

# Run the script
account_id = ARGV[0] || 1
puts "Creating master bot for account ID: #{account_id}"
puts

creator = AcousticHouseMasterBotCreator.new(account_id)
creator.create
```

---

#### 2.3 Data Migration (Day 5)

**Create**: `db/migrate/XXXXXX_migrate_handlers_to_templates.rb`

```ruby
class MigrateHandlersToTemplates < ActiveRecord::Migration[7.0]
  def up
    # This migration is executed via script/migrate_handlers_to_templates.rb
    # to provide more control and visibility during the migration process

    # Run the migration script
    system('rails runner script/migrate_handlers_to_templates.rb --execute')
  end

  def down
    # Remove all templates created by the migration
    BotActionTemplate.where("metadata->>'migrated_from' IS NOT NULL").delete_all
  end
end
```

---

#### 2.4 Update FlowExecutorService Integration (Day 6)

The integration was already added in Phase 1.3. Now we need to ensure it works correctly:

**Test Script**: `script/test_template_execution.rb`

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify template execution works correctly
# Usage: rails runner script/test_template_execution.rb

puts "Template Execution Test"
puts "=" * 80

# Find a test conversation
conversation = Conversation.joins(:inbox)
                          .where(inboxes: { channel_type: 'Channel::AppleMessagesForBusiness' })
                          .first

unless conversation
  puts "❌ No Apple Messages conversations found"
  exit 1
end

puts "✅ Found conversation: #{conversation.id}"

# Find a test template
template = BotActionTemplate.where(template_type: 'send_text_message').first

unless template
  puts "❌ No action templates found"
  exit 1
end

puts "✅ Found template: #{template.name}"

# Create a test message
message = Message.create!(
  conversation: conversation,
  account: conversation.account,
  inbox: conversation.inbox,
  message_type: :incoming,
  content: 'test message'
)

puts "✅ Created test message: #{message.id}"

# Execute the template
executor = AppleMessagesForBusiness::TemplateExecutorService.new(
  template,
  conversation,
  message
)

result = executor.execute

puts "\n✅ Template executed successfully!"
puts "   Messages sent: #{result}"

puts "\n" + "=" * 80
puts "Test completed successfully!"
```

---

#### 2.4 Testing & Verification (Day 6)

**Create**: `spec/services/apple_messages_for_business/template_executor_service_spec.rb`

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::TemplateExecutorService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let(:message) { create(:message, conversation: conversation, account: account) }

  describe '#execute' do
    context 'with send_text_message template' do
      let(:template) do
        create(:bot_action_template,
               account: account,
               template_type: 'send_text_message',
               parameters: { 'message' => 'Hello World' })
      end

      it 'sends a text message' do
        executor = described_class.new(template, conversation, message)

        expect(AppleMessagesForBusiness::SendMessageService).to receive(:new).with(
          conversation: conversation,
          message: 'Hello World'
        ).and_call_original

        result = executor.execute
        expect(result).to eq(1)
      end
    end

    context 'with send_list_picker template' do
      let(:list_picker_template) { create(:message_template, account: account, name: 'test_list_picker') }
      let(:template) do
        create(:bot_action_template,
               account: account,
               template_type: 'send_list_picker',
               parameters: { 'template_id' => list_picker_template.id })
      end

      it 'sends a list picker' do
        executor = described_class.new(template, conversation, message)

        expect(AppleMessagesForBusiness::SendListPickerService).to receive(:new).with(
          conversation: conversation,
          template: list_picker_template
        ).and_call_original

        result = executor.execute
        expect(result).to eq(1)
      end
    end

    context 'with update_attributes template' do
      let(:template) do
        create(:bot_action_template,
               account: account,
               template_type: 'update_attributes',
               parameters: { 'attributes' => { 'test_key' => 'test_value' } })
      end

      it 'updates conversation attributes' do
        executor = described_class.new(template, conversation, message)

        result = executor.execute

        expect(result).to eq(0)
        expect(conversation.reload.custom_attributes['test_key']).to eq('test_value')
      end
    end

    # Add specs for all 12 template types
  end
end
```

---

### **Phase 2.5: Update Predefined Flow Templates** (Day 6-7)

#### 2.5.1 Overview

The Bot Studio includes a "Flow Templates" feature (TemplateBrowserDialog.vue) that provides 6 predefined flow templates for common use cases. These templates currently reference generic template names and don't leverage the new BotActionTemplate system.

**Current Templates**:
1. Customer Support Flow
2. Order Status Inquiry
3. FAQ Handler
4. Appointment Booking
5. Feedback Collection
6. Lead Qualification

**Goal**: Update these templates to use BotActionTemplate references and add Apple Messages for Business specific templates.

---

#### 2.5.2 Add Apple Messages Templates (Day 6)

**Create**: `script/create_apple_messages_flow_templates.rb`

This script creates 4 new AMB-specific flow templates that showcase the template-based handler system:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# Creates Apple Messages for Business flow templates
# Usage: rails runner script/create_apple_messages_flow_templates.rb [account_id]

class AppleMessagesFlowTemplateCreator
  def initialize(account_id)
    @account = Account.find(account_id)
    @templates = {}
  end

  def create_all
    puts "=" * 80
    puts "Creating Apple Messages for Business Flow Templates"
    puts "=" * 80
    puts "Account: #{@account.name} (ID: #{@account.id})"
    puts

    create_guitar_shopping_template
    create_appointment_booking_template
    create_form_collection_template
    create_payment_flow_template

    puts "\n✅ Created #{@templates.size} flow templates"
    puts "=" * 80
  end

  private

  def create_guitar_shopping_template
    puts "\n📋 Creating Guitar Shopping Template..."

    # Create action templates
    welcome_template = create_action_template(
      'guitar_welcome',
      'send_text_message',
      { 'message' => "Welcome! Let's find your perfect guitar 🎸" }
    )

    guitar_picker_template = create_action_template(
      'guitar_picker',
      'send_list_picker',
      { 'template_id' => find_or_create_message_template('guitar_list') }
    )

    save_guitar_template = create_action_template(
      'save_guitar_choice',
      'update_attributes',
      { 'attributes' => { 'selected_guitar' => '{{user_selection}}' } }
    )

    confirmation_template = create_action_template(
      'guitar_confirmation',
      'send_text_message',
      { 'message' => 'Great choice! The {{guitar}} is an excellent instrument.' }
    )

    # Create BotFlow template
    flow_data = {
      nodes: [
        {
          id: 'start',
          type: 'state',
          position: { x: 100, y: 100 },
          data: {
            state_id: 'GUITAR_START',
            label: 'Welcome',
            description: 'Initial greeting',
            actions: [
              { type: 'execute_template', template_id: welcome_template.id }
            ]
          }
        },
        {
          id: 'picker',
          type: 'state',
          position: { x: 350, y: 100 },
          data: {
            state_id: 'GUITAR_PICKER',
            label: 'Show Guitars',
            description: 'Display guitar list picker',
            actions: [
              { type: 'execute_template', template_id: guitar_picker_template.id }
            ]
          }
        },
        {
          id: 'save',
          type: 'state',
          position: { x: 600, y: 100 },
          data: {
            state_id: 'GUITAR_SAVE',
            label: 'Save Choice',
            description: 'Store selected guitar',
            actions: [
              { type: 'execute_template', template_id: save_guitar_template.id },
              { type: 'execute_template', template_id: confirmation_template.id }
            ]
          }
        }
      ],
      edges: [
        { id: 'e1', source: 'start', target: 'picker', type: 'default' },
        { id: 'e2', source: 'picker', target: 'save', type: 'default' }
      ]
    }

    # Save as template BotFlow
    BotFlow.create!(
      account: @account,
      name: 'Guitar Shopping (AMB)',
      description: 'Apple Messages guitar shopping flow with list picker',
      flow_data: flow_data,
      is_active: false,
      is_template: true,
      metadata: {
        category: 'commerce',
        icon: 'i-lucide-guitar',
        preview: { nodes: 3, connections: 2 },
        template_type: 'apple_messages'
      }
    )

    puts "   ✅ Guitar Shopping Template"
  end

  def create_appointment_booking_template
    puts "\n📋 Creating Appointment Booking Template..."

    # Create action templates
    booking_intro = create_action_template(
      'booking_intro',
      'send_text_message',
      { 'message' => "Let's schedule your guitar lesson!" }
    )

    time_picker_template = create_action_template(
      'lesson_time_picker',
      'send_time_picker',
      {
        'template_id' => find_or_create_message_template('lesson_time_picker'),
        'timezone_offset' => -28800
      }
    )

    save_appointment = create_action_template(
      'save_lesson_time',
      'update_attributes',
      { 'attributes' => { 'lesson_time' => '{{selected_time}}' } }
    )

    confirmation = create_action_template(
      'lesson_confirmation',
      'send_text_message',
      { 'message' => "Perfect! Your lesson is scheduled for {{time}}." }
    )

    # Create BotFlow template
    flow_data = {
      nodes: [
        {
          id: 'start',
          type: 'state',
          position: { x: 100, y: 100 },
          data: {
            state_id: 'BOOKING_START',
            label: 'Booking Start',
            actions: [
              { type: 'execute_template', template_id: booking_intro.id }
            ]
          }
        },
        {
          id: 'picker',
          type: 'state',
          position: { x: 350, y: 100 },
          data: {
            state_id: 'TIME_PICKER',
            label: 'Select Time',
            actions: [
              { type: 'execute_template', template_id: time_picker_template.id }
            ]
          }
        },
        {
          id: 'confirm',
          type: 'state',
          position: { x: 600, y: 100 },
          data: {
            state_id: 'CONFIRM',
            label: 'Confirm',
            actions: [
              { type: 'execute_template', template_id: save_appointment.id },
              { type: 'execute_template', template_id: confirmation.id }
            ]
          }
        }
      ],
      edges: [
        { id: 'e1', source: 'start', target: 'picker', type: 'default' },
        { id: 'e2', source: 'picker', target: 'confirm', type: 'default' }
      ]
    }

    BotFlow.create!(
      account: @account,
      name: 'Appointment Booking (AMB)',
      description: 'Apple Messages appointment booking with time picker',
      flow_data: flow_data,
      is_active: false,
      is_template: true,
      metadata: {
        category: 'scheduling',
        icon: 'i-lucide-calendar-check',
        preview: { nodes: 3, connections: 2 },
        template_type: 'apple_messages'
      }
    )

    puts "   ✅ Appointment Booking Template"
  end

  def create_form_collection_template
    puts "\n📋 Creating Form Collection Template..."

    # Create action templates
    form_intro = create_action_template(
      'form_intro',
      'send_text_message',
      { 'message' => 'Please fill out this quick form:' }
    )

    form_template = create_action_template(
      'guitar_info_form',
      'send_form',
      { 'template_id' => find_or_create_message_template('guitar_info_form') }
    )

    form_received = create_action_template(
      'form_received_msg',
      'send_text_message',
      { 'message' => "Thanks! We've received your information." }
    )

    # Create BotFlow template
    flow_data = {
      nodes: [
        {
          id: 'start',
          type: 'state',
          position: { x: 100, y: 100 },
          data: {
            state_id: 'FORM_START',
            label: 'Form Intro',
            actions: [
              { type: 'execute_template', template_id: form_intro.id }
            ]
          }
        },
        {
          id: 'form',
          type: 'state',
          position: { x: 350, y: 100 },
          data: {
            state_id: 'FORM_SEND',
            label: 'Send Form',
            actions: [
              { type: 'execute_template', template_id: form_template.id }
            ]
          }
        },
        {
          id: 'received',
          type: 'state',
          position: { x: 600, y: 100 },
          data: {
            state_id: 'FORM_RECEIVED',
            label: 'Confirmation',
            actions: [
              { type: 'execute_template', template_id: form_received.id }
            ]
          }
        }
      ],
      edges: [
        { id: 'e1', source: 'start', target: 'form', type: 'default' },
        { id: 'e2', source: 'form', target: 'received', type: 'default' }
      ]
    }

    BotFlow.create!(
      account: @account,
      name: 'Form Collection (AMB)',
      description: 'Apple Messages form collection flow',
      flow_data: flow_data,
      is_active: false,
      is_template: true,
      metadata: {
        category: 'engagement',
        icon: 'i-lucide-file-text',
        preview: { nodes: 3, connections: 2 },
        template_type: 'apple_messages'
      }
    )

    puts "   ✅ Form Collection Template"
  end

  def create_payment_flow_template
    puts "\n📋 Creating Payment Flow Template..."

    # Create action templates
    payment_intro = create_action_template(
      'payment_intro',
      'send_text_message',
      { 'message' => 'Ready to complete your purchase?' }
    )

    apple_pay_request = create_action_template(
      'apple_pay_guitar',
      'send_apple_pay',
      {
        'merchant_id' => 'merchant.com.example',
        'item_name' => 'Guitar Purchase',
        'amount' => 999.99,
        'currency' => 'USD'
      }
    )

    payment_success = create_action_template(
      'payment_success_msg',
      'send_text_message',
      { 'message' => '✅ Payment received! Thank you for your purchase.' }
    )

    # Create BotFlow template
    flow_data = {
      nodes: [
        {
          id: 'start',
          type: 'state',
          position: { x: 100, y: 100 },
          data: {
            state_id: 'PAYMENT_START',
            label: 'Payment Intro',
            actions: [
              { type: 'execute_template', template_id: payment_intro.id }
            ]
          }
        },
        {
          id: 'pay',
          type: 'state',
          position: { x: 350, y: 100 },
          data: {
            state_id: 'APPLE_PAY',
            label: 'Apple Pay',
            actions: [
              { type: 'execute_template', template_id: apple_pay_request.id }
            ]
          }
        },
        {
          id: 'success',
          type: 'state',
          position: { x: 600, y: 100 },
          data: {
            state_id: 'PAYMENT_SUCCESS',
            label: 'Success',
            actions: [
              { type: 'execute_template', template_id: payment_success.id }
            ]
          }
        }
      ],
      edges: [
        { id: 'e1', source: 'start', target: 'pay', type: 'default' },
        { id: 'e2', source: 'pay', target: 'success', type: 'default' }
      ]
    }

    BotFlow.create!(
      account: @account,
      name: 'Payment Flow (AMB)',
      description: 'Apple Messages payment flow with Apple Pay',
      flow_data: flow_data,
      is_active: false,
      is_template: true,
      metadata: {
        category: 'commerce',
        icon: 'i-lucide-credit-card',
        preview: { nodes: 3, connections: 2 },
        template_type: 'apple_messages'
      }
    )

    puts "   ✅ Payment Flow Template"
  end

  # Helper methods

  def create_action_template(name, template_type, parameters)
    template = BotActionTemplate.create!(
      account: @account,
      name: name,
      template_type: template_type,
      parameters: parameters,
      metadata: {
        created_by: 'flow_template_creator',
        template_flow: true
      }
    )

    @templates[name] = template
    template
  end

  def find_or_create_message_template(name)
    template = MessageTemplate.find_by(account: @account, name: name)

    if template
      template.id
    else
      # Create placeholder message template
      MessageTemplate.create!(
        account: @account,
        name: name,
        template_type: 'list_picker',
        content: 'Placeholder template - configure in Message Templates'
      ).id
    end
  end
end

# Run the script
account_id = ARGV[0] || 1
puts "Creating flow templates for account ID: #{account_id}"
puts

creator = AppleMessagesFlowTemplateCreator.new(account_id)
creator.create_all
```

---

#### 2.5.3 Add Migration for Template Flag (Day 6)

**Create**: `db/migrate/XXXXXX_add_is_template_to_bot_flows.rb`

```ruby
class AddIsTemplateToBotFlows < ActiveRecord::Migration[7.0]
  def change
    add_column :bot_flows, :is_template, :boolean, default: false, null: false
    add_column :bot_flows, :metadata, :jsonb, default: {}

    add_index :bot_flows, :is_template
    add_index :bot_flows, :metadata, using: :gin
  end
end
```

---

#### 2.5.4 Update TemplateBrowserDialog Component (Day 7)

**Update**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/TemplateBrowserDialog.vue`

Replace the hardcoded templates array with dynamic loading from database:

```vue
<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  accountId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['insertTemplate']);

const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const selectedTemplate = ref(null);
const selectedCategory = ref('all');
const isLoading = ref(false);
const templates = ref([]);

// Load templates from database
const loadTemplates = async () => {
  isLoading.value = true;

  try {
    // Fetch template BotFlows (is_template: true)
    const response = await store.dispatch('agentBots/getTemplateFlows', {
      accountId: props.accountId,
    });

    // Transform database templates to UI format
    templates.value = response.flows.map(flow => ({
      id: flow.id,
      name: flow.name,
      description: flow.description,
      category: flow.metadata?.category || 'general',
      icon: flow.metadata?.icon || 'i-lucide-box',
      preview: flow.metadata?.preview || { nodes: 0, connections: 0 },
      flowData: flow.flow_data,
      isDatabase: true, // Flag to indicate this came from database
    }));

    // Add hardcoded templates for backward compatibility
    templates.value.push(...getHardcodedTemplates());

  } catch (error) {
    console.error('[TemplateBrowser] Failed to load templates:', error);

    // Fallback to hardcoded templates only
    templates.value = getHardcodedTemplates();
  } finally {
    isLoading.value = false;
  }
};

// Hardcoded templates (backward compatibility)
const getHardcodedTemplates = () => [
  {
    id: 'customer-support',
    name: 'Customer Support Flow',
    description: 'Handle common support inquiries with intent detection and routing',
    category: 'support',
    icon: 'i-lucide-headphones',
    preview: { nodes: 5, connections: 6 },
    isDatabase: false,
    flowData: {
      // ... existing flowData ...
    }
  },
  // ... other hardcoded templates ...
];

const categories = computed(() => {
  // Extract unique categories from loaded templates
  const categorySet = new Set(
    templates.value.map(t => t.category)
  );

  const categoryList = [
    {
      value: 'all',
      label: t('AGENT_BOTS.TEMPLATES.CATEGORIES.ALL'),
      icon: 'i-lucide-layout-grid',
    }
  ];

  categorySet.forEach(category => {
    categoryList.push({
      value: category,
      label: t(`AGENT_BOTS.TEMPLATES.CATEGORIES.${category.toUpperCase()}`) || category,
      icon: getCategoryIcon(category),
    });
  });

  return categoryList;
});

const getCategoryIcon = (category) => {
  const iconMap = {
    support: 'i-lucide-headphones',
    commerce: 'i-lucide-shopping-cart',
    scheduling: 'i-lucide-calendar',
    engagement: 'i-lucide-users',
    sales: 'i-lucide-trending-up',
    general: 'i-lucide-box',
  };

  return iconMap[category] || 'i-lucide-box';
};

const filteredTemplates = computed(() => {
  if (selectedCategory.value === 'all') {
    return templates.value;
  }
  return templates.value.filter(
    template => template.category === selectedCategory.value
  );
});

const selectTemplate = template => {
  selectedTemplate.value = template;
};

const close = () => {
  dialogRef.value?.close();
  selectedTemplate.value = null;
};

const insertTemplate = () => {
  if (!selectedTemplate.value) return;

  emit('insertTemplate', selectedTemplate.value.flowData);
  close();
};

const open = () => {
  dialogRef.value?.open();
  loadTemplates();
};

onMounted(() => {
  // Optionally pre-load templates
  // loadTemplates();
});

defineExpose({
  open,
  close,
});
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="t('AGENT_BOTS.TEMPLATES.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    width="7xl"
    overflow-y-auto
  >
    <div class="flex flex-col gap-4">
      <!-- Description -->
      <p class="text-sm text-n-slate-11">
        {{ t('AGENT_BOTS.TEMPLATES.DESCRIPTION') }}
      </p>

      <!-- Loading State -->
      <div
        v-if="isLoading"
        class="flex items-center justify-center py-8"
      >
        <i class="i-lucide-loader-2 w-8 h-8 animate-spin text-n-blue-8" />
      </div>

      <!-- Templates Content (only shown when not loading) -->
      <template v-else>
        <!-- Category Filter -->
        <div class="flex gap-2 overflow-x-auto pb-2">
          <button
            v-for="category in categories"
            :key="category.value"
            class="flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-all whitespace-nowrap"
            :class="[
              selectedCategory === category.value
                ? 'bg-n-blue-8 text-white'
                : 'bg-n-slate-2 text-n-slate-11 hover:bg-n-slate-3',
            ]"
            @click="selectedCategory = category.value"
          >
            <i class="w-4 h-4" :class="[category.icon]" />
            <span>{{ category.label }}</span>
          </button>
        </div>

        <!-- Templates Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <button
            v-for="template in filteredTemplates"
            :key="template.id"
            class="flex flex-col gap-3 p-4 rounded-lg border-2 text-left transition-all group"
            :class="[
              selectedTemplate?.id === template.id
                ? 'border-n-blue-8 bg-n-blue-1'
                : 'border-n-weak hover:border-n-strong bg-n-white',
            ]"
            @click="selectTemplate(template)"
          >
            <!-- Header -->
            <div class="flex items-start gap-3">
              <div
                class="flex items-center justify-center w-12 h-12 rounded-lg transition-colors"
                :class="[
                  selectedTemplate?.id === template.id
                    ? 'bg-n-blue-8 text-white'
                    : 'bg-n-slate-2 text-n-slate-11 group-hover:bg-n-slate-3',
                ]"
              >
                <i class="w-6 h-6" :class="[template.icon]" />
              </div>
              <div class="flex-1 min-w-0">
                <h3 class="font-semibold text-n-slate-12 mb-1">
                  {{ template.name }}
                  <span
                    v-if="template.isDatabase"
                    class="ml-2 px-2 py-0.5 text-xs bg-teal-100 text-teal-800 rounded-full"
                  >
                    {{ t('AGENT_BOTS.TEMPLATES.CUSTOM') }}
                  </span>
                </h3>
                <p class="text-sm text-n-slate-11">
                  {{ template.description }}
                </p>
              </div>
            </div>

            <!-- Preview Stats -->
            <div class="flex items-center gap-4 text-xs text-n-slate-11">
              <div class="flex items-center gap-1">
                <i class="i-lucide-circle-dot w-3 h-3" />
                <span>
                  {{ template.preview.nodes }}
                  {{ t('AGENT_BOTS.TEMPLATES.NODES') }}
                </span>
              </div>
              <div class="flex items-center gap-1">
                <i class="i-lucide-git-branch w-3 h-3" />
                <span>
                  {{ template.preview.connections }}
                  {{ t('AGENT_BOTS.TEMPLATES.CONNECTIONS') }}
                </span>
              </div>
            </div>

            <!-- Selected Indicator -->
            <div
              v-if="selectedTemplate?.id === template.id"
              class="flex items-center gap-2 text-sm text-n-blue-11 font-medium"
            >
              <i class="i-lucide-check-circle w-4 h-4" />
              <span>{{ t('AGENT_BOTS.TEMPLATES.SELECTED') }}</span>
            </div>
          </button>
        </div>

        <!-- Empty State -->
        <div
          v-if="filteredTemplates.length === 0"
          class="flex flex-col items-center justify-center py-8 text-center"
        >
          <i class="i-lucide-folder-open w-12 h-12 mb-3 text-n-slate-8" />
          <p class="text-sm text-n-slate-11">
            {{ t('AGENT_BOTS.TEMPLATES.NO_TEMPLATES') }}
          </p>
        </div>
      </template>

      <!-- Footer Actions -->
      <div
        class="flex justify-between items-center pt-4 border-t border-n-weak"
      >
        <div class="flex items-center gap-2 text-sm text-n-slate-11">
          <i class="i-lucide-info w-4 h-4" />
          <span>{{ t('AGENT_BOTS.TEMPLATES.FOOTER_TIP') }}</span>
        </div>
        <div class="flex gap-2">
          <Button
            faded
            slate
            :label="t('AGENT_BOTS.FORM.CANCEL')"
            @click="close"
          />
          <Button
            :label="t('AGENT_BOTS.TEMPLATES.INSERT')"
            :disabled="!selectedTemplate"
            @click="insertTemplate"
          />
        </div>
      </div>
    </div>
  </Dialog>
</template>
```

---

#### 2.5.5 Add Vuex Action for Template Flows (Day 7)

**Update**: `app/javascript/dashboard/store/modules/agentBots.js`

Add action to fetch template flows:

```javascript
// Actions
const actions = {
  // ... existing actions ...

  async getTemplateFlows({ commit }, { accountId }) {
    try {
      const response = await axios.get(
        `/api/v1/accounts/${accountId}/agent_bots/template_flows`
      );

      return response.data;
    } catch (error) {
      console.error('[Store] Failed to fetch template flows:', error);
      throw error;
    }
  },
};
```

---

#### 2.5.6 Add Backend API Endpoint (Day 7)

**Create**: `app/controllers/api/v1/accounts/agent_bots/template_flows_controller.rb`

```ruby
# frozen_string_literal: true

class Api::V1::Accounts::AgentBots::TemplateFlowsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  # GET /api/v1/accounts/:account_id/agent_bots/template_flows
  # Returns all template flows (is_template: true) for the account
  def index
    @template_flows = Current.account.bot_flows.where(is_template: true)

    render json: {
      flows: @template_flows.as_json(
        only: [:id, :name, :description, :flow_data, :metadata],
        methods: []
      )
    }
  end

  private

  def check_authorization
    authorize! :manage, AgentBot
  end
end
```

**Add Route**: Update `config/routes.rb`

```ruby
namespace :accounts, path: '', defaults: { format: 'json' } do
  resources :agent_bots, only: [:index, :create, :show, :update, :destroy] do
    # ... existing routes ...

    collection do
      get :template_flows
    end
  end
end
```

---

#### 2.5.7 Update I18n Translations (Day 7)

**Add to**: `app/javascript/dashboard/i18n/locale/en/agentBots.json`

```json
{
  "AGENT_BOTS": {
    "TEMPLATES": {
      "TITLE": "Flow Templates",
      "DESCRIPTION": "Choose a pre-built flow template to get started quickly",
      "CUSTOM": "Custom",
      "CATEGORIES": {
        "ALL": "All Templates",
        "SUPPORT": "Customer Support",
        "COMMERCE": "E-Commerce",
        "SCHEDULING": "Scheduling",
        "ENGAGEMENT": "Engagement",
        "SALES": "Sales",
        "GENERAL": "General"
      },
      "NODES": "nodes",
      "CONNECTIONS": "connections",
      "SELECTED": "Selected",
      "INSERT": "Insert Template",
      "NO_TEMPLATES": "No templates found for this category",
      "FOOTER_TIP": "Templates can be customized after insertion"
    }
  }
}
```

---

#### 2.5.8 Testing & Verification (Day 7)

**Manual Testing Checklist**:

1. **Create AMB Templates**:
   ```bash
   rails runner script/create_apple_messages_flow_templates.rb 1
   ```

2. **Verify Database**:
   ```ruby
   rails runner "puts BotFlow.where(is_template: true).count"
   rails runner "puts BotFlow.where(is_template: true).pluck(:name)"
   ```

3. **Test Frontend**:
   - Open Bot Studio
   - Click "Insert Template" button
   - Verify all templates appear (6 hardcoded + 4 AMB)
   - Filter by category
   - Select and insert a template
   - Verify flow loads correctly with BotActionTemplate references

4. **Test API**:
   ```bash
   curl -X GET "http://localhost:3000/api/v1/accounts/1/agent_bots/template_flows" \
     -H "api_access_token: YOUR_TOKEN"
   ```

---

#### 2.5.9 Summary

**Changes Made**:
- ✅ Added `is_template` flag to BotFlow model
- ✅ Created 4 Apple Messages flow templates
- ✅ Updated TemplateBrowserDialog to load templates from database
- ✅ Added backend API endpoint for template flows
- ✅ Added Vuex action for fetching templates
- ✅ Added I18n translations

**Benefits**:
- Templates are now dynamic and customizable
- Templates use BotActionTemplate system (not hardcoded handler names)
- Users can create custom templates and share them
- Apple Messages specific templates showcase the new system
- Backward compatible with existing hardcoded templates

---

### **Phase 3: Deprecation & Cleanup** (1 day)

#### 3.1 Remove Handler System (Day 7)

**Remove from node data structures**:

Update node editors to remove handler field:
- `IntentNodeEditor.vue` - Remove handler field
- `ActionNodeEditor.vue` - Remove handler field
- `StateNodeEditor.vue` - Remove handler field

**Update**: `app/services/apple_messages_for_business/flow_executor_service.rb`

```ruby
def execute_state_node(node)
  state_data = node['data'] || {}
  # REMOVED: handler = state_data['handler']

  # Only execute actions (which are now template-based)
  actions = state_data['actions'] || []
  messages_sent = 0

  actions.each_with_index do |action, index|
    messages_sent += execute_action(action)

    # Add delay between actions (except after last action)
    if index < actions.length - 1
      log_info "[FlowExecutor] ⏱️  Waiting between actions (1.5s delay)"
      sleep 1.5
    end
  end

  # Handle transitions
  outgoing_edge = @edges.find { |e| e['source'] == node['id'] }
  if outgoing_edge
    target_node = find_node_by_id(outgoing_edge['target'])
    if target_node && target_node['type'] == 'state'
      @current_state = target_node.dig('data', 'state_id') || target_node['id']
      log_info "[FlowExecutor] ➡️ Transitioned to state: #{@current_state}"
    end
  end

  messages_sent
end
```

**Remove from**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

Remove these methods:
- `execute_handler_via_metadata`
- `execute_handler_via_service`
- All individual handler methods (`handle_welcome`, `handle_menu`, etc.)

Keep:
- Core bot infrastructure (`process_message`, `process_interactive_response`)
- Helper methods (`send_text_message`, `update_bot_state`, `send_quick_reply`, etc.)
- Configuration management
- Keyword/interactive routing (these will be migrated to flow-based in future)

---

#### 3.2 Documentation Updates (Day 7)

**Create**: `docs/apple-messages/TEMPLATE_BASED_ACTIONS_GUIDE.md`

```markdown
# Template-Based Actions Guide

## Overview

The Template-Based Action system replaces hardcoded Ruby handler methods with configurable UI-based templates. This allows bot behavior to be modified entirely through the Bot Studio UI without requiring code changes or deployments.

## Benefits

- ✅ **No Code Required**: Create and modify bot behaviors entirely in the UI
- ✅ **Immediate Changes**: No deployment needed for behavior updates
- ✅ **Visual Validation**: Preview what will happen before saving
- ✅ **Reusable Templates**: Share templates across multiple bots
- ✅ **Version Control**: Track changes to bot behavior over time

## Template Types

[Full documentation of all 12 template types with examples]

## Creating Action Templates

[Step-by-step guide with screenshots]

## Using Templates in Bot Flows

[Guide on using templates in Intent, Action, and State nodes]

## Migration from Legacy Handlers

[Guide for migrating existing bots to template-based system]

## Best Practices

[Recommendations for organizing and naming templates]

## Troubleshooting

[Common issues and solutions]
```

**Update**: `docs/apple-messages/AMB_INTEGRATION_STATUS_REPORT.md`

Add section on template-based action system:
- Architecture overview
- Component inventory
- Template execution flow
- Migration status

---

## 🧪 Testing Strategy

### Unit Tests

**Models**:
- ✅ BotActionTemplate validations
- ✅ Parameter schema validation
- ✅ Template type validation

**Services**:
- ✅ TemplateExecutorService for all 12 types
- ✅ FlowExecutorService template integration
- ✅ Template parameter processing

### Integration Tests

- ✅ End-to-end flow execution with templates
- ✅ Migration script with test data
- ✅ Template CRUD via API
- ✅ UI interactions for template creation/editing

### Manual Testing Checklist

- [ ] Create template in UI for each of 12 types
- [ ] Edit template parameters
- [ ] Delete template
- [ ] Execute flow with template
- [ ] Verify message sent to Apple MSP
- [ ] Test migration from old handlers
- [ ] Test fallback to old system during transition
- [ ] Test template execution in production-like environment
- [ ] Verify I18n strings in all supported languages

---

## ⚠️ Risk Analysis & Mitigation

### Risk 1: Breaking Existing Flows
**Impact**: High
**Probability**: Medium
**Mitigation**:
- Phase 1 runs parallel with existing system
- Comprehensive testing before Phase 3
- Rollback plan with data backups
- Gradual rollout per account

### Risk 2: Complex Migration
**Impact**: Medium
**Probability**: Medium
**Mitigation**:
- Automated migration scripts with dry-run mode
- Manual verification checklist
- Phased rollout with monitoring
- Support for old system during transition

### Risk 3: Template System Limitations
**Impact**: Medium
**Probability**: Low
**Mitigation**:
- Start with most common patterns (cover 80% of use cases)
- Keep fallback to Ruby handlers for edge cases
- API call template provides flexibility for custom logic
- Can add new template types as needed

### Risk 4: UI Complexity
**Impact**: Low
**Probability**: Low
**Mitigation**:
- Progressive disclosure (show parameters only for selected type)
- Clear labels and help text in I18n
- Preview panel to show what will happen
- User testing before rollout

### Risk 5: Performance Impact
**Impact**: Low
**Probability**: Low
**Mitigation**:
- Template execution is lightweight (just parameter passing)
- No additional database queries vs old system
- Load testing with realistic bot flows
- Monitoring of execution times

---

## 📊 Success Metrics

- ✅ 100% of existing handlers converted to templates
- ✅ Zero message delivery failures during migration
- ✅ Bot behavior identical before and after migration
- ✅ All 12 template types working in production
- ✅ No Ruby code changes required for bot behavior updates
- ✅ Template creation time < 2 minutes per template
- ✅ 95% of bot changes can be done via UI without code
- ✅ Zero rollbacks required
- ✅ User satisfaction score > 4/5

---

## 🚀 Rollout Strategy

### Week 1: Phase 1 Deployment
- Deploy template system alongside existing handlers
- Test in staging environment with full bot flows
- Enable for 1-2 pilot accounts with close monitoring
- Gather feedback and address issues

### Week 2: Phase 2 Deployment
- Run migration scripts for all accounts (dry-run first)
- Execute migration account by account with verification
- Monitor for errors or regressions
- Verify behavior equivalence with test suite

### Week 3: Phase 3 Deployment
- Deprecate old handler system in UI
- Remove handler fields from node editors
- Update documentation and training materials
- Announce new system to users

### Post-Rollout
- Monitor bot execution metrics
- Collect user feedback
- Address any issues promptly
- Plan future enhancements

---

## 💰 Cost-Benefit Analysis

### Current System Costs

**Per Bot Behavior Change**:
- Developer time: 1-2 hours
- Code review: 30 minutes
- Testing: 30 minutes
- Deployment: 15 minutes
- **Total**: ~2.5 hours per change

**Monthly Costs** (assuming 10 changes/month):
- Developer time: 25 hours
- Deployment overhead: 2.5 hours
- Risk of bugs: 2-3 hours debugging
- **Total**: ~30 hours/month

### Template System Benefits

**Per Bot Behavior Change**:
- Template creation: 5 minutes
- Testing in UI: 5 minutes
- Deployment: 0 minutes (immediate)
- **Total**: ~10 minutes per change

**Monthly Savings** (10 changes/month):
- Time saved: 27 hours
- Faster iteration for product team
- Reduced deployment risks
- Better user experience (faster turnaround)

### ROI Calculation

**Investment**:
- Development: 6-8 days (48-64 hours)
- Testing: Included in development time
- Documentation: Included in development time

**Payback Period**:
- Monthly savings: 27 hours
- Break-even: ~2.5 months

**Annual Value**:
- Hours saved: 324 hours
- Cost savings: $32,000+ (at $100/hour developer rate)
- Intangible benefits: Faster product iteration, improved UX

---

## 📝 Appendix: Handler to Template Mapping

Complete mapping of all existing handlers to templates:

| Handler | Templates Needed | Template Types | Notes |
|---------|-----------------|----------------|-------|
| `handle_welcome` | 3 | 2x text + 1x quick_reply | Sequential welcome flow |
| `handle_menu` | 1 | 1x list_picker | Main menu navigation |
| `handle_list_picker_demo` | 2 | 1x text + 1x list_picker | Demo mode |
| `handle_time_picker_demo` | 2 | 1x text + 1x time_picker | Demo mode with location |
| `handle_form_demo` | 2 | 1x text + 1x form | With capability check |
| `handle_apple_pay_demo` | 2 | 1x text + 1x apple_pay | Payment demo |
| `handle_ar_demo` | 2 | 1x text + 1x rich_link | AR experience link |
| `handle_imessage_app` | 2 | 1x text + 1x imessage_app | Shazam integration |
| `handle_app_clip_demo` | 2 | 1x text + 1x app_clip | Guitar tuner clip |
| `handle_region_selection` | 2 | 1x update_attributes + 1x text | Store and confirm |
| `handle_guitar_selection` | 2 | 1x update_attributes + 1x text | Store and confirm |
| `handle_store_selection` | 2 | 1x update_attributes + 1x time_picker | Store + schedule |
| `handle_name_preference` | 2 | 1x update_attributes + 1x text | Store preference |
| `handle_time_picker_response` | 2 | 1x update_attributes + 1x text | Store appointment |

**Total**: 14 handlers → 29 templates

---

## ✅ Pre-Approval Checklist

Before proceeding with implementation, please confirm:

- [ ] **Template types** cover all required use cases
- [ ] **Parameter schemas** are sufficient for each type
- [ ] **Timeline** (6-8 days) is acceptable
- [ ] **Phased rollout** approach is acceptable
- [ ] **I18n requirements** are clearly defined
- [ ] **Migration strategy** makes sense
- [ ] **Testing strategy** is comprehensive
- [ ] **UI mockups** match expectations
- [ ] **Risk mitigation** plans are adequate
- [ ] **Success metrics** are appropriate
- [ ] **Rollback plan** is understood
- [ ] **Resource allocation** is confirmed

---

## 📞 Next Steps

After approval:

1. **Create GitHub Issue/Project Board** with all tasks
2. **Set up development branch** (`feature/template-based-handlers`)
3. **Begin Phase 1 implementation** (Days 1-4)
4. **Daily standup updates** on progress
5. **Demo after each phase** for validation
6. **Deploy to staging** after Phase 2
7. **Production rollout** after successful testing

---

**Document Version**: 1.0
**Last Updated**: December 20, 2024
**Status**: Awaiting Approval
**Estimated Start Date**: TBD
**Estimated Completion Date**: TBD

---

## Amendments & Feedback

Please provide feedback on:
1. Missing template types or parameters
2. Timeline concerns
3. Migration approach
4. UI/UX suggestions
5. Testing requirements
6. Documentation needs
7. Any other concerns or questions
