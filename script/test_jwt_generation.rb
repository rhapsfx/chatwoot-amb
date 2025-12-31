#!/usr/bin/env ruby
# frozen_string_literal: true

# Detailed JWT generation test

require 'jwt'
require 'openssl'
require 'base64'

puts "🔐 Detailed JWT Generation Test\n\n"

team_id = ENV.fetch('APPLE_MAPS_TEAM_ID', nil)
key_id = ENV.fetch('APPLE_MAPS_KEY_ID', nil)
key_content = ENV.fetch('APPLE_MAPS_PRIVATE_KEY', nil)

puts 'Step 1: Format the private key'
clean_key = key_content.gsub(/\s+/, '')
formatted_key_lines = clean_key.scan(/.{1,64}/)
formatted_key = formatted_key_lines.join("\n")
pem_key = "-----BEGIN PRIVATE KEY-----\n#{formatted_key}\n-----END PRIVATE KEY-----"

puts 'PEM Key (first 200 chars):'
puts pem_key[0..200]
puts "...\n\n"

puts 'Step 2: Try to parse with OpenSSL::PKey.read'
begin
  pkey = OpenSSL::PKey.read(pem_key)
  puts '✅ Successfully parsed!'
  puts "   Class: #{pkey.class}"
  puts "   Public key: #{pkey.public_key?}"
  puts "   Private key: #{pkey.private_key?}"

  puts "   Curve: #{pkey.group.curve_name}" if pkey.is_a?(OpenSSL::PKey::EC)

  puts "\nStep 3: Generate JWT token"
  now = Time.now.to_i
  payload = {
    iss: team_id,
    iat: now,
    exp: now + 1800
  }

  token = JWT.encode(payload, pkey, 'ES256', { kid: key_id })
  puts '✅ JWT Token generated successfully!'
  puts "   Token (first 50 chars): #{token[0..50]}..."
  puts "   Token length: #{token.length}"

  # Decode to verify
  decoded = JWT.decode(token, pkey.public_key, true, { algorithm: 'ES256' })
  puts "\n✅ Token verified successfully!"
  puts "   Decoded payload: #{decoded.first.inspect}"

rescue StandardError => e
  puts "❌ Error: #{e.message}"
  puts "   Class: #{e.class}"
  puts '   Backtrace:'
  e.backtrace.first(5).each { |line| puts "      #{line}" }
end
