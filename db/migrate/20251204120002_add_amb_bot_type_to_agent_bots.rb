# frozen_string_literal: true

class AddAmbBotTypeToAgentBots < ActiveRecord::Migration[7.0]
  def up
    # NOTE: The bot_type column is an integer column with Rails enum mapping.
    # No database changes are needed - the enum is defined in the AgentBot model:
    #   enum bot_type: { webhook: 0, apple_messages_for_business: 1 }
    #
    # This migration exists for version tracking and documentation purposes.

    # Add a comment to the bot_type column to document the new value
    execute <<-SQL
      COMMENT ON COLUMN agent_bots.bot_type IS 'Bot type: 0 = webhook, 1 = apple_messages_for_business (AMB)';
    SQL
  end

  def down
    # Remove the column comment
    execute <<-SQL
      COMMENT ON COLUMN agent_bots.bot_type IS NULL;
    SQL
  end
end
