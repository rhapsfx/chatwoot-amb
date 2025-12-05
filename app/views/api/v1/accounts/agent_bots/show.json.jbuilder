json.partial! 'api/v1/models/agent_bot', formats: [:json], resource: AgentBotPresenter.new(@agent_bot)

# Add AMB-specific fields
if @agent_bot.apple_messages_for_business?
  json.agent_bot_inboxes @agent_bot.agent_bot_inboxes.active_bots do |inbox_assoc|
    json.id inbox_assoc.id
    json.inbox_id inbox_assoc.inbox_id
    json.priority inbox_assoc.priority
    json.status inbox_assoc.status
  end

  json.active_version do
    if @agent_bot.active_version
      json.id @agent_bot.active_version.id
      json.version_tag @agent_bot.active_version.version_tag
    end
  end
else
  # For webhook bots, return empty array to prevent frontend errors
  json.agent_bot_inboxes []
end
