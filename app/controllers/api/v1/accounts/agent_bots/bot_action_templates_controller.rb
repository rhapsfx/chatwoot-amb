class Api::V1::Accounts::AgentBots::BotActionTemplatesController < Api::V1::Accounts::BaseController
  before_action :set_agent_bot
  before_action :set_template, only: [:show, :update]
  before_action -> { check_authorization(AgentBot) }

  def index
    @templates = Current.account.bot_action_templates.order(created_at: :desc)

    render json: {
      templates: @templates.as_json(
        only: [:id, :name, :template_type, :description, :parameters, :created_at, :updated_at]
      )
    }
  end

  def show
    render json: {
      template: @template.as_json(
        only: [:id, :name, :template_type, :description, :parameters, :created_at, :updated_at]
      )
    }
  end

  def update
    if @template.update(template_params)
      render json: {
        template: @template.as_json(
          only: [:id, :name, :template_type, :description, :parameters, :created_at, :updated_at]
        )
      }
    else
      render json: { errors: @template.errors }, status: :unprocessable_entity
    end
  end

  private

  def set_agent_bot
    @agent_bot = Current.account.agent_bots.find(params[:agent_bot_id])
  end

  def set_template
    @template = Current.account.bot_action_templates.find(params[:id])
  end

  def template_params
    params.require(:template).permit(:name, :template_type, :description, parameters: {})
  end
end
