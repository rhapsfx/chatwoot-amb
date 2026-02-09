FactoryBot.define do
  factory :apple_list_picker_image do
    account { inbox&.account || association(:account) }
    inbox
    sequence(:identifier) { |n| "picker_img_#{n}" }
    description { 'Test picker image' }
    original_name { 'test_picker_image.png' }

    after(:build) do |picker_image|
      picker_image.image.attach(
        io: Rails.root.join('spec/assets/avatar.png').open,
        filename: 'avatar.png',
        content_type: 'image/png'
      )
    end

    trait :without_attachment do
      after(:build) do |picker_image|
        picker_image.image.purge if picker_image.image.attached?
      end
    end
  end
end
