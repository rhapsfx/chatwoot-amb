# Configure both Apple Pay certificates in Rails console
# Run: rails console < update_apple_pay_certs.rb

# Read all certificate and key files
merchant_identity_cert = File.read('certs/apple_pay/apple_pay_cert.pem')
merchant_identity_key = File.read('certs/apple_pay/apple_pay_private.key')
payment_processing_cert = File.read('certs/apple_pay/payment_processing_cert.pem')
payment_processing_key = File.read('certs/apple_pay/payment_processing_private_v2.key')

# Get the channel
channel = Channel::AppleMessagesForBusiness.first

# Update Apple Pay settings with BOTH certificates
payment_settings = channel.payment_settings || {}
payment_settings['merchantDomain'] = 'liquid-m3-pro.tail367da4.ts.net'
payment_settings['merchantIdentifier'] = 'MS58PRCFSS.com.apple.apple-pay-matthieu'
payment_settings['applePayEnabled'] = true
payment_settings['countryCode'] = 'US'
payment_settings['currencyCode'] = 'USD'

# Store both certificates
payment_settings['apple_pay'] ||= {}
payment_settings['apple_pay']['merchant_identifier'] = 'MS58PRCFSS.com.apple.apple-pay-matthieu'
payment_settings['apple_pay']['merchant_display_name'] = 'Acoustic House'

# Merchant Identity Certificate (for creating merchant sessions)
payment_settings['apple_pay']['merchant_identity_certificate'] = merchant_identity_cert
payment_settings['apple_pay']['merchant_identity_private_key'] = merchant_identity_key

# Payment Processing Certificate (for decrypting payment tokens)
payment_settings['apple_pay']['payment_processing_certificate'] = payment_processing_cert
payment_settings['apple_pay']['payment_processing_private_key'] = payment_processing_key

# Network and capability settings
payment_settings['apple_pay']['supported_networks'] = %w[visa masterCard amex discover]
payment_settings['apple_pay']['merchant_capabilities'] = %w[supports3DS supportsDebit supportsCredit]

# Disable test mode
payment_settings['test_mode'] = false

channel.payment_settings = payment_settings
channel.save!

puts '✅ Apple Pay configured with BOTH certificates!'
puts ''
puts '📋 Configuration:'
puts '   Merchant ID: MS58PRCFSS.com.apple.apple-pay-matthieu'
puts '   Domain: liquid-m3-pro.tail367da4.ts.net'
puts '   Display Name: Acoustic House'
puts ''
puts '🔐 Certificates:'
puts '   ✅ Merchant Identity Certificate (for merchant sessions)'
puts '   ✅ Payment Processing Certificate (for payment decryption)'
puts ''
puts '🚀 Ready to process real Apple Pay payments!'
