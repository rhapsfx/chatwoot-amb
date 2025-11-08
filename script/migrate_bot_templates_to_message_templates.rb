#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to migrate bot templates from agent_bots.bot_config to message_templates table
# This makes templates accessible via the / command in ReplyBox
#
# Usage:
#   rails runner script/migrate_bot_templates_to_message_templates.rb --bot-name "Acoustic House" --account-id 1 [--dry-run]
#
# Options:
#   --bot-name NAME       Name of the AgentBot to migrate templates from (required)
#   --account-id ID       Account ID to create templates for (required)
#   --dry-run            Preview changes without saving
#   --force              Overwrite existing templates with same name
#   --filter-core        Only migrate templates marked as CORE (recommended)

require 'optparse'

class BotTemplateToMessageTemplateMigrator
  attr_reader :bot_name, :account_id, :dry_run, :force, :filter_core

  def initialize(bot_name:, account_id:, dry_run: false, force: false, filter_core: false)
    @bot_name = bot_name
    @account_id = account_id
    @dry_run = dry_run
    @force = force
    @filter_core = filter_core
    @stats = {
      total: 0,
      created: 0,
      skipped: 0,
      errors: 0,
      filtered_out: 0
    }
  end

  def migrate!
    puts "\n" + ('=' * 80)
    puts 'Bot Templates → Message Templates Migration'
    puts '=' * 80
    puts "Bot Name: #{bot_name}"
    puts "Account ID: #{account_id}"
    puts "Mode: #{dry_run ? 'DRY RUN (no changes will be saved)' : 'LIVE'}"
    puts "Force: #{force ? 'Yes (will overwrite existing)' : 'No (will skip existing)'}"
    puts "Filter: #{filter_core ? 'CORE templates only' : 'All templates'}"
    puts '=' * 80
    puts

    # Find bot
    bot = AgentBot.find_by(name: bot_name)
    unless bot
      puts "❌ Error: Bot '#{bot_name}' not found"
      return false
    end

    # Find account
    account = Account.find_by(id: account_id)
    unless account
      puts "❌ Error: Account #{account_id} not found"
      return false
    end

    # Get templates from bot_config
    bot_templates = bot.bot_config['templates'] || []
    @stats[:total] = bot_templates.size

    puts "📦 Found #{@stats[:total]} templates in bot config"
    puts

    # Filter if requested
    if filter_core
      bot_templates = filter_core_templates(bot_templates)
      puts "🔍 Filtered to #{bot_templates.size} CORE templates"
      @stats[:filtered_out] = @stats[:total] - bot_templates.size
      puts
    end

    # Migrate each template
    bot_templates.each_with_index do |bot_template, index|
      migrate_template(account, bot_template, index + 1, bot_templates.size)
    end

    # Print summary
    print_summary

    true
  end

  private

  def filter_core_templates(templates)
    # Core template patterns (from filter_core_templates.rb)
    core_keywords = %w[guitar shop store order wismo ship music acoustic]

    templates.select do |template|
      name = template['name'] || template['request_id'] || ''

      # Check for core keywords
      has_core_keyword = core_keywords.any? { |keyword| name.downcase.include?(keyword) }

      # Exclude test patterns
      is_test = name.match?(/^(ap|tp|form)\d{3,4}$/) ||
                name.match?(/^\d+_/) ||
                name.match?(/test|sqa|nonalpha|backslash|empty|bad/i) ||
                name.match?(/card_dispute|triage_|airline/i)

      has_core_keyword && !is_test
    end
  end

  def migrate_template(account, bot_template, current, total)
    template_name = bot_template['name'] || bot_template['request_id'] || "template_#{current}"

    print "[#{current}/#{total}] Migrating '#{template_name}'... "

    # Check if template already exists
    existing = account.message_templates.find_by(name: template_name)
    if existing && !force
      puts '⏭️  SKIPPED (already exists)'
      @stats[:skipped] += 1
      return
    end

    # Map bot template to message template format
    message_template_data = map_bot_template_to_message_template(bot_template, template_name)

    if dry_run
      puts '✓ DRY RUN (would create)'
      @stats[:created] += 1
      return
    end

    # Create or update template
    begin
      if existing && force
        existing.update!(message_template_data)
        puts '✓ UPDATED'
      else
        account.message_templates.create!(message_template_data)
        puts '✓ CREATED'
      end
      @stats[:created] += 1
    rescue StandardError => e
      puts "❌ ERROR: #{e.message}"
      @stats[:errors] += 1
    end
  end

  def map_bot_template_to_message_template(bot_template, template_name)
    content_type = bot_template['content_type'] || 'text'

    # Determine category based on content type
    category = case content_type
               when 'list_picker' then 'interactive'
               when 'time_picker' then 'interactive'
               when 'apple_pay' then 'payment'
               when 'form' then 'form'
               when 'rich_link' then 'media'
               else 'general'
               end

    # Extract description
    description = bot_template['description'] ||
                  bot_template['title'] ||
                  "Migrated from bot: #{bot_name}"

    # Build tags
    tags = ['migrated', 'bot', bot_name.parameterize]
    tags << content_type if content_type != 'text'
    tags += (bot_template['tags'] || [])

    {
      name: template_name,
      category: category,
      description: description,
      status: 'active',
      supported_channels: ['apple_messages_for_business'],
      tags: tags.uniq,
      use_cases: ['bot_api_only'], # Bot API only - not visible in agent UI
      metadata: {
        migrated_from: 'agent_bot',
        bot_name: bot_name,
        original_request_id: bot_template['request_id'],
        content_type: content_type,
        migration_date: Time.current.iso8601,
        apple_message_content: bot_template # Store original bot template in metadata
      }
    }
  end

  def print_summary
    puts
    puts '=' * 80
    puts 'Migration Summary'
    puts '=' * 80
    puts "Total templates: #{@stats[:total]}"
    puts "Filtered out: #{@stats[:filtered_out]}" if filter_core
    puts "Created/Updated: #{@stats[:created]}"
    puts "Skipped: #{@stats[:skipped]}"
    puts "Errors: #{@stats[:errors]}"
    puts '=' * 80
    puts

    if dry_run
      puts '⚠️  This was a DRY RUN - no changes were saved'
      puts 'Run without --dry-run to apply changes'
    elsif @stats[:errors] > 0
      puts "⚠️  Migration completed with #{@stats[:errors]} errors"
    else
      puts '✅ Migration completed successfully!'
    end
    puts
  end
end

# Parse command line arguments
options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: rails runner script/migrate_bot_templates_to_message_templates.rb [options]'

  opts.on('--bot-name NAME', 'Name of the AgentBot (required)') do |name|
    options[:bot_name] = name
  end

  opts.on('--account-id ID', Integer, 'Account ID (required)') do |id|
    options[:account_id] = id
  end

  opts.on('--dry-run', 'Preview changes without saving') do
    options[:dry_run] = true
  end

  opts.on('--force', 'Overwrite existing templates') do
    options[:force] = true
  end

  opts.on('--filter-core', 'Only migrate CORE templates') do
    options[:filter_core] = true
  end

  opts.on('-h', '--help', 'Show this help message') do
    puts opts
    exit
  end
end.parse!

# Validate required options
unless options[:bot_name] && options[:account_id]
  puts '❌ Error: --bot-name and --account-id are required'
  puts 'Run with --help for usage information'
  exit 1
end

# Run migration
migrator = BotTemplateToMessageTemplateMigrator.new(
  bot_name: options[:bot_name],
  account_id: options[:account_id],
  dry_run: options[:dry_run] || false,
  force: options[:force] || false,
  filter_core: options[:filter_core] || false
)

success = migrator.migrate!
exit(success ? 0 : 1)
