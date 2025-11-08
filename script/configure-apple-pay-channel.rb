#!/usr/bin/env ruby
# Configure Apple Pay for Channel on msp.rhaps.net
# Run this script in Rails console on the server

puts '🍎 Configuring Apple Pay for Apple Messages for Business Channel'
puts '=' * 70

# Read certificate files from container
puts "\n📖 Reading certificate files..."
merchant_cert = File.read('/app/certs/apple_pay/apple_pay_cert.pem')
merchant_key = File.read('/app/certs/apple_pay/apple_pay_private.key')
processing_cert = File.read('/app/certs/apple_pay/payment_processing_cert.pem')
processing_key = File.read('/app/certs/apple_pay/payment_processing_private.key')

puts "✅ Merchant Identity Certificate: #{merchant_cert.lines.count} lines"
puts "✅ Merchant Identity Private Key: #{merchant_key.lines.count} lines"
puts "✅ Payment Processing Certificate: #{processing_cert.lines.count} lines"
puts "✅ Payment Processing Private Key: #{processing_key.lines.count} lines"

# Get the channel
puts "\n🔍 Finding Apple Messages for Business channel..."
channel = Channel::AppleMessagesForBusiness.first

if channel.nil?
  puts '❌ ERROR: No Apple Messages for Business channel found!'
  exit 1
end

puts "✅ Found channel: #{channel.name} (ID: #{channel.id})"
puts "   Inbox: #{channel.inbox.name}"
puts "   Account: #{channel.account.name}"

# Configure Apple Pay
puts "\n⚙️  Configuring Apple Pay settings..."
channel.update!(
  payment_settings: {
    'test_mode' => false,  # Set to true for testing
    'apple_pay_enabled' => true,
    'merchantDomain' => 'msp.rhaps.net',
    'apple_pay' => {
      'merchant_identifier' => 'MS58PRCFSS.com.apple.apple-pay-matthieu',  # Full ID with team prefix - service will strip when needed
      'merchant_display_name' => 'Acoustic House',
      'merchant_identity_certificate' => merchant_cert,
      'merchant_identity_private_key' => merchant_key,
      'payment_processing_certificate' => processing_cert,
      'payment_processing_private_key' => processing_key
    },
    'supported_networks' => %w[visa masterCard amex discover],
    'merchant_capabilities' => %w[supports3DS supportsDebit supportsCredit],
    'country_code' => 'US',
    'currency_code' => 'USD'
  }
)

puts "\n📝 Note: Merchant identifier is stored with team prefix (MS58PRCFSS.com.apple.apple-pay-matthieu)"
puts '   The MerchantSessionService will automatically strip the prefix when communicating with Apple.'

puts "\n✅ Apple Pay configured successfully!"
puts "\n📊 Configuration Summary:"
puts "   Merchant ID: #{channel.payment_settings.dig('apple_pay', 'merchant_identifier')}"
puts "   Domain: #{channel.payment_settings['merchantDomain']}"
puts "   Test Mode: #{channel.payment_settings['test_mode']}"
puts "   Apple Pay Enabled: #{channel.payment_settings['apple_pay_enabled']}"
puts "   Supported Networks: #{channel.payment_settings['supported_networks'].join(', ')}"
puts "   Country: #{channel.payment_settings['country_code']}"
puts "   Currency: #{channel.payment_settings['currency_code']}"

puts "\n🎉 Configuration complete! You can now send Apple Pay payment requests."
puts "\n📝 Next steps:"
puts '   1. Verify domain in Apple Developer Portal'
puts '   2. Test sending an Apple Pay payment request'
puts '   3. Check iOS device for payment sheet'
