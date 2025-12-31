#!/usr/bin/env ruby
# frozen_string_literal: true

# Detailed API response testing

puts "🔍 Testing Apple Maps API Response\n\n"

maps_service = AppleMessagesForBusiness::AppleMapsService.new

# Test with verbose error handling
puts "Testing geocode with detailed error logging...\n"

begin
  # Enable detailed HTTParty logging
  class << maps_service
    def test_geocode_verbose(address)
      token = generate_token
      url = "#{self.class::MAPS_API_BASE_URL}/geocode"

      puts '📡 API Request:'
      puts "   URL: #{url}"
      puts "   Address: #{address}"
      puts "   Token (first 50 chars): #{token[0..50]}..."
      puts ''

      response = HTTParty.post(
        url,
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: { address: address.strip }.to_json,
        timeout: 10,
        debug_output: $stdout  # Enable debug output
      )

      puts "\n📥 API Response:"
      puts "   Status: #{response.code}"
      puts "   Body: #{response.body}"
      puts ''

      response
    end
  end

  response = maps_service.test_geocode_verbose('94102')

  if response.code == 200
    results = response.parsed_response['results']
    if results.present?
      puts "✅ Success! Found #{results.length} results"
      results.each do |result|
        puts "   - #{result['formattedAddress'] || result['name']}"
      end
    else
      puts '⚠️  No results in response'
    end
  else
    puts "❌ API Error: #{response.code}"
    puts "   Message: #{response.parsed_response}"
  end

rescue StandardError => e
  puts "❌ Exception: #{e.message}"
  puts "   Class: #{e.class}"
  puts '   Backtrace:'
  e.backtrace.first(10).each { |line| puts "      #{line}" }
end
