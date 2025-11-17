# frozen_string_literal: true

class AppleMessagesForBusiness::AppleMapsService
  MAPS_API_BASE_URL = 'https://maps-api.apple.com/v1'
  TOKEN_EXPIRATION = 30.minutes
  CACHE_TTL = 1.hour
  DEFAULT_SEARCH_RADIUS = 50_000 # 50 km in meters
  MAX_RESULTS = 10

  class AppleMapsError < StandardError; end
  class AuthenticationError < AppleMapsError; end
  class RateLimitError < AppleMapsError; end
  class InvalidInputError < AppleMapsError; end

  def initialize
    @team_id = ENV.fetch('APPLE_MAPS_TEAM_ID', nil)
    @key_id = ENV.fetch('APPLE_MAPS_KEY_ID', nil)
    @private_key_content = ENV.fetch('APPLE_MAPS_PRIVATE_KEY', nil)

    validate_credentials!
  end

  # Geocode an address or zipcode to coordinates
  # @param address [String] Address or zipcode to geocode
  # @return [Hash, nil] Geocoding result with latitude, longitude, formatted_address
  def geocode(address)
    return nil if address.blank?

    cache_key = "apple_maps:geocode:#{address.strip.downcase}"
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      perform_geocode(address)
    end
  rescue StandardError => e
    Rails.logger.error("AppleMapsService geocode error: #{e.message}")
    nil
  end

  # Search for places near coordinates
  # @param lat [Float] Latitude
  # @param lon [Float] Longitude
  # @param query [String] Search query (e.g., "Apple Store")
  # @param radius [Integer] Search radius in meters (default: 50km)
  # @return [Array<Hash>] Array of place results
  def search_nearby(lat, lon, query, radius: DEFAULT_SEARCH_RADIUS)
    validate_coordinates!(lat, lon)

    cache_key = "apple_maps:search:#{lat}:#{lon}:#{query}:#{radius}"
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      perform_search(lat, lon, query, radius)
    end
  rescue InvalidInputError => e
    Rails.logger.error("AppleMapsService search error: #{e.message}")
    []
  rescue StandardError => e
    Rails.logger.error("AppleMapsService search error: #{e.message}")
    []
  end

  # Calculate distance between two coordinates using Haversine formula
  # @param lat1 [Float] Latitude of point 1
  # @param lon1 [Float] Longitude of point 1
  # @param lat2 [Float] Latitude of point 2
  # @param lon2 [Float] Longitude of point 2
  # @return [Float] Distance in kilometers
  def calculate_distance(lat1, lon1, lat2, lon2)
    earth_radius_km = 6371.0

    lat1_rad = lat1 * Math::PI / 180
    lat2_rad = lat2 * Math::PI / 180
    delta_lat = (lat2 - lat1) * Math::PI / 180
    delta_lon = (lon2 - lon1) * Math::PI / 180

    a = (Math.sin(delta_lat / 2)**2) +
        (Math.cos(lat1_rad) * Math.cos(lat2_rad) *
         Math.sin(delta_lon / 2)**2)

    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    earth_radius_km * c
  end

  # Extract coordinates from Apple Maps URL
  # @param url [String] Apple Maps URL (multiple formats supported)
  # @return [Hash, nil] Hash with latitude and longitude or nil
  def extract_coordinates_from_url(url)
    return nil if url.blank?

    # Try multiple URL formats:
    # 1. ?ll=lat,lon (standard share format)
    # 2. ?coordinate=lat,lon (place format)
    # 3. @lat,lon (some URL variants)

    match = url.match(/(?:ll|coordinate)=([-\d.]+),([-\d.]+)/) ||
            url.match(/@([-\d.]+),([-\d.]+)/)

    return nil unless match

    {
      latitude: match[1].to_f,
      longitude: match[2].to_f
    }
  end

  private

  def validate_credentials!
    missing = []
    missing << 'APPLE_MAPS_TEAM_ID' if @team_id.blank?
    missing << 'APPLE_MAPS_KEY_ID' if @key_id.blank?
    missing << 'APPLE_MAPS_PRIVATE_KEY' if @private_key_content.blank?

    return if missing.empty?

    raise AuthenticationError, "Missing Apple Maps credentials: #{missing.join(', ')}"
  end

  def validate_coordinates!(lat, lon)
    raise InvalidInputError, 'Latitude must be between -90 and 90' unless lat.between?(-90, 90)
    raise InvalidInputError, 'Longitude must be between -180 and 180' unless lon.between?(-180, 180)
  end

  def generate_token
    now = Time.now.to_i

    # Header - exactly as Apple requires
    header = {
      alg: 'ES256',
      kid: @key_id,
      typ: 'JWT'
    }

    # Payload - exactly as Apple requires
    payload = {
      iss: @team_id,
      iat: now,
      exp: now + TOKEN_EXPIRATION.to_i
    }

    # Parse the private key - handle both formats (with/without PEM headers)
    private_key = parse_private_key(@private_key_content)

    # Generate JWT with ES256 algorithm
    JWT.encode(payload, private_key, 'ES256', header)
  rescue StandardError => e
    raise AuthenticationError, "Failed to generate JWT token: #{e.message}"
  end

  def get_access_token
    jwt_token = generate_token

    # Exchange JWT for access token
    response = HTTParty.get(
      "#{MAPS_API_BASE_URL}/token",
      headers: {
        'Authorization' => "Bearer #{jwt_token}"
      },
      timeout: 10
    )

    if response.code == 200
      access_token_data = response.parsed_response
      access_token_data['accessToken']
    else
      raise AuthenticationError, "Failed to get access token: #{response.code} - #{response.body}"
    end
  rescue StandardError => e
    raise AuthenticationError, "Failed to get access token: #{e.message}"
  end

  def parse_private_key(key_content)
    # Convert literal \n to actual newlines if needed
    if key_content.include?('\n')
      key_content = key_content.gsub('\n', "\n")
    end

    # If key doesn't have PEM headers, add them
    unless key_content.include?('BEGIN PRIVATE KEY')
      # Remove any whitespace and newlines
      clean_key = key_content.gsub(/\s+/, '')

      # Split into 64-character lines (PEM format requirement)
      formatted_key = clean_key.scan(/.{1,64}/).join("\n")

      # Add PEM headers
      key_content = "-----BEGIN PRIVATE KEY-----\n#{formatted_key}\n-----END PRIVATE KEY-----"
    end

    # Parse using PKey.read (recommended for ES256 keys)
    OpenSSL::PKey.read(key_content)
  rescue StandardError => e
    # Fallback: try EC.new
    OpenSSL::PKey::EC.new(key_content)
  end

  def perform_geocode(address)
    access_token = get_access_token
    url = "#{MAPS_API_BASE_URL}/geocode"

    response = HTTParty.get(
      url,
      headers: {
        'Authorization' => "Bearer #{access_token}"
      },
      query: { q: address.strip },
      timeout: 10
    )

    handle_api_response(response)

    results = response.parsed_response['results']
    return nil if results.blank?

    first_result = results.first
    coordinate = first_result['coordinate']

    {
      latitude: coordinate['latitude'],
      longitude: coordinate['longitude'],
      formatted_address: first_result['formattedAddressLines']&.join(', ') || first_result['name']
    }
  end

  # rubocop:disable Metrics/MethodLength
  def perform_search(lat, lon, query, radius)
    access_token = get_access_token
    url = "#{MAPS_API_BASE_URL}/search"

    response = HTTParty.get(
      url,
      headers: {
        'Authorization' => "Bearer #{access_token}"
      },
      query: {
        q: query,
        searchLocation: "#{lat},#{lon}",
        searchRegionRadius: radius,
        resultTypeFilter: 'Poi'
      },
      timeout: 10
    )

    handle_api_response(response)

    results = response.parsed_response['results'] || []

    # Process and sort results by distance
    places = results.map do |result|
      coordinate = result['coordinate']
      place_lat = coordinate['latitude']
      place_lon = coordinate['longitude']
      distance_km = calculate_distance(lat, lon, place_lat, place_lon)

      {
        id: result['id'], # Apple Maps place ID for URL construction
        name: result['name'],
        latitude: place_lat,
        longitude: place_lon,
        formatted_address: result['formattedAddressLines']&.join(', ') || result['name'],
        phone: result['telephone'],
        distance_km: distance_km.round(2)
      }
    end

    # Sort by distance and limit results
    places.sort_by { |p| p[:distance_km] }.take(MAX_RESULTS)
  end
  # rubocop:enable Metrics/MethodLength

  def handle_api_response(response)
    case response.code
    when 200
      # Success
      return
    when 401
      raise AuthenticationError, 'Invalid Apple Maps API credentials'
    when 429
      raise RateLimitError, 'Apple Maps API rate limit exceeded'
    when 400
      error_msg = response.parsed_response['error']&.dig('message') || 'Bad request'
      raise InvalidInputError, error_msg
    else
      raise AppleMapsError, "Apple Maps API error: #{response.code} - #{response.message}"
    end
  end
end
