#!/usr/bin/env ruby
# Check what BotActionTemplate records exist for the account

account = Account.find(1)

puts "=== BotActionTemplate Records for Account #{account.name} ==="
puts

templates = BotActionTemplate.where(account: account).order(:name)

if templates.any?
  puts "Found #{templates.count} templates:"
  templates.each do |template|
    puts "  #{template.id.to_s.ljust(4)} | #{template.name.ljust(40)} | #{template.template_type}"
  end
else
  puts '❌ No BotActionTemplate records found!'
  puts
  puts "This means Bot Studio templates haven't been created yet."
  puts 'You need to either:'
  puts '  1. Create templates via Bot Studio UI'
  puts '  2. Import templates from legacy system'
  puts '  3. Keep using handlers (Phase 1)'
end

puts
puts '=== Legacy MessageTemplate Records ==='
puts

legacy_templates = MessageTemplate.where(account: account, name: %w[ah_summary ah_guitar_info_form ah_time_picker])

if legacy_templates.any?
  puts "Found #{legacy_templates.count} legacy templates:"
  legacy_templates.each do |template|
    puts "  #{template.id.to_s.ljust(4)} | #{template.name}"
  end
  puts
  puts 'These are legacy MessageTemplate records, not BotActionTemplate.'
  puts 'They need to be migrated to BotActionTemplate format.'
else
  puts '❌ No legacy templates found either!'
end
