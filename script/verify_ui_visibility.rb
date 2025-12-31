puts '=' * 70
puts 'TEMPLATE UI VISIBILITY CHECK'
puts '=' * 70
puts ''

bot_names = %w[ah_guitar_list_picker ah_guitar_info_form ah_large_form_demo ah_main_menu ah_ar_guitar ah_summary]

# This is the EXACT filter from templates_controller.rb line 22
templates = MessageTemplate.where(account_id: 1, name: bot_names)
                           .where.not(status: 'deprecated')
                           .order(created_at: :desc)

puts "Templates that will appear in UI: #{templates.count}/6"
puts ''

templates.each do |t|
  puts "✅ #{t.name}"
  puts "   ID: #{t.id}"
  puts "   Status: #{t.status}"
  puts "   Category: #{t.category}"
  puts "   Created: #{t.created_at}"
  puts ''
end

if templates.count == 6
  puts '=' * 70
  puts '✅ ALL 6 TEMPLATES SHOULD BE VISIBLE IN UI!'
  puts '=' * 70
  puts ''
  puts 'Check the UI at:'
  puts 'https://msp.rhaps.net/app/accounts/1/settings/templates/list'
  puts ''
  puts "If they still don't appear:"
  puts '  1. Hard refresh: Cmd+Shift+R (or Ctrl+Shift+R)'
  puts '  2. Clear browser cache'
  puts '  3. Check browser console for errors (F12)'
else
  puts "⚠️  Only #{templates.count}/6 templates will be visible"
  puts "Some templates may have status='deprecated'"
end
