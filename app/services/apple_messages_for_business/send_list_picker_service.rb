class AppleMessagesForBusiness::SendListPickerService < AppleMessagesForBusiness::SendMessageService
  # Override to add image saving before sending
  def perform_send
    # Save images before sending
    save_images_to_storage

    # Call parent perform_send
    super
  end

  # Override to update content_attributes with images after successful send
  def send_interactive_message
    result = super

    # If send was successful, update content_attributes with images from payload
    update_content_attributes_with_images if result[:success] && @message.apple_msp_payload.present?

    result
  end

  private

  def update_content_attributes_with_images
    payload = @message.apple_msp_payload
    interactive_data = payload['interactiveData'] || payload[:interactiveData]
    return unless interactive_data

    data = interactive_data['data'] || interactive_data[:data]
    received_message = interactive_data['receivedMessage'] || interactive_data[:receivedMessage]

    # Update content_attributes with images and received_image_identifier
    updated_attrs = @message.content_attributes.dup

    # Copy images array from payload to content_attributes
    if data && data['images'].present?
      updated_attrs['images'] = data['images']
      Rails.logger.info "[AMB ListPicker] Copied #{data['images'].length} images to content_attributes"
    end

    # Copy received_image_identifier from receivedMessage
    if received_message && received_message['imageIdentifier'].present?
      updated_attrs['received_image_identifier'] = received_message['imageIdentifier']
      Rails.logger.info "[AMB ListPicker] Copied received_image_identifier: #{received_message['imageIdentifier']}"
    end

    # Update the message with the new content_attributes
    # Silence SQL logging to avoid base64 spam in logs
    ActiveRecord::Base.logger.silence do
      @message.update(content_attributes: updated_attrs)
    end

    Rails.logger.info '[AMB ListPicker] Updated content_attributes with images for frontend display'
  rescue StandardError => e
    Rails.logger.error "[AMB ListPicker] Failed to update content_attributes with images: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  # Override parent to use transformed images
  def build_interactive_data
    base_data = super

    # Replace the raw images with properly formatted ones (base64 data)
    if content_attributes['images'].present?
      base_data[:data][:images] = build_images_array
      Rails.logger.info "[AMB ListPicker] Added #{base_data[:data][:images].length} formatted images to payload"
      # Debug: log image identifiers being sent
      Rails.logger.info "[AMB ListPicker] Image identifiers: #{base_data[:data][:images].pluck(:identifier).join(', ')}"
      # Debug: log first 100 chars of first image data
      if base_data[:data][:images].first
        first_img = base_data[:data][:images].first
        Rails.logger.info "[AMB ListPicker] First image data present: #{first_img[:data].present?}, length: #{first_img[:data]&.length}"
      end
    end

    base_data
  end

  def save_images_to_storage
    images = content_attributes['images'] || []
    Rails.logger.info "[AMB ListPicker] save_images_to_storage called with #{images.length} images"
    return if images.empty?

    # Performance Optimization: Batch fetch all existing images to avoid N+1 queries
    # This replaces multiple find_by_identifier calls with a single WHERE IN query
    image_identifiers = images.filter_map { |img| img['identifier'] }.uniq

    # Check SharedAppleImage first - don't create inbox-specific duplicates
    shared_images = SharedAppleImage
                    .where(account_id: message.account_id, identifier: image_identifiers)
                    .pluck(:identifier)

    if shared_images.any?
      Rails.logger.info "[AMB ListPicker] Found #{shared_images.length} images in SharedAppleImage - skipping inbox-specific storage"
      Rails.logger.info "[AMB ListPicker] Shared identifiers: #{shared_images.join(', ')}"
    end

    # Only fetch inbox-specific images for identifiers NOT in SharedAppleImage
    inbox_only_identifiers = image_identifiers - shared_images
    existing_images = AppleListPickerImage
                      .where(inbox_id: message.inbox_id, identifier: inbox_only_identifiers)
                      .includes(image_attachment: :blob)
                      .index_by(&:identifier)

    Rails.logger.info "[AMB ListPicker] Batch loaded #{existing_images.size} existing inbox-specific images (avoiding N+1 queries)"

    # Performance Optimization: Process images in batches to control memory usage
    # and provide better progress tracking for large image sets
    batch_size = 10
    total_batches = (images.length.to_f / batch_size).ceil
    successful_count = 0
    failed_count = 0
    skipped_count = 0

    images.each_slice(batch_size).with_index do |batch, batch_index|
      Rails.logger.info "[AMB ListPicker] Processing batch #{batch_index + 1}/#{total_batches} (#{batch.length} images)"

      batch.each do |image_data|
        Rails.logger.info "[AMB ListPicker] Processing image: #{image_data['identifier']}, has data: #{image_data['data'].present?}"

        # Skip invalid images
        unless image_data['identifier'].present? && image_data['data'].present?
          Rails.logger.warn '[AMB ListPicker] Skipping image with missing identifier or data'
          skipped_count += 1
          next
        end

        # Skip images that exist in SharedAppleImage - they'll be fetched from there
        if shared_images.include?(image_data['identifier'])
          Rails.logger.info "[AMB ListPicker] Image #{image_data['identifier']} exists in SharedAppleImage, skipping inbox-specific storage"
          skipped_count += 1
          next
        end

        # Use pre-loaded existing image (no database query here)
        existing_image = existing_images[image_data['identifier']]

        Rails.logger.info "[AMB ListPicker] Existing image found: #{existing_image.present?}, has attachment: #{existing_image&.image&.attached?}"

        # Skip if already saved with attachment
        if existing_image&.image&.attached?
          Rails.logger.info "[AMB ListPicker] Image #{image_data['identifier']} already exists, skipping"
          skipped_count += 1
          next
        end

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
          # Validate base64 format before decoding
          unless %r{\A[A-Za-z0-9+/]*={0,2}\z}.match?(image_data['data'])
            Rails.logger.error "[AMB ListPicker] Invalid base64 format for image #{image_data['identifier']}"
            failed_count += 1
            next
          end

          decoded_data = Base64.strict_decode64(image_data['data'])

          # Validate decoded data size (prevent memory issues)
          max_size = 10.megabytes
          if decoded_data.bytesize > max_size
            Rails.logger.error "[AMB ListPicker] Image #{image_data['identifier']} exceeds max size (#{decoded_data.bytesize} bytes > #{max_size} bytes)"
            failed_count += 1
            next
          end

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
          successful_count += 1
          Rails.logger.info "[AMB ListPicker] Successfully saved image to ActiveStorage: #{image_data['identifier']}"
        rescue ArgumentError => e
          Rails.logger.error "[AMB ListPicker] Base64 decode failed for image #{image_data['identifier']}: #{e.message}"
          failed_count += 1
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[AMB ListPicker] Validation failed for image #{image_data['identifier']}: #{e.message}"
          failed_count += 1
        rescue StandardError => e
          Rails.logger.error "[AMB ListPicker] Failed to save image #{image_data['identifier']}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          failed_count += 1

          # Clear decoded data from memory after processing
        end
      end

      # Log batch completion with progress
      Rails.logger.info "[AMB ListPicker] Batch #{batch_index + 1}/#{total_batches} completed"
    end

    # Log final summary with statistics
    Rails.logger.info "[AMB ListPicker] Image processing complete: #{successful_count} successful, #{skipped_count} skipped, #{failed_count} failed out of #{images.length} total"
  end

  # Override parent to properly transform section/item keys
  def build_list_picker_data
    sections = content_attributes['sections'] || []

    # Use CaseTransformer to convert snake_case → camelCase for Apple MSP
    # This handles all field transformations automatically and consistently
    transformed_sections = sections.map.with_index do |section, section_index|
      # Set defaults for required fields
      # Use fetch() to properly handle nil vs false distinction
      section_with_defaults = section.merge(
        'order' => section.fetch('order', section_index),
        'multiple_selection' => section.fetch('multiple_selection', false)
      )

      # Transform items if present
      if section['items'].present?
        section_with_defaults['items'] = section['items'].map.with_index do |item, item_index|
          item.merge(
            'identifier' => item['identifier'].presence || SecureRandom.uuid,
            'order' => item['order'] || item_index,
            'style' => item['style'] || 'icon'
          )
        end
      end

      # Convert entire section (and nested items) to Apple format
      AppleMessagesForBusiness::CaseTransformer.to_apple_format(section_with_defaults)
    end

    { sections: transformed_sections }
  end

  def build_images_array
    # Extract all image identifiers from list picker config
    identifiers = extract_image_identifiers
    return [] if identifiers.empty?

    # Fetch and encode images from database
    fetch_and_encode_images(identifiers)
  end

  def extract_image_identifiers
    identifiers = Set.new

    # Add header image from received_message
    header_image = content_attributes['received_image_identifier']
    identifiers << header_image if header_image.present?

    # Add reply image if different from header
    reply_image = content_attributes['reply_image_identifier']
    identifiers << reply_image if reply_image.present? && reply_image != header_image

    # Add images from list picker items
    sections = content_attributes['sections']
    if sections.is_a?(Array)
      sections.each do |section|
        items = section['items']
        next unless items.is_a?(Array)

        items.each do |item|
          image_id = item['image_identifier']
          identifiers << image_id if image_id.present?
        end
      end
    end

    identifiers.to_a
  end

  def fetch_and_encode_images(identifiers)
    return [] if identifiers.empty?

    # Use ImageFetchService with three-tier fallback:
    # 1. Inbox-specific images (AppleListPickerImage)
    # 2. Account-wide shared images (SharedAppleImage) - future
    # 3. Embedded images (content_attributes['images'])
    AppleMessagesForBusiness::ImageFetchService.new(
      account_id: message.account_id,
      inbox_id: message.inbox_id,
      embedded_images: content_attributes['images']
    ).fetch_and_encode(identifiers)
  end

  def build_received_message
    received_msg = {
      'title' => content_attributes['received_title'] || 'Please select an option',
      'subtitle' => content_attributes['received_subtitle'],
      'image_identifier' => content_attributes['received_image_identifier'],
      'style' => content_attributes['received_style'] || 'small'
    }

    # Transform to Apple format (camelCase) with received_message context
    AppleMessagesForBusiness::CaseTransformer.to_apple_format(received_msg, context: :received_message)
  end

  def build_reply_message
    reply_msg = {
      'title' => content_attributes['reply_title'] || 'Selected: ${item.title}',
      'subtitle' => content_attributes['reply_subtitle'],
      'image_identifier' => content_attributes['reply_image_identifier'],
      'style' => content_attributes['reply_style'] || 'icon'
    }

    # Transform to Apple format (camelCase) with reply_message context
    AppleMessagesForBusiness::CaseTransformer.to_apple_format(reply_msg, context: :reply_message)
  end

  def default_section
    {
      'title' => 'Options',
      'multiple_selection' => false,
      'items' => []
    }
  end

  def content_attributes
    @content_attributes ||= message.content_attributes || {}
  end
end
