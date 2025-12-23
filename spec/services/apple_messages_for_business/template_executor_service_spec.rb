# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::TemplateExecutorService do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account, channel: channel) }
  let(:channel) { create(:channel_apple_messages_for_business, account: account) }
  let(:contact) do
    create(:contact, account: account, additional_attributes: {
             'apple_messages_source_id' => 'test_source_id_123'
           })
  end
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message) { create(:message, conversation: conversation, account: account, content: 'Hello bot') }

  before do
    account.administrators << admin unless account.administrators.include?(admin)
  end

  describe '#execute' do
    context 'with send_text_message template' do
      let(:template) do
        create(:bot_action_template,
               account: account,
               name: 'Send Welcome Message',
               template_type: 'send_text_message',
               parameters: {
                 'message' => 'Welcome to our service!'
               })
      end

      let(:service) { described_class.new(template: template, conversation: conversation, message: message) }

      it 'creates and sends a text message' do
        allow_any_instance_of(AppleMessagesForBusiness::SendMessageService)
          .to receive(:perform)
          .and_return({ success: true, message_id: 'msg_123' })

        result = service.execute

        expect(result).to eq(1)
        expect(Message.where(conversation: conversation, message_type: :outgoing).count).to eq(1)

        sent_message = Message.where(conversation: conversation, message_type: :outgoing).last
        expect(sent_message.content).to eq('Welcome to our service!')
        expect(sent_message.content_type).to eq('text')
      end

      it 'applies delay if specified' do
        template.update!(parameters: { 'message' => 'Delayed message', 'delay_seconds' => 2 })

        allow_any_instance_of(AppleMessagesForBusiness::SendMessageService)
          .to receive(:perform)
          .and_return({ success: true, message_id: 'msg_123' })

        start_time = Time.current
        service.execute
        end_time = Time.current

        expect(end_time - start_time).to be >= 2.seconds
      end

      it 'returns 0 if message is missing' do
        template.update!(parameters: { 'message' => '' })

        result = service.execute

        expect(result).to eq(0)
      end

      it 'returns 0 if send fails' do
        allow_any_instance_of(AppleMessagesForBusiness::SendMessageService)
          .to receive(:perform)
          .and_return({ success: false, error: 'Network error' })

        result = service.execute

        expect(result).to eq(0)
      end
    end

    context 'with send_list_picker template' do
      let(:message_template) do
        create(:message_template,
               account: account,
               name: 'Menu List',
               template_type: 'list_picker',
               content: { 'sections' => [{ 'title' => 'Main Menu', 'items' => [] }] })
      end

      let(:template) do
        create(:bot_action_template,
               account: account,
               name: 'Show Menu',
               template_type: 'send_list_picker',
               parameters: {
                 'template_id' => message_template.id
               })
      end

      let(:service) { described_class.new(template: template, conversation: conversation, message: message) }

      before do
        allow_any_instance_of(AppleMessagesForBusiness::TemplateFacade)
          .to receive(:load_data_with_images)
          .and_return({
                        'received_title' => 'Select an option',
                        'sections' => [{ 'title' => 'Options', 'items' => [] }]
                      })
      end

      it 'creates and sends a list picker message' do
        allow_any_instance_of(AppleMessagesForBusiness::SendListPickerService)
          .to receive(:perform)
          .and_return({ success: true, message_id: 'msg_123' })

        result = service.execute

        expect(result).to eq(1)

        sent_message = Message.where(conversation: conversation, message_type: :outgoing).last
        expect(sent_message.content_type).to eq('apple_list_picker')
      end

      it 'returns 0 if template not found' do
        template.update!(parameters: { 'template_id' => 999_999 })

        result = service.execute

        expect(result).to eq(0)
      end
    end

    context 'with send_time_picker template' do
      let(:message_template) do
        create(:message_template,
               account: account,
               name: 'Appointment Picker',
               template_type: 'time_picker',
               content: { 'event' => { 'title' => 'Select time' } })
      end

      let(:template) do
        create(:bot_action_template,
               account: account,
               name: 'Schedule Appointment',
               template_type: 'send_time_picker',
               parameters: {
                 'template_id' => message_template.id,
                 'timezone_offset' => 28_800
               })
      end

      let(:service) { described_class.new(template: template, conversation: conversation, message: message) }

      before do
        allow_any_instance_of(AppleMessagesForBusiness::TemplateFacade)
          .to receive(:load_data_with_images)
          .and_return({
                        'received_title' => 'Select a time',
                        'event' => { 'title' => 'Appointment' }
                      })
      end

      it 'creates and sends a time picker message with timezone' do
        allow_any_instance_of(AppleMessagesForBusiness::SendMessageService)
          .to receive(:perform)
          .and_return({ success: true, message_id: 'msg_123' })

        result = service.execute

        expect(result).to eq(1)

        sent_message = Message.where(conversation: conversation, message_type: :outgoing).last
        expect(sent_message.content_type).to eq('apple_time_picker')
        expect(sent_message.content_attributes['timezone_offset']).to eq(28_800)
      end
    end

    context 'with send_form template' do
      let(:message_template) do
        create(:message_template,
               account: account,
               name: 'Contact Form',
               template_type: 'form',
               content: { 'title' => 'Contact Us', 'pages' => [] })
      end

      let(:template) do
        create(:bot_action_template,
               account: account,
               name: 'Show Contact Form',
               template_type: 'send_form',
               parameters: {
                 'template_id' => message_template.id,
                 'pre_fill_data' => { 'name' => 'John Doe' }
               })
      end

      let(:service) { described_class.new(template: template, conversation: conversation, message: message) }

      before do
        allow_any_instance_of(AppleMessagesForBusiness::TemplateFacade)
          .to receive(:load_data_with_images)
          .and_return({
                        'title' => 'Contact Us',
                        'pages' => []
                      })
      end

      it 'creates and sends a form message with pre-fill data' do
        allow_any_instance_of(AppleMessagesForBusiness::SendMessageService)
          .to receive(:perform)
          .and_return({ success: true, message_id: 'msg_123' })

        result = service.execute

        expect(result).to eq(1)

        sent_message = Message.where(conversation: conversation, message_type: :outgoing).last
        expect(sent_message.content_type).to eq('apple_form')
        expect(sent_message.content_attributes['pre_fill_data']).to eq({ 'name' => 'John Doe' })
      end
    end

    context 'with send_rich_link template' do
      let(:template) do
        create(:bot_action_template,
               account: account,
               name: 'Share Website',
               template_type: 'send_rich_link',
               parameters: {
                 'url' => 'https://example.com',
                 'title' => 'Visit Our Website',
                 'subtitle' => 'Learn more about our services'
               })
      end

      let(:service) { described_class.new(template: template, conversation: conversation, message: message) }

      it 'creates and sends a rich link message' do
        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:perform)
          .and_return({ success: true, message_id: 'msg_123' })

        result = service.execute

        expect(result).to eq(1)

        sent_message = Message.where(conversation: conversation, message_type: :outgoing).last
        expect(sent_message.content_type).to eq('apple_rich_link')
        expect(sent_message.content_attributes['url']).to eq('https://example.com')
      end

      it 'returns 0 if url is missing' do
        template.update!(parameters: { 'title' => 'Test' })

        result = service.execute

        expect(result).to eq(0)
      end
    end

    context 'with send_quick_reply template' do
      let(:template) do
        create(:bot_action_template,
               account: account,
               name: 'Ask Question',
               template_type: 'send_quick_reply',
               parameters: {
                 'message' => 'Do you need help?',
                 'request_id' => 'help_123',
                 'items' => [
                   { 'title' => 'Yes', 'value' => 'yes' },
                   { 'title' => 'No', 'value' => 'no' }
                 ]
               })
      end

      let(:service) { described_class.new(template: template, conversation: conversation, message: message) }

      it 'creates and sends a quick reply message' do
        allow_any_instance_of(AppleMessagesForBusiness::SendQuickReplyService)
          .to receive(:perform)
          .and_return({ success: true, message_id: 'msg_123' })

        result = service.execute

        expect(result).to eq(1)

        sent_message = Message.where(conversation: conversation, message_type: :outgoing).last
        expect(sent_message.content_type).to eq('apple_quick_reply')
        expect(sent_message.content_attributes['items'].length).to eq(2)
      end
    end

    context 'with update_attributes template' do
      let(:template) do
        create(:bot_action_template,
               account: account,
               name: 'Tag User',
               template_type: 'update_attributes',
               parameters: {
                 'attributes' => {
                   'user_type' => 'premium',
                   'onboarding_complete' => true
                 }
               })
      end

      let(:service) { described_class.new(template: template, conversation: conversation, message: message) }

      it 'updates conversation custom attributes' do
        conversation.update!(custom_attributes: { 'existing_key' => 'value' })

        result = service.execute

        expect(result).to eq(0) # No messages sent
        expect(conversation.reload.custom_attributes['user_type']).to eq('premium')
        expect(conversation.reload.custom_attributes['onboarding_complete']).to eq(true)
        expect(conversation.reload.custom_attributes['existing_key']).to eq('value') # Preserved
      end

      it 'returns 0 if attributes are invalid' do
        template.update!(parameters: { 'attributes' => 'not_a_hash' })

        result = service.execute

        expect(result).to eq(0)
      end
    end

    context 'with conditional_branch template' do
      let(:true_action_template) do
        create(:bot_action_template,
               account: account,
               name: 'Premium Response',
               template_type: 'send_text_message',
               parameters: { 'message' => 'Thank you, premium user!' })
      end

      let(:false_action_template) do
        create(:bot_action_template,
               account: account,
               name: 'Standard Response',
               template_type: 'send_text_message',
               parameters: { 'message' => 'Thank you!' })
      end

      let(:template) do
        create(:bot_action_template,
               account: account,
               name: 'Check User Type',
               template_type: 'conditional_branch',
               parameters: {
                 'condition_type' => 'attribute_equals',
                 'condition_value' => {
                   'attribute' => 'user_type',
                   'value' => 'premium'
                 },
                 'true_action' => true_action_template.id,
                 'false_action' => false_action_template.id
               })
      end

      let(:service) { described_class.new(template: template, conversation: conversation, message: message) }

      context 'when condition is true' do
        before do
          conversation.update!(custom_attributes: { 'user_type' => 'premium' })
          allow_any_instance_of(AppleMessagesForBusiness::SendMessageService)
            .to receive(:perform)
            .and_return({ success: true, message_id: 'msg_123' })
        end

        it 'executes the true action' do
          result = service.execute

          expect(result).to eq(1)

          sent_message = Message.where(conversation: conversation, message_type: :outgoing).last
          expect(sent_message.content).to eq('Thank you, premium user!')
        end
      end

      context 'when condition is false' do
        before do
          conversation.update!(custom_attributes: { 'user_type' => 'standard' })
          allow_any_instance_of(AppleMessagesForBusiness::SendMessageService)
            .to receive(:perform)
            .and_return({ success: true, message_id: 'msg_123' })
        end

        it 'executes the false action' do
          result = service.execute

          expect(result).to eq(1)

          sent_message = Message.where(conversation: conversation, message_type: :outgoing).last
          expect(sent_message.content).to eq('Thank you!')
        end
      end

      context 'with message_contains condition' do
        let(:template) do
          create(:bot_action_template,
                 account: account,
                 name: 'Detect Keyword',
                 template_type: 'conditional_branch',
                 parameters: {
                   'condition_type' => 'message_contains',
                   'condition_value' => {
                     'text' => 'help'
                   },
                   'true_action' => true_action_template.id
                 })
        end

        it 'detects keyword in message' do
          message.update!(content: 'I need help with my account')
          allow_any_instance_of(AppleMessagesForBusiness::SendMessageService)
            .to receive(:perform)
            .and_return({ success: true, message_id: 'msg_123' })

          result = service.execute

          expect(result).to eq(1)
        end
      end

      context 'with attribute_greater_than condition' do
        let(:template) do
          create(:bot_action_template,
                 account: account,
                 name: 'Check Cart Value',
                 template_type: 'conditional_branch',
                 parameters: {
                   'condition_type' => 'attribute_greater_than',
                   'condition_value' => {
                     'attribute' => 'cart_total',
                     'value' => 100
                   },
                   'true_action' => true_action_template.id
                 })
        end

        it 'compares numeric attributes' do
          conversation.update!(custom_attributes: { 'cart_total' => 150.50 })
          allow_any_instance_of(AppleMessagesForBusiness::SendMessageService)
            .to receive(:perform)
            .and_return({ success: true, message_id: 'msg_123' })

          result = service.execute

          expect(result).to eq(1)
        end
      end
    end

    context 'with send_apple_pay template' do
      let(:template) do
        create(:bot_action_template,
               account: account,
               name: 'Request Payment',
               template_type: 'send_apple_pay',
               parameters: {
                 'merchant_id' => 'com.example.merchant',
                 'item_name' => 'Premium Subscription',
                 'amount' => '9.99',
                 'currency' => 'USD'
               })
      end

      let(:service) { described_class.new(template: template, conversation: conversation, message: message) }

      it 'sends an Apple Pay request' do
        allow_any_instance_of(AppleMessagesForBusiness::SendApplePayService)
          .to receive(:perform)
          .and_return({ success: true, message_id: 'msg_123' })

        result = service.execute

        expect(result).to eq(1)
      end

      it 'returns 0 if required parameters are missing' do
        template.update!(parameters: { 'merchant_id' => 'test' })

        result = service.execute

        expect(result).to eq(0)
      end
    end

    context 'with api_call template' do
      let(:template) do
        create(:bot_action_template,
               account: account,
               name: 'Fetch User Data',
               template_type: 'api_call',
               parameters: {
                 'url' => 'https://api.example.com/user/123',
                 'method' => 'GET',
                 'headers' => { 'Authorization' => 'Bearer token123' },
                 'store_response_in' => 'api_user_data'
               })
      end

      let(:service) { described_class.new(template: template, conversation: conversation, message: message) }

      it 'makes HTTP request and stores response' do
        stub_request(:get, 'https://api.example.com/user/123')
          .with(headers: { 'Authorization' => 'Bearer token123' })
          .to_return(status: 200, body: { name: 'John Doe', email: 'john@example.com' }.to_json)

        result = service.execute

        expect(result).to eq(0) # No messages sent
        expect(conversation.reload.custom_attributes['api_user_data']).to be_present
        expect(conversation.reload.custom_attributes['api_user_data']['body']['name']).to eq('John Doe')
      end

      it 'handles failed requests gracefully' do
        stub_request(:get, 'https://api.example.com/user/123')
          .to_raise(SocketError.new('Connection refused'))

        result = service.execute

        expect(result).to eq(0)
      end
    end

    context 'with send_imessage_app template' do
      let(:template) do
        create(:bot_action_template,
               account: account,
               name: 'Launch Custom App',
               template_type: 'send_imessage_app',
               parameters: {
                 'app_id' => '12345',
                 'app_name' => 'Store Finder',
                 'launch_url' => 'https://example.com/store-finder'
               })
      end

      let(:service) { described_class.new(template: template, conversation: conversation, message: message) }

      it 'creates and sends a custom iMessage app' do
        allow_any_instance_of(AppleMessagesForBusiness::SendMessageService)
          .to receive(:perform)
          .and_return({ success: true, message_id: 'msg_123' })

        result = service.execute

        expect(result).to eq(1)

        sent_message = Message.where(conversation: conversation, message_type: :outgoing).last
        expect(sent_message.content_type).to eq('apple_custom_app')
        expect(sent_message.content_attributes['app_id']).to eq('12345')
      end
    end

    context 'with send_app_clip template' do
      let(:template) do
        create(:bot_action_template,
               account: account,
               name: 'Launch App Clip',
               template_type: 'send_app_clip',
               parameters: {
                 'app_clip_url' => 'https://example.com/clip',
                 'title' => 'Order Ahead',
                 'subtitle' => 'Skip the line',
                 'action_title' => 'Open'
               })
      end

      let(:service) { described_class.new(template: template, conversation: conversation, message: message) }

      it 'creates and sends an app clip' do
        allow_any_instance_of(AppleMessagesForBusiness::SendRichLinkService)
          .to receive(:perform)
          .and_return({ success: true, message_id: 'msg_123' })

        result = service.execute

        expect(result).to eq(1)

        sent_message = Message.where(conversation: conversation, message_type: :outgoing).last
        expect(sent_message.content_type).to eq('apple_rich_link')
        expect(sent_message.content_attributes['url']).to eq('https://example.com/clip')
      end
    end

    context 'when contact has no apple_messages_source_id' do
      let(:contact_without_source_id) { create(:contact, account: account) }
      let(:conversation_without_source_id) do
        create(:conversation, account: account, inbox: inbox, contact: contact_without_source_id)
      end
      let(:template) do
        create(:bot_action_template,
               account: account,
               template_type: 'send_text_message',
               parameters: { 'message' => 'Test' })
      end

      let(:service) do
        described_class.new(
          template: template,
          conversation: conversation_without_source_id,
          message: message
        )
      end

      it 'returns 0 and logs error' do
        result = service.execute

        expect(result).to eq(0)
      end
    end

    context 'with unknown template type' do
      let(:template) do
        build(:bot_action_template,
              account: account,
              template_type: 'send_text_message',
              parameters: { 'message' => 'Test' })
      end

      let(:service) { described_class.new(template: template, conversation: conversation, message: message) }

      it 'returns 0 for unknown types' do
        allow(template).to receive(:template_type).and_return('unknown_type')

        result = service.execute

        expect(result).to eq(0)
      end
    end

    context 'error handling' do
      let(:template) do
        create(:bot_action_template,
               account: account,
               template_type: 'send_text_message',
               parameters: { 'message' => 'Test' })
      end

      let(:service) { described_class.new(template: template, conversation: conversation, message: message) }

      it 'handles exceptions gracefully' do
        allow_any_instance_of(AppleMessagesForBusiness::SendMessageService)
          .to receive(:perform)
          .and_raise(StandardError.new('Unexpected error'))

        result = service.execute

        expect(result).to eq(0)
      end
    end
  end
end
