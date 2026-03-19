# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::AppleMessagesForBusinessEventsJob do
  let(:account) { create(:account) }
  let(:channel) do
    allow_any_instance_of(Channel::AppleMessagesForBusiness).to receive(:validate_jwt_credentials).and_return(nil)
    create(:channel_apple_messages_for_business, account: account)
  end
  let(:headers) { { source_id: 'user@example.com', destination_id: 'msp-uuid', capability_list: 'AUTH' } }

  before do
    allow(Channel::AppleMessagesForBusiness).to receive(:find).and_return(channel)
    allow(channel.account).to receive(:active?).and_return(true)
  end

  describe '#perform' do
    context 'close event without referenceIds (regular AMB close)' do
      let(:payload) { { 'type' => 'close', 'id' => 'evt-123', 'sourceId' => 'user@example.com' } }

      it 'routes to ConversationCloseService' do
        expect(AppleMessagesForBusiness::ConversationCloseService).to receive(:new).and_return(
          instance_double(AppleMessagesForBusiness::ConversationCloseService, perform: nil)
        )
        expect(AppleMessagesForBusiness::CloseSessionHandlerService).not_to receive(:new)

        described_class.perform_now(channel.id, payload, headers)
      end
    end

    context 'close event with referenceIds (invitation opt-out)' do
      let(:payload) do
        { 'type' => 'close', 'sourceId' => 'tel:+33123456789', 'referenceIds' => ['ref-abc'] }
      end

      it 'routes to CloseSessionHandlerService' do
        expect(AppleMessagesForBusiness::CloseSessionHandlerService).to receive(:new).and_return(
          instance_double(AppleMessagesForBusiness::CloseSessionHandlerService, perform: nil)
        )
        expect(AppleMessagesForBusiness::ConversationCloseService).not_to receive(:new)

        described_class.perform_now(channel.id, payload, headers)
      end
    end

    context 'text message' do
      let(:payload) { { 'type' => 'text', 'id' => 'msg-123', 'body' => 'Hello' } }

      it 'routes to IncomingMessageService' do
        expect(AppleMessagesForBusiness::IncomingMessageService).to receive(:new).and_return(
          instance_double(AppleMessagesForBusiness::IncomingMessageService, perform: nil)
        )

        described_class.perform_now(channel.id, payload, headers)
      end
    end
  end
end
