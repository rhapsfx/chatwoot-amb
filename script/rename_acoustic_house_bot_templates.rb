#!/usr/bin/env ruby
# frozen_string_literal: true

# Acoustic House Bot Template Rename Script
#
# Automatically renames templates from hardcoded IDs to standardized names
# that match the REQUIRED_TEMPLATES constant.
#
# Usage:
#   rails runner script/rename_acoustic_house_bot_templates.rb [--execute] [--account-id=N]
#
# Options:
#   --execute      Actually perform the renames (default is dry-run)
#   --account-id=N Specify account ID (default: 1)
#
# Exit codes:
#   0 - Success (all templates renamed or dry-run complete)
#   1 - Error (templates not found or rename failed)

require 'optparse'

class AcousticHouseBotTemplateRenamer
  # Mapping of current template IDs to desired names
  # Based on actual template usage in acoustic_house_bot_service.rb
  TEMPLATE_MAPPINGS = {
    371 => 'ah_guitar_list_picker',    # send_guitar_list_picker (line 1923)
    356 => 'ah_guitar_info_form',      # send_guitar_info_form (line 2032)
    343 => 'ah_large_form_demo',       # send_large_content_form (line 2086)
    344 => 'ah_ar_guitar',             # send_ar_file (line 2422)
    366 => 'ah_main_menu',             # send_menu_list_picker (line 2328)
    355 => 'ah_summary'                # send_summary_list_picker (line 2234)
  }.freeze

  def initialize(account_id:, execute: false)
    @account_id = account_id
    @execute = execute
    @renamed_count = 0
    @skipped_count = 0
    @errors = []
  end

  def rename
    puts '🔄 Acoustic House Bot Template Rename'
    puts '=' * 70
    puts "Account ID: #{@account_id}"
    puts "Mode: #{@execute ? 'EXECUTE' : 'DRY RUN'}"
    puts ''

    TEMPLATE_MAPPINGS.each do |template_id, desired_name|
      rename_template(template_id, desired_name)
    end

    print_summary
    exit(@errors.empty? ? 0 : 1)
  rescue StandardError => e
    puts "💥 Script error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    exit 1
  end

  private

  def rename_template(template_id, desired_name)
    # Find template by ID
    template = MessageTemplate.find_by(id: template_id)

    unless template
      puts "⚠️  Template ID #{template_id} not found (expected name: #{desired_name})"
      @errors << "Template ID #{template_id} not found"
      return
    end

    # Check if template belongs to the correct account
    if template.account_id != @account_id
      puts "⚠️  Template ID #{template_id} belongs to account #{template.account_id}, not #{@account_id}"
      puts '    Skipping...'
      @skipped_count += 1
      return
    end

    # Check if already has correct name
    if template.name == desired_name
      puts "✓  Template ID #{template_id} already named '#{desired_name}' - no change needed"
      @skipped_count += 1
      return
    end

    # Show what will be renamed
    puts "#{@execute ? '🔄' : '📋'} Template ID #{template_id}"
    puts "    Current name: '#{template.name}'"
    puts "    New name:     '#{desired_name}'"

    if @execute
      # Check if target name already exists
      existing = MessageTemplate.find_by(account_id: @account_id, name: desired_name)
      if existing && existing.id != template_id
        puts "    ⚠️  Warning: Name '#{desired_name}' already used by template ID #{existing.id}"
        puts '    Skipping to avoid conflict...'
        @errors << "Name conflict: #{desired_name} already exists (ID: #{existing.id})"
        return
      end

      # Perform rename
      template.name = desired_name
      if template.save
        puts '    ✅ Renamed successfully'
        @renamed_count += 1
      else
        puts "    ❌ Failed to rename: #{template.errors.full_messages.join(', ')}"
        @errors << "Failed to rename ID #{template_id}: #{template.errors.full_messages.join(', ')}"
      end
    else
      puts '    ℹ️  Would rename (dry-run mode)'
      @renamed_count += 1
    end

    puts ''
  end

  def print_summary
    puts '=' * 70
    puts 'Summary:'
    puts "  Templates to rename: #{TEMPLATE_MAPPINGS.size}"
    puts "  Renamed:            #{@renamed_count}"
    puts "  Skipped:            #{@skipped_count}"
    puts "  Errors:             #{@errors.size}"

    if @errors.any?
      puts ''
      puts 'Errors:'
      @errors.each { |error| puts "  - #{error}" }
    end

    puts ''
    if @execute
      if @errors.empty?
        puts '✅ Rename complete - all templates updated'
      else
        puts '⚠️  Rename completed with errors - please review above'
      end
    else
      puts 'ℹ️  This was a dry-run. Add --execute to perform the renames.'
      puts '   Example: rails runner script/rename_acoustic_house_bot_templates.rb --execute'
    end
  end
end

# Parse command line options
options = {
  execute: false,
  account_id: 1
}

ARGV.each do |arg|
  case arg
  when '--execute'
    options[:execute] = true
  when /--account-id=(\d+)/
    options[:account_id] = Regexp.last_match(1).to_i
  end
end

# Run renamer
renamer = AcousticHouseBotTemplateRenamer.new(
  account_id: options[:account_id],
  execute: options[:execute]
)
renamer.rename
