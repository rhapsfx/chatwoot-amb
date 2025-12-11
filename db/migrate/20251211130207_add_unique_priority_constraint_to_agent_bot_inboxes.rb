class AddUniquePriorityConstraintToAgentBotInboxes < ActiveRecord::Migration[7.0]
  def up
    # First, fix any existing duplicates by incrementing priorities
    # Find all inboxes that have duplicate priorities among active bots
    duplicates = AgentBotInbox.active
                              .select('inbox_id, priority, COUNT(*) as count')
                              .group(:inbox_id, :priority)
                              .having('COUNT(*) > 1')

    duplicates.each do |dup|
      # Get all bot inboxes with this duplicate priority
      bot_inboxes = AgentBotInbox.active
                                 .where(inbox_id: dup.inbox_id, priority: dup.priority)
                                 .order(:created_at)

      # Keep the first one, increment others
      bot_inboxes.drop(1).each_with_index do |bot_inbox, index|
        new_priority = dup.priority + index + 1
        # Make sure new priority doesn't exceed 100
        new_priority = [new_priority, 100].min
        bot_inbox.update_column(:priority, new_priority)
      end
    end

    # Add unique partial index (only for active bots)
    # We use a partial index because we only want uniqueness for active bots
    # Inactive bots can have any priority
    add_index :agent_bot_inboxes,
              [:inbox_id, :priority],
              unique: true,
              where: 'status = 0', # 0 is the enum value for 'active'
              name: 'index_agent_bot_inboxes_on_inbox_and_priority_unique'

    # Remove the old non-unique index if it exists
    return unless index_exists?(:agent_bot_inboxes, [:inbox_id, :priority], name: 'index_agent_bot_inboxes_on_inbox_and_priority')

    remove_index :agent_bot_inboxes, name: 'index_agent_bot_inboxes_on_inbox_and_priority'
  end

  def down
    # Remove the unique constraint index
    if index_exists?(:agent_bot_inboxes, [:inbox_id, :priority], name: 'index_agent_bot_inboxes_on_inbox_and_priority_unique')
      remove_index :agent_bot_inboxes, name: 'index_agent_bot_inboxes_on_inbox_and_priority_unique'
    end

    # Re-add the old non-unique index
    return if index_exists?(:agent_bot_inboxes, [:inbox_id, :priority], name: 'index_agent_bot_inboxes_on_inbox_and_priority')

    add_index :agent_bot_inboxes, [:inbox_id, :priority], name: 'index_agent_bot_inboxes_on_inbox_and_priority'
  end
end
