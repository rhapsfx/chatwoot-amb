# frozen_string_literal: true

class CreateBotActionTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :bot_action_templates do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :template_type, null: false
      t.jsonb :parameters, null: false, default: {}
      t.jsonb :metadata, default: {}
      t.integer :execution_order, default: 0

      t.timestamps
    end

    add_index :bot_action_templates, [:account_id, :name], unique: true, name: 'index_bot_action_templates_on_account_id_and_name'
    add_index :bot_action_templates, :template_type
  end
end
