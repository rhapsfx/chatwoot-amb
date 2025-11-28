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
        # Mark as sent if successful
        mark_as_sent
        { success: true, message_id: message_id }
      else
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

  def idempotency_response
    Rails.logger.info "[AMB RichLink] Message #{@message.id} already sent (external_source_id: #{@message.external_source_id_apple_messages}), skipping"
    { success: true, message_id: @message.external_source_id_apple_messages, skipped: true }
  end

  private

  def build_rich_link_data
    content_attrs = @message.content_attributes

    # Always scrape Open Graph data for rich links to get accurate title/description/image
    # This ensures we use proper OpenGraph metadata instead of frontend fallback values
    url = content_attrs['url'] || @message.content
    Rails.logger.info "🔍 Rich Link - Attempting Open Graph scraping for: #{url}"
    og_data = scrape_open_graph_data(url)

    if og_data[:success]
      Rails.logger.info '✅ Rich Link - Open Graph scraping successful'
      Rails.logger.info "🔍 Rich Link - Scraped title: #{og_data[:title]}"
      Rails.logger.info "🔍 Rich Link - Scraped image: #{og_data[:image_url]}"
      Rails.logger.info "🔍 Rich Link - Scraped description: #{og_data[:description]}"

      # Update content_attributes with scraped data
      # ALWAYS prefer scraped data over frontend-provided fallbacks
      # Frontend may send URL as title/description, but we want actual OpenGraph data
      updates = {
        'title' => og_data[:title] || content_attrs['title'],
        'image_url' => og_data[:image_url] || content_attrs['image_url'],
        'description' => og_data[:description] || content_attrs['description']
      }.compact

      # Save updates to database for frontend display
      # Use save! instead of update_column to trigger callbacks and ActionCable broadcasts
      @message.content_attributes = content_attrs.merge(updates)
      Rails.logger.info '🔍 Rich Link - About to save message with scraped data'
      Rails.logger.info "🔍 Rich Link - content_attributes before save: #{@message.content_attributes.inspect}"
      Rails.logger.info "🔍 Rich Link - Message changed?: #{@message.changed?}"
      Rails.logger.info "🔍 Rich Link - Changed attributes: #{@message.changes.inspect}"

      begin
        @message.save!
        Rails.logger.info '✅ Rich Link - Message saved successfully with scraped data'
        Rails.logger.info "🔍 Rich Link - Previous changes after save: #{@message.previous_changes.inspect}"

        # Manually dispatch update event if Rails didn't detect changes
        if @message.previous_changes.blank?
          Rails.logger.warn '⚠️ Rich Link - No previous_changes detected, manually dispatching MESSAGE_UPDATED event'
          Rails.configuration.dispatcher.dispatch(
            'MESSAGE_UPDATED',
            Time.zone.now,
            message: @message.reload,
            performed_by: nil
          )
          Rails.logger.info '✅ Rich Link - Manually dispatched MESSAGE_UPDATED event'
        end
      rescue StandardError => e
        Rails.logger.error "❌ Rich Link - Failed to save message: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end

      # Update local content_attrs for building payload
      content_attrs = @message.content_attributes
      Rails.logger.info "🔍 Rich Link - content_attributes after save: #{content_attrs.inspect}"
    else
      Rails.logger.warn "⚠️ Rich Link - Open Graph scraping failed: #{og_data[:error]}"
    end

    # PRIORITY 1: Check if richLinkDataRef exists (App Clips mode)
    # This takes precedence over manual rich link building
    if content_attrs['rich_link_data_ref'].present?
      log_info '🔍 Rich Link - Using richLinkDataRef (App Clips mode)'
      return build_from_rich_link_data_ref(content_attrs)
    end

    # PRIORITY 2: Build manual richLinkData with assets
    log_info '🔍 Rich Link - Building manual richLinkData with assets'
    url = content_attrs['url'] || @message.content

    {
      url: url,
      title: content_attrs['title'] || extract_title_from_url(url),
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

    # Get image from either 'image_data' (base64), 'image_url' (URL), or 'favicon_url' (fallback)
    image_source = content_attrs['image_data'] || content_attrs['image_url'] || content_attrs['favicon_url']

    Rails.logger.info "🔍 Rich Link - Image source: #{image_source&.truncate(100)}"
    Rails.logger.info "🔍 Rich Link - Content attrs keys: #{content_attrs.keys}"

    # Add image asset if provided
    if image_source.present?
      if image_source.start_with?('http')
        # Download and encode image from URL (including favicon URLs)
        Rails.logger.info "🔍 Rich Link - Downloading image from URL: #{image_source}"
        encoded_image = download_and_encode_image(image_source)
        if encoded_image
          Rails.logger.info "✅ Rich Link - Successfully encoded image (#{encoded_image.length} chars)"
          assets[:image] = {
            data: encoded_image,
            mimeType: detect_image_mime_type(image_source, content_attrs)
          }
        else
          Rails.logger.error "❌ Rich Link - Failed to download/encode image from URL: #{image_source}"
        end
      elsif image_source.start_with?('data:image')
        # Handle data URLs (base64 embedded)
        base64_data = image_source.split(',')[1]
        mime_type = begin
          image_source.match(/data:([^;]+)/)[1]
        rescue StandardError
          'image/jpeg'
        end

        assets[:image] = {
          data: base64_data,
          mimeType: mime_type
        }
      else
        # Assume it's already base64 encoded
        assets[:image] = {
          data: image_source,
          mimeType: content_attrs['image_mime_type'] || 'image/jpeg'
        }
      end
    end

    # Add video asset if provided
    if content_attrs['video_url'].present?
      assets[:video] = {
        url: content_attrs['video_url'],
        mimeType: content_attrs['video_mime_type'] || 'video/mp4'
      }
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

  def download_and_encode_image(image_url)
    return nil if image_url.blank?

    Rails.logger.info "🔍 Rich Link - Starting download for: #{image_url}"

    # Enhanced headers for better favicon access
    headers = {
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Safari/605.1.15',
      'Accept' => 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      'Accept-Language' => 'en-US,en;q=0.9',
      'Cache-Control' => 'no-cache'
    }

    # Download image with timeout and size limits
    response = HTTParty.get(
      image_url,
      timeout: 15,  # Increased timeout for favicons
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

    # Check file size (limit to 1MB for Rich Links)
    if response.body.bytesize > 1.megabyte
      Rails.logger.error "❌ Rich Link - Image too large: #{response.body.bytesize} bytes (max 1MB)"
      return nil
    end

    # Validate content type
    content_type = response.headers['content-type']
    unless content_type&.start_with?('image/')
      Rails.logger.error "❌ Rich Link - Invalid content type: #{content_type}"
      return nil
    end

    # Encode to base64
    encoded = Base64.strict_encode64(response.body)
    Rails.logger.info "✅ Rich Link - Successfully encoded image (#{encoded.length} chars)"
    encoded
  rescue StandardError => e
    log_error "❌ Rich Link - Failed to download image #{image_url}: #{e.message}"
    log_error "❌ Rich Link - Backtrace: #{e.backtrace.first(3).join("\n")}"
    nil
  end

  def extract_title_from_url(url)
    return 'Rich Link' if url.blank?

    # Try to extract domain name as fallback title
    uri = URI.parse(url)
    uri.host&.gsub('www.', '')&.capitalize || 'Rich Link'
  rescue URI::InvalidURIError
    'Rich Link'
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
