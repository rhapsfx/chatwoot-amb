class AppleMessagesForBusiness::SendTimePickerService < AppleMessagesForBusiness::SendMessageService
  # Override to add image saving before sending
  def perform_send
    # Save images before sending
    save_images_to_storage

    # Call parent perform_send
    super
  end

  # Override parent's build_interactive_data to include images
  def build_interactive_data
    base_data = {
      bid: 'com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension',
      data: {
        mspVersion: '1.0',
        requestIdentifier: valid_or_generated_request_identifier,
        event: build_time_picker_data
      },
      receivedMessage: build_received_message,
      replyMessage: build_reply_message
    }

    # Images must be inside data (interactiveData.data.images) per Apple MSP spec.
    # receivedMessage/replyMessage imageIdentifier references interactiveData.data.images.
    images = build_images_array
    base_data[:data][:images] = images if images.present?

    Rails.logger.info "[AMB TimePicker] build_interactive_data - Images in data: #{images&.length || 0}"

    base_data
  end

  private

  def save_images_to_storage
    images = content_attributes['images'] || []
    Rails.logger.info "[AMB TimePicker] save_images_to_storage called with #{images.length} images"
    return if images.empty?

    # Performance Optimization: Batch fetch all existing images to avoid N+1 queries
    # This replaces multiple find_by_identifier calls with a single WHERE IN query
    image_identifiers = images.map { |img| img['identifier'] }.compact.uniq
    existing_images = AppleListPickerImage
                      .where(inbox_id: message.inbox_id, identifier: image_identifiers)
                      .includes(image_attachment: :blob)
                      .index_by(&:identifier)

    Rails.logger.info "[AMB TimePicker] Batch loaded #{existing_images.size} existing images (avoiding N+1 queries)"

    images.each do |image_data|
      Rails.logger.info "[AMB TimePicker] Processing image: #{image_data['identifier']}, has data: #{image_data['data'].present?}"
      next if image_data['identifier'].blank? || image_data['data'].blank?

      # Use pre-loaded existing image (no database query here)
      existing_image = existing_images[image_data['identifier']]

      Rails.logger.info "[AMB TimePicker] Existing image found: #{existing_image.present?}, has attachment: #{existing_image&.image&.attached?}"

      # Skip if already saved
      next if existing_image&.image&.attached?

      # Create or update the image record
      picker_image = existing_image || AppleListPickerImage.new(
        account_id: message.account_id,
        inbox_id: message.inbox_id,
        identifier: image_data['identifier']
      )

      picker_image.description = image_data['description']
      picker_image.original_name = image_data['originalName'] || image_data['identifier']

      # Decode base64 and attach to ActiveStorage
      begin
        decoded_data = Base64.strict_decode64(image_data['data'])

        # Determine filename and content type
        filename = picker_image.original_name || "#{image_data['identifier']}.jpg"
        content_type = determine_content_type(decoded_data, filename)

        # Attach to ActiveStorage
        picker_image.image.attach(
          io: StringIO.new(decoded_data),
          filename: filename,
          content_type: content_type
        )

        picker_image.save!
        Rails.logger.info "[AMB TimePicker] Successfully saved image to ActiveStorage: #{image_data['identifier']}"
      rescue StandardError => e
        Rails.logger.error "[AMB TimePicker] Failed to save image #{image_data['identifier']}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        # Continue processing other images
      end
    end
  end

  def build_time_picker_data
    event_data = content_attributes['event'] || {}

    Rails.logger.info '[AMB TimePicker] build_time_picker_data - Reading from database:'
    sanitized_event = LogSanitizerService.sanitize_for_log(content_attributes['event'])
    Rails.logger.info "[AMB TimePicker] content_attributes['event']: #{sanitized_event.inspect}"
    sanitized_timeslots = LogSanitizerService.sanitize_for_log(event_data['timeslots'])
    Rails.logger.info "[AMB TimePicker] event_data['timeslots']: #{sanitized_timeslots.inspect}"

    # Build event with snake_case, then transform to Apple format
    event = {
      'identifier' => event_data['identifier'].presence || SecureRandom.uuid,
      'title' => event_data['title'].presence || 'Select a time',
      'image_identifier' => event_data['image_identifier'],
      'location' => build_location_data(event_data['location']),
      'timeslots' => build_timeslots(event_data['timeslots'] || default_timeslots),
      'timezone_offset' => event_data['timezone_offset']
    }

    # Transform to Apple format (camelCase)
    AppleMessagesForBusiness::CaseTransformer.to_apple_format(event)
  end

  def build_location_data(location)
    return nil unless location

    {
      latitude: location['latitude']&.to_f,
      longitude: location['longitude']&.to_f,
      radius: location['radius']&.to_f || 100.0,
      title: location['title']
    }
  end

  def build_timeslots(timeslots)
    Rails.logger.info "[AMB TimePicker] build_timeslots called with #{timeslots&.length || 0} slots"

    timeslots.map.with_index do |slot, index|
      Rails.logger.info "[AMB TimePicker] Slot #{index}: #{slot.inspect}"
      Rails.logger.info "[AMB TimePicker] Slot #{index} keys: #{slot.keys.inspect}"
      Rails.logger.info "[AMB TimePicker] Slot #{index} start_time (string key): #{slot['start_time'].inspect}"
      Rails.logger.info "[AMB TimePicker] Slot #{index} start_time (symbol key): #{slot[:start_time].inspect}"

      # Use snake_case internally, CaseTransformer will handle conversion
      # Handle both string and symbol keys
      start_time_value = slot['start_time'] || slot[:start_time]

      result = {
        'identifier' => (slot['identifier'] || slot[:identifier]).presence || SecureRandom.uuid,
        'start_time' => format_iso8601_time(start_time_value),
        'duration' => (slot['duration'] || slot[:duration])&.to_i || 3600 # Default 1 hour in seconds
      }

      Rails.logger.info "[AMB TimePicker] Slot #{index} result: #{result.inspect}"
      result
    end
  end

  def format_iso8601_time(time_input)
    return nil unless time_input

    # Parse various time formats and convert to ISO-8601 format required by Apple
    # Format: 2017-05-26T08:27+0000 (NO seconds, no Z notation)
    # Apple's device expects this format without seconds
    time = case time_input
           when String
             Time.parse(time_input)
           when Integer
             Time.at(time_input)
           when Time
             time_input
           else
             Time.current
           end

    time.utc.strftime('%Y-%m-%dT%H:%M+0000')
  rescue ArgumentError
    # Fallback to current time if parsing fails
    Time.current.utc.strftime('%Y-%m-%dT%H:%M+0000')
  end

  def build_images_array
    Rails.logger.info '[AMB TimePicker] build_images_array called'

    # Collect all image identifiers referenced in event, received_message, and reply_message
    # All data is now normalized to snake_case
    image_identifiers = []
    event_data = content_attributes['event'] || {}
    image_identifiers << event_data['image_identifier']
    image_identifiers << content_attributes['received_image_identifier']
    image_identifiers << content_attributes['reply_image_identifier']
    image_identifiers.compact!
    image_identifiers.uniq!

    Rails.logger.info "[AMB TimePicker] Collected image identifiers: #{image_identifiers.inspect}"

    # Use ImageFetchService with three-tier fallback
    fetch_and_encode_images(image_identifiers)
  end

  def fetch_and_encode_images(identifiers)
    return [] if identifiers.empty?

    # Use ImageFetchService with three-tier fallback
    AppleMessagesForBusiness::ImageFetchService.new(
      account_id: message.account_id,
      inbox_id: message.inbox_id,
      embedded_images: content_attributes['images']
    ).fetch_and_encode(identifiers)
  end

  def build_received_message
    received_msg = {
      'title' => content_attributes['received_title'] || 'Select a time',
      'subtitle' => content_attributes['received_subtitle'],
      'image_identifier' => content_attributes['received_image_identifier'],
      'style' => content_attributes['received_style'] || 'icon'
    }

    # Transform to Apple format (camelCase) with received_message context
    AppleMessagesForBusiness::CaseTransformer.to_apple_format(received_msg, context: :received_message)
  end

  def build_reply_message
    # If reply image is not specified, reuse the received image identifier
    # This follows Apple MSP best practice: reply message should show the same image as received message
    reply_image_id = content_attributes['reply_image_identifier']
    reply_image_id = content_attributes['received_image_identifier'] if reply_image_id.blank?

    reply_msg = {
      'title' => content_attributes['reply_title'] || 'Selected: ${event.title}',
      'subtitle' => content_attributes['reply_subtitle'],
      'image_identifier' => reply_image_id,
      'style' => content_attributes['reply_style'] || 'icon'
    }

    # Transform to Apple format (camelCase) with reply_message context
    AppleMessagesForBusiness::CaseTransformer.to_apple_format(reply_msg, context: :reply_message)
  end

  def default_timeslots
    # Provide some default time slots for the next few hours
    base_time = Time.current.beginning_of_hour + 1.hour

    3.times.map do |i|
      slot_time = base_time + (i * 2).hours
      {
        'identifier' => SecureRandom.uuid,
        'start_time' => slot_time.iso8601,
        'duration' => 3600
      }
    end
  end

  def content_attributes
    @content_attributes ||= message.content_attributes || {}
  end
end
