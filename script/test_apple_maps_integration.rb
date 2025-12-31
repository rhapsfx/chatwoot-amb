#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for Apple Maps Store Locator integration
# Usage: rails runner script/test_apple_maps_integration.rb

puts "🗺️  Testing Apple Maps Store Locator Integration\n\n"

# Check environment variables
puts '1️⃣  Checking environment variables...'
team_id = ENV.fetch('APPLE_MAPS_TEAM_ID', nil)
key_id = ENV.fetch('APPLE_MAPS_KEY_ID', nil)
private_key = ENV.fetch('APPLE_MAPS_PRIVATE_KEY', nil)

if team_id.present?
  puts "   ✅ APPLE_MAPS_TEAM_ID: #{team_id[0..10]}... (configured)"
else
  puts '   ❌ APPLE_MAPS_TEAM_ID: Not configured'
end

if key_id.present?
  puts "   ✅ APPLE_MAPS_KEY_ID: #{key_id[0..10]}... (configured)"
else
  puts '   ❌ APPLE_MAPS_KEY_ID: Not configured'
end

if private_key.present?
  puts "   ✅ APPLE_MAPS_PRIVATE_KEY: Configured (#{private_key.length} characters)"
else
  puts '   ❌ APPLE_MAPS_PRIVATE_KEY: Not configured'
end

unless team_id.present? && key_id.present? && private_key.present?
  puts "\n⚠️  Missing credentials. Please configure all Apple Maps environment variables.\n\n"
  exit 1
end

puts "\n2️⃣  Initializing AppleMapsService..."
begin
  maps_service = AppleMessagesForBusiness::AppleMapsService.new
  puts '   ✅ Service initialized successfully'
rescue StandardError => e
  puts "   ❌ Failed to initialize: #{e.message}"
  puts "   #{e.backtrace.first}"
  exit 1
end

puts "\n3️⃣  Testing geocoding (San Francisco zipcode: 94102)..."
begin
  result = maps_service.geocode('94102')
  if result
    puts '   ✅ Geocoding successful!'
    puts "      Latitude: #{result[:latitude]}"
    puts "      Longitude: #{result[:longitude]}"
    puts "      Address: #{result[:formatted_address]}"
  else
    puts '   ❌ Geocoding returned nil'
  end
rescue StandardError => e
  puts "   ❌ Geocoding failed: #{e.message}"
  puts "   #{e.backtrace.first(3).join("\n   ")}"
end

puts "\n4️⃣  Testing store search (near San Francisco)..."
begin
  # San Francisco coordinates
  lat = 37.7749
  lon = -122.4194

  stores = maps_service.search_nearby(lat, lon, 'Apple Store', radius: 50_000)

  if stores.present?
    puts "   ✅ Found #{stores.length} Apple Stores!"
    puts "\n   Nearby stores:"
    stores.take(5).each_with_index do |store, index|
      puts "   #{index + 1}. #{store[:name]}"
      puts "      Distance: #{store[:distance_km]} km"
      puts "      Address: #{store[:formatted_address]}"
      puts "      Phone: #{store[:phone]}" if store[:phone]
      puts ''
    end
  else
    puts '   ⚠️  No stores found'
  end
rescue StandardError => e
  puts "   ❌ Store search failed: #{e.message}"
  puts "   #{e.backtrace.first(3).join("\n   ")}"
end

puts "\n5️⃣  Testing Apple Maps URL parsing..."
test_url = 'https://maps.apple.com/?ll=37.7749,-122.4194'
coords = maps_service.extract_coordinates_from_url(test_url)
if coords
  puts '   ✅ URL parsing successful!'
  puts "      Latitude: #{coords[:latitude]}"
  puts "      Longitude: #{coords[:longitude]}"
else
  puts '   ❌ Failed to parse coordinates from URL'
end

puts "\n6️⃣  Testing distance calculation..."
# Distance from Apple Park to Apple Union Square (should be ~40 km)
apple_park = { lat: 37.332863, lon: -122.0053739 }
union_square = { lat: 37.788493, lon: -122.407074 }
distance = maps_service.calculate_distance(
  apple_park[:lat],
  apple_park[:lon],
  union_square[:lat],
  union_square[:lon]
)
puts '   ✅ Distance calculation successful!'
puts "      Apple Park to Union Square: #{distance.round(2)} km"

puts "\n✨ All tests completed!\n\n"
puts '📝 Next Steps:'
puts '   1. Start your development server (overmind start -f Procfile.dev)'
puts '   2. Connect via Apple Messages for Business channel'
puts '   3. Start bot conversation and reach location request phase'
puts '   4. Try these test inputs:'
puts '      • Zipcode: 94102 (San Francisco)'
puts '      • Zipcode: 10019 (New York)'
puts '      • Apple Maps URL: https://maps.apple.com/?ll=37.7749,-122.4194'
puts ''
