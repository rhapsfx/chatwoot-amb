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
#  index_agent_bot_inboxes_on_inbox_and_priority  (inbox_id,priority)
#  index_agent_bot_inboxes_on_version_id          (version_id)
#
# Foreign Keys
#
#  fk_rails_...  (version_id => agent_bot_versions.id) ON DELETE => nullify
#

class AgentBotInbox < ApplicationRecord
  validates :inbox_id, presence: true
  validates :agent_bot_id, presence: true
  validates :priority, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  before_validation :ensure_account_id

  belongs_to :inbox
  belongs_to :agent_bot
  belongs_to :account
  belongs_to :version, class_name: 'AgentBotVersion', optional: true, inverse_of: :agent_bot_inboxes

  enum status: { active: 0, inactive: 1 }

  # Scopes
  scope :active_bots, -> { active.order(priority: :asc) }
  scope :ordered_by_priority, -> { order(priority: :desc) }
  scope :for_inbox, ->(inbox_id) { where(inbox_id: inbox_id) }
  scope :with_version, -> { where.not(version_id: nil) }
  scope :without_version, -> { where(version_id: nil) }

  # Get effective config for this bot-inbox association
  def effective_config
    base_config = version&.config || agent_bot.bot_config
    return base_config if config_overrides.blank?

    base_config.deep_merge(config_overrides)
  end

  # Set specific version for this inbox
  def set_version!(version_tag)
    version = agent_bot.bot_versions.find_by!(version_tag: version_tag)
    update!(version_id: version.id)
  end

  # Clear version (use bot's active version)
  def clear_version!
    update!(version_id: nil)
  end

  # Update config overrides
  def update_config_overrides!(overrides)
    update!(config_overrides: config_overrides.deep_merge(overrides))
  end

  # Clear config overrides
  def clear_config_overrides!
    update!(config_overrides: {})
  end

  private

  def ensure_account_id
    self.account_id = inbox&.account_id
  end
end
