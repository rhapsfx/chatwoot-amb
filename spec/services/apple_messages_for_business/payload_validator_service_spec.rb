# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::PayloadValidatorService do
  # A minimal 1x1 PNG, base64-encoded.
  let(:png_base64) do
    Base64.strict_encode64(
      "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1F\x15\xC4\x89".b
    )
  end
  let(:jpeg_base64) { Base64.strict_encode64("\xFF\xD8\xFF\xE0not a real jpeg but has the right magic bytes".b) }
  let(:valid_uuid) { SecureRandom.uuid }

  def text_payload(id: valid_uuid)
    { v: 1, id: id, sourceId: 'biz', destinationId: 'opaque-id', type: 'text', body: 'hi' }
  end

  def list_picker_payload(request_identifier: valid_uuid, images: nil)
    payload = {
      v: 1,
      id: valid_uuid,
      sourceId: 'biz',
      destinationId: 'opaque-id',
      type: 'interactive',
      interactiveData: {
        bid: 'com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension',
        data: {
          requestIdentifier: request_identifier,
          listPicker: { sections: [{ items: [{ identifier: '1', title: 'Item' }] }] }
        }
      }
    }
    payload[:interactiveData][:data][:images] = images if images
    payload
  end

  describe 'id UUID validation' do
    it 'passes for a valid UUID' do
      expect { described_class.new(text_payload, 'text').validate! }.not_to raise_error
    end

    it 'rejects a non-UUID id' do
      expect { described_class.new(text_payload(id: 'not-a-uuid'), 'text').validate! }
        .to raise_error(described_class::ValidationError, /valid UUID/)
    end
  end

  describe 'requestIdentifier UUID validation' do
    it 'passes for a valid UUID' do
      expect { described_class.new(list_picker_payload, 'apple_list_picker').validate! }.not_to raise_error
    end

    it 'rejects a non-UUID requestIdentifier' do
      expect { described_class.new(list_picker_payload(request_identifier: 'abc123'), 'apple_list_picker').validate! }
        .to raise_error(described_class::ValidationError, /requestIdentifier must be a valid UUID/)
    end
  end

  describe 'interactive-message image validation (spec v4.2.2: PNG-only, 200KB max)' do
    it 'accepts a PNG image under 200KB' do
      images = [{ identifier: '1', data: png_base64 }]
      expect { described_class.new(list_picker_payload(images: images), 'apple_list_picker').validate! }.not_to raise_error
    end

    it 'rejects a JPEG image even though it is small' do
      images = [{ identifier: '1', data: jpeg_base64 }]
      expect { described_class.new(list_picker_payload(images: images), 'apple_list_picker').validate! }
        .to raise_error(described_class::ValidationError, /must be PNG format/)
    end

    it 'rejects an image over 200KB even if it is PNG' do
      oversized_png = "\x89PNG\r\n\x1a\n".b + ('a' * (201 * 1024))
      images = [{ identifier: '1', data: Base64.strict_encode64(oversized_png) }]
      expect { described_class.new(list_picker_payload(images: images), 'apple_list_picker').validate! }
        .to raise_error(described_class::ValidationError, /exceeds maximum size/)
    end
  end
end
