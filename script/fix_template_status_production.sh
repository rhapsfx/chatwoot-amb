#!/bin/bash
set -e

echo "=== Fix Acoustic House Bot Template Status ==="
echo ""

ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner - RAILS_ENV=production' <<'RUBY'
# Check current status of bot templates
bot_names = ['ah_guitar_list_picker', 'ah_guitar_info_form', 'ah_large_form_demo', 'ah_main_menu', 'ah_ar_guitar', 'ah_summary']

puts "Step 1: Checking current template status..."
puts "=" * 70

templates = MessageTemplate.where(account_id: 1, name: bot_names)
total_found = templates.count

puts "Total templates found: #{total_found}"
puts ""

if total_found == 0
  puts "❌ No templates found - need to import them first"
  puts "Run: ./script/deploy-backend-changes-safe.sh"
  exit 1
end

puts "Current template status:"
templates.each do |t|
  status_icon = case t.status
                when 'active' then '✅'
                when 'draft' then '⚠️'
                when 'deprecated' then '❌'
                else '❓'
                end
  puts "  #{status_icon} #{t.name}: status='#{t.status || 'NULL'}'"
end

# Count templates by status
active_count = templates.where(status: 'active').count
draft_count = templates.where(status: 'draft').count
deprecated_count = templates.where(status: 'deprecated').count
null_count = templates.where(status: nil).count

puts ""
puts "Status breakdown:"
puts "  Active: #{active_count}"
puts "  Draft: #{draft_count}"
puts "  Deprecated: #{deprecated_count}"
puts "  NULL: #{null_count}"

# Check what UI would show (same filter as templates_controller.rb line 22)
ui_visible = MessageTemplate.where(account_id: 1, name: bot_names)
                            .where.not(status: 'deprecated')
                            .count

puts ""
puts "Templates visible in UI (excluding deprecated): #{ui_visible}/#{total_found}"

# Fix status if needed
needs_fix = templates.where.not(status: 'active').count

if needs_fix == 0
  puts ""
  puts "✅ All templates already have status='active'"
  puts "   If templates still don't appear in UI, check:"
  puts "   1. Browser cache (hard refresh: Cmd+Shift+R)"
  puts "   2. Account ID is correct (expecting 1)"
  puts "   3. Check browser console for errors"
  exit 0
end

puts ""
puts "Step 2: Fixing template status..."
puts "=" * 70
puts "Templates needing fix: #{needs_fix}"
puts ""

fixed_count = 0
templates.where.not(status: 'active').each do |t|
  old_status = t.status || 'NULL'
  t.update!(status: 'active')
  puts "  ✅ #{t.name}: '#{old_status}' → 'active'"
  fixed_count += 1
end

puts ""
puts "=" * 70
puts "✅ Fixed #{fixed_count} templates"

# Verify fix
ui_visible_after = MessageTemplate.where(account_id: 1, name: bot_names)
                                  .where.not(status: 'deprecated')
                                  .count

puts ""
puts "Step 3: Verification"
puts "=" * 70
puts "Templates visible in UI: #{ui_visible_after}/#{total_found}"

if ui_visible_after == total_found
  puts "✅ All templates should now be visible in UI"
  puts ""
  puts "Check UI: https://msp.rhaps.net/app/accounts/1/settings/templates/list"
  puts ""
  puts "If still not visible, try:"
  puts "  1. Hard refresh browser (Cmd+Shift+R)"
  puts "  2. Check browser console for JavaScript errors"
  puts "  3. Verify correct account (should be account 1)"
else
  puts "⚠️  Some templates still not visible"
  puts "   Check template fields (category, supported_channels, etc.)"
end
RUBY

echo ""
echo "✅ Template status fix complete!"
