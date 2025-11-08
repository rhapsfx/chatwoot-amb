#!/usr/bin/env ruby
# frozen_string_literal: true

# Apple Messages Bot Import Script
# Imports migrated bot data into Chatwoot database
#
# Prerequisites:
#   - Run migrate_apple_bot.rb first
#   - Migration data in tmp/bot_migration/
#
# Usage:
#   rails runner scripts/import_migrated_bots.rb [--business TYPE] [--account-id ID] [--dry-run]

require 'json'

class MigratedBotImporter
  attr_reader :options, :stats

  def initialize(options = {})
    @options = options
    @stats = {
      bots_created: 0,
      bots_would_create: 0,
      templates_created: 0,
      templates_would_create: 0,
      images_uploaded: 0,
      images_would_upload: 0,
      errors: []
    }
  end

  def run
    puts '🚀 Importing Migrated Bot Data to Chatwoot'
    puts '=' * 60
    if dry_run?
      puts '⚠️  DRY-RUN MODE - No changes will be made'
      puts '=' * 60
    end
    puts "Account ID: #{@options[:account_id]}" if @options[:account_id]
    puts

    account = find_or_prompt_account
    return unless account

    business_types = @options[:business] ? [@options[:business]] : %w[acoustic_house acoustic_shack telco]

    business_types.each do |business_name|
      puts "🏢 Importing: #{business_name.upcase}"
      puts '-' * 60

      migration_file = find_migration_file(business_name)
      unless migration_file
        puts "  ⚠️  No migration data found for #{business_name}"
        next
      end

      import_business(account, business_name, migration_file)
      puts
    end

    print_summary
  end

  private

  def dry_run?
    @options[:dry_run] == true
  end

  def find_or_prompt_account
    if @options[:account_id]
      account = Account.find_by(id: @options[:account_id])
      if dry_run? && account
        puts "✓ Found account: #{account.name} (ID: #{account.id})"
      elsif dry_run?
        puts "✗ Account ID #{@options[:account_id]} not found"
      end
      account
    else
      # Prompt for account ID
      puts 'Available accounts:'
      Account.order(:id).limit(10).each do |account|
        puts "  #{account.id}: #{account.name}"
      end
      puts
      print 'Enter account ID: '
      account_id = $stdin.gets.chomp.to_i
      account = Account.find_by(id: account_id)
      puts "✓ Would use account: #{account.name} (ID: #{account.id})" if dry_run? && account
      account
    end
  end

  def find_migration_file(business_name)
    filepath = File.join('tmp', 'bot_migration', business_name, 'migration_data.json')
    return filepath if File.exist?(filepath)

    nil
  end

  def import_business(account, business_name, migration_file)
    data = JSON.parse(File.read(migration_file))

    if dry_run?
      preview_business_import(account, business_name, data)
    else
      execute_business_import(account, business_name, data)
    end
  end

  def preview_business_import(account, business_name, data)
    bot_name = business_name.titleize.tr('_', ' ')

    # Check if bot already exists
    existing_bot = AgentBot.find_by(account: account, name: bot_name)

    if existing_bot
      puts "  📋 Would update existing bot: #{bot_name} (ID: #{existing_bot.id})"
    else
      puts "  ➕ Would create new bot: #{bot_name}"
      @stats[:bots_would_create] += 1
    end

    puts "     Description: Migrated from #{bot_name} Flask bot"
    puts '     Bot type: webhook'
    puts "     Business type: #{business_name}"
    puts "     Migrated at: #{data['migrated_at']}"
    puts

    # Preview templates
    puts "  📄 Would import #{data['payloads'].size} templates:"
    data['payloads'].first(5).each do |payload_data|
      template = payload_data['template']
      puts "     • #{template['name']}"
      puts "       - Request ID: #{payload_data['request_id']}"
      puts "       - Content Type: #{template['content_type']}"
      puts "       - Language: #{payload_data['language']}"
      @stats[:templates_would_create] += 1
    end

    if data['payloads'].size > 5
      remaining = data['payloads'].size - 5
      puts "     ... and #{remaining} more templates"
      @stats[:templates_would_create] += remaining
    end
    puts

    # Preview images
    preview_images(business_name)
  end

  def execute_business_import(account, business_name, data)
    # Create or find AgentBot
    bot = create_or_update_bot(account, business_name, data)
    return unless bot

    puts "  ✅ Bot created: #{bot.name} (ID: #{bot.id})"

    # Import templates
    data['payloads'].each do |payload_data|
      import_template(account, bot, business_name, payload_data)
    end

    # Import images
    import_images(account, business_name)
  end

  def create_or_update_bot(account, business_name, data)
    bot_name = business_name.titleize.tr('_', ' ')
    description = "Migrated from #{bot_name} Flask bot"

    bot = AgentBot.find_or_create_by!(account: account, name: bot_name) do |b|
      b.description = description
      b.bot_type = :webhook
      b.outgoing_url = '' # Set webhook URL later
      b.bot_config = {
        business_type: business_name,
        migrated_at: data['migrated_at'],
        original_system: 'acoustic_house_flask'
      }
    end

    @stats[:bots_created] += 1 if bot.previously_new_record?
    bot
  rescue StandardError => e
    @stats[:errors] << "Failed to create bot for #{business_name}: #{e.message}"
    nil
  end

  def import_template(_account, bot, _business_name, payload_data)
    template = payload_data['template']
    request_id = payload_data['request_id']

    puts "  📄 Importing: #{template['name']}"

    # Store template in bot_config
    bot.bot_config ||= {}
    bot.bot_config['templates'] ||= []

    template_entry = {
      name: template['name'],
      request_id: request_id,
      content_type: template['content_type'],
      language: payload_data['language'],
      content: template['content'],
      content_attributes: template['content_attributes'],
      migrated_from: payload_data['original_file']
    }

    bot.bot_config['templates'] << template_entry
    bot.save!

    @stats[:templates_created] += 1
    puts '     ✅ Template imported'
  rescue StandardError => e
    @stats[:errors] << "Failed to import template #{template['name']}: #{e.message}"
    puts "     ❌ Error: #{e.message}"
  end

  def preview_images(business_name)
    images_dir = File.join('tmp', 'bot_migration', business_name, 'images')
    return unless Dir.exist?(images_dir)

    image_files = Dir.glob(File.join(images_dir, '*.png'))
    return if image_files.empty?

    puts "  🖼️  Would import #{image_files.size} images:"

    image_files.first(5).each do |image_path|
      filename = File.basename(image_path)
      file_size = (File.size(image_path) / 1024.0).round(2)
      puts "     • #{filename} (#{file_size} KB)"
      @stats[:images_would_upload] += 1
    end

    if image_files.size > 5
      remaining = image_files.size - 5
      puts "     ... and #{remaining} more images"
      @stats[:images_would_upload] += remaining
    end
    puts
  end

  def import_images(account, business_name)
    images_dir = File.join('tmp', 'bot_migration', business_name, 'images')
    return unless Dir.exist?(images_dir)

    puts '  🖼️  Importing images...'

    Dir.glob(File.join(images_dir, '*.png')).each do |image_path|
      import_image(account, image_path)
    end
  end

  def import_image(account, image_path)
    filename = File.basename(image_path)

    # Create AppleListPickerImage record
    image = AppleListPickerImage.create!(
      account: account,
      data: File.read(image_path) # ActiveStorage will handle encoding
    )

    @stats[:images_uploaded] += 1
    puts "     💾 Uploaded: #{filename} → ID: #{image.id}"
  rescue StandardError => e
    @stats[:errors] << "Failed to upload image #{filename}: #{e.message}"
    puts "     ❌ Error uploading #{filename}: #{e.message}"
  end

  def print_summary
    puts
    puts '=' * 60
    if dry_run?
      puts '📊 Dry-Run Preview Summary'
    else
      puts '📊 Import Summary'
    end
    puts '=' * 60

    if dry_run?
      puts "Would create bots: #{@stats[:bots_would_create]}"
      puts "Would create templates: #{@stats[:templates_would_create]}"
      puts "Would upload images: #{@stats[:images_would_upload]}"

      total_changes = @stats[:bots_would_create] + @stats[:templates_would_create] + @stats[:images_would_upload]
      puts
      puts "Total changes that would be made: #{total_changes}"
    else
      puts "Bots created: #{@stats[:bots_created]}"
      puts "Templates created: #{@stats[:templates_created]}"
      puts "Images uploaded: #{@stats[:images_uploaded]}"
    end

    if @stats[:errors].any?
      puts
      puts "❌ Errors (#{@stats[:errors].size}):"
      @stats[:errors].each { |error| puts "  - #{error}" }
    end

    puts
    if dry_run?
      puts 'ℹ️  This was a preview only - no changes were made'
      puts
      puts '📋 To execute the import:'
      cmd = 'rails runner scripts/import_migrated_bots.rb'
      cmd += " --account-id #{@options[:account_id]}" if @options[:account_id]
      cmd += " --business #{@options[:business]}" if @options[:business]
      puts "  #{cmd}"
    else
      puts '✨ Import complete!'
      puts
      puts '📋 Next steps:'
      puts '  1. Configure bot webhook URLs in admin panel'
      puts '  2. Assign bots to inboxes'
      puts '  3. Test bot flows with sample conversations'
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

# Run import
importer = MigratedBotImporter.new(options)
importer.run
