# == Schema Information
#
# Table name: apple_app_metadata
#
#  id             :bigint           not null, primary key
#  app_icon_url   :string
#  app_name       :string
#  app_store_url  :string
#  description    :text
#  developer_name :string
#  metadata       :jsonb
#  price          :decimal(10, 2)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  bundle_id      :string           not null
#
# Indexes
#
#  index_apple_app_metadata_on_bundle_id  (bundle_id) UNIQUE
#
class AppleAppMetadata < ApplicationRecord
  validates :bundle_id, presence: true, uniqueness: true

  # Fetch app metadata from iTunes API and cache it
  def self.fetch_and_cache(bundle_id)
    return nil if bundle_id.blank?

    # Parse iMessage extension bundle ID to extract actual app bundle ID
    # Format: com.apple.messages.MSMessageExtensionBalloonPlugin:TEAMID:com.app.bundle.imessageextension
    # We want: com.app.bundle
    actual_bundle_id = parse_bundle_id(bundle_id)
    Rails.logger.info "AppleAppMetadata: Original bundle_id: #{bundle_id}, Parsed: #{actual_bundle_id}"

    # Check cache first
    cached = find_by(bundle_id: actual_bundle_id)
    return cached if cached && cached.fresh?

    # Fetch from iTunes API
    url = "https://itunes.apple.com/lookup?bundleId=#{CGI.escape(actual_bundle_id)}"
    Rails.logger.info "AppleAppMetadata: Fetching from iTunes API: #{url}"
    response = RestClient::Request.execute(
      method: :get,
      url: url,
      timeout: 5
    )

    data = JSON.parse(response.body)
    Rails.logger.info "AppleAppMetadata: iTunes API response: resultCount=#{data['resultCount']}"

    if data['resultCount'].to_i.zero?
      Rails.logger.warn "AppleAppMetadata: No results found for #{actual_bundle_id}"
      return cached
    end

    result = data['results'].first
    create_or_update_from_itunes(actual_bundle_id, result)
  rescue RestClient::ExceptionWithResponse, RestClient::Exceptions::OpenTimeout, StandardError => e
    Rails.logger.error("AppleAppMetadata: Failed to fetch iTunes data for #{actual_bundle_id}: #{e.message}")
    cached # Return cached data if available, even if stale
  end

  # Parse iMessage extension bundle ID to extract actual app bundle ID
  # Examples:
  #   "com.apple.messages.MSMessageExtensionBalloonPlugin:4GWDBCF5A4:com.shazam.Shazam.imessageextension"
  #     => "com.shazam.Shazam"
  #   "com.shazam.Shazam" => "com.shazam.Shazam"
  def self.parse_bundle_id(bundle_id)
    return bundle_id if bundle_id.blank?

    # Check if it's an iMessage extension format (contains colons)
    if bundle_id.include?(':')
      # Split by colon and take the last part
      parts = bundle_id.split(':')
      app_bundle = parts.last

      # Remove .imessageextension suffix if present
      app_bundle = app_bundle.sub(/\.imessageextension$/, '')

      return app_bundle
    end

    # Already a regular bundle ID
    bundle_id
  end

  def self.create_or_update_from_itunes(bundle_id, itunes_data)
    find_or_initialize_by(bundle_id: bundle_id).tap do |record|
      record.app_name = itunes_data['trackName']
      record.developer_name = itunes_data['artistName']
      record.app_icon_url = itunes_data['artworkUrl512'] || itunes_data['artworkUrl100']
      record.app_store_url = itunes_data['trackViewUrl']
      record.description = itunes_data['description']
      record.price = itunes_data['price']
      record.metadata = itunes_data
      record.save
    end
  end

  # Consider cache fresh if updated within 7 days
  def fresh?
    updated_at > 7.days.ago
  end
end
