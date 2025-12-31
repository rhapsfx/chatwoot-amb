# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BotFlow, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:agent_bot) }
    it { is_expected.to belong_to(:parent_flow).optional }
    it { is_expected.to have_many(:child_flows) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:agent_bot_id) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'scopes' do
    let(:account) { create(:account) }
    let(:agent_bot) { create(:agent_bot, account: account) }
    let!(:active_flow) { create(:bot_flow, agent_bot: agent_bot, is_active: true) }
    let!(:inactive_flow) { create(:bot_flow, agent_bot: agent_bot, is_active: false) }
    let!(:published_flow) { create(:bot_flow, agent_bot: agent_bot, is_published: true) }
    let!(:draft_flow) { create(:bot_flow, agent_bot: agent_bot, is_published: false) }

    describe '.active' do
      it 'returns only active flows' do
        expect(BotFlow.active).to include(active_flow)
        expect(BotFlow.active).not_to include(inactive_flow)
      end
    end

    describe '.published' do
      it 'returns only published flows' do
        expect(BotFlow.published).to include(published_flow)
        expect(BotFlow.published).not_to include(draft_flow)
      end
    end

    describe '.drafts' do
      it 'returns only draft flows' do
        expect(BotFlow.drafts).to include(draft_flow)
        expect(BotFlow.drafts).not_to include(published_flow)
      end
    end
  end

  describe 'version management' do
    let(:account) { create(:account) }
    let(:agent_bot) { create(:agent_bot, account: account) }
    let(:flow) do
      create(:bot_flow,
             agent_bot: agent_bot,
             name: 'Test Flow',
             version: 1,
             flow_data: {
               'nodes' => [
                 { 'id' => 'node1', 'type' => 'state', 'data' => { 'label' => 'Start' } }
               ],
               'edges' => []
             })
    end

    describe '#create_version' do
      it 'creates a new version with incremented version number' do
        new_version = flow.create_version(version_tag: 'v2.0', changelog: 'Added new features')

        expect(new_version).to be_persisted
        expect(new_version.version).to eq(2)
        expect(new_version.version_tag).to eq('v2.0')
        expect(new_version.changelog).to eq('Added new features')
        expect(new_version.parent_flow_id).to eq(flow.id)
        expect(new_version.is_published).to be(false)
      end

      it 'duplicates flow data' do
        new_version = flow.create_version(version_tag: 'v2.0')

        expect(new_version.flow_data).to eq(flow.flow_data)
        expect(new_version.name).to eq(flow.name)
      end

      it 'resets published status' do
        published_flow = create(:bot_flow, agent_bot: agent_bot, is_published: true, published_at: Time.current)
        new_version = published_flow.create_version(version_tag: 'v2.0')

        expect(new_version.is_published).to be(false)
        expect(new_version.published_at).to be_nil
      end
    end

    describe '#publish!' do
      let(:other_flow) { create(:bot_flow, agent_bot: agent_bot, is_published: true) }

      before do
        other_flow # Create the other flow
      end

      it 'publishes the flow' do
        flow.publish!

        expect(flow.reload.is_published).to be(true)
        expect(flow.published_at).to be_present
      end

      it 'unpublishes other flows for the same bot' do
        flow.publish!

        expect(other_flow.reload.is_published).to be(false)
      end

      it 'updates agent_bot config with compiled flow' do
        allow_any_instance_of(AppleMessagesForBusiness::FlowCompilerService)
          .to receive(:compile)
          .and_return({ 'test' => 'config' })

        flow.publish!

        expect(agent_bot.reload.bot_config).to eq({ 'test' => 'config' })
      end
    end

    describe '#unpublish!' do
      it 'unpublishes the flow' do
        flow.update!(is_published: true, published_at: Time.current)
        flow.unpublish!

        expect(flow.reload.is_published).to be(false)
      end
    end

    describe '#version_tree' do
      it 'returns the version hierarchy' do
        v2 = flow.create_version(version_tag: 'v2.0')
        v3 = v2.create_version(version_tag: 'v3.0')

        tree = v3.version_tree

        expect(tree.length).to eq(3)
        expect(tree[0].id).to eq(flow.id)
        expect(tree[1].id).to eq(v2.id)
        expect(tree[2].id).to eq(v3.id)
      end

      it 'returns single item for flow without parents' do
        tree = flow.version_tree

        expect(tree.length).to eq(1)
        expect(tree[0].id).to eq(flow.id)
      end
    end

    describe '#compare_with' do
      let(:other_flow) do
        create(:bot_flow,
               agent_bot: agent_bot,
               flow_data: {
                 'nodes' => [
                   { 'id' => 'node1', 'type' => 'state', 'data' => { 'label' => 'Modified' } },
                   { 'id' => 'node2', 'type' => 'state', 'data' => { 'label' => 'New' } }
                 ],
                 'edges' => [
                   { 'id' => 'edge1', 'source' => 'node1', 'target' => 'node2' }
                 ]
               })
      end

      it 'returns diff between flows' do
        diff = flow.compare_with(other_flow)

        expect(diff).to have_key(:nodes)
        expect(diff).to have_key(:edges)
        expect(diff).to have_key(:summary)
      end

      it 'identifies added nodes' do
        diff = flow.compare_with(other_flow)

        expect(diff[:nodes][:added].length).to eq(1)
        expect(diff[:nodes][:added][0]['id']).to eq('node2')
      end

      it 'identifies modified nodes' do
        diff = flow.compare_with(other_flow)

        expect(diff[:nodes][:modified].length).to eq(1)
        expect(diff[:nodes][:modified][0][:id]).to eq('node1')
      end
    end

    describe '#version_display' do
      it 'returns version_tag if present' do
        flow.version_tag = 'stable'
        expect(flow.version_display).to eq('stable')
      end

      it 'returns formatted version number if no tag' do
        flow.version_tag = nil
        flow.version = 5
        expect(flow.version_display).to eq('v5')
      end
    end

    describe '#restore_as_new_version' do
      it 'creates a new version from an old version' do
        v2 = flow.create_version(version_tag: 'v2.0')
        v2.create_version(version_tag: 'v3.0')

        restored = flow.restore_as_new_version

        expect(restored).to be_persisted
        expect(restored.version).to eq(4)
        expect(restored.parent_flow_id).to eq(flow.id)
        expect(restored.is_published).to be(false)
      end

      it 'preserves flow data from restored version' do
        original_data = flow.flow_data
        flow.create_version(version_tag: 'v2.0')

        restored = flow.restore_as_new_version

        expect(restored.flow_data).to eq(original_data)
      end

      it 'sets appropriate version tag and changelog' do
        flow.version_tag = 'v1.0'
        restored = flow.restore_as_new_version

        expect(restored.version_tag).to include('Restored from v1.0')
        expect(restored.changelog).to include('Restored from v1.0')
      end

      it 'works with child versions' do
        v2 = flow.create_version(version_tag: 'v2.0')
        v2.create_version(version_tag: 'v3.0')

        restored = v2.restore_as_new_version

        expect(restored.version).to eq(4)
        expect(restored.parent_flow_id).to eq(flow.id)
        expect(restored.changelog).to include('Restored from v2.0')
      end
    end
  end
end
