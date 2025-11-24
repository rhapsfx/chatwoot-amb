class AppleMessagesForBusiness::MessageProcessorService
  include Rails.application.routes.url_helpers

  def initialize(conversation, message_params, user)
    @conversation = conversation
    @message_params = message_params
    @user = user
    @inbox = conversation.inbox
  end

  def process_and_send
    return send_regular_message unless apple_messages_conversation?

    # Check if the customer has opted out (blocked)
    if customer_opted_out?
      Rails.logger.warn '[AMB MessageProcessor] Cannot send message - customer has opted out'
      raise StandardError, 'Cannot send message: Customer has opted out of receiving messages via Apple Messages'
    end

    # Handle Apple-specific message types first
    content_type = @message_params[:content_type]
    if apple_specific_content_type?(content_type)
      Rails.logger.info "[AMB MessageProcessor] Processing Apple-specific message type: #{content_type}"
      return send_apple_message
    end

    # Check if message contains URLs that should be converted to Rich Links
    message_content = @message_params[:content]
    message_parts = split_message_by_urls(message_content)

    # If no URLs found, send as regular message
    return send_regular_message if message_parts.empty?

    # If only one part and it's not a URL, send as regular message
    return send_regular_message if message_parts.length == 1 && message_parts.first[:type] != 'url'

    # Send multiple messages for text + Rich Links
    sent_messages = []

    message_parts.each do |part|
      case part[:type]
      when 'text'
        sent_messages << send_text_message(part[:content])
      when 'url'
        rich_link_message = create_rich_link_message(part[:content])
        sent_messages << (rich_link_message || send_text_message(part[:content]))
      end
    end

    sent_messages.compact
  end

  private

  def apple_specific_content_type?(content_type)
    %w[
      apple_form
      apple_list_picker
      apple_quick_reply
      apple_time_picker
      apple_custom_app
      apple_pay
      apple_authentication
      apple_custom_payload
    ].include?(content_type)
  end

  def send_apple_message
    Rails.logger.info '[AMB MessageProcessor] Creating Apple-specific message using MessageBuilder'

    # For Apple forms, use the form title as the message content if available
    message_params = @message_params.dup
    if @message_params[:content_type] == 'apple_form' && @message_params.dig(:content_attributes, 'title').present?
      message_params[:content] = @message_params[:content_attributes]['title']
    end

    # Clean placeholder content if template has attachments
    if @message_params[:template_id].present?
      template = MessageTemplate.find_by(id: @message_params[:template_id])
      message_params[:content] = clean_placeholder_content(message_params[:content]) if template&.attachments&.attached?
    end

    # Create the message using MessageBuilder (this validates and saves to DB)
    # The message will be automatically sent via SendReplyJob after_create_commit callback
    message = Messages::MessageBuilder.new(@user, @conversation, message_params).perform

    # If template_id is present, attach template files to the message
    attach_template_files(message, @message_params[:template_id]) if @message_params[:template_id].present?

    Rails.logger.info '[AMB MessageProcessor] Message created and will be sent automatically via SendReplyJob'

    # Don't manually send here - the after_create_commit callback in Message model
    # will trigger SendReplyJob.perform_later(id) which handles the actual sending
    # This prevents duplicate messages being sent to the device

    message
  end

  def apple_messages_conversation?
    @inbox.channel_type == 'Channel::AppleMessagesForBusiness'
  end

  def split_message_by_urls(text)
    return [{ type: 'text', content: text }] if text.blank?

    # Enhanced regex to match:
    # 1. URLs with protocol: http://example.com or https://example.com
    # 2. URLs without protocol: www.example.com or example.com/path
    url_with_protocol_regex = %r{https?://[^\s<>"{}|\\^`\[\]]+}i
    url_without_protocol_regex = %r{(?:www\.)[a-zA-Z0-9][-a-zA-Z0-9.]*\.[a-zA-Z]{2,}(?:/[^\s<>"{}|\\^`\[\]]*)?}i

    parts = []
    remaining_text = text.dup
    position = 0

    # First, find all URLs (with and without protocol)
    urls_found = []

    # Find URLs with protocol
    remaining_text.scan(url_with_protocol_regex) do |match|
      match_start = remaining_text.index(match, position)
      urls_found << { url: match, position: match_start, has_protocol: true } if match_start
    end

    # Find URLs without protocol (www.)
    remaining_text.scan(url_without_protocol_regex) do |match|
      match_start = remaining_text.index(match, position)
      # Only add if not already part of a URL with protocol
      next if urls_found.any? { |u| match_start >= u[:position] && match_start < u[:position] + u[:url].length }

      urls_found << { url: match, position: match_start, has_protocol: false } if match_start
    end

    # Sort URLs by position
    urls_found.sort_by! { |u| u[:position] }

    return [{ type: 'text', content: text }] if urls_found.empty?

    # Split text by URLs
    last_index = 0

    urls_found.each do |url_info|
      url = url_info[:url]
      match_start = url_info[:position]

      # Add text before URL if exists
      if match_start > last_index
        before_text = remaining_text[last_index...match_start].strip
        parts << { type: 'text', content: before_text } if before_text.present?
      end

      # Add URL (prepend https:// if missing protocol)
      normalized_url = url_info[:has_protocol] ? url : "https://#{url}"
      parts << { type: 'url', content: normalized_url, original: url }

      last_index = match_start + url.length
    end

    # Add remaining text after last URL if exists
    if last_index < remaining_text.length
      after_text = remaining_text[last_index..-1].strip
      parts << { type: 'text', content: after_text } if after_text.present?
    end

    parts.empty? ? [{ type: 'text', content: text }] : parts
  end

  def send_text_message(content)
    message_params = @message_params.merge(
      content: content,
      content_type: 'text'
    )

    Messages::MessageBuilder.new(@user, @conversation, message_params).perform
  end

  def create_rich_link_message(url)
    # Parse OpenGraph data for the URL
    parser_service = AppleMessagesForBusiness::OpenGraphParserService.new(url)
    result = parser_service.parse

    # Create Rich Link message with parsed data (or defaults if parsing failed)
    content_attributes = {
      url: result[:url] || url,
      title: result[:title] || url,
      description: result[:description],
      site_name: result[:site_name]
    }

    # Only add image data if we have an image URL
    if result[:image_url].present?
      content_attributes[:image_data] = result[:image_url]
      content_attributes[:image_mime_type] = 'image/png' # Default to PNG for web images
    end

    rich_link_params = @message_params.merge(
      content: url,
      content_type: 'apple_rich_link',
      content_attributes: content_attributes
    )

    Messages::MessageBuilder.new(@user, @conversation, rich_link_params).perform
  rescue StandardError => e
    Rails.logger.error "Rich Link creation failed for URL #{url}: #{e.message}"
    # Fallback to creating a basic Rich Link with just the URL
    fallback_params = @message_params.merge(
      content: url,
      content_type: 'apple_rich_link',
      content_attributes: {
        url: url,
        title: url,
        description: nil,
        image_data: nil, # Use image_data instead of image_url
        site_name: nil
      }
    )
    Messages::MessageBuilder.new(@user, @conversation, fallback_params).perform
  end

  def send_regular_message
    message_params = @message_params.dup

    # Clean placeholder content if template has attachments
    if @message_params[:template_id].present?
      template = MessageTemplate.find_by(id: @message_params[:template_id])
      message_params[:content] = clean_placeholder_content(message_params[:content]) if template&.attachments&.attached?
    end

    message = Messages::MessageBuilder.new(@user, @conversation, message_params).perform

    # If template_id is present, attach template files to the message
    attach_template_files(message, @message_params[:template_id]) if @message_params[:template_id].present?

    message
  end

  def customer_opted_out?
    # Check if the customer has been blocked due to AMB close event
    contact = @conversation.contact
    return false unless contact

    # Check if this customer has opted out (blocked) via AMB close event
    contact.additional_attributes&.dig('apple_messages_blocked') == true
  end

  # Clean placeholder content for messages with template attachments
  # This removes generic "Message" text that would appear as a separate bubble
  def clean_placeholder_content(content)
    return content if content.blank?

    stripped = content.strip

    # Remove generic "Message" text (case-insensitive)
    # Keep empty string - SendMessageService will add the replacement character (￼)
    return '' if /^Message$/i.match?(stripped)

    # Remove "Message " prefix but keep the replacement character
    # This handles: "Message ￼" -> "￼"
    return stripped.gsub(/^Message\s+/i, '')
  end

  # Attach template files to the message
  # This is called when a message is created from a template with attachments
  def attach_template_files(message, template_id)
    template = MessageTemplate.find_by(id: template_id)
    return unless template&.attachments&.attached?

    Rails.logger.info "[AMB MessageProcessor] Attaching #{template.attachments.count} template files to message #{message.id}"

    # Get ordered attachment IDs from metadata
    display_order = template.attachment_metadata.dig('display_order') || []

    # Sort attachments by display order
    ordered_attachments = if display_order.present?
                            display_order.filter_map { |id| template.attachments.find { |a| a.id == id } }
                          else
                            template.attachments.to_a
                          end

    # Attach each file to the message
    ordered_attachments.each do |attachment|
      # Download the blob content
      file_content = attachment.download

      # Create a new Attachment record for the message
      message.attachments.create!(
        file_type: determine_file_type(attachment.content_type),
        account_id: message.account_id,
        file: {
          io: StringIO.new(file_content),
          filename: attachment.filename.to_s,
          content_type: attachment.content_type
        }
      )

      Rails.logger.info "[AMB MessageProcessor] Attached file '#{attachment.filename}' to message #{message.id}"
    rescue StandardError => e
      Rails.logger.error "[AMB MessageProcessor] Failed to attach file #{attachment.filename}: #{e.message}"
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
end
