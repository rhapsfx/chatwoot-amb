json.id message.id
json.content message.content
json.inbox_id message.inbox_id
json.echo_id message.echo_id if message.echo_id
json.conversation_id message.conversation.display_id
json.message_type message.message_type_before_type_cast
json.content_type message.content_type
json.status message.status
json.content_attributes message.content_attributes
# CRITICAL: Preserve exact key names in apple_msp_payload (e.g., 'quick-reply' with hyphen)
# jbuilder automatically camelizes nested hash keys
# We must use json.set! with the raw hash to prevent jbuilder from processing it
if message.apple_msp_payload.present?
  json.set! 'appleMspPayload', message.apple_msp_payload
end
json.created_at message.created_at.to_i
json.private message.private
json.source_id message.source_id
# Handle AgentBot sender correctly by passing inbox parameter
if message.sender
  if message.sender.is_a?(AgentBot)
    json.sender message.sender.push_event_data(message.inbox)
  else
    json.sender message.sender.push_event_data
  end
end
json.attachments message.attachments.map(&:push_event_data) if message.attachments.present?

json.set! :call, message.call.push_event_data if message.content_type == 'voice_call' && message.respond_to?(:call) && message.call.present?
