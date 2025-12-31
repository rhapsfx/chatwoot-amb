#!/bin/bash
# Test Apple Maps Service directly

echo "======================================================================="
echo "🗺️  TESTING APPLE MAPS SERVICE"
echo "======================================================================="
echo ""

cat > /tmp/test_apple_maps.rb << 'RUBY'
puts "=" * 70
puts "🗺️  Apple Maps Service Test"
puts "=" * 70
puts ""

# Initialize the service
begin
  service = AppleMessagesForBusiness::AppleMapsService.new
  puts "✅ AppleMapsService initialized successfully"
rescue => e
  puts "❌ Failed to initialize AppleMapsService: #{e.message}"
  puts "   #{e.backtrace.first(3).join("\n   ")}"
  exit 1
end

puts ""
puts "Test 1: Geocoding a simple zipcode (95014 - Cupertino)"
puts "-" * 70
begin
  result = service.geocode('95014')
  if result
    puts "✅ Geocoding successful"
    puts "   Latitude: #{result[:latitude]}"
    puts "   Longitude: #{result[:longitude]}"
    puts "   Formatted: #{result[:formatted_address]}" if result[:formatted_address]
  else
    puts "❌ Geocoding returned nil"
  end
rescue => e
  puts "❌ Geocoding exception: #{e.class.name}: #{e.message}"
  puts "   #{e.backtrace.first(5).join("\n   ")}"
end

puts ""
puts "Test 2: Search for Apple Stores near Cupertino (if geocoding worked)"
puts "-" * 70
if result
  begin
    stores = service.search_nearby(
      result[:latitude],
      result[:longitude],
      'Apple Store',
      radius: 10_000
    )

    if stores && stores.any?
      puts "✅ Found #{stores.length} Apple Store(s)"
      stores.first(3).each do |store|
        puts "   - #{store[:name]}"
      end
    else
      puts "⚠️  Search returned no stores"
    end
  rescue => e
    puts "❌ Search exception: #{e.class.name}: #{e.message}"
    puts "   #{e.backtrace.first(5).join("\n   ")}"
  end
else
  puts "⏭️  Skipping search (geocoding failed)"
end

puts ""
puts "=" * 70
puts "Configuration check:"
puts "-" * 70
puts "APPLE_MAPS_TEAM_ID: #{ENV['APPLE_MAPS_TEAM_ID'].present? ? '✅ Set' : '❌ Not set'}"
puts "APPLE_MAPS_KEY_ID: #{ENV['APPLE_MAPS_KEY_ID'].present? ? '✅ Set' : '❌ Not set'}"
puts "APPLE_MAPS_PRIVATE_KEY: #{ENV['APPLE_MAPS_PRIVATE_KEY'].present? ? '✅ Set' : '❌ Not set'}"
puts ""
puts "=" * 70
RUBY

scp -q /tmp/test_apple_maps.rb root@msp.rhaps.net:/tmp/

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker cp /tmp/test_apple_maps.rb $WEB_CONTAINER:/tmp/
docker exec -e RAILS_ENV=production $WEB_CONTAINER bundle exec rails runner /tmp/test_apple_maps.rb 2>&1 | grep -v "INFO -- :"
REMOTE_SCRIPT

rm -f /tmp/test_apple_maps.rb

echo ""
echo "======================================================================="
