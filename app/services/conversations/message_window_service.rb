class Conversations::MessageWindowService
  MESSAGING_WINDOW_24_HOURS = 24.hours
  MESSAGING_WINDOW_7_DAYS = 7.days

  def initialize(conversation)
    @conversation = conversation
  end

  def can_reply?
    return false if apple_messages_user_blocked?

    return true if messaging_window.blank?

    last_message_in_messaging_window?(messaging_window)
  end

  private

  def messaging_window
    case @conversation.inbox.channel_type
    when 'Channel::Api'
      api_messaging_window
    when 'Channel::FacebookPage'
      messenger_messaging_window
    when 'Channel::Instagram'
      instagram_messaging_window
    when 'Channel::Tiktok'
      tiktok_messaging_window
    when 'Channel::AppleMessagesForBusiness'
      nil
    when 'Channel::Whatsapp'
      MESSAGING_WINDOW_24_HOURS
    when 'Channel::TwilioSms'
      twilio_messaging_window
    end
  end

  def last_message_in_messaging_window?(time)
    return false if last_incoming_message.nil?

    Time.current < last_incoming_message.created_at + time
  end

  def api_messaging_window
    channel_attrs = @conversation.inbox.channel.respond_to?(:additional_attributes) ? @conversation.inbox.channel.additional_attributes : {}
    return if channel_attrs['agent_reply_time_window'].blank?

    channel_attrs['agent_reply_time_window'].to_i.hours
  end

  # Check medium of the inbox to determine the messaging window
  def twilio_messaging_window
    @conversation.inbox.channel.medium == 'whatsapp' ? MESSAGING_WINDOW_24_HOURS : nil
  end

  def messenger_messaging_window
    meta_messaging_window('ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT')
  end

  def instagram_messaging_window
    meta_messaging_window('ENABLE_INSTAGRAM_CHANNEL_HUMAN_AGENT')
  end

  def tiktok_messaging_window
    48.hours
  end

  def meta_messaging_window(config_key)
    GlobalConfigService.load(config_key, nil) ? MESSAGING_WINDOW_7_DAYS : MESSAGING_WINDOW_24_HOURS
  end

  def last_incoming_message
    @last_incoming_message ||= @conversation.messages.where(account_id: @conversation.account_id).incoming&.last
  end
end

  # Check if the contact has opted out of Apple Messages for Business
  def apple_messages_user_blocked?
    return false unless @conversation.inbox.channel_type == 'Channel::AppleMessagesForBusiness'

    @conversation.contact.additional_attributes&.dig('apple_messages_blocked') == true
  end
end
