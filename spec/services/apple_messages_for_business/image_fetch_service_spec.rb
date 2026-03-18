# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::ImageFetchService, type: :service do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:service) { described_class.new(account_id: account.id, inbox_id: inbox.id, embedded_images: embedded_images) }
  let(:embedded_images) { [] }

  # Stub encode_for_apple in all tier/hierarchy/logging tests so they don't depend on ImageMagick.
  # encode_for_apple's own behavior (DPI, JPEG format) is tested in a dedicated describe block below.
  let(:fake_jpeg_base64) { 'fakejpegbase64==' }
  let(:fake_mime) { 'image/jpeg' }

  shared_context 'with encode_for_apple stubbed' do
    before do
      allow(service).to receive(:encode_for_apple).and_return([fake_jpeg_base64, fake_mime])
    end
  end

  def imagemagick_available?
    system('which convert > /dev/null 2>&1') || system('which magick > /dev/null 2>&1')
  end

  describe 'initialization' do
    it 'initializes with required parameters' do
      expect(service.instance_variable_get(:@account_id)).to eq(account.id)
      expect(service.instance_variable_get(:@inbox_id)).to eq(inbox.id)
    end

    it 'initializes with empty embedded_images when not provided' do
      service = described_class.new(account_id: account.id, inbox_id: inbox.id)
      expect(service.instance_variable_get(:@embedded_images)).to eq([])
    end

    it 'initializes with provided embedded_images' do
      embedded = [{ 'identifier' => 'embedded_1', 'data' => 'base64_data' }]
      service = described_class.new(account_id: account.id, inbox_id: inbox.id, embedded_images: embedded)
      expect(service.instance_variable_get(:@embedded_images)).to eq(embedded)
    end
  end

  describe '#fetch_and_encode' do
    context 'with empty identifiers' do
      it 'returns empty array when identifiers is nil' do
        result = service.fetch_and_encode(nil)
        expect(result).to eq([])
      end

      it 'returns empty array when identifiers is empty array' do
        result = service.fetch_and_encode([])
        expect(result).to eq([])
      end

      it 'returns empty array when identifiers is blank string' do
        result = service.fetch_and_encode('')
        expect(result).to eq([])
      end
    end

    context 'with image from Tier 1: Inbox images' do
      include_context 'with encode_for_apple stubbed'

      it 'fetches and encodes image from inbox-specific storage' do
        create(:apple_list_picker_image, inbox: inbox, identifier: 'inbox_img_1')

        result = service.fetch_and_encode(['inbox_img_1'])

        expect(result.length).to eq(1)
        expect(result[0][:identifier]).to eq('inbox_img_1')
        expect(result[0][:data]).to eq(fake_jpeg_base64)
        # Apple spec only allows: identifier, data, description — no mimeType or source
        expect(result[0].keys).to match_array(%i[identifier data description])
      end

      it 'includes description from picker image' do
        create(:apple_list_picker_image, inbox: inbox, identifier: 'inbox_img_1', description: 'Test description')

        result = service.fetch_and_encode(['inbox_img_1'])

        expect(result[0][:description]).to eq('Test description')
      end

      it 'uses identifier as description when description is blank' do
        create(:apple_list_picker_image, inbox: inbox, identifier: 'inbox_img_1', description: nil)

        result = service.fetch_and_encode(['inbox_img_1'])

        expect(result[0][:description]).to eq('inbox_img_1')
      end
    end

    context 'with image from Tier 2: Shared account-wide images' do
      include_context 'with encode_for_apple stubbed'

      it 'fetches and encodes image from shared storage' do
        create(:shared_apple_image, account: account, identifier: 'shared_img_1')

        result = service.fetch_and_encode(['shared_img_1'])

        expect(result.length).to eq(1)
        expect(result[0][:identifier]).to eq('shared_img_1')
        expect(result[0][:data]).to eq(fake_jpeg_base64)
        # Apple spec only allows: identifier, data, description
        expect(result[0].keys).to match_array(%i[identifier data description])
      end

      it 'includes description from shared image' do
        create(:shared_apple_image, account: account, identifier: 'shared_img_1', description: 'Shared image desc')

        result = service.fetch_and_encode(['shared_img_1'])

        expect(result[0][:description]).to eq('Shared image desc')
      end

      it 'uses identifier as description when shared description is blank' do
        create(:shared_apple_image, account: account, identifier: 'shared_img_1', description: nil)

        result = service.fetch_and_encode(['shared_img_1'])

        expect(result[0][:description]).to eq('shared_img_1')
      end
    end

    context 'with image from Tier 3: Embedded images' do
      let(:embedded_images) do
        [
          { 'identifier' => 'embedded_img_1', 'data' => 'base64encodeddata==', 'description' => 'Embedded image' }
        ]
      end

      it 'fetches and returns embedded image' do
        result = service.fetch_and_encode(['embedded_img_1'])

        expect(result.length).to eq(1)
        expect(result[0][:identifier]).to eq('embedded_img_1')
        expect(result[0][:data]).to eq('base64encodeddata==')
        # Apple spec only allows: identifier, data, description
        expect(result[0].keys).to match_array(%i[identifier data description])
      end

      it 'includes description from embedded image' do
        result = service.fetch_and_encode(['embedded_img_1'])

        expect(result[0][:description]).to eq('Embedded image')
      end

      it 'uses identifier as description when embedded description is blank' do
        embedded_images_no_desc = [
          { 'identifier' => 'embedded_img_1', 'data' => 'base64encodeddata==' }
        ]
        service_no_desc = described_class.new(account_id: account.id, inbox_id: inbox.id, embedded_images: embedded_images_no_desc)

        result = service_no_desc.fetch_and_encode(['embedded_img_1'])

        expect(result[0][:description]).to eq('embedded_img_1')
      end
    end

    context 'with image hierarchy: Tier 1 takes precedence' do
      include_context 'with encode_for_apple stubbed'
      it 'uses inbox image over shared image when both exist' do
        # Create shared image
        create(:shared_apple_image, account: account, identifier: 'priority_img', description: 'Shared')
        # Create inbox image with same identifier
        create(:apple_list_picker_image, inbox: inbox, identifier: 'priority_img', description: 'Inbox')

        result = service.fetch_and_encode(['priority_img'])

        expect(result.length).to eq(1)
        expect(result[0][:description]).to eq('Inbox') # inbox image chosen over shared
      end

      it 'uses shared image when inbox image does not exist' do
        create(:shared_apple_image, account: account, identifier: 'shared_only', description: 'Shared')
        embedded_images_local = [
          { 'identifier' => 'shared_only', 'data' => 'embedded_data', 'description' => 'Embedded' }
        ]
        service_local = described_class.new(account_id: account.id, inbox_id: inbox.id, embedded_images: embedded_images_local)

        result = service_local.fetch_and_encode(['shared_only'])

        expect(result[0][:description]).to eq('Shared') # shared image chosen over embedded
      end

      it 'uses embedded image when inbox and shared images do not exist' do
        embedded_images_local = [
          { 'identifier' => 'embedded_only', 'data' => 'embedded_data', 'description' => 'Embedded' }
        ]
        service_local = described_class.new(account_id: account.id, inbox_id: inbox.id, embedded_images: embedded_images_local)

        result = service_local.fetch_and_encode(['embedded_only'])

        expect(result[0][:description]).to eq('Embedded')
      end
    end

    context 'with multiple images' do
      include_context 'with encode_for_apple stubbed'
      it 'fetches multiple images with mixed sources' do
        # Tier 1: Inbox image
        create(:apple_list_picker_image, inbox: inbox, identifier: 'inbox_img', description: 'From inbox')
        # Tier 2: Shared image
        create(:shared_apple_image, account: account, identifier: 'shared_img', description: 'From shared')
        # Tier 3: Embedded image
        embedded_images_local = [
          { 'identifier' => 'embedded_img', 'data' => 'base64data==', 'description' => 'From embedded' }
        ]
        service_local = described_class.new(account_id: account.id, inbox_id: inbox.id, embedded_images: embedded_images_local)

        result = service_local.fetch_and_encode(%w[inbox_img shared_img embedded_img])

        expect(result.length).to eq(3)

        inbox_result = result.find { |r| r[:identifier] == 'inbox_img' }
        expect(inbox_result[:description]).to eq('From inbox')

        shared_result = result.find { |r| r[:identifier] == 'shared_img' }
        expect(shared_result[:description]).to eq('From shared')

        embedded_result = result.find { |r| r[:identifier] == 'embedded_img' }
        expect(embedded_result[:description]).to eq('From embedded')
      end

      it 'returns only found images, skipping missing ones' do
        create(:apple_list_picker_image, inbox: inbox, identifier: 'inbox_img')

        result = service.fetch_and_encode(%w[inbox_img missing_img also_missing])

        expect(result.length).to eq(1)
        expect(result[0][:identifier]).to eq('inbox_img')
      end

      it 'maintains order of results relative to input' do
        create(:shared_apple_image, account: account, identifier: 'img_1')
        create(:shared_apple_image, account: account, identifier: 'img_2')
        create(:shared_apple_image, account: account, identifier: 'img_3')

        result = service.fetch_and_encode(%w[img_1 img_2 img_3])

        expect(result.map { |r| r[:identifier] }).to eq(%w[img_1 img_2 img_3])
      end
    end

    context 'with image not found anywhere' do
      include_context 'with encode_for_apple stubbed'
      it 'skips image that does not exist in any tier' do
        result = service.fetch_and_encode(['nonexistent_img'])

        expect(result).to be_empty
      end

      it 'returns partial results when some images are missing' do
        create(:shared_apple_image, account: account, identifier: 'found_img')

        result = service.fetch_and_encode(%w[found_img missing_img])

        expect(result.length).to eq(1)
        expect(result[0][:identifier]).to eq('found_img')
      end
    end

    context 'with attachment edge cases' do
      include_context 'with encode_for_apple stubbed'
      it 'skips inbox image without attachment' do
        picker_image = create(:apple_list_picker_image, inbox: inbox, identifier: 'no_attachment')
        picker_image.image.purge

        result = service.fetch_and_encode(['no_attachment'])

        expect(result).to be_empty
      end

      it 'skips shared image without attachment' do
        shared_image = create(:shared_apple_image, account: account, identifier: 'no_attachment')
        shared_image.image.purge

        result = service.fetch_and_encode(['no_attachment'])

        expect(result).to be_empty
      end

      it 'skips embedded image without data' do
        embedded_images_local = [
          { 'identifier' => 'no_data', 'data' => nil }
        ]
        service_local = described_class.new(account_id: account.id, inbox_id: inbox.id, embedded_images: embedded_images_local)

        result = service_local.fetch_and_encode(['no_data'])

        expect(result).to be_empty
      end

      it 'skips embedded image with empty data' do
        embedded_images_local = [
          { 'identifier' => 'empty_data', 'data' => '' }
        ]
        service_local = described_class.new(account_id: account.id, inbox_id: inbox.id, embedded_images: embedded_images_local)

        result = service_local.fetch_and_encode(['empty_data'])

        expect(result).to be_empty
      end
    end

    context 'with error handling' do
      include_context 'with encode_for_apple stubbed'
      it 'continues when inbox image fetch fails' do
        # Create picker image but don't attach it
        picker_image = create(:apple_list_picker_image, inbox: inbox, identifier: 'error_img')
        picker_image.image.purge

        # Create a recoverable image in shared
        create(:shared_apple_image, account: account, identifier: 'safe_img')

        result = service.fetch_and_encode(%w[error_img safe_img])

        expect(result.length).to eq(1)
        expect(result[0][:identifier]).to eq('safe_img')
      end

      it 'continues when shared image fetch fails' do
        # Create shared image without attachment
        shared_image = create(:shared_apple_image, account: account, identifier: 'error_img')
        shared_image.image.purge

        # Use embedded as fallback
        embedded_images_local = [
          { 'identifier' => 'safe_img', 'data' => 'base64data==' }
        ]
        service_local = described_class.new(account_id: account.id, inbox_id: inbox.id, embedded_images: embedded_images_local)

        result = service_local.fetch_and_encode(%w[error_img safe_img])

        expect(result.length).to eq(1)
        expect(result[0][:identifier]).to eq('safe_img')
      end

      it 'handles malformed embedded image gracefully' do
        embedded_images_local = [
          { 'identifier' => 'img1', 'data' => 'base64data==' },
          nil, # Malformed entry
          { 'identifier' => 'img2', 'data' => 'base64data2==' }
        ]
        service_local = described_class.new(account_id: account.id, inbox_id: inbox.id, embedded_images: embedded_images_local)

        result = service_local.fetch_and_encode(%w[img1 img2])

        expect(result.length).to eq(2)
      end
    end

    context 'with logging' do
      include_context 'with encode_for_apple stubbed'
      it 'logs image fetch initiation' do
        allow(Rails.logger).to receive(:info).and_call_original
        expect(Rails.logger).to receive(:info).with(/\[ImageFetch\] Looking for/).at_least(:once).and_call_original

        service.fetch_and_encode(['test_img'])
      end

      it 'logs inbox image found' do
        create(:apple_list_picker_image, inbox: inbox, identifier: 'inbox_img')

        allow(Rails.logger).to receive(:info).and_call_original
        expect(Rails.logger).to receive(:info).with(/\[ImageFetch\] ✅ Found in inbox/).and_call_original

        service.fetch_and_encode(['inbox_img'])
      end

      it 'logs shared image found' do
        create(:shared_apple_image, account: account, identifier: 'shared_img')

        allow(Rails.logger).to receive(:info).and_call_original
        expect(Rails.logger).to receive(:info).with(/\[ImageFetch\] ✅ Found in shared/).and_call_original

        service.fetch_and_encode(['shared_img'])
      end

      it 'logs embedded image found' do
        embedded_images_local = [
          { 'identifier' => 'embedded_img', 'data' => 'base64data==' }
        ]
        service_local = described_class.new(account_id: account.id, inbox_id: inbox.id, embedded_images: embedded_images_local)

        allow(Rails.logger).to receive(:info).and_call_original
        expect(Rails.logger).to receive(:info).with(/\[ImageFetch\] ✅ Found in embedded/).and_call_original

        service_local.fetch_and_encode(['embedded_img'])
      end

      it 'logs image not found warning' do
        allow(Rails.logger).to receive(:warn).and_call_original
        expect(Rails.logger).to receive(:warn).with(/\[ImageFetch\] ⚠️  Image not found/).and_call_original

        service.fetch_and_encode(['nonexistent_img'])
      end

      it 'logs summary of fetched images' do
        create(:shared_apple_image, account: account, identifier: 'img1')
        create(:shared_apple_image, account: account, identifier: 'img2')

        allow(Rails.logger).to receive(:info).and_call_original
        expect(Rails.logger).to receive(:info).with(%r{\[ImageFetch\] Found 2/2 images}).and_call_original

        service.fetch_and_encode(%w[img1 img2])
      end
    end

    context 'with different accounts' do
      include_context 'with encode_for_apple stubbed'
      it 'does not fetch shared images from different accounts' do
        other_account = create(:account)
        create(:shared_apple_image, account: other_account, identifier: 'other_account_img')

        result = service.fetch_and_encode(['other_account_img'])

        expect(result).to be_empty
      end

      it 'only fetches inbox images for the specified inbox' do
        other_inbox = create(:inbox, account: account)
        create(:apple_list_picker_image, inbox: other_inbox, identifier: 'other_inbox_img')

        result = service.fetch_and_encode(['other_inbox_img'])

        expect(result).to be_empty
      end

      it 'fetches only from specified inbox and account' do
        other_account = create(:account)
        other_inbox = create(:inbox, account: other_account)

        # Create image in other account's inbox
        create(:apple_list_picker_image, inbox: other_inbox, identifier: 'img')
        # Create image in this account's inbox
        create(:apple_list_picker_image, inbox: inbox, identifier: 'img')

        result = service.fetch_and_encode(['img'])

        expect(result.length).to eq(1)
        expect(result[0][:identifier]).to eq('img')
      end
    end

    context 'with base64 encoding' do
      include_context 'with encode_for_apple stubbed'

      it 'returns the encoded data from encode_for_apple for inbox images' do
        create(:apple_list_picker_image, inbox: inbox, identifier: 'img')

        result = service.fetch_and_encode(['img'])

        expect(result[0][:data]).to eq(fake_jpeg_base64)
      end

      it 'returns the encoded data from encode_for_apple for shared images' do
        create(:shared_apple_image, account: account, identifier: 'img')

        result = service.fetch_and_encode(['img'])

        expect(result[0][:data]).to eq(fake_jpeg_base64)
      end

      it 'preserves embedded base64 data without re-encoding' do
        embedded_images_local = [
          { 'identifier' => 'img', 'data' => 'dGVzdCBkYXRh' } # 'test data' in base64
        ]
        service_local = described_class.new(account_id: account.id, inbox_id: inbox.id, embedded_images: embedded_images_local)

        result = service_local.fetch_and_encode(['img'])

        expect(result[0][:data]).to eq('dGVzdCBkYXRh')
      end
    end

    context 'with Apple MSP image encoding requirements' do
      # Apple's iOS Messages app requires JPEG at 72 DPI to render interactive message images.
      # Requires ImageMagick — install with: brew install imagemagick
      # The JFIF header stores resolution: byte 11=units (1=DPI), bytes 12-13=X density, 14-15=Y density.
      before { skip 'ImageMagick not installed' unless imagemagick_available? }

      it 'outputs JPEG format (magic bytes FF D8) for inbox images' do
        create(:apple_list_picker_image, inbox: inbox, identifier: 'img')
        result = service.fetch_and_encode(['img'])

        image_data = Base64.strict_decode64(result[0][:data])
        expect(image_data.bytes[0]).to eq(0xFF)
        expect(image_data.bytes[1]).to eq(0xD8)
      end

      it 'outputs JPEG format (magic bytes FF D8) for shared images' do
        create(:shared_apple_image, account: account, identifier: 'img')
        result = service.fetch_and_encode(['img'])

        image_data = Base64.strict_decode64(result[0][:data])
        expect(image_data.bytes[0]).to eq(0xFF)
        expect(image_data.bytes[1]).to eq(0xD8)
      end

      it 'returns only Apple-spec fields (identifier, data, description) for inbox images' do
        create(:apple_list_picker_image, inbox: inbox, identifier: 'img')
        result = service.fetch_and_encode(['img'])

        expect(result[0].keys).to match_array(%i[identifier data description])
      end

      it 'sets DPI to 72 in JFIF header for inbox images' do
        create(:apple_list_picker_image, inbox: inbox, identifier: 'img')
        result = service.fetch_and_encode(['img'])

        image_data = Base64.strict_decode64(result[0][:data])
        # Only check JFIF segment (bytes 2-3: FF E0)
        next unless image_data.bytes[2] == 0xFF && image_data.bytes[3] == 0xE0

        jfif_units = image_data.bytes[11]   # 1 = dots per inch
        x_density = (image_data.bytes[12] << 8) | image_data.bytes[13]
        y_density = (image_data.bytes[14] << 8) | image_data.bytes[15]

        expect(jfif_units).to eq(1)
        expect(x_density).to eq(72)
        expect(y_density).to eq(72)
      end

      it 'sets DPI to 72 in JFIF header for shared images' do
        create(:shared_apple_image, account: account, identifier: 'img')
        result = service.fetch_and_encode(['img'])

        image_data = Base64.strict_decode64(result[0][:data])
        next unless image_data.bytes[2] == 0xFF && image_data.bytes[3] == 0xE0

        jfif_units = image_data.bytes[11]
        x_density = (image_data.bytes[12] << 8) | image_data.bytes[13]
        y_density = (image_data.bytes[14] << 8) | image_data.bytes[15]

        expect(jfif_units).to eq(1)
        expect(x_density).to eq(72)
        expect(y_density).to eq(72)
      end

      it 'does not upscale images smaller than 300x300' do
        create(:apple_list_picker_image, inbox: inbox, identifier: 'img')
        result = service.fetch_and_encode(['img'])

        image_data = Base64.strict_decode64(result[0][:data])
        require 'mini_magick'
        image = MiniMagick::Image.read(image_data)
        expect(image.width).to be <= 300
        expect(image.height).to be <= 300
      end
    end
  end
end
