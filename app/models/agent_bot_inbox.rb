# == Schema Information
#
# Table name: agent_bot_inboxes
#
#  id               :bigint           not null, primary key
#  config_overrides :jsonb            not null
#  notes            :text
#  priority         :integer          default(10), not null
#  status           :integer          default("active")
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :integer
#  agent_bot_id     :integer
#  inbox_id         :integer
#  version_id       :bigint
#
# Indexes
#
#  index_agent_bot_inboxes_on_inbox_and_priority_unique  (inbox_id,priority) UNIQUE WHERE (status = 0)
#  index_agent_bot_inboxes_on_version_id                 (version_id)
#
# Foreign Keys
#
#  fk_rails_...  (version_id => agent_bot_versions.id) ON DELETE => nullify
#

class AgentBotInbox < ApplicationRecord
  validates :inbox_id, presence: true
  validates :agent_bot_id, presence: true
  before_validation :ensure_account_id

  belongs_to :inbox
  belongs_to :agent_bot
  belongs_to :account
  enum status: { active: 0, inactive: 1 }

  private

  def ensure_account_id
    self.account_id = inbox&.account_id
  end
end
