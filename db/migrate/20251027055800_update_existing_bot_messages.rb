# frozen_string_literal: true

# Migration to update existing messages' sender_type in the frontend
# This is a one-time fix for messages created before the sender_type normalization

class UpdateExistingBotMessages < ActiveRecord::Migration[7.1]
  def up
    # Update all AgentBot messages to have normalized sender_type
    Message.where(sender_type: 'AgentBot').find_each do |message|
      # Trigger an update event to refresh the frontend
      message.send(:send_update_event)
    end
  end

  def down
    # No need to revert
  end
end
