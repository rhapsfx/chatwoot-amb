class AppleMessagesForBusiness::SendOnAppleMessagesForBusinessService < Base::SendOnChannelService
  private

  def channel_class
    Channel::AppleMessagesForBusiness
  end

  def perform_reply
    Rails.logger.debug { "🔥 SendOnAMB - Processing #{message.content_type} message ID:#{message.id}" }

    case message.content_type
    when 'text'
      send_text_or_attachment_message
    when 'apple_list_picker'
      send_list_picker_message
    when 'apple_time_picker'
      send_time_picker_message
    when 'apple_quick_reply'
      send_quick_reply_message
    when 'apple_rich_link'
      send_rich_link_message
    when 'apple_form'
      send_form_message
    when 'apple_pay'
      send_apple_pay_message
    else
      Rails.logger.debug '🔥 Unknown content type, using fallback'
      send_text_or_attachment_message # fallback
    end
  end

  def send_text_or_attachment_message
    service = AppleMessagesForBusiness::SendMessageService.new(
      channel: channel,
      destination_id: message.conversation.contact_inbox.source_id,
      message: message
    )

    response = service.perform
    update_message_status(response)
  end

  def send_list_picker_message
    service = AppleMessagesForBusiness::SendListPickerService.new(
      channel: channel,
      destination_id: message.conversation.contact_inbox.source_id,
      message: message
    )

    response = service.perform
    update_message_status(response)
  end

  def send_time_picker_message
    service = AppleMessagesForBusiness::SendTimePickerService.new(
      channel: channel,
      destination_id: message.conversation.contact_inbox.source_id,
      message: message
    )

    response = service.perform
    update_message_status(response)
  end

  def send_quick_reply_message
    service = AppleMessagesForBusiness::SendQuickReplyService.new(
      channel: channel,
      destination_id: message.conversation.contact_inbox.source_id,
      message: message
    )

    response = service.perform
    update_message_status(response)
  end

  def send_rich_link_message
    service = AppleMessagesForBusiness::SendRichLinkService.new(
      channel: channel,
      destination_id: message.conversation.contact_inbox.source_id,
      message: message
    )

    response = service.perform
    update_message_status(response)
  end

  def send_form_message
    service = AppleMessagesForBusiness::SendMessageService.new(
      channel: channel,
      destination_id: message.conversation.contact_inbox.source_id,
      message: message
    )

    response = service.perform
    update_message_status(response)
  end

  def send_apple_pay_message
    # Extract payment data from message content_attributes
    payment_data = message.content_attributes.slice(
      'merchant_name',
      'currency_code',
      'country_code',
      'line_items',
      'total',
      'shipping_methods',
      'required_billing_fields',
      'required_shipping_fields',
      'requires_shipping',
      'requires_billing',
      'received_title',
      'received_subtitle',
      'received_style',
      'received_image_identifier'
    )

    service = AppleMessagesForBusiness::SendApplePayService.new(
      channel: channel,
      destination_id: message.conversation.contact_inbox.source_id,
      payment_data: payment_data
    )

    response = service.perform
    update_message_status(response)
  end

  def update_message_status(response)
    if response[:success]
      message.update!(source_id: response[:message_id])
    elsif message.content_type.start_with?('apple_')
      # For Apple Messages content types, preserve original content_attributes
      # Store error in BOTH content_attributes (for UI display) and additional_attributes (for backend reference)
      message.update!(
        status: :failed,
        content_attributes: message.content_attributes.merge(external_error: response[:error]),
        additional_attributes: message.additional_attributes.merge(external_error: response[:error])
      )
    else
      message.update!(
        status: :failed,
        content_attributes: { external_error: response[:error] }
      )
    end
  end
end
