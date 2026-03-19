# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::MessageProcessorService do
  let(:account) { create(:account) }
  let(:channel) do
    allow_any_instance_of(Channel::AppleMessagesForBusiness).to receive(:validate_jwt_credentials).and_return(nil)
    create(:channel_apple_messages_for_business, account: account)
  end
  let(:inbox) { channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) { create(:conversation, contact: contact, inbox: inbox, contact_inbox: contact_inbox, account: account) }
  let(:user) { create(:user, account: account) }

  let(:blocked_contact) do
    create(:contact, account: account,
                     additional_attributes: { 'apple_messages_blocked' => true })
  end
  let(:blocked_contact_inbox) { create(:contact_inbox, contact: blocked_contact, inbox: inbox) }
  let(:blocked_conversation) do
    create(:conversation, contact: blocked_contact, inbox: inbox,
                          contact_inbox: blocked_contact_inbox, account: account, status: :resolved)
  end

  describe '#process_and_send' do
    context 'when customer has opted out' do
      it 'raises an error for regular messages' do
        params = { content: 'Hello', content_type: 'text' }
        service = described_class.new(blocked_conversation, params, user)

        expect { service.process_and_send }.to raise_error(StandardError, /opted out/)
      end

      it 'allows apple_invitation messages to bypass the opt-out check' do
        params = {
          content: 'Apple Invitation: binaryChoice.engage.noImage',
          content_type: 'apple_invitation',
          content_attributes: {
            'invitation_template_id' => 'binaryChoice.engage.noImage',
            'reference_id' => '123',
            'parameters' => { 'brand_name' => 'Test' }
          }
        }
        service = described_class.new(blocked_conversation, params, user)

        allow_any_instance_of(Messages::MessageBuilder).to receive(:perform).and_return(
          create(:message, conversation: blocked_conversation, account: account)
        )

        expect { service.process_and_send }.not_to raise_error
      end
    end

    context 'apple_specific_content_type?' do
      subject(:service) { described_class.new(conversation, {}, user) }

      it 'recognises apple_invitation as an apple-specific content type' do
        expect(service.send(:apple_specific_content_type?, 'apple_invitation')).to be true
      end

      it 'recognises all other apple content types' do
        %w[apple_form apple_list_picker apple_quick_reply apple_time_picker
           apple_custom_app apple_pay apple_authentication apple_custom_payload apple_rich_link].each do |ct|
          expect(service.send(:apple_specific_content_type?, ct)).to be true
        end
      end

      it 'returns false for non-apple content types' do
        expect(service.send(:apple_specific_content_type?, 'text')).to be false
      end
    end
  end
end
