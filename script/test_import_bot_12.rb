# Test importing bot 12's bot_config to visual flow
bot = AgentBot.find(12)

puts "Testing FlowImportService for bot: #{bot.name}"
puts "Bot config has #{bot.bot_config.keys.size} top-level keys"
puts ''

# Create import service
import_service = AppleMessagesForBusiness::FlowImportService.new(bot.bot_config)

# Import to flow data
flow_data = import_service.import_to_flow_data

puts 'Import Results:'
puts "  Nodes created: #{flow_data[:nodes].size}"
puts "  Edges created: #{flow_data[:edges].size}"
puts ''

# Show first few nodes
puts 'Sample Nodes:'
flow_data[:nodes].first(3).each do |node|
  puts "  - Type: #{node[:type]}, ID: #{node[:id]}, Label: #{node.dig(:data, :label) || node.dig(:data, :state_id)}"
end
puts ''

# Create or update the flow
flow = bot.bot_flows.find_or_initialize_by(name: 'Imported from bot_config')
flow.update!(
  description: 'Auto-imported from bot configuration JSON',
  flow_data: flow_data,
  is_active: true,
  version: (flow.version || 0) + 1
)

puts 'Flow saved successfully!'
puts "  Flow ID: #{flow.id}"
puts "  Version: #{flow.version}"
puts "  Node count: #{flow.node_count}"
puts "  Edge count: #{flow.edge_count}"
