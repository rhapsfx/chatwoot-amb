# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::FlowDiffService do
  let(:account) { create(:account) }
  let(:agent_bot) { create(:agent_bot, account: account) }

  let(:flow_a) do
    create(:bot_flow,
           agent_bot: agent_bot,
           flow_data: {
             'nodes' => [
               {
                 'id' => 'node1',
                 'type' => 'state',
                 'position' => { 'x' => 100, 'y' => 100 },
                 'data' => { 'label' => 'Start', 'state_id' => 'START' }
               },
               {
                 'id' => 'node2',
                 'type' => 'template',
                 'position' => { 'x' => 200, 'y' => 200 },
                 'data' => { 'label' => 'Menu', 'template_name' => 'main_menu' }
               }
             ],
             'edges' => [
               {
                 'id' => 'edge1',
                 'source' => 'node1',
                 'target' => 'node2',
                 'sourceHandle' => 'a',
                 'targetHandle' => 'b'
               }
             ]
           })
  end

  let(:flow_b) do
    create(:bot_flow,
           agent_bot: agent_bot,
           flow_data: {
             'nodes' => [
               {
                 'id' => 'node1',
                 'type' => 'state',
                 'position' => { 'x' => 150, 'y' => 150 },
                 'data' => { 'label' => 'Start Modified', 'state_id' => 'START' }
               },
               {
                 'id' => 'node3',
                 'type' => 'intent',
                 'position' => { 'x' => 300, 'y' => 300 },
                 'data' => { 'label' => 'Help Intent', 'keywords' => ['help'] }
               }
             ],
             'edges' => [
               {
                 'id' => 'edge2',
                 'source' => 'node1',
                 'target' => 'node3',
                 'sourceHandle' => 'a',
                 'targetHandle' => 'c'
               }
             ]
           })
  end

  describe '#diff' do
    let(:service) { described_class.new(flow_a, flow_b) }

    it 'returns a complete diff structure' do
      result = service.diff

      expect(result).to have_key(:flows)
      expect(result).to have_key(:nodes)
      expect(result).to have_key(:edges)
      expect(result).to have_key(:summary)
    end

    it 'includes flow summaries' do
      result = service.diff

      expect(result[:flows][:flow_a][:id]).to eq(flow_a.id)
      expect(result[:flows][:flow_b][:id]).to eq(flow_b.id)
      expect(result[:flows][:flow_a][:node_count]).to eq(2)
      expect(result[:flows][:flow_b][:node_count]).to eq(2)
    end

    describe 'node differences' do
      it 'identifies added nodes' do
        result = service.diff

        expect(result[:nodes][:added].length).to eq(1)
        expect(result[:nodes][:added][0]['id']).to eq('node3')
        expect(result[:nodes][:added][0]['type']).to eq('intent')
      end

      it 'identifies removed nodes' do
        result = service.diff

        expect(result[:nodes][:removed].length).to eq(1)
        expect(result[:nodes][:removed][0]['id']).to eq('node2')
        expect(result[:nodes][:removed][0]['type']).to eq('template')
      end

      it 'identifies modified nodes' do
        result = service.diff

        expect(result[:nodes][:modified].length).to eq(1)
        modified = result[:nodes][:modified][0]

        expect(modified[:id]).to eq('node1')
        expect(modified[:type]).to eq('state')
        expect(modified[:label]).to eq('Start Modified')
        expect(modified[:changes]).to have_key('label')
        expect(modified[:changes]['label'][:old]).to eq('Start')
        expect(modified[:changes]['label'][:new]).to eq('Start Modified')
      end

      it 'detects position changes' do
        result = service.diff

        modified = result[:nodes][:modified][0]
        expect(modified[:changes]).to have_key('position')
        expect(modified[:changes]['position'][:old]).to eq({ 'x' => 100, 'y' => 100 })
        expect(modified[:changes]['position'][:new]).to eq({ 'x' => 150, 'y' => 150 })
      end
    end

    describe 'edge differences' do
      it 'identifies added edges' do
        result = service.diff

        expect(result[:edges][:added].length).to eq(1)
        expect(result[:edges][:added][0]['id']).to eq('edge2')
        expect(result[:edges][:added][0]['source']).to eq('node1')
        expect(result[:edges][:added][0]['target']).to eq('node3')
      end

      it 'identifies removed edges' do
        result = service.diff

        expect(result[:edges][:removed].length).to eq(1)
        expect(result[:edges][:removed][0]['id']).to eq('edge1')
        expect(result[:edges][:removed][0]['source']).to eq('node1')
        expect(result[:edges][:removed][0]['target']).to eq('node2')
      end
    end

    describe 'summary' do
      it 'provides accurate counts' do
        result = service.diff
        summary = result[:summary]

        expect(summary[:nodes_added]).to eq(1)
        expect(summary[:nodes_removed]).to eq(1)
        expect(summary[:nodes_modified]).to eq(1)
        expect(summary[:edges_added]).to eq(1)
        expect(summary[:edges_removed]).to eq(1)
        expect(summary[:total_changes]).to eq(5)
      end
    end
  end

  describe 'with identical flows' do
    let(:service) { described_class.new(flow_a, flow_a) }

    it 'returns no differences' do
      result = service.diff
      summary = result[:summary]

      expect(summary[:total_changes]).to eq(0)
      expect(result[:nodes][:added]).to be_empty
      expect(result[:nodes][:removed]).to be_empty
      expect(result[:nodes][:modified]).to be_empty
      expect(result[:edges][:added]).to be_empty
      expect(result[:edges][:removed]).to be_empty
    end
  end
end
