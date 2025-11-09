# frozen_string_literal: true

# Service to render message templates for bot consumption (Dialogflow, Rasa, etc.)
# Handles parameter validation, variable processing, and channel adaptation
#
# Usage:
#   service = Templates::BotRendererService.new(
#     template_id: 123,
#     parameters: { business_name: 'Acme Corp', available_slots: [...] },
#     channel_type: 'apple_messages_for_business'
#   )
#   result = service.render_for_bot
#
# Returns:
#   {
#     template_id: 123,
#     content_type: 'apple_time_picker',
#     content: 'Select a time',
#     content_attributes: { event: {...}, receivedMessage: {...} },
#     webhook_data: { template_name: '...', parameters_used: {...} }
#   }
class Templates::BotRendererService
  # Custom exception for parameter validation errors
  class ParameterValidationError < StandardError; end

  attr_reader :template, :parameters, :channel_type

  def initialize(template_id:, parameters:, channel_type:)
    @template = MessageTemplate.find(template_id)
    @parameters = if parameters.is_a?(ActionController::Parameters)
                    parameters.to_unsafe_h
                  else
                    parameters
                  end
    @parameters = @parameters.with_indifferent_access
    @channel_type = channel_type
  end

  # Main entry point: render template for bot consumption
  def render_for_bot
    validate_parameters!
    validate_channel_compatibility!

    # Check if template has apple_message_content in metadata (migrated bot templates)
    return render_from_metadata if template.metadata.present? && template.metadata['apple_message_content'].present?

    processed_content = process_template_variables
    channel_content = adapt_for_channel(processed_content)

    {
      template_id: template.id,
      template_name: template.name,
      content_type: channel_content[:content_type],
      content: channel_content[:content],
      content_attributes: channel_content[:content_attributes],
      attachments: load_template_attachments,
      webhook_data: generate_webhook_data
    }
  end

  private

  # Render template directly from metadata (for migrated bot templates)
  def render_from_metadata
    apple_content = template.metadata['apple_message_content']

    # Get content attributes
    content_attrs = apple_content['content_attributes'] || {}

    # Detect actual content type from structure
    actual_content_type = detect_content_type_from_attributes(content_attrs)

    # Transform old bot format to Chatwoot format
    transformed_attrs = transform_bot_format_to_chatwoot(content_attrs, actual_content_type)

    # Load images from ActiveStorage if template references them
    transformed_attrs = load_images_from_storage(transformed_attrs) if actual_content_type == 'apple_list_picker'

    # Merge parameters if provided, but filter out keys that would be invalid at root level
    if parameters.present?
      # Filter parameters to only allow valid keys for this content type
      filtered_params = filter_parameters_for_content_type(parameters, actual_content_type)
      # Remove blank/empty values to prevent overriding template defaults
      filtered_params = filtered_params.reject { |_k, v| v.blank? }

      # Special handling for time picker: preserve template timeslots if not providing available_slots
      # This prevents accidentally clearing timeslots when passing other event parameters
      if actual_content_type == 'apple_time_picker' &&
         parameters['available_slots'].blank? &&
         parameters[:available_slots].blank?

        # Check if parameters contain an event that would clear timeslots
        if filtered_params['event'].present? && transformed_attrs['event'].present?
          # Preserve template timeslots if parameter event has empty/nil timeslots
          template_timeslots = transformed_attrs.dig('event', 'timeslots')
          param_timeslots = filtered_params.dig('event', 'timeslots')

          if template_timeslots.present? && (param_timeslots.nil? || param_timeslots.empty?)
            # Save template timeslots, merge other event fields, then restore timeslots
            saved_timeslots = template_timeslots
            transformed_attrs = transformed_attrs.deep_merge(filtered_params)
            transformed_attrs['event']['timeslots'] = saved_timeslots
            Rails.logger.info "[BotRendererService] Preserved #{saved_timeslots.length} template timeslots"
          else
            transformed_attrs = transformed_attrs.deep_merge(filtered_params)
          end
        else
          transformed_attrs = transformed_attrs.deep_merge(filtered_params)
        end
      else
        transformed_attrs = transformed_attrs.deep_merge(filtered_params)
      end
    end

    # Handle available_slots parameter for time picker (bot API compatibility)
    # CRITICAL: Do this AFTER merging parameters to ensure available_slots takes precedence
    if actual_content_type == 'apple_time_picker'
      available_slots = parameters['available_slots'] || parameters[:available_slots]
      if available_slots.present?
        # Convert available_slots to proper event.timeslots structure
        formatted_timeslots = format_timeslots_for_bot(available_slots)
        transformed_attrs['event'] ||= {}
        transformed_attrs['event']['timeslots'] = formatted_timeslots
        Rails.logger.info "[BotRendererService] Converted #{available_slots.length} available_slots to timeslots"
      end
    end

    {
      template_id: template.id,
      template_name: template.name,
      content_type: actual_content_type,
      content: apple_content['content'] || '',
      content_attributes: transformed_attrs,
      attachments: load_template_attachments,
      webhook_data: generate_webhook_data
    }
  end

  # Load images from ActiveStorage and add them to content_attributes
  def load_images_from_storage(attrs)
    # Collect all image identifiers referenced in the template
    image_identifiers = collect_image_identifiers(attrs)
    return attrs if image_identifiers.empty?

    # Load images from ActiveStorage (use distinct to avoid duplicates)
    images = AppleListPickerImage
             .where(account_id: template.account_id, identifier: image_identifiers)
             .includes(image_attachment: :blob)
             .group_by(&:identifier)
             .transform_values(&:first) # Take first record for each identifier

    return attrs if images.empty?

    # Convert images to base64 format, maintaining order of identifiers
    images_array = image_identifiers.filter_map do |identifier|
      img = images[identifier]
      next unless img&.image&.attached?

      begin
        # Read the image data and encode to base64
        image_data = img.image.download
        base64_data = Base64.strict_encode64(image_data)

        {
          'identifier' => img.identifier,
          'data' => base64_data,
          'description' => img.description
        }.compact
      rescue StandardError => e
        Rails.logger.error "[BotRendererService] Failed to load image #{img.identifier}: #{e.message}"
        nil
      end
    end

    # Add images to content_attributes
    attrs['images'] = images_array unless images_array.empty?
    attrs
  end

  # Collect all image identifiers from sections and received_message
  def collect_image_identifiers(attrs)
    identifiers = []

    # Collect from sections items
    sections = attrs['sections'] || []
    sections.each do |section|
      items = section['items'] || []
      items.each do |item|
        identifiers << item['image_identifier'] if item['image_identifier'].present?
      end
    end

    # Collect from received_message
    identifiers << attrs['received_image_identifier'] if attrs['received_image_identifier'].present?

    # Collect from reply_message
    identifiers << attrs['reply_image_identifier'] if attrs['reply_image_identifier'].present?

    identifiers.compact.uniq
  end

  # Filter parameters to only allow valid root-level keys for the content type
  def filter_parameters_for_content_type(params, content_type)
    case content_type
    when 'apple_list_picker'
      # Only allow these keys at root level for list picker
      allowed_keys = %w[
        sections images
        received_title received_subtitle received_image_identifier received_style
        reply_title reply_subtitle reply_image_title reply_image_subtitle
        reply_secondary_subtitle reply_tertiary_subtitle reply_image_identifier reply_style
      ]
      params.select { |key, _| allowed_keys.include?(key.to_s) }
    when 'apple_time_picker'
      # Only allow these keys at root level for time picker
      allowed_keys = %w[
        event timezone_offset timeslots
        received_title received_subtitle received_image_identifier received_style
        reply_title reply_subtitle reply_image_title reply_image_subtitle
        reply_secondary_subtitle reply_tertiary_subtitle reply_image_identifier reply_style
      ]
      params.select { |key, _| allowed_keys.include?(key.to_s) }
    when 'apple_form'
      # Only allow these keys at root level for forms
      allowed_keys = %w[
        title description fields pages submit_url method validation_rules images
        received_message reply_message version form_id use_live_layout submit_button cancel_button
      ]
      params.select { |key, _| allowed_keys.include?(key.to_s) }
    else
      # For other types, allow all parameters (they'll be validated by the model)
      params
    end
  end

  # Detect the actual Apple Messages content type from content_attributes structure
  def detect_content_type_from_attributes(attrs)
    # Check for dynamic content (List Picker, Time Picker, Forms) - old bot format
    if attrs['dynamic'].present?
      template_type = attrs.dig('dynamic', 'template')
      case template_type
      when 'formSelect'
        return 'apple_list_picker'
      when 'timePicker'
        return 'apple_time_picker'
      when 'form'
        return 'apple_form'
      end
    end

    # Check for newer bot format with explicit type wrappers
    return 'apple_list_picker' if attrs['list_picker'].present? && attrs.dig('list_picker', 'sections').present?
    return 'apple_time_picker' if attrs['time_picker'].present? || (attrs['event'].present? && attrs['event']['timeslots'].present?)
    return 'apple_form' if attrs['form'].present?

    # Check for direct sections at root level (Chatwoot format)
    return 'apple_list_picker' if attrs['sections'].present?

    # Check for direct pages at root level (Apple Messages Forms format)
    return 'apple_form' if attrs['pages'].present? && attrs['pages'].is_a?(Array) && attrs['pages'].first&.dig('items').present?

    # Check for other Apple Messages types (support both underscore and hyphenated keys)
    return 'apple_quick_reply' if attrs['quick_reply'].present? || attrs['quick-reply'].present? || attrs['replies'].present?
    return 'apple_rich_link' if attrs['url'].present? && attrs['title'].present?
    return 'apple_pay' if attrs['payment'].present?
    return 'apple_authentication' if attrs['oauth2'].present?

    # Default to text
    'text'
  end

  # Transform old bot format to Chatwoot format
  def transform_bot_format_to_chatwoot(attrs, content_type)
    case content_type
    when 'apple_list_picker'
      transform_list_picker_format(attrs)
    when 'apple_time_picker'
      transform_time_picker_format(attrs)
    when 'apple_form'
      transform_form_format(attrs)
    when 'apple_quick_reply'
      transform_quick_reply_format(attrs)
    else
      # For other types or already in correct format, return as-is
      attrs
    end
  end

  # Transform List Picker from bot format to Chatwoot format
  def transform_list_picker_format(attrs)
    result = {}

    # Handle old format: dynamic.page.sections
    if attrs['dynamic'].present? && attrs.dig('dynamic', 'page', 'sections').present?
      result['sections'] = attrs.dig('dynamic', 'page', 'sections')
    # NOTE: title/subtitle from dynamic.page are NOT copied to root level
    # They should be inside each section if needed
    # Handle newer format: list_picker.sections
    elsif attrs['list_picker'].present? && attrs.dig('list_picker', 'sections').present?
      result['sections'] = attrs.dig('list_picker', 'sections')
    # NOTE: multiple_selection is NOT copied to root level
    # It should be inside each section if needed
    # Already has sections at root - copy them
    elsif attrs['sections'].present?
      result['sections'] = attrs['sections']
    end

    # Normalize sections: rename 'fields' to 'items' and fix invalid style values
    if result['sections'].present?
      # Valid item keys per Chatwoot validation
      valid_item_keys = %w[identifier title subtitle image_identifier imageIdentifier order style]

      result['sections'] = result['sections'].map do |section|
        normalized_section = section.dup

        # Rename 'fields' to 'items' (old nested list picker format)
        normalized_section['items'] = normalized_section.delete('fields') if normalized_section['fields'].present?

        # Normalize items: fix invalid style values and remove invalid keys
        if normalized_section['items'].present?
          normalized_section['items'] = normalized_section['items'].map do |item|
            # Filter to only valid keys
            normalized_item = item.select { |k, _v| valid_item_keys.include?(k.to_s) }

            # Convert invalid 'default' style to 'icon'
            normalized_item['style'] = 'icon' if normalized_item['style'] == 'default'

            # Ensure required fields have defaults
            normalized_item['style'] ||= 'icon'
            normalized_item['identifier'] ||= "item_#{SecureRandom.hex(8)}"

            normalized_item
          end
        end

        normalized_section
      end
    end

    # Copy received_message and reply_message fields (these ARE valid at root level)
    result['received_title'] = attrs.dig('received_message', 'title')
    result['received_subtitle'] = attrs.dig('received_message', 'subtitle')
    result['received_image_identifier'] = attrs.dig('received_message', 'image_identifier')
    result['received_style'] = attrs.dig('received_message', 'style')
    result['reply_title'] = attrs.dig('reply_message', 'title')
    result['reply_subtitle'] = attrs.dig('reply_message', 'subtitle')
    result['reply_image_identifier'] = attrs.dig('reply_message', 'image_identifier')
    result['reply_style'] = attrs.dig('reply_message', 'style')

    # Copy images if present
    result['images'] = attrs['images'] if attrs['images'].present?

    result.compact
  end

  # Transform Time Picker from bot format to Chatwoot format
  def transform_time_picker_format(attrs)
    result = {}

    # Handle old format: dynamic.event
    if attrs['dynamic'].present? && attrs.dig('dynamic', 'event').present?
      result['event'] = attrs.dig('dynamic', 'event')
    # Already in Chatwoot format
    elsif attrs['event'].present?
      return attrs
    end

    # Copy received_message and reply_message
    result['received_title'] = attrs.dig('received_message', 'title')
    result['received_subtitle'] = attrs.dig('received_message', 'subtitle')
    result['received_image_identifier'] = attrs.dig('received_message', 'image_identifier')
    result['reply_title'] = attrs.dig('reply_message', 'title')
    result['reply_subtitle'] = attrs.dig('reply_message', 'subtitle')
    result['reply_image_identifier'] = attrs.dig('reply_message', 'image_identifier')

    result.compact
  end

  # Transform Form from bot format to Chatwoot format
  def transform_form_format(attrs)
    result = {}

    # Handle old format: dynamic.form
    if attrs['dynamic'].present? && attrs.dig('dynamic', 'form').present?
      result['form'] = attrs.dig('dynamic', 'form')
    # Already in Chatwoot format with 'form' wrapper
    elsif attrs['form'].present?
      return attrs
    # Already in Chatwoot format with pages at root level (new Apple Messages Forms format)
    elsif attrs['pages'].present?
      return attrs
    end

    # Copy received_message and reply_message (for legacy format only)
    result['received_title'] = attrs.dig('received_message', 'title')
    result['received_subtitle'] = attrs.dig('received_message', 'subtitle')
    result['received_image_identifier'] = attrs.dig('received_message', 'image_identifier')
    result['reply_title'] = attrs.dig('reply_message', 'title')
    result['reply_subtitle'] = attrs.dig('reply_message', 'subtitle')
    result['reply_image_identifier'] = attrs.dig('reply_message', 'image_identifier')

    result.compact
  end

  # Transform Quick Reply from bot format to Chatwoot format
  def transform_quick_reply_format(attrs)
    result = {}

    # Handle old format with hyphenated key: quick-reply
    if attrs['quick-reply'].present?
      quick_reply_data = attrs['quick-reply']
      result['items'] = quick_reply_data['items'] if quick_reply_data['items'].present?
      result['summary_text'] = quick_reply_data['summary_text'] if quick_reply_data['summary_text'].present?
    # Handle format with underscore key: quick_reply
    elsif attrs['quick_reply'].present?
      quick_reply_data = attrs['quick_reply']
      result['items'] = quick_reply_data['items'] if quick_reply_data['items'].present?
      result['summary_text'] = quick_reply_data['summary_text'] if quick_reply_data['summary_text'].present?
    # Already in Chatwoot format (items at root level)
    elsif attrs['items'].present? || attrs['replies'].present?
      return attrs
    end

    result.compact
  end

  # Validate that all required parameters are present and correct type
  def validate_parameters!
    return if template.parameters.blank?

    template.parameters.each do |param_name, config|
      raise ParameterValidationError, "Required parameter '#{param_name}' is missing" if config['required'] && parameters[param_name].blank?

      next if parameters[param_name].blank?

      validate_parameter_type(param_name, parameters[param_name], config['type'])
    end
  end

  # Validate parameter type matches expected type
  def validate_parameter_type(param_name, value, expected_type)
    case expected_type
    when 'string'
      raise ParameterValidationError, "Parameter '#{param_name}' must be a string" unless value.is_a?(String)
    when 'integer'
      raise ParameterValidationError, "Parameter '#{param_name}' must be an integer" unless value.is_a?(Integer) || value.to_i.to_s == value.to_s
    when 'array'
      raise ParameterValidationError, "Parameter '#{param_name}' must be an array" unless value.is_a?(Array)
    when 'boolean'
      raise ParameterValidationError, "Parameter '#{param_name}' must be a boolean" unless [true, false, 'true', 'false'].include?(value)
    when 'datetime'
      begin
        Time.zone.parse(value.to_s)
      rescue ArgumentError
        raise ParameterValidationError, "Parameter '#{param_name}' must be a valid datetime"
      end
    end
  end

  # Validate that the template supports the requested channel
  def validate_channel_compatibility!
    return if template.supported_channels.blank?

    normalized_channel = normalize_channel_type(channel_type)

    return if template.supported_channels.include?(normalized_channel)

    raise ParameterValidationError,
          "Template '#{template.name}' does not support channel '#{channel_type}'. Supported: #{template.supported_channels.join(', ')}"
  end

  # Normalize channel type to standard format
  def normalize_channel_type(channel_type)
    case channel_type.to_s.downcase
    when 'apple_messages_for_business', 'apple_messages', 'amb'
      'apple_messages_for_business'  # Match what's stored in database
    when 'whatsapp', 'whatsapp_business'
      'whatsapp'
    when 'web_widget', 'web', 'website'
      'web_widget'
    else
      channel_type.to_s.downcase
    end
  end

  # Process template content blocks and replace variables with actual values
  def process_template_variables
    content_blocks = template.content_blocks.order(:order_index)

    content_blocks.filter_map do |block|
      # Skip blocks that don't meet conditions
      next unless evaluate_conditions(block.conditions)

      processed_properties = process_block_properties(block.properties)

      {
        type: block.block_type,
        properties: processed_properties,
        conditions: block.conditions
      }
    end
  end

  # Evaluate block conditions (e.g., show only if user_type == 'premium')
  def evaluate_conditions(conditions)
    return true if conditions.blank?

    # Simple condition evaluation: {if: "{{param}} == 'value'"}
    if_condition = conditions['if']
    return true if if_condition.blank?

    # Replace variables in condition
    evaluated_condition = replace_variables_in_string(if_condition)

    # Simple evaluation (can be enhanced with a safe eval library)
    # For now, support basic equality checks
    if evaluated_condition =~ /^['"]?([^'"]+)['"]?\s*==\s*['"]?([^'"]+)['"]?$/
      Regexp.last_match(1).strip == Regexp.last_match(2).strip
    else
      true # Default to true if condition format is not recognized
    end
  end

  # Process properties hash and replace {{variable}} placeholders
  def process_block_properties(properties)
    return {} if properties.blank?

    # Convert to JSON, replace variables, then parse back
    json_string = properties.to_json
    processed_json = replace_variables_in_string(json_string)

    JSON.parse(processed_json)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to process template variables: #{e.message}"
    properties
  end

  # Replace {{variable}} placeholders with actual parameter values
  def replace_variables_in_string(string)
    string.gsub(/\{\{(\w+)\}\}/) do
      param_name = Regexp.last_match(1)
      value = parameters[param_name]

      # Handle different value types
      case value
      when Array, Hash
        value.to_json
      when NilClass
        "{{#{param_name}}}" # Keep placeholder if value not provided
      else
        value.to_s
      end
    end
  end

  # Adapt processed content for specific channel using adapter pattern
  def adapt_for_channel(content_blocks)
    adapter_class = adapter_class_for_channel(channel_type)

    adapter = adapter_class.new(
      content_blocks: content_blocks,
      template: template,
      parameters: parameters
    )

    adapter.adapt
  end

  # Get the appropriate adapter class for the channel
  def adapter_class_for_channel(channel_type)
    case normalize_channel_type(channel_type)
    when 'apple_messages_for_business'
      Templates::Adapters::AppleMessagesTemplateAdapter
    when 'whatsapp'
      Templates::Adapters::WhatsappTemplateAdapter
    when 'web_widget'
      Templates::Adapters::WebWidgetTemplateAdapter
    else
      raise ParameterValidationError, "Unsupported channel type: #{channel_type}"
    end
  end

  # Generate webhook data for external systems to track template usage
  def generate_webhook_data
    {
      template_id: template.id,
      template_name: template.name,
      template_category: template.category,
      parameters_used: parameters.to_h,
      channel_type: channel_type,
      timestamp: Time.current.iso8601
    }
  end

  # Load template attachments and return metadata for message creation
  def load_template_attachments
    return [] unless template.attachments.attached?

    # Get ordered attachment IDs from metadata
    display_order = template.attachment_metadata.dig('display_order') || []

    # Sort attachments by display order
    ordered_attachments = if display_order.present?
                            display_order.filter_map { |id| template.attachments.find { |a| a.id == id } }
                          else
                            template.attachments.to_a
                          end

    # Return attachment metadata for message creation
    ordered_attachments.map do |attachment|
      {
        id: attachment.id,
        filename: attachment.filename.to_s,
        content_type: attachment.content_type,
        byte_size: attachment.byte_size,
        blob_id: attachment.blob.id,
        signed_id: attachment.signed_id,
        description: template.attachment_metadata.dig('descriptions', attachment.id.to_s)
      }
    end
  end

  # Format timeslots from bot API format to Apple Messages format
  # Handles both string timestamps and hash objects
  def format_timeslots_for_bot(slots)
    return [] unless slots.is_a?(Array)

    slots.map.with_index do |slot_time, index|
      # Handle both string timestamps and hash objects
      if slot_time.is_a?(Hash)
        # Already in proper format (or close to it)
        {
          'identifier' => slot_time['identifier'] || "slot_#{index}",
          'start_time' => slot_time['start_time'] || slot_time['startTime'],
          'duration' => slot_time['duration'] || 3600
        }.compact
      elsif slot_time.is_a?(String) || slot_time.is_a?(Time) || slot_time.is_a?(DateTime)
        # Convert timestamp string to proper format
        {
          'identifier' => "slot_#{index}",
          'start_time' => parse_timestamp(slot_time),
          'duration' => 3600 # Default 1 hour
        }
      end
    end.compact
  end

  # Parse various timestamp formats to Unix timestamp
  def parse_timestamp(timestamp)
    return timestamp if timestamp.is_a?(Integer) || timestamp.to_i.to_s == timestamp.to_s

    begin
      # Try parsing as ISO8601, RFC3339, or common formats
      time = Time.zone.parse(timestamp.to_s)
      time.to_i
    rescue ArgumentError
      # If parsing fails, return nil and let validation catch it
      Rails.logger.error "[BotRendererService] Failed to parse timestamp: #{timestamp}"
      nil
    end
  end
end
