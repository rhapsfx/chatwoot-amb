json.partial! 'api/v1/models/agent_bot', formats: [:json], resource: AgentBotPresenter.new(@agent_bot)

# Add AMB-specific fields for duplicated bots
if @agent_bot.apple_messages_for_business?
  # Duplicated bots have no inboxes assigned yet
  json.agent_bot_inboxes []

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
