# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::ConversationCloseService do
  subject(:service) { described_class.new(inbox: inbox, params: params, headers: headers) }

  let(:account) { create(:account) }
  let(:channel) do
    allow_any_instance_of(Channel::AppleMessagesForBusiness).to receive(:validate_jwt_credentials).and_return(nil)
    create(:channel_apple_messages_for_business, account: account)
  end
  let(:inbox) { channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:source_id) { 'matthieu@rhaps.net' }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: source_id) }
  let!(:conversation) { create(:conversation, contact: contact, inbox: inbox, contact_inbox: contact_inbox, account: account, status: :open) }

  let(:params) do
    { 'type' => 'close', 'id' => 'event-uuid-123', 'sourceId' => source_id, 'destinationId' => 'msp-uuid' }
  end
  let(:headers) { { source_id: source_id, destination_id: 'msp-uuid', capability_list: 'AUTH,LIST' } }

  describe '#perform' do
    context 'when contact is found via ContactInbox source_id' do
      it 'closes the conversation' do
        service.perform
        expect(conversation.reload.status).to eq('resolved')
      end

      it 'sets closed_by in conversation additional_attributes' do
        service.perform
        expect(conversation.reload.additional_attributes['closed_by']).to eq('apple_messages_for_business')
      end

      it 'blocks the contact' do
        service.perform
        expect(contact.reload.additional_attributes['apple_messages_blocked']).to be true
      end

      it 'creates an activity message' do
        expect { service.perform }.to change { conversation.messages.where(message_type: :activity).count }.by(1)
      end
    end

    context 'when contact has apple_messages_source_id in additional_attributes (legacy)' do
      let(:contact_with_attr) do
        create(:contact, account: account,
                         additional_attributes: { 'apple_messages_source_id' => source_id })
      end
      let(:contact_inbox_with_attr) do
        create(:contact_inbox, contact: contact_with_attr, inbox: inbox, source_id: source_id)
      end
      let!(:conversation_with_attr) do
        create(:conversation, contact: contact_with_attr, inbox: inbox,
                              contact_inbox: contact_inbox_with_attr, account: account, status: :open)
      end

      it 'still finds and closes the conversation' do
        service2 = described_class.new(inbox: inbox, params: params, headers: headers)
        service2.perform
        expect(conversation_with_attr.reload.status).to eq('resolved')
      end
    end

    context 'when no contact is found' do
      let(:params) { { 'type' => 'close', 'id' => 'event-uuid-123', 'sourceId' => 'unknown@user.com' } }
      let(:headers) { { source_id: 'unknown@user.com' } }

      it 'does not raise and logs a warning' do
        expect { service.perform }.not_to raise_error
      end

      it 'does not change the conversation status' do
        service.perform
        expect(conversation.reload.status).to eq('open')
      end
    end

    context 'when params are invalid' do
      let(:params) { { 'type' => 'close' } }

      it 'does not raise and returns early' do
        expect { service.perform }.not_to raise_error
      end
    end

    context 'when conversation is already closed by AMB' do
      before do
        conversation.update!(
          status: :resolved,
          additional_attributes: { 'closed_by' => 'apple_messages_for_business' }
        )
      end

      it 'skips duplicate processing' do
        expect { service.perform }.not_to(change { conversation.messages.count })
      end
    end
  end
end
