class AppleMessagesForBusiness::ConversationCloseService
  def initialize(inbox:, params:, headers:)
    @inbox = inbox
    @params = params
    @headers = headers
  end

  def perform
    Rails.logger.info '[AMB ConversationClose] Starting conversation close processing'
    Rails.logger.info "[AMB ConversationClose] Params: #{@params.inspect}"
    Rails.logger.info "[AMB ConversationClose] Headers: #{@headers.inspect}"

    return unless valid_close_event?

    if phone_source_id?
      process_phone_close
    else
      process_opaque_close
    end

    Rails.logger.info '[AMB ConversationClose] Conversation close processing completed successfully'
  end

  private

  # Per the Apple MSP spec, a CloseSession's sourceId is either:
  # - the customer's opaque ID, when a conversation previously existed, or
  # - the customer's phone number in `tel:+1234567890` form, when it never did
  #   (e.g. they declined an invitation, or left before ever texting).
  # Both cases arrive as the same `type: close` event and are distinguished only by this shape.
  def phone_source_id?
    source_id.to_s.start_with?('tel:')
  end

  def valid_close_event?
    has_id = @params['id'].present?
    has_source_id = source_id.present?

    Rails.logger.info "[AMB ConversationClose] Validation - ID: #{has_id}, Source ID: #{has_source_id}"

    valid = has_id && has_source_id
    Rails.logger.info "[AMB ConversationClose] Close event validation result: #{valid}"

    valid
  end

  # --- Opaque-ID path: an existing AMB conversation is being closed ---

  def process_opaque_close
    find_conversation
    return unless @conversation

    close_conversation
    block_future_messages
    create_activity_message
  end

  def find_conversation
    Rails.logger.info "[AMB ConversationClose] Looking for conversation with source_id: #{source_id}"

    # Find the contact first by ContactInbox source_id (reliable - always set for AMB)
    # Fallback to JSONB query on contact additional_attributes for backwards compatibility
    contact_inbox = ContactInbox.joins(:contact)
                                .where(inbox: @inbox)
                                .where(source_id: source_id)
                                .first
    contact_inbox ||= ContactInbox.joins(:contact)
                                  .where(inbox: @inbox)
                                  .where("contacts.additional_attributes->>'apple_messages_source_id' = ?", source_id)
                                  .first

    unless contact_inbox
      Rails.logger.warn "[AMB ConversationClose] No contact found for source_id: #{source_id}"
      Rails.logger.info '[AMB ConversationClose] Searching for conversation by source_id in conversation additional_attributes...'

      # Fallback: Try to find conversation directly by source_id in additional_attributes
      @conversation = @inbox.conversations
                            .where("additional_attributes->>'apple_messages_source_id' = ?", source_id)
                            .where(status: [:open, :pending])
                            .order(updated_at: :desc)
                            .first

      if @conversation
        Rails.logger.info "[AMB ConversationClose] Found conversation #{@conversation.id} via fallback search"
        @contact_inbox = @conversation.contact_inbox
        @contact = @conversation.contact
      else
        Rails.logger.warn '[AMB ConversationClose] No conversation found via fallback search either'
      end

      return
    end

    # Find the most recent conversation for this contact (include resolved to handle repeated close events)
    @conversation = contact_inbox.conversations
                                 .where(status: [:open, :pending, :resolved])
                                 .order(updated_at: :desc)
                                 .first

    if @conversation
      Rails.logger.info "[AMB ConversationClose] Found conversation to close - ID: #{@conversation.id}, Status: #{@conversation.status}"
      @contact_inbox = contact_inbox
      @contact = contact_inbox.contact
    else
      Rails.logger.warn "[AMB ConversationClose] No active conversation found for source_id: #{source_id}"
    end
  end

  def close_conversation
    Rails.logger.info "[AMB ConversationClose] Closing conversation ID: #{@conversation.id}"

    # Skip if conversation is already closed by AMB (avoid duplicate processing)
    if @conversation.status == 'resolved' &&
       @conversation.additional_attributes&.dig('closed_by') == 'apple_messages_for_business'
      Rails.logger.info "[AMB ConversationClose] Conversation #{@conversation.id} already closed by AMB, skipping"
      return
    end

    # Mark conversation as resolved
    @conversation.status = :resolved

    # Add close reason to additional attributes
    additional_attrs = @conversation.additional_attributes || {}
    additional_attrs['closed_by'] = 'apple_messages_for_business'
    additional_attrs['close_reason'] = 'customer_opted_out'
    additional_attrs['closed_at'] = Time.current.iso8601
    additional_attrs['apple_close_event_id'] = @params['id']
    @conversation.additional_attributes = additional_attrs

    @conversation.save!

    Rails.logger.info "[AMB ConversationClose] Conversation #{@conversation.id} closed successfully"
  end

  def block_future_messages
    Rails.logger.info "[AMB ConversationClose] Blocking future messages for source_id: #{source_id}"

    # CRITICAL REQUIREMENT: Block this user from receiving further messages
    # as per Apple MSP specification

    # Mark contact as blocked for Apple Messages
    contact_attrs = @contact.additional_attributes || {}
    contact_attrs['apple_messages_blocked'] = true
    contact_attrs['apple_messages_blocked_at'] = Time.current.iso8601
    contact_attrs['apple_messages_block_reason'] = 'customer_opted_out'
    contact_attrs['apple_close_event_id'] = @params['id']
    @contact.additional_attributes = contact_attrs
    @contact.save!

    Rails.logger.info "[AMB ConversationClose] Contact #{@contact.id} marked as blocked"
  end

  def create_activity_message
    Rails.logger.info '[AMB ConversationClose] Creating activity message for conversation close'

    @conversation.messages.create!(
      content: 'Customer opted out of receiving messages via Apple Messages. They must send a new message to resume the conversation or you shall offer to send an Apple Invitation.',
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :activity,
      sender: nil,
      content_type: 'text',
      content_attributes: {
        automation_rule_id: nil,
        system_generated: true,
        close_event_id: @params['id'],
        closed_by: 'apple_messages_for_business',
        blocked_user: true
      },
      source_id: @params['id']
    )

    Rails.logger.info '[AMB ConversationClose] Activity message created successfully'
  end

  # --- Phone path: the customer never had (or no longer has) an opaque-ID conversation ---
  # This covers both a declined invitation and a customer leaving before ever texting the business.

  def process_phone_close
    Rails.logger.info "[AMB ConversationClose] Processing phone-based close for #{source_id}"

    contact = find_contact_by_phone
    unless contact
      Rails.logger.warn "[AMB ConversationClose] No contact found for phone #{source_id}, skipping"
      return
    end

    record_invitation_opt_out(contact)
    add_activity_to_phone_conversation(contact)
  end

  def find_contact_by_phone
    @inbox.account.contacts.where(phone_number: normalized_phone).first
  end

  def normalized_phone
    source_id.to_s.sub(/\Atel:/, '')
  end

  def record_invitation_opt_out(contact)
    AppleInvitationOptOut.find_or_initialize_by(
      account_id: @inbox.account_id,
      phone_number: source_id,
      inbox_id: @inbox.id
    ).update!(
      contact: contact,
      opted_out_at: Time.current,
      reference_ids: @params['referenceIds'] || []
    )

    Rails.logger.info "[AMB ConversationClose] Invitation opt-out recorded for #{source_id}"
  end

  def add_activity_to_phone_conversation(contact)
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

    Rails.logger.info "[AMB ConversationClose] Activity message added to conversation #{conversation.id}"
  end

  def source_id
    @headers[:source_id] || @params['sourceId']
  end
end
