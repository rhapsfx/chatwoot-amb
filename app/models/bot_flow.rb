class BotFlow < ApplicationRecord
  belongs_to :agent_bot
  belongs_to :account, optional: true
  has_many :versions, class_name: 'BotFlow', foreign_key: 'parent_flow_id', dependent: :nullify
  has_one :published_version, -> { where(is_published: true) }, class_name: 'BotFlow', foreign_key: 'parent_flow_id'

  validates :name, presence: true
  validates :agent_bot_id, presence: true
  validates :version, presence: true

  scope :published, -> { where(is_published: true) }
  scope :by_agent_bot, ->(agent_bot_id) { where(agent_bot_id: agent_bot_id).order(version: :desc) }

  def published_version?
    is_published
  end

  def draft_version?
    !is_published
  end

  def next_version
    (version || 0) + 1
  end
end
