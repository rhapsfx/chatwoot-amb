# Paste this into rails console to configure Apple Pay
# Run: rails console

# Read certificate and private key
cert_content = File.read('certs/apple_pay/apple_pay_cert.pem')
key_content = File.read('certs/apple_pay/apple_pay_private.key')

# Get the channel
channel = Channel::AppleMessagesForBusiness.first

# Configure Apple Pay settings
payment_settings = channel.payment_settings || {}
payment_settings['merchantDomain'] = 'liquid-m3-pro.tail367da4.ts.net'
payment_settings['merchantIdentifier'] = 'MS58PRCFSS.com.apple.apple-pay-matthieu'
payment_settings['applePayEnabled'] = true
payment_settings['countryCode'] = 'US'
payment_settings['currencyCode'] = 'USD'

# Store certificate and private key
payment_settings['apple_pay'] ||= {}
payment_settings['apple_pay']['merchant_identifier'] = 'MS58PRCFSS.com.apple.apple-pay-matthieu'
payment_settings['apple_pay']['merchant_certificate'] = cert_content
payment_settings['apple_pay']['merchant_private_key'] = key_content
payment_settings['apple_pay']['merchant_display_name'] = 'Acoustic House'
payment_settings['apple_pay']['supported_networks'] = %w[visa masterCard amex discover]
payment_settings['apple_pay']['merchant_capabilities'] = %w[supports3DS supportsDebit supportsCredit]

# Disable test mode (use real Apple Pay)
payment_settings['test_mode'] = false

channel.payment_settings = payment_settings
channel.save!

puts '✅ Apple Pay configured successfully!'
puts '   Merchant ID: MS58PRCFSS.com.apple.apple-pay-matthieu'
puts '   Domain: liquid-m3-pro.tail367da4.ts.net'
puts '   Display Name: Acoustic House'
puts '   Test Mode: Disabled (using real Apple Pay)'
