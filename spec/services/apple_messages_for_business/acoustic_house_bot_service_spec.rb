# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::AcousticHouseBotService do
  let(:account) { create(:account) }
  let(:inbox) do
    allow_any_instance_of(Channel::AppleMessagesForBusiness).to receive(:validate_jwt_credentials).and_return(nil)
    create(:inbox, account: account, channel: create(:channel_apple_messages_for_business, account: account))
  end
  let(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let(:contact) { conversation.contact }
  let(:message) { create(:message, conversation: conversation, account: account, message_type: :incoming) }

  # Legacy mode service (backward compatibility)
  let(:service) { described_class.new(conversation, message) }

  # Config-driven mode (new)
  let(:bot_config) do
    {
      conversation_flow: { initial_state: 'AHA1', idle_timeout_minutes: 30 },
      keyword_mappings: {
        demo_keywords: { 'guitar' => 'handle_list_picker_demo' },
        flow_control_keywords: { 'menu' => 'handle_menu' }
      },
      interactive_handlers: { 'qr_travel' => 'handle_region_selection' },
      required_templates: { list: [], validation: { enabled: false } }
    }
  end
  let(:agent_bot) do
    create(:agent_bot, bot_type: :webhook, bot_config: bot_config, account: account)
  end
  let(:config_service) { described_class.new(conversation, message, agent_bot) }

  describe '#initialize' do
    context 'legacy mode (no bot provided)' do
      it 'initializes with hardcoded config' do
        expect { service }.not_to raise_error
      end

      it 'logs warning about legacy mode' do
        expect(Rails.logger).to receive(:warn).with(/legacy mode/)
        described_class.new(conversation, message)
      end
    end

    context 'config-driven mode (bot provided)' do
      it 'initializes with bot config' do
        expect { config_service }.not_to raise_error
      end

      it 'validates config' do
        expect_any_instance_of(described_class).to receive(:validate_config!)
        described_class.new(conversation, message, agent_bot)
      end

      it 'raises error for invalid config' do
        invalid_bot = create(:agent_bot, bot_type: :webhook, bot_config: {}, account: account)
        expect do
          described_class.new(conversation, message, invalid_bot)
        end.to raise_error(StandardError, /Missing required config keys/)
      end
    end

    context 'with explicit config override' do
      let(:override_config) do
        {
          conversation_flow: { initial_state: 'AHA1', idle_timeout_minutes: 60 },
          keyword_mappings: {
            demo_keywords: { 'test' => 'handle_test' },
            flow_control_keywords: { 'stop' => 'handle_stop' }
          },
          interactive_handlers: {},
          required_templates: { list: [], validation: { enabled: false } }
        }
      end

      it 'uses provided config over bot config' do
        service_with_override = described_class.new(conversation, message, agent_bot, override_config)
        expect(service_with_override.instance_variable_get(:@config)['conversation_flow']['idle_timeout_minutes']).to eq(60)
      end
    end
  end

  describe '#process_message' do
    context 'when conversation times out' do
      before do
        # Set conversation last updated > 30 minutes ago
        conversation.custom_attributes = {
          'bot_state' => 'AHC1',
          'bot_state_updated_at' => 31.minutes.ago.iso8601
        }
        conversation.save!
      end

      it 'resets to welcome state' do
        allow(service).to receive(:handle_welcome)
        service.process_message
        expect(conversation.reload.custom_attributes['bot_state']).to eq('AHA1')
      end

      it 'allows keyword handler to process before state' do
        message.update!(content: 'menu')
        allow(service).to receive(:handle_menu)
        expect(service).to receive(:handle_menu).and_call_original
        service.process_message
      end
    end

    context 'when message has attachments' do
      let(:attachment_double) do
        double('attachment',
               file: double('file', content_type: 'image/jpeg'),
               push_event_data: { id: 1, file_type: 'image' })
      end

      before do
        allow(message).to receive(:attachments).and_return([attachment_double])
      end

      it 'routes to attachment handler' do
        expect(service).to receive(:handle_received_attachment)
        service.process_message
      end

      it 'does not process keywords' do
        message.update!(content: 'menu')
        expect(service).not_to receive(:handle_menu)
        service.process_message
      end
    end

    context 'when message contains keywords' do
      it 'routes to list picker demo for "guitar" keyword' do
        message.update!(content: 'guitar')
        expect(service).to receive(:handle_list_picker_demo)
        service.process_message
      end

      it 'routes to form demo for "form" keyword' do
        message.update!(content: 'form')
        expect(service).to receive(:handle_form_demo)
        service.process_message
      end

      it 'sets demo mode state after demo keyword' do
        message.update!(content: 'guitar')
        allow(service).to receive(:send_text_message)
        allow(service).to receive(:send_guitar_list_picker)
        service.process_message
        expect(conversation.reload.custom_attributes['bot_state']).to eq('DEMO_MODE')
      end

      it 'routes to start_over for "startover" keyword' do
        message.update!(content: 'startover')
        expect(service).to receive(:handle_start_over)
        service.process_message
      end
    end

    context 'when message is form response' do
      before do
        message.update!(
          content_type: 'apple_form_response',
          content_attributes: {
            'form_response' => {
              'selections' => [
                { 'title' => 'Full Name', 'items' => [{ 'value' => 'John Doe' }] },
                { 'title' => 'Stage Name', 'items' => [{ 'value' => 'Johnny D' }] }
              ]
            }
          }
        )
      end

      it 'routes to form response handler' do
        expect(service).to receive(:handle_form_response)
        service.process_message
      end

      it 'routes to large form handler in DEMO_MODE_LARGE_FORM state' do
        conversation.custom_attributes = { 'bot_state' => 'DEMO_MODE_LARGE_FORM' }
        conversation.save!
        expect(service).to receive(:handle_large_form_response).with(message.content_attributes)
        service.process_message
      end
    end
  end

  describe '#process_interactive_response' do
    context 'with quick reply format' do
      let(:interactive_data) do
        {
          'data' => {
            'quick-reply' => {
              'selectedIdentifier' => 'qr_travel',
              'selectedIndex' => 0,
              'items' => [
                { 'title' => 'Americas', 'identifier' => 'qr_travel' }
              ]
            }
          }
        }
      end

      it 'extracts selectedIdentifier correctly' do
        expect(service).to receive(:handle_region_selection).with(interactive_data)
        service.process_interactive_response(interactive_data)
      end
    end

    context 'with NSKeyedArchiver format' do
      let(:interactive_data) do
        {
          '$archiver' => 'NSKeyedArchiver',
          '$objects' => ['$null', 'NSString', 'Americas']
        }
      end

      before do
        conversation.custom_attributes = { 'bot_state' => 'AHA2' }
        conversation.save!
      end

      it 'infers requestIdentifier from bot state' do
        expect(service).to receive(:handle_region_selection).with(interactive_data)
        service.process_interactive_response(interactive_data)
      end

      it 'routes form response to form handler' do
        conversation.custom_attributes = { 'bot_state' => 'AHB1' }
        conversation.save!
        expect(service).to receive(:handle_form_response)
        service.process_interactive_response(interactive_data)
      end
    end

    context 'with standard requestIdentifier format' do
      let(:interactive_data) do
        {
          'data' => {
            'requestIdentifier' => 'lp_guitar_0319'
          }
        }
      end

      it 'routes to guitar selection handler' do
        expect(service).to receive(:handle_guitar_selection).with(interactive_data)
        service.process_interactive_response(interactive_data)
      end
    end
  end

  describe '#handle_guitar_selection (idempotency guard)' do
    let(:interactive_data) do
      {
        'ldtext' => 'Martin DC28E Dreadnought'
      }
    end

    before do
      allow(Redis::Alfred).to receive(:get).and_return(nil)
      allow(Redis::Alfred).to receive(:setex)
      allow(service).to receive(:send_text_message)
      allow(service).to receive(:handle_ar_introduction)
    end

    it 'prevents duplicate processing with same data' do
      # First call - should process
      expect(service).to receive(:send_text_message).with(/Great choice/).once
      service.send(:handle_guitar_selection, interactive_data)

      # Simulate Redis showing it was processed
      allow(Redis::Alfred).to receive(:get).and_return('1')

      # Second call - should skip
      expect(service).not_to receive(:send_text_message)
      service.send(:handle_guitar_selection, interactive_data)
    end

    it 'creates unique hash based on conversation and selection data' do
      expected_hash = Digest::MD5.hexdigest("#{conversation.id}:Martin DC28E Dreadnought")
      expect(Redis::Alfred).to receive(:setex).with("guitar_selection:#{expected_hash}", '1', 2.minutes.to_i)
      service.send(:handle_guitar_selection, interactive_data)
    end

    it 'logs processing status' do
      # Allow all log messages, but expect at least one matching our pattern
      allow(Rails.logger).to receive(:info).and_call_original
      expect(Rails.logger).to receive(:info).with(/Guitar selection marked as processed/).and_call_original
      service.send(:handle_guitar_selection, interactive_data)
    end
  end

  describe '#handle_form_response' do
    before do
      message.update!(
        content_attributes: {
          'form_response' => {
            'selections' => [
              { 'title' => 'Full Name', 'items' => [{ 'value' => 'John Doe' }] },
              { 'title' => 'Stage Name', 'items' => [{ 'value' => 'Johnny D' }] },
              {
                'title' => 'Street Address',
                'items' => [{ 'value' => '123 Main St' }]
              },
              {
                'title' => 'City',
                'items' => [{ 'value' => 'San Francisco' }]
              }
            ]
          }
        }
      )
      allow(service).to receive(:send_text_message)
      allow(service).to receive(:handle_name_preference_prompt)
    end

    it 'extracts customer name from form data' do
      service.send(:handle_form_response)
      expect(conversation.reload.custom_attributes['customer_name']).to eq('John Doe')
    end

    it 'extracts stage name from form data' do
      service.send(:handle_form_response)
      expect(conversation.reload.custom_attributes['stage_name']).to eq('Johnny D')
    end

    it 'extracts address information' do
      service.send(:handle_form_response)
      address = conversation.reload.custom_attributes['delivery_address']
      expect(address['street']).to eq('123 Main St')
      expect(address['city']).to eq('San Francisco')
    end

    it 'sends thank you message when both names present' do
      expect(service).to receive(:send_text_message).with('Thank you for your submission!')
      service.send(:handle_form_response)
    end

    it 'transitions to name preference state when both names present' do
      service.send(:handle_form_response)
      expect(conversation.reload.custom_attributes['bot_state']).to eq('AHB2')
    end

    it 'stops in demo mode without continuing flow' do
      # Set demo mode state
      conversation.custom_attributes = { 'bot_state' => 'DEMO_MODE' }
      conversation.save!

      # Reinitialize service to pick up the new state
      demo_service = described_class.new(conversation, message)

      allow(demo_service).to receive(:send_text_message)
      expect(demo_service).not_to receive(:handle_name_preference_prompt)
      expect(demo_service).to receive(:send_text_message).with(/startover/)

      demo_service.send(:handle_form_response)
    end
  end

  describe '#extract_address_from_form' do
    let(:form_data) do
      [
        { 'title' => 'Street Address', 'items' => [{ 'value' => '123 Main St' }] },
        { 'title' => 'City', 'items' => [{ 'value' => 'San Francisco' }] },
        { 'title' => 'State', 'items' => [{ 'value' => 'CA' }] },
        { 'title' => 'Zip Code', 'items' => [{ 'value' => '94102' }] }
      ]
    end

    it 'extracts street address' do
      result = service.send(:extract_address_from_form, form_data)
      expect(result[:street]).to eq('123 Main St')
    end

    it 'extracts city' do
      result = service.send(:extract_address_from_form, form_data)
      expect(result[:city]).to eq('San Francisco')
    end

    it 'extracts state' do
      result = service.send(:extract_address_from_form, form_data)
      expect(result[:state]).to eq('CA')
    end

    it 'extracts zip code' do
      result = service.send(:extract_address_from_form, form_data)
      expect(result[:zip]).to eq('94102')
    end

    it 'returns nil for empty form data' do
      result = service.send(:extract_address_from_form, [])
      expect(result).to be_nil
    end

    it 'handles partial address data' do
      partial_data = [
        { 'title' => 'City', 'items' => [{ 'value' => 'San Francisco' }] }
      ]
      result = service.send(:extract_address_from_form, partial_data)
      expect(result[:city]).to eq('San Francisco')
      expect(result[:street]).to be_nil
    end
  end

  describe 'state machine transitions' do
    before do
      allow(service).to receive(:send_text_message)
      allow(service).to receive(:send_quick_reply)
    end

    context 'AHA1 → AHA2 (welcome to region prompt)' do
      it 'sends welcome messages and transitions to region prompt' do
        conversation.custom_attributes = { 'bot_state' => 'AHA1' }
        conversation.save!
        service.send(:handle_welcome)
        expect(conversation.reload.custom_attributes['bot_state']).to eq('AHA2')
      end
    end

    context 'AHA2 → AHA3 (region selection to form prompt)' do
      let(:interactive_data) do
        {
          '$archiver' => 'NSKeyedArchiver',
          '$objects' => ['$null', 'Americas']
        }
      end

      before do
        conversation.custom_attributes = { 'bot_state' => 'AHA2' }
        conversation.save!
        allow(service).to receive(:handle_form_or_name_prompt)
      end

      it 'stores selected region' do
        service.send(:handle_region_selection, interactive_data)
        expect(conversation.reload.custom_attributes['region']).to eq('Americas')
      end

      it 'transitions to AHA3 state' do
        service.send(:handle_region_selection, interactive_data)
        expect(conversation.reload.custom_attributes['bot_state']).to eq('AHA3')
      end
    end

    context 'AHB3 → AHC1 (guitar list prompt to waiting for selection)' do
      before do
        conversation.custom_attributes = { 'bot_state' => 'AHB3' }
        conversation.save!
        allow(service).to receive(:send_guitar_list_picker)
      end

      it 'sends guitar list picker' do
        expect(service).to receive(:send_guitar_list_picker)
        service.send(:handle_guitar_list_prompt)
      end

      it 'transitions to AHC1 state' do
        service.send(:handle_guitar_list_prompt)
        expect(conversation.reload.custom_attributes['bot_state']).to eq('AHC1')
      end
    end
  end

  describe '#handle_keyword_message' do
    context 'with demo keywords' do
      it 'returns true for "guitar" keyword' do
        message.update!(content: 'guitar')
        allow(service).to receive(:handle_list_picker_demo)
        expect(service.send(:handle_keyword_message)).to be true
      end

      it 'returns true for "form" keyword' do
        message.update!(content: 'form')
        allow(service).to receive(:handle_form_demo)
        expect(service.send(:handle_keyword_message)).to be true
      end

      it 'sets DEMO_MODE state after demo keyword' do
        message.update!(content: 'ar')
        allow(service).to receive(:handle_ar_demo)
        service.send(:handle_keyword_message)
        expect(conversation.reload.custom_attributes['bot_state']).to eq('DEMO_MODE')
      end

      it 'sets DEMO_MODE_LARGE_FORM for large form demo' do
        message.update!(content: 'large form')
        allow(service).to receive(:handle_large_form_demo)
        allow(service).to receive(:send_text_message)
        allow(service).to receive(:send_large_content_form)
        # Simulate form support
        contact.additional_attributes = { 'apple_messages_capabilities' => 'FORM' }
        contact.save!
        service.send(:handle_keyword_message)
        expect(conversation.reload.custom_attributes['bot_state']).to eq('DEMO_MODE_LARGE_FORM')
      end
    end

    context 'with flow control keywords' do
      it 'returns true for "menu" keyword' do
        message.update!(content: 'menu')
        allow(service).to receive(:handle_menu)
        expect(service.send(:handle_keyword_message)).to be true
      end

      it 'returns true for "startover" keyword' do
        message.update!(content: 'startover')
        allow(service).to receive(:handle_start_over)
        expect(service.send(:handle_keyword_message)).to be true
      end

      it 'does not set demo mode for flow control keywords' do
        message.update!(content: 'summary')
        allow(service).to receive(:handle_summary)
        conversation.custom_attributes['bot_state']
        service.send(:handle_keyword_message)
        # State should not be DEMO_MODE
        expect(conversation.reload.custom_attributes['bot_state']).not_to eq('DEMO_MODE')
      end
    end

    context 'with no matching keywords' do
      it 'returns false for non-keyword text' do
        message.update!(content: 'hello there')
        expect(service.send(:handle_keyword_message)).to be false
      end

      it 'returns false for blank message' do
        message.update!(content: '')
        expect(service.send(:handle_keyword_message)).to be false
      end
    end
  end

  describe 'error handling' do
    context 'when template is missing' do
      before do
        allow(MessageTemplate).to receive(:find_by).and_return(nil)
        allow(service).to receive(:send_text_message)
      end

      it 'sends fallback message for missing guitar list picker' do
        expect(service).to receive(:send_text_message).with('Guitar selection temporarily unavailable.')
        service.send(:send_guitar_list_picker)
      end

      it 'sends fallback message for missing AR template' do
        expect(service).to receive(:send_text_message).with('[AR File: Template not found]')
        service.send(:send_ar_file)
      end

      it 'falls back to guitar list when form template missing' do
        conversation.custom_attributes = { 'bot_state' => 'AHA3' }
        conversation.save!
        allow(service).to receive(:handle_guitar_list_prompt)
        expect(service).to receive(:handle_guitar_list_prompt)
        service.send(:send_guitar_info_form)
      end
    end

    context 'when Apple Pay fails' do
      before do
        allow(service).to receive(:send_text_message)
        allow(service).to receive(:handle_lesson_introduction)
        # Mock service to return failure
        allow_any_instance_of(AppleMessagesForBusiness::SendApplePayService).to receive(:perform)
          .and_return({ success: false, error: 'Payment gateway unavailable' })
      end

      it 'skips payment gracefully on failure' do
        expect(service).to receive(:send_text_message).with(/skip the payment step/)
        service.send(:handle_apple_pay_prompt)
      end

      it 'continues to lesson introduction after skip' do
        expect(service).to receive(:handle_lesson_introduction)
        service.send(:handle_apple_pay_prompt)
      end

      it 'transitions to AHF2 state' do
        service.send(:handle_apple_pay_prompt)
        expect(conversation.reload.custom_attributes['bot_state']).to eq('AHF2')
      end
    end

    context 'when geocoding fails' do
      before do
        allow(service).to receive(:send_text_message)
        allow(service).to receive(:send_lesson_time_picker)
        # Mock maps service to return nil
        maps_service = instance_double(AppleMessagesForBusiness::AppleMapsService)
        allow(AppleMessagesForBusiness::AppleMapsService).to receive(:new).and_return(maps_service)
        allow(maps_service).to receive(:geocode).and_return(nil)
        message.update!(content: 'invalid-zipcode-xyz')
      end

      it 'sends helpful message for failed geocoding' do
        expect(service).to receive(:send_text_message).with(/couldn't find that location/)
        service.send(:handle_location_response)
      end

      it 'stays in same state to wait for better input' do
        original_state = conversation.custom_attributes['bot_state']
        service.send(:handle_location_response)
        expect(conversation.reload.custom_attributes['bot_state']).to eq(original_state)
      end
    end
  end

  describe 'retry logic' do
    before do
      allow(service).to receive(:send_text_message)
    end

    context 'for guitar list selection catcher' do
      it 'sends first retry message after one attempt' do
        conversation.custom_attributes = { 'retry_count' => 0, 'bot_state' => 'AHC1' }
        conversation.save!
        expect(service).to receive(:send_text_message).with(/Please select a guitar/)
        service.send(:handle_guitar_list_catcher)
      end

      it 'resends list picker after three attempts' do
        conversation.custom_attributes = { 'retry_count' => 2, 'bot_state' => 'AHC1' }
        conversation.save!
        expect(service).to receive(:send_guitar_list_picker)
        service.send(:handle_guitar_list_catcher)
      end

      it 'auto-selects guitar after five attempts' do
        # Set retry_count to 5 so it becomes 6 after increment (6 % 3 = 0 and 6 >= 5)
        conversation.custom_attributes = { 'retry_count' => 5, 'bot_state' => 'AHC1' }
        conversation.save!
        allow(service).to receive(:auto_select_guitar)
        allow(service).to receive(:handle_ar_introduction)
        expect(service).to receive(:auto_select_guitar).with('Martin DC28E Dreadnought')
        service.send(:handle_guitar_list_catcher)
      end
    end

    context 'for time picker catcher' do
      it 'sends escalating messages across retries' do
        conversation.custom_attributes = { 'retry_count' => 0, 'bot_state' => 'AHH1' }
        conversation.save!
        expect(service).to receive(:send_text_message).with(/waiting for you to select a time/)
        service.send(:handle_time_picker_catcher)
      end

      it 'skips to continue prompt after four retries' do
        conversation.custom_attributes = { 'retry_count' => 3, 'bot_state' => 'AHH1' }
        conversation.save!
        allow(service).to receive(:handle_continue_prompt)
        expect(service).to receive(:handle_continue_prompt)
        service.send(:handle_time_picker_catcher)
      end
    end
  end
end
