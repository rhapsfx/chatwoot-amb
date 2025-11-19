#!/usr/bin/env ruby
# frozen_string_literal: true

# Diagnostic script for Apple Maps private key issues
# Usage: rails runner script/diagnose_apple_maps_key.rb

puts "🔍 Diagnosing Apple Maps Private Key\n\n"

private_key_content = ENV.fetch('APPLE_MAPS_PRIVATE_KEY', nil)

if private_key_content.blank?
  puts '❌ APPLE_MAPS_PRIVATE_KEY is not set'
  exit 1
end

puts '1️⃣  Private Key Content:'
puts "   Length: #{private_key_content.length} characters"
puts "   First 30 chars: #{private_key_content[0..29]}..."
puts "   Last 30 chars: ...#{private_key_content[-30..]}"
puts ''

# Check if key has proper headers
has_header = private_key_content.include?('BEGIN PRIVATE KEY') || private_key_content.include?('BEGIN EC PRIVATE KEY')
has_footer = private_key_content.include?('END PRIVATE KEY') || private_key_content.include?('END EC PRIVATE KEY')

puts '2️⃣  Key Format Check:'
puts "   Has BEGIN header: #{has_header ? '✅' : '❌'}"
puts "   Has END footer: #{has_footer ? '✅' : '❌'}"
puts ''

# Try to parse the key with different methods
puts "3️⃣  Attempting to parse key...\n"

# Method 1: Direct EC key parsing
puts '   Method 1: OpenSSL::PKey::EC.new'
begin
  ec_key = OpenSSL::PKey::EC.new(private_key_content)
  puts '   ✅ Success with EC.new'
  puts "      Group: #{begin
    ec_key.group.curve_name
  rescue StandardError
    'unknown'
  end}"
rescue StandardError => e
  puts "   ❌ Failed: #{e.message}"
end

# Method 2: PKey.read (recommended for Apple keys)
puts "\n   Method 2: OpenSSL::PKey.read (recommended)"
begin
  pkey = OpenSSL::PKey.read(private_key_content)
  puts '   ✅ Success with PKey.read'
  puts "      Key type: #{pkey.class}"
  puts "      Curve: #{pkey.group.curve_name}" if pkey.is_a?(OpenSSL::PKey::EC)
rescue StandardError => e
  puts "   ❌ Failed: #{e.message}"
end

# Method 3: With explicit prime256v1 curve
puts "\n   Method 3: EC.new with explicit prime256v1"
begin
  ec_key = OpenSSL::PKey::EC.new('prime256v1')
  ec_key.private_key = OpenSSL::BN.new(private_key_content.scan(/\h{2}/).join.to_i(16))
  puts '   ✅ Success with explicit curve'
rescue StandardError => e
  puts "   ❌ Failed: #{e.message}"
end

puts "\n4️⃣  Recommendations:\n"
puts '   Apple Maps API uses ES256 (NIST P-256/prime256v1 curve)'
puts ''
puts '   ✅ Your .env should look like this:'
puts '   APPLE_MAPS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----'
puts '   MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg...'
puts '   -----END PRIVATE KEY-----"'
puts ''
puts '   ⚠️  Common issues:'
puts '   1. Missing newlines - use \\n between lines'
puts '   2. Extra spaces or quotes in the key'
puts '   3. Using EC PRIVATE KEY instead of PRIVATE KEY header'
puts "   4. Key not in PKCS#8 format (should start with 'BEGIN PRIVATE KEY')"
puts ''
puts '   🔧 To convert your key to the correct format:'
puts '   openssl pkcs8 -topk8 -nocrypt -in AuthKey_XXXXX.p8 -out converted_key.pem'
puts ''
