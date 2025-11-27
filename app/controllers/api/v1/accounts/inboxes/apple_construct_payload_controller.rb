# frozen_string_literal: true

class Api::V1::Accounts::Inboxes::AppleConstructPayloadController < Api::V1::Accounts::BaseController
  before_action :set_inbox
  before_action :validate_apple_messages_inbox

  # POST /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_construct_payload
  # rubocop:disable Metrics/MethodLength
  def create
    url = construct_payload_params[:url]
    store_region = construct_payload_params[:store_region] || 'US'

    service = AppleMessagesForBusiness::ConstructPayloadService.new(
      channel: @inbox.channel,
      url: url,
      store_region: store_region
    )

    result = service.perform

    if result[:success]
      render json: {
        success: true,
        rich_link_data_ref: result[:rich_link_data_ref],
        version: result[:version]
      }, status: :ok
    else
      render json: {
        success: false,
        error: result[:error],
        error_code: result[:error_code]
      }, status: result[:error_code] == 'NO_APP_CLIPS_SUPPORT' ? :bad_request : :unprocessable_entity
    end
  end
  # rubocop:enable Metrics/MethodLength

  private

  def set_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def validate_apple_messages_inbox
    return if @inbox.channel_type == 'Channel::AppleMessagesForBusiness'

    render json: { error: 'Inbox must be an Apple Messages for Business channel' }, status: :unprocessable_entity
  end

  def construct_payload_params
    # API controller auto-normalizes camelCase → snake_case via before_action
    params.require(:construct_payload).permit(:url, :store_region)
  end
end
