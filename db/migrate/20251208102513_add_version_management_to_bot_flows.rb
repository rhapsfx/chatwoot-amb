# frozen_string_literal: true

class AddVersionManagementToBotFlows < ActiveRecord::Migration[7.1]
  def change
    add_column :bot_flows, :version_tag, :string
    add_column :bot_flows, :parent_flow_id, :bigint
    add_column :bot_flows, :is_published, :boolean, default: false
    add_column :bot_flows, :published_at, :datetime
    add_column :bot_flows, :changelog, :text

    add_index :bot_flows, :parent_flow_id
    add_index :bot_flows, [:agent_bot_id, :version_tag], unique: true, where: 'version_tag IS NOT NULL'
    add_foreign_key :bot_flows, :bot_flows, column: :parent_flow_id
  end
end
