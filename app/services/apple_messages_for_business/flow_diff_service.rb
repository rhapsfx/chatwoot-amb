# frozen_string_literal: true

class AppleMessagesForBusiness::FlowDiffService
  def initialize(flow_a, flow_b)
    @flow_a = flow_a
    @flow_b = flow_b
    @nodes_a = flow_a.flow_data['nodes'] || []
    @nodes_b = flow_b.flow_data['nodes'] || []
    @edges_a = flow_a.flow_data['edges'] || []
    @edges_b = flow_b.flow_data['edges'] || []
  end

  def diff
    {
      flows: {
        flow_a: flow_summary(@flow_a),
        flow_b: flow_summary(@flow_b)
      },
      nodes: {
        added: nodes_added,
        removed: nodes_removed,
        modified: nodes_modified
      },
      edges: {
        added: edges_added,
        removed: edges_removed
      },
      summary: build_summary
    }
  end

  private

  def flow_summary(flow)
    {
      id: flow.id,
      name: flow.name,
      version: flow.version,
      version_tag: flow.version_tag,
      is_published: flow.is_published,
      published_at: flow.published_at,
      node_count: flow.node_count,
      edge_count: flow.edge_count
    }
  end

  def nodes_added
    # rubocop:disable Rails/Pluck
    node_ids_a = @nodes_a.map { |n| n['id'] }
    # rubocop:enable Rails/Pluck
    @nodes_b.reject { |n| node_ids_a.include?(n['id']) }
  end

  def nodes_removed
    # rubocop:disable Rails/Pluck
    node_ids_b = @nodes_b.map { |n| n['id'] }
    # rubocop:enable Rails/Pluck
    @nodes_a.reject { |n| node_ids_b.include?(n['id']) }
  end

  def nodes_modified
    modified = []
    @nodes_b.each do |node_b|
      node_a = @nodes_a.find { |n| n['id'] == node_b['id'] }
      next unless node_a

      next unless nodes_differ?(node_a, node_b)

      modified << {
        id: node_b['id'],
        type: node_b['type'],
        label: node_b.dig('data', 'label'),
        changes: calculate_node_changes(node_a, node_b)
      }
    end
    modified
  end

  def nodes_differ?(node_a, node_b)
    # Compare node type
    return true if node_a['type'] != node_b['type']

    # Compare position
    return true if node_a['position'] != node_b['position']

    # Compare data (deep comparison)
    normalize_node_data(node_a['data']) != normalize_node_data(node_b['data'])
  end

  def normalize_node_data(data)
    return {} if data.nil?

    # Sort keys for consistent comparison
    data.sort.to_h
  end

  def calculate_node_changes(node_a, node_b)
    changes = {}
    data_a = node_a['data'] || {}
    data_b = node_b['data'] || {}

    all_keys = (data_a.keys + data_b.keys).uniq

    all_keys.each do |key|
      value_a = data_a[key]
      value_b = data_b[key]

      next if value_a == value_b

      changes[key] = {
        old: value_a,
        new: value_b
      }
    end

    changes['position'] = { old: node_a['position'], new: node_b['position'] } if node_a['position'] != node_b['position']
    changes['type'] = { old: node_a['type'], new: node_b['type'] } if node_a['type'] != node_b['type']

    changes
  end

  def edges_added
    edge_keys_a = @edges_a.map { |e| edge_key(e) }
    @edges_b.reject { |e| edge_keys_a.include?(edge_key(e)) }
  end

  def edges_removed
    edge_keys_b = @edges_b.map { |e| edge_key(e) }
    @edges_a.reject { |e| edge_keys_b.include?(edge_key(e)) }
  end

  def edge_key(edge)
    "#{edge['source']}_#{edge['sourceHandle']}_#{edge['target']}_#{edge['targetHandle']}"
  end

  def build_summary
    {
      nodes_added: nodes_added.length,
      nodes_removed: nodes_removed.length,
      nodes_modified: nodes_modified.length,
      edges_added: edges_added.length,
      edges_removed: edges_removed.length,
      total_changes: nodes_added.length + nodes_removed.length + nodes_modified.length + edges_added.length + edges_removed.length
    }
  end
end
