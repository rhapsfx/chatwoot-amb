# frozen_string_literal: true

# Adapter to convert unified templates to Apple Messages for Business format
# Reuses existing AMB service logic for consistency
#
# Usage:
#   adapter = Templates::Adapters::AppleMessagesTemplateAdapter.new(
#     content_blocks: processed_blocks,
#     template: template,
#     parameters: { ... }
#   )
#   result = adapter.adapt
#
# Returns:
#   {
#     content_type: 'apple_time_picker',
#     content: 'Select a time',
#     content_attributes: { event: {...}, receivedMessage: {...} }
#   }
class Templates::Adapters::AppleMessagesTemplateAdapter
  attr_reader :content_blocks, :template, :parameters

  def initialize(content_blocks:, template:, parameters:)
    @content_blocks = content_blocks
    @template = template
    @parameters = parameters.with_indifferent_access
  end

  # Main entry point: adapt template to Apple Messages format
  def adapt
    Rails.logger.info "[TemplateAdapter] ========== ADAPT METHOD CALLED =========="
    Rails.logger.info "[TemplateAdapter] Template: #{template.name if template.present?}"
    Rails.logger.info "[TemplateAdapter] Parameters: #{parameters.keys.inspect}"

    channel_mapping = template.channel_mappings
                              &.find_by(channel_type: 'apple_messages_for_business')

    # Use mapping if exists AND has field_mappings, otherwise use defaults
    if channel_mapping && channel_mapping.field_mappings.present?
      adapt_with_mapping(channel_mapping)
    else
      adapt_with_defaults
    end
  end

  private

  def adapt_with_mapping(mapping)
    Rails.logger.info "[TemplateAdapter] adapt_with_mapping called"
    Rails.logger.info "[TemplateAdapter] Mapping content_type: #{mapping.content_type.inspect}"
    Rails.logger.info "[TemplateAdapter] Mapping field_mappings: #{mapping.field_mappings.inspect}"

    result = {
      content_type: mapping.content_type,
      content: generate_content,
      content_attributes: map_attributes(mapping.field_mappings)
    }

    Rails.logger.info "[TemplateAdapter] Result content_attributes: #{result[:content_attributes].inspect}"
    result
  end

  def adapt_with_defaults
    Rails.logger.info "[TemplateAdapter] adapt_with_defaults called"
    Rails.logger.info "[TemplateAdapter] Content blocks count: #{@content_blocks&.length || 0}"

    # Default adaptation logic for Apple Messages
    primary_block = @content_blocks.first

    Rails.logger.info "[TemplateAdapter] Primary block: #{primary_block.inspect}"

    return adapt_generic_content if primary_block.nil?

    block_type = primary_block[:type]
    Rails.logger.info "[TemplateAdapter] Block type detected: #{block_type.inspect}"

    case block_type
    when 'time_picker'
      Rails.logger.info "[TemplateAdapter] Routing to adapt_time_picker"
      adapt_time_picker(primary_block)
    when 'list_picker'
      adapt_list_picker(primary_block)
    when 'payment_request'
      adapt_payment_request(primary_block)
    when 'form'
      adapt_form(primary_block)
    when 'quick_reply'
      adapt_quick_reply(primary_block)
    when 'rich_link'
      adapt_rich_link(primary_block)
    when 'imessage_app'
      adapt_imessage_app(primary_block)
    when 'auth_request', 'oauth'
      adapt_oauth(primary_block)
    else
      Rails.logger.info "[TemplateAdapter] No matching block type, using generic content"
      adapt_generic_content
    end
  end

  def adapt_time_picker(block)
    Rails.logger.info "[TemplateAdapter] adapt_time_picker called"
    properties = block[:properties]

    # CRITICAL: Use snake_case string keys (Chatwoot validation expects this)
    event_image_id = properties['imageIdentifier'] || properties['image_identifier']
    received_image_id = properties['receivedImageIdentifier'] || properties['received_image_identifier']
    reply_image_id = properties['replyImageIdentifier'] || properties['reply_image_identifier']

    # If reply image not specified, reuse received image (Apple MSP best practice)
    reply_image_id = received_image_id if reply_image_id.blank?

    # Get slots from parameters (for dynamic bot usage) or properties (for static templates)
    # CRITICAL: Timeslots are nested inside event object when saved from frontend
    slots = @parameters['available_slots'] || @parameters[:available_slots] ||
            properties.dig('event', 'timeslots') || properties['timeslots'] || properties['slots']

    Rails.logger.info "[TemplateAdapter] Found slots: #{slots.inspect}"

    formatted_timeslots = format_timeslots(slots)

    result = {
      content_type: 'apple_time_picker',
      content: properties['title'] || 'Select a time',
      content_attributes: {
        'event' => {
          'title' => properties['title'],
          'description' => properties['description'],
          'identifier' => properties['identifier'] || SecureRandom.uuid,
          'timeslots' => formatted_timeslots,
          'timezone_offset' => properties['timezoneOffset'] || properties['timezone_offset'],
          'image_identifier' => event_image_id
        }.compact,
        'received_title' => properties['receivedTitle'] || properties['received_title'] || properties['title'],
        'reply_title' => properties['replyTitle'] || properties['reply_title'] || 'Selected: ${event.title}',
        'received_image_identifier' => received_image_id,
        'reply_image_identifier' => reply_image_id,
        'received_style' => properties['receivedStyle'] || properties['received_style'] || 'large',
        'reply_style' => properties['replyStyle'] || properties['reply_style'] || 'large'
      }.compact
    }

    Rails.logger.info "[TemplateAdapter] adapt_time_picker returning content_attributes['event']['timeslots']: #{result[:content_attributes]['event']['timeslots'].inspect}"
    result
  end

  def format_timeslots(slots)
    return [] unless slots.is_a?(Array)

    Rails.logger.info "[TemplateAdapter] format_timeslots called with #{slots.length} slots"

    result = slots.map.with_index do |slot_time, index|
      # Handle both string timestamps and hash objects (use snake_case string keys)
      formatted_slot = if slot_time.is_a?(Hash)
        identifier = slot_time['identifier'] || "slot_#{index}"
        start_time_value = slot_time['startTime'] || slot_time['start_time']

        Rails.logger.info "[TemplateAdapter] Slot #{index}: identifier=#{identifier}, startTime=#{start_time_value.inspect}"

        # Fallback: Try to parse start_time from identifier if missing
        # Format: "YYYY-MM-DD_HH" or similar date-based identifiers
        if start_time_value.nil? && identifier.present?
          Rails.logger.info "[TemplateAdapter] startTime is nil, attempting to parse from identifier: #{identifier}"
          start_time_value = parse_time_from_identifier(identifier)
          Rails.logger.info "[TemplateAdapter] Parsed time from identifier: #{start_time_value.inspect}"
        end

        formatted_time = format_time(start_time_value)
        Rails.logger.info "[TemplateAdapter] Formatted time: #{formatted_time.inspect}"

        {
          'identifier' => identifier,
          'start_time' => formatted_time,
          'duration' => slot_time['duration'] || 3600
        }
      else
        {
          'identifier' => "slot_#{index}",
          'start_time' => format_time(slot_time),
          'duration' => @template.parameters.dig('appointment_duration', 'default') || 3600
        }
      end

      Rails.logger.info "[TemplateAdapter] Formatted slot #{index}: #{formatted_slot.inspect}"
      formatted_slot
    end

    Rails.logger.info "[TemplateAdapter] format_timeslots returning: #{result.inspect}"
    result
  end

  def parse_time_from_identifier(identifier)
    # Try to extract date/time from identifiers like:
    # "2025-10-30_14" → Oct 30, 2025 at 14:00
    # "2025-10-30_1" → Oct 30, 2025 at 01:00
    # "slot_2025-10-30T14:00" → Oct 30, 2025 at 14:00

    return nil unless identifier.is_a?(String)

    # Pattern 1: YYYY-MM-DD_HH format
    if identifier =~ /(\d{4})-(\d{2})-(\d{2})_(\d+)/
      year, month, day, hour = $1.to_i, $2.to_i, $3.to_i, $4.to_i
      begin
        Time.utc(year, month, day, hour, 0, 0)
      rescue ArgumentError
        nil
      end
    # Pattern 2: ISO8601-like in identifier (e.g., "slot_2025-10-30T14:00")
    elsif identifier =~ /(\d{4}-\d{2}-\d{2}T\d{2}:\d{2})/
      begin
        Time.parse($1)
      rescue ArgumentError
        nil
      end
    # Pattern 3: Just a date (e.g., "2025-10-30")
    elsif identifier =~ /^(\d{4}-\d{2}-\d{2})$/
      begin
        Time.parse($1)
      rescue ArgumentError
        nil
      end
    else
      nil
    end
  end

  def format_time(time_input)
    return nil unless time_input

    time = case time_input
           when String
             Time.zone.parse(time_input)
           when Integer
             Time.zone.at(time_input)
           when Time, DateTime
             time_input
           else
             return time_input.to_s
           end

    # Apple MSP format: 2017-05-26T08:27+0000
    time.utc.strftime('%Y-%m-%dT%H:%M+0000')
  rescue ArgumentError
    time_input.to_s
  end

  def adapt_list_picker(block)
    properties = block[:properties]

    # CRITICAL: Use snake_case for all keys (Chatwoot validation expects snake_case)
    received_image_id = properties['receivedImageIdentifier'] || properties['received_image_identifier']
    reply_image_id = properties['replyImageIdentifier'] || properties['reply_image_identifier']

    # Filter images to only include data and identifier (remove size, preview, originalName)
    images = (properties['images'] || []).map do |img|
      {
        'identifier' => img['identifier'],
        'data' => img['data']
      }.compact
    end

    {
      content_type: 'apple_list_picker',
      content: properties['title'] || 'Select an option',
      content_attributes: {
        'sections' => format_list_picker_sections(properties['sections']),
        'received_title' => properties['receivedTitle'] || properties['received_title'] || properties['title'],
        'reply_title' => properties['replyTitle'] || properties['reply_title'] || 'Selected: ${item.title}',
        'received_image_identifier' => received_image_id,
        'reply_image_identifier' => reply_image_id,
        'received_style' => properties['receivedStyle'] || properties['received_style'] || 'small',
        'reply_style' => properties['replyStyle'] || properties['reply_style'] || 'icon',
        'images' => images
      }.compact
    }
  end

  def format_list_picker_sections(sections)
    return [] unless sections.is_a?(Array)

    sections.map.with_index do |section, section_index|
      {
        'title' => section['title'] || "Section #{section_index + 1}",
        'multipleSelection' => section['multipleSelection'] || false,
        'order' => section['order'] || section_index,
        'items' => format_list_picker_items(section['items'], section_index)
      }
    end
  end

  def format_list_picker_items(items, _section_index)
    return [] unless items.is_a?(Array)

    items.map.with_index do |item, item_index|
      # CRITICAL: Use snake_case for image_identifier (Chatwoot validation)
      image_id = item['imageIdentifier'] || item['image_identifier']

      # Normalize style to valid values: icon, small, large (default to icon)
      style = item['style']
      style = 'icon' unless %w[icon small large].include?(style)

      {
        'identifier' => item['identifier'] || SecureRandom.uuid,
        'title' => item['title'] || "Item #{item_index + 1}",
        'subtitle' => item['subtitle'],
        'image_identifier' => image_id,
        'order' => item['order'] || item_index,
        'style' => style
      }.compact
    end
  end

  def adapt_payment_request(block)
    properties = block[:properties]

    {
      content_type: 'apple_pay',
      content: properties['title'] || 'Payment Request',
      content_attributes: {
        payment: {
          merchantIdentifier: properties['merchantIdentifier'],
          merchantName: properties['merchantName'],
          countryCode: properties['countryCode'] || 'US',
          currencyCode: properties['currencyCode'] || 'USD',
          paymentNetworks: properties['paymentNetworks'] || %w[visa mastercard amex],
          lineItems: properties['lineItems'] || [],
          total: {
            label: properties['totalLabel'] || 'Total',
            amount: properties['amount'],
            type: properties['totalType'] || 'final'
          }
        },
        receivedTitle: properties['receivedTitle'] || properties['title'],
        replyTitle: properties['replyTitle'] || 'Payment Sent',
        images: properties['images'] || []
      }.compact
    }
  end

  def adapt_form(block)
    properties = block[:properties]

    # Build received_message with both camelCase and snake_case support
    received_msg = properties['receivedMessage'] || properties['received_message'] || {}
    received_image_id = received_msg['imageIdentifier'] || received_msg['image_identifier']

    # Build reply_message with both camelCase and snake_case support
    reply_msg = properties['replyMessage'] || properties['reply_message'] || {}
    reply_image_id = reply_msg['imageIdentifier'] || reply_msg['image_identifier']

    # If reply image not specified, reuse received image (Apple MSP best practice)
    reply_image_id = received_image_id if reply_image_id.blank?

    {
      content_type: 'apple_form',
      content: properties['title'] || 'Please fill out this form',
      content_attributes: {
        title: properties['title'],
        description: properties['description'],
        pages: properties['pages'] || [],
        show_summary: properties['showSummary'] || properties['show_summary'] || false,
        received_message: {
          title: received_msg['title'] || properties['title'],
          subtitle: received_msg['subtitle'],
          imageIdentifier: received_image_id,
          style: received_msg['style'] || 'large'
        }.compact,
        reply_message: {
          title: reply_msg['title'] || 'Thank you for your submission!',
          subtitle: reply_msg['subtitle'],
          imageIdentifier: reply_image_id,
          style: reply_msg['style'] || 'large'
        }.compact,
        images: properties['images'] || []
      }.compact
    }
  end

  def adapt_quick_reply(block)
    properties = block[:properties]

    # Format items to match Chatwoot's expected format
    items = (properties['items'] || properties[:items] || []).map do |item|
      {
        'identifier' => item['identifier'] || item[:identifier] || SecureRandom.uuid,
        'title' => item['title'] || item[:title]
      }.compact
    end

    {
      content_type: 'apple_quick_reply',
      content: properties['summaryText'] || properties[:summaryText] || properties['summary_text'] || 'Quick Reply',
      content_attributes: {
        'summary_text' => properties['summaryText'] || properties[:summaryText] || properties['summary_text'],
        'items' => items
      }.compact
    }
  end

  def adapt_rich_link(block)
    properties = block[:properties]

    {
      content_type: 'apple_rich_link',
      content: properties['title'] || 'Rich Link',
      content_attributes: {
        url: properties['url'],
        title: properties['title'],
        subtitle: properties['subtitle'],
        imageUrl: properties['imageUrl'],
        openInSafari: properties['openInSafari'] || false
      }.compact
    }
  end

  def adapt_imessage_app(block)
    properties = block[:properties]

    # iMessage App interactive message
    # See: https://developer.apple.com/documentation/businesschatapi/messages_sent/interactive_messages/imessage_apps
    {
      content_type: 'apple_imessage_app',
      content: properties['title'] || 'iMessage App',
      content_attributes: {
        appId: properties['appId'] || properties['app_id'],
        appName: properties['appName'] || properties['app_name'],
        url: properties['url'], # URL scheme to launch the app
        useLiveLayout: properties['useLiveLayout'] || properties['use_live_layout'] || false,
        receivedMessage: {
          title: properties['receivedTitle'] || properties['received_title'] || properties['title'],
          subtitle: properties['receivedSubtitle'] || properties['received_subtitle'],
          imageUrl: properties['receivedImageUrl'] || properties['received_image_url'],
          imageIdentifier: properties['receivedImageIdentifier'] || properties['received_image_identifier'],
          style: properties['receivedStyle'] || properties['received_style'] || 'icon'
        }.compact,
        replyMessage: {
          title: properties['replyTitle'] || properties['reply_title'] || 'Message from ${app.name}',
          subtitle: properties['replySubtitle'] || properties['reply_subtitle'],
          imageUrl: properties['replyImageUrl'] || properties['reply_image_url'],
          imageIdentifier: properties['replyImageIdentifier'] || properties['reply_image_identifier'],
          style: properties['replyStyle'] || properties['reply_style'] || 'icon'
        }.compact,
        data: properties['data'] || {}, # Custom data passed to the app
        images: properties['images'] || []
      }.compact
    }
  end

  def adapt_oauth(block)
    properties = block[:properties]

    # OAuth authentication request
    # See: https://developer.apple.com/documentation/businesschatapi/messages_sent/interactive_messages/authentication
    {
      content_type: 'apple_auth',
      content: properties['title'] || 'Authentication Required',
      content_attributes: {
        oauth2: {
          responseType: properties['responseType'] || properties['response_type'] || 'code',
          scope: properties['scope'] || [],
          state: properties['state'] || SecureRandom.uuid,
          responseEncryptionKey: properties['responseEncryptionKey'] || properties['response_encryption_key']
        }.compact,
        receivedMessage: {
          title: properties['receivedTitle'] || properties['received_title'] || 'Please authenticate',
          subtitle: properties['receivedSubtitle'] || properties['received_subtitle'],
          imageIdentifier: properties['receivedImageIdentifier'] || properties['received_image_identifier'],
          style: properties['receivedStyle'] || properties['received_style'] || 'icon'
        }.compact,
        replyMessage: {
          title: properties['replyTitle'] || properties['reply_title'] || 'Authentication complete',
          subtitle: properties['replySubtitle'] || properties['reply_subtitle'],
          imageIdentifier: properties['replyImageIdentifier'] || properties['reply_image_identifier'],
          style: properties['replyStyle'] || properties['reply_style'] || 'icon'
        }.compact,
        images: properties['images'] || []
      }.compact
    }
  end

  def adapt_generic_content
    # Combine all text blocks into simple text message
    text_content = @content_blocks
                   .select { |block| block[:type] == 'text' }
                   .filter_map { |block| block.dig(:properties, 'content') }
                   .join("\n\n")

    {
      content_type: 'text',
      content: text_content.presence || 'Message',
      content_attributes: {}
    }
  end

  def generate_content
    # Extract primary content from first block
    primary_block = @content_blocks.first
    return '' if primary_block.nil?

    primary_block.dig(:properties, 'title') ||
      primary_block.dig(:properties, 'content') ||
      primary_block.dig(:properties, 'summaryText') ||
      ''
  end

  def map_attributes(field_mappings)
    Rails.logger.info "[TemplateAdapter] map_attributes called"
    Rails.logger.info "[TemplateAdapter] Field mappings: #{field_mappings.inspect}"

    # Apply custom field mappings from template
    result = {}

    field_mappings.each do |target_path, source_path|
      value = extract_value_from_path(source_path)
      Rails.logger.info "[TemplateAdapter] Mapping #{source_path} → #{target_path}: #{value.inspect}"

      set_value_at_path(result, target_path, value) if value.present?
    end

    Rails.logger.info "[TemplateAdapter] map_attributes result: #{result.inspect}"
    result
  end

  def extract_value_from_path(path)
    # Extract value from path like "{{parameters.title}}" or "{{blocks.0.properties.title}}"
    return path unless path.is_a?(String) && path.include?('{{')

    path.scan(/\{\{([^}]+)\}\}/).flatten.first&.then do |variable_path|
      navigate_path(variable_path)
    end
  end

  def navigate_path(path)
    parts = path.split('.')
    current = { 'blocks' => @content_blocks, 'template' => @template }

    parts.each do |part|
      current = if /^\d+$/.match?(part)
                  current[part.to_i]
                else
                  current[part] || current[part.to_sym]
                end

      return nil if current.nil?
    end

    current
  end

  def set_value_at_path(hash, path, value)
    parts = path.split('.')
    last_key = parts.pop

    parts.each do |part|
      hash[part] ||= {}
      hash = hash[part]
    end

    hash[last_key] = value
  end
end
