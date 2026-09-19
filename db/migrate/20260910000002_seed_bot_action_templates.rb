class SeedBotActionTemplates < ActiveRecord::Migration[7.1]
  def up
    # Create system-seeded bot_action_templates (account_id = NULL means system-wide)
    # These define the catalog of non-message action step kinds available in the bot flow builder

    rows = [
      { name: 'assign_team', template_type: 'assign_team', account_id: nil },
      { name: 'add_label', template_type: 'add_label', account_id: nil },
      { name: 'set_conversation_attribute', template_type: 'set_conversation_attribute', account_id: nil },
      { name: 'send_webhook', template_type: 'send_webhook', account_id: nil }
    ]

    rows.each do |row|
      # Only insert if not exists (idempotent)
      BotActionTemplate.find_or_create_by!(name: row[:name], account_id: row[:account_id]) do |template|
        template.template_type = row[:template_type]
      end
    end
  end

  def down
    BotActionTemplate.where(account_id: nil).destroy_all
  end
end
