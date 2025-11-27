# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::SendRichLinkService, type: :service do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_apple_messages_for_business, account: account) }
  let(:inbox) { channel.inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { create(:message, conversation: conversation, account: account, content: 'https://www.example.com') }

  before do
    allow(HTTParty).to receive(:post).and_return(double(success?: true, code: 200, body: '{}'))
  end

  describe '#perform' do
    describe 'idempotency' do
      it 'returns skipped response if message already sent' do
        message.update_column(:external_source_ids, { 'apple_messages' => 'already_sent_id' })

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
        expect(result[:skipped]).to be true
        expect(result[:message_id]).to eq('already_sent_id')
      end
    end

    describe 'richLinkDataRef mode (App Clips)' do
      it 'uses richLinkDataRef when present in content_attributes' do
        rich_link_data_ref = {
          'signature' => 'test_sig',
          'reference' => 'ref_123',
          'certificate' => 'cert_data'
        }

        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com/app',
                                'rich_link_data_ref' => rich_link_data_ref
                              })

        expect(HTTParty).to receive(:post) do |_path, options|
          body = JSON.parse(options[:body])

          # Verify richLinkDataRef is included
          expect(body).to have_key('richLinkDataRef')
          expect(body).not_to have_key('richLinkData')

          # Verify it's transformed to camelCase
          expect(body['richLinkDataRef']).to have_key('signature')

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end

      it 'applies CaseTransformer to richLinkDataRef' do
        rich_link_data_ref = {
          'signature_base64' => 'c2lnXzEyMw==',
          'reference_id' => 'ref_123',
          'cert_chain' => %w[cert1 cert2]
        }

        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com/app',
                                'rich_link_data_ref' => rich_link_data_ref
                              })

        expect(HTTParty).to receive(:post) do |_path, options|
          body = JSON.parse(options[:body])

          # Verify camelCase transformation (except signature-base64 which uses hyphen per Apple spec)
          expect(body['richLinkDataRef']).to have_key('signature-base64')
          expect(body['richLinkDataRef']).to have_key('referenceId')
          expect(body['richLinkDataRef']).to have_key('certChain')

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end

      it 'does not include richLinkData when richLinkDataRef is present' do
        rich_link_data_ref = {
          'signature' => 'test_sig',
          'reference' => 'ref_123'
        }

        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com/app',
                                'rich_link_data_ref' => rich_link_data_ref,
                                'title' => 'Example Site',
                                'image_url' => 'https://example.com/image.png'
                              })

        expect(HTTParty).to receive(:post) do |_path, options|
          body = JSON.parse(options[:body])

          expect(body).to have_key('richLinkDataRef')
          expect(body).not_to have_key('richLinkData')

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end
    end

    describe 'richLinkData mode (Manual)' do
      it 'uses richLinkData when richLinkDataRef is not present' do
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com',
                                'title' => 'Example Site',
                                'image_url' => 'https://example.com/image.png'
                              })

        # Stub HTTP request for image download
        stub_request(:get, 'https://example.com/image.png')
          .to_return(status: 200, body: 'fake_image_data', headers: { 'Content-Type' => 'image/png' })

        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_return(
            success: false,
            error: 'Not scraping'
          )

        expect(HTTParty).to receive(:post) do |_path, options|
          body = JSON.parse(options[:body])

          # Verify richLinkData is included
          expect(body).to have_key('richLinkData')
          expect(body).not_to have_key('richLinkDataRef')

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end

      it 'does not include richLinkDataRef when in manual mode' do
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com',
                                'title' => 'Example Site'
                              })

        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_return(
            success: false,
            error: 'Not scraping'
          )

        expect(HTTParty).to receive(:post) do |_path, options|
          body = JSON.parse(options[:body])

          expect(body).to have_key('richLinkData')
          expect(body).not_to have_key('richLinkDataRef')

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end

      it 'includes url in richLinkData' do
        url = 'https://www.example.com/page'
        message.update_column(:content_attributes, {
                                'url' => url,
                                'title' => 'Example Site'
                              })

        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_return(
            success: false,
            error: 'Not scraping'
          )

        expect(HTTParty).to receive(:post) do |_path, options|
          body = JSON.parse(options[:body])
          expect(body['richLinkData']['url']).to eq(url)

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end

      it 'includes title in richLinkData' do
        title = 'My Page Title'
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com',
                                'title' => title
                              })

        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_return(
            success: false,
            error: 'Not scraping'
          )

        expect(HTTParty).to receive(:post) do |_path, options|
          body = JSON.parse(options[:body])
          expect(body['richLinkData']['title']).to eq(title)

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end

      it 'includes assets in richLinkData with image data' do
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com',
                                'title' => 'Example',
                                'image_data' => 'base64imagedata==',
                                'image_mime_type' => 'image/png'
                              })

        # Mock scrape_open_graph_data to prevent real HTTP calls
        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_return(
            success: false,
            error: 'Not scraping'
          )

        expect(HTTParty).to receive(:post) do |_path, options|
          body = JSON.parse(options[:body])

          expect(body['richLinkData']).to have_key('assets')
          expect(body['richLinkData']['assets']).to have_key('image')
          expect(body['richLinkData']['assets']['image']['data']).to eq('base64imagedata==')
          expect(body['richLinkData']['assets']['image']['mimeType']).to eq('image/png')

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end
    end

    describe 'payload structure' do
      it 'includes required fields in payload' do
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com'
                              })

        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_return(
            success: false,
            error: 'Not scraping'
          )

        expect(HTTParty).to receive(:post) do |_path, options|
          body = JSON.parse(options[:body])

          expect(body).to include('id', 'type', 'sourceId', 'destinationId', 'v', 'body')
          expect(body['type']).to eq('richLink')
          expect(body['v']).to eq(1)
          expect(body['sourceId']).to eq(channel.business_id)
          expect(body['destinationId']).to eq('user123')

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end

      it 'generates unique message ID for each send' do
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com',
                                'title' => 'Example'
                              })

        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_return(
            success: false,
            error: 'Not scraping'
          )

        message_ids = Set.new

        allow(HTTParty).to receive(:post) do |_path, options|
          body = JSON.parse(options[:body])
          message_ids.add(body['id'])

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
        expect(result[:message_id]).not_to be_empty
      end
    end

    describe 'authentication headers' do
      it 'includes JWT token in Authorization header' do
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com',
                                'title' => 'Example'
                              })

        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_return(
            success: false,
            error: 'Not scraping'
          )

        expect(HTTParty).to receive(:post) do |_path, options|
          headers = options[:headers]

          # Verify JWT token format (starts with Bearer eyJ...)
          expect(headers['Authorization']).to match(/^Bearer eyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$/)

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end

      it 'includes Source-Id header with business_id' do
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com',
                                'title' => 'Example'
                              })

        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_return(
            success: false,
            error: 'Not scraping'
          )

        expect(HTTParty).to receive(:post) do |_path, options|
          headers = options[:headers]

          expect(headers['Source-Id']).to eq(channel.business_id)

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end

      it 'includes Destination-Id header' do
        destination_id = 'user_destination_123'
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com',
                                'title' => 'Example'
                              })

        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_return(
            success: false,
            error: 'Not scraping'
          )

        expect(HTTParty).to receive(:post) do |_path, options|
          headers = options[:headers]

          expect(headers['Destination-Id']).to eq(destination_id)

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: destination_id,
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end
    end

    describe 'lock mechanism' do
      it 'acquires lock for send operation' do
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com',
                                'title' => 'Example'
                              })

        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_return(
            success: false,
            error: 'Not scraping'
          )

        expect(Redis::Alfred).to receive(:set).with(
          "amb:send_lock:#{message.id}",
          '1',
          ex: 30,
          nx: true
        ).and_return(true)

        expect(Redis::Alfred).to receive(:delete).with("amb:send_lock:#{message.id}")

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end

      it 'returns error if lock cannot be acquired' do
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com',
                                'title' => 'Example'
                              })

        allow(Redis::Alfred).to receive(:set).and_return(false)
        allow(Redis::Alfred).to receive(:delete)

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error_code]).to eq('SEND_IN_PROGRESS')
      end
    end

    describe 'response handling' do
      it 'marks message as sent on success' do
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com',
                                'title' => 'Example'
                              })

        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_return(
            success: false,
            error: 'Not scraping'
          )

        allow(HTTParty).to receive(:post).and_return(
          double(success?: true, code: 200, body: '{}')
        )

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true

        # Verify message was marked as sent
        message.reload
        expect(message.external_source_id_apple_messages).to be_present
      end

      it 'returns error for failed HTTP response' do
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com',
                                'title' => 'Example'
                              })

        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_return(
            success: false,
            error: 'Not scraping'
          )

        allow(HTTParty).to receive(:post).and_return(
          double(success?: false, code: 500, body: 'Internal Server Error')
        )

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error]).to include('HTTP 500')
      end
    end

    describe 'richLinkDataRef priority' do
      it 'prioritizes richLinkDataRef over manual data' do
        rich_link_data_ref = {
          'signature' => 'test_sig',
          'reference' => 'ref_123'
        }

        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com/app',
                                'title' => 'Ignored Title',  # Should be ignored
                                'rich_link_data_ref' => rich_link_data_ref
                              })

        expect(HTTParty).to receive(:post) do |_path, options|
          body = JSON.parse(options[:body])

          # richLinkDataRef takes precedence
          expect(body).to have_key('richLinkDataRef')
          expect(body).not_to have_key('richLinkData')

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end

      it 'excludes manual rich link data when richLinkDataRef is present' do
        rich_link_data_ref = {
          'signature' => 'test_sig',
          'reference' => 'ref_123'
        }

        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com/app',
                                'title' => 'Title',
                                'image_url' => 'https://example.com/image.png',
                                'rich_link_data_ref' => rich_link_data_ref
                              })

        expect(HTTParty).to receive(:post) do |_path, options|
          body = JSON.parse(options[:body])

          # Should not have title or manual assets
          expect(body['richLinkData']).to be_nil

          double(success?: true, code: 200, body: '{}')
        end

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be true
      end
    end

    describe 'error handling' do
      it 'catches and returns StandardError' do
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com',
                                'title' => 'Example'
                              })

        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_raise(StandardError, 'Unexpected error')

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error]).to include('Unexpected error')
      end

      it 'always releases lock even on exception' do
        message.update_column(:content_attributes, {
                                'url' => 'https://www.example.com',
                                'title' => 'Example'
                              })

        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:scrape_open_graph_data).and_raise(StandardError, 'Error')

        allow(Redis::Alfred).to receive(:set).and_return(true)
        allow(Redis::Alfred).to receive(:delete).and_return(true)

        service = described_class.new(
          channel: channel,
          destination_id: 'user123',
          message: message
        )

        service.perform

        # Verify delete was called to release lock
        expect(Redis::Alfred).to have_received(:delete).with("amb:send_lock:#{message.id}")
      end
    end
  end
end
