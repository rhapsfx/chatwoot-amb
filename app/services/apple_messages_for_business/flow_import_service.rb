# frozen_string_literal: true

# Service to import bot_config JSON into visual flow format
class AppleMessagesForBusiness::FlowImportService
  def initialize(bot_config)
    @bot_config = bot_config || {}
  end

  def import_to_flow_data
    {
      nodes: import_nodes,
      edges: import_edges,
      metadata: {
        imported_from: 'bot_config',
        imported_at: Time.current.iso8601,
        original_config_keys: @bot_config.keys
      }
    }
  end

  private

  def import_nodes
    nodes = []
    nodes += import_state_nodes
    nodes += import_intent_nodes
    nodes += import_template_nodes
    nodes
  end

  def import_state_nodes
    states = @bot_config.dig('conversation_flow', 'states') || {}

    states.map.with_index do |(state_id, state_data), index|
      {
        id: "state_#{state_id}",
        type: 'state',
        position: calculate_position(index, :state),
        data: {
          state_id: state_id,
          label: state_data['name'] || state_id,
          description: state_data['description'] || '',
          handler: state_data['handler'] || '',
          actions: []
        }
      }
    end
  end

  def import_intent_nodes
    nodes = []

    # Import from demo_keywords
    demo_keywords = @bot_config.dig('keyword_mappings', 'demo_keywords') || {}
    demo_keywords.each_with_index do |(keyword, handler), index|
      nodes << {
        id: "intent_demo_#{index}",
        type: 'intent',
        position: calculate_position(index, :intent),
        data: {
          keywords: [keyword],
          handler: handler,
          exact_match: false,
          case_sensitive: false,
          category: 'demo'
        }
      }
    end

    # Import from flow_control_keywords
    flow_keywords = @bot_config.dig('keyword_mappings', 'flow_control_keywords') || {}
    flow_keywords.each_with_index do |(keyword, handler), index|
      nodes << {
        id: "intent_flow_#{index}",
        type: 'intent',
        position: calculate_position(demo_keywords.size + index, :intent),
        data: {
          keywords: [keyword],
          handler: handler,
          exact_match: false,
          case_sensitive: false,
          category: 'flow_control'
        }
      }
    end

    nodes
  end

  def import_template_nodes
    required_templates = @bot_config.dig('required_templates', 'list') || []

    required_templates.map.with_index do |template_name, index|
      # Try to infer template type from name
      template_type = infer_template_type(template_name)

      {
        id: "template_#{index}",
        type: 'template',
        position: calculate_position(index, :template),
        data: {
          template_name: template_name,
          template_type: template_type
        }
      }
    end
  end

  def import_edges
    edges = []

    # Try to create edges based on state flow (basic heuristic)
    states = @bot_config.dig('conversation_flow', 'states') || {}
    state_ids = states.keys.sort

    # Connect sequential states
    state_ids.each_cons(2).with_index do |(from_state, to_state), index|
      edges << {
        id: "edge_state_#{index}",
        source: "state_#{from_state}",
        target: "state_#{to_state}",
        type: 'default',
        label: 'Sequential flow'
      }
    end

    edges
  end

  def calculate_position(index, node_type)
    # Create a grid layout with different rows for different node types
    row_offset = case node_type
                 when :state then 0
                 when :intent then 400
                 when :template then 800
                 else 0
                 end

    col = index % 4 # 4 nodes per row
    row = index / 4

    {
      x: (col * 350) + 100,
      y: (row * 250) + row_offset + 100
    }
  end

  def infer_template_type(template_name)
    case template_name
    when /list.*picker/i, /picker.*list/i
      'list_picker'
    when /time.*picker/i
      'time_picker'
    when /form/i
      'form'
    when /quick.*reply/i
      'quick_reply'
    when /rich.*link/i
      'rich_link'
    else
      'list_picker' # default
    end
  end
end
