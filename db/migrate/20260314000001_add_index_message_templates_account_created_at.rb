class AddIndexMessageTemplatesAccountCreatedAt < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # Covers the common list query:
    # WHERE account_id = ? AND status != 'deprecated' ORDER BY created_at DESC
    # The CONCURRENTLY option avoids locking the table in production.
    add_index :message_templates, [:account_id, :created_at],
              order: { created_at: :desc },
              algorithm: :concurrently,
              name: 'index_message_templates_on_account_id_and_created_at'
  end
end
