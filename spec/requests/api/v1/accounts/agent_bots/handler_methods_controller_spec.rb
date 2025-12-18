# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::Accounts::AgentBots::HandlerMethodsController, type: :request do
  let(:account) { create(:account) }
  let(:agent_bot) { create(:agent_bot, account: account, bot_type: 'AppleMessagesForBusiness::AcousticHouseBotService') }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before do
    create(:account_user, account: account, user: administrator, role: :administrator)
    create(:account_user, account: account, user: agent, role: :agent)
  end

  describe 'GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods' do
    context 'when authenticated as administrator' do
      before do
        sign_in administrator
      end

      it 'returns all handler methods' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods"

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['handler_methods']).to be_an(Array)
        expect(json_response['handler_methods'].length).to be > 0
        expect(json_response['meta']).to include('total', 'services', 'categories', 'handler_types', 'statuses')
      end

      it 'filters by handler_type' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods",
            params: { handler_type: 'state' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['handler_methods']).to be_an(Array)
        expect(json_response['handler_methods'].all? { |h| h['handler_type'] == 'state' }).to be true
      end

      it 'filters by category' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods",
            params: { category: 'onboarding' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['handler_methods'].all? { |h| h['category'] == 'onboarding' }).to be true
      end

      it 'filters by status' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods",
            params: { status: 'stable' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['handler_methods'].all? { |h| h['status'] == 'stable' }).to be true
      end

      it 'searches handler methods' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods",
            params: { search: 'welcome' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['handler_methods']).to be_an(Array)
        # Should find handle_welcome or methods with "welcome" in description
        expect(json_response['handler_methods'].length).to be > 0
      end

      it 'includes expected fields in response' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods"

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        handler = json_response['handler_methods'].first

        expect(handler).to include(
          'method_name',
          'handler_type',
          'display_name',
          'description',
          'category',
          'status',
          'service_name',
          'triggers_count',
          'dependencies_count'
        )
      end
    end

    context 'when authenticated as agent' do
      before do
        sign_in agent
      end

      it 'returns handler methods' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods"

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['handler_methods']).to be_an(Array)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when agent bot does not exist' do
      before do
        sign_in administrator
      end

      it 'returns not found' do
        get "/api/v1/accounts/#{account.id}/agent_bots/999999/handler_methods"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods/:id' do
    context 'when authenticated as administrator' do
      before do
        sign_in administrator
      end

      it 'returns handler method details' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/handle_welcome"

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['handler_method']).to be_a(Hash)
        expect(json_response['handler_method']['method_name']).to eq('handle_welcome')
      end

      it 'includes enriched metadata' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/handle_welcome"

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        handler = json_response['handler_method']

        expect(handler).to include(
          'method_name',
          'handler_type',
          'display_name',
          'description',
          'category',
          'status',
          'service_name',
          'triggers',
          'dependencies'
        )
      end

      it 'includes method signature if available' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/handle_welcome"

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        handler = json_response['handler_method']

        expect(handler).to have_key('signature')
        expect(handler['signature']).to include('arity', 'parameters', 'source_location')
      end

      it 'returns not found for non-existent handler' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/non_existent_handler"

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Handler method not found')
      end
    end

    context 'when authenticated as agent' do
      before do
        sign_in agent
      end

      it 'returns handler method details' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/handle_welcome"

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods/validate' do
    context 'when authenticated as administrator' do
      before do
        sign_in administrator
      end

      it 'validates existing handler method' do
        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/validate",
             params: { method_name: 'handle_welcome' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
        expect(json_response['errors']).to be_empty
      end

      it 'returns validation errors for non-existent handler' do
        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/validate",
             params: { method_name: 'non_existent_handler' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['errors']).not_to be_empty
        expect(json_response['errors'].first['type']).to eq('method_not_found')
      end

      it 'validates handler type if specified' do
        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/validate",
             params: { method_name: 'handle_welcome', handler_type: 'state' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
      end

      it 'returns warning for type mismatch' do
        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/validate",
             params: { method_name: 'handle_welcome', handler_type: 'keyword' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['warnings']).not_to be_empty
        expect(json_response['warnings'].any? { |w| w['type'] == 'type_mismatch' }).to be true
      end

      it 'validates state_id for state handlers' do
        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/validate",
             params: { method_name: 'handle_welcome', handler_type: 'state', state_id: 'AHA1' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
      end

      it 'returns error when method_name is missing' do
        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/validate",
             params: {}

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['errors'].first['type']).to eq('missing_method_name')
      end
    end

    context 'when authenticated as agent' do
      before do
        sign_in agent
      end

      it 'allows validation' do
        post "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/validate",
             params: { method_name: 'handle_welcome' }

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods/search' do
    context 'when authenticated as administrator' do
      before do
        sign_in administrator
      end

      it 'searches handler methods' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/search",
            params: { q: 'welcome' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['results']).to be_an(Array)
        expect(json_response['meta']).to include('query', 'total_results', 'available_results')
      end

      it 'includes match scores and reasons' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/search",
            params: { q: 'welcome' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        result = json_response['results'].first

        expect(result).to include(
          'method_name',
          'display_name',
          'description',
          'match_score',
          'match_reason',
          'category',
          'handler_type',
          'status'
        )
        expect(result['match_score']).to be_a(Float)
      end

      it 'sorts results by match score' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/search",
            params: { q: 'form' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        scores = json_response['results'].map { |r| r['match_score'] }

        expect(scores).to eq(scores.sort.reverse)
      end

      it 'respects limit parameter' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/search",
            params: { q: 'handle', limit: 5 }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['results'].length).to be <= 5
      end

      it 'returns bad request when query is missing' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/search"

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Query parameter is required')
      end
    end

    context 'when authenticated as agent' do
      before do
        sign_in agent
      end

      it 'allows search' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods/search",
            params: { q: 'welcome' }

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'Service class validation' do
    context 'when service class is invalid' do
      before do
        sign_in administrator
      end

      it 'returns error for non-existent service class' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods",
            params: { service_name: 'NonExistentService' }

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid service class')
      end
    end

    context 'when bot has no bot_type' do
      before do
        sign_in administrator
        agent_bot.update!(bot_type: nil)
      end

      it 'returns error' do
        get "/api/v1/accounts/#{account.id}/agent_bots/#{agent_bot.id}/handler_methods"

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Service name not specified')
      end
    end
  end
end
