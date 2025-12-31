# Check and publish flow for bot ID 12

bot = AgentBot.find(12)
puts "Bot: #{bot.name} (ID: #{bot.id})"
puts "Bot Type: #{bot.bot_type}"
puts ""

# Check all flows
all_flows = bot.bot_flows
puts "Total flows: #{all_flows.count}"

if all_flows.any?
  all_flows.each do |flow|
    puts "\nFlow: #{flow.name} (ID: #{flow.id})"
    puts "  Version: #{flow.version_display}"
    puts "  Active: #{flow.is_active}"
    puts "  Published: #{flow.is_published}"
    puts "  Created: #{flow.created_at}"
  end
  
  # Find or create a flow to publish
  flow_to_publish = all_flows.active.first || all_flows.first
  
  if flow_to_publish
    puts "\n" + "="*50
    puts "Publishing flow: #{flow_to_publish.name}"
    puts "="*50
    
    # Ensure it's active
    flow_to_publish.update\!(is_active: true) unless flow_to_publish.is_active
    
    # Publish it
    flow_to_publish.publish\!
    
    puts "✅ Flow published successfully\!"
    puts "  Name: #{flow_to_publish.name}"
    puts "  Published: #{flow_to_publish.is_published}"
    puts "  Active: #{flow_to_publish.is_active}"
    puts "  Version: #{flow_to_publish.version_display}"
  end
else
  puts "\n⚠️  No flows found for this bot\!"
  puts "You need to create a flow in Bot Studio first."
end
