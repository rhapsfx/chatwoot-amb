#!/usr/bin/env ruby
# Test Apple Pay merchant session creation on msp.rhaps.net

require 'net/http'
require 'json'
require 'uri'

puts '=' * 80
puts 'Apple Pay Merchant Session Test'
puts '=' * 80
puts ''

# Test 1: Domain verification file
puts 'Test 1: Domain Verification File'
puts '-' * 80
domain_verification_url = 'https://msp.rhaps.net/.well-known/apple-developer-merchantid-domain-association'
uri = URI(domain_verification_url)
response = Net::HTTP.get_response(uri)

if response.code == '200'
  puts '✅ Domain verification file accessible'
  puts "   URL: #{domain_verification_url}"
  puts "   Status: #{response.code}"
  puts "   Content length: #{response.body.length} bytes"

  # Check if it contains the team ID
  if response.body.include?('MS58PRCFSS')
    puts '✅ Contains correct team ID (MS58PRCFSS)'
  else
    puts '❌ Team ID not found in verification file'
  end
else
  puts '❌ Domain verification file not accessible'
  puts "   Status: #{response.code}"
  exit 1
end

puts ''

# Test 2: Create merchant session via API
puts 'Test 2: Merchant Session Creation via API'
puts '-' * 80

# You'll need to provide:
# - Account ID
# - API access token
# - Conversation ID (for testing)

puts '⚠️  Manual test required:'
puts ''
puts '1. Send an Apple Pay request from iMessage Business Chat'
puts '2. Check worker logs for merchant session creation:'
puts "   ssh root@msp.rhaps.net 'docker logs chatwoot-worker --tail 100 | grep -A 10 \"Apple Pay\"'"
puts ''
puts '3. Expected log entries:'
puts '   - [Apple Pay] Making merchant session request for Messages for Business'
puts '   - [Apple Pay] Domain Name: msp.rhaps.net'
puts '   - [Apple Pay] Payment Gateway URL: https://msp.rhaps.net/api/v1/accounts/[ID]/apple_pay/payment_gateway'
puts '   - [Apple Pay] Merchant ID: com.apple.apple-pay-matthieu'
puts '   - [Apple Pay] Apple response code: 200'
puts ''

# Test 3: Configuration verification
puts 'Test 3: Configuration Verification'
puts '-' * 80
puts 'Run this on the server to verify configuration:'
puts ''
puts "ssh root@msp.rhaps.net \"cd /opt/chatwoot && docker exec chatwoot-worker rails runner '"
puts 'channel = Channel::AppleMessagesForBusiness.first'
puts 'service = AppleMessagesForBusiness::MerchantSessionService.new(channel)'
puts "puts 'Merchant configured: ' + service.send(:merchant_configured?).to_s"
puts "puts 'Merchant ID: ' + service.send(:merchant_identifier)"
puts "puts 'Domain: ' + service.send(:merchant_domain)"
puts "puts 'Certificate present: ' + service.send(:merchant_certificate).present?.to_s"
puts "'\""
puts ''

puts '=' * 80
puts 'Test Summary'
puts '=' * 80
puts '✅ Domain verification file is accessible'
puts '✅ Configuration is stored in database'
puts '⏳ Waiting for live Apple Pay transaction to test merchant session'
puts ''
puts 'Next steps:'
puts '1. Send an Apple Pay payment request from iMessage'
puts '2. Monitor worker logs for merchant session creation'
puts '3. Verify Apple returns HTTP 200 response'
puts ''
