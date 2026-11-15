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

    Rails.logger.info '🔵 [BotMessagingService] Rendered template:'
    Rails.logger.info "🔵   - Content type: #{rendered[:content_type]}"
    Rails.logger.info "🔵   - Has attachments: #{rendered[:attachments].present?}"
    Rails.logger.info "🔵   - Attachment count: #{rendered[:attachments]&.count || 0}"
    Rails.logger.info "🔵   - Apple Messages channel: #{apple_messages_channel?}"
    Rails.logger.info "🔵   - Should use processor: #{apple_messages_channel? && should_use_message_processor?(rendered)}"

    # Show typing indicator for Apple Messages
    if apple_messages_channel?
      send_typing_indicator(:start)
      sleep(1.5) # Wait 1.5 seconds with typing indicator visible
    end

    # For Apple Messages text messages, use MessageProcessorService for automatic URL-to-Rich Link conversion
    # BUT: If there are attachments, use direct creation to ensure attachments are present before send_reply
    if apple_messages_channel? && should_use_message_processor?(rendered) && rendered[:attachments].blank?
      Rails.logger.info '🔵 [BotMessagingService] Using MessageProcessorService path (no attachments)'
      message_params = build_message_params(rendered)
      processor = AppleMessagesForBusiness::MessageProcessorService.new(
        @conversation,
        message_params,
        @sender
      )
      message = processor.process_and_send
      # Handle multiple messages case (when URLs are split)
      message = message.last if message.is_a?(Array)
    elsif rendered[:attachments].present?
      # For messages with attachments, create message with attachments to prevent race condition
      Rails.logger.info "🔵 [BotMessagingService] Using create_message_with_attachments path (#{rendered[:attachments].count} attachments)"
      message = create_message_with_attachments(rendered)
    else
      Rails.logger.info '🔵 [BotMessagingService] Using create_message path (no attachments)'
      message = create_message(rendered)
    end

    # Trigger conversation events - handled automatically by Message model's after_create_commit
    # No need to manually trigger events here

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

    sanitized_attrs = LogSanitizerService.sanitize_for_log(message_params[:content_attributes])
    Rails.logger.info "🟢 BotMessagingService - Creating message with content_attributes: #{sanitized_attrs.inspect}"
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

  # Create message with attachments already attached (prevents race condition in send_reply)
  def create_message_with_attachments(rendered)
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

    Rails.logger.info '🟢 BotMessagingService - Creating message with attachments'
    Rails.logger.info "🟢 BotMessagingService - Sender: #{@sender.class.name} (ID: #{@sender.id})"
    Rails.logger.info "🟢 BotMessagingService - Message params sender_type: #{message_params[:sender_type]}"
    Rails.logger.info "🟢 BotMessagingService - Message params sender_id: #{message_params[:sender_id]}"
    if message_params[:content_type] == 'apple_time_picker'
      Rails.logger.info "🟢 BotMessagingService - Event timeslots: #{message_params.dig(:content_attributes, 'event', 'timeslots').inspect}"
    end

    # Add additional metadata
    message_params[:additional_attributes] = {
      template_id: @template.id,
      template_name: @template.name,
      rendered_at: Time.current.iso8601
    }

    message = nil

    # CRITICAL FIX: Skip callbacks, create message, attach files, then manually trigger send_reply
    # This ensures attachments are present before send_reply checks
    Message.skip_callback(:commit, :after, :execute_after_create_commit_callbacks)

    begin
      # Create message without triggering callbacks
      message = @conversation.messages.create!(message_params)

      Rails.logger.info "🟢 BotMessagingService - Message created! ID: #{message.id}"
      Rails.logger.info "🟢 BotMessagingService - ACTUAL sender_type: #{message.sender_type}"
      Rails.logger.info "🟢 BotMessagingService - ACTUAL sender_id: #{message.sender_id}"
      Rails.logger.info "🟢 BotMessagingService - ACTUAL message_type: #{message.message_type}"

      # Attach template files immediately
      if rendered[:attachments].present?
        Rails.logger.info "🟢 BotMessagingService - Attaching #{rendered[:attachments].count} files to message #{message.id}"
        attach_files_to_message(message, rendered[:attachments])
      end

      # Manually run the callbacks with attachments in place
      message.send(:execute_after_create_commit_callbacks)

    ensure
      # Re-enable the callback for other messages
      Message.set_callback(:commit, :after, :execute_after_create_commit_callbacks)
    end

    message
  end

  # Helper to attach files to an existing message
  def attach_files_to_message(message, template_attachments)
    template_attachments.each do |attachment_data|
      # Find the ActiveStorage blob
      blob = ActiveStorage::Blob.find(attachment_data[:blob_id])

      # Download the blob content
      file_content = blob.download

      # Create attachment record
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
