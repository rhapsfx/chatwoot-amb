class AppleMessagesForBusiness::CloseSessionHandlerService
  pattr_initialize [:inbox!, :params!]

  def perform
    phone_number = params['sourceId']
    reference_ids = params['referenceIds'] || []

    Rails.logger.info "[AMB CloseSession] Processing opt-out for #{phone_number}"

    contact = find_contact(phone_number)
    unless contact
      Rails.logger.warn "[AMB CloseSession] No contact found for #{phone_number}, skipping"
      return
    end

    record_opt_out(contact, phone_number, reference_ids)
    add_activity_to_conversation(contact)
  end

  private

  def find_contact(phone_number)
    normalized = phone_number.gsub(/^tel:/, '')
    @inbox.account.contacts.where(phone_number: normalized).first
  end

  def record_opt_out(contact, phone_number, reference_ids)
    AppleInvitationOptOut.find_or_initialize_by(
      account_id: @inbox.account_id,
      phone_number: phone_number,
      inbox_id: @inbox.id
    ).update!(
      contact: contact,
      opted_out_at: Time.current,
      reference_ids: reference_ids
    )
    Rails.logger.info "[AMB CloseSession] Opt-out recorded for #{phone_number}"
  end

  def add_activity_to_conversation(contact)
    conversation = @inbox.conversations
                         .where(contact_id: contact.id)
                         .order(created_at: :desc)
                         .first
    return unless conversation

    conversation.messages.create!(
      message_type: :activity,
      content: I18n.t('apple_messages.invitation.user_left_conversation'),
      account_id: @inbox.account_id
    )
    Rails.logger.info "[AMB CloseSession] Activity message added to conversation #{conversation.id}"
  end
end
