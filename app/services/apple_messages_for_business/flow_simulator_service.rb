# frozen_string_literal: true

# Service to simulate bot flow execution for testing
# Processes user messages and executes flow logic without actual message sending
#
# Input:
#   - flow: BotFlow object with flow_data (nodes and edges)
#   - session: Current conversation session state
#
# Output:
#   - bot_response: Text response from bot
#   - current_state: Current state ID
#   - executed_nodes: Array of node IDs that were executed
#   - session: Updated session state
class AppleMessagesForBusiness::FlowSimulatorService
  def initialize(flow, session = {})
    @flow = flow
    @flow_data = flow.flow_data || {}
    @nodes = @flow_data['nodes'] || []
    @edges = @flow_data['edges'] || []
    # Convert ActionController::Parameters to hash if needed
    # Use to_unsafe_h for ActionController::Parameters to bypass strong params
    @session = if session.is_a?(ActionController::Parameters)
                 session.to_unsafe_h.symbolize_keys
               elsif session.respond_to?(:symbolize_keys)
                 session.symbolize_keys
               else
                 {}
               end
    @current_state = @session[:current_state] || find_initial_state
    @executed_nodes = []
  end

  # Process user message and return bot response
  # @param message [String] User message text
  # @return [Hash] Response with bot_response, current_state, executed_nodes, session
  def process_message(message)
    # Normalize message
    normalized_message = message.to_s.strip.downcase

    # Track execution path
    @executed_nodes = []

    # Check for keyword matches first (intents)
    if (handler_node = find_intent_match(normalized_message))
      @executed_nodes << handler_node['id']
      process_intent_node(handler_node)
    else
      # Process current state
      state_node = find_state_node(@current_state)
      if state_node
        @executed_nodes << state_node['id']
        process_state_node(state_node)
      else
        # Fallback response
        build_response("I'm not sure how to respond to that. Current state: #{@current_state}")
      end
    end
  end

  private

  # Find initial state from flow
  def find_initial_state
    # Look for node marked as initial
    initial_node = @nodes.find { |n| n['type'] == 'state' && n.dig('data', 'is_initial') == true }
    return initial_node.dig('data', 'state_id') if initial_node

    # Filter out test nodes (nodes with id containing 'test')
    non_test_nodes = @nodes.reject { |n| n['id']&.to_s&.downcase&.include?('test') }

    # Fallback: first non-test state node with state_id matching AHA pattern
    aha_state = non_test_nodes.find { |n| n['type'] == 'state' && n.dig('data', 'state_id')&.match?(/^AHA\d+$/i) }
    return aha_state.dig('data', 'state_id') if aha_state

    # Final fallback: any non-test state node
    first_state = non_test_nodes.find { |n| n['type'] == 'state' }
    return first_state.dig('data', 'state_id') if first_state

    'AHA1' # Default fallback
  end

  # Find state node by state_id
  def find_state_node(state_id)
    @nodes.find do |n|
      n['type'] == 'state' && (n.dig('data', 'state_id') == state_id || n['id'] == state_id)
    end
  end

  # Find intent node that matches message
  def find_intent_match(message)
    intent_nodes = @nodes.select { |n| n['type'] == 'intent' }

    intent_nodes.find do |node|
      keywords = node.dig('data', 'keywords') || []
      exact_match = node.dig('data', 'exact_match')
      case_sensitive = node.dig('data', 'case_sensitive')

      keywords.any? do |keyword|
        keyword_str = case_sensitive ? keyword.to_s : keyword.to_s.downcase
        message_str = case_sensitive ? message : message.downcase

        if exact_match
          keyword_str == message_str
        else
          message_str.include?(keyword_str)
        end
      end
    end
  end

  # Process intent node
  # Intent nodes typically transition to a state
  def process_intent_node(node)
    # Find outgoing edge from intent
    outgoing_edge = @edges.find { |e| e['source'] == node['id'] }

    if outgoing_edge
      target_node = find_node_by_id(outgoing_edge['target'])
      if target_node
        @executed_nodes << target_node['id']

        case target_node['type']
        when 'state'
          # Transition to state
          @current_state = target_node.dig('data', 'state_id') || target_node['id']
          process_state_node(target_node)
        when 'template'
          # Send template
          process_template_node(target_node)
        when 'action'
          # Execute action
          process_action_node(target_node)
        else
          build_response("Intent matched: #{node.dig('data', 'label') || 'Unknown'}")
        end
      else
        build_response("Intent matched but no target found: #{node.dig('data', 'label')}")
      end
    else
      build_response("Intent matched: #{node.dig('data', 'label')}")
    end
  end

  # Process state node
  def process_state_node(node)
    state_data = node['data'] || {}
    state_label = state_data['label'] || 'Unknown State'
    actions = state_data['actions'] || []

    # Build response from state
    response_parts = []
    response_parts << "[State: #{state_label}]"

    # Process actions
    actions.each do |action|
      case action['type']
      when 'send_template'
        template_name = action['template_name']
        response_parts << "Sending template: #{template_name}"

        # Find template node or use action data
        template_node = @nodes.find do |n|
          n['type'] == 'template' && n.dig('data', 'template_name') == template_name
        end

        if template_node
          @executed_nodes << template_node['id']
          response_parts << describe_template(template_node)
        end
      when 'send_text'
        response_parts << action['text']
      else
        response_parts << "Action: #{action['type']}"
      end
    end

    # Check for automatic transitions via edges
    outgoing_edge = @edges.find { |e| e['source'] == node['id'] }
    if outgoing_edge
      target_node = find_node_by_id(outgoing_edge['target'])
      if target_node && target_node['type'] == 'state'
        next_state = target_node.dig('data', 'state_id') || target_node['id']
        @current_state = next_state
        response_parts << "\n[Auto-transitioned to: #{next_state}]"
      end
    else
      # Check for transitions in state data (fallback)
      transitions = state_data['transitions'] || {}
      if transitions['default']
        @current_state = transitions['default']
        response_parts << "\n[Transitioned to: #{transitions['default']}]"
      elsif transitions.any?
        response_parts << "\n[Available transitions: #{transitions.keys.join(', ')}]"
      end
    end

    build_response(response_parts.join("\n"))
  end

  # Process template node
  def process_template_node(node)
    template_data = node['data'] || {}
    template_name = template_data['template_name'] || 'Unknown Template'
    template_data['template_type'] || 'unknown'

    response_parts = []
    response_parts << "[Template: #{template_name}]"
    response_parts << describe_template(node)

    # Follow edges to next state
    outgoing_edge = @edges.find { |e| e['source'] == node['id'] }
    if outgoing_edge
      target_node = find_node_by_id(outgoing_edge['target'])
      if target_node && target_node['type'] == 'state'
        next_state = target_node.dig('data', 'state_id') || target_node['id']
        @current_state = next_state
        response_parts << "\n[Transitioned to state: #{next_state}]"
      end
    end

    build_response(response_parts.join("\n"))
  end

  # Process action node
  def process_action_node(node)
    action_data = node['data'] || {}
    action_type = action_data['action_type'] || 'unknown'
    action_label = action_data['label'] || 'Unknown Action'

    response_parts = []
    response_parts << "[Action: #{action_label}]"
    response_parts << "Type: #{action_type}"

    # Follow edges to next node
    outgoing_edge = @edges.find { |e| e['source'] == node['id'] }
    if outgoing_edge
      target_node = find_node_by_id(outgoing_edge['target'])
      if target_node
        @executed_nodes << target_node['id']

        case target_node['type']
        when 'state'
          @current_state = target_node.dig('data', 'state_id') || target_node['id']
          process_state_node(target_node)
        when 'condition'
          process_condition_node(target_node)
        else
          build_response(response_parts.join("\n"))
        end
      else
        build_response(response_parts.join("\n"))
      end
    else
      build_response(response_parts.join("\n"))
    end
  end

  # Process condition node
  def process_condition_node(node)
    condition_data = node['data'] || {}
    condition_label = condition_data['label'] || 'Unknown Condition'

    # In simulation, we'll randomly evaluate or use session data
    # For now, default to true path
    result = evaluate_condition(condition_data)

    response_parts = []
    response_parts << "[Condition: #{condition_label}]"
    response_parts << "Evaluated to: #{result}"

    # Find appropriate edge (true/false)
    edge_label = result ? condition_data['true_label'] || 'true' : condition_data['false_label'] || 'false'
    outgoing_edge = @edges.find do |e|
      e['source'] == node['id'] && (e['label'] == edge_label || e['data']&.dig('label') == edge_label)
    end

    # Fallback: take first edge if specific label not found
    outgoing_edge ||= @edges.find { |e| e['source'] == node['id'] }

    if outgoing_edge
      target_node = find_node_by_id(outgoing_edge['target'])
      if target_node
        @executed_nodes << target_node['id']

        case target_node['type']
        when 'state'
          @current_state = target_node.dig('data', 'state_id') || target_node['id']
          process_state_node(target_node)
        else
          build_response(response_parts.join("\n"))
        end
      else
        build_response(response_parts.join("\n"))
      end
    else
      build_response(response_parts.join("\n"))
    end
  end

  # Evaluate condition (simplified for simulation)
  def evaluate_condition(condition_data)
    expression = condition_data['condition_expression']

    # Simple evaluation - in real implementation would use session data
    # For now, return true if no expression or use random
    return true if expression.blank?

    # Check session variables if referenced
    # For simulation, default to true
    true
  end

  # Describe template for display
  def describe_template(node)
    template_data = node['data'] || {}
    template_type = template_data['template_type'] || 'unknown'

    case template_type
    when 'list_picker'
      'Interactive list picker - user can select from options'
    when 'time_picker'
      'Time picker - user can select a date/time'
    when 'form', 'apple_form'
      'Form - user fills out information'
    when 'quick_reply'
      'Quick reply - user selects from quick options'
    when 'rich_link'
      'Rich link - displays interactive link'
    else
      "Template type: #{template_type}"
    end
  end

  # Helper: Find node by ID
  def find_node_by_id(node_id)
    @nodes.find { |n| n['id'] == node_id }
  end

  # Build final response
  def build_response(bot_response)
    {
      bot_response: bot_response,
      current_state: @current_state,
      executed_nodes: @executed_nodes,
      session: {
        current_state: @current_state,
        message_count: (@session[:message_count] || 0) + 1,
        last_update: Time.current
      }
    }
  end
end
