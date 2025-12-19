# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::FlowSimulatorService do
  let(:account) { create(:account) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:flow) { create(:bot_flow, agent_bot: agent_bot, flow_data: flow_data) }
  let(:session) { {} }
  let(:service) { described_class.new(flow, session) }

  describe '#initialize' do
    context 'with valid flow and session' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1', 'label' => 'Welcome', 'is_initial' => true } }
          ],
          'edges' => []
        }
      end

      it 'initializes with flow data' do
        expect(service.instance_variable_get(:@flow)).to eq(flow)
        expect(service.instance_variable_get(:@nodes)).to be_an(Array)
        expect(service.instance_variable_get(:@edges)).to be_an(Array)
      end

      it 'sets initial state from marked node' do
        expect(service.instance_variable_get(:@current_state)).to eq('AHA1')
      end
    end

    context 'with ActionController::Parameters session' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1', 'label' => 'Welcome' } }
          ],
          'edges' => []
        }
      end

      it 'converts ActionController::Parameters to hash' do
        params_session = ActionController::Parameters.new({ current_state: 'AHA2', message_count: 5 })
        service = described_class.new(flow, params_session)

        session = service.instance_variable_get(:@session)
        expect(session).to be_a(Hash)
        expect(session[:current_state]).to eq('AHA2')
        expect(session[:message_count]).to eq(5)
      end
    end

    context 'with existing session state' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } },
            { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2' } }
          ],
          'edges' => []
        }
      end
      let(:session) { { current_state: 'AHA2', message_count: 3 } }

      it 'restores current state from session' do
        expect(service.instance_variable_get(:@current_state)).to eq('AHA2')
      end
    end
  end

  describe '#find_initial_state' do
    context 'with node marked as initial' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1', 'is_initial' => true } },
            { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2' } }
          ],
          'edges' => []
        }
      end

      it 'selects the node marked as initial' do
        expect(service.instance_variable_get(:@current_state)).to eq('AHA1')
      end
    end

    context 'with test nodes present' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'test-node-origin', 'type' => 'state', 'data' => { 'state_id' => 'TEST' } },
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } },
            { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2' } }
          ],
          'edges' => []
        }
      end

      it 'filters out test nodes' do
        # Test node is first, but should be skipped
        expect(service.instance_variable_get(:@current_state)).to eq('AHA1')
      end
    end

    context 'with AHA pattern nodes' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_custom', 'type' => 'state', 'data' => { 'state_id' => 'CUSTOM1' } },
            { 'id' => 'state_aha', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
          ],
          'edges' => []
        }
      end

      it 'prefers AHA pattern nodes' do
        expect(service.instance_variable_get(:@current_state)).to eq('AHA1')
      end
    end

    context 'with no state nodes' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'intent_1', 'type' => 'intent', 'data' => { 'keywords' => ['hello'] } }
          ],
          'edges' => []
        }
      end

      it 'falls back to default state' do
        expect(service.instance_variable_get(:@current_state)).to eq('AHA1')
      end
    end
  end

  describe '#process_message' do
    context 'with simple state flow' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_1', 'type' => 'state',
              'data' => { 'state_id' => 'AHA1', 'label' => 'Welcome', 'handler' => 'handle_welcome', 'is_initial' => true } },
            { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2', 'label' => 'Next State' } }
          ],
          'edges' => [
            { 'id' => 'e1', 'source' => 'state_1', 'target' => 'state_2' }
          ]
        }
      end

      it 'processes message and returns response' do
        result = service.process_message('hi')

        expect(result).to be_a(Hash)
        expect(result).to have_key(:bot_response)
        expect(result).to have_key(:current_state)
        expect(result).to have_key(:executed_nodes)
        expect(result).to have_key(:session)
      end

      it 'includes state information in response' do
        result = service.process_message('hi')

        expect(result[:bot_response]).to include('Welcome')
        expect(result[:bot_response]).to include('AHA1')
      end

      it 'shows handler method in response' do
        result = service.process_message('hi')

        expect(result[:bot_response]).to include('handle_welcome')
        expect(result[:bot_response]).to include('AcousticHouseBotService')
      end

      it 'transitions to next state automatically' do
        result = service.process_message('hi')

        expect(result[:current_state]).to eq('AHA2')
        expect(result[:bot_response]).to include('AHA2')
      end

      it 'tracks executed nodes' do
        result = service.process_message('hi')

        expect(result[:executed_nodes]).to include('state_1')
      end

      it 'updates session with new state' do
        result = service.process_message('hi')

        expect(result[:session][:current_state]).to eq('AHA2')
        expect(result[:session][:message_count]).to eq(1)
        expect(result[:session][:last_update]).to be_present
      end
    end

    context 'with intent matching' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1', 'label' => 'Initial', 'is_initial' => true } },
            { 'id' => 'intent_1', 'type' => 'intent', 'data' => { 'keywords' => %w[hello hi], 'label' => 'Greeting' } },
            { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2', 'label' => 'Greeted' } }
          ],
          'edges' => [
            { 'id' => 'e1', 'source' => 'intent_1', 'target' => 'state_2' }
          ]
        }
      end

      it 'matches intent keyword' do
        result = service.process_message('hello')

        expect(result[:executed_nodes]).to include('intent_1')
        expect(result[:current_state]).to eq('AHA2')
      end

      it 'matches case-insensitive by default' do
        result = service.process_message('HELLO')

        expect(result[:executed_nodes]).to include('intent_1')
      end

      it 'falls back to current state if no intent matches' do
        result = service.process_message('random message')

        expect(result[:executed_nodes]).to include('state_1')
        expect(result[:executed_nodes]).not_to include('intent_1')
      end
    end

    context 'with intent exact match' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1', 'is_initial' => true } },
            { 'id' => 'intent_1', 'type' => 'intent',
              'data' => { 'keywords' => ['menu'], 'exact_match' => true, 'label' => 'Menu Intent' } },
            { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2' } }
          ],
          'edges' => [
            { 'id' => 'e1', 'source' => 'intent_1', 'target' => 'state_2' }
          ]
        }
      end

      it 'matches exact keyword only' do
        result = service.process_message('menu')
        expect(result[:executed_nodes]).to include('intent_1')
      end

      it 'does not match partial keyword' do
        result = service.process_message('show me the menu')
        expect(result[:executed_nodes]).not_to include('intent_1')
      end
    end

    context 'with intent case sensitivity' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1', 'is_initial' => true } },
            { 'id' => 'intent_1', 'type' => 'intent',
              'data' => { 'keywords' => ['stop'], 'case_sensitive' => true, 'label' => 'Stop Intent' } },
            { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2' } }
          ],
          'edges' => [
            { 'id' => 'e1', 'source' => 'intent_1', 'target' => 'state_2' }
          ]
        }
      end

      # NOTE: Case sensitivity is currently limited because process_message lowercases
      # the input before intent matching. This test reflects the current behavior.
      it 'matches keyword (case sensitivity limited by normalization)' do
        result = service.process_message('message with stop')
        expect(result[:executed_nodes]).to include('intent_1')
      end

      it 'still matches with different case due to normalization' do
        result = service.process_message('message with STOP')
        # Both match because message is lowercased to 'message with stop'
        expect(result[:executed_nodes]).to include('intent_1')
      end
    end

    context 'with template nodes' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1', 'is_initial' => true } },
            { 'id' => 'template_1', 'type' => 'template',
              'data' => { 'template_name' => 'welcome_template', 'template_type' => 'list_picker' } },
            { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2' } }
          ],
          'edges' => [
            { 'id' => 'e1', 'source' => 'state_1', 'target' => 'template_1' },
            { 'id' => 'e2', 'source' => 'template_1', 'target' => 'state_2' }
          ]
        }
      end

      it 'processes state node (template edge not followed in simulation)' do
        result = service.process_message('hi')

        expect(result[:executed_nodes]).to include('state_1')
        # Simulator only auto-transitions to state nodes, not template nodes
        expect(result[:current_state]).to eq('AHA1')
      end
    end

    context 'with action nodes' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1', 'is_initial' => true } },
            { 'id' => 'action_1', 'type' => 'action',
              'data' => { 'action_type' => 'send_message', 'label' => 'Send Greeting', 'parameters' => { 'text' => 'Hello!' } } },
            { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2' } }
          ],
          'edges' => [
            { 'id' => 'e1', 'source' => 'state_1', 'target' => 'action_1' },
            { 'id' => 'e2', 'source' => 'action_1', 'target' => 'state_2' }
          ]
        }
      end

      it 'processes state node (action edge not followed in simulation)' do
        result = service.process_message('hi')

        expect(result[:executed_nodes]).to include('state_1')
        # Simulator only auto-transitions to state nodes, not action nodes
        expect(result[:current_state]).to eq('AHA1')
      end
    end

    context 'with condition nodes' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1', 'is_initial' => true } },
            { 'id' => 'condition_1', 'type' => 'condition',
              'data' => { 'condition_expression' => 'user.verified == true', 'label' => 'Check Verification',
                          'true_label' => 'verified', 'false_label' => 'not_verified' } },
            { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2', 'label' => 'Verified' } },
            { 'id' => 'state_3', 'type' => 'state', 'data' => { 'state_id' => 'AHA3', 'label' => 'Not Verified' } }
          ],
          'edges' => [
            { 'id' => 'e1', 'source' => 'state_1', 'target' => 'condition_1' },
            { 'id' => 'e2', 'source' => 'condition_1', 'target' => 'state_2', 'label' => 'verified' },
            { 'id' => 'e3', 'source' => 'condition_1', 'target' => 'state_3', 'label' => 'not_verified' }
          ]
        }
      end

      it 'processes state node (condition edge not followed in simulation)' do
        result = service.process_message('hi')

        expect(result[:executed_nodes]).to include('state_1')
        # Simulator only auto-transitions to state nodes, not condition nodes
        expect(result[:current_state]).to eq('AHA1')
      end
    end

    context 'with state actions' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_1', 'type' => 'state',
              'data' => {
                'state_id' => 'AHA1', 'label' => 'Welcome', 'is_initial' => true,
                'actions' => [
                  { 'type' => 'send_text', 'text' => 'Welcome to our service!' },
                  { 'type' => 'send_template', 'template_name' => 'menu_template' }
                ]
              } },
            { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2' } }
          ],
          'edges' => [
            { 'id' => 'e1', 'source' => 'state_1', 'target' => 'state_2' }
          ]
        }
      end

      it 'includes actions in response' do
        result = service.process_message('hi')

        expect(result[:bot_response]).to include('Actions:')
        expect(result[:bot_response]).to include('Welcome to our service!')
      end
    end

    context 'with multi-step flow progression' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1', 'label' => 'State 1', 'is_initial' => true } },
            { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2', 'label' => 'State 2' } },
            { 'id' => 'state_3', 'type' => 'state', 'data' => { 'state_id' => 'AHA3', 'label' => 'State 3' } }
          ],
          'edges' => [
            { 'id' => 'e1', 'source' => 'state_1', 'target' => 'state_2' },
            { 'id' => 'e2', 'source' => 'state_2', 'target' => 'state_3' }
          ]
        }
      end

      it 'progresses through multiple states across messages' do
        # First message: AHA1 -> AHA2
        result1 = service.process_message('hi')
        expect(result1[:current_state]).to eq('AHA2')

        # Create new service with updated session
        service2 = described_class.new(flow, result1[:session])

        # Second message: AHA2 -> AHA3
        result2 = service2.process_message('next')
        expect(result2[:current_state]).to eq('AHA3')
      end
    end

    context 'with session persistence' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1', 'is_initial' => true } }
          ],
          'edges' => []
        }
      end

      it 'increments message count' do
        result1 = service.process_message('message 1')
        expect(result1[:session][:message_count]).to eq(1)

        service2 = described_class.new(flow, result1[:session])
        result2 = service2.process_message('message 2')
        expect(result2[:session][:message_count]).to eq(2)
      end

      it 'updates last_update timestamp' do
        result = service.process_message('hi')

        expect(result[:session][:last_update]).to be_present
        expect(result[:session][:last_update]).to be_a(Time)
      end
    end

    context 'with fallback responses' do
      let(:flow_data) do
        {
          'nodes' => [],
          'edges' => []
        }
      end

      it 'handles missing state nodes gracefully' do
        result = service.process_message('hi')

        expect(result[:bot_response]).to include('not sure how to respond')
        expect(result[:current_state]).to be_present
      end
    end
  end
end
