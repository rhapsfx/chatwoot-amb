# == Schema Information
#
# Table name: apple_invitation_opt_outs
#
#  id            :bigint           not null, primary key
#  opted_out_at  :datetime         not null
#  phone_number  :string           not null
#  reference_ids :jsonb
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  contact_id    :bigint           not null
#  inbox_id      :bigint           not null
#
# Indexes
#
#  idx_apple_inv_opt_outs_unique                  (account_id,phone_number,inbox_id) UNIQUE
#  index_apple_invitation_opt_outs_on_account_id  (account_id)
#  index_apple_invitation_opt_outs_on_contact_id  (contact_id)
#  index_apple_invitation_opt_outs_on_inbox_id    (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#
class AppleInvitationOptOut < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :inbox

  validates :phone_number, presence: true
  validates :opted_out_at, presence: true
  validates :phone_number, uniqueness: { scope: [:account_id, :inbox_id] }

  scope :for_phone, ->(phone) { where(phone_number: phone) }
  scope :for_inbox, ->(inbox_id) { where(inbox_id: inbox_id) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }

  def self.opted_out?(account_id:, phone_number:, inbox_id:)
    for_account(account_id).for_phone(phone_number).for_inbox(inbox_id).exists?
  end
end
