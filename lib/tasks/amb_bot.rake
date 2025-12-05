# frozen_string_literal: true

namespace :amb_bot do
  desc 'Verify AMB bot configuration and templates'
  task verify: :environment do
    puts '=== AMB Bot Configuration Verification ==='
    puts

    AgentBot.amb_bots.find_each do |bot|
      puts "Bot: #{bot.name} (ID: #{bot.id})"
      puts "  Account: #{bot.account&.name || 'System Bot'}"
      puts "  Active Version: #{bot.active_version&.version_tag || 'None'}"
      puts

      # Verify config structure
      config = bot.effective_config
      required_keys = %w[conversation_flow keyword_mappings interactive_handlers required_templates]
      missing_keys = required_keys - config.keys

      if missing_keys.empty?
        puts '  ✅ Config structure valid'
      else
        puts "  ❌ Missing config keys: #{missing_keys.join(', ')}"
      end

      # Verify templates
      if config.dig('required_templates', 'list').present?
        templates = config['required_templates']['list']
        puts "  Templates Required: #{templates.size}"

        templates.each do |template_name|
          template = MessageTemplate.find_by(account_id: bot.account_id, name: template_name)
          if template
            puts "    ✅ #{template_name}"
          else
            puts "    ❌ #{template_name} (NOT FOUND)"
          end
        end
      end

      # Verify inbox associations
      puts "  Inbox Associations: #{bot.agent_bot_inboxes.active_bots.count}"
      bot.agent_bot_inboxes.active_bots.each do |assoc|
        puts "    - Inbox ##{assoc.inbox_id} (Priority: #{assoc.priority}, Version: #{assoc.version&.version_tag || 'default'})"
      end

      puts
    end
  end

  desc 'Migrate existing bot config to versioned system'
  task migrate_to_versions: :environment do
    puts '=== Migrating Existing Bots to Versioned System ==='
    puts

    dry_run = ENV['DRY_RUN'] != 'false'
    puts "Mode: #{dry_run ? 'DRY RUN' : 'LIVE'}"
    puts

    AgentBot.amb_bots.find_each do |bot|
      puts "Processing Bot: #{bot.name} (ID: #{bot.id})"

      # Check if already has versions
      if bot.versions.exists?
        puts '  ⚠️  Already has versions, skipping'
        puts
        next
      end

      # Create initial version from bot_config
      if bot.bot_config.present?
        if dry_run
          puts '  Would create version: v1.0'
          puts "    Config keys: #{bot.bot_config.keys.join(', ')}"
        else
          version = bot.create_version!(
            version_tag: 'v1.0',
            config: bot.bot_config,
            description: 'Initial version (migrated from bot_config)',
            notes: "Auto-migrated on #{Time.current}",
            activate: true,
            set_default: true
          )
          puts "  ✅ Created version: #{version.version_tag}"
        end
      else
        puts '  ⚠️  No bot_config found, skipping'
      end

      puts
    end

    if dry_run
      puts
      puts 'To execute migration, run: DRY_RUN=false rails amb_bot:migrate_to_versions'
    end
  end

  desc 'Create a new bot version'
  task create_version: :environment do
    bot_id = ENV.fetch('BOT_ID', nil)
    version_tag = ENV.fetch('VERSION_TAG', nil)
    description = ENV.fetch('DESCRIPTION', nil)

    unless bot_id && version_tag
      puts 'Usage: BOT_ID=<id> VERSION_TAG=<tag> [DESCRIPTION=<desc>] rails amb_bot:create_version'
      exit 1
    end

    bot = AgentBot.find_by(id: bot_id, bot_type: :apple_messages_for_business)
    unless bot
      puts "Error: AMB Bot with ID #{bot_id} not found"
      exit 1
    end

    # Use bot's current bot_config as base for new version
    config = bot.bot_config

    version = bot.create_version!(
      version_tag: version_tag,
      config: config,
      description: description,
      activate: false,
      set_default: false
    )

    puts "✅ Created version: #{version.version_tag} for bot: #{bot.name}"
    puts "   To activate: rails amb_bot:activate_version BOT_ID=#{bot_id} VERSION_TAG=#{version_tag}"
  rescue StandardError => e
    puts "❌ Error: #{e.message}"
    exit 1
  end

  desc 'Activate a bot version'
  task activate_version: :environment do
    bot_id = ENV.fetch('BOT_ID', nil)
    version_tag = ENV.fetch('VERSION_TAG', nil)

    unless bot_id && version_tag
      puts 'Usage: BOT_ID=<id> VERSION_TAG=<tag> rails amb_bot:activate_version'
      exit 1
    end

    bot = AgentBot.find_by(id: bot_id, bot_type: :apple_messages_for_business)
    unless bot
      puts "Error: AMB Bot with ID #{bot_id} not found"
      exit 1
    end

    bot.activate_version!(version_tag)
    puts "✅ Activated version: #{version_tag} for bot: #{bot.name}"
  rescue StandardError => e
    puts "❌ Error: #{e.message}"
    exit 1
  end

  desc 'List all bot versions'
  task list_versions: :environment do
    bot_id = ENV.fetch('BOT_ID', nil)

    unless bot_id
      puts 'Usage: BOT_ID=<id> rails amb_bot:list_versions'
      exit 1
    end

    bot = AgentBot.find_by(id: bot_id, bot_type: :apple_messages_for_business)
    unless bot
      puts "Error: AMB Bot with ID #{bot_id} not found"
      exit 1
    end

    puts "Bot: #{bot.name} (ID: #{bot.id})"
    puts

    bot.versions.ordered.each do |version|
      status_flags = []
      status_flags << 'ACTIVE' if version.is_active
      status_flags << 'DEFAULT' if version.is_default
      status_str = status_flags.any? ? " [#{status_flags.join(', ')}]" : ''

      puts "#{version.version_tag}#{status_str}"
      puts "  Description: #{version.description}" if version.description
      puts "  Created: #{version.created_at.strftime('%Y-%m-%d %H:%M')}"
      puts "  Activated: #{version.activated_at.strftime('%Y-%m-%d %H:%M')}" if version.activated_at
      puts "  Config keys: #{version.config.keys.join(', ')}"
      puts
    end
  end

  desc 'Set inbox-specific bot version'
  task set_inbox_version: :environment do
    bot_id = ENV.fetch('BOT_ID', nil)
    inbox_id = ENV.fetch('INBOX_ID', nil)
    version_tag = ENV.fetch('VERSION_TAG', nil)

    unless bot_id && inbox_id && version_tag
      puts 'Usage: BOT_ID=<id> INBOX_ID=<id> VERSION_TAG=<tag> rails amb_bot:set_inbox_version'
      exit 1
    end

    bot = AgentBot.find_by(id: bot_id, bot_type: :apple_messages_for_business)
    unless bot
      puts "Error: AMB Bot with ID #{bot_id} not found"
      exit 1
    end

    inbox_assoc = bot.agent_bot_inboxes.find_by(inbox_id: inbox_id)
    unless inbox_assoc
      puts "Error: Bot not associated with inbox #{inbox_id}"
      exit 1
    end

    inbox_assoc.set_version!(version_tag)
    puts "✅ Set version #{version_tag} for inbox #{inbox_id}"
  rescue StandardError => e
    puts "❌ Error: #{e.message}"
    exit 1
  end

  desc 'Validate all AMB bot configurations'
  task validate_all: :environment do
    puts '=== Validating All AMB Bot Configurations ==='
    puts

    errors = []

    AgentBot.amb_bots.find_each do |bot|
      puts "Validating: #{bot.name} (ID: #{bot.id})"

      # Validate bot config
      if bot.valid?
        puts '  ✅ Bot configuration valid'
      else
        puts '  ❌ Bot validation failed:'
        bot.errors.full_messages.each { |msg| puts "    - #{msg}" }
        errors << "Bot #{bot.id}: #{bot.errors.full_messages.join(', ')}"
      end

      # Validate versions
      bot.versions.each do |version|
        if version.valid?
          puts "  ✅ Version #{version.version_tag} valid"
        else
          puts "  ❌ Version #{version.version_tag} validation failed:"
          version.errors.full_messages.each { |msg| puts "    - #{msg}" }
          errors << "Bot #{bot.id} Version #{version.version_tag}: #{version.errors.full_messages.join(', ')}"
        end
      end

      puts
    end

    if errors.any?
      puts
      puts '❌ Validation failed with errors:'
      errors.each { |err| puts "  - #{err}" }
      exit 1
    else
      puts '✅ All configurations valid'
    end
  end

  desc 'Show statistics for AMB bots'
  task stats: :environment do
    puts '=== AMB Bot Statistics ==='
    puts

    total_bots = AgentBot.amb_bots.count
    system_bots = AgentBot.amb_bots.where(account_id: nil).count
    account_bots = AgentBot.amb_bots.where.not(account_id: nil).count

    puts "Total AMB Bots: #{total_bots}"
    puts "  System Bots: #{system_bots}"
    puts "  Account Bots: #{account_bots}"
    puts

    bots_with_versions = AgentBot.amb_bots.with_active_versions.count
    puts "Bots with Active Versions: #{bots_with_versions}"
    puts

    total_versions = AgentBotVersion.count
    active_versions = AgentBotVersion.active.count
    puts "Total Versions: #{total_versions}"
    puts "  Active: #{active_versions}"
    puts

    total_associations = AgentBotInbox.joins(:agent_bot).merge(AgentBot.amb_bots).count
    active_associations = AgentBotInbox.joins(:agent_bot).merge(AgentBot.amb_bots).active_bots.count
    with_version = AgentBotInbox.joins(:agent_bot).merge(AgentBot.amb_bots).with_version.count

    puts "Bot-Inbox Associations: #{total_associations}"
    puts "  Active: #{active_associations}"
    puts "  With Specific Version: #{with_version}"
  end
end
