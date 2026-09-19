class DropDeadBotSchema < ActiveRecord::Migration[7.1]
  def up
    # Drop foreign key on agent_bot_inboxes.version_id -> agent_bot_versions.id
    remove_foreign_key :agent_bot_inboxes, :agent_bot_versions if foreign_key_exists?(:agent_bot_inboxes, :agent_bot_versions)

    # Drop the version_id column from agent_bot_inboxes
    remove_column :agent_bot_inboxes, :version_id, :bigint

    # Drop index on agent_bot_inboxes.version_id
    remove_index :agent_bot_inboxes, :index_agent_bot_inboxes_on_version_id if index_exists?(:agent_bot_inboxes,
                                                                                             :index_agent_bot_inboxes_on_version_id)

    # Drop the entire agent_bot_versions table
    drop_table :agent_bot_versions
  end

  def down
    # Recreate agent_bot_versions table
    create_table :agent_bot_versions do |t|
      t.bigint :agent_bot_id, null: false
      t.boolean :is_active, default: true, null: false
      t.datetime :archived_at
      t.text :notes

      t.index [:agent_bot_id], name: :index_agent_bot_versions_on_agent_bot_id
      t.index [:agent_bot_id, :is_active], name: :index_agent_bot_versions_on_bot_and_active
      t.index [:agent_bot_id, :version_tag], name: :index_agent_bot_versions_on_bot_and_tag, unique: true
      t.index [:archived_at], name: :index_agent_bot_versions_on_archived_at
    end

    # Recreate foreign key
    add_foreign_key :agent_bot_inboxes, :agent_bot_versions, column: :version_id, on_delete: :nullify

    # Recreate version_id column (will be NULL for existing rows)
    add_column :agent_bot_inboxes, :version_id, :bigint
  end
end
