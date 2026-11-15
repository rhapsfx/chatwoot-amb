# frozen_string_literal: true

class AppleMessagesForBusiness::BotInteractiveResponseJob < ApplicationJob
  queue_as :default

  def perform(conversation_id:, message_id:)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    message = conversation.messages.find_by(id: message_id)
    return unless message

    # Prefer the fully processed interactive_response (set by process_interactive_data after message creation),
    # fall back to the raw bot_interactive_data stored synchronously before that step ran.
    interactive_data = message.content_attributes['interactive_response'] ||
                       message.content_attributes['bot_interactive_data']
    return unless interactive_data

    service = AppleMessagesForBusiness::AcousticHouseBotService.new(conversation, message)
    service.process_interactive_response(interactive_data)
  rescue StandardError => e
    Rails.logger.error "[AMB BotInteractiveResponseJob] Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
