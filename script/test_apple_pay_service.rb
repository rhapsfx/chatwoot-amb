#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for Apple Pay CaseTransformer integration
# This validates the transformation logic without loading full Rails

require 'active_support/core_ext/string'
require_relative 'app/services/apple_messages_for_business/case_transformer'

puts '=' * 80
puts 'Apple Pay Service - Transformation Test'
puts '=' * 80

# Test 1: Payment Request Transformation
puts "\n[Test 1] Payment Request Structure"
payment_request = {
  'line_items' => [
    { 'label' => 'Product A', 'amount' => '10.00', 'type' => 'final' },
    { 'label' => 'Shipping', 'amount' => '5.00', 'type' => 'final' }
  ],
  'total' => { 'label' => 'Total', 'amount' => '15.00', 'type' => 'final' },
  'apple_pay' => {
    'merchant_identifier' => 'merchant.com.example',
    'supported_networks' => %w[visa masterCard amex],
    'merchant_capabilities' => %w[supports3DS supportsCredit]
  },
  'merchant_name' => 'Demo Store',
  'country_code' => 'US',
  'currency_code' => 'USD'
}

transformed = AppleMessagesForBusiness::CaseTransformer.to_apple_format(payment_request)

puts "Original (snake_case): #{payment_request.keys.inspect}"
puts "Transformed (camelCase): #{transformed.keys.inspect}"

expected_keys = %i[lineItems total applePay merchantName countryCode currencyCode]
missing_keys = expected_keys - transformed.keys
transformed.keys

if missing_keys.empty?
  puts '✅ All expected keys present'
else
  puts "❌ Missing keys: #{missing_keys.inspect}"
end

# Test 2: Nested applePay Structure
puts "\n[Test 2] Nested applePay Structure"
apple_pay_section = transformed[:applePay]
puts "applePay keys: #{apple_pay_section.keys.inspect}"

expected_apple_pay_keys = %i[merchantIdentifier supportedNetworks merchantCapabilities]
missing_apple_pay_keys = expected_apple_pay_keys - apple_pay_section.keys

if missing_apple_pay_keys.empty?
  puts '✅ All applePay keys transformed correctly'
else
  puts "❌ Missing applePay keys: #{missing_apple_pay_keys.inspect}"
end

# Test 3: Line Items Array
puts "\n[Test 3] Line Items Array Transformation"
line_items = transformed[:lineItems]
puts "Line items count: #{line_items.length}"
puts "First item keys: #{line_items.first.keys.inspect}"

if line_items.first.keys.include?(:label) && line_items.first.keys.include?(:amount)
  puts '✅ Line items preserved correctly'
else
  puts '❌ Line items structure incorrect'
end

# Test 4: Full Payment Structure
puts "\n[Test 4] Complete Payment Structure (with endpoints)"
payment_structure = {
  'payment_request' => payment_request,
  'merchant_session' => { 'session_id' => 'test123', 'expires_at' => '2025-10-27T12:00:00Z' },
  'endpoints' => { 'payment_gateway_url' => 'https://example.com/gateway' }
}

full_transformed = AppleMessagesForBusiness::CaseTransformer.to_apple_format(payment_structure)
puts "Top-level keys: #{full_transformed.keys.inspect}"

expected_top_keys = %i[paymentRequest merchantSession endpoints]
if (expected_top_keys - full_transformed.keys).empty?
  puts '✅ Payment structure transformed correctly'
  puts "   - paymentRequest: #{full_transformed[:paymentRequest].keys.inspect}"
  puts "   - endpoints: #{full_transformed[:endpoints].keys.inspect}"
else
  puts '❌ Payment structure incomplete'
end

# Test 5: Optional Fields
puts "\n[Test 5] Optional Contact Fields"
with_optional = {
  'payment_request' => payment_request,
  'required_billing_contact_fields' => %w[postalAddress email],
  'required_shipping_contact_fields' => %w[postalAddress phone]
}

optional_transformed = AppleMessagesForBusiness::CaseTransformer.to_apple_format(with_optional)
if optional_transformed[:requiredBillingContactFields] && optional_transformed[:requiredShippingContactFields]
  puts '✅ Optional contact fields transformed correctly'
else
  puts "❌ Optional fields missing: #{optional_transformed.keys.inspect}"
end

puts "\n" + ('=' * 80)
puts 'All transformation tests completed!'
puts '=' * 80
