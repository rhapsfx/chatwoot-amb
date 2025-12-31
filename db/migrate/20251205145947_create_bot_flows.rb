class CreateBotFlows < ActiveRecord::Migration[7.1]
  def change
    create_table :bot_flows do |t|
      t.bigint :agent_bot_id, null: false
      t.string :name
      t.text :description
      t.jsonb :flow_data, default: {}
      t.jsonb :metadata, default: {}
      t.boolean :is_active, default: true, null: false
      t.integer :version, default: 1

      t.timestamps

      t.index [:agent_bot_id], name: 'index_bot_flows_on_agent_bot_id'
    end

    add_foreign_key :bot_flows, :agent_bots
  end
end
