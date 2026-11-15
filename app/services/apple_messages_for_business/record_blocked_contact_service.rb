class AppleMessagesForBusiness::RecordBlockedContactService
  pattr_initialize [:inbox!, :destination_id!, :reason]

  def perform
    contact = find_contact
    unless contact
      Rails.logger.warn "[AMB RecordBlockedContact] No contact found for destination_id: #{destination_id}"
      return
    end

    attrs = contact.additional_attributes || {}
    attrs['apple_messages_blocked'] = true
    attrs['apple_messages_blocked_at'] = Time.current.iso8601
    attrs['apple_messages_block_reason'] = reason || 'reactive_410'
    contact.update!(additional_attributes: attrs)

    Rails.logger.info "[AMB RecordBlockedContact] Contact #{contact.id} marked as blocked (reason: #{attrs['apple_messages_block_reason']})"
  end

  private

  def find_contact
    ContactInbox.joins(:contact)
                .where(inbox: inbox, source_id: destination_id)
                .first&.contact ||
      Contact.joins(:contact_inboxes)
             .where(contact_inboxes: { inbox: inbox })
             .where("additional_attributes->>'apple_messages_source_id' = ?", destination_id)
             .first
  end
end
