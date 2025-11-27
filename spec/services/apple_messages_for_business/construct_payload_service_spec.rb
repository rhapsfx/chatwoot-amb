# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::ConstructPayloadService, type: :service do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_apple_messages_for_business, account: account) }

  describe '#perform' do
    context 'with valid inputs and successful API response' do
      it 'returns success with richLinkDataRef' do
        url = 'https://www.example.com/app'
        store_region = 'US'

        # Mock Apple MSP response with richLinkDataRef
        apple_response = {
          'richLinkDataRef' => {
            'signature' => 'sig_123',
            'signature-base64' => 'c2lnXzEyMw==',
            'reference' => 'ref_123',
            'certificate' => 'cert_data'
          },
          'version' => 1.0
        }

        allow(HTTParty).to receive(:post).and_return(
          double(
            success?: true,
            code: 200,
            body: apple_response.to_json
          )
        )

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        expect(result[:success]).to be true
        expect(result[:rich_link_data_ref]).to be_present
        expect(result[:version]).to eq(1.0)
        expect(result[:rich_link_data_ref]).to include('signature_base64')
      end

      it 'converts camelCase response to snake_case' do
        url = 'https://www.example.com/app'
        store_region = 'US'

        apple_response = {
          'richLinkDataRef' => {
            'signatureData' => 'sig_data',
            'referenceId' => 'ref_id',
            'certChain' => %w[cert1 cert2]
          },
          'version' => 1.0
        }

        allow(HTTParty).to receive(:post).and_return(
          double(
            success?: true,
            code: 200,
            body: apple_response.to_json
          )
        )

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        # Verify camelCase is converted to snake_case
        rich_link_data_ref = result[:rich_link_data_ref]
        expect(rich_link_data_ref).to include('signature_data')
        expect(rich_link_data_ref).to include('reference_id')
        expect(rich_link_data_ref).to include('cert_chain')
      end

      it 'includes version in response' do
        url = 'https://www.example.com/app'
        store_region = 'GB'

        apple_response = {
          'richLinkDataRef' => { 'signature' => 'test' },
          'version' => 2.0
        }

        allow(HTTParty).to receive(:post).and_return(
          double(
            success?: true,
            code: 200,
            body: apple_response.to_json
          )
        )

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        expect(result[:version]).to eq(2.0)
      end
    end

    context 'with validation failures' do
      it 'returns error for HTTP URL (not HTTPS)' do
        service = described_class.new(
          channel: channel,
          url: 'http://www.example.com/app',
          store_region: 'US'
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error_code]).to eq('VALIDATION_FAILED')
        expect(result[:error]).to include('is invalid')
      end

      it 'returns error for invalid store region' do
        service = described_class.new(
          channel: channel,
          url: 'https://www.example.com/app',
          store_region: 'INVALID'
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error_code]).to eq('VALIDATION_FAILED')
        expect(result[:error]).to include('is not included in the list')
      end

      it 'returns error for missing URL' do
        service = described_class.new(
          channel: channel,
          url: nil,
          store_region: 'US'
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error_code]).to eq('VALIDATION_FAILED')
        expect(result[:error]).to include("can't be blank")
      end

      it 'returns error for missing store region' do
        service = described_class.new(
          channel: channel,
          url: 'https://www.example.com/app',
          store_region: nil
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error_code]).to eq('VALIDATION_FAILED')
      end

      it 'includes full error message from validator' do
        service = described_class.new(
          channel: channel,
          url: 'http://invalid',
          store_region: 'XX'
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error]).to include(',')  # Multiple errors joined with commas
      end
    end

    context 'with Apple API 400 error (NO_APP_CLIPS_SUPPORT)' do
      it 'returns NO_APP_CLIPS_SUPPORT error code' do
        url = 'https://www.example.com/app'
        store_region = 'US'

        allow(HTTParty).to receive(:post).and_return(
          double(
            success?: false,
            code: 400,
            body: 'Bad Request: URL does not support App Clips'
          )
        )

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error_code]).to eq('NO_APP_CLIPS_SUPPORT')
        expect(result[:error]).to include('does not support App Clips')
      end
    end

    context 'with other HTTP errors' do
      it 'returns API_ERROR for 401 Unauthorized' do
        url = 'https://www.example.com/app'
        store_region = 'US'

        allow(HTTParty).to receive(:post).and_return(
          double(
            success?: false,
            code: 401,
            body: 'Unauthorized'
          )
        )

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error_code]).to eq('API_ERROR')
        expect(result[:error]).to include('HTTP 401')
      end

      it 'returns API_ERROR for 500 Internal Server Error' do
        url = 'https://www.example.com/app'
        store_region = 'US'

        allow(HTTParty).to receive(:post).and_return(
          double(
            success?: false,
            code: 500,
            body: 'Internal Server Error'
          )
        )

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error_code]).to eq('API_ERROR')
        expect(result[:error]).to include('HTTP 500')
      end

      it 'returns API_ERROR for 503 Service Unavailable' do
        url = 'https://www.example.com/app'
        store_region = 'US'

        allow(HTTParty).to receive(:post).and_return(
          double(
            success?: false,
            code: 503,
            body: 'Service Unavailable'
          )
        )

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error_code]).to eq('API_ERROR')
        expect(result[:error]).to include('HTTP 503')
      end
    end

    context 'with exception handling' do
      it 'catches and returns error for StandardError' do
        url = 'https://www.example.com/app'
        store_region = 'US'

        allow(HTTParty).to receive(:post).and_raise(StandardError, 'Network timeout')

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error_code]).to eq('EXCEPTION')
        expect(result[:error]).to include('Network timeout')
      end

      it 'catches Timeout errors' do
        url = 'https://www.example.com/app'
        store_region = 'US'

        allow(HTTParty).to receive(:post).and_raise(Timeout::Error, 'Request timeout')

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error_code]).to eq('EXCEPTION')
        expect(result[:error]).to include('Request timeout')
      end

      it 'catches JSON parse errors' do
        url = 'https://www.example.com/app'
        store_region = 'US'

        allow(HTTParty).to receive(:post).and_return(
          double(
            success?: true,
            code: 200,
            body: 'Invalid JSON {{'
          )
        )

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error_code]).to eq('EXCEPTION')
      end
    end

    context 'with JWT authentication' do
      it 'uses channel JWT token in Authorization header' do
        url = 'https://www.example.com/app'
        store_region = 'US'

        apple_response = {
          'richLinkDataRef' => { 'signature' => 'test' },
          'version' => 1.0
        }

        expect(HTTParty).to receive(:post) do |_path, options|
          # Verify Authorization header contains JWT token
          auth_header = options[:headers]['Authorization']
          expect(auth_header).to start_with('Bearer ')
          expect(auth_header).to include(channel.generate_jwt_token)

          double(
            success?: true,
            code: 200,
            body: apple_response.to_json
          )
        end

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        expect(result[:success]).to be true
      end

      it 'includes Source-Id header with business_id' do
        url = 'https://www.example.com/app'
        store_region = 'US'

        apple_response = {
          'richLinkDataRef' => { 'signature' => 'test' },
          'version' => 1.0
        }

        expect(HTTParty).to receive(:post) do |_path, options|
          source_id = options[:headers]['Source-Id']
          expect(source_id).to eq(channel.business_id)

          double(
            success?: true,
            code: 200,
            body: apple_response.to_json
          )
        end

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        expect(result[:success]).to be true
      end
    end

    context 'with CaseTransformer application' do
      it 'transforms request payload to Apple format (snake_case → camelCase)' do
        url = 'https://www.example.com/app'
        store_region = 'US'

        apple_response = {
          'richLinkDataRef' => { 'signature' => 'test' },
          'version' => 1.0
        }

        expect(HTTParty).to receive(:post) do |_path, options|
          body = JSON.parse(options[:body])

          # Verify payload has camelCase keys (Apple format)
          expect(body).to have_key('type')
          expect(body).to have_key('link')
          expect(body['link']).to have_key('storeRegion')  # snake_case → camelCase

          double(
            success?: true,
            code: 200,
            body: apple_response.to_json
          )
        end

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        expect(result[:success]).to be true
      end
    end

    context 'with different store regions' do
      %w[US GB CA AU DE FR JP CN IN BR].each do |region|
        it "handles store region #{region}" do
          url = 'https://www.example.com/app'

          apple_response = {
            'richLinkDataRef' => { 'signature' => 'test' },
            'version' => 1.0
          }

          allow(HTTParty).to receive(:post).and_return(
            double(
              success?: true,
              code: 200,
              body: apple_response.to_json
            )
          )

          service = described_class.new(
            channel: channel,
            url: url,
            store_region: region
          )

          result = service.perform

          expect(result[:success]).to be true
        end
      end
    end

    context 'with edge case URLs' do
      it 'handles URLs with long query parameters' do
        url = 'https://www.example.com/app?campaign=test&param1=value1&param2=value2'
        store_region = 'US'

        apple_response = {
          'richLinkDataRef' => { 'signature' => 'test' },
          'version' => 1.0
        }

        allow(HTTParty).to receive(:post).and_return(
          double(
            success?: true,
            code: 200,
            body: apple_response.to_json
          )
        )

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        expect(result[:success]).to be true
      end

      it 'handles URLs with fragments' do
        url = 'https://www.example.com/app#section'
        store_region = 'US'

        apple_response = {
          'richLinkDataRef' => { 'signature' => 'test' },
          'version' => 1.0
        }

        allow(HTTParty).to receive(:post).and_return(
          double(
            success?: true,
            code: 200,
            body: apple_response.to_json
          )
        )

        service = described_class.new(
          channel: channel,
          url: url,
          store_region: store_region
        )

        result = service.perform

        expect(result[:success]).to be true
      end
    end
  end

  describe 'request structure' do
    it 'sends payload with correct structure to Apple API' do
      url = 'https://www.example.com/app'
      store_region = 'US'

      apple_response = {
        'richLinkDataRef' => { 'signature' => 'test' },
        'version' => 1.0
      }

      expect(HTTParty).to receive(:post) do |path, options|
        # Verify endpoint
        expect(path).to include('/constructPayload')

        body = JSON.parse(options[:body])

        # Verify request structure
        expect(body).to include('type', 'link', 'version')
        expect(body['type']).to eq('link')
        expect(body['link']).to include('url', 'storeRegion')
        expect(body['link']['url']).to eq(url)
        expect(body['link']['storeRegion']).to eq(store_region)
        expect(body['version']).to eq(1.0)

        double(
          success?: true,
          code: 200,
          body: apple_response.to_json
        )
      end

      service = described_class.new(
        channel: channel,
        url: url,
        store_region: store_region
      )

      result = service.perform

      expect(result[:success]).to be true
    end

    it 'sets correct headers for request' do
      url = 'https://www.example.com/app'
      store_region = 'US'

      apple_response = {
        'richLinkDataRef' => { 'signature' => 'test' },
        'version' => 1.0
      }

      expect(HTTParty).to receive(:post) do |_path, options|
        headers = options[:headers]

        expect(headers).to include('Content-Type', 'Authorization', 'id', 'Source-Id')
        expect(headers['Content-Type']).to eq('application/json')
        expect(headers['Authorization']).to start_with('Bearer ')
        expect(headers['id']).not_to be_empty  # UUID
        expect(headers['Source-Id']).to eq(channel.business_id)

        double(
          success?: true,
          code: 200,
          body: apple_response.to_json
        )
      end

      service = described_class.new(
        channel: channel,
        url: url,
        store_region: store_region
      )

      result = service.perform

      expect(result[:success]).to be true
    end
  end
end
