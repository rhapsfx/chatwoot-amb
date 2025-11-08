# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Templates::BotRendererService do
  let(:account) { create(:account) }
  let(:template) { create(:message_template, account: account, supported_channels: ['apple_messages_for_business']) }

  describe '#render_for_bot' do
    context 'with valid parameters' do
      it 'returns template content for bot consumption' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          template_id: template.id,
          parameters: parameters,
          channel_type: 'apple_messages_for_business'
        )

        result = service.render_for_bot
        expect(result).to have_key(:template_id)
        expect(result).to have_key(:template_name)
        expect(result).to have_key(:content_type)
        expect(result).to have_key(:content)
        expect(result).to have_key(:content_attributes)
        expect(result).to have_key(:attachments)
        expect(result).to have_key(:webhook_data)
      end

      it 'includes correct template_id in result' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          template_id: template.id,
          parameters: parameters,
          channel_type: 'apple_messages_for_business'
        )

        result = service.render_for_bot
        expect(result[:template_id]).to eq(template.id)
      end

      it 'includes template_name in result' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          template_id: template.id,
          parameters: parameters,
          channel_type: 'apple_messages_for_business'
        )

        result = service.render_for_bot
        expect(result[:template_name]).to eq(template.name)
      end
    end

    context 'with attachments' do
      let(:template_with_attachments) { create(:message_template, :with_attachments, account: account) }

      it 'includes attachment metadata in result' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          template_id: template_with_attachments.id,
          parameters: parameters,
          channel_type: 'apple_messages_for_business'
        )

        result = service.render_for_bot
        expect(result[:attachments]).to be_an(Array)
      end

      it 'returns ordered attachments based on metadata' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          template_id: template_with_attachments.id,
          parameters: parameters,
          channel_type: 'apple_messages_for_business'
        )

        result = service.render_for_bot
        attachments = result[:attachments]

        expect(attachments.count).to eq(2)
        expect(attachments[0][:filename]).to eq('test_image.jpg')
        expect(attachments[1][:filename]).to eq('test_document.pdf')
      end

      it 'includes attachment blob information' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          template_id: template_with_attachments.id,
          parameters: parameters,
          channel_type: 'apple_messages_for_business'
        )

        result = service.render_for_bot
        attachment = result[:attachments].first

        expect(attachment).to have_key(:id)
        expect(attachment).to have_key(:filename)
        expect(attachment).to have_key(:content_type)
        expect(attachment).to have_key(:byte_size)
        expect(attachment).to have_key(:blob_id)
        expect(attachment).to have_key(:signed_id)
      end
    end

    context 'with missing required parameters' do
      it 'raises ParameterValidationError for missing required parameter' do
        service = described_class.new(
          template_id: template.id,
          parameters: {},
          channel_type: 'apple_messages_for_business'
        )

        expect do
          service.render_for_bot
        end.to raise_error(Templates::BotRendererService::ParameterValidationError)
      end
    end

    context 'with invalid channel' do
      it 'raises ParameterValidationError for unsupported channel' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          template_id: template.id,
          parameters: parameters,
          channel_type: 'unsupported_channel'
        )

        expect do
          service.render_for_bot
        end.to raise_error(Templates::BotRendererService::ParameterValidationError)
      end
    end

    context 'with migrated bot template metadata' do
      let(:template_with_metadata) { create(:message_template, :with_list_picker_content, account: account) }

      it 'renders from metadata when present' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          template_id: template_with_metadata.id,
          parameters: parameters,
          channel_type: 'apple_messages_for_business'
        )

        result = service.render_for_bot
        expect(result[:content_type]).to eq('apple_list_picker')
      end

      it 'includes content attributes from metadata' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          template_id: template_with_metadata.id,
          parameters: parameters,
          channel_type: 'apple_messages_for_business'
        )

        result = service.render_for_bot
        expect(result[:content_attributes]).to have_key('sections')
      end
    end
  end

  describe '#load_template_attachments' do
    context 'with no attachments' do
      it 'returns empty array' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          template_id: template.id,
          parameters: parameters,
          channel_type: 'apple_messages_for_business'
        )

        attachments = service.send(:load_template_attachments)
        expect(attachments).to eq([])
      end
    end

    context 'with attachments' do
      let(:template_with_attachments) { create(:message_template, :with_attachments, account: account) }

      it 'returns attachment metadata array' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          template_id: template_with_attachments.id,
          parameters: parameters,
          channel_type: 'apple_messages_for_business'
        )

        attachments = service.send(:load_template_attachments)
        expect(attachments).to be_an(Array)
        expect(attachments.count).to eq(2)
      end

      it 'includes all required attachment fields' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          template_id: template_with_attachments.id,
          parameters: parameters,
          channel_type: 'apple_messages_for_business'
        )

        attachments = service.send(:load_template_attachments)
        attachment = attachments.first

        expect(attachment).to have_key(:id)
        expect(attachment).to have_key(:filename)
        expect(attachment).to have_key(:content_type)
        expect(attachment).to have_key(:byte_size)
        expect(attachment).to have_key(:blob_id)
        expect(attachment).to have_key(:signed_id)
      end

      it 'respects attachment display order' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          template_id: template_with_attachments.id,
          parameters: parameters,
          channel_type: 'apple_messages_for_business'
        )

        attachments = service.send(:load_template_attachments)
        expect(attachments[0][:filename]).to eq('test_image.jpg')
        expect(attachments[1][:filename]).to eq('test_document.pdf')
      end
    end
  end

  describe 'channel normalization' do
    context 'with various channel formats' do
      it 'normalizes apple_messages_for_business' do
        template_amb = create(:message_template, account: account, supported_channels: ['apple_messages_for_business'])
        parameters = { business_name: 'Acme Corp' }

        %w[apple_messages_for_business apple_messages amb].each do |channel|
          service = described_class.new(
            template_id: template_amb.id,
            parameters: parameters,
            channel_type: channel
          )

          expect do
            service.render_for_bot
          end.not_to raise_error
        end
      end

      it 'normalizes whatsapp' do
        template_wa = create(:message_template, account: account, supported_channels: ['whatsapp'])
        parameters = { business_name: 'Acme Corp' }

        %w[whatsapp whatsapp_business].each do |channel|
          service = described_class.new(
            template_id: template_wa.id,
            parameters: parameters,
            channel_type: channel
          )

          expect do
            service.render_for_bot
          end.not_to raise_error
        end
      end
    end
  end

  describe 'parameter handling' do
    context 'with ActionController::Parameters' do
      it 'converts ActionController::Parameters to hash' do
        action_params = ActionController::Parameters.new(business_name: 'Acme Corp')
        service = described_class.new(
          template_id: template.id,
          parameters: action_params,
          channel_type: 'apple_messages_for_business'
        )

        result = service.render_for_bot
        expect(result).to have_key(:template_id)
      end
    end

    context 'with indifferent access' do
      it 'supports both symbol and string parameter keys' do
        template_with_params = create(:message_template, account: account, parameters: {
                                        'business_name' => {
                                          'type' => 'string',
                                          'required' => false
                                        }
                                      })

        service = described_class.new(
          template_id: template_with_params.id,
          parameters: { business_name: 'Test' },
          channel_type: 'apple_messages_for_business'
        )

        result = service.render_for_bot
        expect(result).to have_key(:template_id)
      end
    end
  end

  describe 'webhook data generation' do
    it 'includes webhook_data in result' do
      parameters = { business_name: 'Acme Corp' }
      service = described_class.new(
        template_id: template.id,
        parameters: parameters,
        channel_type: 'apple_messages_for_business'
      )

      result = service.render_for_bot
      expect(result[:webhook_data]).to be_a(Hash)
    end

    it 'includes template metadata in webhook_data' do
      parameters = { business_name: 'Acme Corp' }
      service = described_class.new(
        template_id: template.id,
        parameters: parameters,
        channel_type: 'apple_messages_for_business'
      )

      result = service.render_for_bot
      webhook_data = result[:webhook_data]

      expect(webhook_data).to have_key(:template_id)
      expect(webhook_data).to have_key(:template_name)
      expect(webhook_data).to have_key(:channel_type)
      expect(webhook_data).to have_key(:timestamp)
    end

    it 'includes parameters_used in webhook_data' do
      parameters = { business_name: 'Acme Corp' }
      service = described_class.new(
        template_id: template.id,
        parameters: parameters,
        channel_type: 'apple_messages_for_business'
      )

      result = service.render_for_bot
      webhook_data = result[:webhook_data]

      expect(webhook_data[:parameters_used]).to include('business_name')
      expect(webhook_data[:parameters_used]['business_name']).to eq('Acme Corp')
    end
  end

  describe 'error handling' do
    it 'raises error when template not found' do
      expect do
        described_class.new(
          template_id: 99_999,
          parameters: { business_name: 'Acme Corp' },
          channel_type: 'apple_messages_for_business'
        )
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'returns proper error structure for validation failures' do
      service = described_class.new(
        template_id: template.id,
        parameters: {},
        channel_type: 'apple_messages_for_business'
      )

      expect do
        service.render_for_bot
      end.to raise_error(Templates::BotRendererService::ParameterValidationError)
    end
  end
end
