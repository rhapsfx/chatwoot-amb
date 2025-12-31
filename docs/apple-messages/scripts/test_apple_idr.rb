#!/usr/bin/env ruby

# Test script for Apple Messages for Business IDR (Interactive Data Reference) handling
# This script validates that Chatwoot can properly process large interactive message responses

require_relative 'config/environment'

class AppleMessagesIDRTest
  def initialize
    @test_results = []
  end

  def run_all_tests
    puts '🧪 Running Apple Messages IDR Tests...'
    puts '=' * 50

    test_idr_service_validation
    test_idr_service_error_handling
    test_incoming_message_idr_detection
    test_send_message_idr_request
    test_large_payload_detection

    print_summary
  end

  private

  def test_idr_service_validation
    test_name = 'IDR Service Validation'
    puts "\n📋 Testing: #{test_name}"

    begin
      # Test with invalid IDR data (missing required fields)
      invalid_idr = { 'bid' => 'test', 'url' => 'https://example.com' }

      service = AppleMessagesForBusiness::InteractiveDataReferenceService.new(
        idr_data: invalid_idr,
        channel: create_mock_channel
      )

      begin
        service.retrieve_and_decrypt
        record_test_result(test_name, false, 'Should have failed with missing fields')
      rescue ArgumentError => e
        if e.message.include?('Missing required IDR fields')
          record_test_result(test_name, true, 'Correctly validates required fields')
        else
          record_test_result(test_name, false, "Wrong validation error: #{e.message}")
        end
      end
    rescue StandardError => e
      record_test_result(test_name, false, "Unexpected error: #{e.message}")
    end
  end

  def test_idr_service_error_handling
    test_name = 'IDR Service Error Handling'
    puts "\n📋 Testing: #{test_name}"

    begin
      # Test with complete but fake IDR data
      fake_idr = {
        'bid' => 'test-bid',
        'owner' => 'test-owner',
        'url' => 'https://httpbin.org/status/404',
        'size' => '100',
        'signature' => 'fake-signature',
        'dataRefSig' => 'fake-data-ref-sig'
      }

      service = AppleMessagesForBusiness::InteractiveDataReferenceService.new(
        idr_data: fake_idr,
        channel: create_mock_channel
      )

      begin
        service.retrieve_and_decrypt
        record_test_result(test_name, false, 'Should have failed with 404')
      rescue StandardError => e
        if e.message.include?('404') || e.message.include?('download failed')
          record_test_result(test_name, true, 'Correctly handles download failures')
        else
          record_test_result(test_name, false, "Unexpected error type: #{e.message}")
        end
      end
    rescue StandardError => e
      record_test_result(test_name, false, "Setup error: #{e.message}")
    end
  end

  def test_incoming_message_idr_detection
    test_name = 'Incoming Message IDR Detection'
    puts "\n📋 Testing: #{test_name}"

    begin
      # Create a mock incoming message service with IDR data
      params = {
        'id' => 'test-message-id',
        'interactiveDataRef' => {
          'bid' => 'test-bid',
          'owner' => 'test-owner',
          'url' => 'https://example.com/idr',
          'size' => '1000',
          'signature' => 'test-signature',
          'dataRefSig' => 'test-data-ref-sig'
        }
      }

      service = AppleMessagesForBusiness::IncomingMessageService.new(
        inbox: create_mock_inbox,
        params: params,
        headers: { source_id: 'test-source-id' }
      )

      # Test that IDR is detected as a valid interactive message
      if service.send(:interactive_message?)
        record_test_result(test_name, true, 'IDR correctly detected as interactive message')
      else
        record_test_result(test_name, false, 'IDR not detected as interactive message')
      end
    rescue StandardError => e
      record_test_result(test_name, false, "Error testing IDR detection: #{e.message}")
    end
  end

  def test_send_message_idr_request
    test_name = 'Send Message IDR Request Logic'
    puts "\n📋 Testing: #{test_name}"

    begin
      # Create a large list picker payload
      large_payload = {
        interactiveData: {
          data: {
            listPicker: { sections: [{ title: 'Test', items: [] }] },
            images: Array.new(5) { |i| { identifier: "img#{i}", data: 'base64data' * 100 } }
          }
        }
      }

      service = AppleMessagesForBusiness::SendMessageService.new(
        channel: create_mock_channel,
        destination_id: 'test-destination',
        message: create_mock_message
      )

      should_request = service.send(:should_request_idr?, large_payload)

      if should_request
        record_test_result(test_name, true, 'Correctly identifies large payloads for IDR')
      else
        record_test_result(test_name, false, 'Failed to identify large payload for IDR')
      end
    rescue StandardError => e
      record_test_result(test_name, false, "Error testing IDR request logic: #{e.message}")
    end
  end

  def test_large_payload_detection
    test_name = 'Large Payload Detection'
    puts "\n📋 Testing: #{test_name}"

    begin
      service = AppleMessagesForBusiness::SendMessageService.new(
        channel: create_mock_channel,
        destination_id: 'test-destination',
        message: create_mock_message
      )

      # Test small payload (should not request IDR)
      small_payload = { interactiveData: { data: { listPicker: { sections: [] } } } }
      small_result = service.send(:should_request_idr?, small_payload)

      # Test large payload (should request IDR)
      large_payload = { data: 'x' * 10_000 }
      large_result = service.send(:should_request_idr?, large_payload)

      if !small_result && large_result
        record_test_result(test_name, true, 'Correctly detects payload sizes')
      else
        record_test_result(test_name, false, "Incorrect payload size detection: small=#{small_result}, large=#{large_result}")
      end
    rescue StandardError => e
      record_test_result(test_name, false, "Error testing payload detection: #{e.message}")
    end
  end

  def record_test_result(test_name, passed, message)
    status = passed ? '✅ PASS' : '❌ FAIL'
    puts "   #{status}: #{message}"
    @test_results << { test: test_name, passed: passed, message: message }
  end

  def print_summary
    puts "\n" + ('=' * 50)
    puts '📊 TEST SUMMARY'
    puts '=' * 50

    passed_count = @test_results.count { |r| r[:passed] }
    total_count = @test_results.count

    @test_results.each do |result|
      status = result[:passed] ? '✅' : '❌'
      puts "#{status} #{result[:test]}: #{result[:message]}"
    end

    puts "\n🏁 Results: #{passed_count}/#{total_count} tests passed"

    if passed_count == total_count
      puts '🎉 All IDR tests passed! Implementation is ready.'
    else
      puts '⚠️  Some tests failed. Please review the implementation.'
    end
  end

  # Mock objects for testing
  def create_mock_channel
    channel = double('Channel')
    allow(channel).to receive(:generate_jwt_token).and_return('fake-jwt-token')
    allow(channel).to receive(:business_id).and_return('fake-business-id')
    channel
  end

  def create_mock_inbox
    inbox = double('Inbox')
    allow(inbox).to receive(:channel).and_return(create_mock_channel)
    allow(inbox).to receive(:account_id).and_return(1)
    allow(inbox).to receive(:id).and_return(1)
    inbox
  end

  def create_mock_message
    message = double('Message')
    allow(message).to receive(:content_type).and_return('apple_list_picker')
    allow(message).to receive(:content_attributes).and_return({})
    message
  end
end

# Run the tests
AppleMessagesIDRTest.new.run_all_tests if __FILE__ == $0
