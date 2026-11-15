# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::AuthenticationCompleteJob do
  describe '#identity_label' do
    subject(:label) { described_class.new.send(:identity_label, user_data) }

    context 'with name and email' do
      let(:user_data) { { 'name' => 'Johnny Appleseed', 'email' => 'johnny@example.com' } }

      it { is_expected.to eq('Johnny Appleseed (johnny@example.com)') }
    end

    context 'with only a name' do
      let(:user_data) { { 'name' => 'Johnny Appleseed' } }

      it { is_expected.to eq('Johnny Appleseed') }
    end

    context 'with only an email' do
      let(:user_data) { { 'email' => 'johnny@example.com' } }

      it { is_expected.to eq('johnny@example.com') }
    end

    context 'with neither' do
      let(:user_data) { {} }

      it { is_expected.to eq('your account') }
    end
  end
end
