# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::AgentBots::FlowsController', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:agent_bot) { create(:agent_bot, account: account) }

  before do
    sign_in(user)
  end

  describe 'Version Management' do
    let(:flow) do
      create(:bot_flow,
             agent_bot: agent_bot,
             name: 'Test Flow',
             version: 1,
             version_tag: 'v1.0',
             flow_data: {
               'nodes' => [
                 { 'id' => 'node1', 'type' => 'state', 'data' => { 'label' => 'Start' } }
               ],
               'edges' => []
             })
    end

    describe 'POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/create_version' do
      it 'creates a new version with provided tag' do
        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{flow.id}/create_version",
             params: { version_tag: 'v2.0', changelog: 'Added new features' },
             as: :json

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body

        expect(json_response['flow']['version']).to eq(2)
        expect(json_response['flow']['version_tag']).to eq('v2.0')
        expect(json_response['flow']['changelog']).to eq('Added new features')
        expect(json_response['flow']['parent_flow_id']).to eq(flow.id)
        expect(json_response['flow']['is_published']).to be(false)
      end

      it 'auto-generates version tag if not provided' do
        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{flow.id}/create_version",
             as: :json

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body

        expect(json_response['flow']['version_tag']).to eq('v2.0')
      end

      it 'returns error for invalid version tag (duplicate)' do
        create(:bot_flow, agent_bot: agent_bot, version_tag: 'duplicate')

        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{flow.id}/create_version",
             params: { version_tag: 'duplicate' },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe 'POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/publish' do
      it 'publishes the flow' do
        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{flow.id}/publish",
             as: :json

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response['flow']['is_published']).to be(true)
        expect(json_response['flow']['published_at']).to be_present
        expect(json_response['message']).to include('published successfully')
      end

      it 'unpublishes other flows for the same bot' do
        other_flow = create(:bot_flow, agent_bot: agent_bot, is_published: true)

        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{flow.id}/publish",
             as: :json

        expect(response).to have_http_status(:success)
        expect(other_flow.reload.is_published).to be(false)
      end

      it 'updates agent bot config with compiled flow' do
        allow_any_instance_of(AppleMessagesForBusiness::FlowCompilerService)
          .to receive(:compile)
          .and_return({ 'conversation_flow' => { 'states' => {} } })

        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{flow.id}/publish",
             as: :json

        expect(agent_bot.reload.bot_config).to have_key('conversation_flow')
      end
    end

    describe 'POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/unpublish' do
      before do
        flow.update!(is_published: true, published_at: Time.current)
      end

      it 'unpublishes the flow' do
        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{flow.id}/unpublish",
             as: :json

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response['flow']['is_published']).to be(false)
        expect(json_response['message']).to include('unpublished successfully')
      end
    end

    describe 'GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/versions' do
      let!(:v2) { flow.create_version(version_tag: 'v2.0', changelog: 'Version 2') }
      let!(:v3) { v2.create_version(version_tag: 'v3.0', changelog: 'Version 3') }

      it 'returns all versions for the flow family' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{flow.id}/versions",
            as: :json

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response['versions'].length).to eq(3)
        version_tags = json_response['versions'].map { |v| v['version_tag'] }
        expect(version_tags).to contain_exactly('v1.0', 'v2.0', 'v3.0')
      end

      it 'orders versions by version number descending' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{v2.id}/versions",
            as: :json

        json_response = response.parsed_body
        versions = json_response['versions'].map { |v| v['version'] }

        expect(versions).to eq([3, 2, 1])
      end
    end

    describe 'GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/version_tree' do
      let!(:v2) { flow.create_version(version_tag: 'v2.0') }
      let!(:v3) { v2.create_version(version_tag: 'v3.0') }

      it 'returns the version tree from root to current' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{v3.id}/version_tree",
            as: :json

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response['tree'].length).to eq(3)
        expect(json_response['tree'][0]['id']).to eq(flow.id)
        expect(json_response['tree'][1]['id']).to eq(v2.id)
        expect(json_response['tree'][2]['id']).to eq(v3.id)
      end
    end

    describe 'GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/compare/:other_id' do
      let(:other_flow) do
        create(:bot_flow,
               agent_bot: agent_bot,
               flow_data: {
                 'nodes' => [
                   { 'id' => 'node1', 'type' => 'state', 'data' => { 'label' => 'Modified' } },
                   { 'id' => 'node2', 'type' => 'template', 'data' => { 'label' => 'New' } }
                 ],
                 'edges' => [
                   { 'id' => 'edge1', 'source' => 'node1', 'target' => 'node2' }
                 ]
               })
      end

      it 'returns diff between two flows' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{flow.id}/compare/#{other_flow.id}",
            as: :json

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response['diff']).to have_key('nodes')
        expect(json_response['diff']).to have_key('edges')
        expect(json_response['diff']).to have_key('summary')
      end

      it 'identifies added and modified nodes' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{flow.id}/compare/#{other_flow.id}",
            as: :json

        json_response = response.parsed_body
        summary = json_response['diff']['summary']

        expect(summary['nodes_added']).to eq(1)
        expect(summary['nodes_modified']).to eq(1)
        expect(summary['edges_added']).to eq(1)
      end

      it 'returns error when comparison flow not found' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{flow.id}/compare/999999",
            as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/restore' do
      let!(:v2) { flow.create_version(version_tag: 'v2.0', changelog: 'Version 2') }
      let!(:v3) { v2.create_version(version_tag: 'v3.0', changelog: 'Version 3') }

      it 'restores an old version as a new version' do
        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{flow.id}/restore",
             as: :json

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body

        expect(json_response['flow']['version']).to eq(4)
        expect(json_response['flow']['version_tag']).to include('Restored from')
        expect(json_response['flow']['changelog']).to include('Restored from')
        expect(json_response['flow']['parent_flow_id']).to eq(flow.id)
        expect(json_response['flow']['is_published']).to be(false)
        expect(json_response['message']).to include('Flow restored')
      end

      it 'restores from a child version to latest version number' do
        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{v2.id}/restore",
             as: :json

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body

        expect(json_response['flow']['version']).to eq(4)
        expect(json_response['flow']['changelog']).to include('Restored from v2.0')
      end

      it 'preserves flow data from restored version' do
        original_flow_data = flow.flow_data

        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{flow.id}/restore",
             as: :json

        json_response = response.parsed_body
        restored_flow = BotFlow.find(json_response['flow']['id'])

        expect(restored_flow.flow_data).to eq(original_flow_data)
      end
    end
  end

  describe 'Authorization' do
    let(:flow) { create(:bot_flow, agent_bot: agent_bot) }
    let(:other_account) { create(:account) }
    let(:other_user) { create(:user, account: other_account, role: :administrator) }

    before do
      sign_out(user)
      sign_in(other_user)
    end

    it 'prevents access to flows from different account' do
      post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/flows/#{flow.id}/publish",
           as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
