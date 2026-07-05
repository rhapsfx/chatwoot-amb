# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::ConversationCloseService do
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

  describe 'opaque-ID close (existing conversation)' do
    subject(:service) { described_class.new(inbox: amb_inbox, params: params, headers: headers) }

    let(:contact)       { create(:contact, account: account) }
    let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: amb_inbox, source_id: 'opaque-user-id') }
    let!(:conversation) do
      create(:conversation, account: account, inbox: amb_inbox, contact: contact, contact_inbox: contact_inbox, status: :open)
    end

    let(:params)  { { 'id' => SecureRandom.uuid, 'sourceId' => 'opaque-user-id', 'type' => 'close' } }
    let(:headers) { {} }

    it 'resolves the conversation and blocks the contact' do
      service.perform

      expect(conversation.reload.status).to eq('resolved')
      expect(contact.reload.additional_attributes['apple_messages_blocked']).to be true
    end

    it 'creates an activity message on the conversation' do
      expect { service.perform }.to change { conversation.messages.count }.by(1)
      expect(conversation.messages.last.message_type).to eq('activity')
    end

    it 'is idempotent for a second close event on an already-closed conversation' do
      service.perform
      expect { described_class.new(inbox: amb_inbox, params: params, headers: headers).perform }.not_to raise_error
    end
  end

  describe 'phone-shaped close (declined invitation / never conversed)' do
    subject(:service) { described_class.new(inbox: amb_inbox, params: params, headers: headers) }

    let(:contact) { create(:contact, account: account, phone_number: '+15551234567') }
    let(:params)  { { 'id' => SecureRandom.uuid, 'sourceId' => 'tel:+15551234567', 'type' => 'close' } }
    let(:headers) { {} }

    before { contact }

    it 'records an AppleInvitationOptOut row for the phone number' do
      service.perform

      opt_out = AppleInvitationOptOut.find_by(account_id: account.id, inbox_id: amb_inbox.id, phone_number: 'tel:+15551234567')
      expect(opt_out).to be_present
      expect(opt_out.contact_id).to eq(contact.id)
    end

    it 'does not raise when no contact matches the phone number' do
      no_match_params = params.merge('sourceId' => 'tel:+19998887777')
      expect { described_class.new(inbox: amb_inbox, params: no_match_params, headers: headers).perform }.not_to raise_error
      expect(AppleInvitationOptOut.where(phone_number: 'tel:+19998887777')).to be_empty
    end

    it 'does not touch Contact#additional_attributes apple_messages_blocked (that flag is opaque-ID-flow only)' do
      service.perform
      expect(contact.reload.additional_attributes['apple_messages_blocked']).to be_nil
    end
  end
end
