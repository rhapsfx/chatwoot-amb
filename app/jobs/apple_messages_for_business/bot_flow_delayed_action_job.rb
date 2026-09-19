class AppleMessagesForBusiness::BotFlowDelayedActionJob < ApplicationJob
  queue_as :default

  def perform(conversation_id:, next_step_id:)
    conversation = Conversation.find(conversation_id)
    return unless conversation.inbox.agent_bot&.flow?

    service = AppleMessagesForBusiness::BotFlowRuntimeService.new(conversation)
    service.process_delayed_action({ 'next_step_id' => next_step_id })
  end
end
