class CreateBotFlowsPublishedIndex < ActiveRecord::Migration[7.1]
  def up
    add_index :bot_flows, [:agent_bot_id], where: 'is_published', name: 'index_bot_flows_on_agent_bot_id_published', unique: true
  end

  def down
    remove_index :bot_flows, name: 'index_bot_flows_on_agent_bot_id_published'
  end
end
