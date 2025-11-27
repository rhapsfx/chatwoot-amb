# frozen_string_literal: true

class AppleMessagesForBusiness::ConstructPayloadValidator
  include ActiveModel::Validations

  attr_accessor :url, :store_region

  # ISO 3166 alpha-2 country codes (Top 30 Apple App Store regions)
  VALID_STORE_REGIONS = %w[
    US GB CA AU DE FR JP CN IN BR
    IT ES NL SE CH BE AT NO DK FI
    IE PT PL CZ HU GR RO SK BG HR
  ].freeze

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[https]) }
  validates :store_region, presence: true, inclusion: { in: VALID_STORE_REGIONS }

  def initialize(url:, store_region:)
    @url = url&.strip
    @store_region = store_region&.upcase
  end
end
