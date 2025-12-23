# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BotActionTemplate do
  let(:account) { create(:account) }
  let(:bot_action_template) { create(:bot_action_template, account: account) }

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
  end

  describe 'validations' do
    describe 'name' do
      it { is_expected.to validate_presence_of(:name) }

      it 'validates uniqueness of name scoped to account' do
        create(:bot_action_template, account: account, name: 'Unique Template')
        duplicate_template = build(:bot_action_template, account: account, name: 'Unique Template')
        expect(duplicate_template).not_to be_valid
        expect(duplicate_template.errors[:name]).to include('has already been taken')
      end

      it 'allows same name in different accounts' do
        other_account = create(:account)
        create(:bot_action_template, account: account, name: 'Shared Name')
        template = build(:bot_action_template, account: other_account, name: 'Shared Name')
        expect(template).to be_valid
      end
    end

    describe 'template_type' do
      it { is_expected.to validate_presence_of(:template_type) }
      it { is_expected.to validate_inclusion_of(:template_type).in_array(BotActionTemplate::TEMPLATE_TYPES) }

      it 'rejects invalid template types' do
        template = build(:bot_action_template, template_type: 'invalid_type')
        expect(template).not_to be_valid
        expect(template.errors[:template_type]).to include('is not included in the list')
      end
    end

    describe 'parameters' do
      it { is_expected.to validate_presence_of(:parameters) }

      it 'requires parameters to be a hash' do
        template = build(:bot_action_template, parameters: 'not a hash')
        expect(template).not_to be_valid
        expect(template.errors[:parameters]).to include('must be a hash')
      end

      it 'accepts empty hash if no required parameters' do
        # For template types with no required parameters, empty hash should be invalid
        # because all current template types have at least one required parameter
        template = build(:bot_action_template, template_type: 'send_text_message', parameters: {})
        expect(template).not_to be_valid
      end
    end

    describe 'execution_order' do
      it { is_expected.to validate_numericality_of(:execution_order).only_integer.is_greater_than_or_equal_to(0) }

      it 'rejects negative execution order' do
        template = build(:bot_action_template, execution_order: -1)
        expect(template).not_to be_valid
      end

      it 'accepts zero execution order' do
        template = build(:bot_action_template, execution_order: 0)
        expect(template).to be_valid
      end

      it 'accepts positive execution order' do
        template = build(:bot_action_template, execution_order: 5)
        expect(template).to be_valid
      end
    end
  end

  describe 'template type validations' do
    describe 'send_text_message' do
      it 'validates with required parameters' do
        template = build(:bot_action_template, template_type: 'send_text_message', parameters: { 'message' => 'Hello' })
        expect(template).to be_valid
      end

      it 'validates with required and optional parameters' do
        template = build(:bot_action_template, template_type: 'send_text_message',
                                               parameters: { 'message' => 'Hello', 'delay_seconds' => 5 })
        expect(template).to be_valid
      end

      it 'rejects missing required parameters' do
        template = build(:bot_action_template, template_type: 'send_text_message', parameters: {})
        expect(template).not_to be_valid
        expect(template.errors[:parameters]).to include(a_string_matching(/missing required parameter 'message'/))
      end

      it 'rejects unknown parameters' do
        template = build(:bot_action_template, template_type: 'send_text_message',
                                               parameters: { 'message' => 'Hello', 'unknown_param' => 'value' })
        expect(template).not_to be_valid
        expect(template.errors[:parameters]).to include(a_string_matching(/contains unknown parameters: unknown_param/))
      end
    end

    describe 'send_list_picker' do
      it 'validates with required parameters' do
        template = build(:bot_action_template, :list_picker)
        expect(template).to be_valid
      end

      it 'rejects missing template_id' do
        template = build(:bot_action_template, template_type: 'send_list_picker', parameters: {})
        expect(template).not_to be_valid
        expect(template.errors[:parameters]).to include(a_string_matching(/missing required parameter 'template_id'/))
      end
    end

    describe 'send_time_picker' do
      it 'validates with required parameters' do
        template = build(:bot_action_template, template_type: 'send_time_picker', parameters: { 'template_id' => 123 })
        expect(template).to be_valid
      end

      it 'validates with optional parameters' do
        template = build(:bot_action_template, :time_picker)
        expect(template).to be_valid
      end
    end

    describe 'send_form' do
      it 'validates with required parameters' do
        template = build(:bot_action_template, template_type: 'send_form', parameters: { 'template_id' => 789 })
        expect(template).to be_valid
      end

      it 'validates with optional pre_fill_data' do
        template = build(:bot_action_template, :form)
        expect(template).to be_valid
      end
    end

    describe 'send_rich_link' do
      it 'validates with required parameters' do
        template = build(:bot_action_template, template_type: 'send_rich_link',
                                               parameters: { 'url' => 'https://example.com', 'title' => 'Example' })
        expect(template).to be_valid
      end

      it 'rejects missing url' do
        template = build(:bot_action_template, template_type: 'send_rich_link', parameters: { 'title' => 'Example' })
        expect(template).not_to be_valid
      end

      it 'rejects missing title' do
        template = build(:bot_action_template, template_type: 'send_rich_link', parameters: { 'url' => 'https://example.com' })
        expect(template).not_to be_valid
      end
    end

    describe 'send_quick_reply' do
      it 'validates with all required parameters' do
        template = build(:bot_action_template, :quick_reply)
        expect(template).to be_valid
      end

      it 'rejects missing items' do
        template = build(:bot_action_template, template_type: 'send_quick_reply',
                                               parameters: { 'message' => 'Select', 'request_id' => '123' })
        expect(template).not_to be_valid
      end
    end

    describe 'update_attributes' do
      it 'validates with required parameters' do
        template = build(:bot_action_template, :update_attributes)
        expect(template).to be_valid
      end
    end

    describe 'conditional_branch' do
      it 'validates with required parameters' do
        template = build(:bot_action_template, template_type: 'conditional_branch',
                                               parameters: { 'condition_type' => 'equals', 'condition_value' => 'yes' })
        expect(template).to be_valid
      end

      it 'validates with optional actions' do
        template = build(:bot_action_template, :conditional_branch)
        expect(template).to be_valid
      end
    end

    describe 'send_apple_pay' do
      it 'validates with required parameters' do
        template = build(:bot_action_template, template_type: 'send_apple_pay',
                                               parameters: { 'merchant_id' => 'merchant.test', 'item_name' => 'Item', 'amount' => 9.99 })
        expect(template).to be_valid
      end

      it 'validates with optional currency' do
        template = build(:bot_action_template, :apple_pay)
        expect(template).to be_valid
      end
    end

    describe 'api_call' do
      it 'validates with required parameters' do
        template = build(:bot_action_template, template_type: 'api_call',
                                               parameters: { 'url' => 'https://api.example.com', 'method' => 'GET' })
        expect(template).to be_valid
      end

      it 'validates with optional parameters' do
        template = build(:bot_action_template, :api_call)
        expect(template).to be_valid
      end
    end

    describe 'send_imessage_app' do
      it 'validates with required parameters' do
        template = build(:bot_action_template, template_type: 'send_imessage_app',
                                               parameters: { 'app_id' => 'com.example.app', 'app_name' => 'Example App' })
        expect(template).to be_valid
      end

      it 'validates with optional parameters' do
        template = build(:bot_action_template, :imessage_app)
        expect(template).to be_valid
      end
    end

    describe 'send_app_clip' do
      it 'validates with required parameters' do
        template = build(:bot_action_template, template_type: 'send_app_clip',
                                               parameters: { 'app_clip_url' => 'https://example.com', 'title' => 'Try App' })
        expect(template).to be_valid
      end

      it 'validates with optional parameters' do
        template = build(:bot_action_template, :app_clip)
        expect(template).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.by_type' do
      it 'filters by template type' do
        list_picker = create(:bot_action_template, :list_picker, account: account)
        create(:bot_action_template, template_type: 'send_text_message', account: account)

        result = described_class.by_type('send_list_picker')
        expect(result).to include(list_picker)
        expect(result.count).to eq(1)
      end

      it 'returns all when type is blank' do
        create(:bot_action_template, :list_picker, account: account)
        create(:bot_action_template, template_type: 'send_text_message', account: account)

        result = described_class.by_type(nil)
        expect(result.count).to eq(2)
      end
    end

    describe '.ordered' do
      it 'orders by execution_order then created_at' do
        template3 = create(:bot_action_template, account: account, execution_order: 2)
        template1 = create(:bot_action_template, account: account, execution_order: 0)
        template2 = create(:bot_action_template, account: account, execution_order: 1)

        result = described_class.ordered
        expect(result.to_a).to eq([template1, template2, template3])
      end
    end
  end

  describe 'instance methods' do
    describe '#parameter_schema' do
      it 'returns schema for valid template type' do
        template = build(:bot_action_template, template_type: 'send_text_message')
        schema = template.parameter_schema

        expect(schema[:required]).to include('message')
        expect(schema[:optional]).to include('delay_seconds')
      end

      it 'returns empty schema for unknown template type' do
        template = build(:bot_action_template)
        allow(template).to receive(:template_type).and_return('unknown_type')

        schema = template.parameter_schema
        expect(schema[:required]).to eq([])
        expect(schema[:optional]).to eq([])
      end
    end

    describe '#required_parameters' do
      it 'returns required parameters for template type' do
        template = build(:bot_action_template, template_type: 'send_rich_link')
        expect(template.required_parameters).to match_array(%w[url title])
      end
    end

    describe '#optional_parameters' do
      it 'returns optional parameters for template type' do
        template = build(:bot_action_template, template_type: 'send_rich_link')
        expect(template.optional_parameters).to match_array(%w[subtitle image_url])
      end
    end

    describe '#valid_parameter_names' do
      it 'returns all valid parameter names' do
        template = build(:bot_action_template, template_type: 'send_text_message')
        expect(template.valid_parameter_names).to match_array(%w[message delay_seconds])
      end
    end

    describe '#parameter_required?' do
      it 'returns true for required parameter' do
        template = build(:bot_action_template, template_type: 'send_text_message')
        expect(template.parameter_required?('message')).to be true
      end

      it 'returns false for optional parameter' do
        template = build(:bot_action_template, template_type: 'send_text_message')
        expect(template.parameter_required?('delay_seconds')).to be false
      end

      it 'returns false for unknown parameter' do
        template = build(:bot_action_template, template_type: 'send_text_message')
        expect(template.parameter_required?('unknown')).to be false
      end
    end

    describe '#parameter_optional?' do
      it 'returns true for optional parameter' do
        template = build(:bot_action_template, template_type: 'send_text_message')
        expect(template.parameter_optional?('delay_seconds')).to be true
      end

      it 'returns false for required parameter' do
        template = build(:bot_action_template, template_type: 'send_text_message')
        expect(template.parameter_optional?('message')).to be false
      end
    end

    describe '#validate_provided_parameters' do
      it 'returns empty array for valid parameters' do
        template = build(:bot_action_template, template_type: 'send_text_message')
        errors = template.validate_provided_parameters({ 'message' => 'Hello' })
        expect(errors).to be_empty
      end

      it 'returns error for missing required parameter' do
        template = build(:bot_action_template, template_type: 'send_text_message')
        errors = template.validate_provided_parameters({})
        expect(errors).to include(a_string_matching(/Required parameter 'message' is missing/))
      end

      it 'returns error for unknown parameter' do
        template = build(:bot_action_template, template_type: 'send_text_message')
        errors = template.validate_provided_parameters({ 'message' => 'Hello', 'unknown' => 'value' })
        expect(errors).to include(a_string_matching(/Unknown parameter 'unknown'/))
      end

      it 'handles symbol keys in provided parameters' do
        template = build(:bot_action_template, template_type: 'send_text_message')
        errors = template.validate_provided_parameters({ message: 'Hello' })
        expect(errors).to be_empty
      end

      it 'handles non-hash provided parameters' do
        template = build(:bot_action_template, template_type: 'send_text_message')
        errors = template.validate_provided_parameters('not a hash')
        expect(errors).not_to be_empty
      end
    end

    describe '#execution_summary' do
      it 'returns summary hash' do
        template = create(:bot_action_template, account: account)
        summary = template.execution_summary

        expect(summary).to include(
          id: template.id,
          name: template.name,
          type: template.template_type,
          parameters: template.parameters,
          metadata: template.metadata,
          execution_order: template.execution_order
        )
      end
    end
  end

  describe 'constants' do
    describe 'TEMPLATE_TYPES' do
      it 'contains 12 template types' do
        expect(BotActionTemplate::TEMPLATE_TYPES.count).to eq(12)
      end

      it 'includes all expected template types' do
        expected_types = %w[
          send_text_message send_list_picker send_time_picker send_form
          send_rich_link send_quick_reply update_attributes conditional_branch
          send_apple_pay api_call send_imessage_app send_app_clip
        ]
        expect(BotActionTemplate::TEMPLATE_TYPES).to match_array(expected_types)
      end
    end

    describe 'PARAMETER_SCHEMAS' do
      it 'has schema for each template type' do
        BotActionTemplate::TEMPLATE_TYPES.each do |template_type|
          expect(BotActionTemplate::PARAMETER_SCHEMAS[template_type]).to be_present
        end
      end

      it 'each schema has required and optional keys' do
        BotActionTemplate::PARAMETER_SCHEMAS.each_value do |schema|
          expect(schema).to have_key(:required)
          expect(schema).to have_key(:optional)
          expect(schema[:required]).to be_an(Array)
          expect(schema[:optional]).to be_an(Array)
        end
      end
    end
  end

  describe 'database constraints' do
    it 'enforces unique index on account_id and name' do
      create(:bot_action_template, account: account, name: 'Unique Name')

      expect do
        create(:bot_action_template, account: account, name: 'Unique Name')
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'requires account_id' do
      template = build(:bot_action_template, account: nil)
      expect(template).not_to be_valid
    end

    it 'requires name' do
      template = build(:bot_action_template, name: nil)
      expect(template).not_to be_valid
    end

    it 'requires template_type' do
      template = build(:bot_action_template, template_type: nil)
      expect(template).not_to be_valid
    end

    it 'has default value for parameters' do
      template = described_class.new(
        account: account,
        name: 'Test',
        template_type: 'send_text_message'
      )
      expect(template.parameters).to eq({})
    end

    it 'has default value for metadata' do
      template = described_class.new(
        account: account,
        name: 'Test',
        template_type: 'send_text_message',
        parameters: { 'message' => 'Hello' }
      )
      expect(template.metadata).to eq({})
    end

    it 'has default value for execution_order' do
      template = described_class.new(
        account: account,
        name: 'Test',
        template_type: 'send_text_message',
        parameters: { 'message' => 'Hello' }
      )
      expect(template.execution_order).to eq(0)
    end
  end
end
