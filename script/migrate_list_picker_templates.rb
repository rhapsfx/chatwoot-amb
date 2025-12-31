#!/usr/bin/env ruby
# frozen_string_literal: true

# Migrate existing list picker templates from camelCase to snake_case

puts '=== Migrating List Picker Templates to snake_case ==='
puts

dry_run = ENV['DRY_RUN'] != 'false'

if dry_run
  puts '🔍 DRY RUN MODE - No changes will be made'
  puts 'To execute migration: DRY_RUN=false rails runner script/migrate_list_picker_templates.rb'
else
  puts '🚀 EXECUTION MODE - Changes will be saved to database'
end
puts

# Find all templates with list picker content
templates = MessageTemplate.where("metadata -> 'apple_message_content' -> 'content_attributes' -> 'list_picker' IS NOT NULL")
                           .or(MessageTemplate.where("metadata -> 'apple_message_content' -> 'content_attributes' -> 'sections' IS NOT NULL"))

puts "Found #{templates.count} list picker templates to check"
puts

migrated_count = 0
already_correct_count = 0
error_count = 0

templates.each do |template|
  puts '─' * 80
  puts "Template ID: #{template.id} - #{template.name}"

  begin
    content_attrs = template.metadata&.dig('apple_message_content', 'content_attributes')

    unless content_attrs
      puts '  ⚠️ SKIP: No content_attributes found'
      next
    end

    # Get sections
    sections = content_attrs['sections'] || content_attrs.dig('list_picker', 'sections')

    unless sections
      puts '  ⚠️ SKIP: No sections found'
      next
    end

    # Check if migration is needed
    needs_migration = sections.any? do |section|
      section.key?('multipleSelection') ||
        section['items']&.any? { |item| item.key?('imageIdentifier') }
    end

    unless needs_migration
      puts '  ✅ Already in snake_case format'
      already_correct_count += 1
      next
    end

    puts '  🔄 Needs migration - normalizing to snake_case'

    # Normalize the entire content_attributes using CaseTransformer
    normalized_attrs = AppleMessagesForBusiness::CaseTransformer.from_apple_format(content_attrs)

    # Update the template
    template.metadata['apple_message_content']['content_attributes'] = normalized_attrs

    if dry_run
      puts '  ✓ Would migrate (dry run)'
    else
      template.save!
      puts '  ✅ Migrated successfully'
    end

    migrated_count += 1

  rescue StandardError => e
    puts "  ❌ ERROR: #{e.message}"
    puts "  Backtrace: #{e.backtrace.first(3).join("\n")}"
    error_count += 1
  end
  puts
end

puts '=' * 80
puts
puts '📊 MIGRATION SUMMARY'
puts "  Templates checked: #{templates.count}"
puts "  Already correct: #{already_correct_count}"
puts "  #{dry_run ? 'Would migrate' : 'Migrated'}: #{migrated_count}"
puts "  Errors: #{error_count}"
puts

if dry_run && migrated_count > 0
  puts '💡 To execute migration: DRY_RUN=false rails runner script/migrate_list_picker_templates.rb'
elsif !dry_run && migrated_count > 0
  puts '✅ Migration complete! All list picker templates now use snake_case.'
end
