# frozen_string_literal: true

FactoryBot.define do
  factory :message_template do
    sequence(:name) { |n| "Test Template #{n}" }
    status { 'active' }
    category { 'general' }
    description { 'Test template description' }
    version { 1 }
    account

    parameters do
      {
        'business_name' => {
          'type' => 'string',
          'required' => true,
          'description' => 'Name of the business',
          'example' => 'Acme Corp'
        }
      }
    end

    supported_channels { ['apple_messages_for_business'] }
    tags { %w[test sample] }
    use_cases { ['scheduling'] }

    trait :with_attachments do
      after(:create) do |template|
        template.attachments.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/test_image.jpg')),
          filename: 'test_image.jpg',
          content_type: 'image/jpeg'
        )

        template.attachments.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/test_document.pdf')),
          filename: 'test_document.pdf',
          content_type: 'application/pdf'
        )

        # Initialize attachment metadata
        template.attachment_metadata = {
          'attachments' => [
            {
              'id' => template.attachments[0].id.to_s,
              'display_order' => 0,
              'description' => 'Test image attachment',
              'attached_at' => Time.current.iso8601,
              'updated_at' => Time.current.iso8601
            },
            {
              'id' => template.attachments[1].id.to_s,
              'display_order' => 1,
              'description' => 'Test PDF attachment',
              'attached_at' => Time.current.iso8601,
              'updated_at' => Time.current.iso8601
            }
          ]
        }
        template.save!
      end
    end

    trait :draft do
      status { 'draft' }
    end

    trait :deprecated do
      status { 'deprecated' }
    end

    trait :with_list_picker_content do
      after(:create) do |template|
        template.metadata = {
          'apple_message_content' => {
            'content' => 'Select a product',
            'content_attributes' => {
              'sections' => [
                {
                  'title' => 'Products',
                  'items' => [
                    { 'identifier' => 'item_1', 'title' => 'Product A', 'style' => 'icon' },
                    { 'identifier' => 'item_2', 'title' => 'Product B', 'style' => 'icon' }
                  ]
                }
              ]
            }
          }
        }
        template.save!
      end
    end

    trait :with_time_picker_content do
      after(:create) do |template|
        template.metadata = {
          'apple_message_content' => {
            'content' => 'Select a time',
            'content_attributes' => {
              'event' => {
                'identifier' => 'appointment_booking',
                'timeslots' => [
                  { 'start_time' => '2025-01-15T10:00:00Z', 'duration' => 1800 },
                  { 'start_time' => '2025-01-15T11:00:00Z', 'duration' => 1800 }
                ]
              }
            }
          }
        }
        template.save!
      end
    end
  end
end
