# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Apple Construct Payload Controller API', type: :request do
  let(:account) { create(:account) }
  let(:admin_user) { create(:user, account: account, role: :administrator) }
  let(:agent_user) { create(:user, account: account, role: :agent) }
  let(:amb_channel) { create(:channel_apple_messages_for_business, account: account) }
  let(:amb_inbox) { amb_channel.inbox }

  describe 'POST /api/v1/accounts/{account_id}/inboxes/{inbox_id}/apple_construct_payload' do
    let(:endpoint) do
      "/api/v1/accounts/#{account.id}/inboxes/#{amb_inbox.id}/apple_construct_payload"
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post endpoint,
             params: { construct_payload: { url: 'https://www.example.com/app', store_region: 'US' } }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated but inbox is not Apple Messages channel' do
      let(:non_amb_inbox) { create(:inbox, account: account) }

      it 'returns unprocessable entity with error message' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{non_amb_inbox.id}/apple_construct_payload",
             params: { construct_payload: { url: 'https://www.example.com/app', store_region: 'US' } },
             headers: admin_user.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['error']).to include('Apple Messages for Business')
      end
    end

    context 'when authenticated as administrator' do
      context 'with valid inputs and successful service response' do
        it 'returns success response with richLinkDataRef' do
          url = 'https://www.example.com/app'
          store_region = 'US'

          service_response = {
            success: true,
            rich_link_data_ref: {
              'signature' => 'test_sig',
              'signature_base64' => 'c2lnXzEyMw==',
              'reference' => 'ref_123'
            },
            version: 1.0
          }

          allow_any_instance_of(AppleMessagesForBusiness::ConstructPayloadService)
            .to receive(:perform).and_return(service_response)

          post endpoint,
               params: { construct_payload: { url: url, store_region: store_region } },
               headers: admin_user.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:ok)
          json_response = response.parsed_body
          expect(json_response['success']).to be true
          expect(json_response['rich_link_data_ref']).to be_present
          expect(json_response['version']).to eq(1.0)
        end

        it 'passes correct parameters to service' do
          url = 'https://www.example.com/app'
          store_region = 'GB'

          service_response = {
            success: true,
            rich_link_data_ref: { 'signature' => 'test' },
            version: 1.0
          }

          expect(AppleMessagesForBusiness::ConstructPayloadService).to receive(:new)
            .with(
              channel: amb_channel,
              url: url,
              store_region: store_region
            )
            .and_call_original

          allow_any_instance_of(AppleMessagesForBusiness::ConstructPayloadService)
            .to receive(:perform).and_return(service_response)

          post endpoint,
               params: { construct_payload: { url: url, store_region: store_region } },
               headers: admin_user.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:ok)
        end

        it 'uses default US region when not provided' do
          url = 'https://www.example.com/app'

          service_response = {
            success: true,
            rich_link_data_ref: { 'signature' => 'test' },
            version: 1.0
          }

          expect(AppleMessagesForBusiness::ConstructPayloadService).to receive(:new)
            .with(
              channel: amb_channel,
              url: url,
              store_region: 'US'  # Default
            )
            .and_call_original

          allow_any_instance_of(AppleMessagesForBusiness::ConstructPayloadService)
            .to receive(:perform).and_return(service_response)

          post endpoint,
               params: { construct_payload: { url: url } },
               headers: admin_user.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:ok)
        end
      end

      context 'with validation error from service' do
        it 'returns 422 with validation error' do
          url = 'http://invalid-http-url.com'  # Invalid: HTTP not HTTPS

          service_response = {
            success: false,
            error: 'Url is invalid',
            error_code: 'VALIDATION_FAILED'
          }

          allow_any_instance_of(AppleMessagesForBusiness::ConstructPayloadService)
            .to receive(:perform).and_return(service_response)

          post endpoint,
               params: { construct_payload: { url: url, store_region: 'US' } },
               headers: admin_user.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = response.parsed_body
          expect(json_response['success']).to be false
          expect(json_response['error']).to include('invalid')
          expect(json_response['error_code']).to eq('VALIDATION_FAILED')
        end
      end

      context 'with NO_APP_CLIPS_SUPPORT error from service' do
        it 'returns 400 Bad Request' do
          url = 'https://www.example.com/app'
          store_region = 'US'

          service_response = {
            success: false,
            error: 'URL does not support App Clips',
            error_code: 'NO_APP_CLIPS_SUPPORT'
          }

          allow_any_instance_of(AppleMessagesForBusiness::ConstructPayloadService)
            .to receive(:perform).and_return(service_response)

          post endpoint,
               params: { construct_payload: { url: url, store_region: store_region } },
               headers: admin_user.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:bad_request)
          json_response = response.parsed_body
          expect(json_response['success']).to be false
          expect(json_response['error_code']).to eq('NO_APP_CLIPS_SUPPORT')
        end
      end

      context 'with other API error from service' do
        it 'returns 422 for API_ERROR' do
          url = 'https://www.example.com/app'
          store_region = 'US'

          service_response = {
            success: false,
            error: 'HTTP 500: Internal Server Error',
            error_code: 'API_ERROR'
          }

          allow_any_instance_of(AppleMessagesForBusiness::ConstructPayloadService)
            .to receive(:perform).and_return(service_response)

          post endpoint,
               params: { construct_payload: { url: url, store_region: store_region } },
               headers: admin_user.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = response.parsed_body
          expect(json_response['success']).to be false
          expect(json_response['error_code']).to eq('API_ERROR')
        end
      end

      context 'with exception from service' do
        it 'returns 422 for EXCEPTION error code' do
          url = 'https://www.example.com/app'
          store_region = 'US'

          service_response = {
            success: false,
            error: 'Network timeout',
            error_code: 'EXCEPTION'
          }

          allow_any_instance_of(AppleMessagesForBusiness::ConstructPayloadService)
            .to receive(:perform).and_return(service_response)

          post endpoint,
               params: { construct_payload: { url: url, store_region: store_region } },
               headers: admin_user.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = response.parsed_body
          expect(json_response['success']).to be false
          expect(json_response['error_code']).to eq('EXCEPTION')
        end
      end
    end

    context 'when authenticated as agent' do
      it 'returns unauthorized' do
        post endpoint,
             params: { construct_payload: { url: 'https://www.example.com/app', store_region: 'US' } },
             headers: agent_user.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid inbox_id' do
      it 'returns not found' do
        post "/api/v1/accounts/#{account.id}/inboxes/999999/apple_construct_payload",
             params: { construct_payload: { url: 'https://www.example.com/app', store_region: 'US' } },
             headers: admin_user.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with invalid account_id' do
      it 'returns not found' do
        post "/api/v1/accounts/999999/inboxes/#{amb_inbox.id}/apple_construct_payload",
             params: { construct_payload: { url: 'https://www.example.com/app', store_region: 'US' } },
             headers: admin_user.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with response format validation' do
      it 'returns all fields in success response' do
        url = 'https://www.example.com/app'
        store_region = 'US'

        service_response = {
          success: true,
          rich_link_data_ref: {
            'signature' => 'test_sig',
            'reference' => 'ref_123'
          },
          version: 2.0
        }

        allow_any_instance_of(AppleMessagesForBusiness::ConstructPayloadService)
          .to receive(:perform).and_return(service_response)

        post endpoint,
             params: { construct_payload: { url: url, store_region: store_region } },
             headers: admin_user.create_new_auth_token,
             as: :json

        json_response = response.parsed_body
        expect(json_response).to include('success', 'rich_link_data_ref', 'version')
      end

      it 'returns all fields in error response' do
        url = 'https://www.example.com/app'
        store_region = 'INVALID'

        service_response = {
          success: false,
          error: 'Store region is not included in the list',
          error_code: 'VALIDATION_FAILED'
        }

        allow_any_instance_of(AppleMessagesForBusiness::ConstructPayloadService)
          .to receive(:perform).and_return(service_response)

        post endpoint,
             params: { construct_payload: { url: url, store_region: store_region } },
             headers: admin_user.create_new_auth_token,
             as: :json

        json_response = response.parsed_body
        expect(json_response).to include('success', 'error', 'error_code')
        expect(json_response).not_to include('rich_link_data_ref')
      end
    end

    context 'with parameter validation' do
      it 'accepts camelCase parameters and normalizes them' do
        # The API controller should auto-normalize camelCase to snake_case
        url = 'https://www.example.com/app'
        store_region = 'US'

        service_response = {
          success: true,
          rich_link_data_ref: { 'signature' => 'test' },
          version: 1.0
        }

        allow_any_instance_of(AppleMessagesForBusiness::ConstructPayloadService)
          .to receive(:perform).and_return(service_response)

        # Send with camelCase storeRegion
        post endpoint,
             params: { construct_payload: { url: url, storeRegion: store_region } },
             headers: admin_user.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with multiple store regions' do
      %w[US GB CA AU DE FR JP CN IN BR].each do |region|
        it "accepts store region #{region}" do
          url = 'https://www.example.com/app'

          service_response = {
            success: true,
            rich_link_data_ref: { 'signature' => 'test' },
            version: 1.0
          }

          allow_any_instance_of(AppleMessagesForBusiness::ConstructPayloadService)
            .to receive(:perform).and_return(service_response)

          post endpoint,
               params: { construct_payload: { url: url, store_region: region } },
               headers: admin_user.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
