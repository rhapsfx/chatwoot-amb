#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug private key parsing
puts "🔧 Debugging Private Key Parsing\n\n"

key_content = ENV.fetch('APPLE_MAPS_PRIVATE_KEY', nil)
puts "Original key: #{key_content[0..50]}...\n\n"

# Try adding headers
clean_key = key_content.gsub(/\s+/, '')
formatted_key = "-----BEGIN PRIVATE KEY-----\n#{clean_key}\n-----END PRIVATE KEY-----"

puts 'Formatted key (first 100 chars):'
puts formatted_key[0..100]
puts "...\n\n"

puts 'Attempting to parse with OpenSSL::PKey.read...'
begin
  pkey = OpenSSL::PKey.read(formatted_key)
  puts '✅ Success!'
  puts "   Class: #{pkey.class}"
  puts "   Curve: #{pkey.group.curve_name}" if pkey.respond_to?(:group)
rescue StandardError => e
  puts "❌ Failed: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first}"
end

puts "\nAttempting to parse with OpenSSL::PKey::EC.new('prime256v1')..."
begin
  OpenSSL::PKey::EC.new('prime256v1')
  puts '✅ EC key with prime256v1 curve created'
rescue StandardError => e
  puts "❌ Failed: #{e.message}"
end
