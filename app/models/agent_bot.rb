# == Schema Information
#
# Table name: agent_bots
#
#  id                                                                     :bigint           not null, primary key
#  bot_config                                                             :jsonb
#  bot_type(Bot type: 0 = webhook, 1 = apple_messages_for_business (AMB)) :integer          default("webhook")
#  description                                                            :string
#  name                                                                   :string
#  outgoing_url                                                           :string
#  created_at                                                             :datetime         not null
#  updated_at                                                             :datetime         not null
#  account_id                                                             :bigint
#
# Indexes
#
#  index_agent_bots_on_account_id  (account_id)
#

class AgentBot < ApplicationRecord
  include AccessTokenable
  include Avatarable

  scope :accessible_to, lambda { |account|
    account_id = account&.id
    where(account_id: [nil, account_id])
  }

  has_many :agent_bot_inboxes, dependent: :destroy_async
  has_many :inboxes, through: :agent_bot_inboxes
  has_many :messages, as: :sender, dependent: :nullify
  has_many :assigned_conversations, class_name: 'Conversation',
                                    foreign_key: :assignee_agent_bot_id,
                                    dependent: :nullify,
                                    inverse_of: :assignee_agent_bot
  has_many :versions, class_name: 'AgentBotVersion', dependent: :destroy, inverse_of: :agent_bot
  has_many :bot_flows, dependent: :destroy
  belongs_to :account, optional: true

  enum bot_type: { webhook: 0, apple_messages_for_business: 1 }

  validates :outgoing_url, length: { maximum: Limits::URL_LENGTH_LIMIT }
  validates :bot_type, presence: true
  validate :validate_amb_config, if: :apple_messages_for_business?

  # Scopes for AMB bots
  scope :amb_bots, -> { where(bot_type: :apple_messages_for_business) }
  scope :with_active_versions, -> { joins(:versions).merge(AgentBotVersion.active).distinct }

  def available_name
    name
  end

  def push_event_data(inbox = nil)
    {
      id: id,
      name: name,
      avatar_url: avatar_url || inbox&.avatar_url,
      type: 'agent_bot'
    }
  end

  def webhook_data
    {
      id: id,
      name: name,
      type: 'agent_bot'
    }
  end

  def system_bot?
    account.nil?
  end

  # === Version Management Methods ===

  def active_version
    versions.active.first
  end

  def default_version
    versions.default_versions.first
  end

  def create_version!(version_tag:, config:, description: nil, notes: nil, activate: false, set_default: false)
    version = versions.create!(
      version_tag: version_tag,
      config: config,
      description: description,
      notes: notes,
      is_active: activate,
      is_default: set_default
    )

    version.activate! if activate
    version.set_as_default! if set_default

    version
  end

  def activate_version!(version_tag)
    version = versions.find_by!(version_tag: version_tag)
    version.activate!
  end

  def effective_config(inbox_id: nil)
    base_config = active_version&.config || bot_config

    return base_config unless inbox_id

    # Merge with inbox-specific overrides if provided
    inbox_association = agent_bot_inboxes.find_by(inbox_id: inbox_id)
    return base_config unless inbox_association&.config_overrides.present?

    base_config.deep_merge(inbox_association.config_overrides)
  end

  # === Config-Driven Bot Processing ===

  def process_message(conversation, message)
    return process_webhook_bot(conversation, message) if webhook?
    return process_amb_bot(conversation, message) if apple_messages_for_business?

    Rails.logger.error "[AgentBot] Unknown bot_type: #{bot_type}"
    false
  end

  private

  def process_webhook_bot(_conversation, _message)
    # Existing webhook bot logic (placeholder for now)
    true
  end

  def process_amb_bot(_conversation, _message)
    Rails.logger.info "[AgentBot] AMB processing via AcousticHouseBotService is disabled (bot_id: #{id})"
    false
  end

  def validate_amb_config
    required_keys = %w[conversation_flow keyword_mappings interactive_handlers required_templates]
    missing_keys = required_keys - bot_config.keys

    return unless missing_keys.any?

    errors.add(:bot_config, "missing required keys for AMB bot: #{missing_keys.join(', ')}")
  end
end
