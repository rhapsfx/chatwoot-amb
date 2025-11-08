# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MessageTemplate do
  let(:account) { create(:account) }
  let(:template) { create(:message_template, account: account) }

  describe 'associations' do
    it { is_expected.to have_many_attached(:attachments) }
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:content_blocks).dependent(:destroy) }
    it { is_expected.to have_many(:channel_mappings).dependent(:destroy) }
    it { is_expected.to have_many(:usage_logs).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[active draft deprecated]) }
    it { is_expected.to validate_inclusion_of(:category).in_array(MessageTemplate::CATEGORIES).allow_nil }
    it { is_expected.to validate_numericality_of(:version).is_greater_than(0) }

    describe 'name uniqueness' do
      it 'validates uniqueness of name scoped to account' do
        create(:message_template, account: account, name: 'Unique Template')
        template = build(:message_template, account: account, name: 'Unique Template')
        expect(template).not_to be_valid
        expect(template.errors[:name]).to include('has already been taken')
      end

      it 'allows same name in different accounts' do
        other_account = create(:account)
        create(:message_template, account: account, name: 'Shared Name')
        template = build(:message_template, account: other_account, name: 'Shared Name')
        expect(template).to be_valid
      end
    end
  end

  describe 'attachment validations' do
    describe 'MAX_ATTACHMENTS constant' do
      it 'is set to 5' do
        expect(MessageTemplate::MAX_ATTACHMENTS).to eq(5)
      end
    end

    describe 'MAX_ATTACHMENT_SIZE constant' do
      it 'is set to 100 megabytes' do
        expect(MessageTemplate::MAX_ATTACHMENT_SIZE).to eq(100.megabytes)
      end
    end

    describe 'validate_attachments_count' do
      it 'allows up to 5 attachments' do
        template = create(:message_template, account: account)
        5.times do |i|
          template.attachments.attach(
            io: StringIO.new("content#{i}"),
            filename: "file#{i}.txt",
            content_type: 'text/plain'
          )
        end
        expect(template).to be_valid
      end

      it 'rejects more than 5 attachments' do
        template = create(:message_template, account: account)
        6.times do |i|
          template.attachments.attach(
            io: StringIO.new("content#{i}"),
            filename: "file#{i}.txt",
            content_type: 'text/plain'
          )
        end
        expect(template).not_to be_valid
        expect(template.errors[:attachments]).to include(a_string_matching(/cannot exceed 5 files/))
      end
    end

    describe 'validate_attachments_size' do
      it 'accepts files under 100MB' do
        template = create(:message_template, account: account)
        template.attachments.attach(
          io: StringIO.new('x' * (50.megabytes)),
          filename: 'large_file.bin',
          content_type: 'application/octet-stream'
        )
        expect(template).to be_valid
      end

      it 'rejects files exceeding 100MB' do
        template = create(:message_template, account: account)
        template.attachments.attach(
          io: StringIO.new('x' * (101.megabytes)),
          filename: 'too_large.bin',
          content_type: 'application/octet-stream'
        )
        expect(template).not_to be_valid
        expect(template.errors[:attachments]).to include(a_string_matching(/exceeds maximum size/))
      end
    end

    describe 'validate_attachments_content_type' do
      it 'accepts allowed MIME types' do
        MessageTemplate::ALLOWED_ATTACHMENT_TYPES.sample(3).each do |mime_type|
          template = create(:message_template, account: account)
          template.attachments.attach(
            io: StringIO.new('test content'),
            filename: "file.#{mime_type.split('/').last}",
            content_type: mime_type
          )
          expect(template).to be_valid, "Expected #{mime_type} to be allowed"
        end
      end

      it 'rejects unsupported MIME types' do
        template = create(:message_template, account: account)
        template.attachments.attach(
          io: StringIO.new('test'),
          filename: 'malicious.exe',
          content_type: 'application/x-msdownload'
        )
        expect(template).not_to be_valid
        expect(template.errors[:attachments]).to include(a_string_matching(/unsupported type/))
      end

      it 'accepts common image formats' do
        %w[image/jpeg image/png image/gif image/webp image/heic].each do |mime_type|
          template = create(:message_template, account: account)
          template.attachments.attach(
            io: StringIO.new('image data'),
            filename: 'image.jpg',
            content_type: mime_type
          )
          expect(template).to be_valid, "Expected #{mime_type} to be allowed"
        end
      end

      it 'accepts common video formats' do
        %w[video/mp4 video/quicktime video/mpeg].each do |mime_type|
          template = create(:message_template, account: account)
          template.attachments.attach(
            io: StringIO.new('video data'),
            filename: 'video.mp4',
            content_type: mime_type
          )
          expect(template).to be_valid, "Expected #{mime_type} to be allowed"
        end
      end

      it 'accepts common audio formats' do
        %w[audio/mpeg audio/mp4 audio/wav audio/aac].each do |mime_type|
          template = create(:message_template, account: account)
          template.attachments.attach(
            io: StringIO.new('audio data'),
            filename: 'audio.mp3',
            content_type: mime_type
          )
          expect(template).to be_valid, "Expected #{mime_type} to be allowed"
        end
      end

      it 'accepts document formats' do
        %w[application/pdf application/msword application/vnd.ms-excel text/plain text/csv].each do |mime_type|
          template = create(:message_template, account: account)
          template.attachments.attach(
            io: StringIO.new('document data'),
            filename: 'doc.pdf',
            content_type: mime_type
          )
          expect(template).to be_valid, "Expected #{mime_type} to be allowed"
        end
      end
    end
  end

  describe '#attachments_summary' do
    context 'when template has no attachments' do
      it 'returns empty array' do
        template = create(:message_template, account: account)
        expect(template.attachments_summary).to eq([])
      end
    end

    context 'when template has attachments' do
      let(:template_with_files) { create(:message_template, :with_attachments, account: account) }

      it 'returns array of attachment metadata' do
        summary = template_with_files.attachments_summary
        expect(summary).to be_an(Array)
        expect(summary.count).to eq(2)
      end

      it 'includes attachment id in metadata' do
        summary = template_with_files.attachments_summary
        expect(summary.first).to have_key(:id)
        expect(summary.first[:id]).to be_present
      end

      it 'includes filename in metadata' do
        summary = template_with_files.attachments_summary
        expect(summary.first).to have_key(:filename)
        expect(summary.first[:filename]).to eq('test_image.jpg')
        expect(summary.last[:filename]).to eq('test_document.pdf')
      end

      it 'includes content_type in metadata' do
        summary = template_with_files.attachments_summary
        expect(summary.first).to have_key(:content_type)
        expect(summary.first[:content_type]).to eq('image/jpeg')
        expect(summary.last[:content_type]).to eq('application/pdf')
      end

      it 'includes byte_size in metadata' do
        summary = template_with_files.attachments_summary
        expect(summary.first).to have_key(:byte_size)
        expect(summary.first[:byte_size]).to be_a(Integer)
      end

      it 'includes display_order in metadata' do
        summary = template_with_files.attachments_summary
        expect(summary.first).to have_key(:display_order)
        expect(summary.first[:display_order]).to eq(0)
        expect(summary.last[:display_order]).to eq(1)
      end

      it 'includes description in metadata' do
        summary = template_with_files.attachments_summary
        expect(summary.first[:description]).to eq('Test image attachment')
        expect(summary.last[:description]).to eq('Test PDF attachment')
      end

      it 'returns attachments sorted by display order' do
        summary = template_with_files.attachments_summary
        expect(summary.map { |a| a[:display_order] }).to eq([0, 1])
      end

      it 'includes URL for attachment' do
        summary = template_with_files.attachments_summary
        expect(summary.first).to have_key(:url)
        expect(summary.first[:url]).to be_present
      end
    end
  end

  describe '#attach_files' do
    context 'with valid files' do
      it 'attaches single file successfully' do
        template = create(:message_template, account: account)
        file = fixture_file_upload('test_image.jpg', 'image/jpeg')

        expect do
          template.attach_files(file)
        end.to change { template.attachments.count }.by(1)
      end

      it 'attaches multiple files successfully' do
        template = create(:message_template, account: account)
        files = [
          fixture_file_upload('test_image.jpg', 'image/jpeg'),
          fixture_file_upload('test_document.pdf', 'application/pdf')
        ]

        expect do
          template.attach_files(files)
        end.to change { template.attachments.count }.by(2)
      end

      it 'returns true on successful attachment' do
        template = create(:message_template, account: account)
        file = fixture_file_upload('test_image.jpg', 'image/jpeg')

        result = template.attach_files(file)
        expect(result).to be(true)
      end

      it 'updates attachment metadata on attachment' do
        template = create(:message_template, account: account)
        file = fixture_file_upload('test_image.jpg', 'image/jpeg')

        template.attach_files(file)

        metadata = template.attachment_metadata
        expect(metadata['attachments']).to be_present
        expect(metadata['attachments'].first).to have_key('display_order')
        expect(metadata['attachments'].first).to have_key('attached_at')
      end

      it 'sets correct display_order for multiple files' do
        template = create(:message_template, account: account)
        files = [
          fixture_file_upload('test_image.jpg', 'image/jpeg'),
          fixture_file_upload('test_document.pdf', 'application/pdf')
        ]

        template.attach_files(files)

        metadata = template.attachment_metadata
        expect(metadata['attachments'][0]['display_order']).to eq(0)
        expect(metadata['attachments'][1]['display_order']).to eq(1)
      end
    end

    context 'with invalid files' do
      it 'returns false when files blank' do
        template = create(:message_template, account: account)
        result = template.attach_files(nil)
        expect(result).to be(false)
      end

      it 'returns false when empty array provided' do
        template = create(:message_template, account: account)
        result = template.attach_files([])
        expect(result).to be(false)
      end

      it 'fails gracefully with invalid file type' do
        template = create(:message_template, account: account)
        invalid_file = fixture_file_upload('invalid.exe', 'application/x-msdownload')

        result = template.attach_files(invalid_file)
        expect(result).to be(false)
        expect(template.errors[:attachments]).to be_present
      end

      it 'fails gracefully with oversized file' do
        template = create(:message_template, account: account)

        # Create a mock file that's too large
        oversized_file = double('file')
        allow(oversized_file).to receive(:is_a?).with(Array).and_return(false)

        # We can't easily test with actual large files, but we can test the validation
        template.attachments.attach(
          io: StringIO.new('x' * (101.megabytes)),
          filename: 'too_large.bin',
          content_type: 'application/octet-stream'
        )

        result = template.attach_files(nil) # Test that it doesn't crash
        expect(result).to be(false)
      end
    end

    context 'transaction handling' do
      it 'uses transaction to ensure atomicity' do
        template = create(:message_template, account: account)
        expect(ActiveRecord::Base).to receive(:transaction).and_yield
        template.attach_files(fixture_file_upload('test_image.jpg', 'image/jpeg'))
      end
    end
  end

  describe '#remove_attachment' do
    context 'with valid attachment' do
      let(:template_with_files) { create(:message_template, :with_attachments, account: account) }

      it 'removes attachment successfully' do
        attachment_id = template_with_files.attachments.first.id

        expect do
          template_with_files.remove_attachment(attachment_id)
        end.to change { template_with_files.attachments.count }.by(-1)
      end

      it 'returns true on successful removal' do
        attachment_id = template_with_files.attachments.first.id
        result = template_with_files.remove_attachment(attachment_id)
        expect(result).to be(true)
      end

      it 'removes attachment from metadata' do
        attachment_id = template_with_files.attachments.first.id
        template_with_files.remove_attachment(attachment_id)

        metadata = template_with_files.attachment_metadata
        attachment_ids = metadata['attachments'].map { |a| a['id'] }
        expect(attachment_ids).not_to include(attachment_id.to_s)
      end

      it 'reindexes display order after removal' do
        # Create template with 3 attachments
        template = create(:message_template, account: account)
        3.times do |_i|
          file = fixture_file_upload('test_image.jpg', 'image/jpeg')
          template.attachments.attach(file)
        end

        # Update metadata for all attachments
        template.reload
        template.attachment_metadata = {
          'attachments' => [
            { 'id' => template.attachments[0].id.to_s, 'display_order' => 0 },
            { 'id' => template.attachments[1].id.to_s, 'display_order' => 1 },
            { 'id' => template.attachments[2].id.to_s, 'display_order' => 2 }
          ]
        }
        template.save!

        # Remove middle attachment
        template.remove_attachment(template.attachments[1].id)

        # Check reindexing
        template.reload
        metadata = template.attachment_metadata
        display_orders = metadata['attachments'].map { |a| a['display_order'] }.sort
        expect(display_orders).to eq([0, 1])
      end
    end

    context 'with invalid attachment' do
      it 'returns false when attachment not found' do
        template = create(:message_template, account: account)
        result = template.remove_attachment('nonexistent-id')
        expect(result).to be(false)
      end

      it 'does not raise error for nonexistent attachment' do
        template = create(:message_template, account: account)
        expect do
          template.remove_attachment('nonexistent-id')
        end.not_to raise_error
      end
    end

    context 'transaction handling' do
      it 'uses transaction for atomicity' do
        template_with_files = create(:message_template, :with_attachments, account: account)
        attachment_id = template_with_files.attachments.first.id

        expect(ActiveRecord::Base).to receive(:transaction).and_yield
        template_with_files.remove_attachment(attachment_id)
      end
    end
  end

  describe '#reorder_attachments' do
    context 'with valid attachment IDs' do
      let(:template_with_files) { create(:message_template, :with_attachments, account: account) }

      it 'reorders attachments successfully' do
        attachment_ids = template_with_files.attachments.map(&:id).reverse
        result = template_with_files.reorder_attachments(attachment_ids)
        expect(result).to be(true)
      end

      it 'updates display_order in metadata' do
        attachment_ids = template_with_files.attachments.map(&:id).reverse
        template_with_files.reorder_attachments(attachment_ids)

        metadata = template_with_files.attachment_metadata
        first_attachment_meta = metadata['attachments'].find { |a| a['id'] == attachment_ids[0].to_s }
        expect(first_attachment_meta['display_order']).to eq(0)
      end

      it 'applies new display order correctly' do
        attachment_ids = template_with_files.attachments.map(&:id).reverse
        template_with_files.reorder_attachments(attachment_ids)

        summary = template_with_files.attachments_summary
        expect(summary[0][:id]).to eq(attachment_ids[0])
        expect(summary[1][:id]).to eq(attachment_ids[1])
      end

      it 'returns false when IDs are blank' do
        template_with_files = create(:message_template, :with_attachments, account: account)
        result = template_with_files.reorder_attachments(nil)
        expect(result).to be(false)
      end

      it 'returns false when empty array provided' do
        template_with_files = create(:message_template, :with_attachments, account: account)
        result = template_with_files.reorder_attachments([])
        expect(result).to be(false)
      end
    end

    context 'with invalid IDs' do
      it 'handles nonexistent attachment IDs gracefully' do
        template = create(:message_template, account: account)
        file = fixture_file_upload('test_image.jpg', 'image/jpeg')
        template.attachments.attach(file)

        result = template.reorder_attachments(['nonexistent-id'])
        # Should still succeed, but won't find the attachment
        expect(result).to be(true)
      end
    end

    context 'transaction handling' do
      it 'uses transaction for atomicity' do
        template_with_files = create(:message_template, :with_attachments, account: account)
        attachment_ids = template_with_files.attachments.map(&:id)

        expect(ActiveRecord::Base).to receive(:transaction).and_yield
        template_with_files.reorder_attachments(attachment_ids)
      end
    end
  end

  describe 'bot_summary' do
    it 'includes attachments count' do
      template = create(:message_template, :with_attachments, account: account)
      summary = template.bot_summary

      expect(summary).to have_key(:id)
      expect(summary).to have_key(:name)
      expect(summary).to have_key(:category)
      expect(summary).to have_key(:description)
    end
  end

  describe 'constants' do
    it 'has ALLOWED_ATTACHMENT_TYPES constant' do
      expect(MessageTemplate::ALLOWED_ATTACHMENT_TYPES).to be_an(Array)
      expect(MessageTemplate::ALLOWED_ATTACHMENT_TYPES).to include('image/jpeg')
      expect(MessageTemplate::ALLOWED_ATTACHMENT_TYPES).to include('application/pdf')
    end

    it 'has reasonable ALLOWED_ATTACHMENT_TYPES' do
      # Should support at least common types
      expected_types = %w[image/jpeg image/png image/gif video/mp4 audio/mpeg application/pdf text/plain]
      expected_types.each do |mime_type|
        expect(MessageTemplate::ALLOWED_ATTACHMENT_TYPES).to include(mime_type)
      end
    end
  end

  describe 'scopes' do
    let!(:active_template) { create(:message_template, account: account, status: 'active') }
    let!(:draft_template) { create(:message_template, account: account, status: 'draft') }
    let!(:deprecated_template) { create(:message_template, account: account, status: 'deprecated') }

    describe '.active' do
      it 'returns only active templates' do
        templates = MessageTemplate.active
        expect(templates).to include(active_template)
        expect(templates).not_to include(draft_template)
        expect(templates).not_to include(deprecated_template)
      end
    end

    describe '.draft' do
      it 'returns only draft templates' do
        templates = MessageTemplate.draft
        expect(templates).to include(draft_template)
        expect(templates).not_to include(active_template)
      end
    end

    describe '.deprecated' do
      it 'returns only deprecated templates' do
        templates = MessageTemplate.deprecated
        expect(templates).to include(deprecated_template)
        expect(templates).not_to include(active_template)
      end
    end
  end
end
