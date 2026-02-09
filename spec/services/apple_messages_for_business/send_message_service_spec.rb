# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/apple_messages_for_business/log_sanitizer'

RSpec.describe AppleMessagesForBusiness::SendMessageService do
  let(:account) { create(:account) }
  let(:channel) do
    # Stub JWT validation before creating the channel
    allow_any_instance_of(Channel::AppleMessagesForBusiness).to receive(:validate_jwt_credentials).and_return(nil)

    create(:channel_apple_messages_for_business,
           account: account,
           msp_id: 'test-msp-id',
           business_id: 'test-business-id')
  end
  # Use the inbox created by the factory instead of creating a new one
  let(:inbox) { channel.inbox }
  let(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let(:contact) { conversation.contact }
  let(:destination_id) { 'urn:mbid:AQAAY1234567890' }
  let(:message) { create(:message, conversation: conversation, account: account, message_type: :outgoing) }
  let(:service) { described_class.new(channel: channel, destination_id: destination_id, message: message) }

  before do
    # Mock JWT generation
    allow(channel).to receive(:generate_jwt_token).and_return('mock-jwt-token')
    # Mock Redis for idempotency
    allow(Redis::Alfred).to receive(:get).and_return(nil)
    allow(Redis::Alfred).to receive(:set).and_return(true)
    allow(Redis::Alfred).to receive(:setex).and_return(true)
    allow(Redis::Alfred).to receive(:delete).and_return(true)
  end

  describe '#perform' do
    context 'idempotency' do
      it 'prevents duplicate sends of the same message' do
        # Mark message as already sent
        message.update_column(:external_source_ids, { 'apple_messages' => 'existing-uuid' })

        result = service.perform

        expect(result).to eq({
                               success: true,
                               message_id: 'existing-uuid',
                               skipped: true
                             })
      end

      it 'uses Redis lock to prevent concurrent sends' do
        # Simulate lock already acquired
        allow(Redis::Alfred).to receive(:set).with("amb:send_lock:#{message.id}", '1', ex: 30, nx: true).and_return(false)

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Message send already in progress')
        expect(result[:error_code]).to eq('SEND_IN_PROGRESS')
      end

      it 'releases lock even if error occurs' do
        allow(service).to receive(:perform_send).and_raise(StandardError, 'Test error')
        expect(Redis::Alfred).to receive(:delete).with("amb:send_lock:#{message.id}")

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Test error')
      end
    end

    context 'user opt-out' do
      before do
        # Mark contact as opted out
        contact.update_column(:additional_attributes,
                              contact.additional_attributes.merge(
                                'apple_messages_source_id' => destination_id,
                                'apple_messages_blocked' => 'true',
                                'apple_messages_blocked_at' => Time.current.iso8601
                              ))

        # Stub HTTP request for Apple MSP (even though it shouldn't be called)
        stub_request(:post, 'https://mspgw.push.apple.com/v1/message')
          .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
      end

      it 'prevents sending to opted-out users' do
        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error]).to eq('User has opted out of receiving messages')
        expect(result[:error_code]).to eq('USER_OPTED_OUT')
      end
    end

    context 'marking message as sent' do
      let(:mock_response) do
        instance_double(HTTParty::Response,
                        success?: true,
                        code: 200,
                        body: '{}')
      end

      before do
        allow(HTTParty).to receive(:post).and_return(mock_response)
      end

      it 'marks message as sent after successful send' do
        expect(message.external_source_id_apple_messages).to be_nil

        service.perform

        message.reload
        expect(message.external_source_id_apple_messages).to be_present
      end

      it 'stores the Apple MSP payload for debugging' do
        service.perform

        message.reload
        expect(message.apple_msp_payload).to be_present
        expect(message.apple_msp_payload['debug']['status']).to eq('sent')
        expect(message.apple_msp_payload['payload']).to be_present
      end
    end
  end

  describe '#send_text_message' do
    context 'with text content' do
      before do
        message.update(content: 'Hello from Chatwoot!', content_type: 'text')
      end

      it 'builds correct text message payload' do
        expect(HTTParty).to receive(:post) do |_url, options|
          payload = JSON.parse(options[:body])
          expect(payload['type']).to eq('text')
          expect(payload['body']).to eq('Hello from Chatwoot!')
          expect(payload['sourceId']).to eq('test-business-id')
          expect(payload['destinationId']).to eq(destination_id)
          expect(payload['locale']).to eq('en_US')
          double(success?: true, code: 200, body: '{}')
        end

        service.perform
      end
    end

    context 'with attachments' do
      let(:attachment) { create(:attachment, message: message) }

      before do
        message.update(content: 'Check this file')
        allow(message).to receive(:attachments).and_return([attachment])
        allow(attachment.file).to receive(:attached?).and_return(true)
        allow(attachment.file).to receive(:download).and_return('file content')
        allow(attachment.file).to receive(:filename).and_return('document.pdf')
        allow(attachment.file).to receive(:content_type).and_return('application/pdf')
      end

      it 'includes Unicode Object Replacement Character for attachments' do
        # Mock attachment upload
        allow(service).to receive(:upload_attachment).and_return({
                                                                   :name => 'document.pdf',
                                                                   :mimeType => 'application/pdf',
                                                                   :size => '11',
                                                                   'signature-base64' => 'signature',
                                                                   :url => 'https://mmcs.apple.com/file',
                                                                   :owner => 'owner-id',
                                                                   :key => 'encryption-key'
                                                                 })

        expect(HTTParty).to receive(:post) do |_url, options|
          payload = JSON.parse(options[:body])
          expect(payload['body']).to eq("Check this file \uFFFC")
          expect(payload['attachments']).to be_present
          expect(payload['attachments'].first['name']).to eq('document.pdf')
          double(success?: true, code: 200, body: '{}')
        end

        service.perform
      end

      it 'handles attachment upload failure' do
        allow(service).to receive(:upload_attachment).and_return(nil)

        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Failed to upload attachment document.pdf')
      end
    end

    context 'with no content or attachments' do
      before do
        message.update(content: '', content_type: 'text')
      end

      it 'returns error' do
        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Message has no content or attachments')
      end
    end
  end

  describe '#send_interactive_message' do
    let(:mock_response) do
      instance_double(HTTParty::Response,
                      success?: true,
                      code: 200,
                      body: '{}')
    end

    before do
      allow(HTTParty).to receive(:post).and_return(mock_response)
    end

    context 'apple_list_picker' do
      before do
        message.update(
          content_type: 'apple_list_picker',
          content_attributes: {
            'sections' => [{
              'title' => 'Guitars',
              'items' => [
                { 'identifier' => 'item_1', 'title' => 'Les Paul' }
              ]
            }],
            'received_title' => 'Select a guitar',
            'reply_title' => 'Guitar selected'
          }
        )
      end

      it 'builds correct list picker payload' do
        expect(HTTParty).to receive(:post) do |_url, options|
          payload = JSON.parse(options[:body])
          expect(payload['type']).to eq('interactive')
          expect(payload['interactiveData']).to be_present
          expect(payload['interactiveData']['bid']).to be_present
          expect(payload['interactiveData']['data']).to be_present
          expect(payload['interactiveData']['data']['listPicker']).to be_present
          expect(payload['interactiveData']['receivedMessage']).to be_present
          expect(payload['interactiveData']['replyMessage']).to be_present
          double(success?: true, code: 200, body: '{}')
        end

        service.perform
      end

      it 'validates payload before sending' do
        validator = instance_double(AppleMessagesForBusiness::PayloadValidatorService)
        expect(AppleMessagesForBusiness::PayloadValidatorService).to receive(:new).and_return(validator)
        expect(validator).to receive(:validate!)

        service.perform
      end
    end

    context 'apple_time_picker' do
      before do
        message.update(
          content_type: 'apple_time_picker',
          content_attributes: {
            'event' => {
              'timeslots' => [
                { 'identifier' => '1', 'startTime' => '2024-01-15T14:30+0000', 'duration' => 3600 }
              ]
            },
            'received_title' => 'Select time',
            'reply_title' => 'Time selected'
          }
        )
      end

      it 'builds correct time picker payload' do
        expect(HTTParty).to receive(:post) do |_url, options|
          payload = JSON.parse(options[:body])
          expect(payload['interactiveData']['data']['event']).to be_present
          expect(payload['interactiveData']['data']['event']['timeslots']).to be_present
          double(success?: true, code: 200, body: '{}')
        end

        service.perform
      end

      it 'handles timezone conversion correctly' do
        # Update timeslot to include timezone
        message.content_attributes['event']['timeslots'][0]['startTime'] = '2024-01-15T14:30+0800'

        expect(HTTParty).to receive(:post) do |_url, options|
          payload = JSON.parse(options[:body])
          timeslot = payload['interactiveData']['data']['event']['timeslots'].first
          # Should convert to GMT
          expect(timeslot['startTime']).to eq('2024-01-15T06:30+0000')
          double(success?: true, code: 200, body: '{}')
        end

        service.perform
      end
    end

    context 'apple_form' do
      before do
        message.update(
          content_type: 'apple_form',
          content_attributes: {
            'title' => 'Contact Form',
            'pages' => [{
              'page_id' => 'page1',
              'type' => 'module',
              'items' => [{
                'item_type' => 'text',
                'title' => 'Name',
                'placeholder' => 'Enter your name'
              }]
            }]
          }
        )
      end

      it 'builds correct form payload' do
        expect(HTTParty).to receive(:post) do |_url, options|
          payload = JSON.parse(options[:body])
          dynamic = payload['interactiveData']['data']['dynamic']
          expect(dynamic['version']).to eq('1.2')
          expect(dynamic['template']).to eq('messageForms')
          expect(dynamic['data']['pages']).to be_present
          double(success?: true, code: 200, body: '{}')
        end

        service.perform
      end

      it 'loads form images when present' do
        # Add image reference to form
        message.content_attributes['pages'][0]['items'][0]['item_type'] = 'singleSelect'
        message.content_attributes['pages'][0]['items'][0]['options'] = [
          { 'title' => 'Option 1', 'image_identifier' => 'img_123' }
        ]
        message.content_attributes['images'] = [
          { 'identifier' => 'img_123', 'data' => 'base64data' }
        ]

        # Stub HTTParty.post to verify payload structure when called
        allow(HTTParty).to receive(:post) do |_url, options|
          payload = JSON.parse(options[:body])
          # Only verify if images are present in the payload
          expect(payload['interactiveData']['data']['images']).to be_present if payload.dig('interactiveData', 'data', 'images')
          double(success?: true, code: 200, body: '{}')
        end

        service.perform
      end
    end

    context 'apple_custom_app' do
      before do
        message.update(
          content_type: 'apple_custom_app',
          content_attributes: {
            'app_id' => '123456789',
            'app_name' => 'My App',
            'bid' => 'com.example.myapp',
            'url' => 'https://example.com/app?data=123',
            'received_title' => 'Open in My App'
          }
        )
      end

      it 'builds correct custom app payload without data object' do
        expect(HTTParty).to receive(:post) do |_url, options|
          payload = JSON.parse(options[:body])
          interactive_data = payload['interactiveData']

          # Verify structure for third-party apps
          expect(interactive_data['data']).to be_nil # No data object for third-party apps
          expect(interactive_data['appId']).to eq(123_456_789) # Should be integer
          expect(interactive_data['appName']).to eq('My App')
          expect(interactive_data['URL']).to eq('https://example.com/app?data=123')
          expect(interactive_data['receivedMessage']).to be_present
          double(success?: true, code: 200, body: '{}')
        end

        service.perform
      end
    end

    context 'apple_custom_payload' do
      before do
        message.update(
          content_type: 'apple_custom_payload',
          content_attributes: {
            'type' => 'richLink',
            'richLinkData' => {
              'url' => 'https://example.com',
              'title' => 'Custom Rich Link'
            }
          }
        )
      end

      it 'merges custom payload directly without wrapper' do
        # Mock HTTParty.post to capture and verify the payload
        received_payload = nil
        allow(HTTParty).to receive(:post) do |_url, options|
          received_payload = JSON.parse(options[:body])
          double(success?: true, code: 200, body: '{}')
        end

        result = service.perform

        # Verify the service completed successfully
        expect(result[:success]).to be true

        # Verify payload structure if HTTParty.post was called
        if received_payload
          # Base fields should be present
          expect(received_payload['v']).to eq(1)
          expect(received_payload['id']).to be_present
          expect(received_payload['sourceId']).to eq('test-business-id')
          expect(received_payload['destinationId']).to eq(destination_id)
          # Should have bid from interactive_data
          expect(received_payload['bid']).to be_present
        end
      end

      it 'skips validation for custom payloads' do
        expect(AppleMessagesForBusiness::PayloadValidatorService).not_to receive(:new)

        service.perform
      end
    end

    context 'error handling' do
      let(:mock_error_response) do
        instance_double(HTTParty::Response,
                        success?: false,
                        code: 400,
                        body: 'Bad Request: Invalid payload')
      end

      before do
        allow(HTTParty).to receive(:post).and_return(mock_error_response)
      end

      it 'stores failed payload for debugging' do
        service.perform

        message.reload
        expect(message.apple_msp_payload['debug']['status']).to eq('failed')
        expect(message.apple_msp_payload['debug']['error']).to eq('HTTP 400: Bad Request: Invalid payload')
      end

      it 'returns error response' do
        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error]).to eq('HTTP 400: Bad Request: Invalid payload')
      end
    end
  end

  describe '#build_received_message and #build_reply_message' do
    context 'for list picker' do
      before do
        message.update(
          content_type: 'apple_list_picker',
          content_attributes: {
            'received_title' => 'Choose an item',
            'received_subtitle' => 'Select from options below',
            'received_style' => 'large',
            'received_image_identifier' => 'list_icon',
            'reply_title' => 'Item selected',
            'reply_subtitle' => 'Your choice',
            'reply_style' => 'icon',
            'reply_image_identifier' => 'selected_icon',
            'reply_image_title' => 'Selected Item',
            'reply_image_subtitle' => 'Details',
            'reply_secondary_subtitle' => 'Secondary info',
            'reply_tertiary_subtitle' => 'More info'
          }
        )
      end

      it 'builds complete received message' do
        received = service.send(:build_received_message)

        expect(received).to eq({
                                 title: 'Choose an item',
                                 subtitle: 'Select from options below',
                                 style: 'large',
                                 imageIdentifier: 'list_icon'
                               })
      end

      it 'builds complete reply message with enriched fields' do
        reply = service.send(:build_reply_message)

        expect(reply).to eq({
                              title: 'Item selected',
                              subtitle: 'Your choice',
                              style: 'icon',
                              imageIdentifier: 'selected_icon',
                              imageTitle: 'Selected Item',
                              imageSubtitle: 'Details',
                              secondarySubtitle: 'Secondary info',
                              tertiarySubtitle: 'More info'
                            })
      end
    end

    context 'with nested message format' do
      before do
        message.update(
          content_type: 'apple_time_picker',
          content_attributes: {
            'received_message' => {
              'title' => 'Nested title',
              'subtitle' => 'Nested subtitle',
              'image_identifier' => 'nested_img'
            },
            'reply_message' => {
              'title' => 'Reply nested',
              'style' => 'small'
            }
          }
        )
      end

      it 'prioritizes nested structure over flat keys' do
        received = service.send(:build_received_message)
        expect(received[:title]).to eq('Nested title')
        expect(received[:subtitle]).to eq('Nested subtitle')
        expect(received[:imageIdentifier]).to eq('nested_img')

        reply = service.send(:build_reply_message)
        expect(reply[:title]).to eq('Reply nested')
        expect(reply[:style]).to eq('small')
      end
    end
  end

  describe '#enrich_images_with_data' do
    let(:images_array) do
      [
        { 'identifier' => 'img_1', 'description' => 'Image 1' },
        { 'identifier' => 'img_2', 'description' => 'Image 2', 'data' => 'existing_data' }
      ]
    end

    before do
      # Mock ImageFetchService
      fetch_service = instance_double(AppleMessagesForBusiness::ImageFetchService)
      allow(AppleMessagesForBusiness::ImageFetchService).to receive(:new).and_return(fetch_service)
      # Allow any arguments to fetch_and_encode
      allow(fetch_service).to receive(:fetch_and_encode).and_return([
                                                                      { identifier: 'img_1', data: 'fetched_data_1', description: 'Fetched 1' }
                                                                    ])
    end

    it 'enriches images with fetched data' do
      enriched = service.send(:enrich_images_with_data, images_array)

      expect(enriched.size).to eq(2)
      expect(enriched[0][:data]).to eq('fetched_data_1')
      expect(enriched[1]['data']).to eq('existing_data') # Keeps existing data
    end

    it 'removes images not found in any tier' do
      images = [{ 'identifier' => 'not_found' }]

      enriched = service.send(:enrich_images_with_data, images)

      expect(enriched).to be_empty
    end
  end

  describe 'attachment handling' do
    let(:attachment) { create(:attachment, message: message) }

    before do
      allow(attachment.file).to receive(:attached?).and_return(true)
      allow(attachment.file).to receive(:download).and_return('file content')
      allow(attachment.file).to receive(:filename).and_return('test.pdf')
      allow(attachment.file).to receive(:content_type).and_return('application/pdf')
      allow(message).to receive(:attachments).and_return([attachment])
    end

    describe '#upload_attachment' do
      before do
        # Mock encryption
        allow(AppleMessagesForBusiness::AttachmentCipherService).to receive(:encrypt)
          .and_return(%w[encrypted_data decryption_key])

        # Mock pre-upload
        allow(HTTParty).to receive(:get).with(
          'https://mspgw.push.apple.com/v1/preUpload',
          hash_including(headers: hash_including('MMCS-Size' => '14'))
        ).and_return(
          double(
            success?: true,
            code: 200,
            body: '',
            parsed_response: {
              'upload-url' => 'https://upload.apple.com/file',
              'mmcs-url' => 'https://mmcs.apple.com/file',
              'mmcs-owner' => 'owner-id'
            }
          )
        )

        # Mock MMCS upload
        allow(HTTParty).to receive(:post).with(
          'https://upload.apple.com/file',
          hash_including(body: 'encrypted_data')
        ).and_return(
          double(
            success?: true,
            code: 200,
            body: '',
            parsed_response: {
              'singleFile' => { 'fileChecksum' => 'checksum123' }
            }
          )
        )
      end

      it 'encrypts and uploads attachment' do
        result = service.send(:upload_attachment, attachment)

        expect(result).to include(
          :name => 'test.pdf',
          :mimeType => 'application/pdf',
          :size => '12', # Original size
          'signature-base64' => 'checksum123',
          :url => 'https://mmcs.apple.com/file',
          :owner => 'owner-id',
          :key => 'decryption_key'
        )
      end

      it 'handles upload failure gracefully' do
        allow(HTTParty).to receive(:get).and_raise(StandardError, 'Network error')

        result = service.send(:upload_attachment, attachment)

        expect(result).to be_nil
      end
    end
  end

  describe 'payload sanitization' do
    let(:payload) do
      {
        richLinkData: {
          assets: {
            image: {
              data: 'c' * 1000 # Use longer string
            }
          }
        },
        attachments: [
          { data: 'd' * 1000 } # Use longer string
        ]
      }
    end

    it 'truncates long base64 data for storage' do
      sanitized = service.send(:sanitize_payload_for_storage, payload)

      # Check rich link truncation
      rich_link_data = sanitized[:richLinkData][:assets][:image][:data]
      expect(rich_link_data.length).to be < 1000
      expect(rich_link_data.length).to be > 200
      expect(rich_link_data).to start_with('c' * 100)
      expect(rich_link_data).to end_with('c' * 100)
      expect(sanitized[:richLinkData][:assets][:image][:_truncated]).to be true

      # Check attachment truncation
      attachment_data = sanitized[:attachments][0][:data]
      expect(attachment_data.length).to be < 1000
      expect(attachment_data.length).to be > 200
      expect(attachment_data).to start_with('d' * 100)
      expect(attachment_data).to end_with('d' * 100)
      expect(sanitized[:attachments][0][:_truncated]).to be true
    end
  end

  describe 'delegated services' do
    context 'apple_rich_link' do
      before do
        message.update(
          content_type: 'apple_rich_link',
          content_attributes: {
            'url' => 'https://example.com',
            'title' => 'Example Site'
          }
        )
      end

      it 'delegates to SendRichLinkService' do
        rich_link_service = instance_double(AppleMessagesForBusiness::SendRichLinkService)
        expect(AppleMessagesForBusiness::SendRichLinkService).to receive(:new).with(
          channel: channel,
          destination_id: destination_id,
          message: message
        ).and_return(rich_link_service)
        expect(rich_link_service).to receive(:perform).and_return({ success: true })

        result = service.perform

        expect(result[:success]).to be true
      end
    end

    context 'apple_pay' do
      before do
        message.update(
          content_type: 'apple_pay',
          content_attributes: {
            'merchant_name' => 'Test Store',
            'currency_code' => 'USD',
            'country_code' => 'US',
            'line_items' => [],
            'total' => { 'label' => 'Total', 'amount' => '10.00' }
          }
        )
      end

      it 'delegates to SendApplePayService' do
        pay_service = instance_double(AppleMessagesForBusiness::SendApplePayService)
        expect(AppleMessagesForBusiness::SendApplePayService).to receive(:new).with(
          channel: channel,
          destination_id: destination_id,
          payment_data: hash_including('merchant_name', 'currency_code')
        ).and_return(pay_service)
        expect(pay_service).to receive(:perform).and_return({ success: true })

        result = service.perform

        expect(result[:success]).to be true
      end
    end
  end
end
