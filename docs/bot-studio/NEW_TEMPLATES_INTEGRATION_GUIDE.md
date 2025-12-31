# Integration Guide - New Template Components

## Overview

This guide shows how to integrate the 4 new complex template editor components into the existing Bot Studio system.

## New Components

1. **ConditionalBranchTemplate.vue** - Conditional logic branching
2. **ApiCallTemplate.vue** - HTTP API calls
3. **SendIMessageAppTemplate.vue** - iMessage app invocations
4. **SendAppClipTemplate.vue** - App Clip experiences

## Integration Steps

### Step 1: Component Registration

The parent editor that loads these templates needs to import and register them. Based on the existing architecture, this is likely done in a parent component like `ActionNodeEditor.vue` or `TemplateNodeEditor.vue`.

**Example Registration Pattern**:

```vue
<script setup>
// ... existing imports
import ConditionalBranchTemplate from './templates/ConditionalBranchTemplate.vue';
import ApiCallTemplate from './templates/ApiCallTemplate.vue';
import SendIMessageAppTemplate from './templates/SendIMessageAppTemplate.vue';
import SendAppClipTemplate from './templates/SendAppClipTemplate.vue';

// Template type mapping
const templateComponents = {
  // Existing templates
  'send_text_message': SendTextMessageTemplate,
  'update_attributes': UpdateAttributesTemplate,
  'send_quick_reply': SendQuickReplyTemplate,
  'send_list_picker': SendListPickerTemplate,
  'send_time_picker': SendTimePickerTemplate,
  'send_form': SendFormTemplate,
  'send_apple_pay': SendApplePayTemplate,
  'send_rich_link': SendRichLinkTemplate,

  // NEW: Complex templates
  'conditional_branch': ConditionalBranchTemplate,
  'api_call': ApiCallTemplate,
  'send_imessage_app': SendIMessageAppTemplate,
  'send_app_clip': SendAppClipTemplate,
};
</script>

<template>
  <component
    :is="templateComponents[selectedTemplate.action_type]"
    v-model="selectedTemplate.parameters"
    :account-id="accountId"
  />
</template>
```

### Step 2: Backend API Support

Add the new action types to the backend `BotActionTemplate` model.

**File**: `app/models/bot_action_template.rb`

```ruby
class BotActionTemplate < ApplicationRecord
  # Existing action types
  ACTION_TYPES = %w[
    send_text_message
    update_attributes
    send_quick_reply
    send_list_picker
    send_time_picker
    send_form
    send_apple_pay
    send_rich_link
    conditional_branch
    api_call
    send_imessage_app
    send_app_clip
  ].freeze

  validates :action_type, inclusion: { in: ACTION_TYPES }
end
```

### Step 3: Parameter Validation Schemas

Add JSON schema validation for the new parameter structures.

**File**: `app/validators/bot_action_template_parameters_validator.rb` (or similar)

```ruby
# ConditionalBranch schema
CONDITIONAL_BRANCH_SCHEMA = {
  type: 'object',
  required: ['condition_type', 'condition_value'],
  properties: {
    condition_type: {
      type: 'string',
      enum: ['attribute_equals', 'attribute_contains', 'message_contains', 'custom_expression']
    },
    condition_value: { type: 'object' },
    true_action: { type: ['integer', 'null'] },
    false_action: { type: ['integer', 'null'] }
  }
}

# ApiCall schema
API_CALL_SCHEMA = {
  type: 'object',
  required: ['url', 'method'],
  properties: {
    url: { type: 'string', format: 'uri' },
    method: { type: 'string', enum: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'] },
    headers: { type: 'object' },
    body: { type: 'object' },
    store_response_in: { type: 'string' }
  }
}

# SendIMessageApp schema
SEND_IMESSAGE_APP_SCHEMA = {
  type: 'object',
  required: ['app_id', 'app_name'],
  properties: {
    app_id: { type: 'string' },
    app_name: { type: 'string' },
    app_icon_url: { type: 'string', format: 'uri' },
    launch_url: { type: 'string', format: 'uri' },
    data: { type: 'object' }
  }
}

# SendAppClip schema
SEND_APP_CLIP_SCHEMA = {
  type: 'object',
  required: ['app_clip_url', 'title'],
  properties: {
    app_clip_url: { type: 'string', format: 'uri' },
    title: { type: 'string' },
    subtitle: { type: 'string' },
    image_url: { type: 'string', format: 'uri' },
    action_title: { type: 'string' }
  }
}
```

### Step 4: Backend Services Implementation

Create the corresponding service classes to execute these templates.

#### ConditionalBranchService

**File**: `app/services/bot_studio/conditional_branch_service.rb`

```ruby
module BotStudio
  class ConditionalBranchService
    def initialize(template, context)
      @template = template
      @context = context
      @conversation = context[:conversation]
      @message = context[:message]
    end

    def execute
      condition_met = evaluate_condition

      next_template_id = condition_met ?
        @template.parameters['true_action'] :
        @template.parameters['false_action']

      return nil unless next_template_id

      BotActionTemplate.find_by(id: next_template_id)
    end

    private

    def evaluate_condition
      type = @template.parameters['condition_type']
      value = @template.parameters['condition_value']

      case type
      when 'attribute_equals'
        evaluate_attribute_equals(value)
      when 'attribute_contains'
        evaluate_attribute_contains(value)
      when 'message_contains'
        evaluate_message_contains(value)
      when 'custom_expression'
        evaluate_custom_expression(value)
      else
        false
      end
    end

    def evaluate_attribute_equals(value)
      attr = @conversation.custom_attributes[value['attribute']]
      attr.to_s == value['value'].to_s
    end

    def evaluate_attribute_contains(value)
      attr = @conversation.custom_attributes[value['attribute']].to_s
      attr.include?(value['value'].to_s)
    end

    def evaluate_message_contains(value)
      @message.content.to_s.downcase.include?(value['text'].to_s.downcase)
    end

    def evaluate_custom_expression(value)
      # Evaluate Ruby expression with sandbox
      # WARNING: Requires careful security review
      @conversation.instance_eval(value['expression'])
    rescue StandardError
      false
    end
  end
end
```

#### ApiCallService

**File**: `app/services/bot_studio/api_call_service.rb`

```ruby
module BotStudio
  class ApiCallService
    def initialize(template, context)
      @template = template
      @context = context
      @conversation = context[:conversation]
    end

    def execute
      response = make_api_call
      store_response(response) if @template.parameters['store_response_in']

      { success: true, response: response }
    rescue StandardError => e
      Rails.logger.error("API call failed: #{e.message}")
      { success: false, error: e.message }
    end

    private

    def make_api_call
      url = @template.parameters['url']
      method = @template.parameters['method'].downcase.to_sym
      headers = @template.parameters['headers'] || {}
      body = @template.parameters['body']

      response = HTTParty.send(method, url, {
        headers: headers,
        body: body&.to_json
      })

      response.parsed_response
    end

    def store_response(response)
      attribute_name = @template.parameters['store_response_in']
      custom_attributes = @conversation.custom_attributes || {}
      custom_attributes[attribute_name] = response

      @conversation.update(custom_attributes: custom_attributes)
    end
  end
end
```

#### SendIMessageAppService

**File**: `app/services/bot_studio/send_imessage_app_service.rb`

```ruby
module BotStudio
  class SendIMessageAppService
    def initialize(template, context)
      @template = template
      @context = context
      @conversation = context[:conversation]
    end

    def execute
      message_data = build_message_data

      # Send via Apple MSP
      AppleMessagesForBusiness::SendMessageService.new(
        conversation: @conversation,
        message_type: :interactive,
        interactive_data: message_data
      ).perform

      { success: true }
    end

    private

    def build_message_data
      params = @template.parameters

      {
        appId: params['app_id'],
        appName: params['app_name'],
        appIconUrl: params['app_icon_url'],
        launchUrl: params['launch_url'],
        data: params['data']
      }.compact
    end
  end
end
```

#### SendAppClipService

**File**: `app/services/bot_studio/send_app_clip_service.rb`

```ruby
module BotStudio
  class SendAppClipService
    def initialize(template, context)
      @template = template
      @context = context
      @conversation = context[:conversation]
    end

    def execute
      message_data = build_message_data

      # Send via Apple MSP
      AppleMessagesForBusiness::SendMessageService.new(
        conversation: @conversation,
        message_type: :interactive,
        interactive_data: message_data
      ).perform

      { success: true }
    end

    private

    def build_message_data
      params = @template.parameters

      {
        type: 'appClip',
        url: params['app_clip_url'],
        title: params['title'],
        subtitle: params['subtitle'],
        imageUrl: params['image_url'],
        actionTitle: params['action_title'] || 'Open'
      }.compact
    end
  end
end
```

### Step 5: Service Registry

Register the new services in the service registry.

**File**: `app/services/bot_studio/template_executor_service.rb`

```ruby
module BotStudio
  class TemplateExecutorService
    SERVICE_MAPPING = {
      # Existing services
      'send_text_message' => SendTextMessageService,
      'update_attributes' => UpdateAttributesService,
      'send_quick_reply' => SendQuickReplyService,
      'send_list_picker' => SendListPickerService,
      'send_time_picker' => SendTimePickerService,
      'send_form' => SendFormService,
      'send_apple_pay' => SendApplePayService,
      'send_rich_link' => SendRichLinkService,

      # NEW services
      'conditional_branch' => ConditionalBranchService,
      'api_call' => ApiCallService,
      'send_imessage_app' => SendIMessageAppService,
      'send_app_clip' => SendAppClipService
    }.freeze

    def self.execute(template, context)
      service_class = SERVICE_MAPPING[template.action_type]
      raise "Unknown action type: #{template.action_type}" unless service_class

      service_class.new(template, context).execute
    end
  end
end
```

### Step 6: Frontend Template Type Labels

Add labels for the new template types in the UI.

**File**: `app/javascript/dashboard/i18n/locale/en/agentBots.json`

```json
{
  "AGENT_BOTS": {
    "TEMPLATE_TYPES": {
      "CONDITIONAL_BRANCH": "Conditional Branch",
      "API_CALL": "API Call",
      "SEND_IMESSAGE_APP": "iMessage App",
      "SEND_APP_CLIP": "App Clip"
    }
  }
}
```

### Step 7: Migration

Create database migration if needed to add new action types.

**File**: `db/migrate/YYYYMMDDHHMMSS_add_new_template_types.rb`

```ruby
class AddNewTemplateTypes < ActiveRecord::Migration[7.0]
  def up
    # No schema changes needed if using text columns with validation
    # This migration is just for documentation

    # Optionally add check constraint if using enum in database
    # execute <<-SQL
    #   ALTER TABLE bot_action_templates
    #   DROP CONSTRAINT IF EXISTS check_action_type;
    #
    #   ALTER TABLE bot_action_templates
    #   ADD CONSTRAINT check_action_type
    #   CHECK (action_type IN (
    #     'send_text_message', 'update_attributes', 'send_quick_reply',
    #     'send_list_picker', 'send_time_picker', 'send_form',
    #     'send_apple_pay', 'send_rich_link', 'conditional_branch',
    #     'api_call', 'send_imessage_app', 'send_app_clip'
    #   ));
    # SQL
  end

  def down
    # Revert constraint if needed
  end
end
```

## Testing

### Unit Tests

**File**: `spec/services/bot_studio/conditional_branch_service_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe BotStudio::ConditionalBranchService do
  let(:conversation) { create(:conversation) }
  let(:message) { create(:message, conversation: conversation, content: 'hello world') }
  let(:template) { create(:bot_action_template, action_type: 'conditional_branch') }
  let(:context) { { conversation: conversation, message: message } }

  describe '#execute' do
    context 'with attribute_equals condition' do
      before do
        template.update(parameters: {
          'condition_type' => 'attribute_equals',
          'condition_value' => { 'attribute' => 'status', 'value' => 'active' },
          'true_action' => 123,
          'false_action' => 456
        })
        conversation.update(custom_attributes: { 'status' => 'active' })
      end

      it 'returns true_action template when condition is met' do
        result = described_class.new(template, context).execute
        expect(result.id).to eq(123)
      end
    end

    context 'with message_contains condition' do
      before do
        template.update(parameters: {
          'condition_type' => 'message_contains',
          'condition_value' => { 'text' => 'hello' },
          'true_action' => 789
        })
      end

      it 'returns true_action template when message contains text' do
        result = described_class.new(template, context).execute
        expect(result.id).to eq(789)
      end
    end
  end
end
```

## Security Considerations

### Custom Expression Sandbox

The `custom_expression` condition type allows arbitrary Ruby code execution. Implement proper sandboxing:

```ruby
def evaluate_custom_expression(value)
  # Use a sandboxed eval with timeout
  Timeout.timeout(1) do
    # Create isolated binding with only allowed variables
    binding = create_safe_binding
    binding.eval(value['expression'])
  end
rescue StandardError => e
  Rails.logger.warn("Custom expression failed: #{e.message}")
  false
end

def create_safe_binding
  # Create binding with limited scope
  # Only expose @conversation and @message as read-only
  SafeBinding.new(@conversation, @message).instance_eval { binding }
end
```

### API Call Security

Implement safeguards for external API calls:

```ruby
# Whitelist allowed domains
ALLOWED_DOMAINS = ENV['ALLOWED_API_DOMAINS']&.split(',') || []

def validate_url
  uri = URI.parse(@template.parameters['url'])

  unless ALLOWED_DOMAINS.any? { |domain| uri.host.end_with?(domain) }
    raise SecurityError, "Domain not whitelisted: #{uri.host}"
  end
end

# Rate limiting
def check_rate_limit
  key = "api_call:#{@conversation.account_id}:#{Date.today}"
  count = Rails.cache.read(key) || 0

  if count > MAX_API_CALLS_PER_DAY
    raise RateLimitError, "Daily API call limit exceeded"
  end

  Rails.cache.write(key, count + 1, expires_in: 24.hours)
end
```

## Monitoring

Add monitoring for the new services:

```ruby
# config/initializers/bot_studio_monitoring.rb

ActiveSupport::Notifications.subscribe('bot_studio.template_executed') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)

  Rails.logger.info({
    event: 'template_executed',
    template_type: event.payload[:template_type],
    duration: event.duration,
    success: event.payload[:success]
  }.to_json)
end
```

## Deployment Checklist

- [ ] Frontend components created and tested
- [ ] Backend services implemented
- [ ] Parameter validation schemas added
- [ ] Database migrations run (if needed)
- [ ] Security measures implemented
- [ ] Unit tests written and passing
- [ ] Integration tests written and passing
- [ ] Documentation updated
- [ ] Monitoring configured
- [ ] Feature flag enabled (if using feature flags)

## Rollback Plan

If issues are discovered in production:

1. **Frontend**: Remove new template types from UI selector
2. **Backend**: Disable service execution via feature flag
3. **Database**: No rollback needed (backward compatible)

```ruby
# app/services/bot_studio/template_executor_service.rb
def self.execute(template, context)
  if NEW_TEMPLATE_TYPES.include?(template.action_type)
    return { success: false, error: 'Template type disabled' } unless FeatureFlag.enabled?(:new_templates)
  end

  # ... existing code
end
```

## Conclusion

This integration guide covers all aspects of adding the 4 new complex template editor components to the Bot Studio system, from frontend registration to backend services, validation, testing, and security considerations.
