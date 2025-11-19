#!/usr/bin/env ruby

# Simple test script to verify Apple Messages webhook endpoint
require 'net/http'
require 'json'
require 'uri'

webhook_url = 'https://dev.rhaps.net/webhooks/apple_messages_for_business/c7b1f0cf-c3fd-40ab-8d40-cff3d81d1d6b/message'
puts "Testing Apple Messages webhook endpoint: #{webhook_url}"
puts

# Test 1: Basic connectivity
puts '🔗 Test 1: Basic connectivity'
begin
  uri = URI(webhook_url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  # Send a simple POST request (will fail auth but should get a response)
  request = Net::HTTP::Post.new(uri.path)
  request['Content-Type'] = 'application/json'
  request.body = '{"test": "connectivity"}'

  response = http.request(request)
  puts "✅ Response code: #{response.code}"
  puts "✅ Response message: #{response.message}"
  puts '✅ Endpoint is reachable'
rescue StandardError => e
  puts "❌ Connection failed: #{e.message}"
  exit 1
end

puts
puts '🔍 Test 2: Expected responses'
case response.code.to_i
when 401, 403
  puts "✅ Good: Endpoint returns #{response.code} (auth required)"
when 404
  puts '❌ Problem: Channel not found (MSP ID mismatch)'
when 500
  puts '⚠️  Server error - check logs'
else
  puts "⚠️  Unexpected response: #{response.code}"
end

puts
puts '📋 Summary:'
puts "- Webhook URL: #{webhook_url}"
puts '- MSP ID: c7b1f0cf-c3fd-40ab-8d40-cff3d81d1d6b'
puts '- Customer messages: https://bcrw.apple.com/urn:biz:b0566171-3c85-4eff-b0fb-dcab6bc5cdc6'
puts '- Expected: Apple Business Register should route customer messages to your webhook'
puts
puts 'If endpoint is reachable but no webhooks arrive:'
puts '1. Check Apple Business Register webhook configuration'
puts '2. Verify Business ID (b0566171-3c85-4eff-b0fb-dcab6bc5cdc6) is linked to MSP ID'
puts '3. Test sending message from a different device'
puts '4. Check Apple Business Register status/logs'
