# frozen_string_literal: true

require 'base64'
require_relative 'log_sanitizer'

class AppleMessagesForBusiness::SendRichLinkService
  include AppleMessagesForBusiness::Concerns::Utf8Logging

  AMB_SERVER = 'https://mspgw.push.apple.com/v1'

  def initialize(channel:, destination_id:, message:)
    @channel = channel
    @destination_id = destination_id
    @message = message
  end

  def perform
    # Idempotency guard: prevent duplicate sends of the same message
    return idempotency_response if already_sent?

    # Acquire lock to prevent concurrent sends
    lock_key = "amb:send_lock:#{@message.id}"
    lock_acquired = Redis::Alfred.set(lock_key, '1', ex: 30, nx: true)

    unless lock_acquired
      Rails.logger.warn "[AMB RichLink] Message #{@message.id} is already being sent (lock exists)"
      return { success: false, error: 'Message send already in progress', error_code: 'SEND_IN_PROGRESS' }
    end

    begin
      message_id = SecureRandom.uuid

      rich_link_data = build_rich_link_data

      payload = {
        id: message_id,
        type: 'richLink',
        sourceId: @channel.business_id,
        destinationId: @destination_id,
        v: 1,
        body: rich_link_data[:url]
      }

      # Add EITHER richLinkData OR richLinkDataRef (not both)
      # richLinkDataRef takes precedence (App Clips mode)
      if rich_link_data[:richLinkDataRef].present?
        payload[:richLinkDataRef] = rich_link_data[:richLinkDataRef]
        log_info '🔍 Rich Link - Using richLinkDataRef (App Clips)'
        log_info "🔍 Rich Link - richLinkDataRef keys: #{rich_link_data[:richLinkDataRef].keys.join(', ')}"
      else
        payload[:richLinkData] = rich_link_data
        # Log sanitized payload (truncate base64 data)
        sanitized_data = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(rich_link_data)
        log_info '🔍 Rich Link - Using manual richLinkData'
        log_info "🔍 Rich Link - Final payload richLinkData: #{sanitized_data.to_json}"
        log_info "🔍 Rich Link - Has image asset: #{rich_link_data[:assets]&.key?(:image)}"
        if rich_link_data[:assets]&.key?(:image)
          Rails.logger.info "🔍 Rich Link - Image data length: #{rich_link_data[:assets][:image][:data]&.length} chars"
          Rails.logger.info "🔍 Rich Link - Image mime type: #{rich_link_data[:assets][:image][:mimeType]}"
        end
      end

      response = send_to_apple_gateway(payload, message_id)

      if response.success?
        # Store the payload that was sent to Apple MSP for debugging
        store_apple_msp_payload(payload, 'sent', message_id)
        # Mark as sent if successful
        mark_as_sent
        { success: true, message_id: message_id }
      else
        # Store the failed payload for debugging
        store_apple_msp_payload(payload, 'failed', message_id, "HTTP #{response.code}: #{response.body}")
        { success: false, error: "HTTP #{response.code}: #{response.body}" }
      end
    ensure
      # Always release the lock
      Redis::Alfred.delete(lock_key)
    end
  rescue StandardError => e
    Rails.logger.error "Rich link send failed: #{e.message}"
    { success: false, error: e.message }
  end

  def already_sent?
    # Check if message has already been successfully sent to Apple MSP
    @message.external_source_id_apple_messages.present?
  end

  def mark_as_sent
    # Mark message as sent by setting external_source_id_apple_messages
    return if @message.external_source_id_apple_messages.present?

    @message.update_column(:external_source_ids,
                           @message.external_source_ids.merge('apple_messages' => SecureRandom.uuid))
  end

  def store_apple_msp_payload(payload, status, message_id, error = nil)
    # Store the actual payload sent to Apple MSP Gateway for debugging
    # This allows agents to see exactly what was sent via the info (i) button
    apple_msp_payload = {
      payload: sanitize_payload_for_storage(payload),
      debug: {
        status: status,
        message_id: message_id,
        timestamp: Time.current.iso8601,
        msp_gateway: AMB_SERVER
      }
    }

    # Add error details if present
    apple_msp_payload[:debug][:error] = error if error.present?

    # Store in database
    @message.update_column(:apple_msp_payload, apple_msp_payload)

    Rails.logger.info "✅ Rich Link - Stored Apple MSP payload (status: #{status})"
  end

  def sanitize_payload_for_storage(payload)
    # Create a deep copy to avoid modifying the original
    sanitized = payload.deep_dup

    # Truncate base64 image data for storage (keep first/last 100 chars for verification)
    if sanitized[:richLinkData]&.dig(:assets, :image, :data)
      image_data = sanitized[:richLinkData][:assets][:image][:data]
      if image_data.length > 200
        sanitized[:richLinkData][:assets][:image][:data] = "#{image_data[0...100]}...#{image_data[-100..]}"
        sanitized[:richLinkData][:assets][:image][:_truncated] = true
        sanitized[:richLinkData][:assets][:image][:_original_length] = image_data.length
      end
    end

    sanitized
  end

  def idempotency_response
    Rails.logger.info "[AMB RichLink] Message #{@message.id} already sent (external_source_id: #{@message.external_source_id_apple_messages}), skipping"
    { success: true, message_id: @message.external_source_id_apple_messages, skipped: true }
  end

  private

  def build_rich_link_data
    content_attrs = @message.content_attributes
    url = content_attrs['url'] || @message.content

    # Only re-scrape if the frontend didn't already send usable OG data.
    # Sites with bot-protection (Akamai, Cloudflare) may return a tracking pixel or
    # a generic page on the second request, overwriting good data from the first scrape.
    og_data = { success: false }

    if frontend_og_data_usable?(content_attrs, url)
      Rails.logger.info '✅ Rich Link - Frontend already has good OG data, skipping re-scrape'
    else
      Rails.logger.info "🔍 Rich Link - Attempting Open Graph scraping for: #{url}"
      og_data = scrape_open_graph_data(url)

      # Treat error pages as scrape failures
      if og_data[:success] && error_page_title?(og_data[:title])
        Rails.logger.warn "⚠️ Rich Link - Scrape returned error page: '#{og_data[:title]}', treating as failure"
        og_data = { success: false }
      end

      if og_data[:success]
        Rails.logger.info "✅ Rich Link - Scraped title: #{og_data[:title]}, image: #{og_data[:image_url]}"

        # Don't overwrite with tracking pixels — keep frontend value if scraped one is junk
        scraped_image = og_data[:image_url]
        scraped_image = nil if scraped_image&.match?(%r{/akam/|/pixel_|/beacon\.|1x1|tracking})

        # Prefer the higher-quality favicon: keep frontend PNG over scraped .ico
        existing_favicon = content_attrs['favicon_url'].to_s
        scraped_favicon_url = og_data[:favicon_url].to_s
        scraped_favicon = if existing_favicon.match?(/\.(png|jpg|jpeg|webp|svg)/i) && scraped_favicon_url.match?(/\.ico$/i)
                            existing_favicon
                          else
                            scraped_favicon_url.presence || existing_favicon
                          end

        updates = {
          'title' => og_data[:title] || content_attrs['title'],
          'image_url' => scraped_image || content_attrs['image_url'],
          'image_data' => og_data[:image_data].presence,
          'image_mime_type' => og_data[:image_mime_type].presence,
          'favicon_url' => scraped_favicon,
          'video_url' => og_data[:video_url] || content_attrs['video_url'],
          'video_mime_type' => og_data[:video_mime_type] || content_attrs['video_mime_type'],
          'description' => og_data[:description] || content_attrs['description']
        }.compact

        @message.content_attributes = content_attrs.merge(updates)

        begin
          @message.save!

          if @message.previous_changes.blank?
            Rails.configuration.dispatcher.dispatch(
              'MESSAGE_UPDATED',
              Time.zone.now,
              message: @message.reload,
              performed_by: nil
            )
          end
        rescue StandardError => e
          Rails.logger.error "❌ Rich Link - Failed to save scraped data: #{e.message}"
        end

        content_attrs = @message.content_attributes
      else
        Rails.logger.warn "⚠️ Rich Link - Open Graph scraping failed: #{og_data[:error]}"
      end
    end

    # Use richLinkDataRef (App Clips) only when we have no usable OG data at all
    if content_attrs['rich_link_data_ref'].present? && !frontend_og_data_usable?(content_attrs, url) && !og_data[:success]
      log_info '🔍 Rich Link - Using richLinkDataRef (App Clips mode, no usable OG data)'
      return build_from_rich_link_data_ref(content_attrs)
    end

    # Build embedded richLinkData with assets (title/description/image inline)
    log_info '🔍 Rich Link - Building manual richLinkData with assets'
    url = content_attrs['url'] || @message.content

    # Auto-detect direct video URLs (URLs ending with video extensions)
    # If the primary URL is a video, use it as both the URL and video asset
    if direct_video_url?(url)
      Rails.logger.info "🔍 Rich Link - Direct video URL detected: #{url}"
      content_attrs['video_url'] = url unless content_attrs['video_url'].present?
    end

    # When title is just the domain, an error page title, or blank — derive from URL slug + brand
    title = content_attrs['title'].to_s.strip
    begin
      host = URI.parse(url).host.to_s.downcase.delete_prefix('www.')
      title = extract_title_from_url(url, content_attrs['site_name']) if title.blank? || title.downcase == host || error_page_title?(title)
    rescue URI::InvalidURIError
      title = extract_title_from_url(url, content_attrs['site_name']) if title.blank? || error_page_title?(title)
    end

    {
      url: url,
      title: title,
      assets: build_assets(content_attrs)
    }
  end

  # Build rich link data from richLinkDataRef (App Clips)
  # richLinkDataRef is stored in snake_case in database
  # Must be converted to camelCase for Apple MSP
  def build_from_rich_link_data_ref(content_attrs)
    rich_link_data_ref = content_attrs['rich_link_data_ref']
    url = content_attrs['url']

    # Transform to Apple format (snake_case → camelCase)
    apple_format_ref = AppleMessagesForBusiness::CaseTransformer.to_apple_format(rich_link_data_ref)

    log_info "🔍 Rich Link - richLinkDataRef keys: #{apple_format_ref.keys.join(', ')}"
    log_info "🔍 Rich Link - URL: #{url}"

    {
      url: url,
      richLinkDataRef: apple_format_ref
    }
  end

  def build_assets(content_attrs)
    assets = {}

    Rails.logger.info "🔍 Rich Link - build_assets image_data=#{content_attrs['image_data']&.truncate(80)} image_url=#{content_attrs['image_url']&.truncate(80)} favicon_url=#{content_attrs['favicon_url']&.truncate(80)}"

    # Build prioritized candidate list. Google favicon is always last resort.
    begin
      domain = URI.parse(content_attrs['url'] || '').host.to_s.delete_prefix('www.')
      google_favicon = domain.present? ? "https://www.google.com/s2/favicons?domain=#{domain}&sz=128" : nil
    rescue URI::InvalidURIError
      google_favicon = nil
    end

    # Upgrade favicon to highest-res available (apple-touch-icon → Google 128px).
    # favicon.ico is 16–32px and looks pixelated when used as the rich link image.
    raw_favicon = content_attrs['favicon_url']
    best_favicon = raw_favicon.present? ? fetch_best_domain_icon(raw_favicon) : google_favicon

    candidate_sources = [
      content_attrs['image_data'],
      content_attrs['image_url'],
      best_favicon,
      google_favicon
    ].compact.uniq.reject { |s| s.match?(%r{/akam/|/pixel_|/beacon\.|1x1|tracking|data:image/gif}) }

    # Try candidates in order; stop at first success.
    # This ensures CDN-protected images (e.g. booking.com) fall through to favicon/google icon.
    candidate_sources.each_with_index do |source, idx|
      Rails.logger.info "🔍 Rich Link - Trying candidate #{idx + 1}/#{candidate_sources.size}: #{source.truncate(100)}"

      encoded_image = nil
      actual_mime_type = nil

      if source.start_with?('http')
        result = download_and_encode_image(source)
        next unless result

        encoded_image, actual_mime_type = result
      elsif source.start_with?('data:image')
        encoded_image = source.split(',')[1]
        actual_mime_type = begin
          source.match(/data:([^;]+)/)[1]
        rescue StandardError
          'image/jpeg'
        end
      else
        encoded_image = source
        actual_mime_type = content_attrs['image_mime_type'] || 'image/jpeg'
      end

      next if encoded_image.blank?

      assets[:image] = { data: encoded_image, mimeType: actual_mime_type }
      Rails.logger.info "✅ Rich Link - Image asset set from candidate #{idx + 1}"
      break
    end

    Rails.logger.warn '⚠️ Rich Link - No image asset could be built' if assets.empty?

    # Add video asset if provided
    if content_attrs['video_url'].present?
      Rails.logger.info "🔍 Rich Link - Adding video asset: #{content_attrs['video_url']}"
      assets[:video] = {
        url: content_attrs['video_url'],
        mimeType: content_attrs['video_mime_type'] || detect_video_mime_type(content_attrs['video_url'])
      }
      Rails.logger.info "✅ Rich Link - Video asset added with mimeType: #{assets[:video][:mimeType]}"
    end

    assets
  end

  def scrape_open_graph_data(url)
    return { success: false, error: 'No URL provided' } if url.blank?

    Rails.logger.info "🔍 Rich Link - Scraping Open Graph data for: #{url}"

    parser = AppleMessagesForBusiness::OpenGraphParserService.new(url)
    result = parser.parse

    Rails.logger.info "🔍 Rich Link - Scraping result success: #{result[:success]}"

    result
  rescue StandardError => e
    Rails.logger.error "❌ Rich Link - Open Graph parsing error: #{e.message}"
    Rails.logger.error "❌ Rich Link - Backtrace: #{e.backtrace.first(3).join("\n")}"
    { success: false, error: e.message }
  end

  def detect_image_mime_type(image_url, content_attrs)
    # Use provided mime type if available
    return content_attrs['image_mime_type'] if content_attrs['image_mime_type'].present?

    # Detect from URL extension or source
    case image_url
    when /\.png$/i
      'image/png'
    when /\.gif$/i
      'image/gif'
    when /\.webp$/i
      'image/webp'
    when /\.svg$/i
      'image/svg+xml'
    when /favicon\.ico$/i
      'image/x-icon'
    else
      'image/jpeg'
    end
  end

  def detect_video_mime_type(video_url)
    # Detect from URL extension
    case video_url
    when /\.mp4$/i
      'video/mp4'
    when /\.mov$/i
      'video/quicktime'
    when /\.m4v$/i
      'video/x-m4v'
    when /\.avi$/i
      'video/x-msvideo'
    when /\.wmv$/i
      'video/x-ms-wmv'
    when /\.flv$/i
      'video/x-flv'
    when /\.webm$/i
      'video/webm'
    when /\.mkv$/i
      'video/x-matroska'
    when /\.3gp$/i
      'video/3gpp'
    else
      'video/mp4' # Default to mp4
    end
  end

  # Apple MSP only supports image/jpeg and image/png for richLinkData assets.
  APPLE_SUPPORTED_IMAGE_TYPES = %w[image/jpeg image/png].freeze
  # Apple spec: image binary size must be 200KB or smaller
  APPLE_IMAGE_SIZE_LIMIT = 200.kilobytes

  # Returns [base64_string, mime_type] or nil on failure
  def download_and_encode_image(image_url)
    return nil if image_url.blank?

    Rails.logger.info "🔍 Rich Link - Starting download for: #{image_url}"

    headers = {
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Safari/605.1.15',
      'Accept' => 'image/jpeg,image/png,image/*,*/*;q=0.8',
      'Accept-Language' => 'en-US,en;q=0.9',
      'Cache-Control' => 'no-cache'
    }

    response = HTTParty.get(
      image_url,
      timeout: 15,
      headers: headers,
      follow_redirects: true
    )

    log_info "🔍 Rich Link - Response code: #{response.code}"
    log_info "🔍 Rich Link - Content-Type: #{response.headers['content-type']}"
    log_info "🔍 Rich Link - Body size: #{response.body.bytesize} bytes"

    unless response.success?
      Rails.logger.error "❌ Rich Link - HTTP request failed with code: #{response.code}"
      return nil
    end

    content_type = response.headers['content-type']&.split(';')&.first&.strip
    unless content_type&.start_with?('image/')
      Rails.logger.error "❌ Rich Link - Invalid content type: #{content_type}"
      return nil
    end

    image_data = response.body

    # Convert unsupported formats (webp, gif, ico, bmp, etc.) to JPEG
    unless APPLE_SUPPORTED_IMAGE_TYPES.include?(content_type)
      Rails.logger.info "🔄 Rich Link - Converting #{content_type} to image/jpeg (not supported by Apple MSP)"
      image_data = convert_to_jpeg(image_data, content_type)
      content_type = 'image/jpeg'
      return nil if image_data.nil?
    end

    # Resize Apple Maps directions icon to 150x150
    if apple_maps_directions_icon?(image_url)
      Rails.logger.info '🔍 Rich Link - Resizing Apple Maps directions icon to 150x150'
      image_data = resize_image_to_icon_format(image_data)
      content_type = 'image/png'
    end

    if image_data.bytesize > APPLE_IMAGE_SIZE_LIMIT
      Rails.logger.info "🔄 Rich Link - Image too large (#{image_data.bytesize} bytes), compressing to fit 200KB limit..."
      image_data = compress_image_to_limit(image_data, content_type)
      content_type = 'image/jpeg'
      if image_data.nil? || image_data.bytesize > APPLE_IMAGE_SIZE_LIMIT
        Rails.logger.error '❌ Rich Link - Could not compress image under 200KB, skipping'
        return nil
      end
      Rails.logger.info "✅ Rich Link - Compressed to #{image_data.bytesize} bytes"
    end

    encoded = Base64.strict_encode64(image_data)
    Rails.logger.info "✅ Rich Link - Successfully encoded image (#{image_data.bytesize} bytes, #{content_type})"
    [encoded, content_type]
  rescue StandardError => e
    log_error "❌ Rich Link - Failed to download image #{image_url}: #{e.message}"
    log_error "❌ Rich Link - Backtrace: #{e.backtrace.first(3).join("\n")}"
    nil
  end

  def convert_to_jpeg(image_data, source_mime_type = nil)
    require 'mini_magick'
    require 'image_processing/mini_magick'
    # Let MiniMagick auto-detect: uses `magick` (IM7) or `convert` (IM6) based on what is installed

    # MiniMagick needs the correct file extension to identify the format
    ext = case source_mime_type
          when 'image/x-icon', 'image/vnd.microsoft.icon' then '.ico'
          when 'image/webp' then '.webp'
          when 'image/gif' then '.gif'
          when 'image/bmp' then '.bmp'
          when 'image/tiff' then '.tiff'
          else '.bin'
          end

    tempfile = Tempfile.new(['amb_image', ext])
    tempfile.binmode
    tempfile.write(image_data)
    tempfile.rewind

    processed = ImageProcessing::MiniMagick
                .source(tempfile)
                .convert('jpeg')
                .call

    File.binread(processed.path)
  rescue StandardError => e
    Rails.logger.error "❌ Rich Link - Failed to convert image to JPEG: #{e.message}"
    nil
  ensure
    tempfile&.close
    tempfile&.unlink
    processed&.unlink if processed
  end

  # Compress an oversized image to fit within APPLE_IMAGE_SIZE_LIMIT (200KB).
  # Strategy: convert to JPEG and progressively lower quality until it fits.
  def compress_image_to_limit(image_data, source_mime_type = nil)
    require 'mini_magick'
    require 'image_processing/mini_magick'
    # Let MiniMagick auto-detect: uses `magick` (IM7) or `convert` (IM6) based on what is installed

    ext = case source_mime_type
          when 'image/png' then '.png'
          when 'image/webp' then '.webp'
          when 'image/gif' then '.gif'
          else '.jpg'
          end

    tempfile = Tempfile.new(['amb_compress', ext])
    tempfile.binmode
    tempfile.write(image_data)
    tempfile.rewind

    # Try progressively lower JPEG quality until under the limit
    [85, 70, 55, 40].each do |quality|
      processed = ImageProcessing::MiniMagick
                  .source(tempfile)
                  .convert('jpeg')
                  .saver(quality: quality)
                  .call

      result = File.binread(processed.path)
      processed.unlink
      Rails.logger.info "🔄 Rich Link - Compressed at quality #{quality}: #{result.bytesize} bytes"
      return result if result.bytesize <= APPLE_IMAGE_SIZE_LIMIT
    end

    nil
  rescue StandardError => e
    Rails.logger.error "❌ Rich Link - Failed to compress image: #{e.message}"
    nil
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  # Check if this is the Apple Maps directions default icon
  def apple_maps_directions_icon?(image_url)
    image_url.include?('maps.apple.com') && image_url.include?('maps-app-icon')
  end

  # Resize image to 150x150 (icon format for rich links)
  def resize_image_to_icon_format(image_data)
    require 'mini_magick'
    require 'image_processing/mini_magick'
    # Let MiniMagick auto-detect: uses `magick` (IM7) or `convert` (IM6) based on what is installed

    # Create a temporary file from the image data
    tempfile = Tempfile.new(['apple_maps_icon', '.png'])
    tempfile.binmode
    tempfile.write(image_data)
    tempfile.rewind

    # Resize to 150x150 using ImageProcessing
    processed = ImageProcessing::MiniMagick
                .source(tempfile)
                .resize_to_fill(150, 150)
                .call

    # Read the resized image
    resized_data = File.binread(processed.path)

    Rails.logger.info "✅ Rich Link - Resized Apple Maps icon from #{image_data.bytesize} to #{resized_data.bytesize} bytes"

    resized_data
  rescue StandardError => e
    Rails.logger.error "❌ Rich Link - Failed to resize image: #{e.message}"
    # Return original image if resize fails
    image_data
  ensure
    tempfile&.close
    tempfile&.unlink
    processed&.unlink if processed
  end

  # Try to find a higher-resolution icon than the detected favicon.
  # Priority:
  # 1. Standard apple-touch-icon paths on the domain (180x180 PNG)
  # 2. Google's favicon service (returns 128x128 PNG for any domain)
  def fetch_best_domain_icon(favicon_url)
    return favicon_url if favicon_url.blank?

    uri = URI.parse(favicon_url)
    base = "#{uri.scheme}://#{uri.host}"
    host = uri.host

    # Try standard apple-touch-icon paths first
    high_res_paths = %w[
      /apple-touch-icon-180x180.png
      /apple-touch-icon-152x152.png
      /apple-touch-icon-120x120.png
      /apple-touch-icon.png
      /apple-touch-icon-precomposed.png
    ]

    high_res_paths.each do |path|
      candidate = "#{base}#{path}"
      next if candidate == favicon_url

      response = HTTParty.head(candidate, timeout: 5, headers: {
                                 'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Safari/605.1.15'
                               })
      return candidate if response.success? && response.headers['content-type']&.start_with?('image/')
    rescue StandardError
      next
    end

    # Fall back to Google's favicon service — always returns a 128×128 PNG
    "https://www.google.com/s2/favicons?domain=#{host}&sz=128"
  rescue URI::InvalidURIError, StandardError
    favicon_url
  end

  # Derives a human title from the URL path + brand name.
  # Used when the page title is unavailable (bot-blocked, error page, bare domain).
  #
  # Examples:
  #   /fr_fr/bague-josephine-aigrette-083590         → "Bague Josephine Aigrette – Chaumet"
  #   /fr/fr/luggage/colour/green/cabin-plus/84256311.html → "Cabin Plus – Rimowa"
  #   /hotel/hu/7seasons-apartments-budapest.en-gb.html    → "7seasons Apartments Budapest – Booking"
  def extract_title_from_url(url, site_name = nil)
    return 'Rich Link' if url.blank?

    uri = URI.parse(url)
    path = uri.path.to_s
    product_title = nil

    unless path.empty? || path == '/'
      segments = path.split('/').reject(&:blank?)
      # Walk segments from deepest to shallowest looking for a descriptive slug:
      # must contain at least one letter AND a hyphen/underscore, and be >4 chars.
      # Pure numeric IDs (e.g. "84256311") and locale codes (e.g. "fr_fr") are skipped.
      content_segment = segments.reverse.find do |s|
        s.length > 4 && s.match?(/[a-z]/i) && s.match?(/[-_]/) && !s.match?(/\A[\d_-]+\z/)
      end

      if content_segment
        slug = content_segment
               .sub(/\.[a-z]{2,4}$/i, '')              # strip extension (.html)
               .sub(/\.[a-z]{2}(-[a-z]{2,4})?$/i, '')  # strip locale suffix (.en-gb)
               .gsub(/[-_]+/, ' ')
               .split
               .map(&:capitalize)
               .join(' ')
        product_title = slug if slug.length > 3
      end
    end

    brand = extract_brand_name(url, site_name)

    if product_title.present? && brand.present?
      "#{product_title} – #{brand}"
    elsif product_title.present?
      product_title
    else
      brand || 'Rich Link'
    end
  rescue URI::InvalidURIError
    'Rich Link'
  end

  # Derives brand name from og:site_name (cleaned) or the first domain label.
  def extract_brand_name(url, site_name = nil)
    if site_name.present? && !error_page_title?(site_name)
      # Strip common TLD suffixes left in site_name values like "Chaumet.com" or "Rimowa.com"
      clean = site_name.sub(/\s*\.(com|fr|net|org|co\.uk|de|es|it|nl|be|ch|au|ca|jp|cn)\s*$/i, '').strip
      return clean if clean.present?
    end

    uri = URI.parse(url)
    uri.host&.delete_prefix('www.')&.split('.')&.first&.capitalize
  rescue URI::InvalidURIError
    nil
  end

  # Returns true when the frontend already sent meaningful OG data that we should trust.
  # A title equal to the URL or the bare domain means the frontend scrape also failed.
  # An image_url that looks like a tracking pixel (1×1, query-param-only, akamai/akam path) is not usable.
  ERROR_PAGE_PATTERNS = /\b(error|404|403|not found|access denied|forbidden|blocked|page not found|something went wrong)\b/i

  def error_page_title?(title)
    return false if title.blank?

    ERROR_PAGE_PATTERNS.match?(title)
  end

  def frontend_og_data_usable?(content_attrs, url)
    title = content_attrs['title'].to_s.strip
    image_url = (content_attrs['image_url'] || content_attrs['image_data']).to_s.strip

    return false if title.blank?

    # Title is just the URL itself — frontend scrape returned nothing useful
    return false if title == url.to_s.strip

    # Title is only a bare domain (e.g. "fnac.com") — bot-detection fallback page
    begin
      host = URI.parse(url).host.to_s.downcase.delete_prefix('www.')
      return false if title.downcase == host
    rescue URI::InvalidURIError
      nil
    end

    # Image looks like a tracking pixel, Akamai challenge asset, or lazy-load placeholder GIF
    return false if image_url.match?(%r{/akam/|/pixel_|/beacon\.|1x1|tracking|data:image/gif})
    return false if image_url.blank?

    true
  end

  def direct_video_url?(url)
    return false if url.blank?

    # Check if URL ends with common video extensions
    video_extensions = %w[.mp4 .mov .m4v .avi .wmv .flv .webm .mkv .3gp]
    video_extensions.any? { |ext| url.downcase.end_with?(ext) }
  end

  def send_to_apple_gateway(payload, message_id)
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@channel.generate_jwt_token}",
      'id' => message_id,
      'Source-Id' => @channel.business_id,
      'Destination-Id' => @destination_id
    }

    HTTParty.post(
      "#{AMB_SERVER}/message",
      body: payload.to_json,
      headers: headers,
      timeout: 30
    )
  end
end
