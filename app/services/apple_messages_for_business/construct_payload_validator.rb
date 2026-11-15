# frozen_string_literal: true

class AppleMessagesForBusiness::ConstructPayloadValidator
  include ActiveModel::Validations

  attr_accessor :url, :store_region, :url_type

  # ISO 3166 alpha-2 country codes (Apple App Store regions)
  VALID_STORE_REGIONS = %w[
    US GB CA AU DE FR JP CN IN BR
    IT ES NL SE CH BE AT NO DK FI
    IE PT PL CZ HU GR RO SK BG HR
    LT LV EE SI CY MT LU
  ].freeze

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[https]) }
  # store_region is an App-Clip-only concept - it doesn't gate/apply to Music or Maps URLs.
  validates :store_region, presence: true, inclusion: { in: VALID_STORE_REGIONS }, if: -> { url_type == :link }
  validate :url_without_whitespace

  def initialize(url:, store_region:, url_type: :link)
    @url = url
    @store_region = store_region&.upcase
    @url_type = url_type
  end

  private

  def url_without_whitespace
    return if url.blank?

    errors.add(:url, 'is invalid') if url != url.strip
  end
end
