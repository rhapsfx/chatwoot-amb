#!/usr/bin/env ruby
# frozen_string_literal: true

# Fix existing migrated templates by removing bad channel mappings
# Usage: rails runner scripts/fix_migrated_templates.rb --account-id 1 [--dry-run]

require 'json'

options = {}
ARGV.each_with_index do |arg, i|
  case arg
  when '--account-id'
    options[:account_id] = ARGV[i + 1].to_i
  when '--dry-run'
    options[:dry_run] = true
  end
end

account_id = options[:account_id]

unless account_id && account_id > 0
  puts 'Usage: rails runner scripts/fix_migrated_templates.rb --account-id 1 [--dry-run]'
  exit 1
end

puts '🔧 Fixing Migrated Templates'
puts '=' * 80
if options[:dry_run]
  puts '⚠️  DRY-RUN MODE - No changes will be made'
  puts '=' * 80
end
puts

# Find all migrated templates
templates = MessageTemplate.where(account_id: account_id)
                           .select { |t| t.tags.include?('migrated') }

puts "Found #{templates.size} migrated templates"
puts

fixed_count = 0

templates.each do |template|
  # Check if it has channel mappings with template variables
  bad_mappings = template.channel_mappings.select do |mapping|
    mapping.field_mappings.present? &&
      mapping.field_mappings.values.any? { |v| v.to_s.include?('{{') }
  end

  next if bad_mappings.empty?

  puts "Template ##{template.id}: #{template.name}"
  puts "  Found #{bad_mappings.size} bad channel mappings"

  if options[:dry_run]
    puts '  Would delete these mappings'
  else
    bad_mappings.each do |mapping|
      puts "  Deleting mapping ##{mapping.id} (#{mapping.channel_type})"
      mapping.destroy
    end
    fixed_count += 1
  end
  puts
end

puts '=' * 80
puts '📊 Summary'
puts '=' * 80
if options[:dry_run]
  puts "Would fix #{templates.count { |t| t.channel_mappings.any? { |m| m.field_mappings.values.any? { |v| v.to_s.include?('{{') } } }} templates"
else
  puts "Fixed #{fixed_count} templates"
  puts '✨ Done! Templates will now use adapt_with_defaults'
end
