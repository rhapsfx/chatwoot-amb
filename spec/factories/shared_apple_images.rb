# frozen_string_literal: true

FactoryBot.define do
  factory :shared_apple_image do
    account
    sequence(:identifier) { |n| "apple_img_#{n}" }
    image_type { 'system' }
    description { 'Test image description' }
    original_name { 'test_image.png' }
    metadata { { width: 400, height: 400 } }

    after(:build) do |shared_image|
      shared_image.image.attach(
        io: Rails.root.join('spec/assets/avatar.png').open,
        filename: 'avatar.png',
        content_type: 'image/png'
      )
    end

    trait :branding do
      image_type { 'branding' }
      description { 'Branding image' }
    end

    trait :template do
      image_type { 'template' }
      description { 'Template image' }
    end

    trait :without_attachment do
      after(:build) do |shared_image|
        shared_image.image.purge if shared_image.image.attached?
      end
    end
  end
end
