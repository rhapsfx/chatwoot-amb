# Service for sending rendered template messages to conversations
# Used by bots and external systems to send rich content via templates
class Templates::BotMessagingService
  class SendError < StandardError; end

  def initialize(conversation:, template:, parameters:, sender:)
    @conversation = conversation
    @template = template
    @parameters = parameters
    @sender = sender
  end

  def send_template_message
    # Render the template for the conversation's channel
    channel_type = determine_channel_type

    renderer = Templates::BotRendererService.new(
      template_id: @template.id,
      parameters: @parameters,
      channel_type: channel_type
    )

    rendered = renderer.render_for_bot

    # Show typing indicator for Apple Messages
    if apple_messages_channel?
      send_typing_indicator(:start)
      sleep(1.5) # Wait 1.5 seconds with typing indicator visible
    end

    # For Apple Messages text messages, use MessageProcessorService for automatic URL-to-Rich Link conversion
    if apple_messages_channel? && should_use_message_processor?(rendered)
      message_params = build_message_params(rendered)
      processor = AppleMessagesForBusiness::MessageProcessorService.new(
        @conversation,
        message_params,
        @sender
      )
      message = processor.process_and_send
      # Handle multiple messages case (when URLs are split)
      message = message.last if message.is_a?(Array)
    else
      # Create the message directly for complex content types
      message = create_message(rendered)
    end

    # Attach template files to message
    attach_template_files_to_message(message, rendered[:attachments])

    # Trigger conversation events
    trigger_events(message)

    message
  rescue StandardError => e
    Rails.logger.error "[Templates::BotMessagingService] Failed to send message: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise SendError, "Failed to send template message: #{e.message}"
  end

  private

  def should_use_message_processor?(rendered)
    # Use MessageProcessorService for text messages to enable URL-to-Rich Link conversion
    # Skip for complex Apple Messages content types that are already properly formatted
    content_type = rendered[:content_type] || rendered[:contentType] || 'text'

    # List of Apple Messages content types that are already formatted and should skip URL processing
    skip_processor_types = %w[
      apple_list_picker
      apple_time_picker
      apple_quick_reply
      apple_pay
      apple_rich_link
      apple_authentication
      apple_form
      apple_custom_app
    ]

    !skip_processor_types.include?(content_type)
  end

  def build_message_params(rendered)
    content_type = rendered[:content_type] || rendered[:contentType] || 'text'
    content = rendered[:content]

    # Clean placeholder content, but preserve minimal content if attachments are present
    content = clean_content_for_template_messages(content, content_type, rendered[:attachments])

    {
      content: content,
      content_type: content_type,
      content_attributes: rendered[:content_attributes] || rendered[:contentAttributes] || {},
      message_type: :outgoing,
      sender_type: @sender.class.name,
      sender_id: @sender.id,
      additional_attributes: {
        template_id: @template.id,
        template_name: @template.name,
        rendered_at: Time.current.iso8601
      }
    }
  end

  def determine_channel_type
    # Convert inbox channel to standardized template channel type
    case @conversation.inbox.channel_type
    when 'Channel::AppleMessagesForBusiness'
      'apple_messages_for_business'
    when 'Channel::Whatsapp'
      'whatsapp'
    when 'Channel::WebWidget', 'Channel::Api'
      'web_widget'
    else
      # Fallback to a generic type
      @conversation.inbox.channel_type.demodulize.underscore
    end
  end

  def create_message(rendered)
    content_type = rendered[:content_type] || rendered[:contentType]

    # Clean placeholder content, but preserve minimal content if attachments are present
    content = clean_content_for_template_messages(rendered[:content], content_type, rendered[:attachments])

    message_params = {
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :outgoing,
      content: content,
      sender_type: @sender.class.name,
      sender_id: @sender.id
    }

    # Add content_type and content_attributes if present (check both camelCase and snake_case)
    message_params[:content_type] = content_type if content_type.present?
    if rendered[:content_attributes].present? || rendered[:contentAttributes].present?
      message_params[:content_attributes] =
        rendered[:content_attributes] || rendered[:contentAttributes]
    end

    Rails.logger.info "🟢 BotMessagingService - Creating message with content_attributes: #{message_params[:content_attributes].inspect}"
    if message_params[:content_type] == 'apple_time_picker'
      Rails.logger.info "🟢 BotMessagingService - Event timeslots: #{message_params.dig(:content_attributes, 'event', 'timeslots').inspect}"
    end

    # Add additional metadata
    message_params[:additional_attributes] = {
      template_id: @template.id,
      template_name: @template.name,
      rendered_at: Time.current.iso8601
    }

    @conversation.messages.create!(message_params)
  end

  # Clean content for template messages
  # Removes placeholder text but preserves necessary content for attachments
  def clean_content_for_template_messages(content, content_type, template_attachments)
    # List of rich Apple Messages types that should have empty content
    rich_types = %w[
      apple_list_picker
      apple_time_picker
      apple_form
      apple_pay
      apple_authentication
      apple_custom_app
    ]

    # For rich types, always return empty content
    return '' if rich_types.include?(content_type)

    # For text messages, check if we need to clean placeholder text
    return content if content.blank?

    # Strip whitespace for comparison
    stripped = content.strip

    # Remove generic "Message" text
    # But if there are attachments, keep a placeholder to prevent validation errors
    if /^Message$/i.match?(stripped)
      # If template has attachments, keep empty string (SendMessageService will add replacement char)
      # Otherwise keep the content as-is (might be intentional)
      return template_attachments.present? && template_attachments.any? ? '' : content
    end

    # For "Message ￼" pattern, keep just the replacement character
    return "\uFFFC" if /^Message\s+\uFFFC$/i.match?(stripped)

    # Return original content if it's meaningful
    content
  end

  def trigger_events(message)
    # Trigger Rails events for message creation
    # This will be picked up by webhooks and other listeners
    Rails.configuration.dispatcher.dispatch(
      Events::BASE_EVENTS[:message_created],
      Time.zone.now,
      message: message,
      conversation: @conversation
    )
  rescue StandardError => e
    Rails.logger.error "[Templates::BotMessagingService] Failed to trigger events: #{e.message}"
    # Don't fail the message creation if event dispatch fails
  end

  # Attach template files to the created message
  def attach_template_files_to_message(message, template_attachments)
    return if template_attachments.blank?

    template_attachments.each do |attachment_data|
      # Find the ActiveStorage blob
      blob = ActiveStorage::Blob.find(attachment_data[:blob_id])

      # Download the blob content
      file_content = blob.download

      # Create a new Attachment record for the message
      message.attachments.create!(
        file_type: determine_file_type(blob.content_type),
        account_id: message.account_id,
        file: {
          io: StringIO.new(file_content),
          filename: blob.filename.to_s,
          content_type: blob.content_type
        }
      )

      Rails.logger.info "[BotMessagingService] Attached file '#{blob.filename}' to message #{message.id}"
    rescue StandardError => e
      Rails.logger.error "[BotMessagingService] Failed to attach file #{attachment_data[:filename]}: #{e.message}"
      # Continue with other attachments even if one fails
    end
  end

  # Determine attachment file type from content type
  def determine_file_type(content_type)
    case content_type
    when %r{^image/}
      :image
    when %r{^video/}
      :video
    when %r{^audio/}
      :audio
    else
      :file
    end
  end

  def apple_messages_channel?
    @conversation.inbox.channel.is_a?(Channel::AppleMessagesForBusiness)
  end

  def send_typing_indicator(action)
    return unless apple_messages_channel?

    # Get the Apple Messages source ID from contact's additional attributes
    apple_source_urn = @conversation.contact&.additional_attributes&.dig('apple_messages_source_id')
    return unless apple_source_urn # Need destination ID

    # Extract the UUID from the URN format (urn:biz:UUID)
    destination_id = apple_source_urn.sub(/^urn:biz:/, '')

    service = AppleMessagesForBusiness::OutgoingTypingIndicatorService.new(
      channel: @conversation.inbox.channel,
      destination_id: destination_id,
      action: action
    )

    result = service.perform
    Rails.logger.info "[BotMessagingService] Typing indicator #{action}: #{result[:success] ? 'success' : result[:error]}"
  rescue StandardError => e
    Rails.logger.error "[BotMessagingService] Failed to send typing indicator: #{e.message}"
    # Don't fail the message sending if typing indicator fails
  end
end
