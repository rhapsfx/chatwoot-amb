class AppleMessagesForBusiness::OptOutCheckerService
  pattr_initialize [:inbox!, :destination_id!]

  def opted_out?
    contact_blocked? || invitation_opted_out?
  end

  private

  def contact_blocked?
    Contact.joins(:contact_inboxes)
           .where(contact_inboxes: { inbox: inbox })
           .where("additional_attributes->>'apple_messages_source_id' = ?", destination_id)
           .where("additional_attributes->>'apple_messages_blocked' = ?", 'true')
           .exists?
  end

  def invitation_opted_out?
    AppleInvitationOptOut.opted_out?(account_id: inbox.account_id, phone_number: phone_key, inbox_id: inbox.id)
  end

  def phone_key
    destination_id.to_s.start_with?('tel:') ? destination_id : "tel:#{destination_id}"
  end
end
