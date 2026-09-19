class Api::V1::Accounts::BotFlowsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :agent_bot, except: [:index]
  before_action :bot_flow, only: [:show, :update, :destroy, :publish, :latest_draft]
  before_action :ensure_flow_owned_by_bot, only: [:update, :destroy, :publish]

  def index
    @bot_flows = current_account.bot_flows.order(created_at: :desc).includes(:agent_bot)
  end

  def show; end

  def create
    @bot_flow = current_account.bot_flows.build(bot_flow_params)
    @bot_flow.agent_bot = @agent_bot unless params[:agent_bot_id].present?
    @bot_flow.version = @bot_flow.next_version
    @bot_flow.save!
  end

  def update
    @bot_flow.update!(bot_flow_params)
  end

  def destroy
    @bot_flow.destroy!
    head :ok
  end

  def publish
    @bot_flow.is_published = true
    @bot_flow.published_at = Time.current
    @bot_flow.save!

    # Unpublish any other published versions for the same agent_bot
    @agent_bot.bot_flows.where(id: @bot_flow.id).where.not(is_published: false).update_all(is_published: false, published_at: nil)

    head :ok
  end

  def latest_draft
    @bot_flow = @agent_bot.bot_flows.where(is_published: false).order(version: :desc).first
    render :show
  end

  private

  def agent_bot
    @agent_bot = current_account.agent_bots.find(params[:agent_bot_id])
  end

  def bot_flow
    @bot_flow = current_account.bot_flows.find(params[:id])
  end

  def ensure_flow_owned_by_bot
    return if @bot_flow.agent_bot_id == @agent_bot&.id

    render json: { error: 'Bot flow does not belong to the specified agent bot' }, status: :unprocessable_entity
  end

  def bot_flow_params
    params.permit(:name, :description, :agent_bot_id, :flow_data, :metadata, :is_active, :version, :version_tag, :parent_flow_id, :is_published,
                  :published_at, :changelog)
  end
end
