#!/bin/bash
set -e

echo "=== Acoustic House Bot Template Verification & Import ==="
echo ""

# Step 1: Check if templates exist
echo "Step 1: Checking if templates exist on production..."
ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner - RAILS_ENV=production' <<'RUBY_CHECK'
count = MessageTemplate.where(
  account_id: 1,
  name: ['ah_guitar_list_picker', 'ah_guitar_info_form', 'ah_large_form_demo', 'ah_main_menu', 'ah_ar_guitar', 'ah_summary']
).count

puts "Templates found: #{count}"

if count == 6
  puts "✅ All 6 templates already exist"
  exit 0
else
  puts "⚠️  Only #{count}/6 templates found - need to import"
  exit 1
end
RUBY_CHECK

TEMPLATES_EXIST=$?

if [ $TEMPLATES_EXIST -eq 0 ]; then
  echo ""
  echo "All templates already exist. Exiting."
  exit 0
fi

# Step 2: Import templates
echo ""
echo "Step 2: Importing templates to production..."
ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner - RAILS_ENV=production' <<'RUBY_IMPORT'
require 'json'

template_file = '/tmp/bot_templates.json'

unless File.exist?(template_file)
  puts "❌ Template file not found: #{template_file}"
  puts "Run deployment script first to export templates"
  exit 1
end

data = JSON.parse(File.read(template_file))

puts "📦 Manual Template Import"
puts "=" * 70
puts "Account ID from export: #{data['metadata']['account_id']}"
puts "Templates in export: #{data['templates'].size}"
puts ""

# Import templates with detailed logging
puts "📋 Importing templates..."
success_count = 0
error_count = 0

data['templates'].each do |template_data|
  puts ""
  puts "Processing: #{template_data['name']}"

  template = MessageTemplate.find_or_initialize_by(
    account_id: template_data['account_id'],
    name: template_data['name']
  )

  puts "  Status: #{template.new_record? ? 'NEW' : 'EXISTS (updating)'}"

  # Exclude id, attachments, and status (let status default to 'active')
  template.assign_attributes(template_data.except('id', 'attachments', 'status'))

  if template.save
    puts "  ✅ Saved (ID: #{template.id}, Status: #{template.status})"
    success_count += 1
  else
    puts "  ❌ FAILED: #{template.errors.full_messages.join(', ')}"
    error_count += 1
  end
end

puts ""
puts "=" * 70
puts "Import complete: #{success_count} saved, #{error_count} failed"

if error_count > 0
  puts "❌ Some templates failed to import"
  exit 1
end

puts "✅ All templates imported successfully"
RUBY_IMPORT

# Step 3: Verify import
echo ""
echo "Step 3: Verifying import..."
ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner - RAILS_ENV=production' <<'RUBY_VERIFY'
result = AppleMessagesForBusiness::AcousticHouseBotService.verify_templates_exist(1)

puts ""
puts "=" * 70
puts "Verification Results:"
puts "  All Present: #{result[:all_present]}"
puts "  Found: #{result[:found].size} templates"

if result[:missing].any?
  puts "  Missing: #{result[:missing].join(', ')}"
  exit 1
else
  puts "✅ All required templates are present and accessible"
  exit 0
end
RUBY_VERIFY

echo ""
echo "✅ Template import and verification complete!"
