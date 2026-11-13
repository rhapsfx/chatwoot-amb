# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleInvitationOptOut do
  let(:account)       { create(:account) }
  let(:other_account) { create(:account) }

  let(:amb_channel) do
    Channel::AppleMessagesForBusiness.create!(
      account: account,
      msp_id: 'test-msp-id',
      business_id: "biz-#{SecureRandom.hex(4)}",
      secret: 'test-secret'
    )
  end
  let(:amb_inbox) { create(:inbox, account: account, channel: amb_channel) }
  let(:contact)   { create(:contact, account: account) }

  let(:other_amb_channel) do
    Channel::AppleMessagesForBusiness.create!(
      account: other_account,
      msp_id: 'other-msp-id',
      business_id: "biz-#{SecureRandom.hex(4)}",
      secret: 'other-secret'
    )
  end
  let(:other_amb_inbox) { create(:inbox, account: other_account, channel: other_amb_channel) }
  let(:other_contact)   { create(:contact, account: other_account) }

  describe 'validations' do
    it 'requires phone_number and opted_out_at' do
      opt_out = described_class.new(account: account, contact: contact, inbox: amb_inbox)
      expect(opt_out).not_to be_valid
      expect(opt_out.errors[:phone_number]).to be_present
      expect(opt_out.errors[:opted_out_at]).to be_present
    end

    it 'enforces uniqueness scoped to account_id and inbox_id' do
      described_class.create!(account: account, contact: contact, inbox: amb_inbox, phone_number: 'tel:+15551234567', opted_out_at: Time.current)

      duplicate = described_class.new(account: account, contact: contact, inbox: amb_inbox, phone_number: 'tel:+15551234567',
                                      opted_out_at: Time.current)
      expect(duplicate).not_to be_valid
    end
  end

  describe '.opted_out?' do
    before do
      described_class.create!(account: account, contact: contact, inbox: amb_inbox, phone_number: 'tel:+15551234567', opted_out_at: Time.current)
    end

    it 'returns true for the matching account/phone/inbox combination' do
      expect(described_class.opted_out?(account_id: account.id, phone_number: 'tel:+15551234567', inbox_id: amb_inbox.id)).to be true
    end

    it 'returns false for a different account even with the same phone number and inbox id' do
      # Regression test: opted_out? must be scoped by account_id, not just phone_number + inbox_id,
      # since the unique index is [account_id, phone_number, inbox_id].
      expect(described_class.opted_out?(account_id: other_account.id, phone_number: 'tel:+15551234567', inbox_id: amb_inbox.id)).to be false
    end

    it 'returns false for a different phone number' do
      expect(described_class.opted_out?(account_id: account.id, phone_number: 'tel:+19998887777', inbox_id: amb_inbox.id)).to be false
    end
  end
end
