# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Templates::BotMessagingService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, channel_type: 'Channel::Api') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:sender) { create(:user, account: account) }
  let(:template) { create(:message_template, account: account, supported_channels: ['web_widget']) }

  describe '#send_template_message' do
    context 'with valid template and parameters' do
      it 'sends message successfully' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          conversation: conversation,
          template: template,
          parameters: parameters,
          sender: sender
        )

        message = service.send_template_message
        expect(message).to be_a(Message)
        expect(message.conversation).to eq(conversation)
      end

      it 'creates outgoing message' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          conversation: conversation,
          template: template,
          parameters: parameters,
          sender: sender
        )

        message = service.send_template_message
        expect(message.message_type).to eq('outgoing')
        expect(message.sender_type).to eq('User')
        expect(message.sender_id).to eq(sender.id)
      end

      it 'adds template metadata to message' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          conversation: conversation,
          template: template,
          parameters: parameters,
          sender: sender
        )

        message = service.send_template_message
        expect(message.additional_attributes).to have_key('template_id')
        expect(message.additional_attributes['template_id']).to eq(template.id)
        expect(message.additional_attributes['template_name']).to eq(template.name)
      end
    end

    context 'with attachments in template' do
      let(:template_with_attachments) { create(:message_template, :with_attachments, account: account, supported_channels: ['web_widget']) }

      it 'attaches template files to message' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          conversation: conversation,
          template: template_with_attachments,
          parameters: parameters,
          sender: sender
        )

        message = service.send_template_message
        expect(message.attachments.count).to eq(2)
      end

      it 'preserves attachment metadata when copying' do
        parameters = { business_name: 'Acme Corp' }
        service = described_class.new(
          conversation: conversation,
          template: template_with_attachments,
          parameters: parameters,
          sender: sender
        )

        message = service.send_template_message
        attachment = message.attachments.first

        expect(attachment.account_id).to eq(account.id)
        expect(attachment.file).to be_attached
      end
    end

    context 'error handling' do
      it 'raises SendError on service failure' do
        # Create a scenario where rendering will fail
        template_invalid = create(:message_template, account: account, parameters: {
                                    'required_param' => { 'type' => 'string', 'required' => true }
                                  })

        service = described_class.new(
          conversation: conversation,
          template: template_invalid,
          parameters: {},
          sender: sender
        )

        expect do
          service.send_template_message
        end.to raise_error(Templates::BotMessagingService::SendError)
      end

      it 'logs errors appropriately' do
        template_invalid = create(:message_template, account: account, parameters: {
                                    'required_param' => { 'type' => 'string', 'required' => true }
                                  })

        service = described_class.new(
          conversation: conversation,
          template: template_invalid,
          parameters: {},
          sender: sender
        )

        expect(Rails.logger).to receive(:error).at_least(:once)
        expect do
          service.send_template_message
        end.to raise_error(Templates::BotMessagingService::SendError)
      end
    end
  end

  describe '#attach_template_files_to_message' do
    let(:message) { create(:message, conversation: conversation, account: account) }
    let(:template_with_attachments) { create(:message_template, :with_attachments, account: account) }

    context 'with valid attachments' do
      it 'attaches files to message' do
        service = described_class.new(
          conversation: conversation,
          template: template_with_attachments,
          parameters: {},
          sender: sender
        )

        attachments_data = template_with_attachments.attachments_summary.map do |a|
          {
            blob_id: a[:id],
            filename: a[:filename],
            content_type: a[:content_type]
          }
        end

        expect do
          service.send(:attach_template_files_to_message, message, attachments_data.map do |a|
            { blob_id: template_with_attachments.attachments.first.blob.id, filename: a[:filename], content_type: a[:content_type] }
          end)
        end.to change { message.attachments.count }.by(2)
      end

      it 'continues on partial attachment failure' do
        service = described_class.new(
          conversation: conversation,
          template: template_with_attachments,
          parameters: {},
          sender: sender
        )

        # Pass invalid blob ID for first attachment
        attachments_data = [
          { blob_id: 'invalid', filename: 'invalid.jpg', content_type: 'image/jpeg' },
          { blob_id: template_with_attachments.attachments.last.blob.id, filename: 'valid.pdf', content_type: 'application/pdf' }
        ]

        expect do
          service.send(:attach_template_files_to_message, message, attachments_data)
        end.not_to raise_error
      end
    end

    context 'with no attachments' do
      it 'does nothing when attachments blank' do
        service = described_class.new(
          conversation: conversation,
          template: template,
          parameters: {},
          sender: sender
        )

        expect do
          service.send(:attach_template_files_to_message, message, nil)
        end.not_to(change { message.attachments.count })
      end

      it 'does nothing when attachments empty' do
        service = described_class.new(
          conversation: conversation,
          template: template,
          parameters: {},
          sender: sender
        )

        expect do
          service.send(:attach_template_files_to_message, message, [])
        end.not_to(change { message.attachments.count })
      end
    end
  end

  describe '#determine_file_type' do
    let(:service) do
      described_class.new(
        conversation: conversation,
        template: template,
        parameters: {},
        sender: sender
      )
    end

    context 'with image content types' do
      %w[image/jpeg image/png image/gif image/webp].each do |mime_type|
        it "returns :image for #{mime_type}" do
          file_type = service.send(:determine_file_type, mime_type)
          expect(file_type).to eq(:image)
        end
      end
    end

    context 'with video content types' do
      %w[video/mp4 video/quicktime video/mpeg].each do |mime_type|
        it "returns :video for #{mime_type}" do
          file_type = service.send(:determine_file_type, mime_type)
          expect(file_type).to eq(:video)
        end
      end
    end

    context 'with audio content types' do
      %w[audio/mpeg audio/mp4 audio/wav audio/aac].each do |mime_type|
        it "returns :audio for #{mime_type}" do
          file_type = service.send(:determine_file_type, mime_type)
          expect(file_type).to eq(:audio)
        end
      end
    end

    context 'with other content types' do
      %w[application/pdf application/msword text/plain application/zip].each do |mime_type|
        it "returns :file for #{mime_type}" do
          file_type = service.send(:determine_file_type, mime_type)
          expect(file_type).to eq(:file)
        end
      end
    end
  end

  describe 'channel type determination' do
    context 'with various channel types' do
      it 'maps Channel::AppleMessagesForBusiness to apple_messages_for_business' do
        amb_inbox = create(:inbox, account: account, channel_type: 'Channel::AppleMessagesForBusiness')
        amb_conversation = create(:conversation, account: account, inbox: amb_inbox)

        service = described_class.new(
          conversation: amb_conversation,
          template: template,
          parameters: {},
          sender: sender
        )

        channel_type = service.send(:determine_channel_type)
        expect(channel_type).to eq('apple_messages_for_business')
      end

      it 'maps Channel::Whatsapp to whatsapp' do
        wa_inbox = create(:inbox, account: account, channel_type: 'Channel::Whatsapp')
        wa_conversation = create(:conversation, account: account, inbox: wa_inbox)

        service = described_class.new(
          conversation: wa_conversation,
          template: template,
          parameters: {},
          sender: sender
        )

        channel_type = service.send(:determine_channel_type)
        expect(channel_type).to eq('whatsapp')
      end

      it 'maps Channel::Api to web_widget' do
        service = described_class.new(
          conversation: conversation,
          template: template,
          parameters: {},
          sender: sender
        )

        channel_type = service.send(:determine_channel_type)
        expect(channel_type).to eq('web_widget')
      end
    end
  end

  describe 'integration tests' do
    context 'full message sending flow' do
      let(:template_with_attachments) { create(:message_template, :with_attachments, account: account, supported_channels: ['web_widget']) }

      it 'sends complete message with template metadata and attachments' do
        parameters = { business_name: 'Test Business' }

        service = described_class.new(
          conversation: conversation,
          template: template_with_attachments,
          parameters: parameters,
          sender: sender
        )

        message = service.send_template_message

        expect(message).to be_persisted
        expect(message.conversation_id).to eq(conversation.id)
        expect(message.account_id).to eq(account.id)
        expect(message.message_type).to eq('outgoing')
        expect(message.sender_id).to eq(sender.id)
        expect(message.attachments.count).to eq(2)
        expect(message.additional_attributes['template_id']).to eq(template_with_attachments.id)
      end
    end
  end

  describe 'event triggering' do
    it 'triggers message_created event' do
      parameters = { business_name: 'Acme Corp' }
      service = described_class.new(
        conversation: conversation,
        template: template,
        parameters: parameters,
        sender: sender
      )

      expect(Rails.configuration.dispatcher).to receive(:dispatch).at_least(:once)
      service.send_template_message
    end
  end
end
