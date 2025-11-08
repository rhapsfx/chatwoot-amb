#!/usr/bin/env ruby
# frozen_string_literal: true

# Cleanup Script for Imported MessageTemplates
# Removes templates that were imported with bad names from the bot migration
#
# Usage:
#   rails runner scripts/cleanup_imported_templates.rb --account-id 1 --business acoustic_house [--dry-run]

require 'json'

class TemplateCleanup
  attr_reader :options

  def initialize(options = {})
    @options = options
  end

  def run
    puts '🧹 Template Cleanup'
    puts '=' * 60
    if dry_run?
      puts '⚠️  DRY-RUN MODE - No deletions will be made'
      puts '=' * 60
    end
    puts "Account ID: #{@options[:account_id]}" if @options[:account_id]
    puts

    account = find_account
    return unless account

    business_tags = @options[:business] ? [@options[:business]] : %w[acoustic_house acoustic_shack telco]

    total_deleted = 0
    business_tags.each do |business_tag|
      puts "🔍 Finding templates for: #{business_tag}"
      templates = find_templates(account, business_tag)

      if templates.empty?
        puts '  No templates found'
        next
      end

      puts "  Found #{templates.size} templates"

      if dry_run?
        preview_templates(templates)
      else
        deleted = delete_templates(templates)
        total_deleted += deleted
      end

      puts
    end

    print_summary(total_deleted)
  end

  private

  def dry_run?
    @options[:dry_run] == true
  end

  def find_account
    if @options[:account_id]
      Account.find_by(id: @options[:account_id])
    else
      puts 'Please specify --account-id'
      nil
    end
  end

  def find_templates(account, business_tag)
    MessageTemplate.where(account: account)
                   .select { |t| t.tags.include?('migrated') && t.tags.include?(business_tag) }
  end

  def preview_templates(templates)
    puts '  Would delete:'
    templates.first(10).each do |t|
      puts "    • #{t.name} (ID: #{t.id})"
    end
    return unless templates.size > 10

    puts "    ... and #{templates.size - 10} more"
  end

  def delete_templates(templates)
    deleted = 0
    templates.each do |t|
      puts "  Deleting: #{t.name} (ID: #{t.id})"
      t.destroy
      deleted += 1
    rescue StandardError => e
      puts "  ❌ Error deleting template #{t.id}: #{e.message}"
    end
    deleted
  end

  def print_summary(total_deleted)
    puts
    puts '=' * 60
    puts '📊 Cleanup Summary'
    puts '=' * 60

    if dry_run?
      puts 'This was a preview only - no templates were deleted'
      puts
      puts 'To delete the templates, run without --dry-run:'
      cmd = 'rails runner scripts/cleanup_imported_templates.rb'
      cmd += " --account-id #{@options[:account_id]}" if @options[:account_id]
      cmd += " --business #{@options[:business]}" if @options[:business]
      puts "  #{cmd}"
    else
      puts "Deleted #{total_deleted} templates"
      puts '✨ Cleanup complete!'
    end
  end
end

# Parse options
options = {}
ARGV.each_with_index do |arg, i|
  case arg
  when '--business'
    options[:business] = ARGV[i + 1]
  when '--account-id'
    options[:account_id] = ARGV[i + 1].to_i
  when '--dry-run'
    options[:dry_run] = true
  end
end

# Run cleanup
cleanup = TemplateCleanup.new(options)
cleanup.run
