class AppleMessages::OneoffInvitationCampaignService
  pattr_initialize [:campaign!]

  def perform
    validate_campaign!
    process_audience
    campaign.completed!
  end

  private

  delegate :inbox, to: :campaign

  def validate_campaign!
    raise "Invalid campaign #{campaign.id}" unless amb_campaign? && campaign.one_off?
    raise 'Completed Campaign' if campaign.completed?
    raise 'No template_params configured' if campaign.template_params.blank?
  end

  def amb_campaign?
    campaign.inbox.inbox_type == 'AppleMessagesForBusiness'
  end

  def process_audience
    contacts_from_labels.each { |contact| send_to_contact_phone(contact.phone_number, contact) }
    direct_phones.each { |phone| send_to_contact_phone(phone, nil) }
  end

  def contacts_from_labels
    label_ids = campaign.audience.select { |a| a['type'] == 'Label' }.pluck('id')
    return [] if label_ids.empty?

    labels = campaign.account.labels.where(id: label_ids).pluck(:title)
    campaign.account.contacts.tagged_with(labels, any: true)
  end

  def direct_phones
    campaign.audience.select { |a| a['type'] == 'Phone' }.pluck('phone')
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def send_to_contact_phone(phone, contact)
    if phone.blank?
      Rails.logger.info "[AMB Campaign #{campaign.id}] Skipping contact - no phone number"
      return
    end

    dest = phone.start_with?('tel:') ? phone : "tel:#{phone}"

    if AppleInvitationOptOut.opted_out?(phone_number: dest, inbox_id: inbox.id)
      Rails.logger.info "[AMB Campaign #{campaign.id}] Skipping #{dest} - opted out"
      return
    end

    result = AppleMessagesForBusiness::SendInvitationService.new(
      inbox: inbox,
      destination_id: dest,
      template_id: campaign.template_params['template_id'],
      reference_id: build_reference_id(contact),
      parameters: campaign.template_params['parameters'] || {},
      locale: campaign.template_params['locale']
    ).perform

    store_message_record(contact, result) if result[:success]
  rescue StandardError => e
    Rails.logger.error "[AMB Campaign #{campaign.id}] Failed for #{dest}: #{e.message}"
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  def store_message_record(contact, _result)
    conversation = find_or_create_conversation(contact)
    return unless conversation

    conversation.messages.create!(
      message_type: :outgoing,
      content_type: :apple_invitation,
      content_attributes: {
        'invitation_template_id' => campaign.template_params['template_id'],
        'reference_id' => build_reference_id(contact),
        'parameters' => campaign.template_params['parameters'],
        'locale' => campaign.template_params['locale']
      },
      account_id: campaign.account_id
    )
  rescue StandardError => e
    Rails.logger.error "[AMB Campaign #{campaign.id}] Failed to store message record: #{e.message}"
  end

  def find_or_create_conversation(contact)
    return nil unless contact

    inbox.conversations.find_or_create_by!(
      contact_id: contact.id,
      account_id: campaign.account_id
    )
  rescue StandardError => e
    Rails.logger.error "[AMB Campaign #{campaign.id}] Failed to find/create conversation: #{e.message}"
    nil
  end

  def build_reference_id(contact)
    if contact
      "campaign-#{campaign.id}-contact-#{contact.id}"
    else
      "campaign-#{campaign.id}-#{SecureRandom.hex(4)}"
    end
  end
end
