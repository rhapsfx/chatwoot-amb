# frozen_string_literal: true

# Pre-send validation service for Apple Messages for Business payloads
# Validates payload structure, ISO 8601 dates, and base64 image encoding
# before sending to mspgw.apple.com
class AppleMessagesForBusiness::PayloadValidatorService
  class ValidationError < StandardError; end

  def initialize(payload, message_type)
    @payload = payload
    @message_type = message_type
    @errors = []
  end

  def validate!
    Rails.logger.info "[AMB PayloadValidator] Validating #{@message_type} payload before sending to Apple MSP"

    validate_payload_structure
    validate_required_fields
    validate_iso8601_dates
    validate_base64_images

    if @errors.any?
      error_message = "Payload validation failed: #{@errors.join(', ')}"
      Rails.logger.error "[AMB PayloadValidator] #{error_message}"
      raise ValidationError, error_message
    end

    Rails.logger.info '[AMB PayloadValidator] ✅ Payload validation passed'
    log_payload_summary
    true
  end

  private

  def validate_payload_structure
    # Validate basic payload structure
    unless @payload.is_a?(Hash)
      @errors << 'Payload must be a hash'
      return
    end

    # Validate required top-level fields
    required_fields = %i[v id sourceId destinationId type]
    required_fields.each do |field|
      @errors << "Missing required field: #{field}" unless @payload[field].present?
    end

    # Validate version
    @errors << 'Invalid version (must be 1)' unless @payload[:v] == 1

    # Validate type
    valid_types = %w[text interactive]
    @errors << "Invalid type: #{@payload[:type]}" unless valid_types.include?(@payload[:type])
  end

  def validate_required_fields
    case @payload[:type]
    when 'text'
      validate_text_message
    when 'interactive'
      validate_interactive_message
    end
  end

  def validate_text_message
    # Text messages require body field
    @errors << 'Text message missing body field' unless @payload[:body].present?
  end

  def validate_interactive_message
    # Interactive messages require interactiveData
    unless @payload[:interactiveData].present?
      @errors << 'Interactive message missing interactiveData'
      return
    end

    interactive_data = @payload[:interactiveData]

    # Validate bid
    @errors << 'interactiveData missing bid' unless interactive_data[:bid].present?

    # Validate data structure
    unless interactive_data[:data].present?
      @errors << 'interactiveData missing data'
      return
    end

    data = interactive_data[:data]

    # Validate based on message type
    case @message_type
    when 'apple_list_picker'
      validate_list_picker_data(data)
    when 'apple_time_picker'
      validate_time_picker_data(data)
    when 'apple_quick_reply'
      validate_quick_reply_data(data)
    when 'apple_form'
      validate_form_data(data)
    end
  end

  def validate_list_picker_data(data)
    unless data[:listPicker].present?
      @errors << 'List picker data missing listPicker field'
      return
    end

    list_picker = data[:listPicker]

    # Validate sections
    unless list_picker[:sections].is_a?(Array) && list_picker[:sections].any?
      @errors << 'List picker must have at least one section'
      return
    end

    # Validate each section
    list_picker[:sections].each_with_index do |section, index|
      validate_list_picker_section(section, index)
    end
  end

  def validate_list_picker_section(section, index)
    @errors << "Section #{index} missing items" unless section['items'].is_a?(Array) && section['items'].any?

    # Validate each item
    section['items']&.each_with_index do |item, item_index|
      validate_list_picker_item(item, index, item_index)
    end
  end

  def validate_list_picker_item(item, section_index, item_index)
    @errors << "Section #{section_index} item #{item_index} missing identifier" unless item['identifier'].present?
    @errors << "Section #{section_index} item #{item_index} missing title" unless item['title'].present?

    # Validate style if present
    return unless item['style'].present?

    valid_styles = %w[icon small large]
    return if valid_styles.include?(item['style'])

    @errors << "Section #{section_index} item #{item_index} has invalid style: #{item['style']}"
  end

  def validate_time_picker_data(data)
    unless data[:event].present?
      @errors << 'Time picker data missing event field'
      return
    end

    event = data[:event]

    # Validate timeslots
    unless event['timeslots'].is_a?(Array) && event['timeslots'].any?
      @errors << 'Time picker event must have at least one timeslot'
      return
    end

    # Validate each timeslot
    event['timeslots'].each_with_index do |slot, index|
      validate_timeslot(slot, index)
    end
  end

  def validate_timeslot(slot, index)
    @errors << "Timeslot #{index} missing identifier" unless slot['identifier'].present?
    @errors << "Timeslot #{index} missing startTime" unless slot['startTime'].present?
    @errors << "Timeslot #{index} missing duration" unless slot['duration'].present?
  end

  def validate_quick_reply_data(data)
    quick_reply = data[:'quick-reply']

    unless quick_reply.present?
      @errors << 'Quick reply data missing quick-reply field'
      return
    end

    # Validate items
    unless quick_reply[:items].is_a?(Array) && quick_reply[:items].any?
      @errors << 'Quick reply must have at least one item'
      return
    end

    # Apple MSP requires 2-5 items for quick reply
    item_count = quick_reply[:items].length
    @errors << "Quick reply must have 2-5 items (has #{item_count})" unless item_count.between?(2, 5)

    # Validate each item
    quick_reply[:items].each_with_index do |item, index|
      @errors << "Quick reply item #{index} missing identifier" unless item['identifier'].present?
      @errors << "Quick reply item #{index} missing title" unless item['title'].present?
    end
  end

  def validate_form_data(data)
    unless data[:dynamic].present?
      @errors << 'Form data missing dynamic field'
      return
    end

    dynamic = data[:dynamic]

    # Validate pages
    unless dynamic[:pages].is_a?(Array) && dynamic[:pages].any?
      @errors << 'Form must have at least one page'
      return
    end

    # Validate each page
    dynamic[:pages].each_with_index do |page, index|
      validate_form_page(page, index)
    end
  end

  def validate_form_page(page, index)
    @errors << "Form page #{index} missing pageIdentifier" unless page[:pageIdentifier].present?
    @errors << "Form page #{index} missing type" unless page[:type].present?
    @errors << "Form page #{index} missing title" unless page[:title].present?
  end

  def validate_iso8601_dates
    # Validate ISO 8601 date formats in time picker timeslots
    return unless @message_type == 'apple_time_picker'
    return unless @payload[:interactiveData]&.dig(:data, :event, 'timeslots')

    timeslots = @payload[:interactiveData][:data][:event]['timeslots']

    timeslots.each_with_index do |slot, index|
      start_time = slot['startTime']
      next unless start_time.present?

      @errors << "Timeslot #{index} has invalid ISO 8601 startTime: #{start_time}" unless valid_iso8601_datetime?(start_time)
    end
  end

  def valid_iso8601_datetime?(datetime_string)
    # Valid formats:
    # - 2024-01-15T14:30:00+0000 (with timezone)
    # - 2024-01-15T14:30:00Z (UTC)
    # - 2024-01-15T14:30:00 (local time, less preferred)

    return false unless datetime_string.is_a?(String)

    # Check basic ISO 8601 format
    iso8601_regex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}([+-]\d{4}|Z)?$/
    return false unless datetime_string.match?(iso8601_regex)

    # Try to parse it
    Time.parse(datetime_string)
    true
  rescue ArgumentError
    false
  end

  def validate_base64_images
    # Validate base64 encoding for images in interactive messages
    return unless @payload[:interactiveData]&.dig(:data, :images)

    images = @payload[:interactiveData][:data][:images]

    images.each_with_index do |image, index|
      validate_image(image, index)
    end
  end

  def validate_image(image, index)
    # Validate identifier
    unless image[:identifier].present? || image['identifier'].present?
      @errors << "Image #{index} missing identifier"
      return
    end

    # Validate data field
    data = image[:data] || image['data']
    unless data.present?
      @errors << "Image #{index} missing data field"
      return
    end

    # Validate base64 encoding
    @errors << "Image #{index} has invalid base64 encoding" unless valid_base64?(data)

    # Validate base64 data size (Apple has limits)
    decoded_size = Base64.decode64(data).bytesize
    max_size = 10 * 1024 * 1024 # 10MB limit
    return unless decoded_size > max_size

    @errors << "Image #{index} exceeds maximum size (#{decoded_size} bytes > #{max_size} bytes)"
  end

  def valid_base64?(string)
    return false unless string.is_a?(String)
    return false if string.empty?

    # Base64 should only contain A-Z, a-z, 0-9, +, /, and = for padding
    return false unless string.match?(%r{^[A-Za-z0-9+/]*={0,2}$})

    # Try to decode it
    Base64.strict_decode64(string)
    true
  rescue ArgumentError
    false
  end

  def log_payload_summary
    summary = {
      type: @payload[:type],
      message_type: @message_type,
      payload_size: @payload.to_json.bytesize,
      has_images: @payload[:interactiveData]&.dig(:data, :images)&.any? || false,
      image_count: @payload[:interactiveData]&.dig(:data, :images)&.length || 0
    }

    case @message_type
    when 'apple_list_picker'
      list_picker = @payload[:interactiveData]&.dig(:data, :listPicker)
      summary[:section_count] = list_picker&.dig(:sections)&.length || 0
      summary[:total_items] = list_picker&.dig(:sections)&.sum { |s| s['items']&.length || 0 } || 0
    when 'apple_time_picker'
      event = @payload[:interactiveData]&.dig(:data, :event)
      summary[:timeslot_count] = event&.dig('timeslots')&.length || 0
    when 'apple_quick_reply'
      quick_reply = @payload[:interactiveData]&.dig(:data, :'quick-reply')
      summary[:item_count] = quick_reply&.dig(:items)&.length || 0
    when 'apple_form'
      dynamic = @payload[:interactiveData]&.dig(:data, :dynamic)
      summary[:page_count] = dynamic&.dig(:pages)&.length || 0
    end

    Rails.logger.info "[AMB PayloadValidator] Payload summary: #{summary.to_json}"
  end
end
