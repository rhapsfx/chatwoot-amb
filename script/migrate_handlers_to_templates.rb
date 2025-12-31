#!/usr/bin/env ruby
# frozen_string_literal: true

# Migration script to convert existing handlers to action templates
# Usage: rails runner script/migrate_handlers_to_templates.rb [--execute]
#
# By default runs in dry-run mode. Pass --execute to actually create templates.

require 'json'

# Handler to template mappings
# Each handler maps to one or more action templates that execute in sequence
HANDLER_MAPPINGS = {
  handle_welcome: [
    {
      name: 'welcome_message_1',
      template_type: 'send_text_message',
      parameters: {
        'message' => 'Thank you for contacting Acoustic Bot Prod.'
      },
      execution_order: 0
    },
    {
      name: 'welcome_message_2',
      template_type: 'send_text_message',
      parameters: {
        'message' => "Let's help you find your next guitar 🎸."
      },
      execution_order: 1
    },
    {
      name: 'welcome_region_prompt',
      template_type: 'send_quick_reply',
      parameters: {
        'message' => 'Which region are you traveling from?',
        'request_id' => 'qr_travel',
        'items' => [
          { 'title' => 'Americas', 'value' => 'Americas' },
          { 'title' => 'EMEA', 'value' => 'EMEA' },
          { 'title' => 'APAC', 'value' => 'APAC' }
        ]
      },
      execution_order: 2
    }
  ],

  handle_menu: [
    {
      name: 'menu_list_picker',
      template_type: 'send_list_picker',
      parameters: {
        # Will be filled in with actual template ID during migration
        'template_id' => 'PLACEHOLDER_ah_main_menu',
        'wait_for_response' => true
      },
      execution_order: 0
    }
  ],

  handle_list_picker_demo: [
    {
      name: 'list_picker_demo_intro',
      template_type: 'send_text_message',
      parameters: {
        'message' => 'Here are some amazing guitars:'
      },
      execution_order: 0
    },
    {
      name: 'list_picker_demo_picker',
      template_type: 'send_list_picker',
      parameters: {
        'template_id' => 'PLACEHOLDER_ah_guitar_list_picker',
        'wait_for_response' => true
      },
      execution_order: 1
    }
  ],

  handle_time_picker_demo: [
    {
      name: 'time_picker_demo_intro',
      template_type: 'send_text_message',
      parameters: {
        'message' => "Here's a time picker demo:"
      },
      execution_order: 0
    },
    {
      name: 'time_picker_demo_picker',
      template_type: 'send_time_picker',
      parameters: {
        'template_id' => 'PLACEHOLDER_time_picker_template',
        'timezone_offset' => -28_800, # Pacific Time
        'location_data' => {
          'name' => 'Apple Park',
          'latitude' => 37.334606,
          'longitude' => -122.009102
        }
      },
      execution_order: 1
    }
  ],

  handle_form_demo: [
    {
      name: 'form_demo_intro',
      template_type: 'send_text_message',
      parameters: {
        'message' => "Here's our guitar information form:"
      },
      execution_order: 0
    },
    {
      name: 'form_demo_form',
      template_type: 'send_form',
      parameters: {
        'template_id' => 'PLACEHOLDER_ah_guitar_info_form'
      },
      execution_order: 1
    }
  ],

  handle_apple_pay_demo: [
    {
      name: 'apple_pay_demo_intro',
      template_type: 'send_text_message',
      parameters: {
        'message' => "Here's an Apple Pay payment request:"
      },
      execution_order: 0
    },
    {
      name: 'apple_pay_demo_request',
      template_type: 'send_apple_pay',
      parameters: {
        'merchant_id' => 'merchant.com.example',
        'item_name' => 'Demo Guitar - Fender Stratocaster',
        'amount' => 1299.99,
        'currency' => 'USD'
      },
      execution_order: 1
    }
  ],

  handle_ar_demo: [
    {
      name: 'ar_demo_intro',
      template_type: 'send_text_message',
      parameters: {
        'message' => 'Check out our AR experience:'
      },
      execution_order: 0
    },
    {
      name: 'ar_demo_link',
      template_type: 'send_rich_link',
      parameters: {
        'url' => 'https://example.com/ar/guitar',
        'title' => 'View Guitar in AR',
        'subtitle' => 'See the guitar in your space',
        'image_url' => 'https://example.com/ar-preview.png'
      },
      execution_order: 1
    }
  ],

  handle_imessage_app: [
    {
      name: 'imessage_app_intro',
      template_type: 'send_text_message',
      parameters: {
        'message' => 'Here are some iMessage apps you can try:'
      },
      execution_order: 0
    },
    {
      name: 'imessage_app_shazam',
      template_type: 'send_imessage_app',
      parameters: {
        'app_id' => 'com.shazam.Shazam.MessagesExtension',
        'app_name' => 'Shazam',
        'app_icon_url' => 'https://example.com/shazam-icon.png',
        'launch_url' => 'shazam://identify'
      },
      execution_order: 1
    }
  ],

  handle_app_clip_demo: [
    {
      name: 'app_clip_demo_intro',
      template_type: 'send_text_message',
      parameters: {
        'message' => 'Try our App Clip experience:'
      },
      execution_order: 0
    },
    {
      name: 'app_clip_demo_clip',
      template_type: 'send_app_clip',
      parameters: {
        'app_clip_url' => 'https://acoustichouse.example.com/clips/guitar-tuner',
        'title' => 'Acoustic House Guitar Tuner',
        'subtitle' => 'Tune your guitar without installing an app',
        'image_url' => 'https://example.com/tuner-hero.png',
        'action_title' => 'Try Now'
      },
      execution_order: 1
    }
  ],

  handle_region_selection: [
    {
      name: 'region_store_attribute',
      template_type: 'update_attributes',
      parameters: {
        'attributes' => {
          'selected_region' => '{{user_selection}}'
        }
      },
      execution_order: 0
    },
    {
      name: 'region_confirmation',
      template_type: 'send_text_message',
      parameters: {
        'message' => "Great! You're traveling from {{region}}."
      },
      execution_order: 1
    }
  ],

  handle_guitar_selection: [
    {
      name: 'guitar_store_attribute',
      template_type: 'update_attributes',
      parameters: {
        'attributes' => {
          'selected_guitar' => '{{user_selection}}'
        }
      },
      execution_order: 0
    },
    {
      name: 'guitar_confirmation',
      template_type: 'send_text_message',
      parameters: {
        'message' => 'Excellent choice! The {{guitar}} is a fantastic instrument.'
      },
      execution_order: 1
    }
  ],

  handle_store_selection: [
    {
      name: 'store_save_attribute',
      template_type: 'update_attributes',
      parameters: {
        'attributes' => {
          'selected_store' => '{{user_selection}}'
        }
      },
      execution_order: 0
    },
    {
      name: 'store_send_time_picker',
      template_type: 'send_time_picker',
      parameters: {
        'template_id' => 'PLACEHOLDER_time_picker_template',
        'timezone_offset' => '{{store_timezone}}'
      },
      execution_order: 1
    }
  ]
}.freeze

class HandlerToTemplateMigration
  def initialize(dry_run: true)
    @dry_run = dry_run
    @stats = {
      accounts_processed: 0,
      templates_created: 0,
      templates_skipped: 0,
      errors: []
    }
  end

  def run
    puts '=' * 80
    puts 'Handler to Template Migration'
    puts '=' * 80
    puts "Mode: #{@dry_run ? 'DRY RUN' : 'EXECUTE'}"
    puts

    Account.find_each do |account|
      process_account(account)
    end

    print_summary
  end

  private

  def process_account(account)
    puts "\n--- Processing Account: #{account.name} (ID: #{account.id}) ---"

    # Resolve template placeholders
    template_map = resolve_template_placeholders(account)

    HANDLER_MAPPINGS.each do |handler_name, template_configs|
      template_configs.each do |config|
        process_template(account, handler_name, config, template_map)
      end
    end

    @stats[:accounts_processed] += 1
  end

  def resolve_template_placeholders(account)
    # Map placeholder names to actual template IDs for this account
    template_names = %w[
      ah_main_menu
      ah_guitar_list_picker
      ah_guitar_info_form
      time_picker_template
    ]

    map = {}
    template_names.each do |name|
      template = MessageTemplate.find_by(account: account, name: name)
      if template
        map["PLACEHOLDER_#{name}"] = template.id
      else
        puts "  ⚠️  Warning: Template '#{name}' not found for account #{account.id}"
      end
    end

    map
  end

  def process_template(account, handler_name, config, template_map)
    template_name = "#{handler_name}_#{config[:name]}"

    # Check if template already exists
    existing = BotActionTemplate.find_by(account: account, name: template_name)
    if existing
      puts "  ⏭️  Skipping #{template_name} (already exists)"
      @stats[:templates_skipped] += 1
      return
    end

    # Replace placeholders with actual template IDs
    parameters = deep_replace_placeholders(config[:parameters], template_map)

    if @dry_run
      puts "  📋 Would create: #{template_name}"
      puts "     Type: #{config[:template_type]}"
      puts "     Parameters: #{parameters.inspect}"
    else
      begin
        BotActionTemplate.create!(
          account: account,
          name: template_name,
          template_type: config[:template_type],
          parameters: parameters,
          execution_order: config[:execution_order],
          metadata: {
            migrated_from: handler_name.to_s,
            migration_date: Time.current.iso8601
          }
        )
        puts "  ✅ Created: #{template_name}"
        @stats[:templates_created] += 1
      rescue StandardError => e
        error_msg = "Failed to create #{template_name}: #{e.message}"
        puts "  ❌ #{error_msg}"
        @stats[:errors] << error_msg
      end
    end
  end

  def deep_replace_placeholders(obj, template_map)
    case obj
    when Hash
      obj.transform_values { |v| deep_replace_placeholders(v, template_map) }
    when Array
      obj.map { |v| deep_replace_placeholders(v, template_map) }
    when String
      template_map[obj] || obj
    else
      obj
    end
  end

  def print_summary
    puts "\n" + ('=' * 80)
    puts 'Migration Summary'
    puts '=' * 80
    puts "Accounts processed: #{@stats[:accounts_processed]}"
    puts "Templates created: #{@stats[:templates_created]}"
    puts "Templates skipped: #{@stats[:templates_skipped]}"
    puts "Errors: #{@stats[:errors].count}"

    if @stats[:errors].any?
      puts "\nErrors:"
      @stats[:errors].each do |error|
        puts "  - #{error}"
      end
    end

    if @dry_run
      puts "\n⚠️  This was a DRY RUN. No changes were made."
      puts '   Run with --execute to apply changes.'
    else
      puts "\n✅ Migration complete!"
    end
    puts '=' * 80
  end
end

# Run migration
dry_run = !ARGV.include?('--execute')
migration = HandlerToTemplateMigration.new(dry_run: dry_run)
migration.run
