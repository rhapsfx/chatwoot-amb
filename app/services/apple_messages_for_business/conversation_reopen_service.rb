class AppleMessagesForBusiness::ConversationReopenService
  def initialize(inbox:, source_id:)
    @inbox = inbox
    @source_id = source_id
  end

  def perform
    Rails.logger.info "[AMB ConversationReopen] Re-enabling messages for source_id: #{@source_id}"

    # NOTE: this only clears the opaque-ID `apple_messages_blocked` flag on Contact. It
    # deliberately does NOT touch any AppleInvitationOptOut row for this contact's phone number —
    # per spec, receiving a message must not by itself re-enable invitations; the customer must
    # explicitly re-subscribe with the same phone number through a valid opt-in channel.

    # Find the contact by ContactInbox source_id (reliable - always set for AMB)
    # Fallback to JSONB query on contact additional_attributes for backwards compatibility
    contact_inbox = ContactInbox.joins(:contact)
                                .where(inbox: @inbox)
                                .where(source_id: @source_id)
                                .first
    contact_inbox ||= ContactInbox.joins(:contact)
                                  .where(inbox: @inbox)
                                  .where("contacts.additional_attributes->>'apple_messages_source_id' = ?", @source_id)
                                  .first

    return unless contact_inbox

    contact = contact_inbox.contact

    # Remove blocking flags from contact
    was_blocked = contact.additional_attributes&.dig('apple_messages_blocked')
    if was_blocked
      contact_attrs = contact.additional_attributes.dup
      contact_attrs.delete('apple_messages_blocked')
      contact_attrs.delete('apple_messages_blocked_at')
      contact_attrs.delete('apple_messages_block_reason')
      contact_attrs.delete('apple_close_event_id')
      contact_attrs['apple_messages_reopened_at'] = Time.current.iso8601
      contact_attrs['apple_messages_reopen_reason'] = 'customer_message_received'
      contact.additional_attributes = contact_attrs
      contact.save!
      Rails.logger.info "[AMB ConversationReopen] Unblocked contact #{contact.id}"

      reopen_conversation(contact_inbox)
    end

    Rails.logger.info "[AMB ConversationReopen] Successfully re-enabled messages for source_id: #{@source_id}"
  end

  private

  def reopen_conversation(contact_inbox)
    conversation = contact_inbox.conversations
                                .where(status: :resolved)
                                .where("additional_attributes->>'closed_by' = ?", 'apple_messages_for_business')
                                .order(updated_at: :desc)
                                .first

    return unless conversation

    additional_attrs = (conversation.additional_attributes || {}).except(
      'closed_by', 'close_reason', 'closed_at', 'apple_close_event_id'
    )
    conversation.update!(status: :open, additional_attributes: additional_attrs)
    conversation.messages.create!(
      content: 'Customer reconnected via Apple Messages.',
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :activity,
      sender: nil,
      content_type: 'text'
    )
    Rails.logger.info "[AMB ConversationReopen] Reopened conversation #{conversation.id}"
  end
end
