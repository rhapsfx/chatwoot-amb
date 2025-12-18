# frozen_string_literal: true

# == Schema Information
#
# Table name: bot_flows
#
#  id             :bigint           not null, primary key
#  changelog      :text
#  description    :text
#  flow_data      :jsonb
#  is_active      :boolean          default(TRUE), not null
#  is_published   :boolean          default(FALSE)
#  metadata       :jsonb
#  name           :string
#  published_at   :datetime
#  version        :integer          default(1)
#  version_tag    :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  agent_bot_id   :bigint           not null
#  parent_flow_id :bigint
#
# Indexes
#
#  index_bot_flows_on_agent_bot_id                  (agent_bot_id)
#  index_bot_flows_on_agent_bot_id_and_version_tag  (agent_bot_id,version_tag) UNIQUE WHERE (version_tag IS NOT NULL)
#  index_bot_flows_on_parent_flow_id                (parent_flow_id)
#
# Foreign Keys
#
#  fk_rails_...  (agent_bot_id => agent_bots.id)
#  fk_rails_...  (parent_flow_id => bot_flows.id)
#

class BotFlow < ApplicationRecord
  belongs_to :agent_bot
  belongs_to :parent_flow, class_name: 'BotFlow', optional: true
  has_many :child_flows, class_name: 'BotFlow', foreign_key: :parent_flow_id, dependent: :nullify

  # Validations
  validates :agent_bot_id, presence: true
  validates :name, presence: true
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validates :version_tag, uniqueness: { scope: :agent_bot_id }, allow_nil: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :published, -> { where(is_published: true) }
  scope :drafts, -> { where(is_published: false) }
  scope :ordered_by_name, -> { order(name: :asc) }
  scope :ordered_by_version, -> { order(version: :desc) }
  scope :recent, -> { order(created_at: :desc) }

  # Helper methods
  def activate!
    update(is_active: true)
  end

  def deactivate!
    update(is_active: false)
  end

  def duplicate
    dup.tap do |new_flow|
      new_flow.name = "#{name} (Copy)"
      new_flow.version = 1
      new_flow.is_active = false
    end
  end

  def node_count
    flow_data&.dig('nodes')&.size || 0
  end

  def edge_count
    flow_data&.dig('edges')&.size || 0
  end

  # === Version Management Methods ===

  def create_version(version_tag:, changelog: nil)
    new_version = dup
    new_version.version_tag = version_tag
    new_version.parent_flow_id = id
    new_version.version += 1
    new_version.is_published = false
    new_version.published_at = nil
    new_version.changelog = changelog
    new_version.save!
    new_version
  end

  def publish!
    transaction do
      # Unpublish all other versions for this bot
      agent_bot.bot_flows.where.not(id: id).update_all(is_published: false)

      # Publish this version
      update!(
        is_published: true,
        published_at: Time.current
      )

      # Compile and update agent_bot config
      compiled_config = AppleMessagesForBusiness::FlowCompilerService.new(self).compile
      agent_bot.update!(bot_config: compiled_config)
    end
  end

  def unpublish!
    update!(is_published: false)
  end

  def restore_as_new_version
    # Find the root flow to get the latest version number
    root_flow = parent_flow_id.present? ? BotFlow.find(parent_flow_id) : self
    latest_version_number = agent_bot.bot_flows
                                     .where('parent_flow_id = ? OR id = ?', root_flow.id, root_flow.id)
                                     .maximum(:version) || version

    # Create a new version based on this flow's data
    new_version = dup
    new_version.version = latest_version_number + 1
    new_version.version_tag = "v#{new_version.version} (Restored from v#{version})"
    new_version.parent_flow_id = root_flow.id
    new_version.is_published = false
    new_version.published_at = nil
    new_version.changelog = "Restored from #{version_display}"
    new_version.save!
    new_version
  end

  def version_tree
    tree = []
    current = self

    # Walk up the parent chain
    while current.parent_flow.present?
      tree.unshift(current.parent_flow)
      current = current.parent_flow
    end

    # Add self at the end
    tree << self
    tree
  end

  def compare_with(other_flow)
    AppleMessagesForBusiness::FlowDiffService.new(self, other_flow).diff
  end

  def version_display
    version_tag.presence || "v#{version}"
  end
end
