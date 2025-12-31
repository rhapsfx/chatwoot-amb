# frozen_string_literal: true

FactoryBot.define do
  factory :bot_action_template do
    sequence(:name) { |n| "Bot Action Template #{n}" }
    template_type { 'send_text_message' }
    execution_order { 0 }
    account

    parameters do
      {
        'message' => 'Hello! How can I help you today?'
      }
    end

    metadata do
      {
        'description' => 'Default bot action template',
        'created_by' => 'system'
      }
    end

    # Trait for send_text_message with delay
    trait :with_delay do
      parameters do
        {
          'message' => 'This message will be sent with a delay',
          'delay_seconds' => 5
        }
      end
    end

    # Trait for send_list_picker
    trait :list_picker do
      template_type { 'send_list_picker' }
      parameters do
        {
          'template_id' => 123,
          'wait_for_response' => true
        }
      end
    end

    # Trait for send_time_picker
    trait :time_picker do
      template_type { 'send_time_picker' }
      parameters do
        {
          'template_id' => 456,
          'timezone_offset' => 28_800,
          'location_data' => {
            'latitude' => 37.7749,
            'longitude' => -122.4194
          }
        }
      end
    end

    # Trait for send_form
    trait :form do
      template_type { 'send_form' }
      parameters do
        {
          'template_id' => 789,
          'pre_fill_data' => {
            'name' => 'John Doe',
            'email' => 'john@example.com'
          }
        }
      end
    end

    # Trait for send_rich_link
    trait :rich_link do
      template_type { 'send_rich_link' }
      parameters do
        {
          'url' => 'https://example.com',
          'title' => 'Check out this link',
          'subtitle' => 'Click to learn more',
          'image_url' => 'https://example.com/image.jpg'
        }
      end
    end

    # Trait for send_quick_reply
    trait :quick_reply do
      template_type { 'send_quick_reply' }
      parameters do
        {
          'message' => 'Please select an option',
          'request_id' => 'quick_reply_123',
          'items' => [
            { 'identifier' => 'yes', 'title' => 'Yes' },
            { 'identifier' => 'no', 'title' => 'No' }
          ]
        }
      end
    end

    # Trait for update_attributes
    trait :update_attributes do
      template_type { 'update_attributes' }
      parameters do
        {
          'attributes' => {
            'customer_name' => 'John Doe',
            'status' => 'active'
          }
        }
      end
    end

    # Trait for conditional_branch
    trait :conditional_branch do
      template_type { 'conditional_branch' }
      parameters do
        {
          'condition_type' => 'equals',
          'condition_value' => 'yes',
          'true_action' => 'send_confirmation',
          'false_action' => 'send_cancellation'
        }
      end
    end

    # Trait for send_apple_pay
    trait :apple_pay do
      template_type { 'send_apple_pay' }
      parameters do
        {
          'merchant_id' => 'merchant.com.example',
          'item_name' => 'Premium Subscription',
          'amount' => 9.99,
          'currency' => 'USD'
        }
      end
    end

    # Trait for api_call
    trait :api_call do
      template_type { 'api_call' }
      parameters do
        {
          'url' => 'https://api.example.com/endpoint',
          'method' => 'POST',
          'headers' => {
            'Content-Type' => 'application/json',
            'Authorization' => 'Bearer token123'
          },
          'body' => {
            'key' => 'value'
          },
          'store_response_in' => 'api_response'
        }
      end
    end

    # Trait for send_imessage_app
    trait :imessage_app do
      template_type { 'send_imessage_app' }
      parameters do
        {
          'app_id' => 'com.example.app',
          'app_name' => 'Example App',
          'app_icon_url' => 'https://example.com/icon.png',
          'launch_url' => 'https://example.com/launch',
          'data' => {
            'custom_field' => 'value'
          }
        }
      end
    end

    # Trait for send_app_clip
    trait :app_clip do
      template_type { 'send_app_clip' }
      parameters do
        {
          'app_clip_url' => 'https://example.com/clip',
          'title' => 'Try our App Clip',
          'subtitle' => 'Quick and easy',
          'image_url' => 'https://example.com/clip-image.jpg',
          'action_title' => 'Open'
        }
      end
    end

    # Trait with invalid parameters (for testing validation)
    trait :invalid_parameters do
      parameters do
        {
          'invalid_param' => 'This parameter does not exist'
        }
      end
    end

    # Trait with missing required parameters (for testing validation)
    trait :missing_required_parameters do
      parameters { {} }
    end

    # Trait with custom execution order
    trait :high_priority do
      execution_order { 1 }
    end

    trait :low_priority do
      execution_order { 10 }
    end
  end
end
