# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_bot_versions
#
#  id           :bigint           not null, primary key
#  activated_at :datetime
#  archived_at  :datetime
#  config       :jsonb            not null
#  description  :text
#  is_active    :boolean          default(FALSE), not null
#  is_default   :boolean          default(FALSE), not null
#  notes        :text
#  version_tag  :string(50)       not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  agent_bot_id :bigint           not null
#
# Indexes
#
#  index_agent_bot_versions_on_agent_bot_id    (agent_bot_id)
#  index_agent_bot_versions_on_archived_at     (archived_at)
#  index_agent_bot_versions_on_bot_and_active  (agent_bot_id,is_active)
#  index_agent_bot_versions_on_bot_and_tag     (agent_bot_id,version_tag) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agent_bot_id => agent_bots.id)
#

class AgentBotVersion < ApplicationRecord
  belongs_to :agent_bot
  has_many :agent_bot_inboxes, foreign_key: :version_id, dependent: :nullify, inverse_of: :version

  # Validations
  validates :version_tag, presence: true, length: { maximum: 50 }
  validates :version_tag, uniqueness: { scope: :agent_bot_id }
  validates :config, presence: true
  validate :only_one_active_default_version, if: -> { is_active? && is_default? }
  validate :config_structure, if: -> { agent_bot&.apple_messages_for_business? }

  # Callbacks
  before_save :set_activated_at, if: -> { is_active_changed?(to: true) }
  after_save :deactivate_other_defaults, if: -> { saved_change_to_is_default? && is_default? }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :default_versions, -> { where(is_default: true) }
  scope :archived, lambda {
    if column_names.include?('archived_at')
      where.not(archived_at: nil)
    else
      none
    end
  }
  scope :not_archived, lambda {
    if column_names.include?('archived_at')
      where(archived_at: nil)
    else
      all
    end
  }
  scope :recent, -> { order(created_at: :desc) }

  def activate!
    transaction do
      # Deactivate other versions for this bot
      agent_bot.versions.where.not(id: id).update_all(is_active: false, activated_at: nil)
      update!(is_active: true, activated_at: Time.current)
    end
  end

  def deactivate!
    update!(is_active: false)
  end

  def set_as_default!
    transaction do
      # Remove default flag from other versions
      agent_bot.versions.where.not(id: id).update_all(is_default: false)
      update!(is_default: true)
    end
  end

  def archive!
    update!(archived_at: Time.current, is_active: false)
  end

  def restore!
    update!(archived_at: nil)
  end

  def archived?
    return false unless respond_to?(:archived_at)

    archived_at.present?
  end

  # For JSON serialization
  def archived
    archived?
  end

  def compare_with(other_version)
    {
      config_diff: config_differences(other_version),
      version_tag_changed: version_tag != other_version.version_tag,
      description_changed: description != other_version.description,
      notes_changed: notes != other_version.notes
    }
  end

  private

  def config_differences(other_version)
    return {} if config == other_version.config

    {
      added_keys: other_version.config.keys - config.keys,
      removed_keys: config.keys - other_version.config.keys,
      modified_keys: config.keys.select { |key| config[key] != other_version.config[key] }
    }
  end

  def only_one_active_default_version
    existing = agent_bot.versions.active.default_versions.where.not(id: id)
    return unless existing.exists?

    errors.add(:base, 'Only one active default version allowed per bot')
  end

  def config_structure
    required_keys = %w[conversation_flow keyword_mappings interactive_handlers required_templates]
    missing_keys = required_keys - config.keys

    return unless missing_keys.any?

    errors.add(:config, "missing required keys: #{missing_keys.join(', ')}")
  end

  def set_activated_at
    self.activated_at = Time.current
  end

  def deactivate_other_defaults
    agent_bot.versions.where.not(id: id).update_all(is_default: false)
  end
end
