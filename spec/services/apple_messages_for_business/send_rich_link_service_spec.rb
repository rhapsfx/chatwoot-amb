# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::SendRichLinkService, type: :service do
  let(:account) { create(:account) }
  let(:channel) do
    allow_any_instance_of(Channel::AppleMessagesForBusiness).to receive(:validate_jwt_credentials).and_return(nil)
    create(:channel_apple_messages_for_business, account: account)
  end
  let(:inbox) { channel.inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { create(:message, conversation: conversation, account: account, content: 'https://www.example.com') }

  # Stub Apple MSP gateway and scraping by default — override in specific contexts
  before do
    allow(HTTParty).to receive(:post).and_return(double(success?: true, code: 200, body: '{}'))
    allow_any_instance_of(described_class).to receive(:scrape_open_graph_data)
      .and_return({ success: false, error: 'stubbed' })
  end

  def build_service(destination_id: 'user123')
    described_class.new(channel: channel, destination_id: destination_id, message: message)
  end

  def set_content_attrs(attrs)
    message.update_column(:content_attributes, attrs)
  end

  def captured_payload
    body = nil
    allow(HTTParty).to receive(:post) do |_url, opts|
      body = JSON.parse(opts[:body])
      double(success?: true, code: 200, body: '{}')
    end
    yield
    body
  end

  # ---------------------------------------------------------------------------
  # frontend_og_data_usable?
  # ---------------------------------------------------------------------------
  describe '#frontend_og_data_usable?' do
    subject { build_service.send(:frontend_og_data_usable?, attrs, url) }

    let(:url) { 'https://www.example.com/product' }

    context 'when title is blank' do
      let(:attrs) { { 'title' => '', 'image_url' => 'https://example.com/img.jpg' } }

      it { is_expected.to be false }
    end

    context 'when title equals the URL' do
      let(:attrs) { { 'title' => url, 'image_url' => 'https://example.com/img.jpg' } }

      it { is_expected.to be false }
    end

    context 'when title is just the bare domain' do
      let(:attrs) { { 'title' => 'example.com', 'image_url' => 'https://example.com/img.jpg' } }

      it { is_expected.to be false }
    end

    context 'when image_url is a tracking pixel' do
      let(:attrs) { { 'title' => 'Great Product', 'image_url' => 'https://www.site.com/akam/13/pixel_abc' } }

      it { is_expected.to be false }
    end

    context 'when image_url is blank' do
      let(:attrs) { { 'title' => 'Great Product', 'image_url' => '' } }

      it { is_expected.to be false }
    end

    context 'when title and image_url are both meaningful' do
      let(:attrs) { { 'title' => 'Great Product', 'image_url' => 'https://example.com/product.jpg' } }

      it { is_expected.to be true }
    end
  end

  # ---------------------------------------------------------------------------
  # error_page_title?
  # ---------------------------------------------------------------------------
  describe '#error_page_title?' do
    subject { build_service.send(:error_page_title?, title) }

    it { expect(build_service.send(:error_page_title?, 'Access Denied')).to be true }
    it { expect(build_service.send(:error_page_title?, '403 Forbidden')).to be true }
    it { expect(build_service.send(:error_page_title?, 'Page Not Found')).to be true }
    it { expect(build_service.send(:error_page_title?, 'Something Went Wrong')).to be true }
    it { expect(build_service.send(:error_page_title?, 'iPad - Apple')).to be false }
    it { expect(build_service.send(:error_page_title?, nil)).to be false }
    it { expect(build_service.send(:error_page_title?, '')).to be false }
  end

  # ---------------------------------------------------------------------------
  # extract_title_from_url
  # ---------------------------------------------------------------------------
  describe '#extract_title_from_url' do
    subject { build_service.send(:extract_title_from_url, url, site_name) }

    let(:site_name) { nil }

    context 'with a slug-style hotel URL' do
      let(:url) { 'https://www.booking.com/hotel/hu/7seasons-apartments-budapest.en-gb.html' }

      it 'extracts product slug and appends brand' do
        expect(subject).to eq('7seasons Apartments Budapest – Booking')
      end
    end

    context 'with a luxury product URL and site_name' do
      let(:url) { 'https://www.chaumet.com/fr_fr/bague-josephine-aigrette-083590' }
      let(:site_name) { 'Chaumet.com' }

      it 'strips .com suffix from site_name and combines with slug' do
        expect(subject).to eq('Bague Josephine Aigrette – Chaumet')
      end
    end

    context 'with a product slug and numeric ID at end' do
      let(:url) { 'https://www.rimowa.com/fr/fr/luggage/colour/green/cabin-plus/84256311.html' }
      let(:site_name) { 'Rimowa.com' }

      it 'skips numeric segment and uses descriptive slug' do
        expect(subject).to eq('Cabin Plus – Rimowa')
      end
    end

    context 'with a root URL and no path' do
      let(:url) { 'https://www.example.com/' }

      it 'falls back to first domain label' do
        expect(subject).to eq('Example')
      end
    end

    context 'with blank url' do
      let(:url) { '' }

      it { is_expected.to eq('Rich Link') }
    end
  end

  # ---------------------------------------------------------------------------
  # build_assets — cascading image fallback
  # ---------------------------------------------------------------------------
  describe '#build_assets' do
    let(:service) { build_service }

    def build_assets_for(attrs)
      service.send(:build_assets, attrs)
    end

    context 'when image_url is downloadable' do
      before do
        stub_request(:get, 'https://example.com/product.jpg')
          .to_return(status: 200, body: 'x' * 1000, headers: { 'Content-Type' => 'image/jpeg' })
      end

      it 'uses image_url as first candidate' do
        assets = build_assets_for('url' => 'https://example.com', 'image_url' => 'https://example.com/product.jpg')
        expect(assets[:image][:mimeType]).to eq('image/jpeg')
      end
    end

    context 'when image_url download fails and favicon is available' do
      before do
        stub_request(:get, 'https://example.com/large.png')
          .to_return(status: 403, body: 'Forbidden')
        stub_request(:get, 'https://example.com/favicon.ico')
          .to_return(status: 200, body: 'ico_data', headers: { 'Content-Type' => 'image/x-icon' })
      end

      it 'falls through to favicon candidate' do
        allow(service).to receive(:convert_to_jpeg).and_return('jpeg_bytes')

        assets = build_assets_for(
          'url' => 'https://example.com',
          'image_url' => 'https://example.com/large.png',
          'favicon_url' => 'https://example.com/favicon.ico'
        )
        expect(assets).to have_key(:image)
      end
    end

    context 'when all explicit sources fail, falls back to Google favicon' do
      before do
        stub_request(:get, 'https://www.google.com/s2/favicons?domain=example.com&sz=128')
          .to_return(status: 200, body: 'png_bytes', headers: { 'Content-Type' => 'image/png' })
      end

      it 'uses Google favicon as last resort' do
        assets = build_assets_for('url' => 'https://example.com')
        expect(assets[:image][:mimeType]).to eq('image/png')
      end
    end

    context 'when tracking pixel is in image_url' do
      before do
        stub_request(:get, 'https://www.google.com/s2/favicons?domain=darty.com&sz=128')
          .to_return(status: 200, body: 'png_bytes', headers: { 'Content-Type' => 'image/png' })
      end

      it 'filters tracking pixel and uses next candidate' do
        assets = build_assets_for(
          'url' => 'https://darty.com',
          'image_url' => 'https://www.darty.com/akam/13/pixel_abc?a=tracking'
        )
        expect(assets).to have_key(:image)
      end
    end

    context 'when image_data is base64 embedded' do
      it 'uses data URL directly without HTTP download' do
        assets = build_assets_for(
          'url' => 'https://example.com',
          'image_data' => 'data:image/png;base64,abc123==',
          'image_mime_type' => 'image/png'
        )
        expect(assets[:image][:data]).to eq('abc123==')
        expect(assets[:image][:mimeType]).to eq('image/png')
      end
    end

    context 'when image is over 200KB' do
      let(:large_png) { 'x' * (201 * 1024) }

      before do
        stub_request(:get, 'https://example.com/big.png')
          .to_return(status: 200, body: large_png, headers: { 'Content-Type' => 'image/png' })
      end

      it 'compresses rather than discards the image' do
        small_jpeg = 'j' * 50_000
        allow(service).to receive(:compress_image_to_limit).and_return(small_jpeg)

        assets = build_assets_for('url' => 'https://example.com', 'image_url' => 'https://example.com/big.png')
        expect(assets[:image][:mimeType]).to eq('image/jpeg')
        expect(assets[:image][:data]).to eq(Base64.strict_encode64(small_jpeg))
      end

      it 'falls to next candidate if compression fails' do
        allow(service).to receive(:compress_image_to_limit).and_return(nil)

        stub_request(:get, 'https://www.google.com/s2/favicons?domain=example.com&sz=128')
          .to_return(status: 200, body: 'icon', headers: { 'Content-Type' => 'image/png' })

        assets = build_assets_for('url' => 'https://example.com', 'image_url' => 'https://example.com/big.png')
        # Falls back to Google favicon
        expect(assets[:image]).to be_present
      end
    end

    context 'when video_url is present' do
      before do
        stub_request(:get, 'https://www.google.com/s2/favicons?domain=example.com&sz=128')
          .to_return(status: 200, body: 'icon', headers: { 'Content-Type' => 'image/png' })
      end

      it 'includes video asset with detected MIME type' do
        assets = build_assets_for(
          'url' => 'https://example.com',
          'video_url' => 'https://example.com/video.mp4'
        )
        expect(assets[:video][:url]).to eq('https://example.com/video.mp4')
        expect(assets[:video][:mimeType]).to eq('video/mp4')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # download_and_encode_image
  # ---------------------------------------------------------------------------
  describe '#download_and_encode_image' do
    let(:service) { build_service }

    it 'returns [base64, mime_type] for valid JPEG' do
      stub_request(:get, 'https://example.com/photo.jpg')
        .to_return(status: 200, body: 'jpeg_bytes', headers: { 'Content-Type' => 'image/jpeg' })

      result = service.send(:download_and_encode_image, 'https://example.com/photo.jpg')
      expect(result).to eq([Base64.strict_encode64('jpeg_bytes'), 'image/jpeg'])
    end

    it 'uses actual Content-Type header, not URL extension' do
      stub_request(:get, 'https://example.com/image.jpg')
        .to_return(status: 200, body: 'png_bytes', headers: { 'Content-Type' => 'image/png' })

      _data, mime = service.send(:download_and_encode_image, 'https://example.com/image.jpg')
      expect(mime).to eq('image/png')
    end

    it 'converts webp to jpeg' do
      stub_request(:get, 'https://example.com/image.webp')
        .to_return(status: 200, body: 'webp_data', headers: { 'Content-Type' => 'image/webp' })

      allow(service).to receive(:convert_to_jpeg).with('webp_data', 'image/webp').and_return('jpeg_converted')

      _data, mime = service.send(:download_and_encode_image, 'https://example.com/image.webp')
      expect(mime).to eq('image/jpeg')
    end

    it 'returns nil for non-200 response' do
      stub_request(:get, 'https://example.com/missing.jpg').to_return(status: 404)

      expect(service.send(:download_and_encode_image, 'https://example.com/missing.jpg')).to be_nil
    end

    it 'returns nil for non-image content type' do
      stub_request(:get, 'https://example.com/page.html')
        .to_return(status: 200, body: '<html>', headers: { 'Content-Type' => 'text/html' })

      expect(service.send(:download_and_encode_image, 'https://example.com/page.html')).to be_nil
    end

    it 'compresses images over 200KB' do
      large_body = 'x' * (201 * 1024)
      stub_request(:get, 'https://example.com/big.png')
        .to_return(status: 200, body: large_body, headers: { 'Content-Type' => 'image/png' })

      allow(service).to receive(:compress_image_to_limit).and_return('compressed')

      data, mime = service.send(:download_and_encode_image, 'https://example.com/big.png')
      expect(mime).to eq('image/jpeg')
      expect(data).to eq(Base64.strict_encode64('compressed'))
    end

    it 'returns nil if image is over 200KB and compression fails' do
      large_body = 'x' * (201 * 1024)
      stub_request(:get, 'https://example.com/big.png')
        .to_return(status: 200, body: large_body, headers: { 'Content-Type' => 'image/png' })

      allow(service).to receive(:compress_image_to_limit).and_return(nil)

      expect(service.send(:download_and_encode_image, 'https://example.com/big.png')).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # OG data priority in build_rich_link_data
  # ---------------------------------------------------------------------------
  describe 'OG data priority' do
    context 'when frontend sent usable OG data' do
      before do
        set_content_attrs(
          'url' => 'https://www.example.com/product',
          'title' => 'Great Product',
          'image_url' => 'https://example.com/product.jpg'
        )
        stub_request(:get, 'https://example.com/product.jpg')
          .to_return(status: 200, body: 'img', headers: { 'Content-Type' => 'image/jpeg' })
      end

      it 'skips re-scraping entirely' do
        expect_any_instance_of(described_class).not_to receive(:scrape_open_graph_data)
        build_service.perform
      end

      it 'uses the frontend title directly' do
        payload = captured_payload { build_service.perform }
        expect(payload['richLinkData']['title']).to eq('Great Product')
      end
    end

    context 'when frontend title is an error page' do
      before do
        set_content_attrs(
          'url' => 'https://www.chaumet.com/fr_fr/bague-josephine-aigrette-083590',
          'title' => 'Access Denied',
          'image_url' => nil,
          'site_name' => 'Chaumet.com'
        )
      end

      it 'derives title from URL slug + brand' do
        payload = captured_payload { build_service.perform }
        expect(payload['richLinkData']['title']).to include('Chaumet')
        expect(payload['richLinkData']['title']).not_to eq('Access Denied')
      end
    end

    context 'when scrape returns a good result' do
      before do
        set_content_attrs(
          'url' => 'https://www.example.com/product',
          'title' => 'example.com',   # bare domain — not usable
          'image_url' => nil
        )

        allow_any_instance_of(described_class).to receive(:scrape_open_graph_data).and_return(
          success: true,
          title: 'Scraped Product Title',
          image_url: 'https://example.com/scraped.jpg',
          description: 'A great product',
          favicon_url: nil,
          video_url: nil,
          video_mime_type: nil
        )

        stub_request(:get, 'https://example.com/scraped.jpg')
          .to_return(status: 200, body: 'img', headers: { 'Content-Type' => 'image/jpeg' })
      end

      it 'uses scraped title in payload' do
        payload = captured_payload { build_service.perform }
        expect(payload['richLinkData']['title']).to eq('Scraped Product Title')
      end
    end

    context 'when scrape returns a tracking pixel image' do
      before do
        set_content_attrs('url' => 'https://www.darty.com/product', 'title' => 'darty.com', 'image_url' => nil)

        allow_any_instance_of(described_class).to receive(:scrape_open_graph_data).and_return(
          success: true,
          title: 'darty.com',
          image_url: 'https://www.darty.com/akam/13/pixel_xyz?a=tracking',
          description: nil,
          favicon_url: 'https://www.darty.com/favicon.ico',
          video_url: nil,
          video_mime_type: nil
        )

        stub_request(:get, 'https://www.darty.com/favicon.ico')
          .to_return(status: 200, body: 'ico', headers: { 'Content-Type' => 'image/x-icon' })
        allow_any_instance_of(described_class).to receive(:convert_to_jpeg).and_return('jpeg')
      end

      it 'discards tracking pixel and uses favicon instead' do
        payload = captured_payload { build_service.perform }
        # Image asset should be present (from favicon), not the tracking pixel
        image_data = payload.dig('richLinkData', 'assets', 'image', 'data')
        expect(image_data).not_to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # richLinkDataRef mode (App Clips)
  # ---------------------------------------------------------------------------
  describe 'richLinkDataRef mode' do
    let(:rich_link_data_ref) { { 'signature' => 'sig', 'reference' => 'ref123' } }

    before do
      set_content_attrs(
        'url' => 'https://www.example.com/app',
        'rich_link_data_ref' => rich_link_data_ref
      )
      # No OG data — ensures App Clips path is used
    end

    it 'sends richLinkDataRef instead of richLinkData' do
      payload = captured_payload { build_service.perform }
      expect(payload).to have_key('richLinkDataRef')
      expect(payload).not_to have_key('richLinkData')
    end

    it 'applies CaseTransformer to richLinkDataRef keys' do
      set_content_attrs(
        'url' => 'https://www.example.com/app',
        'rich_link_data_ref' => { 'signature_base64' => 'c2ln', 'reference_id' => 'ref', 'cert_chain' => [] }
      )

      payload = captured_payload { build_service.perform }
      ref = payload['richLinkDataRef']
      expect(ref).to have_key('signature-base64')
      expect(ref).to have_key('referenceId')
      expect(ref).to have_key('certChain')
    end

    it 'does not use richLinkDataRef when frontend OG data is usable' do
      set_content_attrs(
        'url' => 'https://www.example.com/app',
        'title' => 'Real Product',
        'image_url' => 'https://example.com/real.jpg',
        'rich_link_data_ref' => rich_link_data_ref
      )

      stub_request(:get, 'https://example.com/real.jpg')
        .to_return(status: 200, body: 'img', headers: { 'Content-Type' => 'image/jpeg' })

      payload = captured_payload { build_service.perform }
      expect(payload).to have_key('richLinkData')
      expect(payload).not_to have_key('richLinkDataRef')
    end
  end

  # ---------------------------------------------------------------------------
  # Payload structure
  # ---------------------------------------------------------------------------
  describe 'payload structure' do
    before { set_content_attrs('url' => 'https://www.example.com', 'title' => 'Example') }

    it 'includes all required Apple MSP fields' do
      payload = captured_payload { build_service.perform }
      expect(payload).to include('id', 'type', 'sourceId', 'destinationId', 'v', 'body')
      expect(payload['type']).to eq('richLink')
      expect(payload['v']).to eq(1)
      expect(payload['sourceId']).to eq(channel.business_id)
      expect(payload['destinationId']).to eq('user123')
    end

    it 'sets body to the URL' do
      payload = captured_payload { build_service.perform }
      expect(payload['body']).to eq('https://www.example.com')
    end

    it 'generates a UUID message ID' do
      payload = captured_payload { build_service.perform }
      expect(payload['id']).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  # ---------------------------------------------------------------------------
  # Authentication headers
  # ---------------------------------------------------------------------------
  describe 'authentication headers' do
    before { set_content_attrs('url' => 'https://www.example.com', 'title' => 'Example') }

    it 'sends JWT Bearer token' do
      headers = nil
      allow(HTTParty).to receive(:post) do |_url, opts|
        headers = opts[:headers]
        double(success?: true, code: 200, body: '{}')
      end
      build_service.perform
      expect(headers['Authorization']).to match(/\ABearer eyJ[A-Za-z0-9\-_.]+\z/)
    end

    it 'includes Source-Id and Destination-Id' do
      headers = nil
      allow(HTTParty).to receive(:post) do |_url, opts|
        headers = opts[:headers]
        double(success?: true, code: 200, body: '{}')
      end
      build_service(destination_id: 'dest_456').perform
      expect(headers['Source-Id']).to eq(channel.business_id)
      expect(headers['Destination-Id']).to eq('dest_456')
    end
  end

  # ---------------------------------------------------------------------------
  # Idempotency & locking
  # ---------------------------------------------------------------------------
  describe 'idempotency' do
    it 'skips send when message already has external_source_id' do
      message.update_column(:external_source_ids, { 'apple_messages' => 'sent_id' })
      result = build_service.perform
      expect(result[:skipped]).to be true
      expect(result[:message_id]).to eq('sent_id')
      expect(HTTParty).not_to have_received(:post)
    end
  end

  describe 'Redis lock' do
    before { set_content_attrs('url' => 'https://www.example.com', 'title' => 'Example') }

    it 'acquires and releases lock around send' do
      expect(Redis::Alfred).to receive(:set).with("amb:send_lock:#{message.id}", '1', ex: 30, nx: true).and_return(true)
      expect(Redis::Alfred).to receive(:delete).with("amb:send_lock:#{message.id}")
      build_service.perform
    end

    it 'returns SEND_IN_PROGRESS when lock cannot be acquired' do
      allow(Redis::Alfred).to receive(:set).and_return(false)
      allow(Redis::Alfred).to receive(:delete)
      result = build_service.perform
      expect(result[:success]).to be false
      expect(result[:error_code]).to eq('SEND_IN_PROGRESS')
    end

    it 'always releases lock even when an exception occurs' do
      allow(Redis::Alfred).to receive(:set).and_return(true)
      allow(Redis::Alfred).to receive(:delete)
      allow_any_instance_of(described_class).to receive(:build_rich_link_data).and_raise(StandardError, 'boom')
      build_service.perform
      expect(Redis::Alfred).to have_received(:delete).with("amb:send_lock:#{message.id}")
    end
  end

  # ---------------------------------------------------------------------------
  # Response handling
  # ---------------------------------------------------------------------------
  describe 'response handling' do
    before { set_content_attrs('url' => 'https://www.example.com', 'title' => 'Example') }

    it 'marks message as sent on success' do
      build_service.perform
      expect(message.reload.external_source_id_apple_messages).to be_present
    end

    it 'stores Apple MSP payload in message' do
      build_service.perform
      expect(message.reload.apple_msp_payload).to be_present
      expect(message.reload.apple_msp_payload.dig('debug', 'status')).to eq('sent')
    end

    it 'returns error and stores failed payload on HTTP error' do
      allow(HTTParty).to receive(:post).and_return(double(success?: false, code: 500, body: 'Internal Server Error'))
      result = build_service.perform
      expect(result[:success]).to be false
      expect(result[:error]).to include('HTTP 500')
      expect(message.reload.apple_msp_payload.dig('debug', 'status')).to eq('failed')
    end

    it 'catches StandardError and returns failure' do
      allow_any_instance_of(described_class).to receive(:build_rich_link_data).and_raise(StandardError, 'Unexpected')
      result = build_service.perform
      expect(result[:success]).to be false
      expect(result[:error]).to include('Unexpected')
    end
  end
end
