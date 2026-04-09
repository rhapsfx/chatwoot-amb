# frozen_string_literal: true

require 'nokogiri'
require 'open-uri'
require 'httparty'
require 'cgi'

class AppleMessagesForBusiness::OpenGraphParserService
  def initialize(url)
    @url = normalize_url(url)
  end

  def parse
    return default_data unless valid_url?

    # Special handling for Apple Maps URLs with query parameters
    # Short URLs (maps.apple/p/...) should go through normal OpenGraph parsing
    return parse_apple_maps_url if apple_maps_url_with_params?

    # 1. Try standard HTTParty + Nokogiri scraping (fast, no overhead)
    result = begin
      doc = fetch_document
      extract_open_graph_data(doc)
    rescue StandardError => e
      Rails.logger.error "OpenGraph parsing failed for #{@url}: #{e.message}"
      apple_maps_short_url? ? apple_maps_fallback_data : default_data
    end

    # 2. Use the HTTParty result if it produced a real title (not an error/bot-challenge page)
    #    and at least some content we can work with.
    if og_result_usable?(result)
      Rails.logger.info "✅ OpenGraph - HTTParty scrape usable (title: #{result[:title]&.truncate(60)})"
      return result
    end

    Rails.logger.info "⚠️ OpenGraph - HTTParty result not usable (title: '#{result[:title]}'), trying Playwright stealth scraper..."

    # 3. Fall back to Playwright stealth scraper — bypasses bot-detection (Akamai, Cloudflare, etc.)
    #    Only reached when HTTParty returned an error page or no meaningful content.
    playwright_data = AppleMessagesForBusiness::PlaywrightScraperClient.fetch(@url)
    if playwright_data && og_result_usable?(build_result_from_playwright(playwright_data))
      @final_url = playwright_data[:url].presence || @url
      Rails.logger.info "✅ OpenGraph - Playwright scrape succeeded (title: #{playwright_data[:title]&.truncate(60)})"
      return build_result_from_playwright(playwright_data)
    end

    Rails.logger.warn '⚠️ OpenGraph - Playwright also failed or unavailable, returning best available result'

    # Return whatever HTTParty gave us (even if partial) — caller handles further fallbacks
    result
  end

  private

  # Returns true when an OG scrape result is worth using — has a real title
  # (not a bot-challenge/error page) with at least an image or description.
  ERROR_TITLE_PATTERNS = /\b(access denied|403 forbidden|404|not found|forbidden|blocked|error|robot|captcha|checking your browser|just a moment|ddos|cloudflare|please wait)\b/i

  def og_result_usable?(result)
    return false unless result.is_a?(Hash) && result[:success]

    title = result[:title].to_s.strip
    return false if title.blank?
    return false if ERROR_TITLE_PATTERNS.match?(title)

    # Title must not be just the bare domain
    begin
      host = URI.parse(@url).host.to_s.downcase.delete_prefix('www.')
      return false if title.downcase == host
    rescue URI::InvalidURIError
      nil
    end

    # Must have at least an image or a description to be worth sending
    image = result[:image_url].to_s.strip
    desc  = result[:description].to_s.strip

    image.present? || desc.present?
  end

  # Build the standard result hash from Playwright scraper response.
  # Resolves relative favicon/image URLs to absolute using the final page URL.
  def build_result_from_playwright(data)
    {
      success: true,
      title: data[:title],
      description: data[:description],
      image_url: make_absolute_url(data[:image_url]),
      video_url: make_absolute_url(data[:video_url]),
      video_mime_type: data[:video_mime_type],
      favicon_url: make_absolute_url(data[:favicon_url]),
      url: data[:url].presence || @url,
      site_name: data[:site_name] || extract_domain_name
    }
  end

  # Check if URL is an Apple Maps URL with query parameters (needs special handling)
  def apple_maps_url_with_params?
    # Only use parameter extraction for URLs with actual location parameters (name, address, coordinate)
    # Place ID URLs should go through normal Open Graph HTML scraping to extract og:title and og:image
    return false if @url.include?('place-id=')

    (@url.include?('maps.apple.com') || @url.include?('maps.apple')) && @url.include?('?')
  end

  # Check if URL is an Apple Maps short URL
  def apple_maps_short_url?
    @url.match?(%r{maps\.apple(?:\.com)?/p/})
  end

  # Fallback data for Apple Maps short URLs
  def apple_maps_fallback_data
    {
      success: true,
      title: 'Apple Maps Location',
      description: 'View this location in Apple Maps',
      image_url: nil,
      favicon_url: 'https://logo.clearbit.com/apple.com',
      url: @url,
      site_name: 'Apple Maps'
    }
  end

  # Parse Apple Maps URL and extract location information
  def parse_apple_maps_url
    # Encode non-ASCII characters for URI parsing
    encoded_url = @url.encode('UTF-8').gsub(/[^\x00-\x7F]/) { |char| CGI.escape(char) }
    uri = URI.parse(encoded_url)
    params = URI.decode_www_form(uri.query || '').to_h

    # Check if this is a directions URL
    return parse_directions_url(params) if params['source'].present? || params['destination'].present?

    # Extract place information from URL parameters
    place_name = params['name'] || params['q'] || 'Location'
    address = params['address'] || ''
    coordinate = params['coordinate']&.split(',')

    # Build descriptive title and description
    title = place_name
    description_parts = []
    description_parts << address if address.present?
    description_parts << "Coordinates: #{coordinate.join(', ')}" if coordinate

    {
      success: true,
      title: title,
      description: description_parts.join("\n"),
      image_url: apple_maps_preview_image(coordinate),
      favicon_url: 'https://logo.clearbit.com/apple.com',
      url: @url,
      site_name: 'Apple Maps'
    }
  rescue StandardError => e
    Rails.logger.error "Apple Maps URL parsing failed for #{@url}: #{e.message}"
    {
      success: true,
      title: 'Apple Maps Location',
      description: 'View location in Apple Maps',
      image_url: nil,
      favicon_url: 'https://logo.clearbit.com/apple.com',
      url: @url,
      site_name: 'Apple Maps'
    }
  end

  # Parse Apple Maps directions URL
  def parse_directions_url(params)
    source = params['source'] || 'Current Location'
    destination = params['destination'] || 'Destination'
    mode = params['mode']&.capitalize || 'Driving'

    # Build descriptive title and description
    title = "Directions: #{source} → #{destination}"
    description = "Get #{mode.downcase} directions from #{source} to #{destination}"

    {
      success: true,
      title: title,
      description: description,
      image_url: 'https://maps.apple.com/static/maps-app-web-client/images/maps-app-icon-180x180.png',
      favicon_url: 'https://maps.apple.com/static/maps-app-web-client/images/maps-app-icon-180x180.png',
      url: @url,
      site_name: 'Apple Maps'
    }
  rescue StandardError => e
    Rails.logger.error "Apple Maps directions URL parsing failed for #{@url}: #{e.message}"
    {
      success: true,
      title: 'Apple Maps Directions',
      description: 'Get directions in Apple Maps',
      image_url: 'https://maps.apple.com/static/maps-app-web-client/images/maps-app-icon-180x180.png',
      favicon_url: 'https://maps.apple.com/static/maps-app-web-client/images/maps-app-icon-180x180.png',
      url: @url,
      site_name: 'Apple Maps'
    }
  end

  # Generate a static map preview image for Apple Maps
  def apple_maps_preview_image(_coordinate)
    # Return nil for now - could integrate with MapKit or another mapping service
    # For now, Apple Maps rich links will use the Apple favicon
    nil
  end

  # Normalize URL by adding protocol if missing
  def normalize_url(url)
    return url if url.blank?

    # Already has protocol
    return url if url.match?(%r{\Ahttps?://})

    # Add https:// for www. and domain.tld patterns
    if url.match?(/\A(www\.|[a-zA-Z0-9-]+\.[a-zA-Z]{2,})/)
      "https://#{url}"
    else
      url
    end
  end

  def valid_url?
    @url.present? && @url.match?(%r{\Ahttps?://})
  end

  def fetch_document
    # Use Safari User Agent to avoid blocking
    headers = {
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Safari/605.1.15'
    }

    # Use HTTParty to follow redirects and capture final URL
    response = HTTParty.get(@url, headers: headers, follow_redirects: true, timeout: 15)

    # Capture the final URL after following redirects
    # This is important for Apple Maps short URLs that redirect to full URLs
    if response.request.respond_to?(:uri)
      @final_url = response.request.uri.to_s
      Rails.logger.info "🔍 OpenGraph - URL redirected from #{@url} to #{@final_url}" if @final_url != @url
    end

    Nokogiri::HTML(response.body)
  end

  def extract_open_graph_data(doc)
    {
      success: true,
      title: extract_title(doc),
      description: extract_description(doc),
      image_url: extract_image_url(doc),
      video_url: extract_video_url(doc),
      video_mime_type: extract_video_mime_type(doc),
      favicon_url: extract_favicon_url(doc),
      url: @final_url || @url, # Use final URL after redirects if available, fallback to original
      site_name: extract_site_name(doc)
    }
  end

  def extract_title(doc)
    # Try OpenGraph title first
    og_title = doc.at_css('meta[property="og:title"]')&.[]('content')
    return og_title if og_title.present?

    # Fallback to page title
    page_title = doc.at_css('title')&.text
    return page_title if page_title.present?

    # Try JSON-LD structured data
    doc.css('script[type="application/ld+json"]').each do |script|
      json = JSON.parse(script.text.strip)
      schemas = json.is_a?(Array) ? json : [json]
      schemas.each do |schema|
        next unless schema.is_a?(Hash)

        nodes = schema['@graph'].is_a?(Array) ? schema['@graph'] : [schema]
        nodes.each do |node|
          title = node['name'] || node['headline']
          return title if title.is_a?(String) && title.present?
        end
      end
    rescue JSON::ParserError, StandardError
      next
    end

    # Final fallback to domain name
    extract_domain_name
  end

  def extract_description(doc)
    # Try OpenGraph description
    og_desc = doc.at_css('meta[property="og:description"]')&.[]('content')
    return og_desc if og_desc.present?

    # Fallback to meta description
    meta_desc = doc.at_css('meta[name="description"]')&.[]('content')
    return meta_desc if meta_desc.present?

    nil
  end

  def extract_image_url(doc)
    # Try OpenGraph image first
    og_image = doc.at_css('meta[property="og:image"]')&.[]('content')
    return make_absolute_url(og_image) if og_image.present?

    # Try Twitter Card image
    twitter_image = doc.at_css('meta[name="twitter:image"]')&.[]('content')
    return make_absolute_url(twitter_image) if twitter_image.present?

    # Try JSON-LD structured data (Product, ItemPage, etc.)
    # Many e-commerce sites embed this even when OG tags are blocked
    schema_image = extract_schema_image(doc)
    return schema_image if schema_image.present?

    # Try to find the largest image on the page
    images = doc.css('img[src]')
    largest_image = images.max_by do |img|
      width = img['width']&.to_i || 0
      height = img['height']&.to_i || 0
      width * height
    end

    return make_absolute_url(largest_image['src']) if largest_image

    nil
  end

  # Extract image from JSON-LD structured data (Schema.org)
  # Handles Product, ItemPage, WebPage, Article, etc.
  def extract_schema_image(doc)
    scripts = doc.css('script[type="application/ld+json"]')
    Rails.logger.info "🔍 Schema - Found #{scripts.length} JSON-LD scripts"

    scripts.each do |script|
      json = JSON.parse(script.text.strip)
      schemas = json.is_a?(Array) ? json : [json]

      schemas.each do |schema|
        type = schema.is_a?(Hash) ? (schema['@type'] || schema.dig('@graph', 0, '@type')) : nil
        Rails.logger.info "🔍 Schema - Processing schema type: #{type}"
        image = extract_image_from_schema(schema)
        if image.present?
          Rails.logger.info "✅ Schema - Found image: #{image.truncate(100)}"
          return make_absolute_url(image)
        end
      end
    rescue JSON::ParserError, StandardError => e
      Rails.logger.warn "⚠️ Schema - Failed to parse JSON-LD: #{e.message}"
      next
    end

    Rails.logger.info '⚠️ Schema - No image found in JSON-LD'
    nil
  end

  def extract_image_from_schema(schema)
    return nil unless schema.is_a?(Hash)

    # Unwrap @graph array (common pattern)
    if schema['@graph'].is_a?(Array)
      schema['@graph'].each do |node|
        image = extract_image_from_schema(node)
        return image if image.present?
      end
      return nil
    end

    # Extract image from this schema node
    raw = schema['image']
    image = case raw
            when String then raw
            when Hash   then raw['url'] || raw['contentUrl']
            when Array
              first = raw.first
              first.is_a?(String) ? first : first&.dig('url') || first&.dig('contentUrl')
            end

    image.presence
  end

  def extract_video_url(doc)
    # Try OpenGraph video
    og_video = doc.at_css('meta[property="og:video"]')&.[]('content') ||
               doc.at_css('meta[property="og:video:url"]')&.[]('content') ||
               doc.at_css('meta[property="og:video:secure_url"]')&.[]('content')
    return make_absolute_url(og_video) if og_video.present?

    # Try Twitter Card video
    twitter_video = doc.at_css('meta[name="twitter:player:stream"]')&.[]('content')
    return make_absolute_url(twitter_video) if twitter_video.present?

    nil
  end

  def extract_video_mime_type(doc)
    # Try OpenGraph video type
    og_video_type = doc.at_css('meta[property="og:video:type"]')&.[]('content')
    return og_video_type if og_video_type.present?

    nil
  end

  # Extract favicon URL from various possible sources
  def extract_favicon_url(doc)
    # Try different favicon link rel attributes in order of preference
    favicon_selectors = [
      'link[rel="apple-touch-icon"]',           # High-res Apple touch icon
      'link[rel="apple-touch-icon-precomposed"]', # Precomposed Apple icon
      'link[rel="icon"][sizes]',                # Sized favicon (usually higher quality)
      'link[rel="shortcut icon"]',              # Traditional shortcut icon
      'link[rel="icon"]'                        # Standard icon
    ]

    favicon_selectors.each do |selector|
      favicon_link = doc.at_css(selector)
      if favicon_link&.[]('href')
        favicon_url = make_absolute_url(favicon_link['href'])
        return favicon_url if favicon_url.present?
      end
    end

    # Final fallback: standard /favicon.ico path
    uri = URI.parse(@url)
    standard_favicon = "#{uri.scheme}://#{uri.host}/favicon.ico"

    # Verify the standard favicon exists by checking if it's accessible
    return standard_favicon if favicon_exists?(standard_favicon)

    nil
  rescue URI::InvalidURIError
    nil
  end

  # Check if a favicon URL is accessible
  def favicon_exists?(favicon_url)
    response = HTTParty.head(
      favicon_url,
      timeout: 5,
      headers: {
        'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Safari/605.1.15'
      }
    )

    response.success? && response.headers['content-type']&.start_with?('image/')
  rescue StandardError
    false
  end

  def extract_site_name(doc)
    # Try OpenGraph site name
    og_site = doc.at_css('meta[property="og:site_name"]')&.[]('content')
    return og_site if og_site.present?

    # Fallback to domain name
    extract_domain_name
  end

  def make_absolute_url(url)
    return url if url.blank? || url.start_with?('http')

    # Use final URL after redirects for base URL, fallback to original
    base = @final_url || @url
    uri = URI.parse(base)
    base_url = "#{uri.scheme}://#{uri.host}"
    base_url += ":#{uri.port}" if uri.port != 80 && uri.port != 443

    if url.start_with?('//')
      "#{uri.scheme}:#{url}"
    elsif url.start_with?('/')
      "#{base_url}#{url}"
    else
      "#{base_url}/#{url}"
    end
  rescue URI::InvalidURIError
    url
  end

  def extract_domain_name
    # Use final URL after redirects for domain extraction, fallback to original
    base = @final_url || @url
    uri = URI.parse(base)
    uri.host&.gsub('www.', '')&.capitalize
  rescue URI::InvalidURIError
    'Website'
  end

  def default_data
    # Try to get a favicon even when page access fails
    default_favicon = try_default_favicon

    {
      success: false,
      title: extract_domain_name || 'Rich Link',
      description: nil,
      image_url: default_favicon,
      favicon_url: default_favicon,
      url: @url,
      site_name: extract_domain_name
    }
  end

  # Attempt to get favicon when page parsing fails
  def try_default_favicon
    # Use final URL if available, fallback to original
    base = @final_url || @url
    return nil if base.blank?

    begin
      uri = URI.parse(base)

      # Check for well-known domain favicon mappings first
      known_favicon = get_known_domain_favicon(uri.host)
      return known_favicon if known_favicon

      # Try common favicon paths in order of preference
      favicon_paths = [
        '/apple-touch-icon.png',           # High-quality Apple touch icon
        '/apple-touch-icon-180x180.png',   # Specific size Apple icon
        '/favicon-32x32.png',              # High-quality favicon
        '/favicon-16x16.png',              # Standard favicon
        '/favicon.ico'                     # Classic favicon
      ]

      favicon_paths.each do |path|
        favicon_url = "#{uri.scheme}://#{uri.host}#{path}"
        return favicon_url if favicon_exists?(favicon_url)
      end

      nil
    rescue URI::InvalidURIError
      nil
    end
  end

  # Get favicon for well-known domains that might block requests
  def get_known_domain_favicon(host)
    # Remove www. prefix for matching
    domain = host&.gsub('www.', '')&.downcase

    # Map of domains to their reliable favicon URLs
    # Using embedded base64 images for domains that block external requests
    domain_favicons = {
      'google.com' => get_embedded_google_icon,
      'rcsforbusiness.google' => get_embedded_google_icon,
      'github.com' => 'https://logo.clearbit.com/github.com',
      'apple.com' => 'https://logo.clearbit.com/apple.com',
      'facebook.com' => 'https://logo.clearbit.com/facebook.com',
      'instagram.com' => 'https://logo.clearbit.com/instagram.com',
      'twitter.com' => 'https://logo.clearbit.com/twitter.com',
      'x.com' => 'https://logo.clearbit.com/twitter.com',
      'linkedin.com' => 'https://logo.clearbit.com/linkedin.com',
      'youtube.com' => 'https://logo.clearbit.com/youtube.com'
    }

    # Return the mapped favicon URL if domain is known
    domain_favicons[domain]
  end

  # Embedded Google icon as base64 to avoid blocking issues
  def get_embedded_google_icon
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAAdgAAAHYBTnsmCAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAOKSURBVFiFpZdNbBNnEIafsb3+ie04cWLHJCE/pKQNbUPTpqRKQVWFVOjRUlVt6aUqvfTQaq/tpb32VHGBKlpxgfPaE5e2HCBfQEqhTVqlIdAkJARnJ/7F39/OzHdw0tCENtDPjGb2nd3nmfddhZQSf+dQABNAFIgDAeBUvV6f3O12QwghBAARQgAEEIACoLy/DqClpSUIvAvstG3bSKVSXL58GddccaPRaLz1ygJGowGAoiiIogh6vZ6qqio8Hg8cx1Eulys7Ozv30+n0q7OzswOAkX8iYH9/f7DZbPLRRx8lJiYmKBaLNBqNOXlBBBGxLIs7duxwOzo6/AMDA8f6+voGgC+B2FsFBEH4UNO0Y4cOHSKdThMMBoNOp5N/eY9bCaF+LpcDXVe5fPmy6PcLB/v7+08Cn5VKJf1VBbq6unqLxeLnTqfzlNvtbjMMQ79TIymlIKaJGQqhFgrYu3cjC4VC6sKlixcCgcDHwCfPFIjH4xHTNE/c6oTT6dzYyskoaP8Utra2IqRkZGSEQABkpcK5cxdObty4cbq3t3fm/wLRaDQE3Gp/MBjMaZpm/xOB3a0SHnf/fhXhcLhkWdZfCUSj0TfK5XIun8/ns9lsVtOy+Hw+ysjVq1fZ2NjIDxkZBweHh+Hs2bNYlnUsHAof/GbSpBCCcDhcamtrE4ODg8+oVqtDNE1TLpfL1Wo1H43Gg0KI8fHx8pdfLxQKhQJer9fW6/VnysrKWLBgwePLly/LdDrdnE4nbzJJPTvnz5/Htm373NzcHIoQAs/HM7z++uv4fD40TfOqqqoKIYQihEAIQT6f5+bNm5RKJSzLQgjBnDlzaG9vZ/LkyXXXdR0hBFJKJiYmSCQSZDIZGo0GACmlKrq6upgxY4aUUuJyubAsC5fLxaxZs5BSNg8GbGdn50HTNLl69SqiKBIOh8nlcgB/nAyEEAQCAa5cucLy5ctZtXoVo6OjTW/vu+8+Ll269M9PBgjBsmXLpJQyz549fP/9zN70vn37mDp1aiQcDtu9vb3YjgMiAiJAkydPFrquS5fLJSORCHPnzsXn8/H48ROsW7fOiV20hAaOb4yOjjI8PIy79i62baOqKpZlIYRgamtrSdd1KaVE13VaW1uJRCIMDw1z9OjR7FtvvfXMGWjtCNfX1z18dOjInKamJhRFwXVdFEVBVVWy2Szj4+PPPAjAayAXQaZhGPrExMT9Usp5wLxnu5ckVykTrQI6oAFaAAi8+AWmAdOAmbXarv8APaUEUEJjywgAAAAASUVORK5CYII='
  end

  # Add favicon support for additional common services
  def get_service_favicon(domain)
    case domain
    when 'slack.com'
      'https://logo.clearbit.com/slack.com'
    when 'notion.so'
      'https://logo.clearbit.com/notion.so'
    when 'zoom.us'
      'https://logo.clearbit.com/zoom.us'
    when 'microsoft.com'
      'https://logo.clearbit.com/microsoft.com'
    when 'dropbox.com'
      'https://logo.clearbit.com/dropbox.com'
    end
  end
end
