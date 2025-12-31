# frozen_string_literal: true

# Script to activate the Acoustic House Master Bot flow
# This makes the flow active and published so FlowExecutorService will use it

puts '=' * 80
puts 'Activating Acoustic House Master Bot Flow'
puts '=' * 80

# Find the Acoustic House Master Bot
bot = AgentBot.find_by(name: 'Acoustic House Master Bot')

unless bot
  puts '❌ Error: Acoustic House Master Bot not found'
  puts '💡 Run script/create_acoustic_house_master_bot.rb first'
  exit 1
end

puts "✅ Found bot: #{bot.name} (ID: #{bot.id})"

# Find the flow
flow = bot.bot_flows.first

unless flow
  puts '❌ Error: No flow found for this bot'
  exit 1
end

puts "✅ Found flow: #{flow.name} (ID: #{flow.id})"
puts "   Current is_active: #{flow.is_active}"
puts "   Current is_published: #{flow.is_published}"

# Update flow to be active and published
flow.update!(
  is_active: true,
  is_published: true
)

puts "\n✅ Flow activated!"
puts "   New is_active: #{flow.is_active}"
puts "   New is_published: #{flow.is_published}"

# Verify the flow will be picked up
active_flows = bot.bot_flows.active.published
puts "\n📊 Verification:"
puts "   Total flows for bot: #{bot.bot_flows.count}"
puts "   Active + Published flows: #{active_flows.count}"

if active_flows.any?
  puts "\n✅ SUCCESS: Flow will now be used by FlowExecutorService!"
  puts "\n🔧 Next steps:"
  puts '   1. Test the bot in a conversation'
  puts "   2. Check logs for: '[Bot] 🎨 Bot has active flow:'"
  puts "   3. Verify it's using FlowExecutorService instead of AcousticHouseBotService"
  puts "\n📋 Expected log output:"
  puts "   [Bot] 🤖 Using configured AMB bot: Acoustic House Master Bot (ID: #{bot.id})"
  puts "   [Bot] 🎨 Bot has active flow: 'Acoustic House Flow' (ID: #{flow.id})"
  puts '   [Bot] 🚀 Using FlowExecutorService for visual bot flow'
else
  puts "\n❌ ERROR: Flow still not showing as active+published"
  puts "   This shouldn't happen - please check bot_flows table"
end

puts "\n" + ('=' * 80)
