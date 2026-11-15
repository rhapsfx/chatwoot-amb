# == Schema Information
#
# Table name: shared_apple_images
#
#  id            :bigint           not null, primary key
#  description   :text
#  identifier    :string           not null
#  image_type    :string           default("system"), not null
#  metadata      :jsonb
#  original_name :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#
# Indexes
#
#  index_shared_apple_images_on_account_id                 (account_id)
#  index_shared_apple_images_on_account_id_and_identifier  (account_id,identifier) UNIQUE
#  index_shared_apple_images_on_image_type                 (image_type)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class SharedAppleImage < ApplicationRecord
  belongs_to :account
  has_one_attached :image

  validates :account_id, presence: true
  validates :identifier, presence: true, uniqueness: { scope: :account_id }
  validates :image_type, presence: true, inclusion: { in: %w[system branding template] }

  scope :system_images, -> { where(image_type: 'system') }
  scope :branding_images, -> { where(image_type: 'branding') }
  scope :template_images, -> { where(image_type: 'template') }

  # Get image data as base64 for Apple Messages API
  def image_data_base64
    return nil unless image.attached?

    image.download.then { |data| Base64.strict_encode64(data) }
  end

  # Get image URL for preview
  def image_url
    return nil unless image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(image, only_path: true)
  end

  # Check if image is attached
  def image_attached?
    image.attached?
  end

  # Get image file size in bytes
  def image_size
    return nil unless image.attached?

    image.byte_size
  end
end
