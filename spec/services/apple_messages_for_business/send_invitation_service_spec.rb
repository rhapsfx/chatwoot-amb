# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::SendInvitationService do
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

  def build_service(reference_id: 'campaign-1-contact-1', destination_id: 'tel:+15551234567')
    described_class.new(
      inbox: amb_inbox,
      destination_id: destination_id,
      template_id: 'binaryChoice.engage.withImage',
      reference_id: reference_id,
      parameters: { 'brandName' => 'Acme' },
      locale: 'en-us'
    )
  end

  describe 'reference_id validation' do
    it 'rejects a blank reference_id without making an HTTP call' do
      expect(HTTParty).not_to receive(:post)
      result = build_service(reference_id: '').perform
      expect(result[:success]).to be false
      expect(result[:error]).to match(/required/)
    end

    it 'rejects a reference_id over 1000 characters' do
      expect(HTTParty).not_to receive(:post)
      result = build_service(reference_id: 'a' * 1001).perform
      expect(result[:success]).to be false
      expect(result[:error]).to match(/1000 characters/)
    end

    it 'rejects a reference_id containing a quote or apostrophe' do
      expect(HTTParty).not_to receive(:post)
      result = build_service(reference_id: "campaign's ref").perform
      expect(result[:success]).to be false
      expect(result[:error]).to match(/quote or apostrophe/)
    end
  end

  describe 'opt-out gating' do
    it 'refuses to send when the destination has opted out' do
      AppleInvitationOptOut.create!(
        account: account, inbox: amb_inbox, contact: create(:contact, account: account),
        phone_number: 'tel:+15551234567', opted_out_at: Time.current
      )

      expect(HTTParty).not_to receive(:post)
      result = build_service.perform
      expect(result[:success]).to be false
      expect(result[:error]).to match(/opted out/)
    end
  end

  describe 'response handling' do
    it 'returns success on a 2xx response' do
      response = instance_double(HTTParty::Response, success?: true, code: 200, body: '{}')
      allow(HTTParty).to receive(:post).and_return(response)

      result = build_service.perform
      expect(result[:success]).to be true
    end

    it 'returns error_code UNDELIVERABLE_FALLBACK_REQUIRED on a 404 (spec: MSP must fall back to another channel)' do
      response = instance_double(HTTParty::Response, success?: false, code: 404, body: 'not found')
      allow(HTTParty).to receive(:post).and_return(response)

      result = build_service.perform
      expect(result[:success]).to be false
      expect(result[:error_code]).to eq('UNDELIVERABLE_FALLBACK_REQUIRED')
    end

    it 'does not treat a 410 as an opt-out signal (410 for invitations means a header bug, not user opt-out)' do
      response = instance_double(HTTParty::Response, success?: false, code: 410, body: 'gone')
      allow(HTTParty).to receive(:post).and_return(response)

      expect(AppleInvitationOptOut).not_to receive(:find_or_initialize_by)
      result = build_service.perform
      expect(result[:success]).to be false
      expect(result[:error_code]).to be_nil
    end
  end
end
