module AccessTokenAuthHelper
  BOT_ACCESSIBLE_ENDPOINTS = {
    'api/v1/accounts/conversations' => %w[show toggle_status toggle_typing_status toggle_priority create update custom_attributes],
    'api/v1/accounts/conversations/messages' => ['create'],
    'api/v1/accounts/conversations/assignments' => ['create'],
    'api/v1/accounts/conversations/labels' => %w[index create],
    'api/v1/accounts/bot_templates' => %w[search render_template send_message],
    'api/v1/accounts/templates' => %w[index show]
  }.freeze

  def ensure_access_token
    # Try multiple header formats (some may be stripped by proxies)
    token = request.headers['X-Api-Access-Token'] ||
            request.headers['HTTP_X_API_ACCESS_TOKEN'] ||
            request.headers[:api_access_token] ||
            request.headers[:HTTP_API_ACCESS_TOKEN] ||
            params[:api_access_token]

    Rails.logger.info "[AccessToken] Token found: #{token.present?}"
    Rails.logger.info "[AccessToken] Token value (first 10 chars): #{token&.first(10)}"

    @access_token = AccessToken.find_by(token: token) if token.present?

    Rails.logger.info "[AccessToken] AccessToken record found: #{@access_token.present?}"
    Rails.logger.info "[AccessToken] Owner type: #{@access_token&.owner&.class&.name}"
  end

  def authenticate_access_token!
    ensure_access_token
    render_unauthorized('Invalid Access Token') && return if @access_token.blank?

    # NOTE: This ensures that current_user is set and available for the rest of the controller actions
    @resource = @access_token.owner
    Current.user = @resource if allowed_current_user_type?(@resource)
  end

  def allowed_current_user_type?(resource)
    return true if resource.is_a?(User)
    return true if resource.is_a?(AgentBot)

    false
  end

  def validate_bot_access_token!
    return if Current.user.is_a?(User)
    return if @resource.is_a?(AgentBot) && agent_bot_accessible?

    render_unauthorized('Access to this endpoint is not authorized for bots')
  end

  def agent_bot_accessible?
    BOT_ACCESSIBLE_ENDPOINTS.fetch(params[:controller], []).include?(params[:action])
  end
end
