class BotActionTemplate < ApplicationRecord
  has_many :action_steps, class_name: 'BotFlow::Step', foreign_key: 'action_template_id', dependent: :nullify

  scope :system, -> { where(account_id: nil) }
  scope :account_scoped, -> { where.not(account_id: nil) }

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :template_type, presence: true
end
