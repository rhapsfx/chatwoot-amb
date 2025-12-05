# frozen_string_literal: true

class EnhanceAgentBotInboxes < ActiveRecord::Migration[7.0]
  def change
    add_column :agent_bot_inboxes, :priority, :integer, default: 10, null: false
    add_column :agent_bot_inboxes, :config_overrides, :jsonb, default: {}, null: false
    add_column :agent_bot_inboxes, :version_id, :bigint
    add_column :agent_bot_inboxes, :notes, :text

    # Add foreign key for version_id
    add_foreign_key :agent_bot_inboxes, :agent_bot_versions, column: :version_id, on_delete: :nullify

    # Add index for priority sorting
    add_index :agent_bot_inboxes, [:inbox_id, :priority], name: 'index_agent_bot_inboxes_on_inbox_and_priority'
    # Add index for version lookup
    add_index :agent_bot_inboxes, :version_id, name: 'index_agent_bot_inboxes_on_version_id'
  end
end
