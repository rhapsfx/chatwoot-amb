class AppleMessagesForBusiness::OauthCallbackController < ApplicationController
  skip_before_action :set_current_user
  before_action :find_channel

  def callback
    Rails.logger.info "[OAuth Callback] callback method called - code present: #{params[:code].present?}, state: #{params[:state]}"

    return render_error('Missing authorization code') unless params[:code]
    return render_error('Missing state parameter') unless params[:state]

    provider = extract_provider_from_state(params[:state])
    Rails.logger.info "[OAuth Callback] Extracted provider: #{provider}"
    return render_error('Invalid provider') unless provider

    auth_service = AppleMessagesForBusiness::AuthenticationService.new(@channel)
    Rails.logger.info '[OAuth Callback] Calling process_oauth2_callback'

    result = auth_service.process_oauth2_callback(params[:code], params[:state], provider)
    Rails.logger.info "[OAuth Callback] process_oauth2_callback result: #{result.inspect}"

    if result[:error]
      Rails.logger.error "[OAuth Callback] Authentication error: #{result[:error]}"
      render_error(result[:error])
    else
      Rails.logger.info '[OAuth Callback] Authentication successful, rendering success page'
      render_success(result, provider)
    end
  rescue StandardError => e
    Rails.logger.error "[OAuth Callback] Unexpected error in callback: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render_error("Authentication failed: #{e.message}")
  end

  def landing_page
    return render_error('Missing state parameter') unless params[:state]

    provider = extract_provider_from_state(params[:state])
    return render_error('Invalid provider') unless provider

    landing_service = AppleMessagesForBusiness::LandingPageService.new(@channel)
    page_data = landing_service.generate_landing_page(params[:state], provider)

    render html: page_data[:html].html_safe, content_type: page_data[:content_type], status: page_data[:status]
  end

  private

  def find_channel
    # Get channel_id and destination_id from Redis state (stored during OAuth initiation)
    Rails.logger.info "[OAuth Callback] Starting find_channel - state: #{params[:state]}"
    return render_error('Missing state parameter') unless params[:state]

    state_key = "oauth_state:#{params[:state]}"
    state_data = Redis::Alfred.get(state_key)
    Rails.logger.info "[OAuth Callback] State data from Redis: #{state_data.inspect}"
    return render_error('Invalid or expired state') unless state_data

    begin
      state_json = JSON.parse(state_data)
      channel_id = state_json['channel_id']
      @destination_id = state_json['destination_id']
      Rails.logger.info "[OAuth Callback] Parsed state - channel_id: #{channel_id}, destination_id: #{@destination_id}"

      @channel = Channel::AppleMessagesForBusiness.find(channel_id)
      Rails.logger.info "[OAuth Callback] Found channel: #{@channel.id}"
    rescue JSON::ParserError => e
      Rails.logger.error "[OAuth Callback] JSON parse error: #{e.message}"
      render_error('Invalid state format')
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "[OAuth Callback] Channel not found: #{e.message}"
      render_error('Channel not found')
    rescue StandardError => e
      Rails.logger.error "[OAuth Callback] Unexpected error in find_channel: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_error('Internal error')
    end
  end

  def extract_provider_from_state(state)
    # Extract provider from Redis state
    state_key = "oauth_state:#{state}"
    state_data = Redis::Alfred.get(state_key)
    return nil unless state_data

    begin
      state_json = JSON.parse(state_data)
      state_json['provider']
    rescue JSON::ParserError
      nil
    end
  end

  def render_success(result, provider)
    # Store the successful authentication for processing when we receive the webhook
    store_authentication_result(result, provider)

    # Redirect to messages-auth:// URL scheme to close the authentication window
    # Apple will then send a webhook to /message endpoint with authentication response
    redirect_to 'messages-auth://?status=success', allow_other_host: true
  end

  def render_error(error_message)
    # Redirect to messages-auth:// URL scheme with error status
    redirect_to "messages-auth://?status=error&error=#{CGI.escape(error_message)}", allow_other_host: true
  end

  def store_authentication_result(result, provider)
    # Store the authentication result temporarily for processing when webhook arrives
    auth_key = "apple_auth_result:#{@channel.id}:#{@destination_id}"

    Redis::Alfred.setex(
      auth_key,
      {
        user: result[:user],
        provider: provider,
        authenticated_at: result[:authenticated_at],
        channel_id: @channel.id,
        destination_id: @destination_id
      }.to_json,
      3600 # 1 hour
    )

    Rails.logger.info "[OAuth Callback] Stored authentication result in Redis with key: #{auth_key}"
  end
end
