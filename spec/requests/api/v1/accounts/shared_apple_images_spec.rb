# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SharedAppleImages API', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:other_account) { create(:account) }
  let(:other_user) { create(:user, account: other_account) }
  let(:shared_image) { create(:shared_apple_image, account: account) }

  before do
    sign_in user
  end

  describe 'GET /api/v1/accounts/:account_id/shared_apple_images' do
    context 'with valid authentication' do
      it 'returns all shared images for account' do
        create_list(:shared_apple_image, 3, account: account)

        get "/api/v1/accounts/#{account.id}/shared_apple_images"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json).to have_key('shared_apple_images')
        expect(json['shared_apple_images'].count).to eq(3)
      end

      it 'returns empty array for account with no images' do
        get "/api/v1/accounts/#{account.id}/shared_apple_images"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['shared_apple_images']).to eq([])
      end

      it 'does not return images from other accounts' do
        create_list(:shared_apple_image, 2, account: account)
        create_list(:shared_apple_image, 2, account: other_account)

        get "/api/v1/accounts/#{account.id}/shared_apple_images"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['shared_apple_images'].count).to eq(2)
        expect(json['shared_apple_images'].all? { |img| img['account_id'] == account.id }).to be true
      end

      it 'returns paginated results' do
        create_list(:shared_apple_image, 25, account: account)

        get "/api/v1/accounts/#{account.id}/shared_apple_images", params: { page: 1, per_page: 10 }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['shared_apple_images'].count).to eq(10)
        expect(json['total']).to eq(25)
        expect(json['page']).to eq(1)
        expect(json['per_page']).to eq(10)
      end

      it 'returns second page of results' do
        create_list(:shared_apple_image, 25, account: account)

        get "/api/v1/accounts/#{account.id}/shared_apple_images", params: { page: 2, per_page: 10 }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['shared_apple_images'].count).to eq(10)
        expect(json['page']).to eq(2)
      end

      it 'respects maximum per_page limit' do
        create_list(:shared_apple_image, 150, account: account)

        get "/api/v1/accounts/#{account.id}/shared_apple_images", params: { per_page: 200 }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['shared_apple_images'].count).to eq(100)
      end

      it 'includes image attachment URL' do
        image = create(:shared_apple_image, account: account)

        get "/api/v1/accounts/#{account.id}/shared_apple_images"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['shared_apple_images'].first).to have_key('image_url')
      end

      it 'includes metadata' do
        image = create(:shared_apple_image, account: account, metadata: { width: 500, height: 500 })

        get "/api/v1/accounts/#{account.id}/shared_apple_images"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['shared_apple_images'].first['metadata']).to include('width' => 500, 'height' => 500)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        sign_out user
        get "/api/v1/accounts/#{account.id}/shared_apple_images"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'without account access' do
      it 'returns unauthorized for other account' do
        get "/api/v1/accounts/#{other_account.id}/shared_apple_images"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/shared_apple_images/system_images' do
    it 'returns only system images' do
      system_images = create_list(:shared_apple_image, 2, account: account, image_type: 'system')
      create_list(:shared_apple_image, 2, account: account, image_type: 'branding')
      create_list(:shared_apple_image, 2, account: account, image_type: 'template')

      get "/api/v1/accounts/#{account.id}/shared_apple_images/system_images"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['shared_apple_images'].count).to eq(2)
      expect(json['shared_apple_images'].all? { |img| img['image_type'] == 'system' }).to be true
    end

    it 'returns empty array when no system images' do
      create_list(:shared_apple_image, 2, account: account, image_type: 'branding')

      get "/api/v1/accounts/#{account.id}/shared_apple_images/system_images"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['shared_apple_images']).to eq([])
    end
  end

  describe 'GET /api/v1/accounts/:account_id/shared_apple_images/branding_images' do
    it 'returns only branding images' do
      create_list(:shared_apple_image, 2, account: account, image_type: 'system')
      branding_images = create_list(:shared_apple_image, 3, account: account, image_type: 'branding')
      create_list(:shared_apple_image, 2, account: account, image_type: 'template')

      get "/api/v1/accounts/#{account.id}/shared_apple_images/branding_images"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['shared_apple_images'].count).to eq(3)
      expect(json['shared_apple_images'].all? { |img| img['image_type'] == 'branding' }).to be true
    end

    it 'returns empty array when no branding images' do
      create_list(:shared_apple_image, 2, account: account, image_type: 'system')

      get "/api/v1/accounts/#{account.id}/shared_apple_images/branding_images"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['shared_apple_images']).to eq([])
    end
  end

  describe 'GET /api/v1/accounts/:account_id/shared_apple_images/template_images' do
    it 'returns only template images' do
      create_list(:shared_apple_image, 2, account: account, image_type: 'system')
      create_list(:shared_apple_image, 2, account: account, image_type: 'branding')
      template_images = create_list(:shared_apple_image, 4, account: account, image_type: 'template')

      get "/api/v1/accounts/#{account.id}/shared_apple_images/template_images"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['shared_apple_images'].count).to eq(4)
      expect(json['shared_apple_images'].all? { |img| img['image_type'] == 'template' }).to be true
    end

    it 'respects pagination for template images' do
      create_list(:shared_apple_image, 15, account: account, image_type: 'template')

      get "/api/v1/accounts/#{account.id}/shared_apple_images/template_images", params: { per_page: 5 }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['shared_apple_images'].count).to eq(5)
      expect(json['total']).to eq(15)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/shared_apple_images/:id' do
    context 'with valid image' do
      it 'returns image details' do
        image = create(:shared_apple_image, account: account)

        get "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['shared_apple_image']['id']).to eq(image.id)
        expect(json['shared_apple_image']['identifier']).to eq(image.identifier)
        expect(json['shared_apple_image']['image_type']).to eq(image.image_type)
      end

      it 'includes all image attributes' do
        image = create(:shared_apple_image, account: account, description: 'Test image', original_name: 'test.png')

        get "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['shared_apple_image']).to include(
          'id' => image.id,
          'identifier' => image.identifier,
          'description' => 'Test image',
          'original_name' => 'test.png',
          'image_type' => image.image_type,
          'account_id' => account.id
        )
      end
    end

    context 'with non-existent image' do
      it 'returns 404' do
        get "/api/v1/accounts/#{account.id}/shared_apple_images/99999"

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with image from different account' do
      it 'returns 404' do
        other_image = create(:shared_apple_image, account: other_account)

        get "/api/v1/accounts/#{account.id}/shared_apple_images/#{other_image.id}"

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        image = create(:shared_apple_image, account: account)
        sign_out user

        get "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/shared_apple_images' do
    context 'with valid parameters' do
      it 'creates new shared image' do
        params = {
          identifier: 'my_test_image',
          image_type: 'system',
          description: 'Test image',
          original_name: 'test.png'
        }

        expect {
          post "/api/v1/accounts/#{account.id}/shared_apple_images", params: params
        }.to change(SharedAppleImage, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['shared_apple_image']['identifier']).to eq('my_test_image')
        expect(json['shared_apple_image']['image_type']).to eq('system')
      end

      it 'uploads image attachment' do
        file = fixture_file_upload('test_image.jpg', 'image/jpeg')
        params = {
          identifier: 'my_image_with_file',
          image_type: 'branding',
          image: file
        }

        post "/api/v1/accounts/#{account.id}/shared_apple_images", params: params

        expect(response).to have_http_status(:created)
        image = SharedAppleImage.last
        expect(image.image.attached?).to be true
      end

      it 'creates image with all supported types' do
        %w[system branding template].each do |image_type|
          params = {
            identifier: "image_#{image_type}",
            image_type: image_type,
            description: "#{image_type} image"
          }

          post "/api/v1/accounts/#{account.id}/shared_apple_images", params: params

          expect(response).to have_http_status(:created)
          json = JSON.parse(response.body)
          expect(json['shared_apple_image']['image_type']).to eq(image_type)
        end
      end

      it 'stores metadata if provided' do
        params = {
          identifier: 'image_with_metadata',
          image_type: 'system',
          metadata: { width: 512, height: 512, format: 'png' }
        }

        post "/api/v1/accounts/#{account.id}/shared_apple_images", params: params

        expect(response).to have_http_status(:created)
        image = SharedAppleImage.last
        expect(image.metadata).to include('width' => 512, 'height' => 512, 'format' => 'png')
      end

      it 'returns image URL in response' do
        file = fixture_file_upload('test_image.jpg', 'image/jpeg')
        params = {
          identifier: 'url_test_image',
          image_type: 'system',
          image: file
        }

        post "/api/v1/accounts/#{account.id}/shared_apple_images", params: params

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['shared_apple_image']).to have_key('image_url')
      end
    end

    context 'with invalid parameters' do
      it 'returns 422 with missing identifier' do
        params = {
          image_type: 'system'
        }

        post "/api/v1/accounts/#{account.id}/shared_apple_images", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('identifier')
      end

      it 'returns 422 with missing image_type' do
        params = {
          identifier: 'test_image'
        }

        post "/api/v1/accounts/#{account.id}/shared_apple_images", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('image_type')
      end

      it 'returns 422 with invalid image_type' do
        params = {
          identifier: 'test_image',
          image_type: 'invalid_type'
        }

        post "/api/v1/accounts/#{account.id}/shared_apple_images", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('image_type')
      end

      it 'returns 422 with duplicate identifier in same account' do
        create(:shared_apple_image, account: account, identifier: 'duplicate_id')
        params = {
          identifier: 'duplicate_id',
          image_type: 'system'
        }

        post "/api/v1/accounts/#{account.id}/shared_apple_images", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('identifier')
      end

      it 'allows duplicate identifier in different account' do
        create(:shared_apple_image, account: other_account, identifier: 'same_id')
        params = {
          identifier: 'same_id',
          image_type: 'system'
        }

        post "/api/v1/accounts/#{account.id}/shared_apple_images", params: params

        expect(response).to have_http_status(:created)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        sign_out user
        params = { identifier: 'test', image_type: 'system' }

        post "/api/v1/accounts/#{account.id}/shared_apple_images", params: params

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/accounts/:account_id/shared_apple_images/:id' do
    context 'with valid parameters' do
      it 'updates image metadata' do
        image = create(:shared_apple_image, account: account, description: 'Old description')
        params = {
          description: 'Updated description'
        }

        put "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}", params: params

        expect(response).to have_http_status(:success)
        image.reload
        expect(image.description).to eq('Updated description')
      end

      it 'updates original_name' do
        image = create(:shared_apple_image, account: account, original_name: 'old.png')
        params = {
          original_name: 'new.png'
        }

        put "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}", params: params

        expect(response).to have_http_status(:success)
        image.reload
        expect(image.original_name).to eq('new.png')
      end

      it 'updates metadata' do
        image = create(:shared_apple_image, account: account, metadata: { width: 400 })
        params = {
          metadata: { width: 500, height: 500 }
        }

        put "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}", params: params

        expect(response).to have_http_status(:success)
        image.reload
        expect(image.metadata).to include('width' => 500, 'height' => 500)
      end

      it 'updates image_type' do
        image = create(:shared_apple_image, account: account, image_type: 'system')
        params = {
          image_type: 'branding'
        }

        put "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}", params: params

        expect(response).to have_http_status(:success)
        image.reload
        expect(image.image_type).to eq('branding')
      end
    end

    context 'with invalid parameters' do
      it 'returns 422 with invalid image_type' do
        image = create(:shared_apple_image, account: account)
        params = {
          image_type: 'invalid_type'
        }

        put "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('image_type')
      end

      it 'cannot update to duplicate identifier in same account' do
        image1 = create(:shared_apple_image, account: account, identifier: 'id_1')
        image2 = create(:shared_apple_image, account: account, identifier: 'id_2')
        params = {
          identifier: 'id_1'
        }

        put "/api/v1/accounts/#{account.id}/shared_apple_images/#{image2.id}", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('identifier')
      end

      it 'allows updating to same identifier' do
        image = create(:shared_apple_image, account: account, identifier: 'same_id')
        params = {
          identifier: 'same_id',
          description: 'Updated'
        }

        put "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}", params: params

        expect(response).to have_http_status(:success)
      end

      it 'allows identifier that exists in other account' do
        other_image = create(:shared_apple_image, account: other_account, identifier: 'shared_id')
        image = create(:shared_apple_image, account: account, identifier: 'my_id')
        params = {
          identifier: 'shared_id'
        }

        put "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}", params: params

        expect(response).to have_http_status(:success)
        image.reload
        expect(image.identifier).to eq('shared_id')
      end
    end

    context 'with non-existent image' do
      it 'returns 404' do
        params = { description: 'Test' }

        put "/api/v1/accounts/#{account.id}/shared_apple_images/99999", params: params

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        image = create(:shared_apple_image, account: account)
        sign_out user
        params = { description: 'Test' }

        put "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}", params: params

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/shared_apple_images/:id' do
    context 'with valid image' do
      it 'deletes shared image' do
        image = create(:shared_apple_image, account: account)

        expect {
          delete "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}"
        }.to change(SharedAppleImage, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it 'removes image attachment' do
        image = create(:shared_apple_image, account: account)
        image_id = image.image.blob.id

        delete "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}"

        expect(response).to have_http_status(:no_content)
        expect { image.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with non-existent image' do
      it 'returns 404' do
        delete "/api/v1/accounts/#{account.id}/shared_apple_images/99999"

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with image from different account' do
      it 'returns 404' do
        other_image = create(:shared_apple_image, account: other_account)

        delete "/api/v1/accounts/#{account.id}/shared_apple_images/#{other_image.id}"

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        image = create(:shared_apple_image, account: account)
        sign_out user

        delete "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/shared_apple_images/:id/upload' do
    context 'with valid file' do
      it 'uploads and replaces image attachment' do
        image = create(:shared_apple_image, account: account)
        original_blob_id = image.image.blob.id

        file = fixture_file_upload('test_image.jpg', 'image/jpeg')
        post "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}/upload", params: { image: file }

        expect(response).to have_http_status(:success)
        image.reload
        expect(image.image.blob.id).not_to eq(original_blob_id)
        expect(image.image.attached?).to be true
      end

      it 'returns updated image with new URL' do
        image = create(:shared_apple_image, account: account)

        file = fixture_file_upload('test_image.jpg', 'image/jpeg')
        post "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}/upload", params: { image: file }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['shared_apple_image']).to have_key('image_url')
      end

      it 'updates metadata with image dimensions if available' do
        image = create(:shared_apple_image, account: account)

        file = fixture_file_upload('test_image.jpg', 'image/jpeg')
        post "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}/upload", params: { image: file }

        expect(response).to have_http_status(:success)
        image.reload
        expect(image.metadata).to have_key('updated_at')
      end
    end

    context 'with invalid file' do
      it 'returns 422 when no file provided' do
        image = create(:shared_apple_image, account: account)

        post "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}/upload", params: {}

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('image')
      end

      it 'rejects unsupported file type' do
        image = create(:shared_apple_image, account: account)

        file = fixture_file_upload('test.txt', 'text/plain')
        post "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}/upload", params: { image: file }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with non-existent image' do
      it 'returns 404' do
        file = fixture_file_upload('test_image.jpg', 'image/jpeg')

        post "/api/v1/accounts/#{account.id}/shared_apple_images/99999/upload", params: { image: file }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        image = create(:shared_apple_image, account: account)
        sign_out user

        file = fixture_file_upload('test_image.jpg', 'image/jpeg')
        post "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}/upload", params: { image: file }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/shared_apple_images/:id/remove_image' do
    context 'with image attachment' do
      it 'removes image attachment but keeps record' do
        image = create(:shared_apple_image, account: account)
        expect(image.image.attached?).to be true

        delete "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}/remove_image"

        expect(response).to have_http_status(:success)
        image.reload
        expect(image.image.attached?).to be false
        expect(image).to be_persisted
      end

      it 'returns record without attachment' do
        image = create(:shared_apple_image, account: account)

        delete "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}/remove_image"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['shared_apple_image']['id']).to eq(image.id)
        expect(json['shared_apple_image']).not_to have_key('image_url')
      end
    end

    context 'with non-existent image' do
      it 'returns 404' do
        delete "/api/v1/accounts/#{account.id}/shared_apple_images/99999/remove_image"

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        image = create(:shared_apple_image, account: account)
        sign_out user

        delete "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}/remove_image"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'Authorization and access control' do
    context 'with unauthenticated user' do
      it 'requires authentication for all endpoints' do
        sign_out user
        image = create(:shared_apple_image, account: account)

        expect {
          get "/api/v1/accounts/#{account.id}/shared_apple_images"
          expect(response).to have_http_status(:unauthorized)

          get "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}"
          expect(response).to have_http_status(:unauthorized)

          post "/api/v1/accounts/#{account.id}/shared_apple_images", params: { identifier: 'test', image_type: 'system' }
          expect(response).to have_http_status(:unauthorized)

          put "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}", params: {}
          expect(response).to have_http_status(:unauthorized)

          delete "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}"
          expect(response).to have_http_status(:unauthorized)
        }.to avoid_changing(SharedAppleImage, :count)
      end
    end

    context 'with user from different account' do
      it 'cannot access other account images' do
        image = create(:shared_apple_image, account: account)
        sign_in other_user

        expect {
          get "/api/v1/accounts/#{account.id}/shared_apple_images"
          expect(response).to have_http_status(:unauthorized)

          get "/api/v1/accounts/#{account.id}/shared_apple_images/#{image.id}"
          expect(response).to have_http_status(:unauthorized)
        }.not_to change(SharedAppleImage, :count)
      end
    end
  end

  describe 'Response formats' do
    it 'includes proper JSON response structure' do
      create(:shared_apple_image, account: account)

      get "/api/v1/accounts/#{account.id}/shared_apple_images"

      expect(response.content_type).to include('application/json')
      json = JSON.parse(response.body)
      expect(json).to be_a(Hash)
      expect(json).to have_key('shared_apple_images')
    end

    it 'includes pagination metadata' do
      create_list(:shared_apple_image, 15, account: account)

      get "/api/v1/accounts/#{account.id}/shared_apple_images", params: { per_page: 5 }

      json = JSON.parse(response.body)
      expect(json).to have_key('total')
      expect(json).to have_key('page')
      expect(json).to have_key('per_page')
    end

    it 'returns errors with proper structure' do
      params = {
        image_type: 'invalid_type'
      }

      post "/api/v1/accounts/#{account.id}/shared_apple_images", params: params

      json = JSON.parse(response.body)
      expect(json).to have_key('errors')
    end
  end
end
