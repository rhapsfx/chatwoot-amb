#!/usr/bin/env ruby

# Simple validation script for Apple Messages IDR implementation
# This script checks that all the necessary components are in place

puts '🔍 Apple Messages IDR Implementation Validation'
puts '=' * 50

# Check 1: IDR Service exists
begin
  require_relative 'app/services/apple_messages_for_business/interactive_data_reference_service'
  puts '✅ InteractiveDataReferenceService class exists'
rescue LoadError => e
  puts "❌ InteractiveDataReferenceService class missing: #{e.message}"
end

# Check 2: IDR Service has required methods
begin
  service_methods = AppleMessagesForBusiness::InteractiveDataReferenceService.instance_methods(false)
  required_methods = [:retrieve_and_decrypt, :validate_idr_data!, :download_encrypted_data, :decrypt_data]

  required_methods.each do |method|
    if service_methods.include?(method) || AppleMessagesForBusiness::InteractiveDataReferenceService.private_instance_methods(false).include?(method)
      puts "✅ IDR Service has #{method} method"
    else
      puts "❌ IDR Service missing #{method} method"
    end
  end
rescue StandardError => e
  puts "❌ Error checking IDR Service methods: #{e.message}"
end

# Check 3: Incoming Message Service has IDR support
begin
  require_relative 'app/services/apple_messages_for_business/incoming_message_service'
  service_methods = AppleMessagesForBusiness::IncomingMessageService.private_instance_methods(false)

  if service_methods.include?(:process_interactive_data_reference)
    puts '✅ IncomingMessageService has IDR processing method'
  else
    puts '❌ IncomingMessageService missing IDR processing method'
  end

  if service_methods.include?(:determine_content_type_from_data)
    puts '✅ IncomingMessageService has IDR content type detection'
  else
    puts '❌ IncomingMessageService missing IDR content type detection'
  end
rescue StandardError => e
  puts "❌ Error checking IncomingMessageService: #{e.message}"
end

# Check 4: Send Message Service has IDR support
begin
  require_relative 'app/services/apple_messages_for_business/send_message_service'
  service_methods = AppleMessagesForBusiness::SendMessageService.private_instance_methods(false)

  if service_methods.include?(:should_request_idr?)
    puts '✅ SendMessageService has IDR request logic'
  else
    puts '❌ SendMessageService missing IDR request logic'
  end

  # Check if send_to_apple_gateway supports request_idr parameter
  method = AppleMessagesForBusiness::SendMessageService.instance_method(:send_to_apple_gateway)
  if method.parameters.any? { |p| p[1] == :request_idr }
    puts '✅ SendMessageService gateway supports IDR header'
  else
    puts '❌ SendMessageService gateway missing IDR header support'
  end
rescue StandardError => e
  puts "❌ Error checking SendMessageService: #{e.message}"
end

# Check 5: Test basic IDR validation
begin
  puts "\n🧪 Testing IDR Validation Logic..."

  # Test missing fields validation
  begin
    # Create a simple mock channel
    mock_channel = Object.new
    def generate_jwt_token = 'test-token'
    def business_id = 'test-business-id'

    invalid_idr = { 'bid' => 'test' }  # Missing required fields

    service = AppleMessagesForBusiness::InteractiveDataReferenceService.new(
      idr_data: invalid_idr,
      channel: mock_channel
    )

    service.send(:validate_idr_data!)
    puts '❌ IDR validation should have failed'
  rescue ArgumentError => e
    if e.message.include?('Missing required IDR fields')
      puts '✅ IDR validation correctly rejects incomplete data'
    else
      puts "❌ IDR validation error message incorrect: #{e.message}"
    end
  rescue StandardError => e
    puts "❌ Unexpected error in IDR validation: #{e.message}"
  end
rescue StandardError => e
  puts "❌ Error testing IDR validation: #{e.message}"
end

# Check 6: Test payload size detection
begin
  puts "\n🧪 Testing Payload Size Detection..."

  # Create a simple mock for testing
  mock_channel = Object.new
  def generate_jwt_token = 'test-token'
  def business_id = 'test-business-id'

  mock_message = Object.new
  def content_type = 'apple_list_picker'
  def content_attributes = {}

  service = AppleMessagesForBusiness::SendMessageService.new(
    channel: mock_channel,
    destination_id: 'test-destination',
    message: mock_message
  )

  # Test small payload
  small_payload = { data: 'small' }
  small_result = service.send(:should_request_idr?, small_payload)

  # Test large payload
  large_payload = { data: 'x' * 10_000 }
  large_result = service.send(:should_request_idr?, large_payload)

  if !small_result && large_result
    puts '✅ Payload size detection works correctly'
  else
    puts "❌ Payload size detection failed: small=#{small_result}, large=#{large_result}"
  end
rescue StandardError => e
  puts "❌ Error testing payload size detection: #{e.message}"
end

puts "\n" + ('=' * 50)
puts '🏁 IDR Implementation Validation Complete'
puts "\n💡 Next Steps:"
puts '   1. Test with actual Apple Messages for Business webhook'
puts '   2. Send a list picker with multiple images (>10KB response)'
puts '   3. Verify IDR processing in production logs'
puts '   4. Monitor message processing performance'
