# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::AuthenticationService do
  let(:account) { create(:account) }
  let(:channel) do
    Channel::AppleMessagesForBusiness.create!(
      account: account,
      msp_id: 'test-msp-id',
      business_id: "biz-#{SecureRandom.hex(4)}",
      secret: 'test-secret'
    )
  end
  let(:service) { described_class.new(channel) }

  describe '.consume_oauth_state' do
    let(:state) { SecureRandom.hex(16) }
    let(:key) { "oauth_state:#{state}" }
    let(:payload) do
      {
        channel_id: channel.id,
        destination_id: 'opaque-user-id',
        provider: 'google',
        request_identifier: 'request-1'
      }
    end

    before { Redis::Alfred.setex(key, payload.to_json, 600) }
    after { Redis::Alfred.delete(key) }

    it 'returns the stored state' do
      expect(described_class.consume_oauth_state(state))
        .to include('provider' => 'google', 'request_identifier' => 'request-1')
    end

    it 'rejects a replayed state' do
      described_class.consume_oauth_state(state)

      expect(described_class.consume_oauth_state(state)).to be_nil
    end

    it 'returns nil for a missing state' do
      expect(described_class.consume_oauth_state(nil)).to be_nil
      expect(described_class.consume_oauth_state('unknown')).to be_nil
    end
  end

  describe '#consume_authentication_result' do
    let(:request_identifier) { SecureRandom.uuid }
    let(:key) { "apple_auth_result:#{request_identifier}" }

    before do
      service.store_authentication_result(
        request_identifier: request_identifier,
        destination_id: 'opaque-user-id',
        provider: 'google',
        user: { 'email' => 'user@example.com' },
        authenticated_at: Time.current
      )
    end

    after { Redis::Alfred.delete(key) }

    it 'returns the pending identity for the OpaqueID the request was sent to' do
      result = service.consume_authentication_result(
        request_identifier: request_identifier,
        source_id: 'opaque-user-id'
      )

      expect(result).to include('user' => { 'email' => 'user@example.com' }, 'provider' => 'google')
    end

    it 'links only once' do
      service.consume_authentication_result(request_identifier: request_identifier, source_id: 'opaque-user-id')

      expect(
        service.consume_authentication_result(request_identifier: request_identifier, source_id: 'opaque-user-id')
      ).to be_nil
    end

    it 'returns nothing when the response comes from another OpaqueID' do
      expect(
        service.consume_authentication_result(request_identifier: request_identifier, source_id: 'someone-else')
      ).to be_nil
    end

    it 'keeps the pending identity for a short time only' do
      expect(Redis::Alfred.ttl(key)).to be_between(1, described_class::AUTH_RESULT_TTL)
    end

    it 'returns nothing for an unknown request' do
      expect(
        service.consume_authentication_result(request_identifier: SecureRandom.uuid, source_id: 'opaque-user-id')
      ).to be_nil
    end
  end

  describe '#process_oauth2_callback' do
    it 'rejects a state that was already consumed' do
      expect(service.process_oauth2_callback('code', nil, 'google'))
        .to include(error: 'Invalid or expired state')
    end
  end
end
