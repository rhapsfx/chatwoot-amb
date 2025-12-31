#!/usr/bin/env ruby
# Check current time-picker-demo node configuration

flow = BotFlow.find(5)
node = flow.flow_data['nodes'].find { |n| n['id'] == 'state-time-picker-demo' }

puts '=== Time Picker Demo Node Configuration ==='
puts
puts "Node ID: #{node['id']}"
puts "Label: #{node.dig('data', 'label')}"
puts "Handler: #{node.dig('data', 'handlerMethod') || node.dig('data', 'handler') || 'none'}"
puts
puts 'Actions:'
actions = node.dig('data', 'actions') || []
if actions.any?
  actions.each_with_index do |action, i|
    puts "  Action #{i + 1}:"
    puts "    Type: #{action['type']}"
    if action['template_id']
      template = BotActionTemplate.find_by(id: action['template_id'])
      puts "    Template ID: #{action['template_id']}"
      puts "    Template Name: #{template&.name || 'NOT FOUND'}"
      puts "    Template Type: #{template&.template_type || 'N/A'}"
    elsif action['template_ids']
      puts "    Template IDs: #{action['template_ids'].inspect}"
      action['template_ids'].each do |tid|
        template = BotActionTemplate.find_by(id: tid)
        puts "      - #{tid}: #{template&.name || 'NOT FOUND'} (#{template&.template_type || 'N/A'})"
      end
    end
  end
else
  puts '  No actions configured!'
end
