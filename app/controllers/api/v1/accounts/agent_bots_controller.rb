class Api::V1::Accounts::AgentBotsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :check_authorization
  before_action :agent_bot, except: [:index, :create]

  def index
    @agent_bots = AgentBot.accessible_to(Current.account)
  end

  def show; end

  def create
    parsed_params = permitted_params.except(:avatar_url)

    # Parse bot_config if it's a JSON string
    parsed_params[:bot_config] = JSON.parse(parsed_params[:bot_config]) if parsed_params[:bot_config].is_a?(String)

    # Convert to hash manually to avoid UnfilteredParameters error
    params_hash = {
      name: parsed_params[:name],
      description: parsed_params[:description],
      bot_type: parsed_params[:bot_type],
      outgoing_url: parsed_params[:outgoing_url],
      avatar: parsed_params[:avatar],
      bot_config: parsed_params[:bot_config]
    }.compact

    @agent_bot = Current.account.agent_bots.create!(params_hash)
    process_avatar_from_url
  end

  def update
    parsed_params = permitted_params.except(:avatar_url)

    # Parse bot_config if it's a JSON string
    parsed_params[:bot_config] = JSON.parse(parsed_params[:bot_config]) if parsed_params[:bot_config].is_a?(String)

    # Convert to hash manually to avoid UnfilteredParameters error
    params_hash = {
      name: parsed_params[:name],
      description: parsed_params[:description],
      bot_type: parsed_params[:bot_type],
      outgoing_url: parsed_params[:outgoing_url],
      avatar: parsed_params[:avatar],
      bot_config: parsed_params[:bot_config]
    }.compact

    @agent_bot.update!(params_hash)
    process_avatar_from_url
  end

  def avatar
    @agent_bot.avatar.purge if @agent_bot.avatar.attached?
    @agent_bot
  end

  def destroy
    @agent_bot.destroy!
    head :ok
  end

  def reset_access_token
    @agent_bot.access_token.regenerate_token
    @agent_bot.reload
  end

  def duplicate
    # Create a copy of the bot with "(Copy)" suffix
    duplicate_bot = @agent_bot.dup
    duplicate_bot.name = "#{@agent_bot.name} (Copy)"
    duplicate_bot.bot_config = @agent_bot.bot_config&.deep_dup
    duplicate_bot.save!

    # Copy avatar if exists
    if @agent_bot.avatar.attached?
      duplicate_bot.avatar.attach(
        io: @agent_bot.avatar.download,
        filename: @agent_bot.avatar.filename,
        content_type: @agent_bot.avatar.content_type
      )
    end

    # Copy flows
    @agent_bot.bot_flows.each do |flow|
      duplicate_flow = flow.dup
      duplicate_flow.agent_bot = duplicate_bot
      duplicate_flow.flow_data = flow.flow_data&.deep_dup
      duplicate_flow.metadata = flow.metadata&.deep_dup
      duplicate_flow.save!
    end

    @agent_bot = duplicate_bot
    render :show
  end

  private

  def agent_bot
    @agent_bot = AgentBot.accessible_to(Current.account).find(params[:id]) if params[:action] == 'show'
    @agent_bot ||= Current.account.agent_bots.find(params[:id])
  end

  def permitted_params
    # bot_config can be either a string (JSON) or a hash
    allowed = params.permit(:name, :description, :outgoing_url, :avatar, :avatar_url, :bot_type, :bot_config)

    # If bot_config wasn't permitted as scalar, try as hash
    allowed[:bot_config] ||= params.permit(bot_config: {})[:bot_config] if params[:bot_config].is_a?(Hash)

    allowed
  end

  def process_avatar_from_url
    ::Avatar::AvatarFromUrlJob.perform_later(@agent_bot, params[:avatar_url]) if params[:avatar_url].present?
  end
end
