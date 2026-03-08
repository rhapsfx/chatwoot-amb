# frozen_string_literal: true

class AppleMessagesForBusiness::BotDelayedActionJob < ApplicationJob
  queue_as :default

  def perform(conversation_id:, method_name:)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    last_message = conversation.messages.order(created_at: :desc).first
    return unless last_message

    service = AppleMessagesForBusiness::AcousticHouseBotService.new(conversation, last_message)
    return unless service.respond_to?(method_name, true)

    service.send(method_name)
  rescue StandardError => e
    Rails.logger.error "[AMB BotDelayedActionJob] Error running #{method_name}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
