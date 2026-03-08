# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::PayloadValidatorService do
  let(:validator) { described_class.new(payload, message_type) }

  describe '#validate!' do
    context 'basic payload structure validation' do
      let(:message_type) { 'text' }
      let(:payload) do
        {
          v: 1,
          id: 'msg-123',
          sourceId: 'business-id',
          destinationId: 'user-id',
          type: 'text',
          body: 'Hello'
        }
      end

      it 'passes validation for valid text message' do
        expect { validator.validate! }.not_to raise_error
      end

      it 'fails when payload is not a hash' do
        validator = described_class.new('not a hash', message_type)
        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, 'Payload validation failed: Payload must be a hash')
      end

      it 'fails when missing required fields' do
        payload.delete(:v)
        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Missing required field: v/)
      end

      it 'fails with invalid version' do
        payload[:v] = 2
        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Invalid version/)
      end

      it 'fails with invalid type' do
        payload[:type] = 'invalid'
        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Invalid type: invalid/)
      end
    end

    context 'text message validation' do
      let(:message_type) { 'text' }
      let(:payload) do
        {
          v: 1,
          id: 'msg-123',
          sourceId: 'business-id',
          destinationId: 'user-id',
          type: 'text'
        }
      end

      it 'fails when body is missing' do
        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Text message missing body field/)
      end

      it 'passes when body is present' do
        payload[:body] = 'Hello'
        expect { validator.validate! }.not_to raise_error
      end
    end

    context 'interactive message validation' do
      let(:message_type) { 'apple_list_picker' }
      let(:base_payload) do
        {
          v: 1,
          id: 'msg-123',
          sourceId: 'business-id',
          destinationId: 'user-id',
          type: 'interactive'
        }
      end
      let(:payload) { base_payload }

      it 'fails when interactiveData is missing' do
        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Interactive message missing interactiveData/)
      end

      it 'fails when bid is missing' do
        payload[:interactiveData] = { data: { placeholder: true } }

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /interactiveData missing bid/)
      end

      it 'fails when data object is missing for Apple types' do
        payload[:interactiveData] = { bid: 'com.apple.messages' }

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /interactiveData missing data/)
      end
    end

    context 'apple_list_picker validation' do
      let(:message_type) { 'apple_list_picker' }
      let(:payload) do
        {
          v: 1,
          id: 'msg-123',
          sourceId: 'business-id',
          destinationId: 'user-id',
          type: 'interactive',
          interactiveData: {
            bid: 'com.apple.messages',
            data: { placeholder: true }
          }
        }
      end

      it 'fails when listPicker is missing' do
        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /List picker data missing listPicker field/)
      end

      it 'fails when sections are missing' do
        payload[:interactiveData][:data][:listPicker] = {}

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /List picker data missing listPicker field/)
      end

      it 'fails when sections is not an array' do
        payload[:interactiveData][:data][:listPicker] = { sections: 'not array' }

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /List picker must have at least one section/)
      end

      it 'validates section structure' do
        payload[:interactiveData][:data][:listPicker] = {
          sections: [
            { items: nil }
          ]
        }

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Section 0 missing items/)
      end

      it 'validates item structure' do
        payload[:interactiveData][:data][:listPicker] = {
          sections: [
            {
              items: [
                { title: 'Item 1' } # Missing identifier
              ]
            }
          ]
        }

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Section 0 item 0 missing identifier/)
      end

      it 'validates item style values' do
        payload[:interactiveData][:data][:listPicker] = {
          sections: [
            {
              items: [
                { identifier: '1', title: 'Item', style: 'invalid' }
              ]
            }
          ]
        }

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Section 0 item 0 has invalid style: invalid/)
      end

      it 'passes with valid list picker structure' do
        payload[:interactiveData][:data][:listPicker] = {
          sections: [
            {
              title: 'Section 1',
              items: [
                { identifier: '1', title: 'Item 1', style: 'icon' }
              ]
            }
          ]
        }

        expect { validator.validate! }.not_to raise_error
      end
    end

    context 'apple_time_picker validation' do
      let(:message_type) { 'apple_time_picker' }
      let(:payload) do
        {
          v: 1,
          id: 'msg-123',
          sourceId: 'business-id',
          destinationId: 'user-id',
          type: 'interactive',
          interactiveData: {
            bid: 'com.apple.messages',
            data: { placeholder: true }
          }
        }
      end

      it 'fails when event is missing' do
        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Time picker data missing event field/)
      end

      it 'fails when timeslots are missing' do
        payload[:interactiveData][:data][:event] = {}

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Time picker data missing event field/)
      end

      it 'validates timeslot structure' do
        payload[:interactiveData][:data][:event] = {
          timeslots: [
            { startTime: '2024-01-15T14:30+0000' } # Missing identifier and duration
          ]
        }

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Timeslot 0 missing identifier/)
      end

      it 'validates ISO 8601 date format' do
        payload[:interactiveData][:data][:event] = {
          timeslots: [
            {
              identifier: '1',
              startTime: 'invalid-date',
              duration: 3600
            }
          ]
        }

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Timeslot 0 has invalid ISO 8601 startTime/)
      end

      it 'accepts valid ISO 8601 formats' do
        valid_dates = [
          '2024-01-15T14:30+0000',      # Apple's preferred (no seconds)
          '2024-01-15T14:30:00+0000',   # With seconds
          '2024-01-15T14:30Z',          # UTC notation without seconds
          '2024-01-15T14:30:00Z'        # UTC notation with seconds
        ]

        valid_dates.each do |date|
          payload[:interactiveData][:data][:event] = {
            timeslots: [
              {
                identifier: '1',
                startTime: date,
                duration: 3600
              }
            ]
          }

          expect { validator.validate! }.not_to raise_error
        end
      end
    end

    context 'apple_quick_reply validation' do
      let(:message_type) { 'apple_quick_reply' }
      let(:payload) do
        {
          v: 1,
          id: 'msg-123',
          sourceId: 'business-id',
          destinationId: 'user-id',
          type: 'interactive',
          interactiveData: {
            bid: 'com.apple.messages',
            data: { placeholder: true }
          }
        }
      end

      it 'fails when quick-reply is missing' do
        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Quick reply data missing quick-reply field/)
      end

      it 'validates item count (2-5 required)' do
        # Too few
        payload[:interactiveData][:data][:'quick-reply'] = {
          items: [{ identifier: '1', title: 'Only one' }]
        }

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Quick reply must have 2-5 items/)

        # Too many
        payload[:interactiveData][:data][:'quick-reply'] = {
          items: (1..6).map { |i| { identifier: i.to_s, title: "Item #{i}" } }
        }

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Quick reply must have 2-5 items/)
      end

      it 'passes with valid quick reply structure' do
        payload[:interactiveData][:data][:'quick-reply'] = {
          items: [
            { identifier: '1', title: 'Yes' },
            { identifier: '2', title: 'No' }
          ]
        }

        expect { validator.validate! }.not_to raise_error
      end
    end

    context 'apple_form validation' do
      let(:message_type) { 'apple_form' }
      let(:payload) do
        {
          v: 1,
          id: 'msg-123',
          sourceId: 'business-id',
          destinationId: 'user-id',
          type: 'interactive',
          interactiveData: {
            bid: 'com.apple.messages',
            data: { placeholder: true }
          }
        }
      end

      it 'fails when dynamic is missing' do
        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Form data missing dynamic field/)
      end

      it 'fails when dynamic.data is missing' do
        payload[:interactiveData][:data][:dynamic] = {}

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Form data missing dynamic field/)
      end

      it 'validates page structure' do
        payload[:interactiveData][:data][:dynamic] = {
          data: {
            pages: [
              { type: 'input' } # Missing pageIdentifier and title
            ]
          }
        }

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Form page 0 missing pageIdentifier/)
      end

      it 'passes with valid form structure' do
        payload[:interactiveData][:data][:dynamic] = {
          version: '1.2',
          template: 'messageForms',
          data: {
            startPageIdentifier: '0',
            pages: [
              {
                pageIdentifier: '0',
                type: 'input',
                title: 'Name'
              }
            ]
          }
        }

        expect { validator.validate! }.not_to raise_error
      end
    end

    context 'apple_custom_app validation' do
      let(:message_type) { 'apple_custom_app' }
      let(:payload) do
        {
          v: 1,
          id: 'msg-123',
          sourceId: 'business-id',
          destinationId: 'user-id',
          type: 'interactive',
          interactiveData: {
            bid: 'com.example.app'
          }
        }
      end

      it 'skips data validation for third-party apps' do
        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /apple_custom_app missing appId/)
      end

      it 'validates required fields for custom apps' do
        payload[:interactiveData][:appId] = 123_456_789

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /apple_custom_app missing receivedMessage/)
      end

      it 'passes with valid custom app structure' do
        payload[:interactiveData].merge!(
          appId: 123_456_789,
          appName: 'My App',
          receivedMessage: { title: 'Open in app', style: 'icon' }
        )

        expect { validator.validate! }.not_to raise_error
      end

      it 'does not require data object for custom apps' do
        payload[:interactiveData].merge!(
          appId: 123_456_789,
          receivedMessage: { title: 'Open in app' },
          data: { custom: 'data' } # Should not cause error
        )

        expect { validator.validate! }.not_to raise_error
      end
    end

    context 'apple_authentication validation' do
      let(:message_type) { 'apple_authentication' }
      let(:payload) do
        {
          v: 1,
          id: 'msg-123',
          sourceId: 'business-id',
          destinationId: 'user-id',
          type: 'interactive',
          interactiveData: {
            bid: 'com.apple.messages',
            data: { placeholder: true }
          }
        }
      end

      it 'validates OAuth2 structure' do
        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Authentication missing authenticate object/)
      end

      it 'validates OAuth2 fields' do
        payload[:interactiveData][:data][:authenticate] = {
          oauth2: {}
        }

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Authentication missing oauth2 field/)
      end

      it 'validates OAuth2 responseType' do
        payload[:interactiveData][:data][:authenticate] = {
          oauth2: {
            scope: %w[read write],
            state: 'abc123',
            responseType: 'token', # Invalid
            redirectUri: 'https://example.com/callback'
          }
        }

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /OAuth2 responseType must be 'code'/)
      end

      it 'passes with valid OAuth2 structure' do
        payload[:interactiveData][:data][:authenticate] = {
          oauth2: {
            scope: %w[read write],
            state: 'abc123',
            responseType: 'code',
            redirectUri: 'https://example.com/callback'
          }
        }

        expect { validator.validate! }.not_to raise_error
      end

      it 'handles both camelCase and snake_case fields' do
        payload[:interactiveData][:data][:authenticate] = {
          oauth2: {
            scope: ['read'],
            state: 'abc123',
            response_type: 'code', # Snake case variant
            redirect_uri: 'https://example.com' # Snake case variant
          }
        }

        expect { validator.validate! }.not_to raise_error
      end
    end

    context 'base64 image validation' do
      let(:message_type) { 'apple_list_picker' }
      let(:payload) do
        {
          v: 1,
          id: 'msg-123',
          sourceId: 'business-id',
          destinationId: 'user-id',
          type: 'interactive',
          interactiveData: {
            bid: 'com.apple.messages',
            data: {
              listPicker: {
                sections: [{ items: [{ identifier: '1', title: 'Item' }] }]
              }
            }
          }
        }
      end

      it 'validates base64 encoding' do
        payload[:interactiveData][:data][:images] = [
          {
            identifier: 'img1',
            data: 'not-valid-base64!'
          }
        ]

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Image 0 has invalid base64 encoding/)
      end

      it 'validates image size limits' do
        # Create 11MB of data (over 10MB limit)
        large_data = Base64.strict_encode64('x' * (11 * 1024 * 1024))
        payload[:interactiveData][:data][:images] = [
          {
            identifier: 'img1',
            data: large_data
          }
        ]

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError, /Image 0 exceeds maximum size/)
      end

      it 'passes with valid base64 images' do
        payload[:interactiveData][:data][:images] = [
          {
            identifier: 'img1',
            data: Base64.strict_encode64('valid image data')
          }
        ]

        expect { validator.validate! }.not_to raise_error
      end

      it 'handles empty image arrays' do
        payload[:interactiveData][:data][:images] = []

        expect { validator.validate! }.not_to raise_error
      end
    end

    context 'payload summary logging' do
      let(:message_type) { 'apple_list_picker' }
      let(:payload) do
        {
          v: 1,
          id: 'msg-123',
          sourceId: 'business-id',
          destinationId: 'user-id',
          type: 'interactive',
          interactiveData: {
            bid: 'com.apple.messages',
            data: {
              listPicker: {
                sections: [
                  {
                    items: [
                      { identifier: '1', title: 'Item 1' },
                      { identifier: '2', title: 'Item 2' }
                    ]
                  },
                  {
                    items: [
                      { identifier: '3', title: 'Item 3' }
                    ]
                  }
                ]
              },
              images: [
                { identifier: 'img1', data: Base64.strict_encode64('test image bytes') }
              ]
            }
          }
        }
      end

      it 'logs payload summary after successful validation' do
        allow(Rails.logger).to receive(:info)
        validator.validate!
        expect(Rails.logger).to have_received(:info).with(/Payload summary:.*"section_count":2/)
        expect(Rails.logger).to have_received(:info).with(/Payload summary:.*"total_items":3/)
        expect(Rails.logger).to have_received(:info).with(/Payload summary:.*"image_count":1/)
      end
    end

    context 'edge cases' do
      let(:message_type) { 'apple_list_picker' }

      it 'handles both string and symbol keys' do
        payload = {
          v: 1,
          id: 'msg-123',
          sourceId: 'business-id',
          destinationId: 'user-id',
          type: 'interactive',
          interactiveData: {
            bid: 'com.apple.messages',
            data: {
              'listPicker' => { # String key
                'sections' => [
                  {
                    'items' => [
                      { 'identifier' => '1', 'title' => 'Item' }
                    ]
                  }
                ]
              }
            }
          }
        }

        validator = described_class.new(payload, message_type)
        expect { validator.validate! }.not_to raise_error
      end

      it 'provides detailed error messages' do
        payload = {
          v: 1,
          id: 'msg-123',
          sourceId: 'business-id',
          destinationId: 'user-id',
          type: 'interactive',
          interactiveData: {
            bid: 'com.apple.messages',
            data: {
              listPicker: {
                sections: [
                  {
                    items: [
                      { title: 'No ID' },
                      { identifier: '2' } # No title
                    ]
                  }
                ]
              }
            }
          }
        }

        validator = described_class.new(payload, message_type)

        expect { validator.validate! }
          .to raise_error(described_class::ValidationError) do |error|
            expect(error.message).to include('Section 0 item 0 missing identifier')
            expect(error.message).to include('Section 0 item 1 missing title')
          end
      end
    end
  end
end
