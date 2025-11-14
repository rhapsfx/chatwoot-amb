#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive Acoustic House Bot Verification Script
# Verifies bot configuration, templates, images, and responses

puts "\n" + ('=' * 80)
puts '🎸 Acoustic House Bot Verification'
puts ('=' * 80) + "\n"

# Initialize results
results = {
  inbox: false,
  bot_service: false,
  templates: { total: 0, missing: [] },
  images: { total: 0, missing_per_inbox: {} },
  conversations: { total: 0, bot_enabled: 0 },
  keywords: []
}

# ============================================================================
# 1. Check AMB Inbox Configuration
# ============================================================================
puts '1️⃣  Checking AMB Inbox Configuration'
puts '-' * 80

inbox = Inbox.where(channel_type: 'Channel::AppleMessagesForBusiness').first

unless inbox
  puts '❌ No Apple Messages for Business inbox found'
  puts '   Please create an AMB inbox first'
  exit 1
end

results[:inbox] = true
puts "✅ Found AMB inbox: #{inbox.name}"
puts "   Inbox ID: #{inbox.id}"
puts "   Account ID: #{inbox.account_id}"
puts ''

# ============================================================================
# 2. Check Bot Service
# ============================================================================
puts '2️⃣  Checking Bot Service'
puts '-' * 80

begin
  # Check if service class exists
  service_class = AppleMessagesForBusiness::AcousticHouseBotService
  puts "✅ Bot service class exists: #{service_class.name}"

  # Check for required methods
  required_methods = [
    :handle_message,
    :process_user_message,
    :check_template_images_available,
    :send_template_message
  ]

  missing_methods = []
  required_methods.each do |method|
    if service_class.instance_methods.include?(method)
      puts "   ✅ Method present: #{method}"
    else
      puts "   ❌ Method missing: #{method}"
      missing_methods << method
    end
  end

  if missing_methods.empty?
    results[:bot_service] = true
    puts '✅ All required methods present'
  else
    puts "⚠️  Missing #{missing_methods.count} methods"
  end
rescue NameError => e
  puts "❌ Bot service not found: #{e.message}"
end
puts ''

# ============================================================================
# 3. Check Bot Templates
# ============================================================================
puts '3️⃣  Checking Bot Templates'
puts '-' * 80

# Expected bot templates
expected_templates = {
  'AHA1' => 'Welcome message',
  'AHA2' => 'Region selection',
  'AHA3' => 'Customer name form',
  'AHA4' => 'Guitar selection list',
  'AHA5' => 'Guitar details',
  'AHA6' => 'Contact options',
  'AHA7' => 'Schedule appointment time picker',
  'AHA8' => 'Thank you message'
}

account = Account.find(inbox.account_id)
bot_templates = MessageTemplate.where(account: account, short_code: expected_templates.keys)

results[:templates][:total] = bot_templates.count

puts "Found #{bot_templates.count}/#{expected_templates.count} expected templates"
puts ''

expected_templates.each do |code, description|
  template = bot_templates.find { |t| t.short_code == code }

  if template
    puts "✅ #{code}: #{template.name}"
    puts "   Description: #{description}"
    puts "   Category: #{template.category}"

    # Check content blocks
    if template.content_blocks.present?
      puts "   Content blocks: #{template.content_blocks.count}"
    else
      puts '   ⚠️  No content blocks'
    end
  else
    puts "❌ #{code}: Missing"
    puts "   Expected: #{description}"
    results[:templates][:missing] << code
  end
  puts ''
end

# ============================================================================
# 4. Check Images with New Endpoint
# ============================================================================
puts '4️⃣  Checking Images (New apple_amb_images Endpoint)'
puts '-' * 80

all_amb_inboxes = Inbox.where(
  account_id: account.id,
  channel_type: 'Channel::AppleMessagesForBusiness'
)

puts "Checking images across #{all_amb_inboxes.count} AMB inbox(es):"
puts ''

# Get all unique image identifiers from templates
all_identifiers = Set.new
bot_templates.each do |template|
  identifiers = template.extract_image_identifiers_from_blocks
  all_identifiers.merge(identifiers)
end

results[:images][:total] = all_identifiers.count
puts "Total unique image identifiers in templates: #{all_identifiers.count}"
puts "Identifiers: #{all_identifiers.to_a.inspect}"
puts ''

all_amb_inboxes.each do |check_inbox|
  puts "Inbox: #{check_inbox.name} (ID: #{check_inbox.id})"

  available = AppleListPickerImage.where(
    inbox_id: check_inbox.id,
    identifier: all_identifiers.to_a
  ).pluck(:identifier)

  missing = all_identifiers.to_a - available

  if missing.empty?
    puts "  ✅ All #{all_identifiers.count} images available"
  else
    puts "  ⚠️  Missing #{missing.count} images: #{missing.inspect}"
    results[:images][:missing_per_inbox][check_inbox.id] = missing
  end

  puts "  Available images: #{available.count}"
  puts ''
end

# ============================================================================
# 5. Check Recent Conversations
# ============================================================================
puts '5️⃣  Checking Recent Conversations'
puts '-' * 80

recent_convos = inbox.conversations.order(created_at: :desc).limit(5)
results[:conversations][:total] = recent_convos.count

recent_convos.each do |convo|
  custom_attrs = convo.custom_attributes || {}
  bot_enabled = custom_attrs.fetch('bot_enabled', true)
  bot_state = custom_attrs['bot_state'] || 'AHA1'

  results[:conversations][:bot_enabled] += 1 if bot_enabled

  puts "Conversation ID: #{convo.id}"
  puts "  Contact: #{convo.contact.name || 'Unknown'}"
  puts "  Status: #{convo.status}"
  puts "  Bot Enabled: #{bot_enabled ? '✅' : '❌'}"
  puts "  Bot State: #{bot_state}"
  puts "  Messages: #{convo.messages.count}"
  puts ''
end

# ============================================================================
# 6. Check Bot Keywords
# ============================================================================
puts '6️⃣  Checking Bot Keywords'
puts '-' * 80

# These are the keywords the bot should respond to
keywords = [
  { keyword: 'listpicker', description: 'Should show guitar selection list (AHA4)' },
  { keyword: 'timepicker', description: 'Should show appointment scheduler (AHA7)' },
  { keyword: 'form', description: 'Should show customer name form (AHA3)' },
  { keyword: 'restart', description: 'Should reset bot to welcome (AHA1)' },
  { keyword: 'welcome', description: 'Should show welcome message (AHA1)' }
]

puts 'Expected bot keywords:'
keywords.each do |kw|
  puts "  • #{kw[:keyword]}: #{kw[:description]}"
  results[:keywords] << kw[:keyword]
end
puts ''

# ============================================================================
# Summary
# ============================================================================
puts "\n" + ('=' * 80)
puts '📊 Verification Summary'
puts ('=' * 80) + "\n"

all_good = true

# Inbox check
if results[:inbox]
  puts '✅ AMB Inbox: Configured'
else
  puts '❌ AMB Inbox: Not found'
  all_good = false
end

# Bot service check
if results[:bot_service]
  puts '✅ Bot Service: All methods present'
else
  puts '⚠️  Bot Service: Missing methods'
  all_good = false
end

# Templates check
if results[:templates][:missing].empty?
  puts "✅ Templates: All #{results[:templates][:total]} templates found"
else
  puts "⚠️  Templates: Missing #{results[:templates][:missing].count} templates"
  puts "   Missing: #{results[:templates][:missing].join(', ')}"
  all_good = false
end

# Images check
if results[:images][:missing_per_inbox].empty?
  puts '✅ Images: All images available in all inboxes'
else
  puts '⚠️  Images: Some inboxes missing images'
  results[:images][:missing_per_inbox].each do |inbox_id, missing|
    puts "   Inbox #{inbox_id}: Missing #{missing.count} images"
  end
  all_good = false
end

# Conversations check
puts "ℹ️  Conversations: #{results[:conversations][:total]} recent, #{results[:conversations][:bot_enabled]} with bot enabled"

# Keywords check
puts "ℹ️  Keywords: #{results[:keywords].count} keywords configured"

puts ''

if all_good
  puts '🎉 All checks passed! Bot is ready to use.'
  puts ''
  puts 'Next steps:'
  puts '1. Test bot by sending a message to your AMB inbox'
  puts "2. Try keywords: #{results[:keywords].join(', ')}"
  puts "3. Monitor logs: tail -f log/development.log | grep -E '(Bot|AMB)'"
else
  puts '⚠️  Some checks failed. Please review the issues above.'
  puts ''
  puts 'Common fixes:'
  puts '1. Missing templates: Run template creation scripts'
  puts '2. Missing images: Use ImageValidationModal to copy images'
  puts '3. Bot not responding: Check conversation bot_enabled flag'
end

puts ''
puts '=' * 80
