# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::ConversationReopenService do
  subject(:service) { described_class.new(inbox: inbox, source_id: source_id) }

  let(:account) { create(:account) }
  let(:channel) do
    allow_any_instance_of(Channel::AppleMessagesForBusiness).to receive(:validate_jwt_credentials).and_return(nil)
    create(:channel_apple_messages_for_business, account: account)
  end
  let(:inbox) { channel.inbox }
  let(:source_id) { 'matthieu@rhaps.net' }
  let(:contact) do
    create(:contact, account: account,
                     additional_attributes: {
                       'apple_messages_blocked' => true,
                       'apple_messages_blocked_at' => Time.current.iso8601,
                       'apple_messages_block_reason' => 'customer_opted_out'
                     })
  end
  let!(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: source_id) }

  describe '#perform' do
    context 'when contact is found via ContactInbox source_id' do
      it 'removes the blocked flag' do
        service.perform
        expect(contact.reload.additional_attributes['apple_messages_blocked']).to be_nil
      end

      it 'removes blocked_at and block_reason' do
        service.perform
        attrs = contact.reload.additional_attributes
        expect(attrs['apple_messages_blocked_at']).to be_nil
        expect(attrs['apple_messages_block_reason']).to be_nil
      end

      it 'sets reopened_at' do
        service.perform
        expect(contact.reload.additional_attributes['apple_messages_reopened_at']).to be_present
      end
    end

    context 'when contact is not blocked' do
      let(:contact) { create(:contact, account: account) }

      it 'does not raise' do
        expect { service.perform }.not_to raise_error
      end
    end

    context 'when no ContactInbox matches source_id' do
      subject(:service) { described_class.new(inbox: inbox, source_id: 'unknown@user.com') }

      it 'does not raise' do
        expect { service.perform }.not_to raise_error
      end
    end
  end
end
