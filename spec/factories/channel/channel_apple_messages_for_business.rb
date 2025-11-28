# frozen_string_literal: true

FactoryBot.define do
  factory :channel_apple_messages_for_business, class: 'Channel::AppleMessagesForBusiness' do
    sequence(:msp_id) { |n| "msp_#{n}" }
    sequence(:business_id) { |n| "business_#{n}" }
    # Generate a valid Base64-encoded secret for JWT validation
    secret { Base64.strict_encode64(SecureRandom.random_bytes(32)) }
    account

    after(:create) do |channel|
      create(:inbox, channel: channel, account: channel.account)
    end
  end
end
