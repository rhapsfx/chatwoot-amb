# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::FlowExecutorService, type: :service do
  subject(:service) { described_class.new(bot_flow, conversation, message) }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, channel: create(:channel_apple_messages_for_business, account: account)) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'hello') }
  let(:agent_bot) do
    create(:agent_bot,
           account: account,
           bot_type: 'apple_messages_for_business',
           bot_config: {
             conversation_flow: {},
             keyword_mappings: {},
             interactive_handlers: {},
             required_templates: []
           })
  end
  let(:bot_flow) { create(:bot_flow, agent_bot: agent_bot) }

  describe '#execute' do
    context 'with basic flow' do
      let(:flow_data) do
        {
          'nodes' => [
            {
              'id' => 'state-1',
              'type' => 'state',
              'data' => {
                'state_id' => 'AHA1',
                'label' => 'Initial State',
                'is_initial' => true,
                'actions' => []
              }
            }
          ],
          'edges' => []
        }
      end

      before do
        bot_flow.update!(flow_data: flow_data)
      end

      it 'executes successfully' do
        result = service.execute

        expect(result[:success]).to be true
        expect(result[:current_state]).to eq('AHA1')
        expect(result[:nodes_executed]).to include('state-1')
      end
    end
  end

  describe '#execute_handler_method' do
    context 'PRIORITY 1: template reference (template:123)' do
      let(:bot_action_template) do
        create(:bot_action_template,
               account: account,
               name: 'Send Welcome',
               template_type: 'send_text_message',
               parameters: { 'message' => 'Welcome!' })
      end

      it 'executes template by reference' do
        handler_name = "template:#{bot_action_template.id}"

        expect_any_instance_of(AppleMessagesForBusiness::TemplateExecutorService)
          .to receive(:execute).and_return(1)

        messages_sent = service.send(:execute_handler_method, handler_name)

        expect(messages_sent).to eq(1)
      end

      it 'logs error when template not found' do
        handler_name = 'template:99999'

        allow(Rails.logger).to receive(:error)

        messages_sent = service.send(:execute_handler_method, handler_name)

        expect(messages_sent).to eq(0)
        expect(Rails.logger).to have_received(:error).with(/Template not found: 99999/)
      end
    end

    context 'PRIORITY 2: template by name' do
      let!(:bot_action_template) do
        create(:bot_action_template,
               account: account,
               name: 'Send Welcome Message',
               template_type: 'send_text_message',
               parameters: { 'message' => 'Welcome!' })
      end

      it 'executes template by name' do
        expect_any_instance_of(AppleMessagesForBusiness::TemplateExecutorService)
          .to receive(:execute).and_return(1)

        messages_sent = service.send(:execute_handler_method, 'Send Welcome Message')

        expect(messages_sent).to eq(1)
      end
    end

    context 'PRIORITY 3: handler metadata (existing system)' do
      before do
        allow(AppleMessagesForBusiness::AcousticHouseBotService)
          .to receive(:handler_methods_metadata)
          .and_return({
                        test_handler: {
                          dependencies: {
                            templates: ['Test Template']
                          }
                        }
                      })
      end

      it 'executes via handler metadata' do
        allow(service).to receive(:execute_handler_via_metadata).and_return(2)

        messages_sent = service.send(:execute_handler_method, 'test_handler')

        expect(messages_sent).to eq(2)
      end
    end

    context 'PRIORITY 4: direct service call (deprecated)' do
      it 'executes via direct service call' do
        allow(AppleMessagesForBusiness::AcousticHouseBotService)
          .to receive(:handler_methods_metadata)
          .and_return({})

        allow(service).to receive(:execute_handler_via_service).and_return(1)
        allow(Rails.logger).to receive(:warn)

        messages_sent = service.send(:execute_handler_method, 'some_handler')

        expect(messages_sent).to eq(1)
        expect(Rails.logger).to have_received(:warn).with(/Using deprecated handler method/)
      end
    end
  end

  describe '#execute_template' do
    let(:bot_action_template) do
      create(:bot_action_template,
             account: account,
             name: 'Test Template',
             template_type: 'send_text_message',
             parameters: { 'message' => 'Test message' })
    end

    it 'executes template using TemplateExecutorService' do
      expect_any_instance_of(AppleMessagesForBusiness::TemplateExecutorService)
        .to receive(:execute).and_return(1)

      messages_sent = service.send(:execute_template, bot_action_template)

      expect(messages_sent).to eq(1)
    end

    it 'logs template execution' do
      allow_any_instance_of(AppleMessagesForBusiness::TemplateExecutorService)
        .to receive(:execute).and_return(1)

      allow(Rails.logger).to receive(:info)

      service.send(:execute_template, bot_action_template)

      expect(Rails.logger).to have_received(:info).with(/Executing template: Test Template/)
      expect(Rails.logger).to have_received(:info).with(/Template executed: Test Template, messages sent: 1/)
    end
  end

  describe '#execute_action' do
    context 'with execute_template action' do
      let(:bot_action_template) do
        create(:bot_action_template,
               account: account,
               name: 'Action Template',
               template_type: 'send_text_message',
               parameters: { 'message' => 'From action' })
      end

      let(:action) do
        {
          'type' => 'execute_template',
          'template_id' => bot_action_template.id
        }
      end

      it 'executes the template' do
        expect_any_instance_of(AppleMessagesForBusiness::TemplateExecutorService)
          .to receive(:execute).and_return(1)

        messages_sent = service.send(:execute_action, action)

        expect(messages_sent).to eq(1)
      end

      it 'returns 0 when template not found' do
        action['template_id'] = 99_999

        allow(Rails.logger).to receive(:error)

        messages_sent = service.send(:execute_action, action)

        expect(messages_sent).to eq(0)
        expect(Rails.logger).to have_received(:error).with(/Template not found: 99999/)
      end
    end

    context 'with execute_templates action' do
      let(:template1) do
        create(:bot_action_template,
               account: account,
               name: 'Template 1',
               template_type: 'send_text_message',
               parameters: { 'message' => 'Message 1' })
      end

      let(:template2) do
        create(:bot_action_template,
               account: account,
               name: 'Template 2',
               template_type: 'send_text_message',
               parameters: { 'message' => 'Message 2' })
      end

      let(:action) do
        {
          'type' => 'execute_templates',
          'template_ids' => [template1.id, template2.id]
        }
      end

      it 'executes multiple templates in sequence' do
        allow_any_instance_of(AppleMessagesForBusiness::TemplateExecutorService)
          .to receive(:execute).and_return(1)

        allow(service).to receive(:sleep) # Skip delays in tests

        messages_sent = service.send(:execute_action, action)

        expect(messages_sent).to eq(2)
      end

      it 'adds delay between templates' do
        allow_any_instance_of(AppleMessagesForBusiness::TemplateExecutorService)
          .to receive(:execute).and_return(1)

        expect(service).to receive(:sleep).with(1.5).once

        service.send(:execute_action, action)
      end

      it 'skips missing templates and continues' do
        action['template_ids'] = [template1.id, 99_999, template2.id]

        allow_any_instance_of(AppleMessagesForBusiness::TemplateExecutorService)
          .to receive(:execute).and_return(1)

        allow(Rails.logger).to receive(:error)
        allow(service).to receive(:sleep)

        messages_sent = service.send(:execute_action, action)

        expect(messages_sent).to eq(2) # Only template1 and template2
        expect(Rails.logger).to have_received(:error).with(/Template not found: 99999/)
      end
    end

    context 'with execute_handler action' do
      let(:action) do
        {
          'type' => 'execute_handler',
          'handler_name' => 'test_handler'
        }
      end

      it 'calls execute_handler_method' do
        allow(service).to receive(:execute_handler_method).with('test_handler').and_return(1)

        messages_sent = service.send(:execute_action, action)

        expect(messages_sent).to eq(1)
        expect(service).to have_received(:execute_handler_method).with('test_handler')
      end
    end

    context 'with send_template action (legacy)' do
      let(:message_template) do
        create(:message_template,
               account: account,
               name: 'Legacy Template',
               supported_channels: ['apple_messages_for_business'])
      end

      let(:action) do
        {
          'type' => 'send_template',
          'template_name' => 'Legacy Template'
        }
      end

      it 'sends template using existing method' do
        allow(service).to receive(:find_template).with('Legacy Template').and_return(message_template)
        allow(service).to receive(:send_template).with(message_template).and_return(1)
        allow(service).to receive(:sleep)

        messages_sent = service.send(:execute_action, action)

        expect(messages_sent).to eq(1)
      end
    end

    context 'with send_text action' do
      let(:action) do
        {
          'type' => 'send_text',
          'text' => 'Simple text'
        }
      end

      it 'sends text message' do
        allow(service).to receive(:send_text_message).with('Simple text')

        messages_sent = service.send(:execute_action, action)

        expect(messages_sent).to eq(1)
      end
    end

    context 'with unknown action type' do
      let(:action) do
        {
          'type' => 'unknown_action'
        }
      end

      it 'logs warning and returns 0' do
        allow(Rails.logger).to receive(:warn)

        messages_sent = service.send(:execute_action, action)

        expect(messages_sent).to eq(0)
        expect(Rails.logger).to have_received(:warn).with(/Unknown action type: unknown_action/)
      end
    end
  end

  describe '#execute_state_node' do
    context 'with template actions' do
      let(:bot_action_template) do
        create(:bot_action_template,
               account: account,
               name: 'State Template',
               template_type: 'send_text_message',
               parameters: { 'message' => 'From state' })
      end

      let(:state_node) do
        {
          'id' => 'state-1',
          'type' => 'state',
          'data' => {
            'state_id' => 'AHA1',
            'label' => 'State with Template',
            'actions' => [
              {
                'type' => 'execute_template',
                'template_id' => bot_action_template.id
              }
            ]
          }
        }
      end

      let(:flow_data) do
        {
          'nodes' => [state_node],
          'edges' => []
        }
      end

      before do
        bot_flow.update!(flow_data: flow_data)
      end

      it 'executes template actions' do
        expect_any_instance_of(AppleMessagesForBusiness::TemplateExecutorService)
          .to receive(:execute).and_return(1)

        messages_sent = service.send(:execute_state_node, state_node)

        expect(messages_sent).to eq(1)
      end

      it 'logs state execution' do
        allow_any_instance_of(AppleMessagesForBusiness::TemplateExecutorService)
          .to receive(:execute).and_return(1)

        allow(Rails.logger).to receive(:info)

        service.send(:execute_state_node, state_node)

        expect(Rails.logger).to have_received(:info).with(/Executing state node: AHA1/)
      end
    end

    context 'with handler and actions' do
      let(:bot_action_template) do
        create(:bot_action_template,
               account: account,
               name: 'Combined Template',
               template_type: 'send_text_message',
               parameters: { 'message' => 'From action' })
      end

      let(:state_node) do
        {
          'id' => 'state-1',
          'type' => 'state',
          'data' => {
            'state_id' => 'AHA1',
            'handler' => 'template:' + bot_action_template.id.to_s,
            'actions' => [
              {
                'type' => 'send_text',
                'text' => 'Follow-up text'
              }
            ]
          }
        }
      end

      it 'executes both handler and actions' do
        expect_any_instance_of(AppleMessagesForBusiness::TemplateExecutorService)
          .to receive(:execute).and_return(1)

        allow(service).to receive(:send_text_message).and_return(true)
        allow(service).to receive(:sleep)

        messages_sent = service.send(:execute_state_node, state_node)

        expect(messages_sent).to eq(2) # 1 from handler + 1 from action
      end
    end
  end

  describe 'backward compatibility' do
    context 'with existing handler_methods_metadata' do
      let(:message_template) do
        create(:message_template,
               account: account,
               name: 'Legacy Handler Template',
               supported_channels: ['apple_messages_for_business'])
      end

      before do
        allow(AppleMessagesForBusiness::AcousticHouseBotService)
          .to receive(:handler_methods_metadata)
          .and_return({
                        legacy_handler: {
                          dependencies: {
                            templates: ['Legacy Handler Template']
                          }
                        }
                      })

        allow(service).to receive(:find_template).with('Legacy Handler Template').and_return(message_template)
        allow(service).to receive(:send_template).with(message_template).and_return(1)
        allow(service).to receive(:sleep)
      end

      it 'still works with legacy metadata' do
        messages_sent = service.send(:execute_handler_method, 'legacy_handler')

        expect(messages_sent).to eq(1)
      end
    end

    context 'with direct service calls' do
      let(:bot_service) { instance_double(AppleMessagesForBusiness::AcousticHouseBotService) }

      before do
        allow(AppleMessagesForBusiness::AcousticHouseBotService)
          .to receive(:handler_methods_metadata)
          .and_return({})

        allow(AppleMessagesForBusiness::AcousticHouseBotService)
          .to receive(:new)
          .and_return(bot_service)

        allow(bot_service).to receive(:respond_to?).with(:old_handler, true).and_return(true)
        allow(bot_service).to receive(:send).with(:old_handler)
      end

      it 'falls back to direct service call' do
        messages_sent = service.send(:execute_handler_method, 'old_handler')

        expect(messages_sent).to eq(1)
        expect(bot_service).to have_received(:send).with(:old_handler)
      end
    end
  end

  describe 'integration test' do
    context 'with complete flow using templates' do
      let(:welcome_template) do
        create(:bot_action_template,
               account: account,
               name: 'Welcome Message',
               template_type: 'send_text_message',
               parameters: { 'message' => 'Welcome to our service!' })
      end

      let(:menu_template) do
        create(:bot_action_template,
               account: account,
               name: 'Main Menu',
               template_type: 'send_text_message',
               parameters: { 'message' => 'Please select an option' })
      end

      let(:flow_data) do
        {
          'nodes' => [
            {
              'id' => 'state-1',
              'type' => 'state',
              'data' => {
                'state_id' => 'AHA1',
                'label' => 'Welcome State',
                'is_initial' => true,
                'handler' => 'template:' + welcome_template.id.to_s,
                'actions' => [
                  {
                    'type' => 'execute_template',
                    'template_id' => menu_template.id
                  }
                ]
              }
            }
          ],
          'edges' => []
        }
      end

      before do
        bot_flow.update!(flow_data: flow_data)
      end

      it 'executes complete flow with templates' do
        allow_any_instance_of(AppleMessagesForBusiness::TemplateExecutorService)
          .to receive(:execute).and_return(1)

        allow(service).to receive(:sleep)

        result = service.execute

        expect(result[:success]).to be true
        expect(result[:messages_sent]).to eq(2)
        expect(result[:current_state]).to eq('AHA1')
      end
    end
  end
end
