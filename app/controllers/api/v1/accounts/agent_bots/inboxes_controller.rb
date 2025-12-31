# frozen_string_literal: true

class Api::V1::Accounts::AgentBots::InboxesController < Api::V1::Accounts::BaseController
  before_action :set_agent_bot
  before_action :set_bot_inbox, only: [:show, :update, :destroy, :assign_version, :clear_version, :update_config_override]
  before_action -> { check_authorization(AgentBot) }

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes
  def index
    @bot_inboxes = @agent_bot.agent_bot_inboxes
                             .includes(:inbox, :version)
                             .ordered_by_priority

    # Add 'active' field for frontend compatibility
    bot_inboxes_json = @bot_inboxes.as_json(
      include: {
        inbox: { only: [:id, :name, :channel_type] },
        version: { only: [:id, :version_tag] }
      }
    )

    bot_inboxes_json.each do |bi|
      bot_inbox = @bot_inboxes.find { |b| b.id == bi['id'] }
      bi['active'] = bot_inbox.active?
    end

    render json: {
      bot_inboxes: bot_inboxes_json
    }
  end

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes/:id
  def show
    render json: {
      bot_inbox: @bot_inbox.as_json(
        include: {
          inbox: { only: [:id, :name, :channel_type] },
          version: { only: [:id, :version_tag, :config] }
        }
      )
    }
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes
  def create
    @bot_inbox = @agent_bot.agent_bot_inboxes.create!(inbox_params)

    render json: {
      bot_inbox: @bot_inbox,
      message: 'Bot successfully assigned to inbox'
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PATCH /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes/:id
  def update
    Rails.logger.info "[AgentBotInbox] Update called - bot_id: #{params[:agent_bot_id]}, inbox_id: #{params[:id]}"
    Rails.logger.info "[AgentBotInbox] Params: #{params.inspect}"

    # Transform 'active' boolean to 'status' enum if provided
    update_params = inbox_params.to_h.symbolize_keys
    Rails.logger.info "[AgentBotInbox] inbox_params: #{update_params.inspect}"

    if params.key?(:active)
      update_params[:status] = params[:active] ? :active : :inactive
      update_params.delete(:active)
      Rails.logger.info "[AgentBotInbox] Transformed params: #{update_params.inspect}"
    end

    Rails.logger.info "[AgentBotInbox] About to update bot_inbox ID: #{@bot_inbox.id}"
    @bot_inbox.update!(update_params)
    Rails.logger.info '[AgentBotInbox] Update successful'

    # Return bot_inbox with 'active' field for frontend compatibility
    response_data = @bot_inbox.as_json
    response_data['active'] = @bot_inbox.active?

    render json: {
      bot_inbox: response_data,
      message: 'Inbox assignment updated successfully'
    }
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[AgentBotInbox] Update failed: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error "[AgentBotInbox] Unexpected error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end

  # DELETE /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes/:id
  def destroy
    @bot_inbox.destroy!

    render json: { message: 'Bot unassigned from inbox successfully' }, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes/:id/assign_version
  def assign_version
    version_id = params[:version_id]

    # Validate version belongs to the agent bot
    @agent_bot.versions.find(version_id) if version_id.present?

    @bot_inbox.assign_version!(version_id)

    render json: {
      bot_inbox: @bot_inbox.reload,
      message: 'Version assigned to inbox successfully'
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Version not found' }, status: :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes/:id/clear_version
  def clear_version
    @bot_inbox.clear_version!

    render json: {
      bot_inbox: @bot_inbox.reload,
      message: 'Version cleared from inbox successfully'
    }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PATCH /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes/:id/config_override
  def update_config_override
    key_path = params[:key_path]
    value = params[:value]

    if key_path.blank?
      render json: { error: 'key_path is required' }, status: :bad_request
      return
    end

    @bot_inbox.update_config_override!(key_path, value)

    render json: {
      bot_inbox: @bot_inbox.reload,
      message: 'Configuration override updated successfully'
    }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/inboxes/bulk_assign
  def bulk_assign
    inbox_ids = params[:inbox_ids] || []
    priority = params[:priority] || 0
    version_id = params[:version_id]

    validation_error = validate_bulk_assign_params(inbox_ids, version_id)
    return validation_error if validation_error

    result = perform_bulk_assignment(inbox_ids, priority, version_id)

    render json: {
      bot_inboxes: reload_bot_inboxes,
      message: "Successfully assigned bot to #{result[:created]} inbox(es) and updated #{result[:updated]} existing assignment(s)"
    }, status: :ok
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def set_agent_bot
    @agent_bot = Current.account.agent_bots.find(params[:agent_bot_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Agent bot not found' }, status: :not_found
  end

  def set_bot_inbox
    # The :id parameter is actually the inbox_id, not the agent_bot_inbox.id
    @bot_inbox = @agent_bot.agent_bot_inboxes.find_by!(inbox_id: params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Inbox assignment not found' }, status: :not_found
  end

  def inbox_params
    params.permit(:inbox_id, :status, :active, :priority, :version_id, :notes, config_overrides: {})
  end

  def validate_bulk_assign_params(inbox_ids, version_id)
    if inbox_ids.empty?
      render json: { error: 'inbox_ids cannot be empty' }, status: :bad_request
      return true
    end

    # Validate all inboxes belong to the account
    inboxes = Current.account.inboxes.where(id: inbox_ids)
    if inboxes.count != inbox_ids.count
      render json: { error: 'Some inboxes not found or do not belong to this account' }, status: :not_found
      return true
    end

    # Validate version if provided
    @agent_bot.versions.find(version_id) if version_id.present?

    nil
  end

  def perform_bulk_assignment(inbox_ids, priority, version_id)
    created_count = 0
    updated_count = 0

    ActiveRecord::Base.transaction do
      inbox_ids.each do |inbox_id|
        bot_inbox = @agent_bot.agent_bot_inboxes.find_or_initialize_by(inbox_id: inbox_id)

        if bot_inbox.new_record?
          create_bot_inbox(bot_inbox, priority, version_id)
          created_count += 1
        else
          update_bot_inbox(bot_inbox, priority, version_id)
          updated_count += 1
        end
      end
    end

    { created: created_count, updated: updated_count }
  end

  def create_bot_inbox(bot_inbox, priority, version_id)
    bot_inbox.priority = priority
    bot_inbox.version_id = version_id if version_id
    bot_inbox.status = :active
    bot_inbox.save!
  end

  def update_bot_inbox(bot_inbox, priority, version_id)
    bot_inbox.update!(
      priority: priority,
      version_id: version_id,
      status: :active
    )
  end

  def reload_bot_inboxes
    @agent_bot.agent_bot_inboxes.reload
              .includes(:inbox, :version)
              .ordered_by_priority
  end
end
