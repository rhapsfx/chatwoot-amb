# frozen_string_literal: true

class Api::V1::Accounts::AgentBots::FlowsController < Api::V1::Accounts::BaseController
  before_action :set_agent_bot
  before_action :set_flow, only: [:show, :update, :destroy, :compile, :validate, :preview, :update_node,
                                  :create_version, :publish, :unpublish, :versions, :version_tree, :compare, :restore, :simulate]
  before_action -> { check_authorization(AgentBot) }

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows
  def index
    @flows = @agent_bot.bot_flows.order(created_at: :desc)

    render json: {
      flows: @flows.as_json(
        only: [:id, :name, :description, :is_active, :version, :created_at, :updated_at],
        methods: [:node_count, :edge_count]
      )
    }
  end

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/templates
  def templates
    begin
      # Find all flows marked as templates for this account
      # Templates are stored in a special "Flow Templates Bot" agent bot
      template_bots = Current.account.agent_bots.where("bot_config ->> 'is_template_bot' = ?", 'true')

      if template_bots.empty?
        # No template bots found, return empty array
        return render json: { templates: [] }
      end

      @template_flows = BotFlow.where(agent_bot: template_bots)
                               .where("metadata ->> 'is_template' = ?", 'true')
                               .order(created_at: :desc)

      render json: {
        templates: @template_flows.map do |flow|
          {
            id: flow.id,
            name: flow.name,
            description: flow.description,
            metadata: flow.metadata,
            flow_data: flow.flow_data,
            created_at: flow.created_at,
            updated_at: flow.updated_at,
            node_count: flow.flow_data&.dig('nodes')&.size || 0,
            edge_count: flow.flow_data&.dig('edges')&.size || 0
          }
        end
      }
    rescue StandardError => e
      Rails.logger.error "[FlowTemplates] Error loading templates: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        error: e.message,
        message: 'Failed to load flow templates'
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id
  def show
    render json: {
      flow: @flow.as_json(
        only: [:id, :name, :description, :flow_data, :metadata, :is_active, :version, :created_at, :updated_at],
        methods: [:node_count, :edge_count]
      )
    }
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows
  def create
    @flow = @agent_bot.bot_flows.create!(flow_params)

    render json: {
      flow: @flow.as_json(
        only: [:id, :name, :description, :flow_data, :metadata, :is_active, :version, :created_at, :updated_at]
      )
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PATCH /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id
  def update
    @flow.update!(flow_params)

    render json: {
      flow: @flow.as_json(
        only: [:id, :name, :description, :flow_data, :metadata, :is_active, :version, :created_at, :updated_at]
      ),
      message: 'Flow updated successfully'
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # DELETE /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id
  def destroy
    @flow.destroy!
    head :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/import_from_bot_config
  def import_from_bot_config
    import_service = AppleMessagesForBusiness::FlowImportService.new(@agent_bot.bot_config)
    flow_data = import_service.import_to_flow_data

    # Create or update a flow named "Imported from bot_config"
    @flow = @agent_bot.bot_flows.find_or_initialize_by(name: 'Imported from bot_config')
    @flow.update!(
      description: 'Auto-imported from bot configuration JSON',
      flow_data: flow_data,
      is_active: true,
      version: (@flow.version || 0) + 1
    )

    render json: {
      flow: @flow.as_json(
        only: [:id, :name, :description, :flow_data, :metadata, :is_active, :version, :created_at, :updated_at]
      ),
      message: 'Bot config imported successfully'
    }
  rescue StandardError => e
    render json: {
      error: e.message,
      message: 'Failed to import bot config'
    }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/compile
  def compile
    compiler = AppleMessagesForBusiness::FlowCompilerService.new(@flow)
    compiled_config = compiler.compile

    # Update the bot's bot_config with the compiled result
    @agent_bot.update!(bot_config: compiled_config)

    render json: {
      bot_config: compiled_config,
      message: 'Flow compiled and bot config updated successfully'
    }
  rescue StandardError => e
    render json: {
      error: e.message,
      message: 'Failed to compile flow'
    }, status: :unprocessable_entity
  end

  # PATCH /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/nodes/:node_id
  def update_node
    node_id = params[:node_id]
    node_data = node_params

    flow_data = @flow.flow_data || { 'nodes' => [], 'edges' => [] }
    nodes = flow_data['nodes'] || []

    # Find the node by id
    node_index = nodes.find_index { |n| n['id'] == node_id }

    if node_index.nil?
      return render json: {
        error: "Node with id '#{node_id}' not found"
      }, status: :not_found
    end

    # Update the node data
    nodes[node_index]['data'] = node_data
    flow_data['nodes'] = nodes

    # Save the updated flow
    @flow.update!(flow_data: flow_data)

    render json: {
      node: nodes[node_index],
      message: 'Node updated successfully'
    }
  rescue StandardError => e
    render json: {
      error: e.message,
      message: 'Failed to update node'
    }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/validate
  def validate
    validator = AppleMessagesForBusiness::FlowValidatorService.new(@flow)
    validation_result = validator.validate

    render json: {
      valid: validation_result[:valid],
      errors: validation_result[:errors] || [],
      warnings: validation_result[:warnings] || [],
      message: validation_result[:valid] ? 'Flow is valid' : 'Flow has validation errors'
    }
  rescue StandardError => e
    render json: {
      error: e.message,
      message: 'Flow validation failed'
    }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/preview
  def preview
    # Placeholder for flow preview service
    # Will be implemented in Phase 3
    preview_service = AppleMessagesForBusiness::FlowPreviewService.new(@flow)
    preview_data = preview_service.generate

    render json: {
      preview: preview_data,
      message: 'Flow preview generated successfully'
    }
  rescue StandardError => e
    render json: {
      error: e.message,
      message: 'Flow preview is not yet implemented'
    }, status: :not_implemented
  end

  # === Version Management Actions ===

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/create_version
  def create_version
    version_tag = params[:version_tag] || "v#{@flow.version + 1}.0"
    changelog = params[:changelog]

    new_version = @flow.create_version(
      version_tag: version_tag,
      changelog: changelog
    )

    render json: {
      flow: new_version.as_json(
        only: [:id, :name, :description, :version, :version_tag, :changelog,
               :is_published, :published_at, :parent_flow_id, :created_at, :updated_at],
        methods: [:node_count, :edge_count, :version_display]
      ),
      message: "Version #{new_version.version_display} created successfully"
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/publish
  def publish
    @flow.publish!

    render json: {
      flow: @flow.as_json(
        only: [:id, :name, :description, :version, :version_tag,
               :is_published, :published_at, :created_at, :updated_at],
        methods: [:node_count, :edge_count, :version_display]
      ),
      message: "Flow #{@flow.version_display} published successfully"
    }
  rescue StandardError => e
    render json: {
      error: e.message,
      message: 'Failed to publish flow'
    }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/unpublish
  def unpublish
    @flow.unpublish!

    render json: {
      flow: @flow.as_json(
        only: [:id, :name, :description, :version, :version_tag,
               :is_published, :published_at, :created_at, :updated_at],
        methods: [:node_count, :edge_count, :version_display]
      ),
      message: "Flow #{@flow.version_display} unpublished successfully"
    }
  rescue StandardError => e
    render json: {
      error: e.message,
      message: 'Failed to unpublish flow'
    }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/versions
  def versions
    # Get all versions related to this flow (siblings and children)
    all_versions = if @flow.parent_flow_id.present?
                     # This is a child version, get all siblings
                     @agent_bot.bot_flows.where(parent_flow_id: @flow.parent_flow_id).or(
                       @agent_bot.bot_flows.where(id: @flow.parent_flow_id)
                     ).ordered_by_version
                   else
                     # This is a root flow, get it and its children
                     @agent_bot.bot_flows.where(id: @flow.id).or(
                       @agent_bot.bot_flows.where(parent_flow_id: @flow.id)
                     ).ordered_by_version
                   end

    render json: {
      versions: all_versions.as_json(
        only: [:id, :name, :description, :version, :version_tag, :changelog,
               :is_published, :published_at, :parent_flow_id, :created_at, :updated_at],
        methods: [:node_count, :edge_count, :version_display]
      )
    }
  end

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/version_tree
  def version_tree
    tree = @flow.version_tree

    render json: {
      tree: tree.as_json(
        only: [:id, :name, :description, :version, :version_tag, :changelog,
               :is_published, :published_at, :parent_flow_id, :created_at, :updated_at],
        methods: [:node_count, :edge_count, :version_display]
      )
    }
  end

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/compare/:other_id
  def compare
    other_flow = @agent_bot.bot_flows.find(params[:other_id])
    diff = @flow.compare_with(other_flow)

    render json: {
      diff: diff,
      message: 'Flow comparison completed successfully'
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Comparison flow not found' }, status: :not_found
  rescue StandardError => e
    render json: {
      error: e.message,
      message: 'Failed to compare flows'
    }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/restore
  def restore
    restored_flow = @flow.restore_as_new_version

    render json: {
      flow: restored_flow.as_json(
        only: [:id, :name, :description, :version, :version_tag, :changelog,
               :is_published, :published_at, :parent_flow_id, :created_at, :updated_at],
        methods: [:node_count, :edge_count, :version_display]
      ),
      message: "Flow restored as #{restored_flow.version_display}"
    }, status: :created
  rescue StandardError => e
    render json: {
      error: e.message,
      message: 'Failed to restore flow'
    }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/simulate
  def simulate
    # Rails wraps the request body in a 'flow' parameter
    # Check both root level and nested level for backwards compatibility
    user_message = params[:message] || params.dig(:flow, :message)
    session_data = params[:session] || params.dig(:flow, :session) || {}

    Rails.logger.info "[FlowSimulator] user_message: #{user_message.inspect}, session_data: #{session_data.inspect}"

    simulator = AppleMessagesForBusiness::FlowSimulatorService.new(@flow, session_data)
    result = simulator.process_message(user_message)

    Rails.logger.info "[FlowSimulator] result: #{result.inspect}"

    render json: {
      bot_response: result[:bot_response],
      current_state: result[:current_state],
      executed_nodes: result[:executed_nodes],
      template_previews: result[:template_previews] || [],
      session: result[:session],
      message: 'Message processed successfully'
    }
  rescue StandardError => e
    Rails.logger.error "[FlowSimulator] Error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: {
      error: e.message,
      message: 'Failed to simulate message'
    }, status: :unprocessable_entity
  end

  private

  def set_agent_bot
    @agent_bot = Current.account.agent_bots.find(params[:agent_bot_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Agent bot not found' }, status: :not_found
  end

  def set_flow
    @flow = @agent_bot.bot_flows.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Flow not found' }, status: :not_found
  end

  def flow_params
    parsed_params = params.permit(:name, :description, :is_active, :version)
    parsed_params[:flow_data] = parse_jsonb_field(:flow_data)
    parsed_params[:metadata] = parse_jsonb_field(:metadata)

    # Convert to hash to avoid ActionController::Parameters issues
    {
      name: parsed_params[:name],
      description: parsed_params[:description],
      flow_data: parsed_params[:flow_data],
      metadata: parsed_params[:metadata],
      is_active: parsed_params[:is_active],
      version: parsed_params[:version]
    }.compact
  end

  def parse_jsonb_field(field_name)
    return nil if params[field_name].blank?

    params[field_name].is_a?(String) ? JSON.parse(params[field_name]) : params[field_name]
  end

  def node_params
    # Accept all node data fields as a hash
    node_data = params.permit(:label, :description, :state_id, :handler, :action_type,
                              :condition_expression, :true_label, :false_label,
                              :template_name, :template_type, :exact_match, :case_sensitive,
                              actions: [], keywords: [], parameters: {})

    # Convert to plain hash and remove nil values
    node_data.to_h.compact
  end
end
