# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::OpenGraphParserService, type: :service do
  def parser_for(url)
    described_class.new(url)
  end

  def stub_html(url, body, status: 200, content_type: 'text/html')
    stub_request(:get, url).to_return(
      status: status,
      body: body,
      headers: { 'Content-Type' => content_type }
    )
  end

  # Stub all HEAD requests (favicon_exists? probes) to return 404 by default.
  # Individual tests can override with a more specific stub_request(:head, ...) call.
  def stub_head_requests_as_missing
    stub_request(:head, //).to_return(status: 404)
  end

  def og_html(title: nil, description: nil, image: nil, site_name: nil, page_title: nil, favicon: nil, json_ld: nil)
    parts = []
    parts << "<meta property='og:title' content='#{title}' />" if title
    parts << "<meta property='og:description' content='#{description}' />" if description
    parts << "<meta property='og:image' content='#{image}' />" if image
    parts << "<meta property='og:site_name' content='#{site_name}' />" if site_name
    parts << "<link rel='icon' href='#{favicon}' />" if favicon
    parts << json_ld if json_ld
    <<~HTML
      <html><head>
        <title>#{page_title || title || 'Page'}</title>
        #{parts.join("\n")}
      </head><body></body></html>
    HTML
  end

  # ---------------------------------------------------------------------------
  # Happy path — HTTParty succeeds
  # ---------------------------------------------------------------------------
  describe '#parse' do
    # favicon_exists? probes via HEAD — stub all HEAD requests to 404 by default
    before { stub_head_requests_as_missing }

    context 'with full OG tags' do
      before do
        stub_html(
          'https://example.com/product',
          og_html(
            title: 'Amazing Product',
            description: 'A great description',
            image: 'https://example.com/product.jpg',
            site_name: 'Example Store'
          )
        )
        allow(AppleMessagesForBusiness::PlaywrightScraperClient).to receive(:fetch).and_return(nil)
      end

      it 'returns success with extracted fields' do
        result = parser_for('https://example.com/product').parse
        expect(result[:success]).to be true
        expect(result[:title]).to eq('Amazing Product')
        expect(result[:description]).to eq('A great description')
        expect(result[:image_url]).to eq('https://example.com/product.jpg')
        expect(result[:site_name]).to eq('Example Store')
      end
    end

    context 'when HTTParty returns an error/bot-challenge page (no image, title = domain)' do
      before do
        stub_html('https://www.fnac.com/product', og_html(page_title: 'fnac.com'))
        allow(AppleMessagesForBusiness::PlaywrightScraperClient).to receive(:fetch).and_return(nil)
      end

      it 'marks result as unusable and does not call Playwright if also fails' do
        result = parser_for('https://www.fnac.com/product').parse
        # title equals bare domain — og_result_usable? returns false
        expect(result[:title]).to eq('fnac.com')
      end
    end

    context 'when HTTParty gets a bot-challenge page and Playwright succeeds' do
      before do
        stub_html('https://www.fnac.com/product', og_html(page_title: 'fnac.com'))

        allow(AppleMessagesForBusiness::PlaywrightScraperClient).to receive(:fetch).and_return(
          success: true,
          url: 'https://www.fnac.com/product',
          title: 'Drone DJI Avata 360',
          description: 'Amazing drone',
          image_url: 'https://static.fnac-static.com/drone.jpg',
          favicon_url: 'https://www.fnac.com/favicon.ico',
          site_name: 'Fnac',
          video_url: nil,
          video_mime_type: nil
        )
      end

      it 'falls back to Playwright and returns its data' do
        result = parser_for('https://www.fnac.com/product').parse
        expect(result[:title]).to eq('Drone DJI Avata 360')
        expect(result[:image_url]).to eq('https://static.fnac-static.com/drone.jpg')
      end
    end

    context 'when HTTParty returns "Access Denied" title' do
      before do
        stub_html('https://www.chaumet.com/product', og_html(page_title: 'Access Denied'))
        allow(AppleMessagesForBusiness::PlaywrightScraperClient).to receive(:fetch).and_return(nil)
      end

      it 'triggers Playwright fallback attempt' do
        expect(AppleMessagesForBusiness::PlaywrightScraperClient).to receive(:fetch)
        parser_for('https://www.chaumet.com/product').parse
      end
    end

    context 'when both HTTParty and Playwright fail' do
      before do
        stub_html('https://www.bot-protected.com/product', og_html(page_title: 'Access Denied'))
        allow(AppleMessagesForBusiness::PlaywrightScraperClient).to receive(:fetch).and_return(nil)
      end

      it 'returns the HTTParty result as best available' do
        result = parser_for('https://www.bot-protected.com/product').parse
        expect(result).to be_a(Hash)
        expect(result[:success]).to be true
      end
    end

    context 'with JSON-LD Product schema' do
      let(:json_ld_script) do
        <<~HTML
          <script type="application/ld+json">
            {"@context":"http://schema.org/","@type":"Product","name":"Drone DJI",
             "image":["https://static.fnac-static.com/drone-1.jpg","https://static.fnac-static.com/drone-2.jpg"],
             "description":"Great drone"}
          </script>
        HTML
      end

      before do
        stub_html(
          'https://www.fnac.com/product',
          og_html(page_title: 'Fnac', json_ld: json_ld_script)
        )
        allow(AppleMessagesForBusiness::PlaywrightScraperClient).to receive(:fetch).and_return(nil)
      end

      it 'extracts image from JSON-LD when no og:image is present' do
        result = parser_for('https://www.fnac.com/product').parse
        expect(result[:image_url]).to eq('https://static.fnac-static.com/drone-1.jpg')
      end
    end

    context 'with Apple Maps URL with query parameters' do
      it 'parses place parameters' do
        result = parser_for('https://maps.apple.com/?q=Paris&name=Eiffel+Tower').parse
        expect(result[:title]).to include('Eiffel Tower')
        expect(result[:site_name]).to eq('Apple Maps')
      end

      it 'parses directions URL' do
        result = parser_for('https://maps.apple.com/?source=Paris&destination=Lyon').parse
        expect(result[:title]).to include('Paris')
        expect(result[:title]).to include('Lyon')
      end
    end

    context 'when URL is invalid' do
      it 'returns default_data for non-HTTP scheme' do
        result = parser_for('not-a-url').parse
        expect(result[:success]).to be false
      end

      it 'returns default_data for blank URL' do
        result = parser_for('').parse
        expect(result[:success]).to be false
      end
    end

    context 'when HTTP request raises an error' do
      before do
        stub_request(:get, 'https://example.com/error').to_raise(Net::OpenTimeout)
        allow(AppleMessagesForBusiness::PlaywrightScraperClient).to receive(:fetch).and_return(nil)
      end

      it 'returns default_data without raising' do
        expect { parser_for('https://example.com/error').parse }.not_to raise_error
      end
    end
  end

  # ---------------------------------------------------------------------------
  # og_result_usable?
  # ---------------------------------------------------------------------------
  describe '#og_result_usable?' do
    let(:url) { 'https://www.example.com/product' }
    let(:parser) { parser_for(url) }

    def usable?(result)
      parser.send(:og_result_usable?, result)
    end

    it 'returns false for non-Hash input' do
      expect(usable?(nil)).to be false
    end

    it 'returns false when success is false' do
      expect(usable?({ success: false, title: 'Good', image_url: 'https://x.com/img.jpg' })).to be false
    end

    it 'returns false when title is blank' do
      expect(usable?({ success: true, title: '', image_url: 'https://x.com/img.jpg' })).to be false
    end

    it 'returns false when title matches ERROR_TITLE_PATTERNS' do
      ['Access Denied', '403 Forbidden', 'Checking your browser', 'Just a moment'].each do |bad_title|
        expect(usable?({ success: true, title: bad_title, image_url: 'https://x.com/img.jpg' })).to be false
      end
    end

    it 'returns false when title equals bare domain' do
      expect(usable?({ success: true, title: 'example.com', image_url: 'https://x.com/img.jpg' })).to be false
    end

    it 'returns false when both image_url and description are blank' do
      expect(usable?({ success: true, title: 'Good Title', image_url: nil, description: nil })).to be false
    end

    it 'returns true with real title + image' do
      expect(usable?({ success: true, title: 'Amazing Product', image_url: 'https://x.com/img.jpg' })).to be true
    end

    it 'returns true with real title + description only (no image)' do
      expect(usable?({ success: true, title: 'Amazing Product', image_url: nil, description: 'A description' })).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # Favicon extraction priority
  # ---------------------------------------------------------------------------
  describe 'favicon extraction' do
    before do
      stub_head_requests_as_missing
      allow(AppleMessagesForBusiness::PlaywrightScraperClient).to receive(:fetch).and_return(nil)
    end

    it 'prefers apple-touch-icon over standard icon' do
      html = <<~HTML
        <html><head>
          <link rel="apple-touch-icon" href="/apple-touch-icon.png" />
          <link rel="icon" href="/favicon.ico" />
        </head></html>
      HTML
      stub_html('https://example.com/', html)
      result = parser_for('https://example.com/').parse
      expect(result[:favicon_url]).to include('apple-touch-icon.png')
    end
  end
end
