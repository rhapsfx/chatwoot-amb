# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::MessageProcessorService do
  # Shared setup: an AMB inbox + conversation, a user, and a message template with a
  # file attachment.  These are the minimal ingredients for the regression under test.
  let(:account) { create(:account) }
  let(:user)    { create(:user, account: account) }

  let(:amb_channel) do
    Channel::AppleMessagesForBusiness.create!(
      account: account,
      msp_id: 'test-msp-id',
      business_id: "biz-#{SecureRandom.hex(4)}",
      secret: 'test-secret'
    )
  end

  let(:amb_inbox) do
    create(:inbox, account: account, channel: amb_channel)
  end

  let(:contact)       { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: amb_inbox) }

  let(:conversation) do
    create(:conversation, account: account, inbox: amb_inbox,
                          contact: contact, contact_inbox: contact_inbox)
  end

  let(:template) { MessageTemplate.create!(account: account, name: 'usdz_test', status: 'active') }

  # Attach a real file so template.attachments.attached? returns true.
  before do
    template.attachments.attach(
      io: Rails.root.join('spec/assets/sample.pdf').open,
      filename: 'model.usdz',
      content_type: 'model/vnd.usdz+zip'
    )
  end

  describe '#process_and_send — plain-text message with template file attachment' do
    let(:message_params) do
      {
        content: '',
        content_type: 'text',
        content_attributes: {},
        private: false,
        echo_id: SecureRandom.hex(6),
        template_id: template.id
      }
    end

    subject(:service) { described_class.new(conversation, message_params, user) }

    it 'does not fire SendReplyJob at message-save time (before attach_template_files)' do
      # Track every enqueue.  If SendReplyJob is fired synchronously inside
      # MessageBuilder.perform — before attach_template_files copies the blob —
      # it will appear here immediately, before the test assertion below.
      enqueued_ids = []
      allow(SendReplyJob).to receive(:perform_later) { |id| enqueued_ids << id }
      allow(SendReplyJob).to receive(:set).and_return(SendReplyJob)

      # Intercept attach_template_files so we can inspect the sequence of calls.
      attach_called_at = nil
      allow(service).to receive(:attach_template_files).and_wrap_original do |orig, *args|
        attach_called_at = enqueued_ids.dup
        orig.call(*args)
      end

      service.process_and_send

      # The job must NOT have been enqueued before attach_template_files ran.
      expect(attach_called_at).to be_empty,
        'SendReplyJob was enqueued before attach_template_files — ' \
        'the file would not yet be on the message when the job runs'
    end

    it 'enqueues SendReplyJob exactly once, after attach_template_files' do
      allow(SendReplyJob).to receive(:set).and_return(SendReplyJob)
      expect(SendReplyJob).to receive(:perform_later).once

      service.process_and_send
    end

    it 'copies the template attachment onto the message before enqueueing the job' do
      saved_message = nil

      allow(SendReplyJob).to receive(:set).and_return(SendReplyJob)
      allow(SendReplyJob).to receive(:perform_later) do |message_id|
        saved_message = Message.find(message_id)
      end

      service.process_and_send

      expect(saved_message).not_to be_nil
      expect(saved_message.attachments.count).to eq(1),
        'message must have the template attachment before SendReplyJob is called'
    end

    it 'creates the message with skip_send_reply_job set so the after_create callback does not fire early' do
      skipped = false
      original_perform = Messages::MessageBuilder.instance_method(:perform)

      allow_any_instance_of(Messages::MessageBuilder).to receive(:perform) do |builder|
        skipped = builder.instance_variable_get(:@params)[:skip_send_reply_job]
        original_perform.bind(builder).call
      end

      allow(SendReplyJob).to receive(:set).and_return(SendReplyJob)
      allow(SendReplyJob).to receive(:perform_later)

      service.process_and_send

      expect(skipped).to be_truthy,
        'MessageBuilder must receive skip_send_reply_job: true so the ' \
        'after_create_commit hook does not enqueue the job prematurely'
    end
  end

  describe '#process_and_send — template without file attachments' do
    let(:template_no_file) { MessageTemplate.create!(account: account, name: 'no_file', status: 'active') }

    let(:message_params) do
      {
        content: 'hello',
        content_type: 'text',
        content_attributes: {},
        private: false,
        echo_id: SecureRandom.hex(6),
        template_id: template_no_file.id
      }
    end

    subject(:service) { described_class.new(conversation, message_params, user) }

    it 'does not set skip_send_reply_job and does not manually enqueue SendReplyJob' do
      skipped = nil
      original_perform = Messages::MessageBuilder.instance_method(:perform)

      allow_any_instance_of(Messages::MessageBuilder).to receive(:perform) do |builder|
        skipped = builder.instance_variable_get(:@params)[:skip_send_reply_job]
        original_perform.bind(builder).call
      end

      expect(SendReplyJob).not_to receive(:set)

      service.process_and_send

      expect(skipped).to be_falsy
    end
  end
end
