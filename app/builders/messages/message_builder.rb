# frozen_string_literal: true

class Messages::MessageBuilder
  include ::FileTypeHelper
  include ::EmailHelper
  include ::DataHelper

  attr_reader :message

  def initialize(user, conversation, params)
    @params = params
    @private = params[:private] || false
    @conversation = conversation
    @user = user
    @account = conversation.account
    @message_type = params[:message_type] || 'outgoing'
    @attachments = params[:attachments]
    @automation_rule = content_attributes&.dig(:automation_rule_id)
    return unless params.instance_of?(ActionController::Parameters)

    @in_reply_to = content_attributes&.dig(:in_reply_to)
    @items = content_attributes&.dig(:items)
  end

  def perform
    @message = @conversation.messages.build(message_params)

    # 🔵 DEBUG: Log sender information
    Rails.logger.info "🔵 MessageBuilder - @user class: #{@user.class.name}, ID: #{@user.id}"
    Rails.logger.info "🔵 MessageBuilder - message_type: #{message_type}"
    Rails.logger.info "🔵 MessageBuilder - message_sender: #{message_sender.inspect}"
    Rails.logger.info "🔵 MessageBuilder - computed sender: #{sender.class.name}, ID: #{sender.id}"
    Rails.logger.info "🔵 MessageBuilder - @message.sender_type: #{@message.sender_type}"
    Rails.logger.info "🔵 MessageBuilder - @message.sender_id: #{@message.sender_id}"

    process_attachments
    process_emails

    # Debug log for Apple Messages
    if @message.content_type&.start_with?('apple_')
      Rails.logger.debug { "🔥 MessageBuilder - Saving #{@message.content_type} message (valid: #{@message.valid?})" }
      Rails.logger.error "🔥 Validation Errors: #{@message.errors.full_messages}" unless @message.valid?
    end

    # When the message has no quoted content, it will just be rendered as a regular message
    # The frontend is equipped to handle this case
    process_email_content
    @message.save!
    @message
  end

  private

  # Extracts content attributes from the given params.
  # - Converts ActionController::Parameters to a regular hash if needed.
  # - Attempts to parse a JSON string if content is a string.
  # - Returns an empty hash if content is not present, if there's a parsing error, or if it's an unexpected type.
  def content_attributes
    params = convert_to_hash(@params)
    content_attributes = params.fetch(:content_attributes, {})

    # Early return for String - use upstream's safe_parse_json
    if content_attributes.is_a?(String)
      parsed = safe_parse_json(content_attributes)
      # Debug log for Apple Messages
      if @params[:content_type]&.start_with?('apple_')
        image_count = params.key?(:images) ? params[:images]&.length : 0
        Rails.logger.debug { "🔥 MessageBuilder content_attributes - Type: #{@params[:content_type]}, Images: #{image_count}" }
      end
      return parsed
    end

    # Get content_attributes as hash
    parsed_content_attributes = content_attributes.is_a?(Hash) ? content_attributes : {}

    # 🔥 FIX: Include images in content_attributes for Apple Messages
    # Check both separate images parameter AND images nested in content_attributes
    if @params[:content_type]&.start_with?('apple_')
      if params.key?(:images)
        parsed_content_attributes[:images] = params[:images]
        Rails.logger.info '🔥 MessageBuilder content_attributes - Added images from separate parameter'
      elsif parsed_content_attributes.key?(:images) || parsed_content_attributes.key?('images')
        # Images are already in content_attributes, keep them there
        images_data = parsed_content_attributes[:images] || parsed_content_attributes['images']
        sanitized_images = LogSanitizerService.sanitize_for_log(images_data)
        Rails.logger.info "🔥 MessageBuilder content_attributes - Images already in content_attributes: #{sanitized_images.inspect}"
      else
        Rails.logger.info '🔥 MessageBuilder content_attributes - No images found anywhere'
      end
    end

    parsed_content_attributes
  end

  def process_attachments
    return if @attachments.blank?

    @attachments.each do |uploaded_attachment|
      attachment = @message.attachments.build(
        account_id: @message.account_id,
        file: uploaded_attachment
      )

      attachment.file_type = if uploaded_attachment.is_a?(String)
                               file_type_by_signed_id(
                                 uploaded_attachment
                               )
                             else
                               file_type(uploaded_attachment&.content_type)
                             end
    end
  end

  def process_emails
    return unless @conversation.inbox&.inbox_type == 'Email'

    cc_emails = process_email_string(@params[:cc_emails])
    bcc_emails = process_email_string(@params[:bcc_emails])
    to_emails = process_email_string(@params[:to_emails])

    all_email_addresses = cc_emails + bcc_emails + to_emails
    validate_email_addresses(all_email_addresses)

    @message.content_attributes[:cc_emails] = cc_emails
    @message.content_attributes[:bcc_emails] = bcc_emails
    @message.content_attributes[:to_emails] = to_emails
  end

  def process_email_content
    return unless should_process_email_content?

    @message.content_attributes ||= {}
    email_attributes = build_email_attributes
    @message.content_attributes[:email] = email_attributes
  end

  def process_email_string(email_string)
    return [] if email_string.blank?

    email_string.gsub(/\s+/, '').split(',')
  end

  def message_type
    if @conversation.inbox.channel_type != 'Channel::Api' && @message_type == 'incoming'
      raise StandardError, 'Incoming messages are only allowed in Api inboxes'
    end

    @message_type
  end

  def sender
    # FIX: Convert message_type to string for comparison (it's a Symbol from enum)
    result = message_type.to_s == 'outgoing' ? (message_sender || @user) : @conversation.contact

    Rails.logger.debug { "🔵 MessageBuilder sender: #{result.class.name} ID:#{result.id} (type: #{message_type})" }
    result
  end

  def external_created_at
    @params[:external_created_at].present? ? { external_created_at: @params[:external_created_at] } : {}
  end

  def automation_rule_id
    @automation_rule.present? ? { content_attributes: { automation_rule_id: @automation_rule } } : {}
  end

  def campaign_id
    @params[:campaign_id].present? ? { additional_attributes: { campaign_id: @params[:campaign_id] } } : {}
  end

  def template_params
    @params[:template_params].present? ? { additional_attributes: { template_params: JSON.parse(@params[:template_params].to_json) } } : {}
  end

  def message_sender
    return if @params[:sender_type] != 'AgentBot'

    AgentBot.where(account_id: [nil, @conversation.account.id]).find_by(id: @params[:sender_id])
  end

  def message_params
    {
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: message_type,
      content: @params[:content],
      private: @private,
      sender: sender,
      content_type: @params[:content_type] || 'text',
      content_attributes: content_attributes,
      items: @items,
      in_reply_to: @in_reply_to,
      echo_id: @params[:echo_id],
      source_id: @params[:source_id]
    }.merge(external_created_at).merge(automation_rule_id).merge(campaign_id).merge(template_params)
  end

  def email_inbox?
    @conversation.inbox&.inbox_type == 'Email'
  end

  def should_process_email_content?
    email_inbox? && !@private && @message.content.present?
  end

  def build_email_attributes
    email_attributes = ensure_indifferent_access(@message.content_attributes[:email] || {})
    normalized_content = normalize_email_body(@message.content)

    # Process liquid templates in normalized content with code block protection
    processed_content = process_liquid_in_email_body(normalized_content)

    # Use custom HTML content if provided, otherwise generate from message content
    email_attributes[:html_content] = if custom_email_content_provided?
                                        build_custom_html_content
                                      else
                                        build_html_content(processed_content)
                                      end

    email_attributes[:text_content] = build_text_content(processed_content)
    email_attributes
  end

  def build_html_content(normalized_content)
    html_content = ensure_indifferent_access(@message.content_attributes.dig(:email, :html_content) || {})
    rendered_html = render_email_html(normalized_content)
    html_content[:full] = rendered_html
    html_content[:reply] = rendered_html
    html_content
  end

  def build_text_content(normalized_content)
    text_content = ensure_indifferent_access(@message.content_attributes.dig(:email, :text_content) || {})
    text_content[:full] = normalized_content
    text_content[:reply] = normalized_content
    text_content
  end

  def custom_email_content_provided?
    @params[:email_html_content].present?
  end

  def build_custom_html_content
    html_content = ensure_indifferent_access(@message.content_attributes.dig(:email, :html_content) || {})

    html_content[:full] = @params[:email_html_content]
    html_content[:reply] = @params[:email_html_content]

    html_content
  end

  # Liquid processing methods for email content
  def process_liquid_in_email_body(content)
    return content if content.blank?
    return content unless should_process_liquid?

    # Protect code blocks from liquid processing
    modified_content = modified_liquid_content(content)
    template = Liquid::Template.parse(modified_content)
    template.render(drops_with_sender)
  rescue Liquid::Error
    content
  end

  def should_process_liquid?
    @message_type == 'outgoing' || @message_type == 'template'
  end

  def drops_with_sender
    message_drops(@conversation).merge({
                                         'agent' => UserDrop.new(sender)
                                       })
  end
end
