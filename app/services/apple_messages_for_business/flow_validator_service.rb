# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Metrics/CyclomaticComplexity
# rubocop:disable Metrics/PerceivedComplexity, Metrics/AbcSize
# Validator service with comprehensive flow validation logic - complexity is inherent to validation
class AppleMessagesForBusiness::FlowValidatorService
  # Node type constants
  NODE_TYPES = %w[state intent template action condition start end].freeze

  # Valid action types
  ACTION_TYPES = %w[send_message transition_state call_api set_variable].freeze

  # State ID regex pattern
  # Must start with uppercase letter, can contain uppercase letters, numbers, underscores, and hyphens
  # Examples: AHA1, MAIN2, START1, DEMO_MODE, WELCOME_STATE, MAIN_MENU
  STATE_ID_PATTERN = /^[A-Z][A-Z0-9_-]*$/

  def initialize(flow)
    @flow = flow
    @account = flow.agent_bot.account
    @nodes = flow.flow_data['nodes'] || []
    @edges = flow.flow_data['edges'] || []
    @errors = []
    @warnings = []
  end

  def validate
    validate_structure
    validate_nodes
    validate_connections
    validate_references

    {
      valid: @errors.empty?,
      errors: @errors,
      warnings: @warnings
    }
  end

  private

  def validate_structure
    # Check for at least one node
    if @nodes.empty?
      add_error(
        type: 'empty_flow',
        message: 'Flow must have at least one node'
      )
      return
    end

    # Check for at least one state node
    state_nodes = @nodes.select { |n| n['type'] == 'state' }
    if state_nodes.empty?
      add_error(
        type: 'missing_state_nodes',
        message: 'Flow must have at least one state node'
      )
    end

    # Warn if no start node defined
    start_nodes = @nodes.select { |n| n['type'] == 'start' }
    if start_nodes.empty?
      add_warning(
        type: 'missing_start_node',
        message: 'Flow should have a start node to define the initial state'
      )
    elsif start_nodes.length > 1
      add_warning(
        type: 'multiple_start_nodes',
        message: 'Flow has multiple start nodes. Only the first will be used.'
      )
    end

    # Warn if no end state defined
    end_nodes = @nodes.select { |n| n['type'] == 'end' }
    return unless end_nodes.empty?

    add_warning(
      type: 'missing_end_node',
      message: 'Flow should have at least one end node to define termination points'
    )
  end

  def validate_nodes
    @nodes.each do |node|
      validate_node(node)
    end

    # Check for duplicate state IDs
    state_nodes = @nodes.select { |n| n['type'] == 'state' }
    state_ids = state_nodes.filter_map { |n| n.dig('data', 'state_id') }
    duplicate_ids = state_ids.select { |id| state_ids.count(id) > 1 }.uniq

    duplicate_ids.each do |state_id|
      add_error(
        type: 'duplicate_state_id',
        state_id: state_id,
        message: "Duplicate state ID: #{state_id}"
      )
    end
  end

  def validate_node(node)
    node_id = node['id']
    node_type = node['type']
    data = node['data'] || {}

    # Validate node type
    unless NODE_TYPES.include?(node_type)
      add_error(
        node_id: node_id,
        type: 'invalid_node_type',
        node_type: node_type,
        message: "Invalid node type: #{node_type}"
      )
      return
    end

    # Type-specific validation
    case node_type
    when 'state'
      validate_state_node(node_id, data)
    when 'intent'
      validate_intent_node(node_id, data)
    when 'template'
      validate_template_node(node_id, data)
    when 'action'
      validate_action_node(node_id, data)
    when 'condition'
      validate_condition_node(node_id, data)
    when 'start'
      validate_start_node(node_id, data)
    end
  end

  def validate_state_node(node_id, data)
    # State ID is required
    state_id = data['state_id']
    if state_id.blank?
      add_error(
        node_id: node_id,
        type: 'missing_required_field',
        field: 'state_id',
        message: 'State node must have a state_id'
      )
    elsif !STATE_ID_PATTERN.match?(state_id)
      add_error(
        node_id: node_id,
        type: 'invalid_state_id_format',
        field: 'state_id',
        value: state_id,
        message: "State ID '#{state_id}' must match format (e.g., AHA1, MAIN2, START1)"
      )
    end

    # State must have at least one action OR one transition
    has_actions = data['actions'].present? && data['actions'].any?
    has_transitions = outgoing_edges(node_id).any?

    return if has_actions || has_transitions

    add_warning(
      node_id: node_id,
      type: 'isolated_state',
      message: 'State has no actions and no transitions. It may be incomplete.'
    )
  end

  def validate_intent_node(node_id, data)
    # Keywords are required
    keywords = data['keywords']
    if keywords.blank? || !keywords.is_a?(Array) || keywords.empty?
      add_error(
        node_id: node_id,
        type: 'missing_required_field',
        field: 'keywords',
        message: 'Intent node must have at least one keyword'
      )
    else
      # Validate each keyword
      keywords.each_with_index do |keyword, index|
        next unless keyword.blank? || !keyword.is_a?(String)

        add_error(
          node_id: node_id,
          type: 'invalid_keyword',
          field: 'keywords',
          index: index,
          message: "Keyword at index #{index} must be a non-empty string"
        )
      end
    end

    # Intent should connect to a state node
    target_nodes = outgoing_edges(node_id).filter_map { |edge| find_node(edge['target']) }
    state_targets = target_nodes.select { |n| n['type'] == 'state' }

    return unless state_targets.empty?

    add_warning(
      node_id: node_id,
      type: 'intent_no_state_target',
      message: 'Intent node should connect to a state node'
    )
  end

  def validate_template_node(node_id, data)
    # Template name is required
    template_name = data['template_name']
    if template_name.blank?
      add_error(
        node_id: node_id,
        type: 'missing_required_field',
        field: 'template_name',
        message: 'Template node must have a template_name'
      )
      return
    end

    # Validate template existence (this will be checked in validate_references)
    # but provide helpful context here
    return if data['template_type'].present?

    add_warning(
      node_id: node_id,
      type: 'missing_template_type',
      field: 'template_type',
      message: 'Template node should specify template_type (list_picker, time_picker, form)'
    )
  end

  def validate_action_node(node_id, data)
    # Action type is required
    action_type = data['action_type']
    if action_type.blank?
      add_error(
        node_id: node_id,
        type: 'missing_required_field',
        field: 'action_type',
        message: 'Action node must have an action_type'
      )
    elsif ACTION_TYPES.exclude?(action_type)
      add_error(
        node_id: node_id,
        type: 'invalid_action_type',
        field: 'action_type',
        value: action_type,
        message: "Invalid action type: #{action_type}. Must be one of: #{ACTION_TYPES.join(', ')}"
      )
    end

    # Validate parameters if present
    parameters = data['parameters']
    return if parameters.blank?
    return if parameters.is_a?(Hash)

    add_error(
      node_id: node_id,
      type: 'invalid_parameters',
      field: 'parameters',
      message: 'Action parameters must be a valid object/hash'
    )
  end

  def validate_condition_node(node_id, data)
    # Condition expression is required
    condition_expression = data['condition_expression']
    if condition_expression.blank?
      add_error(
        node_id: node_id,
        type: 'missing_required_field',
        field: 'condition_expression',
        message: 'Condition node must have a condition_expression'
      )
    end

    # Condition nodes should have exactly 2 outgoing edges (true/false paths)
    outgoing = outgoing_edges(node_id)
    if outgoing.length != 2
      add_error(
        node_id: node_id,
        type: 'invalid_condition_branches',
        message: "Condition node must have exactly 2 outgoing connections (has #{outgoing.length})"
      )
    end

    # Check for true/false labels
    true_label = data['true_label']
    false_label = data['false_label']
    return unless true_label.blank? || false_label.blank?

    add_warning(
      node_id: node_id,
      type: 'missing_branch_labels',
      message: 'Condition node should have true_label and false_label for clarity'
    )
  end

  def validate_start_node(node_id, _data)
    # Start node should connect to exactly one state node
    targets = outgoing_edges(node_id)
    if targets.empty?
      add_error(
        node_id: node_id,
        type: 'start_node_no_connection',
        message: 'Start node must connect to an initial state'
      )
    elsif targets.length > 1
      add_warning(
        node_id: node_id,
        type: 'start_node_multiple_connections',
        message: 'Start node connects to multiple nodes. Only the first will be used.'
      )
    end
  end

  def validate_connections
    # Check for orphaned nodes (nodes with no connections)
    @nodes.each do |node|
      node_id = node['id']
      node_type = node['type']

      # Skip end nodes - they're expected to have no outgoing connections
      next if node_type == 'end'

      # Check for orphaned nodes (no incoming or outgoing edges)
      incoming = incoming_edges(node_id)
      outgoing = outgoing_edges(node_id)

      if incoming.empty? && outgoing.empty? && node_type != 'start'
        add_warning(
          node_id: node_id,
          type: 'orphaned_node',
          message: 'Node is not connected to any other nodes and will never be reached'
        )
      elsif outgoing.empty? && node_type != 'end'
        add_warning(
          node_id: node_id,
          type: 'dead_end_node',
          message: 'Node has no outgoing connections (except end nodes)'
        )
      end
    end

    # Check for duplicate edges
    edge_keys = @edges.map { |e| "#{e['source']}_#{e['target']}" }
    duplicate_edges = edge_keys.select { |key| edge_keys.count(key) > 1 }.uniq

    duplicate_edges.each do |edge_key|
      source, target = edge_key.split('_')
      add_warning(
        type: 'duplicate_edge',
        source: source,
        target: target,
        message: "Duplicate connection between #{source} and #{target}"
      )
    end

    # Check for circular references (infinite loops)
    detect_circular_references
  end

  def validate_references
    # Validate template references
    template_nodes = @nodes.select { |n| n['type'] == 'template' }
    template_nodes.each do |node|
      node_id = node['id']
      template_name = node.dig('data', 'template_name')
      next if template_name.blank?

      # Check if template exists in database
      template = MessageTemplate.find_by(account: @account, name: template_name)
      if template.nil?
        add_error(
          node_id: node_id,
          type: 'invalid_template',
          template_name: template_name,
          message: "Template '#{template_name}' does not exist in account"
        )
      elsif template.status != 'active'
        add_warning(
          node_id: node_id,
          type: 'inactive_template',
          template_name: template_name,
          message: "Template '#{template_name}' exists but is not active (status: #{template.status})"
        )
      end
    end

    # Validate state transitions reference valid states
    validate_state_transitions
  end

  def validate_state_transitions
    state_nodes = @nodes.select { |n| n['type'] == 'state' }
    state_ids = state_nodes.filter_map { |n| n.dig('data', 'state_id') }.to_set

    # Check edges from state nodes
    state_nodes.each do |node|
      node_id = node['id']
      outgoing = outgoing_edges(node_id)

      outgoing.each do |edge|
        target_node = find_node(edge['target'])
        next unless target_node

        # If target is a state node, validate the state_id exists
        next unless target_node['type'] == 'state'

        target_state_id = target_node.dig('data', 'state_id')
        next unless target_state_id.present? && state_ids.exclude?(target_state_id)

        add_error(
          node_id: node_id,
          type: 'invalid_state_transition',
          target_state_id: target_state_id,
          message: "Transition references non-existent state: #{target_state_id}"
        )
      end
    end
  end

  def detect_circular_references
    # Use depth-first search to detect cycles
    visited = Set.new
    recursion_stack = Set.new

    @nodes.each do |node|
      node_id = node['id']
      next if visited.include?(node_id)

      next unless cycle?(node_id, visited, recursion_stack)

      add_error(
        node_id: node_id,
        type: 'circular_reference',
        message: 'Circular reference detected: Flow contains an infinite loop'
      )
      break # Report only the first cycle found
    end
  end

  def cycle?(node_id, visited, recursion_stack)
    visited.add(node_id)
    recursion_stack.add(node_id)

    outgoing = outgoing_edges(node_id)
    outgoing.each do |edge|
      target_id = edge['target']

      # If target not visited yet, recurse
      if visited.exclude?(target_id)
        return true if cycle?(target_id, visited, recursion_stack)
      # If target is in recursion stack, we found a cycle
      elsif recursion_stack.include?(target_id)
        return true
      end
    end

    recursion_stack.delete(node_id)
    false
  end

  # Helper methods

  def find_node(node_id)
    @nodes.find { |n| n['id'] == node_id }
  end

  def outgoing_edges(node_id)
    @edges.select { |e| e['source'] == node_id }
  end

  def incoming_edges(node_id)
    @edges.select { |e| e['target'] == node_id }
  end

  def add_error(error_data)
    @errors << error_data
  end

  def add_warning(warning_data)
    @warnings << warning_data
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/CyclomaticComplexity
# rubocop:enable Metrics/PerceivedComplexity, Metrics/AbcSize
