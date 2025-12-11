class AddArchivedAtToAgentBotVersions < ActiveRecord::Migration[7.1]
  def change
    add_column :agent_bot_versions, :archived_at, :datetime
    add_index :agent_bot_versions, :archived_at
  end
end
