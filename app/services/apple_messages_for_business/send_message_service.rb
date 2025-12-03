require_relative 'log_sanitizer'

class AppleMessagesForBusiness::SendMessageService
  include AppleMessagesForBusiness::Concerns::Utf8Logging

  AMB_SERVER = 'https://mspgw.push.apple.com/v1'.freeze

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
      Rails.logger.warn "[AMB Send] Message #{@message.id} is already being sent (lock exists)"
      return { success: false, error: 'Message send already in progress', error_code: 'SEND_IN_PROGRESS' }
    end

    begin
      # CRITICAL: Check if user has opted out (Apple MSP requirement)
      if user_opted_out?
        Rails.logger.warn "[AMB Send] Cannot send message - user #{@destination_id} has opted out"
        return { success: false, error: 'User has opted out of receiving messages', error_code: 'USER_OPTED_OUT' }
      end

      result = perform_send

      # Mark as sent if successful
      mark_as_sent if result[:success]

      result
    ensure
      # Always release the lock
      Redis::Alfred.delete(lock_key)
    end
  rescue StandardError => e
    Rails.logger.error "Apple Messages send failed: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def perform_send
    case @message.content_type
    when 'text'
      send_text_message
    when 'apple_list_picker'
      send_interactive_message
    when 'apple_time_picker'
      send_interactive_message
    when 'apple_quick_reply'
      send_interactive_message
    when 'apple_form'
      send_interactive_message
    when 'apple_custom_app'
      send_interactive_message
    when 'apple_custom_payload'
      send_interactive_message
    when 'apple_rich_link'
      send_rich_link_message
    when 'apple_pay'
      send_apple_pay_message
    else
      send_text_message # fallback
    end
  end

  def already_sent?
    # Check if message has already been successfully sent to Apple MSP
    # We use external_source_id_apple_messages to track if a message was sent
    @message.external_source_id_apple_messages.present?
  end

  def mark_as_sent
    # Mark message as sent by setting external_source_id_apple_messages
    # This prevents duplicate sends even if the job is retried
    return if @message.external_source_id_apple_messages.present?

    @message.update_column(:external_source_ids,
                           @message.external_source_ids.merge('apple_messages' => SecureRandom.uuid))
  end

  def idempotency_response
    Rails.logger.info "[AMB Send] Message #{@message.id} already sent (external_source_id: #{@message.external_source_id_apple_messages}), skipping"
    { success: true, message_id: @message.external_source_id_apple_messages, skipped: true }
  end

  def store_apple_msp_payload(payload, status, message_id, error = nil)
    # Store the actual payload sent to Apple MSP Gateway for debugging
    # This allows agents to see exactly what was sent via the info (i) button in Chatwoot UI
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

    Rails.logger.info "✅ Apple MSP - Stored payload (status: #{status}, type: #{@message.content_type})"
  end

  def sanitize_payload_for_storage(payload)
    # Create a deep copy to avoid modifying the original
    sanitized = payload.deep_dup

    # Truncate base64 image data for storage (keep first/last 100 chars for verification)
    # This applies to various payload types
    if sanitized.dig(:interactiveData, :data, :imageBubbleStyle, :imageIdentifier)
      # For interactive messages with image bubbles
      image_data = sanitized[:interactiveData][:data][:imageBubbleStyle][:imageIdentifier]
      if image_data.is_a?(String) && image_data.length > 200
        sanitized[:interactiveData][:data][:imageBubbleStyle][:imageIdentifier] = truncate_base64(image_data)
      end
    end

    if sanitized.dig(:richLinkData, :assets, :image, :data)
      # For rich links with embedded images
      image_data = sanitized[:richLinkData][:assets][:image][:data]
      if image_data.length > 200
        sanitized[:richLinkData][:assets][:image][:data] = truncate_base64(image_data)
        sanitized[:richLinkData][:assets][:image][:_truncated] = true
        sanitized[:richLinkData][:assets][:image][:_original_length] = image_data.length
      end
    end

    if sanitized[:attachments].is_a?(Array)
      # For text messages with attachments
      sanitized[:attachments].each do |attachment|
        next unless attachment[:data].is_a?(String) && attachment[:data].length > 200

        attachment[:data] = truncate_base64(attachment[:data])
        attachment[:_truncated] = true
      end
    end

    sanitized
  end

  def truncate_base64(data)
    "#{data[0...100]}...#{data[-100..]}"
  end

  def send_text_message
    message_id = SecureRandom.uuid

    # All messages must be type "text" according to Apple MSP spec
    # The body field is required for type "text"
    has_text = @message.content.present?
    has_attachments = @message.attachments.present?

    return { success: false, error: 'Message has no content or attachments' } if !has_text && !has_attachments

    # Build message body with Unicode Object Replacement Characters for attachments
    body_text = @message.content || ''
    if has_attachments
      # Add one Unicode Object Replacement Character (\uFFFC) for each attachment
      attachment_placeholders = "\uFFFC" * @message.attachments.count
      body_text = has_text ? "#{body_text} #{attachment_placeholders}" : attachment_placeholders
    end

    payload = {
      id: message_id,
      type: 'text',
      sourceId: @channel.business_id,
      destinationId: @destination_id,
      v: 1,
      body: body_text,
      locale: 'en_US'
    }

    # Add attachments if present
    if has_attachments
      attachments_result = process_attachments
      return attachments_result unless attachments_result[:success]

      payload[:attachments] = attachments_result[:attachments]
    end

    response = send_to_apple_gateway(payload, message_id)

    if response.success?
      # Store the payload that was sent to Apple MSP for debugging
      store_apple_msp_payload(payload, 'sent', message_id)
      { success: true, message_id: message_id }
    else
      # Store the failed payload for debugging
      store_apple_msp_payload(payload, 'failed', message_id, "HTTP #{response.code}: #{response.body}")
      { success: false, error: "HTTP #{response.code}: #{response.body}" }
    end
  end

  def send_interactive_message
    message_id = SecureRandom.uuid

    Rails.logger.info "[AMB Send] 🚀 Sending interactive message - Message ID: #{@message.id}, Apple MSP ID: #{message_id}, Content Type: #{@message.content_type}"

    payload = build_apple_msp_payload(message_id)

    # Log full payload for custom apps to help debug
    Rails.logger.info "[AMB Send] 📦 Full custom app payload: #{payload.to_json}" if @message.content_type == 'apple_custom_app'

    # Check if this message should request IDR for large responses
    request_idr = should_request_idr?(payload)

    response = send_to_apple_gateway(payload, message_id, request_idr: request_idr)

    Rails.logger.info "[AMB Send] Apple MSP Response - Code: #{response.code}, Success: #{response.success?}"

    if response.success?
      Rails.logger.info "[AMB Send] ✅ Successfully sent to Apple MSP - Message ID: #{@message.id}"
      # Store the payload that was sent to Apple MSP for debugging
      store_apple_msp_payload(payload, 'sent', message_id)

      result = { success: true, message_id: message_id }

      # If we requested IDR and got a dataRef back, store it
      if request_idr && response.body.present?
        begin
          response_data = JSON.parse(response.body)
          if response_data['dataRef'].present?
            Rails.logger.info "[AMB Send] Received dataRef for message #{message_id}"
            result[:data_ref] = response_data['dataRef']
          end
        rescue JSON::ParserError => e
          Rails.logger.warn "[AMB Send] Failed to parse response body for dataRef: #{e.message}"
        end
      end

      result
    else
      log_error "[AMB Send] ❌ Apple MSP rejected message - HTTP #{response.code}: #{response.body}"
      # Store the failed payload for debugging
      store_apple_msp_payload(payload, 'failed', message_id, "HTTP #{response.code}: #{response.body}")
      { success: false, error: "HTTP #{response.code}: #{response.body}" }
    end
  end

  # Build the correct Apple MSP interactive message format
  def build_apple_msp_payload(message_id)
    # For custom payloads, merge interactive_data directly instead of wrapping in interactiveData
    if @message.content_type == 'apple_custom_payload'
      interactive_data = build_interactive_data

      # Base fields that are always required by Apple MSP
      base_payload = {
        v: 1,
        id: message_id,
        sourceId: source_id,
        destinationId: destination_id
      }

      # Merge custom payload directly - it may contain 'type' and other top-level fields
      return base_payload.merge(interactive_data)
    end

    # Standard interactive message format for other types
    {
      v: 1,
      id: message_id,
      sourceId: source_id,
      destinationId: destination_id,
      type: 'interactive',
      interactiveData: build_interactive_data
    }
  end

  # Build the interactiveData structure according to Apple MSP spec
  def build_interactive_data
    # For custom apps, use the BID from content_attributes, otherwise use default
    bid_value = if @message.content_type == 'apple_custom_app' && content_attributes['bid'].present?
                  content_attributes['bid']
                else
                  'com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension'
                end

    base_data = {
      bid: bid_value,
      useLiveLayout: content_attributes['use_live_layout'] != false # Default to true unless explicitly false
    }

    # CRITICAL: Third-party custom apps (apple_custom_app) CANNOT have a "data" object
    # Apple returns: "400 Bad Request : Third party interactive data disallows use of 'data'"
    # Only add data object for Apple's own interactive message types
    unless @message.content_type == 'apple_custom_app'
      base_data[:data] = {
        version: content_attributes['version'] || '1.0',
        requestIdentifier: content_attributes['request_identifier'] || SecureRandom.uuid
      }
    end

    # Add the specific interactive content based on message type
    case @message.content_type
    when 'apple_quick_reply'
      base_data[:data]['quick-reply'] = build_quick_reply_data
      base_data[:receivedMessage] = build_received_message
      base_data[:replyMessage] = build_reply_message
    when 'apple_list_picker'
      list_picker_data = build_list_picker_data
      base_data[:data][:listPicker] = list_picker_data
      base_data[:receivedMessage] = build_received_message
      base_data[:replyMessage] = build_reply_message
    when 'apple_time_picker'
      # Time picker should have event directly in data, not nested under timePicker
      base_data[:data][:event] = build_time_picker_data
      base_data[:receivedMessage] = build_received_message
      base_data[:replyMessage] = build_reply_message
    when 'apple_form'
      # Apple MSP Form requires dynamic structure with messageForms template
      base_data[:data][:dynamic] = build_form_dynamic_data
      base_data[:receivedMessage] = build_received_message
      base_data[:replyMessage] = build_reply_message
    when 'apple_custom_app'
      # For custom iMessage apps, per Apple spec (type-interactive.md line 259-274):
      # appId, appName, URL, and receivedMessage go at TOP LEVEL of interactiveData
      # CRITICAL: Third-party apps CANNOT have a "data" object (Apple returns 400 error)

      # Add appId at top level - MUST be integer per Apple spec
      base_data[:appId] = content_attributes['app_id'].to_i if content_attributes['app_id'].present?

      # Add appName at top level
      base_data[:appName] = content_attributes['app_name'] if content_attributes['app_name'].present?

      # URL goes at top level - uppercase per Apple working example
      base_data[:URL] = content_attributes['url'] if content_attributes['url'].present?

      # receivedMessage is REQUIRED for custom interactive messages per Apple spec
      # If not provided in content_attributes, create a default one
      base_data[:receivedMessage] = if content_attributes['received_message'].present? || content_attributes['received_title'].present?
                                      build_received_message
                                    else
                                      # Create default receivedMessage with subtitle (not style) per Apple working example
                                      {
                                        title: content_attributes['app_name'] || @message.content || 'Interactive Message',
                                        subtitle: content_attributes['received_subtitle'] || 'Tap to view'
                                      }
                                    end

      # Add replyMessage if provided (optional but recommended per Apple working example)
      base_data[:replyMessage] = build_reply_message if content_attributes['reply_message'].present? || content_attributes['reply_title'].present?

      # NOTE: Do NOT add app_data to base_data[:data] - third-party apps cannot have "data" object
      # If you need to pass custom data, it must go in the URL query parameters

      Rails.logger.info "[AMB Send] Custom app payload - BID: #{base_data[:bid]}, appId: #{base_data[:appId]}, URL: #{base_data[:URL].present? ? 'present' : 'none'}, receivedMessage: #{base_data[:receivedMessage].present?}, replyMessage: #{base_data[:replyMessage].present?}"
    end

    # Add images array if present
    # For forms, use @form_images loaded during build_form_dynamic_data
    # For other types, enrich from content_attributes['images']
    if @message.content_type == 'apple_form' && @form_images.present?
      base_data[:data][:images] = @form_images
    elsif content_attributes['images'].present?
      images = enrich_images_with_data(content_attributes['images'])
      base_data[:data][:images] = images if images.present?
    end

    base_data
  end

  # Enrich images array with base64 data using three-tier fallback
  def enrich_images_with_data(images_array)
    return [] if images_array.blank?

    # Get all identifiers
    identifiers = images_array.filter_map { |img| img['identifier'] }
    return images_array if identifiers.empty?

    # Use ImageFetchService for three-tier fallback (inbox → shared → embedded)
    fetched_images = AppleMessagesForBusiness::ImageFetchService.new(
      account_id: @channel.account_id,
      inbox_id: @channel.inbox.id,
      embedded_images: images_array # Pass existing images as tier-3 fallback
    ).fetch_and_encode(identifiers)

    # Build index of fetched images
    fetched_by_id = fetched_images.index_by { |img| img[:identifier] }

    # Enrich each image with fetched data
    images_array.filter_map do |img|
      identifier = img['identifier']
      fetched = fetched_by_id[identifier]

      if fetched
        # Image found via ImageFetchService (any tier)
        {
          identifier: identifier,
          data: fetched[:data],
          description: img['description'] || fetched[:description] || identifier
        }
      elsif img['data'].present?
        # Not found in any tier - return as-is if it has data
        img
      else
        Rails.logger.warn "[AMB Send] Image #{identifier} not found in any tier (inbox/shared/embedded)"
        nil
      end
    end.compact
  end

  # Override these methods in subclasses for specific message types
  def build_quick_reply_data
    {
      summaryText: content_attributes['summary_text'] || @message.content,
      items: content_attributes['items'] || []
    }
  end

  def build_list_picker_data
    Rails.logger.info '[AMB Send] 🔴 PARENT CLASS build_list_picker_data called'
    sections = content_attributes['sections'] || []

    # Add missing order and style fields according to Apple MSP spec
    sections.each_with_index do |section, section_index|
      section['order'] = section_index unless section.key?('order')

      next unless section['items']

      section['items'].each_with_index do |item, item_index|
        item['order'] = item_index unless item.key?('order')
        item['style'] = 'icon' unless item.key?('style')
        Rails.logger.info "[AMB Send] 🔴 PARENT: Item keys after processing: #{item.keys.inspect}"
      end
    end

    result = {
      sections: sections
    }
    Rails.logger.info "[AMB Send] 🔴 PARENT CLASS returning: #{if result[:sections].first && result[:sections].first['items'].first
                                                                result[:sections].first['items'].first.keys.inspect
                                                              end}"
    result
  end

  def build_time_picker_data
    # Return event structure directly (not nested under timePicker)
    event_data = content_attributes['event'] || {}

    # Add timezone offset if present at top level (for backward compatibility)
    event_data['timezoneOffset'] = content_attributes['timezone_offset'] if content_attributes['timezone_offset'] && !event_data['timezoneOffset']

    # Add timeslots if present at top level (for backward compatibility)
    event_data['timeslots'] = content_attributes['timeslots'] if content_attributes['timeslots'] && !event_data['timeslots']

    # Fix timeslot format for Apple's requirements
    if event_data['timeslots'].present?
      # Handle both camelCase and snake_case for timezone detection
      has_timezone_in_times = event_data['timeslots'].any? do |slot|
        # Handle both symbol and string keys
        time_value = slot[:startTime] || slot['startTime'] || slot[:start_time] || slot['start_time']
        time_value&.include?('+') || time_value&.include?('Z')
      end

      event_data['timeslots'] = event_data['timeslots'].map do |slot|
        # Handle both symbol and string keys (CaseTransformer returns symbol keys)
        start_time = slot[:startTime] || slot['startTime'] || slot[:start_time] || slot['start_time']
        duration = slot[:duration] || slot['duration']
        identifier = slot[:identifier] || slot['identifier']

        # Convert local time to GMT if it contains timezone info
        if start_time&.include?('+') || start_time&.include?('Z')
          begin
            parsed_time = Time.zone.parse(start_time)
            start_time = parsed_time.utc.strftime('%Y-%m-%dT%H:%M+0000')
          rescue StandardError
            # If parsing fails, keep original format
          end
        end

        {
          'identifier' => identifier,  # Apple expects identifier first
          'startTime' => start_time,
          'duration' => convert_duration_if_needed(duration)
        }
      end

      # Use Apple's "User timezone approach": If we converted times to GMT, remove timezoneOffset
      # This lets Apple display times in the user's local timezone automatically
      event_data.delete('timezoneOffset') if has_timezone_in_times
    end

    event_data
  end

  def convert_duration_if_needed(duration)
    # Apple working sample uses seconds (3600), but ensure consistency
    # If duration is less than 300, assume it's already in minutes and convert to seconds
    duration_int = duration.to_i
    duration_int < 300 ? (duration_int * 60) : duration_int
  end

  def build_received_message
    # For Apple forms, use the form title if available
    default_title = if @message.content_type == 'apple_form' && content_attributes['title'].present?
                      content_attributes['title']
                    else
                      @message.content || 'Interactive Message'
                    end

    # Check if we have a nested received_message object (new form builder format)
    received_msg = content_attributes['received_message'] || {}

    # Build the message, prioritizing nested structure over flat keys
    msg = {
      title: received_msg['title'] || content_attributes['received_title'] || default_title,
      style: received_msg['style'] || content_attributes['received_style'] || 'icon'
    }

    # Add subtitle if present
    subtitle = received_msg['subtitle'] || content_attributes['received_subtitle']
    msg[:subtitle] = subtitle if subtitle.present?

    # Add imageIdentifier if present (check both camelCase and snake_case)
    image_id = received_msg['image_identifier'] || received_msg['imageIdentifier'] || content_attributes['received_image_identifier']
    msg[:imageIdentifier] = image_id if image_id.present?

    msg
  end

  def build_reply_message
    # For Apple forms, use a form-specific reply title if no custom title is set
    default_reply_title = if @message.content_type == 'apple_form' && content_attributes['title'].present? && content_attributes['reply_title'].blank?
                            "#{content_attributes['title']} - Submitted"
                          else
                            'Selection Made'
                          end

    # Check if we have a nested reply_message object (new form builder format)
    reply_msg = content_attributes['reply_message'] || {}

    # Build the message, prioritizing nested structure over flat keys
    msg = {
      title: reply_msg['title'] || content_attributes['reply_title'] || default_reply_title,
      style: reply_msg['style'] || content_attributes['reply_style'] || 'icon'
    }

    # Add subtitle if present
    subtitle = reply_msg['subtitle'] || content_attributes['reply_subtitle']
    msg[:subtitle] = subtitle if subtitle.present?

    # Add enriched replyMessage fields according to Apple MSP specification
    msg[:imageTitle] = content_attributes['reply_image_title'] if content_attributes['reply_image_title'].present?

    msg[:imageSubtitle] = content_attributes['reply_image_subtitle'] if content_attributes['reply_image_subtitle'].present?

    msg[:secondarySubtitle] = content_attributes['reply_secondary_subtitle'] if content_attributes['reply_secondary_subtitle'].present?

    msg[:tertiarySubtitle] = content_attributes['reply_tertiary_subtitle'] if content_attributes['reply_tertiary_subtitle'].present?

    # Add imageIdentifier if present (check both camelCase and snake_case)
    image_id = reply_msg['image_identifier'] || reply_msg['imageIdentifier'] || content_attributes['reply_image_identifier']
    msg[:imageIdentifier] = image_id if image_id.present?

    msg
  end

  def build_form_dynamic_data
    # Apple MSP Form specification requires specific dynamic structure
    form_data = content_attributes || {}

    Rails.logger.info '[SendMessageService build_form_dynamic_data] Starting'
    Rails.logger.info "[SendMessageService] content_attributes keys: #{content_attributes.keys.inspect}"
    Rails.logger.info "[SendMessageService] form_data keys: #{form_data.keys.inspect}"
    Rails.logger.info "[SendMessageService] form_data['pages'].present?: #{form_data['pages'].present?}"

    # DEBUG: Log the first page's first item's options to see if image_identifier is present
    if form_data['pages'].present? && form_data['pages'].first && form_data['pages'].first['items'].present?
      first_item = form_data['pages'].first['items'].first
      Rails.logger.info "[SendMessageService] First item: #{first_item.inspect}"
      Rails.logger.info "[SendMessageService] First option: #{first_item['options'].first.inspect}" if first_item['options'].present?
    end

    # Check if we have pages from the form builder (new format)
    if form_data['pages'].present?
      Rails.logger.info "[SendMessageService] Found pages at root level: #{form_data['pages'].length} pages"
      # Convert pages with items to Apple MSP format
      pages = convert_form_builder_pages_to_msp(form_data['pages'])
      # Set startPageIdentifier to the first page's ID
      start_page_id = pages.first&.dig(:pageIdentifier) || '0'

      # Collect image identifiers from form pages and load images
      Rails.logger.info '[SendMessageService] Calling collect_form_image_identifiers'
      image_identifiers = collect_form_image_identifiers(form_data['pages'])
      Rails.logger.info "[SendMessageService] collect_form_image_identifiers returned #{image_identifiers.length} identifiers: #{image_identifiers.inspect}"
      load_form_images(image_identifiers) if image_identifiers.any?
      Rails.logger.info "[SendMessageService] After load_form_images, @form_images count: #{@form_images&.length || 0}"
    else
      Rails.logger.warn '[SendMessageService] No pages found, using legacy fields format'
      # Legacy: Convert flat fields array to MSP format
      pages = convert_legacy_fields_to_msp(form_data['fields'] || [])
      start_page_id = '0'
    end

    {
      version: '1.2',
      template: 'messageForms',
      data: {
        startPageIdentifier: start_page_id,
        showSummary: form_data['show_summary'] || false,
        pages: pages
      }
    }
  end

  # Collect all image identifiers referenced in form pages
  def collect_form_image_identifiers(pages)
    identifiers = []

    Rails.logger.info "[collect_form_image_identifiers] Pages count: #{pages&.length || 0}"
    Rails.logger.info "[collect_form_image_identifiers] Pages structure: #{pages&.first&.keys&.inspect}"

    # Collect from page items (singleSelect/multiSelect options)
    pages.each_with_index do |page, idx|
      page_type = page['type'] || 'module'

      # Collect splash page images
      if page_type == 'splash' && page['image_identifier'].present?
        Rails.logger.info "[collect_form_image_identifiers] Found splash page image: #{page['image_identifier']}"
        identifiers << page['image_identifier']
      end

      items = page['items'] || []
      Rails.logger.info "[collect_form_image_identifiers] Page #{idx} items count: #{items.length}"

      items.each do |item|
        Rails.logger.info "[collect_form_image_identifiers] Item type: #{item['item_type']}"
        next unless item['item_type'] == 'singleSelect' || item['item_type'] == 'multiSelect'

        options = item['options'] || []
        Rails.logger.info "[collect_form_image_identifiers] Options count: #{options.length}"

        options.each do |option|
          # Support both camelCase and snake_case (API normalizes to snake_case)
          image_id = option['imageIdentifier'] || option['image_identifier']
          Rails.logger.info "[collect_form_image_identifiers] Option image_id: #{image_id.inspect}"
          identifiers << image_id if image_id.present?
        end
      end
    end

    # Collect from received_message and reply_message
    received_msg = content_attributes['received_message'] || {}
    reply_msg = content_attributes['reply_message'] || {}

    identifiers << received_msg['image_identifier'] if received_msg['image_identifier'].present?
    identifiers << reply_msg['image_identifier'] if reply_msg['image_identifier'].present?

    # Collect from top-level images array (sent by frontend)
    if content_attributes['images'].present?
      content_attributes['images'].each do |img|
        identifiers << img['identifier'] if img['identifier'].present?
      end
    end

    Rails.logger.info "[collect_form_image_identifiers] Final identifiers: #{identifiers.inspect}"
    identifiers.compact.uniq
  end

  # Load form images using three-tier fallback and add them to @form_images
  def load_form_images(identifiers)
    return if identifiers.empty?

    # Use ImageFetchService for three-tier fallback (inbox → shared → embedded)
    images_array = AppleMessagesForBusiness::ImageFetchService.new(
      account_id: @channel.account_id,
      inbox_id: @channel.inbox.id,
      embedded_images: content_attributes['images'] || [] # Pass embedded images from form
    ).fetch_and_encode(identifiers)

    # Add to the payload (this will be accessed by build_interactive_data)
    @form_images = images_array unless images_array.empty?

    # Log warnings for missing images
    missing = identifiers - images_array.map { |img| img[:identifier] }
    missing.each do |identifier|
      Rails.logger.warn "[AMB Send] Form image #{identifier} not found in any tier"
    end
  end

  def convert_form_builder_pages_to_msp(builder_pages)
    return [] if builder_pages.blank?

    msp_pages = []

    # First, collect all page IDs to know what comes next
    all_page_items = []
    builder_pages.each_with_index do |page, page_index|
      page_id = page['page_id'] || page_index.to_s
      page_type = page['type'] || 'module'

      if page_type == 'splash'
        # Splash pages are standalone - add them directly
        all_page_items << {
          page_id: page_id,
          item: nil,
          page: page,
          is_splash: true
        }
      else
        # Module pages - convert each item to a page
        items = page['items'] || []
        items.each_with_index do |item, item_index|
          all_page_items << {
            page_id: "#{page_id}_#{item_index}",
            item: item,
            page: page,
            is_splash: false
          }
        end
      end
    end

    # Now build MSP pages with correct next page references
    all_page_items.each_with_index do |page_item, global_index|
      next_page_id = global_index < all_page_items.length - 1 ? all_page_items[global_index + 1][:page_id] : nil

      msp_page = if page_item[:is_splash]
                   # Build splash page
                   build_msp_splash_page(
                     page_item[:page],
                     page_item[:page_id],
                     next_page_id
                   )
                 else
                   # Build regular item-based page
                   build_msp_page_from_item(
                     page_item[:item],
                     page_item[:page],
                     page_item[:page_id],
                     next_page_id,
                     next_page_id.nil?
                   )
                 end
      msp_pages << msp_page if msp_page
    end

    msp_pages
  end

  def build_msp_page_from_item(item, _page, item_page_id, next_page_id, is_last)
    # Each item becomes its own page in Apple MSP

    case item['item_type']
    when 'text', 'textArea', 'email', 'phone'
      {
        pageIdentifier: item_page_id,
        type: 'input',
        title: item['title'] || 'Input',
        subtitle: item['description'] || item['placeholder'] || '',
        nextPageIdentifier: next_page_id,
        submitForm: is_last,
        options: {
          required: item['required'] || false,
          inputType: item['item_type'] == 'textArea' ? 'multiline' : 'singleline',
          keyboardType: item['keyboard_type'] || (if item['item_type'] == 'email'
                                                    'emailAddress'
                                                  else
                                                    (item['item_type'] == 'phone' ? 'phonePad' : 'default')
                                                  end),
          placeholder: item['placeholder'] || '',
          textContentType: item['text_content_type'],
          maximumCharacterCount: item['max_length'] || 300
        }.compact
      }
    when 'singleSelect', 'multiSelect'
      multiple_selection = item['item_type'] == 'multiSelect'
      items_list = (item['options'] || []).map.with_index do |option, opt_index|
        item_data = {
          title: option['title'] || option['value'],
          value: option['value'],
          identifier: "#{item_page_id}_#{opt_index}"
        }
        # Add imageIdentifier if present (check both camelCase and snake_case)
        image_id = option['imageIdentifier'] || option['image_identifier']
        item_data[:imageIdentifier] = image_id if image_id.present?
        # For single select, each item can specify next page
        item_data[:nextPageIdentifier] = next_page_id if !multiple_selection && next_page_id
        item_data
      end

      page_data = {
        pageIdentifier: item_page_id,
        type: 'select',
        title: item['title'] || 'Select',
        subtitle: item['description'] || item['placeholder'] || 'Please select an option',
        multipleSelection: multiple_selection,
        items: items_list,
        submitForm: is_last
      }

      # For multiple selection, set nextPageIdentifier on page level
      page_data[:nextPageIdentifier] = next_page_id if multiple_selection && next_page_id
      page_data
    when 'dateTime'
      # Get current date/time for default values
      current_datetime = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
      # Set maximum date to 1 year from now to allow future bookings
      max_date = (Time.now.utc + 365.days).strftime('%Y-%m-%d')

      {
        pageIdentifier: item_page_id,
        type: 'datePicker',
        title: item['title'] || 'Select Date',
        subtitle: item['description'] || 'Please select a date and time',
        nextPageIdentifier: next_page_id,
        submitForm: is_last,
        options: {
          required: item['required'] || false,
          startDate: current_datetime,      # Default to current date/time
          maximumDate: max_date,            # Allow up to 1 year in the future
          labelText: item['title'] || 'Date'
        }.compact
      }
    when 'picker'
      # Handle picker type - use picker_type to determine the specific picker format
      case item['picker_type']
      when 'date', 'dateTime'
        # Get current date/time for default values
        current_datetime = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
        # Set maximum date to 1 year from now to allow future bookings
        max_date = (Time.now.utc + 365.days).strftime('%Y-%m-%d')

        {
          pageIdentifier: item_page_id,
          type: 'datePicker',
          title: item['title'] || 'Select Date',
          subtitle: item['description'] || 'Please select a date',
          nextPageIdentifier: next_page_id,
          submitForm: is_last,
          options: {
            required: item['required'] || false,
            startDate: current_datetime,      # Default to current date/time
            maximumDate: max_date,            # Allow up to 1 year in the future
            labelText: item['title'] || 'Date'
          }.compact
        }
      else
        # For unsupported picker types, fall back to text input
        Rails.logger.warn "[SendMessageService] Unsupported picker_type '#{item['picker_type']}' for item '#{item['title']}', falling back to text input"
        {
          pageIdentifier: item_page_id,
          type: 'input',
          title: item['title'] || 'Input',
          subtitle: item['description'] || item['placeholder'] || '',
          nextPageIdentifier: next_page_id,
          submitForm: is_last,
          options: {
            required: item['required'] || false,
            inputType: 'singleline',
            keyboardType: 'default',
            placeholder: item['placeholder'] || '',
            maximumCharacterCount: 300
          }.compact
        }
      end
    when 'toggle'
      {
        pageIdentifier: item_page_id,
        type: 'select',
        title: item['title'] || 'Toggle',
        subtitle: item['description'] || '',
        multipleSelection: false,
        nextPageIdentifier: next_page_id,
        submitForm: is_last,
        items: [
          { title: 'Yes', value: 'true', identifier: "#{item_page_id}_yes", nextPageIdentifier: next_page_id },
          { title: 'No', value: 'false', identifier: "#{item_page_id}_no", nextPageIdentifier: next_page_id }
        ]
      }
    when 'stepper'
      {
        pageIdentifier: item_page_id,
        type: 'input',
        title: item['title'] || 'Number',
        subtitle: item['description'] || "Enter a number between #{item['min_value']} and #{item['max_value']}",
        nextPageIdentifier: next_page_id,
        submitForm: is_last,
        options: {
          required: item['required'] || false,
          inputType: 'singleline',
          keyboardType: 'numberPad',
          placeholder: (item['default_value'] || item['min_value'] || '1').to_s
        }.compact
      }
    end
  end

  def build_msp_splash_page(page, page_id, next_page_id)
    # Build Apple MSP splash page format
    # Apple expects: type='splash', header, splashtext, buttonTitle (required), imageIdentifier (optional)
    {
      pageIdentifier: page_id,
      type: 'splash',
      header: page['header'],
      splashtext: page['splashtext'],
      buttonTitle: page['button_title'],
      imageIdentifier: page['image_identifier'],
      nextPageIdentifier: next_page_id
    }.compact
  end

  def convert_legacy_fields_to_msp(fields)
    return [] if fields.empty?

    # Create separate pages for each field (Apple MSP forms are page-based)
    pages = []

    fields.each_with_index do |field, index|
      page_id = index.to_s
      next_page_id = index + 1 < fields.length ? (index + 1).to_s : nil

      case field['type']
      when 'text', 'email'
        pages << {
          pageIdentifier: page_id,
          type: 'input',
          title: field['label'] || field['name'] || "Field #{index + 1}",
          subtitle: field['placeholder'] || 'Please enter your response',
          nextPageIdentifier: next_page_id,
          submitForm: next_page_id.nil?, # Last field submits form
          options: {
            required: field['required'] || false,
            inputType: 'singleline',
            keyboardType: field['type'] == 'email' ? 'emailAddress' : 'default',
            placeholder: field['placeholder'] || '',
            maximumCharacterCount: 300
          }.compact
        }
      when 'singleSelect', 'multiSelect'
        multiple_selection = field['type'] == 'multiSelect'
        items = (field['options'] || []).map.with_index do |option, opt_index|
          item_data = {
            title: option['title'] || option['label'] || option['value'],
            value: option['value'] || option['title'],
            identifier: "#{page_id}_#{opt_index}"
          }
          # Add imageIdentifier if present (check both camelCase and snake_case)
          image_id = option['imageIdentifier'] || option['image_identifier']
          item_data[:imageIdentifier] = image_id if image_id.present?
          # For single select, each item can specify next page
          item_data[:nextPageIdentifier] = next_page_id if !multiple_selection && next_page_id
          item_data
        end

        page_data = {
          pageIdentifier: page_id,
          type: 'select',
          title: field['label'] || field['name'] || "Field #{index + 1}",
          subtitle: field['placeholder'] || 'Please select an option',
          multipleSelection: multiple_selection,
          items: items,
          submitForm: next_page_id.nil? # Last field submits form
        }

        # For multiple selection, set nextPageIdentifier on page level
        page_data[:nextPageIdentifier] = next_page_id if multiple_selection && next_page_id

        pages << page_data
      when 'date', 'dateTime'
        pages << {
          pageIdentifier: page_id,
          type: 'datePicker',
          title: field['label'] || field['name'] || "Field #{index + 1}",
          subtitle: field['placeholder'] || 'Please select a date',
          nextPageIdentifier: next_page_id,
          submitForm: next_page_id.nil?, # Last field submits form
          options: {
            dateFormat: 'MM/dd/yyyy',
            startDate: Date.current.strftime('%m/%d/%Y')
          }
        }
      else
        # Default to input field for unknown types
        pages << {
          pageIdentifier: page_id,
          type: 'input',
          title: field['label'] || field['name'] || "Field #{index + 1}",
          subtitle: field['placeholder'] || 'Please enter your response',
          nextPageIdentifier: next_page_id,
          submitForm: next_page_id.nil?, # Last field submits form
          options: {
            required: field['required'] || false,
            inputType: 'singleline',
            placeholder: field['placeholder'] || '',
            maximumCharacterCount: 300
          }.compact
        }
      end
    end

    pages
  end

  # Legacy method for backward compatibility - now delegates to build_apple_msp_payload
  def message_payload
    build_apple_msp_payload(SecureRandom.uuid)
  end

  def source_id
    @channel.business_id
  end

  attr_reader :destination_id, :channel, :message

  def content_attributes
    @message.content_attributes || {}
  end

  def send_rich_link_message
    # Delegate to the specialized RichLinkService
    service = AppleMessagesForBusiness::SendRichLinkService.new(
      channel: @channel,
      destination_id: @destination_id,
      message: @message
    )

    service.perform
  end

  def send_apple_pay_message
    # Delegate to the specialized SendApplePayService
    # Extract payment data from message content_attributes
    payment_data = content_attributes.slice(
      'merchant_name',
      'currency_code',
      'country_code',
      'line_items',
      'total',
      'shipping_methods',
      'required_billing_fields',
      'required_shipping_fields',
      'received_title',
      'received_subtitle',
      'received_style',
      'received_image_identifier'
    )

    service = AppleMessagesForBusiness::SendApplePayService.new(
      channel: @channel,
      destination_id: @destination_id,
      payment_data: payment_data
    )

    service.perform
  end

  def process_attachments
    # Performance Note: To avoid N+1 queries, ensure @message is loaded with:
    # .includes(attachments: { file_attachment: :blob })
    # This preloads ActiveStorage attachments and blobs for all message attachments
    attachments = []

    @message.attachments.each do |attachment|
      if attachment.file.attached?
        result = upload_attachment(attachment)
        return { success: false, error: "Failed to upload attachment #{attachment.file.filename}" } if result.nil?

        attachments << result
      else
        # Handle external attachments
        attachments << {
          name: attachment.fallback_title,
          url: attachment.external_url,
          mimeType: attachment.file.content_type || 'application/octet-stream'
        }
      end
    end

    { success: true, attachments: attachments }
  end

  def upload_attachment(attachment)
    file_data = attachment.file.download
    encrypted_data, decryption_key = AppleMessagesForBusiness::AttachmentCipherService.encrypt(file_data)

    Rails.logger.info "Uploading attachment: #{attachment.file.filename} (#{file_data.size} bytes -> #{encrypted_data.size} bytes encrypted)"

    # Pre-upload to get upload URL
    upload_info = pre_upload_attachment(encrypted_data.size)

    # Upload encrypted data
    upload_response = upload_to_mmcs(upload_info[:upload_url], encrypted_data)

    attachment_data = {
      :name => attachment.file.filename.to_s,
      :mimeType => attachment.file.content_type,
      :size => file_data.size.to_s, # Use original file size, not encrypted size
      'signature-base64' => upload_response[:signature],
      :url => upload_info[:mmcs_url],
      :owner => upload_info[:mmcs_owner],
      :key => decryption_key
    }

    Rails.logger.info "Attachment upload successful: #{attachment_data}"
    attachment_data
  rescue StandardError => e
    Rails.logger.error "Attachment upload failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end

  def pre_upload_attachment(size)
    headers = {
      'Authorization' => "Bearer #{@channel.generate_jwt_token}",
      'Source-Id' => @channel.business_id,
      'MMCS-Size' => size.to_s
    }

    Rails.logger.info "Pre-upload request: #{AMB_SERVER}/preUpload with size: #{size}"

    response = HTTParty.get(
      "#{AMB_SERVER}/preUpload",
      headers: headers,
      timeout: 30
    )

    Rails.logger.info "Pre-upload response: #{response.code} - #{response.body}"

    raise "Pre-upload failed: #{response.code} #{response.body}" unless response.success?

    parsed = response.parsed_response
    {
      upload_url: parsed['upload-url'],
      mmcs_url: parsed['mmcs-url'],
      mmcs_owner: parsed['mmcs-owner']
    }
  end

  def upload_to_mmcs(upload_url, encrypted_data)
    headers = {
      'Content-Length' => encrypted_data.size.to_s,
      'Content-Type' => 'application/octet-stream'
    }

    Rails.logger.info "MMCS upload to: #{upload_url} with size: #{encrypted_data.size}"

    response = HTTParty.post(
      upload_url,
      body: encrypted_data,
      headers: headers,
      timeout: 60
    )

    Rails.logger.info "MMCS upload response: #{response.code} - #{response.body}"

    raise "MMCS upload failed: #{response.code} #{response.body}" unless response.success?

    parsed = response.parsed_response
    signature = parsed.dig('singleFile', 'fileChecksum')

    if signature.nil?
      Rails.logger.error "No fileChecksum in MMCS response: #{parsed}"
      raise 'MMCS upload failed: No fileChecksum in response'
    end

    {
      signature: signature
    }
  end

  def send_to_apple_gateway(payload, message_id, request_idr: false, content_type: nil)
    # PRE-SEND VALIDATION: Validate payload before sending to Apple MSP
    begin
      # Debug: Log the actual payload structure (sanitized to avoid base64 spam)
      Rails.logger.info "[AMB Send] Payload keys: #{payload.keys.inspect}"
      Rails.logger.info "[AMB Send] interactiveData keys: #{payload[:interactiveData]&.keys&.inspect}"
      Rails.logger.info "[AMB Send] data keys: #{payload[:interactiveData]&.dig(:data)&.keys&.inspect}"
      Rails.logger.info "[AMB Send] event keys: #{payload[:interactiveData]&.dig(:data, :event)&.keys&.inspect}"

      # Sanitize event content before logging to avoid base64 spam
      event_data = payload[:interactiveData]&.dig(:data, :event)
      if event_data
        sanitized_event = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(event_data)
        Rails.logger.info "[AMB Send] event content: #{sanitized_event.inspect}"
      end

      # Get content_type from parameter, message, or default to 'apple_pay' for direct Apple Pay requests
      content_type ||= @message&.content_type || 'apple_pay'

      # Skip strict validation for custom payloads - users can send any structure
      # Apple MSP will reject if truly invalid
      if content_type == 'apple_custom_payload'
        Rails.logger.info '[AMB Send] Skipping PayloadValidator for custom payload (user controls structure)'
      else
        validator = AppleMessagesForBusiness::PayloadValidatorService.new(payload, content_type)
        validator.validate!
      end
    rescue AppleMessagesForBusiness::PayloadValidatorService::ValidationError => e
      Rails.logger.error "[AMB Send] Payload validation failed: #{e.message}"
      # Log the invalid payload for debugging (sanitized to avoid base64 spam)
      sanitized_payload = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(payload)
      Rails.logger.error "[AMB Send] Invalid payload: #{sanitized_payload.to_json}"
      # Return error response instead of sending to Apple
      return OpenStruct.new(
        success?: false,
        code: 400,
        body: { error: 'Payload validation failed', details: e.message }.to_json
      )
    end

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@channel.generate_jwt_token}",
      'id' => message_id,
      'Source-Id' => @channel.business_id,
      'Destination-Id' => @destination_id
    }

    # Add include-data-ref header if requesting IDR for large responses
    if request_idr
      headers['include-data-ref'] = 'true'
      Rails.logger.info "[AMB Send] Requesting IDR for message #{message_id} (payload size: #{payload.to_json.bytesize} bytes)"
    end

    # Debug: Log the actual payload being sent for list pickers (sanitized to avoid base64 spam)
    if payload[:interactiveData] && payload[:interactiveData][:data] && payload[:interactiveData][:data][:listPicker]
      list_picker = payload[:interactiveData][:data][:listPicker]
      sanitized_list_picker = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(list_picker)
      log_info "[AMB Send] 🔍 Final listPicker payload: #{sanitized_list_picker.to_json}"
      if list_picker[:sections]&.first && list_picker[:sections].first['items']
        first_item = list_picker[:sections].first['items'].first
        log_info "[AMB Send] 🔍 First item keys: #{first_item.keys.inspect}"
        sanitized_first_item = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(first_item)
        log_info "[AMB Send] 🔍 First item: #{sanitized_first_item.to_json}"
      end
    end

    HTTParty.post(
      "#{AMB_SERVER}/message",
      body: payload.to_json,
      headers: headers,
      timeout: 30
    )
  end

  def should_request_idr?(_payload)
    # TEMPORARY: Disable IDR for all messages due to URL expiration issues in dev/sandbox
    # IDR URLs from Apple expire within 1-2 seconds, causing 404 errors before we can download
    # This forces Apple to send the full response inline instead of via IDR
    Rails.logger.info '[AMB Send] IDR disabled - sending full payload inline'
    return false

    # Original logic below (commented out for now):
    # Request IDR when the payload is likely to result in a large response
    # This is especially important for list pickers with images

    # payload_size = payload.to_json.bytesize

    # # Always request IDR for payloads > 8KB, as responses may exceed 10KB
    # return true if payload_size > 8192

    # # Request IDR for list pickers and time pickers with images
    # if payload[:interactiveData] && payload[:interactiveData][:data]
    #   interactive_data = payload[:interactiveData][:data]

    #   # List picker with images is likely to produce large responses
    #   if interactive_data[:listPicker] && interactive_data[:images]&.any?
    #     Rails.logger.info '[AMB Send] Requesting IDR for list picker with images'
    #     return true
    #   end

    #   # Time picker with multiple time slots may also produce large responses
    #   if interactive_data[:timePicker] && interactive_data[:images]&.any?
    #     Rails.logger.info '[AMB Send] Requesting IDR for time picker with images'
    #     return true
    #   end
    # end

    # # For other cases, let Apple decide based on actual response size
    # false
  end

  def user_opted_out?
    # Check if this user has opted out of receiving messages
    # as per Apple MSP specification requirement

    # Find contact by Apple Messages source ID (destination_id is the user's opaque ID)
    contact = Contact.joins(:contact_inboxes)
                     .where(contact_inboxes: { inbox: @channel.inbox })
                     .where("additional_attributes->>'apple_messages_source_id' = ?", @destination_id)
                     .where("additional_attributes->>'apple_messages_blocked' = ?", 'true')
                     .first

    if contact
      Rails.logger.info "[AMB Send] User #{@destination_id} is blocked - opted out at #{contact.additional_attributes['apple_messages_blocked_at']}"
      return true
    end

    false
  end
end
