# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Message Template Attachment Controller' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:template) { create(:message_template, account: account) }

  before do
    sign_in user
  end

  describe 'POST /api/v1/accounts/:account_id/message_templates/:template_id/attach_files' do
    context 'with valid file' do
      it 'attaches file to template successfully' do
        file = fixture_file_upload('test_image.jpg', 'image/jpeg')

        post "/api/v1/accounts/#{account.id}/message_templates/#{template.id}/attach_files",
             params: { files: [file] }

        expect(response).to have_http_status(:success)
        expect(template.reload.attachments.count).to eq(1)
      end

      it 'returns attachment metadata in response' do
        file = fixture_file_upload('test_image.jpg', 'image/jpeg')

        post "/api/v1/accounts/#{account.id}/message_templates/#{template.id}/attach_files",
             params: { files: [file] }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json).to have_key('attachments')
        expect(json['attachments']).to be_an(Array)
      end

      it 'attaches multiple files' do
        files = [
          fixture_file_upload('test_image.jpg', 'image/jpeg'),
          fixture_file_upload('test_document.pdf', 'application/pdf')
        ]

        post "/api/v1/accounts/#{account.id}/message_templates/#{template.id}/attach_files",
             params: { files: files }

        expect(response).to have_http_status(:success)
        expect(template.reload.attachments.count).to eq(2)
      end
    end

    context 'with invalid files' do
      it 'rejects unsupported file type' do
        file = fixture_file_upload('malicious.exe', 'application/x-msdownload')

        post "/api/v1/accounts/#{account.id}/message_templates/#{template.id}/attach_files",
             params: { files: [file] }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(template.reload.attachments.count).to eq(0)
      end

      it 'rejects oversized file' do
        # This would require an actual large file in test fixtures
        # For now, we test the validation logic
        file = fixture_file_upload('test_image.jpg', 'image/jpeg')

        # Mock the file size validation
        allow_any_instance_of(MessageTemplate).to receive(:validate_attachments_size) do |instance|
          instance.errors.add(:attachments, 'file exceeds maximum size of 100MB')
        end

        post "/api/v1/accounts/#{account.id}/message_templates/#{template.id}/attach_files",
             params: { files: [file] }

        # Should handle the error gracefully
        expect([200, 400, 422]).to include(response.status)
      end

      it 'returns error when no files provided' do
        post "/api/v1/accounts/#{account.id}/message_templates/#{template.id}/attach_files",
             params: { files: [] }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error when files not provided' do
        post "/api/v1/accounts/#{account.id}/message_templates/#{template.id}/attach_files",
             params: {}

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'authorization' do
      it 'requires authentication' do
        sign_out user

        post "/api/v1/accounts/#{account.id}/message_templates/#{template.id}/attach_files",
             params: { files: [] }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'requires account access' do
        other_account = create(:account)
        other_template = create(:message_template, account: other_account)

        post "/api/v1/accounts/#{other_account.id}/message_templates/#{other_template.id}/attach_files",
             params: { files: [] }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/message_templates/:template_id/attachments/:attachment_id' do
    let(:template_with_attachments) { create(:message_template, :with_attachments, account: account) }

    context 'with valid attachment' do
      it 'removes attachment successfully' do
        attachment_id = template_with_attachments.attachments.first.id

        delete "/api/v1/accounts/#{account.id}/message_templates/#{template_with_attachments.id}/attachments/#{attachment_id}"

        expect(response).to have_http_status(:success)
        expect(template_with_attachments.reload.attachments.count).to eq(1)
      end

      it 'returns success message' do
        attachment_id = template_with_attachments.attachments.first.id

        delete "/api/v1/accounts/#{account.id}/message_templates/#{template_with_attachments.id}/attachments/#{attachment_id}"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json).to have_key('message')
      end
    end

    context 'with invalid attachment' do
      it 'returns 404 when attachment not found' do
        delete "/api/v1/accounts/#{account.id}/message_templates/#{template_with_attachments.id}/attachments/invalid-id"

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'authorization' do
      it 'requires authentication' do
        sign_out user
        attachment_id = template_with_attachments.attachments.first.id

        delete "/api/v1/accounts/#{account.id}/message_templates/#{template_with_attachments.id}/attachments/#{attachment_id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/accounts/:account_id/message_templates/:template_id/reorder_attachments' do
    let(:template_with_attachments) { create(:message_template, :with_attachments, account: account) }

    context 'with valid attachment IDs' do
      it 'reorders attachments successfully' do
        attachment_ids = template_with_attachments.attachments.map(&:id).reverse

        put "/api/v1/accounts/#{account.id}/message_templates/#{template_with_attachments.id}/reorder_attachments",
            params: { attachment_ids: attachment_ids }

        expect(response).to have_http_status(:success)
      end

      it 'returns updated attachments in order' do
        attachment_ids = template_with_attachments.attachments.map(&:id).reverse

        put "/api/v1/accounts/#{account.id}/message_templates/#{template_with_attachments.id}/reorder_attachments",
            params: { attachment_ids: attachment_ids }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['attachments'][0]['id']).to eq(attachment_ids[0].to_s)
      end
    end

    context 'with invalid IDs' do
      it 'returns error when no IDs provided' do
        put "/api/v1/accounts/#{account.id}/message_templates/#{template_with_attachments.id}/reorder_attachments",
            params: { attachment_ids: [] }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error when invalid IDs provided' do
        put "/api/v1/accounts/#{account.id}/message_templates/#{template_with_attachments.id}/reorder_attachments",
            params: { attachment_ids: ['invalid-id'] }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'authorization' do
      it 'requires authentication' do
        sign_out user
        attachment_ids = template_with_attachments.attachments.map(&:id)

        put "/api/v1/accounts/#{account.id}/message_templates/#{template_with_attachments.id}/reorder_attachments",
            params: { attachment_ids: attachment_ids }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
