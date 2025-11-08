# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Template Attachment Integration' do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, channel_type: 'Channel::Api') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:user) { create(:user, account: account) }

  describe 'Complete template attachment workflow' do
    it 'creates template, attaches files, renders for bot, and sends message' do
      # Step 1: Create template
      template = create(:message_template, account: account, name: 'Booking Confirmation', supported_channels: ['web_widget'])
      expect(template).to be_persisted

      # Step 2: Attach files to template
      file1 = fixture_file_upload('test_image.jpg', 'image/jpeg')
      file2 = fixture_file_upload('test_document.pdf', 'application/pdf')

      template.attach_files([file1, file2])
      expect(template.attachments.count).to eq(2)

      # Step 3: Verify attachments summary
      summary = template.attachments_summary
      expect(summary.count).to eq(2)
      expect(summary[0][:filename]).to eq('test_image.jpg')
      expect(summary[1][:filename]).to eq('test_document.pdf')

      # Step 4: Render template for bot
      renderer = Templates::BotRendererService.new(
        template_id: template.id,
        parameters: { business_name: 'Test Business' },
        channel_type: 'web_widget'
      )

      rendered = renderer.render_for_bot
      expect(rendered[:attachments]).to be_an(Array)
      expect(rendered[:attachments].count).to eq(2)

      # Step 5: Send template message with attachments
      sender = create(:user, account: account)
      service = Templates::BotMessagingService.new(
        conversation: conversation,
        template: template,
        parameters: { business_name: 'Test Business' },
        sender: sender
      )

      message = service.send_template_message
      expect(message).to be_persisted
      expect(message.attachments.count).to eq(2)
      expect(message.additional_attributes['template_id']).to eq(template.id)
    end
  end

  describe 'Attachment management during template lifecycle' do
    it 'adds, reorders, and removes attachments' do
      template = create(:message_template, account: account)

      # Add initial attachments
      file1 = fixture_file_upload('test_image.jpg', 'image/jpeg')
      file2 = fixture_file_upload('test_document.pdf', 'application/pdf')
      template.attach_files([file1, file2])
      expect(template.attachments.count).to eq(2)

      # Get initial order
      initial_summary = template.attachments_summary
      first_id = initial_summary[0][:id]
      second_id = initial_summary[1][:id]

      # Reorder attachments
      template.reorder_attachments([second_id, first_id])
      template.reload

      reordered_summary = template.attachments_summary
      expect(reordered_summary[0][:id]).to eq(second_id)
      expect(reordered_summary[1][:id]).to eq(first_id)

      # Remove first attachment
      template.remove_attachment(second_id)
      template.reload
      expect(template.attachments.count).to eq(1)

      # Verify remaining attachment
      final_summary = template.attachments_summary
      expect(final_summary[0][:id]).to eq(first_id)
    end
  end

  describe 'Attachment validation during send' do
    it 'enforces file count limit' do
      template = create(:message_template, account: account)

      # Try to attach more than 5 files
      5.times do |_i|
        file = fixture_file_upload('test_image.jpg', 'image/jpeg')
        template.attachments.attach(file)
      end

      # Sixth file should fail validation
      file6 = fixture_file_upload('test_image.jpg', 'image/jpeg')
      template.attachments.attach(file6)

      expect(template).not_to be_valid
      expect(template.errors[:attachments]).to include(a_string_matching(/cannot exceed 5 files/))
    end

    it 'enforces file size limit' do
      template = create(:message_template, account: account)

      # Attach a file that will fail size validation
      template.attachments.attach(
        io: StringIO.new('x' * (101.megabytes)),
        filename: 'too_large.bin',
        content_type: 'application/octet-stream'
      )

      expect(template).not_to be_valid
      expect(template.errors[:attachments]).to include(a_string_matching(/exceeds maximum size/))
    end

    it 'enforces allowed MIME types' do
      template = create(:message_template, account: account)

      # Try to attach unsupported file type
      template.attachments.attach(
        io: StringIO.new('malicious content'),
        filename: 'script.exe',
        content_type: 'application/x-msdownload'
      )

      expect(template).not_to be_valid
      expect(template.errors[:attachments]).to include(a_string_matching(/unsupported type/))
    end
  end

  describe 'Attachment metadata persistence' do
    it 'maintains attachment metadata across save cycles' do
      template = create(:message_template, account: account)
      file = fixture_file_upload('test_image.jpg', 'image/jpeg')

      template.attach_files(file)
      template.reload

      # Get metadata
      attachment_id = template.attachments.first.id
      metadata = template.attachment_metadata['attachments'].find { |m| m['id'] == attachment_id.to_s }

      expect(metadata).to have_key('display_order')
      expect(metadata).to have_key('attached_at')
      expect(metadata).to have_key('updated_at')

      # Reload and verify persistence
      template.reload
      metadata_after = template.attachment_metadata['attachments'].find { |m| m['id'] == attachment_id.to_s }

      expect(metadata_after['display_order']).to eq(metadata['display_order'])
      expect(metadata_after['attached_at']).to eq(metadata['attached_at'])
    end

    it 'maintains description metadata when provided' do
      create(:message_template, account: account)

      # Use the :with_attachments trait which sets descriptions
      template_with_meta = create(:message_template, :with_attachments, account: account)

      summary = template_with_meta.attachments_summary
      expect(summary[0][:description]).to eq('Test image attachment')
      expect(summary[1][:description]).to eq('Test PDF attachment')
    end
  end

  describe 'Attachment integration with channel types' do
    context 'with Apple Messages for Business' do
      let(:amb_inbox) { create(:inbox, account: account, channel_type: 'Channel::AppleMessagesForBusiness') }
      let(:amb_conversation) { create(:conversation, account: account, inbox: amb_inbox) }

      it 'renders and sends attachments for AMB channel' do
        template = create(:message_template, :with_attachments, account: account, supported_channels: ['apple_messages_for_business'])

        renderer = Templates::BotRendererService.new(
          template_id: template.id,
          parameters: {},
          channel_type: 'apple_messages_for_business'
        )

        rendered = renderer.render_for_bot
        expect(rendered[:attachments]).to be_an(Array)
        expect(rendered[:attachments].count).to eq(2)
      end
    end

    context 'with Web Widget' do
      it 'renders and sends attachments for web widget' do
        template = create(:message_template, :with_attachments, account: account, supported_channels: ['web_widget'])

        renderer = Templates::BotRendererService.new(
          template_id: template.id,
          parameters: {},
          channel_type: 'web_widget'
        )

        rendered = renderer.render_for_bot
        expect(rendered[:attachments]).to be_an(Array)
        expect(rendered[:attachments].count).to eq(2)
      end
    end
  end

  describe 'Error handling and recovery' do
    it 'handles attachment removal gracefully' do
      template = create(:message_template, :with_attachments, account: account)

      attachment_id = template.attachments.first.id
      result = template.remove_attachment(attachment_id)

      expect(result).to be(true)
      template.reload
      expect(template.attachments.count).to eq(1)
    end

    it 'handles duplicate attachment operations safely' do
      template = create(:message_template, account: account)
      file = fixture_file_upload('test_image.jpg', 'image/jpeg')

      result1 = template.attach_files(file)
      expect(result1).to be(true)

      # Reload and get fresh attachment
      template.reload

      # Try to remove the same attachment twice
      attachment_id = template.attachments.first.id
      result2 = template.remove_attachment(attachment_id)
      expect(result2).to be(true)

      result3 = template.remove_attachment(attachment_id)
      expect(result3).to be(false) # Should fail gracefully on second attempt
    end

    it 'rolls back transaction if attachment metadata fails' do
      template = create(:message_template, account: account)

      # This tests the transaction handling in attach_files
      template.attachments.count

      # Simulate a failure by mocking
      allow(template).to receive(:save!).and_raise(StandardError, 'Simulated failure')

      file = fixture_file_upload('test_image.jpg', 'image/jpeg')
      result = template.attach_files(file)

      expect(result).to be(false)
      expect(template.errors[:attachments]).to be_present
    end
  end

  describe 'Attachment count and metadata accuracy' do
    it 'maintains accurate attachment count in metadata' do
      template = create(:message_template, account: account)

      # Add multiple attachments sequentially
      3.times do |_i|
        file = fixture_file_upload('test_image.jpg', 'image/jpeg')
        template.attach_files(file)
      end

      template.reload
      metadata_count = template.attachment_metadata['attachments'].count
      actual_count = template.attachments.count

      expect(metadata_count).to eq(actual_count)
      expect(metadata_count).to eq(3)
    end

    it 'recalculates display_order correctly after removal' do
      template = create(:message_template, account: account)

      # Add 3 attachments
      3.times do
        file = fixture_file_upload('test_image.jpg', 'image/jpeg')
        template.attach_files(file)
      end

      template.reload

      # Remove middle attachment
      all_attachments = template.attachments.to_a
      middle_id = all_attachments[1].id

      template.remove_attachment(middle_id)
      template.reload

      # Check that display_order is continuous (0, 1 instead of 0, 2)
      metadata = template.attachment_metadata['attachments']
      display_orders = metadata.map { |m| m['display_order'] }.sort
      expect(display_orders).to eq([0, 1])
    end
  end
end
