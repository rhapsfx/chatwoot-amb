class AppleMessagesForBusiness::OauthCallbackController < ApplicationController
  skip_before_action :set_current_user
  before_action :find_channel, only: :callback

  def callback
    Rails.logger.info "[OAuth Callback] callback method called - code present: #{params[:code].present?}, state: #{params[:state]}"

    return render_error('Missing authorization code') unless params[:code]
    return render_error('Missing state parameter') unless params[:state]

    provider = @oauth_state['provider']
    Rails.logger.info "[OAuth Callback] Extracted provider: #{provider}"
    return render_error('Invalid provider') unless provider

    auth_service = AppleMessagesForBusiness::AuthenticationService.new(@channel)
    Rails.logger.info '[OAuth Callback] Calling process_oauth2_callback'

    result = auth_service.process_oauth2_callback(params[:code], @oauth_state, provider)
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

  private

  def find_channel
    # The OAuth state is single-use: consume it here, so a replayed callback is rejected.
    Rails.logger.info "[OAuth Callback] Starting find_channel - state: #{params[:state]}"
    return render_error('Missing state parameter') unless params[:state]

    @oauth_state = AppleMessagesForBusiness::AuthenticationService.consume_oauth_state(params[:state])
    Rails.logger.info "[OAuth Callback] Consumed state: #{@oauth_state.inspect}"

    # A second callback for the same state lands here. The identity provider does not
    # enforce single-use, so reject it and let the user start the flow again.
    return render_error('Invalid or expired state', status: 'failure') unless @oauth_state

    @destination_id = @oauth_state['destination_id']
    @channel = Channel::AppleMessagesForBusiness.find(@oauth_state['channel_id'])
    Rails.logger.info "[OAuth Callback] Found channel: #{@channel.id}, destination_id: #{@destination_id}"
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[OAuth Callback] Channel not found: #{e.message}"
    render_error('Channel not found')
  rescue StandardError => e
    Rails.logger.error "[OAuth Callback] Unexpected error in find_channel: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render_error('Internal error')
  end

  def render_success(result, provider)
    # Keep the identity pending until the interactive authentication response arrives
    persist_authentication_result(result, provider)

    # Redirect to messages-auth:// URL scheme to close the authentication window
    # Apple will then send a webhook to /message endpoint with authentication response
    redirect_to 'messages-auth://?status=success', allow_other_host: true
  end

  def render_error(error_message, status: 'error')
    # Redirect to messages-auth:// URL scheme with the given status
    redirect_to "messages-auth://?status=#{status}&error=#{CGI.escape(error_message)}", allow_other_host: true
  end

  # Stored against the requestIdentifier, not the destination: the interactive
  # response has to echo it before the account is linked.
  def persist_authentication_result(result, provider)
    AppleMessagesForBusiness::AuthenticationService.new(@channel).store_authentication_result(
      request_identifier: result[:request_identifier],
      destination_id: result[:destination_id] || @destination_id,
      provider: provider,
      user: result[:user],
      authenticated_at: result[:authenticated_at]
    )

    Rails.logger.info "[OAuth Callback] Stored pending identity for request #{result[:request_identifier].inspect}"
  end
end
