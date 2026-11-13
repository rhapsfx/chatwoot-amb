class AppleMessagesForBusiness::SendQuickReplyService < AppleMessagesForBusiness::SendMessageService
  private

  def build_quick_reply_items
    items = content_attributes['items'] || []

    # Ensure we have between 2-5 items as per Apple specification
    if items.empty?
      items = default_items
    elsif items.length > 5
      items = items.first(5)
    elsif items.length < 2
      items += default_items.drop(items.length)
    end

    items.map do |item|
      {
        identifier: item['identifier'].presence || SecureRandom.uuid,
        title: item['title'] || 'Option'
      }
    end
  end

  def build_received_message
    {
      title: content_attributes['received_title'] || 'Please select an option',
      subtitle: content_attributes['received_subtitle'],
      imageIdentifier: content_attributes['received_image_identifier'],
      style: content_attributes['received_style'] || 'small'
    }.compact
  end

  def build_reply_message
    {
      title: content_attributes['reply_title'] || 'Selected: ${item.title}',
      subtitle: content_attributes['reply_subtitle'],
      imageIdentifier: content_attributes['reply_image_identifier'],
      style: content_attributes['reply_style'] || 'icon'
    }.compact
  end

  def default_items
    [
      { 'title' => 'Yes', 'identifier' => 'yes' },
      { 'title' => 'No', 'identifier' => 'no' }
    ]
  end

  def content_attributes
    @content_attributes ||= message.content_attributes || {}
  end
end
