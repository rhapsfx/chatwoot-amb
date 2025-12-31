#!/usr/bin/env ruby
# Publish flow for bot ID 12

bot = AgentBot.find(12)
puts "Bot: #{bot.name} (ID: #{bot.id})"
puts ''

flows = bot.bot_flows
puts "Total flows: #{flows.count}"

flows.each do |flow|
  puts "\nFlow ID: #{flow.id}"
  puts "  Name: #{flow.name}"
  puts "  Active: #{flow.is_active} #{flow.is_active ? 'YES' : 'NO'}"
  puts "  Published: #{flow.is_published} #{flow.is_published ? 'YES' : 'NO'}"
  puts "  Version: #{flow.version}"

  if flow.is_published
    puts '  Flow is already published'
  else
    puts "\n  WARNING: Flow is NOT published!"
    puts "  This is why logs show 'No active flow found'"
    puts ''
    puts '  Publishing flow now...'
    flow.update!(is_active: true) unless flow.is_active
    flow.publish!
    puts '  SUCCESS: Flow published!'

    flow.reload
    puts ''
    puts '  After publishing:'
    puts "    Active: #{flow.is_active} (should be true)"
    puts "    Published: #{flow.is_published} (should be true)"
  end
end

puts "\n" + ('='*60)
puts 'Checking routing logic...'
active_flow = bot.bot_flows.active.published.first

if active_flow
  puts 'SUCCESS: FlowExecutorService WILL be used'
  puts "   Flow: #{active_flow.name} (ID: #{active_flow.id})"
else
  puts 'PROBLEM: No published flow found - will use legacy service'
end
puts '='*60
