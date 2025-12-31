# frozen_string_literal: true

class CreateAgentBotVersions < ActiveRecord::Migration[7.0]
  def change
    create_table :agent_bot_versions do |t|
      t.references :agent_bot, null: false, foreign_key: true, index: true
      t.string :version_tag, null: false, limit: 50
      t.text :description
      t.jsonb :config, null: false, default: {}
      t.boolean :is_active, default: false, null: false
      t.boolean :is_default, default: false, null: false
      t.datetime :activated_at
      t.text :notes

      t.timestamps
    end

    # Composite index for active version lookup
    add_index :agent_bot_versions, [:agent_bot_id, :is_active], name: 'index_agent_bot_versions_on_bot_and_active'
    # Unique constraint on version tag per bot
    add_index :agent_bot_versions, [:agent_bot_id, :version_tag], unique: true, name: 'index_agent_bot_versions_on_bot_and_tag'
  end
end
