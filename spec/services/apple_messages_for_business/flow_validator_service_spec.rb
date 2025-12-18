# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::FlowValidatorService do
  let(:account) { create(:account) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:flow) { create(:bot_flow, agent_bot: agent_bot, flow_data: flow_data) }
  let(:service) { described_class.new(flow) }

  describe '#validate' do
    context 'with a valid simple flow' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'start_1', 'type' => 'start', 'data' => { 'label' => 'Start' } },
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1', 'label' => 'Welcome' } },
            { 'id' => 'end_1', 'type' => 'end', 'data' => { 'label' => 'End' } }
          ],
          'edges' => [
            { 'id' => 'e1', 'source' => 'start_1', 'target' => 'state_1' },
            { 'id' => 'e2', 'source' => 'state_1', 'target' => 'end_1' }
          ]
        }
      end

      it 'returns valid result' do
        result = service.validate
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end

      it 'may have warnings but still be valid' do
        result = service.validate
        expect(result[:valid]).to be true
        expect(result[:warnings]).to be_an(Array)
      end
    end

    context 'with an empty flow' do
      let(:flow_data) { { 'nodes' => [], 'edges' => [] } }

      it 'returns error for empty flow' do
        result = service.validate
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(hash_including(type: 'empty_flow'))
      end
    end

    context 'with missing state nodes' do
      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'intent_1', 'type' => 'intent', 'data' => { 'keywords' => ['hello'] } }
          ],
          'edges' => []
        }
      end

      it 'returns error for missing state nodes' do
        result = service.validate
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(hash_including(type: 'missing_state_nodes'))
      end
    end

    context 'with state node validation' do
      context 'missing state_id' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'label' => 'Welcome' } }
            ],
            'edges' => []
          }
        end

        it 'returns error for missing state_id' do
          result = service.validate
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(
            hash_including(
              node_id: 'state_1',
              type: 'missing_required_field',
              field: 'state_id'
            )
          )
        end
      end

      context 'invalid state_id format' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'invalid', 'label' => 'Welcome' } }
            ],
            'edges' => []
          }
        end

        it 'returns error for invalid state_id format' do
          result = service.validate
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(
            hash_including(
              node_id: 'state_1',
              type: 'invalid_state_id_format',
              field: 'state_id'
            )
          )
        end
      end

      context 'valid state_id formats' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } },
              { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'START1' } },
              { 'id' => 'state_3', 'type' => 'state', 'data' => { 'state_id' => 'MAIN999' } }
            ],
            'edges' => [
              { 'id' => 'e1', 'source' => 'state_1', 'target' => 'state_2' },
              { 'id' => 'e2', 'source' => 'state_2', 'target' => 'state_3' }
            ]
          }
        end

        it 'accepts valid state_id formats' do
          result = service.validate
          state_id_errors = result[:errors].select { |e| e[:type] == 'invalid_state_id_format' }
          expect(state_id_errors).to be_empty
        end
      end

      context 'duplicate state IDs' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } },
              { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
            ],
            'edges' => []
          }
        end

        it 'returns error for duplicate state IDs' do
          result = service.validate
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(
            hash_including(
              type: 'duplicate_state_id',
              state_id: 'AHA1'
            )
          )
        end
      end
    end

    context 'with intent node validation' do
      context 'missing keywords' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'intent_1', 'type' => 'intent', 'data' => { 'label' => 'Greeting' } },
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
            ],
            'edges' => []
          }
        end

        it 'returns error for missing keywords' do
          result = service.validate
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(
            hash_including(
              node_id: 'intent_1',
              type: 'missing_required_field',
              field: 'keywords'
            )
          )
        end
      end

      context 'empty keywords array' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'intent_1', 'type' => 'intent', 'data' => { 'keywords' => [] } },
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
            ],
            'edges' => []
          }
        end

        it 'returns error for empty keywords' do
          result = service.validate
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(
            hash_including(
              node_id: 'intent_1',
              type: 'missing_required_field',
              field: 'keywords'
            )
          )
        end
      end

      context 'invalid keyword types' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'intent_1', 'type' => 'intent', 'data' => { 'keywords' => ['hello', '', nil, 123] } },
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
            ],
            'edges' => []
          }
        end

        it 'returns errors for invalid keywords' do
          result = service.validate
          expect(result[:valid]).to be false
          invalid_keyword_errors = result[:errors].select { |e| e[:type] == 'invalid_keyword' }
          expect(invalid_keyword_errors.length).to be >= 2 # Empty string and non-string
        end
      end
    end

    context 'with template node validation' do
      context 'missing template_name' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'template_1', 'type' => 'template', 'data' => { 'template_type' => 'list_picker' } },
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
            ],
            'edges' => []
          }
        end

        it 'returns error for missing template_name' do
          result = service.validate
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(
            hash_including(
              node_id: 'template_1',
              type: 'missing_required_field',
              field: 'template_name'
            )
          )
        end
      end

      context 'non-existent template' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'template_1', 'type' => 'template', 'data' => { 'template_name' => 'nonexistent_template' } },
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
            ],
            'edges' => []
          }
        end

        it 'returns error for non-existent template' do
          result = service.validate
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(
            hash_including(
              node_id: 'template_1',
              type: 'invalid_template',
              template_name: 'nonexistent_template'
            )
          )
        end
      end

      context 'inactive template' do
        let!(:template) do
          create(:message_template, account: account, name: 'inactive_template', status: 'draft')
        end

        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'template_1', 'type' => 'template', 'data' => { 'template_name' => 'inactive_template' } },
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
            ],
            'edges' => []
          }
        end

        it 'returns warning for inactive template' do
          result = service.validate
          expect(result[:warnings]).to include(
            hash_including(
              node_id: 'template_1',
              type: 'inactive_template',
              template_name: 'inactive_template'
            )
          )
        end
      end

      context 'valid active template' do
        let!(:template) do
          create(:message_template, account: account, name: 'active_template', status: 'active')
        end

        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'template_1', 'type' => 'template', 'data' => { 'template_name' => 'active_template' } },
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
            ],
            'edges' => []
          }
        end

        it 'accepts valid active template' do
          result = service.validate
          template_errors = result[:errors].select { |e| e[:node_id] == 'template_1' && e[:type] == 'invalid_template' }
          expect(template_errors).to be_empty
        end
      end
    end

    context 'with action node validation' do
      context 'missing action_type' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'action_1', 'type' => 'action', 'data' => {} },
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
            ],
            'edges' => []
          }
        end

        it 'returns error for missing action_type' do
          result = service.validate
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(
            hash_including(
              node_id: 'action_1',
              type: 'missing_required_field',
              field: 'action_type'
            )
          )
        end
      end

      context 'invalid action_type' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'action_1', 'type' => 'action', 'data' => { 'action_type' => 'invalid_action' } },
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
            ],
            'edges' => []
          }
        end

        it 'returns error for invalid action_type' do
          result = service.validate
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(
            hash_including(
              node_id: 'action_1',
              type: 'invalid_action_type',
              field: 'action_type'
            )
          )
        end
      end

      context 'invalid parameters type' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'action_1', 'type' => 'action', 'data' => { 'action_type' => 'send_message', 'parameters' => 'not_a_hash' } },
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
            ],
            'edges' => []
          }
        end

        it 'returns error for invalid parameters type' do
          result = service.validate
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(
            hash_including(
              node_id: 'action_1',
              type: 'invalid_parameters',
              field: 'parameters'
            )
          )
        end
      end
    end

    context 'with condition node validation' do
      context 'missing condition_expression' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'condition_1', 'type' => 'condition', 'data' => {} },
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
            ],
            'edges' => []
          }
        end

        it 'returns error for missing condition_expression' do
          result = service.validate
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(
            hash_including(
              node_id: 'condition_1',
              type: 'missing_required_field',
              field: 'condition_expression'
            )
          )
        end
      end

      context 'incorrect number of branches' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'condition_1', 'type' => 'condition', 'data' => { 'condition_expression' => 'user.age > 18' } },
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
            ],
            'edges' => [
              { 'id' => 'e1', 'source' => 'condition_1', 'target' => 'state_1' }
            ]
          }
        end

        it 'returns error for not having exactly 2 branches' do
          result = service.validate
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(
            hash_including(
              node_id: 'condition_1',
              type: 'invalid_condition_branches'
            )
          )
        end
      end

      context 'valid condition with 2 branches' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'condition_1', 'type' => 'condition',
                'data' => { 'condition_expression' => 'user.age > 18', 'true_label' => 'Yes', 'false_label' => 'No' } },
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } },
              { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2' } }
            ],
            'edges' => [
              { 'id' => 'e1', 'source' => 'condition_1', 'target' => 'state_1' },
              { 'id' => 'e2', 'source' => 'condition_1', 'target' => 'state_2' }
            ]
          }
        end

        it 'accepts valid condition with 2 branches' do
          result = service.validate
          condition_errors = result[:errors].select { |e| e[:node_id] == 'condition_1' }
          expect(condition_errors).to be_empty
        end
      end
    end

    context 'with connection validation' do
      context 'orphaned nodes' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } },
              { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2' } }
            ],
            'edges' => []
          }
        end

        it 'returns warning for orphaned nodes' do
          result = service.validate
          expect(result[:warnings]).to include(
            hash_including(
              node_id: 'state_1',
              type: 'orphaned_node'
            )
          )
        end
      end

      context 'duplicate edges' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } },
              { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2' } }
            ],
            'edges' => [
              { 'id' => 'e1', 'source' => 'state_1', 'target' => 'state_2' },
              { 'id' => 'e2', 'source' => 'state_1', 'target' => 'state_2' }
            ]
          }
        end

        it 'returns warning for duplicate edges' do
          result = service.validate
          expect(result[:warnings]).to include(
            hash_including(
              type: 'duplicate_edge',
              source: 'state_1',
              target: 'state_2'
            )
          )
        end
      end

      context 'circular references' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } },
              { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2' } },
              { 'id' => 'state_3', 'type' => 'state', 'data' => { 'state_id' => 'AHA3' } }
            ],
            'edges' => [
              { 'id' => 'e1', 'source' => 'state_1', 'target' => 'state_2' },
              { 'id' => 'e2', 'source' => 'state_2', 'target' => 'state_3' },
              { 'id' => 'e3', 'source' => 'state_3', 'target' => 'state_1' } # Creates a loop
            ]
          }
        end

        it 'returns error for circular reference' do
          result = service.validate
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(
            hash_including(
              type: 'circular_reference'
            )
          )
        end
      end

      context 'start node with no connection' do
        let(:flow_data) do
          {
            'nodes' => [
              { 'id' => 'start_1', 'type' => 'start', 'data' => {} },
              { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1' } }
            ],
            'edges' => []
          }
        end

        it 'returns error for start node with no connection' do
          result = service.validate
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(
            hash_including(
              node_id: 'start_1',
              type: 'start_node_no_connection'
            )
          )
        end
      end
    end

    context 'with complex valid flow' do
      let!(:template) do
        create(:message_template, account: account, name: 'welcome_template', status: 'active')
      end

      let(:flow_data) do
        {
          'nodes' => [
            { 'id' => 'start_1', 'type' => 'start', 'data' => { 'label' => 'Start' } },
            { 'id' => 'state_1', 'type' => 'state', 'data' => { 'state_id' => 'AHA1', 'label' => 'Welcome' } },
            { 'id' => 'intent_1', 'type' => 'intent', 'data' => { 'keywords' => %w[hello hi], 'label' => 'Greeting' } },
            { 'id' => 'template_1', 'type' => 'template', 'data' => { 'template_name' => 'welcome_template', 'template_type' => 'list_picker' } },
            { 'id' => 'action_1', 'type' => 'action', 'data' => { 'action_type' => 'send_message', 'parameters' => { 'text' => 'Hello!' } } },
            { 'id' => 'condition_1', 'type' => 'condition',
              'data' => { 'condition_expression' => 'user.verified == true', 'true_label' => 'Verified', 'false_label' => 'Not Verified' } },
            { 'id' => 'state_2', 'type' => 'state', 'data' => { 'state_id' => 'AHA2', 'label' => 'Verified State' } },
            { 'id' => 'state_3', 'type' => 'state', 'data' => { 'state_id' => 'AHA3', 'label' => 'Unverified State' } },
            { 'id' => 'end_1', 'type' => 'end', 'data' => { 'label' => 'End' } }
          ],
          'edges' => [
            { 'id' => 'e1', 'source' => 'start_1', 'target' => 'state_1' },
            { 'id' => 'e2', 'source' => 'intent_1', 'target' => 'state_1' },
            { 'id' => 'e3', 'source' => 'state_1', 'target' => 'template_1' },
            { 'id' => 'e4', 'source' => 'template_1', 'target' => 'action_1' },
            { 'id' => 'e5', 'source' => 'action_1', 'target' => 'condition_1' },
            { 'id' => 'e6', 'source' => 'condition_1', 'target' => 'state_2' },
            { 'id' => 'e7', 'source' => 'condition_1', 'target' => 'state_3' },
            { 'id' => 'e8', 'source' => 'state_2', 'target' => 'end_1' },
            { 'id' => 'e9', 'source' => 'state_3', 'target' => 'end_1' }
          ]
        }
      end

      it 'validates successfully' do
        result = service.validate
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end

      it 'provides structured validation result' do
        result = service.validate
        expect(result).to have_key(:valid)
        expect(result).to have_key(:errors)
        expect(result).to have_key(:warnings)
      end
    end
  end
end
