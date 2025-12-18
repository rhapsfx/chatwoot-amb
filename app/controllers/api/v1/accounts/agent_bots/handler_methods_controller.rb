# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class Api::V1::Accounts::AgentBots::HandlerMethodsController < Api::V1::Accounts::BaseController
  before_action :set_agent_bot
  before_action :set_service_class
  before_action -> { authorize @agent_bot }

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods
  def index
    handlers = @service_class.handler_methods_metadata

    # Apply filters
    handlers = filter_by_type(handlers) if params[:handler_type].present?
    handlers = filter_by_category(handlers) if params[:category].present?
    handlers = filter_by_status(handlers) if params[:status].present?
    handlers = search_handlers(handlers) if params[:search].present?

    # Build response
    render json: {
      handler_methods: format_handlers_list(handlers),
      meta: build_meta(handlers)
    }
  rescue StandardError => e
    render json: {
      error: e.message,
      message: 'Failed to list handler methods'
    }, status: :internal_server_error
  end

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods/:id
  def show
    method_name = params[:id].to_sym
    handlers = @service_class.handler_methods_metadata

    metadata = handlers[method_name]

    if metadata
      # Enrich metadata with additional information
      enriched_metadata = enrich_metadata(method_name, metadata)
      render json: { handler_method: enriched_metadata }
    else
      render json: {
        error: 'Handler method not found',
        message: "Handler method '#{params[:id]}' does not exist in #{@service_class.name}"
      }, status: :not_found
    end
  rescue StandardError => e
    render json: {
      error: e.message,
      message: 'Failed to get handler method details'
    }, status: :internal_server_error
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods/validate
  def validate
    method_name = params[:method_name]&.to_sym
    handlers = @service_class.handler_methods_metadata

    result = validate_handler_method(method_name, handlers)
    render json: result
  rescue StandardError => e
    render json: {
      error: e.message,
      message: 'Failed to validate handler method'
    }, status: :internal_server_error
  end

  # GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods/search
  # rubocop:disable Metrics/MethodLength
  def search
    query = params[:q]

    if query.blank?
      return render json: {
        error: 'Query parameter is required',
        message: 'Please provide a search query using the q parameter'
      }, status: :bad_request
    end

    handlers = @service_class.handler_methods_metadata
    results = search_handlers_with_scores(handlers, query)

    # Apply limit
    limit = params[:limit]&.to_i || 20
    limited_results = results.take(limit)

    render json: {
      results: limited_results,
      meta: {
        query: query,
        total_results: limited_results.length,
        available_results: results.length
      }
    }
  rescue StandardError => e
    render json: {
      error: e.message,
      message: 'Failed to search handler methods'
    }, status: :internal_server_error
  end
  # rubocop:enable Metrics/MethodLength

  private

  def set_agent_bot
    Rails.logger.info "[HandlerMethods] set_agent_bot called - account_id: #{params[:account_id]}, bot_id: #{params[:agent_bot_id]}"
    @agent_bot = Current.account.agent_bots.find(params[:agent_bot_id])
    Rails.logger.info "[HandlerMethods] Agent bot found: #{@agent_bot.inspect}"
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[HandlerMethods] Agent bot NOT FOUND: #{e.message}"
    render json: { error: 'Agent bot not found' }, status: :not_found
  end

  def set_service_class
    # Use bot_type from agent_bot or allow override via query param
    service_name = params[:service_name] || @agent_bot&.bot_type

    if service_name.blank?
      return render json: {
        error: 'Service name not specified',
        message: 'Bot service class name is required'
      }, status: :bad_request
    end

    # Handle both short names and fully qualified names
    # If service_name doesn't contain ::, try to resolve it in AppleMessagesForBusiness namespace
    service_name = "AppleMessagesForBusiness::#{service_name}" unless service_name.include?('::')

    @service_class = service_name.constantize

    # Verify the service class has handler_methods_metadata
    unless @service_class.respond_to?(:handler_methods_metadata)
      return render json: {
        error: 'Invalid service class',
        message: "#{service_name} does not implement handler_methods_metadata"
      }, status: :bad_request
    end
  rescue NameError
    render json: {
      error: 'Invalid service class',
      message: "Service class '#{service_name}' not found"
    }, status: :bad_request
  end

  # Filtering helpers

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def filter_by_type(handlers)
    target_type = params[:handler_type].to_sym
    handlers.select { |_, meta| meta[:handler_type] == target_type }
  end

  def filter_by_category(handlers)
    target_category = params[:category].to_s
    handlers.select { |_, meta| meta[:category].to_s == target_category }
  end

  def filter_by_status(handlers)
    target_status = params[:status].to_sym
    handlers.select { |_, meta| meta[:status] == target_status }
  end

  def search_handlers(handlers)
    query = params[:search].downcase
    handlers.select do |method_name, meta|
      method_name.to_s.downcase.include?(query) ||
        meta[:display_name]&.downcase&.include?(query) ||
        meta[:description]&.downcase&.include?(query) ||
        meta[:tags]&.any? { |tag| tag.to_s.downcase.include?(query) }
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # Search with scoring for relevance ranking

  def search_handlers_with_scores(handlers, query)
    query_lower = query.to_s.downcase

    results = handlers.filter_map do |method_name, metadata|
      score = calculate_match_score(query_lower, method_name, metadata)
      next if score < 0.3

      {
        method_name: method_name,
        display_name: metadata[:display_name],
        description: metadata[:description],
        match_score: score,
        match_reason: explain_match(query_lower, method_name, metadata),
        category: metadata[:category],
        handler_type: metadata[:handler_type],
        status: metadata[:status]
      }
    end

    results.sort_by { |r| -r[:match_score] }
  end

  def calculate_match_score(query, method_name, metadata)
    name_match = fuzzy_match(query, method_name.to_s.downcase)
    display_match = fuzzy_match(query, metadata[:display_name].to_s.downcase)
    desc_match = fuzzy_match(query, metadata[:description].to_s.downcase)
    tag_match = metadata[:tags]&.any? { |tag| fuzzy_match(query, tag.to_s.downcase) > 0.8 } ? 0.8 : 0

    # Weight matches: method name > display name > description > tags
    (name_match * 1.0) + (display_match * 0.9) + (desc_match * 0.7) + (tag_match * 0.6)
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def fuzzy_match(query, text)
    return 0.0 if text.blank?
    return 1.0 if text == query
    return 0.9 if text.include?(query)

    # Check word-by-word matching
    query_words = query.split(/\W+/)
    text_words = text.split(/\W+/)

    return 0.0 if query_words.empty?

    matches = query_words.count { |qw| text_words.any? { |tw| tw.include?(qw) || qw.include?(tw) } }
    matches.to_f / query_words.length
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def explain_match(query, method_name, metadata)
    if method_name.to_s.downcase.include?(query)
      'Matches in method name'
    elsif metadata[:display_name]&.downcase&.include?(query)
      'Matches in display name'
    elsif metadata[:description]&.downcase&.include?(query)
      'Matches in description'
    elsif metadata[:tags]&.any? { |tag| tag.to_s.downcase.include?(query) }
      'Matches in tags'
    else
      'Partial match'
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # Response formatting

  def format_handlers_list(handlers)
    handlers.map do |method_name, metadata|
      {
        method_name: method_name,
        handler_type: metadata[:handler_type],
        display_name: metadata[:display_name],
        description: metadata[:description],
        category: metadata[:category],
        status: metadata[:status],
        service_name: @service_class.name,
        triggers_count: count_triggers(metadata),
        dependencies_count: count_dependencies(metadata)
      }
    end
  end

  # rubocop:disable Metrics/MethodLength
  def enrich_metadata(method_name, metadata)
    enriched = metadata.dup

    # Add service information
    enriched[:service_name] = @service_class.name

    # Add method signature if available
    if @service_class.method_defined?(method_name) || @service_class.private_method_defined?(method_name)
      begin
        method_obj = @service_class.instance_method(method_name)
        enriched[:signature] = {
          arity: method_obj.arity,
          parameters: method_obj.parameters,
          source_location: method_obj.source_location
        }

        # Extract source file and line number
        if enriched[:signature][:source_location]
          source_file, source_line = enriched[:signature][:source_location]
          enriched[:source_file] = source_file
          enriched[:source_line] = source_line
        end
      rescue StandardError => e
        Rails.logger.warn("Failed to get method signature for #{method_name}: #{e.message}")
      end
    end

    enriched
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/CyclomaticComplexity
  def count_triggers(metadata)
    triggers = metadata[:triggers] || {}
    (triggers[:state_ids]&.length || 0) +
      (triggers[:keywords]&.length || 0) +
      (triggers[:interactive_ids]&.length || 0)
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  # rubocop:disable Metrics/CyclomaticComplexity
  def count_dependencies(metadata)
    deps = metadata[:dependencies] || {}
    (deps[:templates]&.length || 0) +
      (deps[:attributes]&.length || 0) +
      (deps[:services]&.length || 0)
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def build_meta(handlers)
    {
      total: handlers.length,
      services: [@service_class.name],
      categories: handlers.filter_map { |_, m| m[:category] }.uniq.sort,
      handler_types: handlers.filter_map { |_, m| m[:handler_type] }.uniq.sort,
      statuses: handlers.filter_map { |_, m| m[:status] }.uniq.sort
    }
  end

  # Validation logic

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def validate_handler_method(method_name, handlers)
    errors = []
    warnings = []

    # Check if method name is provided
    if method_name.blank?
      errors << {
        type: 'missing_method_name',
        message: 'Method name is required'
      }
      return { valid: false, errors: errors, warnings: warnings }
    end

    # Check if method exists in service class
    unless @service_class.method_defined?(method_name) || @service_class.private_method_defined?(method_name)
      errors << {
        type: 'method_not_found',
        message: "Handler method '#{method_name}' does not exist in #{@service_class.name}",
        suggestion: find_similar_method(method_name)
      }
      return { valid: false, errors: errors, warnings: warnings }
    end

    # Check if metadata exists
    metadata = handlers[method_name]
    if metadata.nil?
      warnings << {
        type: 'no_documentation',
        message: "Handler method '#{method_name}' lacks documentation metadata",
        recommendation: 'Add metadata to handler_methods_metadata in the service class'
      }
    else
      # Validate metadata completeness
      validate_metadata_completeness(method_name, metadata, warnings)
    end

    # Check handler type if specified
    if params[:handler_type].present? && metadata
      expected_type = params[:handler_type].to_sym
      actual_type = metadata[:handler_type]

      if actual_type != expected_type
        warnings << {
          type: 'type_mismatch',
          message: "Handler type mismatch: expected #{expected_type}, got #{actual_type}"
        }
      end
    end

    # Check state_id if specified (for state handlers)
    if params[:state_id].present? && metadata && metadata[:handler_type] == :state
      state_id = params[:state_id]
      triggers = metadata[:triggers] || {}
      state_ids = triggers[:state_ids] || []

      unless state_ids.include?(state_id)
        warnings << {
          type: 'state_not_in_triggers',
          message: "State '#{state_id}' is not listed in handler triggers",
          recommendation: "Add '#{state_id}' to triggers.state_ids in metadata"
        }
      end
    end

    { valid: errors.empty?, errors: errors, warnings: warnings }
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def validate_metadata_completeness(method_name, metadata, warnings)
    required_fields = [:handler_type, :display_name, :description, :category, :status]

    required_fields.each do |field|
      next if metadata[field].present?

      warnings << {
        type: 'incomplete_metadata',
        field: field,
        message: "Handler '#{method_name}' is missing required metadata field: #{field}"
      }
    end

    # Check if triggers are defined for handler types that need them
    return unless [:state, :keyword, :interactive].include?(metadata[:handler_type])

    triggers = metadata[:triggers]
    return if triggers.present?

    warnings << {
      type: 'missing_triggers',
      message: "Handler '#{method_name}' of type #{metadata[:handler_type]} should define triggers"
    }
  end

  def find_similar_method(method_name)
    all_methods = @service_class.instance_methods(false) + @service_class.private_instance_methods(false)
    handler_methods = all_methods.select { |m| m.to_s.start_with?('handle_') }

    # Find methods with similar prefix
    method_prefix = method_name.to_s[0..5]
    similar = handler_methods.find { |m| m.to_s.start_with?(method_prefix) }

    similar ? "Did you mean '#{similar}'?" : nil
  end
end
# rubocop:enable Metrics/ClassLength
