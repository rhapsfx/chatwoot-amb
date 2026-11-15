# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::AppleMessagesForBusinessEventsJob do
  let(:account) { create(:account) }

  let(:amb_channel) do
    Channel::AppleMessagesForBusiness.create!(
      account: account,
      msp_id: 'test-msp-id',
      business_id: "biz-#{SecureRandom.hex(4)}",
      secret: 'test-secret'
    )
  end
  let(:amb_inbox) { create(:inbox, account: account, channel: amb_channel) }

  before { amb_inbox }

  describe '#perform for type: close' do
    it 'routes an opaque-ID sourceId to ConversationCloseService' do
      payload = { 'type' => 'close', 'id' => SecureRandom.uuid, 'sourceId' => 'opaque-user-id' }
      headers = {}

      expect(AppleMessagesForBusiness::ConversationCloseService).to receive(:new)
        .with(inbox: amb_inbox, params: payload, headers: headers)
        .and_call_original

      described_class.new.perform(amb_channel.id, payload, headers)
    end

    it 'routes a tel:-shaped sourceId through the same ConversationCloseService (which branches internally)' do
      payload = { 'type' => 'close', 'id' => SecureRandom.uuid, 'sourceId' => 'tel:+15551234567' }
      headers = {}

      expect(AppleMessagesForBusiness::ConversationCloseService).to receive(:new)
        .with(inbox: amb_inbox, params: payload, headers: headers)
        .and_call_original

      described_class.new.perform(amb_channel.id, payload, headers)
    end

    it 'does not branch on the presence of referenceIds (legacy dead-code discriminator removed)' do
      payload = { 'type' => 'close', 'id' => SecureRandom.uuid, 'sourceId' => 'tel:+15551234567', 'referenceIds' => ['some-ref'] }
      headers = {}

      expect(AppleMessagesForBusiness::ConversationCloseService).to receive(:new).and_call_original

      described_class.new.perform(amb_channel.id, payload, headers)
    end

    it 'no longer references the retired CloseSessionHandlerService class' do
      expect(defined?(AppleMessagesForBusiness::CloseSessionHandlerService)).to be_nil
    end
  end
end
