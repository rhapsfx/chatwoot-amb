# frozen_string_literal: true

class Api::V1::Accounts::AgentBots::VersionsController < Api::V1::Accounts::BaseController
  before_action :set_agent_bot
  before_action :set_version, only: [:show, :activate, :archive, :restore, :compare]
  before_action -> { check_authorization(AgentBot) }

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/versions
  def index
    @versions = @agent_bot.versions.recent.includes(:created_by)
    @versions = @versions.where(is_archived: false) unless params[:include_archived]

    render json: {
      versions: @versions.as_json(
        include: {
          created_by: { only: [:id, :name, :email] }
        },
        methods: [:config_summary]
      )
    }
  end

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/versions/:id
  def show
    render json: {
      version: @version.as_json(
        include: {
          created_by: { only: [:id, :name, :email] }
        }
      )
    }
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/versions
  def create
    @version = @agent_bot.create_version!(
      version_tag: params[:version_tag],
      config: params[:config] || @agent_bot.bot_config,
      description: params[:description],
      notes: params[:notes],
      activate: params[:activate] || false,
      set_default: params[:set_default] || false
    )

    render json: { version: @version }, status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/versions/:id/activate
  def activate
    @version.activate!
    @version.reload

    render json: {
      version: @version,
      message: 'Version activated successfully'
    }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/versions/:id/archive
  def archive
    @version.archive!

    render json: {
      version: @version,
      message: 'Version archived successfully'
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/versions/:id/restore
  def restore
    @version.restore!

    render json: {
      version: @version,
      message: 'Version restored successfully'
    }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/versions/:id/compare/:other_id
  def compare
    other_version = @agent_bot.versions.find(params[:other_id])
    @comparison = @version.compare_with(other_version)

    render json: {
      comparison: @comparison,
      base_version: @version.as_json(only: [:id, :version_tag]),
      other_version: other_version.as_json(only: [:id, :version_tag])
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Version not found' }, status: :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_agent_bot
    @agent_bot = Current.account.agent_bots.find(params[:agent_bot_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Agent bot not found' }, status: :not_found
  end

  def set_version
    @version = @agent_bot.versions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Version not found' }, status: :not_found
  end
end
