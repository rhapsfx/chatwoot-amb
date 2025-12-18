# frozen_string_literal: true

# Service to compile visual flow data into bot_config JSON format
# Converts React Flow node/edge structure into AcousticHouseBotService-compatible configuration
#
# Flow Structure (Input):
#   - nodes: Array of node objects (state, intent, template, action, condition)
#   - edges: Array of edge objects connecting nodes
#
# Bot Config Structure (Output):
#   - conversation_flow: Initial state and state definitions
#   - keyword_mappings: Keyword → handler mappings (demo + flow_control)
#   - interactive_handlers: Interactive message → handler mappings
#   - required_templates: List of template names with validation config
#   - typing_indicators: Typing indicator configuration
#   - idempotency: Idempotency configuration
#   - features: Feature flags
# rubocop:disable Metrics/ClassLength
class AppleMessagesForBusiness::FlowCompilerService
  # Node type constants
  NODE_TYPES = %w[state intent template action condition].freeze

  def initialize(flow)
    @flow = flow
    @flow_data = flow.flow_data || {}
    @nodes = @flow_data['nodes'] || []
    @edges = @flow_data['edges'] || []
    @metadata = @flow_data['metadata'] || {}
  end

  # Compile visual flow into bot_config
  # @return [Hash] Complete bot_config structure
  def compile
    validate_flow!

    {
      conversation_flow: build_conversation_flow,
      keyword_mappings: build_keyword_mappings,
      interactive_handlers: build_interactive_handlers,
      required_templates: extract_required_templates,
      typing_indicators: default_typing_indicators,
      idempotency: default_idempotency,
      features: extract_features
    }
  end

  private

  # Validate flow structure
  def validate_flow!
    raise StandardError, 'Flow has no nodes' if @nodes.empty?
    raise StandardError, 'Flow has no state nodes' if state_nodes.empty?
  end

  # Build conversation_flow section
  # Includes initial state, idle timeout, and state definitions
  def build_conversation_flow
    state_map = build_state_map
    initial_state = find_initial_state

    {
      'initial_state' => initial_state,
      'idle_timeout_minutes' => @metadata['idle_timeout_minutes'] || 30,
      'states' => state_map
    }
  end

  # Build state map from state nodes
  # Maps state_id → { name, handler, description, actions, transitions }
  def build_state_map
    state_nodes.each_with_object({}) do |node, hash|
      data = node['data'] || {}
      state_id = data['state_id'] || node['id']

      hash[state_id] = {
        'name' => data['label'] || state_id,
        'handler' => data['handler'] || generate_state_handler_name(state_id),
        'description' => data['description'],
        'actions' => extract_node_actions(node),
        'transitions' => build_state_transitions(node)
      }.compact
    end
  end

  # Extract actions from state node
  # Actions can be: send_template, send_text, send_quick_reply, etc.
  def extract_node_actions(node)
    data = node['data'] || {}
    actions = data['actions'] || []

    # If node has a template reference, add send_template action
    if data['template_name'].present?
      actions << {
        'type' => 'send_template',
        'template_name' => data['template_name'],
        'parameters' => data['parameters'] || {}
      }
    end

    actions
  end

  # Build transitions for a state node
  # Follows edges from this state to determine next state(s)
  def build_state_transitions(node)
    outgoing_edges = @edges.select { |e| e['source'] == node['id'] }
    return {} if outgoing_edges.empty?

    transitions = {}

    outgoing_edges.each do |edge|
      target_node = find_node_by_id(edge['target'])
      next unless target_node

      # Determine transition type
      if edge['type'] == 'conditional'
        # Conditional transition (from condition node)
        condition_label = edge['label'] || 'true'
        transitions[condition_label] = get_target_state_id(target_node)
      else
        # Default transition
        transitions['default'] = get_target_state_id(target_node)
      end
    end

    transitions
  end

  # Get state ID from target node
  def get_target_state_id(node)
    return nil unless node

    if node['type'] == 'state'
      node.dig('data', 'state_id') || node['id']
    else
      # Non-state target (template, action, etc.) - find next state
      find_next_state_from_node(node)
    end
  end

  # Find next state by following edges from non-state node
  def find_next_state_from_node(node)
    outgoing_edges = @edges.select { |e| e['source'] == node['id'] }
    return nil if outgoing_edges.empty?

    # Follow first edge to find next state
    next_node = find_node_by_id(outgoing_edges.first['target'])
    return nil unless next_node

    if next_node['type'] == 'state'
      next_node.dig('data', 'state_id') || next_node['id']
    else
      # Recursively follow edges
      find_next_state_from_node(next_node)
    end
  end

  # Find initial state (first state node, or node marked as initial)
  def find_initial_state
    # Look for node marked as initial
    initial_node = state_nodes.find { |n| n.dig('data', 'is_initial') == true }
    return initial_node.dig('data', 'state_id') if initial_node

    # Fallback: first state node
    first_state = state_nodes.first
    return 'AHA1' unless first_state

    first_state.dig('data', 'state_id') || first_state['id']
  end

  # Build keyword_mappings section
  # Maps keywords to handlers, split into demo_keywords and flow_control_keywords
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def build_keyword_mappings
    intent_nodes = @nodes.select { |n| n['type'] == 'intent' }

    demo_keywords = {}
    flow_control_keywords = {}

    intent_nodes.each do |node|
      data = node['data'] || {}
      keywords = data['keywords'] || []
      handler = data['handler'] || generate_intent_handler_name(node)
      category = data['category'] || 'demo'

      # Map each keyword to the same handler
      keywords.each do |keyword|
        normalized_keyword = keyword.to_s.downcase.strip

        if category == 'flow_control'
          flow_control_keywords[normalized_keyword] = handler
        else
          demo_keywords[normalized_keyword] = handler
        end
      end
    end

    result = {}
    result['demo_keywords'] = demo_keywords unless demo_keywords.empty?
    result['flow_control_keywords'] = flow_control_keywords unless flow_control_keywords.empty?
    result
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # Build interactive_handlers section
  # Maps request_identifier (from templates/interactive messages) to handler methods
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def build_interactive_handlers
    handlers = {}

    # Extract from template nodes
    template_nodes.each do |node|
      data = node['data'] || {}
      template_name = data['template_name']
      next if template_name.blank?

      # Use explicit request_identifier if provided, otherwise generate
      request_id = data['request_identifier'] || generate_request_identifier(template_name, data['template_type'])

      # Determine handler method
      handler = data['handler'] || generate_template_handler_name(template_name, data['template_type'])

      handlers[request_id] = handler
    end

    # Extract from action nodes with explicit request identifiers
    action_nodes = @nodes.select { |n| n['type'] == 'action' }
    action_nodes.each do |node|
      data = node['data'] || {}
      request_id = data['request_identifier']
      handler = data['handler']

      handlers[request_id] = handler if request_id.present? && handler.present?
    end

    handlers
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # Extract required_templates section
  # Lists all template names used in the flow
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def extract_required_templates
    template_list = []

    # From template nodes
    template_nodes.each do |node|
      data = node['data'] || {}
      template_name = data['template_name']
      template_list << template_name if template_name.present?
    end

    # From state actions
    state_nodes.each do |node|
      data = node['data'] || {}
      actions = data['actions'] || []

      actions.each do |action|
        template_list << action['template_name'] if action['type'] == 'send_template' && action['template_name'].present?
      end
    end

    # Remove duplicates and sort
    template_list = template_list.uniq.sort

    {
      'list' => template_list,
      'validation' => {
        'enabled' => @metadata['validate_templates'] || true,
        'fail_on_missing' => @metadata['fail_on_missing_templates'] || false
      }
    }
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # Extract features section
  # Feature flags for AR, forms, OAuth, etc.
  def extract_features
    features = {
      'ar_enabled' => true,
      'forms_enabled' => true,
      'oauth_enabled' => true,
      'app_clips_enabled' => true,
      'apple_pay_enabled' => true,
      'apple_maps_enabled' => true,
      'rich_links_enabled' => true,
      'attachments_enabled' => true,
      'imessage_apps_enabled' => true
    }

    # Override with metadata if present
    metadata_features = @metadata['features'] || {}
    features.merge(metadata_features)
  end

  # Default typing indicators configuration
  def default_typing_indicators
    {
      'enabled' => true,
      'delay_seconds' => 1.5
    }
  end

  # Default idempotency configuration
  def default_idempotency
    {
      'enabled' => true,
      'ttl_minutes' => 2,
      'redis_key_prefix' => 'amb_bot'
    }
  end

  # Generate handler name for state
  # e.g., 'AHA1' → 'handle_aha1'
  def generate_state_handler_name(state_id)
    "handle_#{state_id.downcase}"
  end

  # Generate handler name for intent
  # Finds target state and generates handler
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def generate_intent_handler_name(node)
    # Find target state by following edges
    outgoing_edges = @edges.select { |e| e['source'] == node['id'] }
    return 'handle_unknown_intent' if outgoing_edges.empty?

    target_node = find_node_by_id(outgoing_edges.first['target'])
    return 'handle_unknown_intent' unless target_node

    if target_node['type'] == 'state'
      target_state_id = target_node.dig('data', 'state_id') || target_node['id']
      generate_state_handler_name(target_state_id)
    else
      # Use first keyword as handler name
      keywords = node.dig('data', 'keywords') || []
      return 'handle_unknown_intent' if keywords.empty?

      "handle_#{keywords.first.to_s.downcase.gsub(/\s+/, '_')}"
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # Generate handler name for template
  # e.g., 'ah_guitar_list_picker' + 'list_picker' → 'handle_guitar_selection'
  def generate_template_handler_name(template_name, template_type)
    # Remove common prefixes
    base = template_name.gsub(/^(ah_|amb_|apple_)/, '').tr('_', ' ')

    suffix = case template_type
             when 'list_picker'
               'selection'
             when 'time_picker', 'form', 'apple_form', 'quick_reply'
               'response'
             else
               "#{template_name}_response"
             end

    "handle_#{base}_#{suffix}".tr(' ', '_')
  end

  # Generate request identifier for template
  # e.g., 'ah_guitar_list_picker' + 'list_picker' → 'lp_guitar_0319'
  def generate_request_identifier(template_name, template_type)
    # Remove common prefixes
    base = template_name.gsub(/^(ah_|amb_|apple_)/, '')

    # Generate type prefix
    type_prefix = case template_type
                  when 'list_picker'
                    'lp'
                  when 'time_picker'
                    'time'
                  when 'form', 'apple_form'
                    'form'
                  when 'quick_reply', 'apple_quick_reply'
                    'qr'
                  when 'apple_pay'
                    'applepay'
                  else
                    'act'
                  end

    # Generate random suffix (4 digits)
    suffix = format('%04d', rand(10_000))

    "#{type_prefix}_#{base}_#{suffix}"
  end

  # Helper: Find node by ID
  def find_node_by_id(node_id)
    @nodes.find { |n| n['id'] == node_id }
  end

  # Helper: Get all state nodes
  def state_nodes
    @state_nodes ||= @nodes.select { |n| n['type'] == 'state' }
  end

  # Helper: Get all template nodes
  def template_nodes
    @template_nodes ||= @nodes.select { |n| n['type'] == 'template' }
  end
end
# rubocop:enable Metrics/ClassLength
