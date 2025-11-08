#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive Rollback Script for Template Imports
# Safely removes imported templates with backup and restore capability
#
# Usage:
#   rails runner scripts/rollback_template_import.rb --account-id 1 [--business TYPE] [--dry-run] [--backup]

require 'json'
require 'fileutils'

class TemplateRollback
  attr_reader :options, :stats

  def initialize(options = {})
    @options = options
    @stats = {
      templates_found: 0,
      templates_deleted: 0,
      content_blocks_deleted: 0,
      channel_mappings_deleted: 0,
      errors: []
    }
  end

  def run
    puts '🔄 Template Import Rollback'
    puts '=' * 80
    puts '⚠️  DRY-RUN MODE - No deletions will be made' if dry_run?
    puts '💾 BACKUP MODE - Will save template data before deletion' if backup?
    puts '=' * 80
    puts

    account = find_account
    return unless account

    # Create backup if requested
    create_backup(account) if backup? && !dry_run?

    # Find templates to delete
    templates = find_migrated_templates(account)

    if templates.empty?
      puts "No migrated templates found for account ##{account.id}"
      return
    end

    @stats[:templates_found] = templates.size
    puts "Found #{templates.size} migrated templates to remove"
    puts

    if dry_run?
      preview_deletion(templates)
    else
      execute_deletion(templates)
    end

    print_summary
  end

  private

  def dry_run?
    @options[:dry_run] == true
  end

  def backup?
    @options[:backup] == true
  end

  def find_account
    account_id = @options[:account_id]
    unless account_id && account_id > 0
      puts 'Error: --account-id required'
      return nil
    end

    Account.find_by(id: account_id)
  end

  def find_migrated_templates(account)
    templates = MessageTemplate.where(account: account)
                               .select { |t| t.tags.include?('migrated') }

    # Filter by business if specified
    templates.select! { |t| t.tags.include?(@options[:business]) } if @options[:business]

    templates
  end

  def create_backup(account)
    backup_dir = File.join('tmp', 'template_backups')
    FileUtils.mkdir_p(backup_dir)

    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    backup_file = File.join(backup_dir, "rollback_backup_account_#{account.id}_#{timestamp}.json")

    templates = find_migrated_templates(account)
    backup_data = {
      account_id: account.id,
      account_name: account.name,
      backed_up_at: Time.now.iso8601,
      template_count: templates.size,
      templates: templates.map do |t|
        {
          id: t.id,
          name: t.name,
          category: t.category,
          description: t.description,
          status: t.status,
          supported_channels: t.supported_channels,
          tags: t.tags,
          use_cases: t.use_cases,
          version: t.version,
          parameters: t.parameters,
          metadata: t.metadata,
          content_blocks: t.content_blocks.map do |block|
            {
              id: block.id,
              block_type: block.block_type,
              properties: block.properties,
              conditions: block.conditions,
              order_index: block.order_index
            }
          end,
          channel_mappings: t.channel_mappings.map do |mapping|
            {
              id: mapping.id,
              channel_type: mapping.channel_type,
              content_type: mapping.content_type,
              field_mappings: mapping.field_mappings
            }
          end
        }
      end
    }

    File.write(backup_file, JSON.pretty_generate(backup_data))
    puts "💾 Backup saved to: #{backup_file}"
    puts
  end

  def preview_deletion(templates)
    puts 'Would delete the following templates:'
    puts

    templates.group_by { |t| t.tags.find { |tag| tag.in?(%w[acoustic_house acoustic_shack telco]) } || 'unknown' }.each do |business, biz_templates|
      puts "  #{business.upcase}:"
      biz_templates.first(5).each do |t|
        blocks = t.content_blocks.count
        mappings = t.channel_mappings.count
        puts "    • #{t.name} (ID: #{t.id}) - #{blocks} blocks, #{mappings} mappings"
      end
      puts "    ... and #{biz_templates.size - 5} more" if biz_templates.size > 5
      puts
    end
  end

  def execute_deletion(templates)
    templates.each do |template|
      blocks_count = template.content_blocks.count
      mappings_count = template.channel_mappings.count

      puts "Deleting: #{template.name} (ID: #{template.id})"
      template.destroy

      @stats[:templates_deleted] += 1
      @stats[:content_blocks_deleted] += blocks_count
      @stats[:channel_mappings_deleted] += mappings_count
    rescue StandardError => e
      @stats[:errors] << "Failed to delete template #{template.id}: #{e.message}"
      puts "  ❌ Error: #{e.message}"
    end
  end

  def print_summary
    puts
    puts '=' * 80
    puts '📊 Rollback Summary'
    puts '=' * 80

    if dry_run?
      puts 'Would delete:'
      puts "  Templates: #{@stats[:templates_found]}"
    else
      puts 'Deleted:'
      puts "  Templates: #{@stats[:templates_deleted]}"
      puts "  Content Blocks: #{@stats[:content_blocks_deleted]}"
      puts "  Channel Mappings: #{@stats[:channel_mappings_deleted]}"
    end

    if @stats[:errors].any?
      puts
      puts "❌ Errors (#{@stats[:errors].size}):"
      @stats[:errors].each { |error| puts "  - #{error}" }
    end

    puts
    if dry_run?
      puts 'This was a preview - no changes were made'
      puts
      puts 'To execute rollback:'
      cmd = "rails runner scripts/rollback_template_import.rb --account-id #{@options[:account_id]}"
      cmd += " --business #{@options[:business]}" if @options[:business]
      cmd += ' --backup' # Recommend backup
      puts "  #{cmd}"
    else
      puts '✨ Rollback complete!'
    end
  end
end

# Parse options
options = {}
ARGV.each_with_index do |arg, i|
  case arg
  when '--account-id'
    options[:account_id] = ARGV[i + 1].to_i
  when '--business'
    options[:business] = ARGV[i + 1]
  when '--dry-run'
    options[:dry_run] = true
  when '--backup'
    options[:backup] = true
  end
end

# Run rollback
rollback = TemplateRollback.new(options)
rollback.run
