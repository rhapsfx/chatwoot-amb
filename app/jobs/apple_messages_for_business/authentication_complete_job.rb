# frozen_string_literal: true

# Job to handle completed OAuth authentication
# - Updates contact with OAuth user data
# - Creates activity message in conversation
# - Sends confirmation message to user
class AppleMessagesForBusiness::AuthenticationCompleteJob < ApplicationJob
  queue_as :default

  def perform(channel_id:, auth_key:, user_data:, provider:, destination_id:)
    Rails.logger.info "[AMB Auth Job] Starting authentication completion for destination_id: #{destination_id}"
    Rails.logger.info "[AMB Auth Job] User data: #{user_data.inspect}"

    channel = Channel::AppleMessagesForBusiness.find(channel_id)
    Rails.logger.info "[AMB Auth Job] Found channel: #{channel.id}"

    # Find the contact via ContactInbox (source_id is in contact_inboxes table, not contacts)
    contact_inbox = channel.inbox.contact_inboxes.find_by(
      source_id: destination_id
    )
    Rails.logger.info "[AMB Auth Job] ContactInbox lookup result: #{contact_inbox ? "found (id: #{contact_inbox.id})" : 'not found'}"
    return unless contact_inbox

    contact = contact_inbox.contact
    Rails.logger.info "[AMB Auth Job] Contact: #{contact.id}, current name: #{contact.name}, current email: #{contact.email}"

    conversation = channel.inbox.conversations.where(
      contact_id: contact.id
    ).last
    Rails.logger.info "[AMB Auth Job] Conversation: #{conversation ? conversation.id : 'not found'}"
    return unless conversation

    # Update contact with OAuth user data
    update_contact_with_oauth_data(contact, user_data, provider)

    # Create activity message in conversation
    create_activity_message(conversation, user_data, provider)

    # Send confirmation message to user via Apple Messages
    send_confirmation_message(channel, destination_id, user_data, provider, conversation)

    Rails.logger.info "[AMB Auth] Authentication completed for #{user_data['name']} via #{provider}"
  rescue StandardError => e
    Rails.logger.error "[AMB Auth Job] Error during authentication completion: #{e.message}"
    Rails.logger.error "[AMB Auth Job] Backtrace: #{e.backtrace.first(10).join("\n")}"
    raise e # Re-raise to trigger Sidekiq retry
  end

  private

  def update_contact_with_oauth_data(contact, user_data, provider)
    # Update contact with OAuth data
    updates = {}

    # Update name if available and not already set
    updates[:name] = user_data['name'] if user_data['name'].present? && (contact.name.blank? || contact.name == 'MD - Own ID')

    # Update email if available
    updates[:email] = user_data['email'] if user_data['email'].present?

    # Store OAuth data in custom attributes
    custom_attrs = contact.custom_attributes || {}
    custom_attrs["#{provider}_id"] = user_data['id']
    custom_attrs["#{provider}_profile"] = user_data['picture'] if user_data['picture']
    custom_attrs['authenticated_at'] = Time.current.iso8601
    custom_attrs['auth_provider'] = provider
    updates[:custom_attributes] = custom_attrs

    contact.update!(updates) if updates.any?

    Rails.logger.info "[AMB Auth] Updated contact #{contact.id} with OAuth data from #{provider}"
    Rails.logger.info "[AMB Auth] Contact after update - name: #{contact.reload.name}, email: #{contact.email}"
  end

  def create_activity_message(conversation, user_data, provider)
    # Create an activity message showing authentication success
    content = "✅ Authenticated via #{provider.capitalize}\n" \
              "Name: #{user_data['name']}\n" \
              "Email: #{user_data['email']}"

    Message.create!(
      conversation: conversation,
      inbox: conversation.inbox,
      account: conversation.account,
      message_type: :activity,
      content: content,
      content_type: 'text',
      content_attributes: {
        'activity_type' => 'oauth_authentication',
        'provider' => provider,
        'user_data' => user_data
      }
    )

    Rails.logger.info "[AMB Auth] Created activity message for conversation #{conversation.id}"
  end

  def send_confirmation_message(channel, destination_id, user_data, provider, conversation)
    Rails.logger.info "[AMB Auth] Preparing to send confirmation message to #{user_data['name']}"

    # Send a confirmation message to the user via Apple Messages
    message_content = "✅ Authentication Successful!\n\n" \
                      "Welcome, #{user_data['name']}!\n" \
                      "You've successfully authenticated with #{provider.capitalize}."

    # Create outgoing message in conversation
    message = Message.create!(
      conversation: conversation,
      inbox: channel.inbox,
      account: channel.account,
      message_type: :outgoing,
      content: message_content,
      content_type: 'text',
      sender: conversation.inbox.account.users.first
    )
    Rails.logger.info "[AMB Auth] Created outgoing message #{message.id} in conversation #{conversation.id}"

    # Send via Apple MSP
    send_service = AppleMessagesForBusiness::SendMessageService.new(
      channel: channel,
      destination_id: destination_id,
      message: message
    )
    result = send_service.perform
    Rails.logger.info "[AMB Auth] SendMessageService result: #{result.inspect}"

    Rails.logger.info '[AMB Auth] Sent confirmation message to user via Apple Messages'
  end
end
