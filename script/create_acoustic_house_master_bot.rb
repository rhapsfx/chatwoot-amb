#!/usr/bin/env ruby
# frozen_string_literal: true

# Master Bot Creator - Acoustic House Reference Bot
# Creates a complete reference bot demonstrating all 12 template types
# Usage: rails runner script/create_acoustic_house_master_bot.rb [--account-id=N] [--execute]
#
# This script creates:
# - 1 AgentBot with complete visual flow
# - 29 BotActionTemplates (all 12 template types)
# - 1 BotFlow with nodes and edges
# - Complete conversation flow from welcome to completion
#
# By default runs in dry-run mode. Pass --execute to actually create the bot.

require 'json'

class MasterBotCreator
  MASTER_BOT_NAME = 'Acoustic House Master Bot'
  MASTER_BOT_DESCRIPTION = 'Complete reference bot demonstrating all 12 template types with visual flow'

  def initialize(account_id: nil, dry_run: true)
    @account_id = account_id
    @dry_run = dry_run
    @stats = {
      agent_bots_created: 0,
      bot_flows_created: 0,
      templates_created: 0,
      errors: []
    }
    @created_template_ids = {}
  end

  def run
    print_header

    @account = find_or_validate_account
    return unless @account

    create_master_bot
    print_summary
  end

  private

  def find_or_validate_account
    if @account_id
      account = Account.find_by(id: @account_id)
      unless account
        error("Account with ID #{@account_id} not found")
        return nil
      end
      puts "Using specified account: #{account.name} (ID: #{account.id})"
      account
    else
      accounts = Account.all.to_a
      if accounts.empty?
        error('No accounts found in database')
        return nil
      elsif accounts.size == 1
        account = accounts.first
        puts "Using only available account: #{account.name} (ID: #{account.id})"
        account
      else
        error('Multiple accounts found. Please specify --account-id=N')
        puts "\nAvailable accounts:"
        accounts.each do |acc|
          puts "  - ID #{acc.id}: #{acc.name}"
        end
        nil
      end
    end
  end

  def create_master_bot
    puts "\n--- Creating Master Bot for Account: #{@account.name} (ID: #{@account.id}) ---\n\n"

    # Step 1: Create all templates
    puts "Step 1: Creating Templates\n"
    create_all_templates

    # Step 2: Create AgentBot
    puts "\nStep 2: Creating AgentBot\n"
    agent_bot = create_agent_bot

    # Step 3: Create BotFlow with visual layout
    puts "\nStep 3: Creating BotFlow with Visual Layout\n"
    create_bot_flow(agent_bot) if agent_bot
  end

  def create_all_templates
    template_definitions.each do |template_def|
      create_template(template_def)
    end
  end

  def create_template(template_def)
    name = template_def[:name]

    # Check if template already exists
    existing = BotActionTemplate.find_by(account: @account, name: name)
    if existing
      puts "  ⏭️  Skipping #{name} (already exists)"
      @created_template_ids[name] = existing.id
      return existing
    end

    if @dry_run
      puts "  📋 Would create: #{name}"
      puts "     Type: #{template_def[:template_type]}"
      puts "     Parameters: #{template_def[:parameters].keys.join(', ')}"
      @created_template_ids[name] = "(dry-run-id-#{name})"
      return nil
    else
      begin
        template = BotActionTemplate.create!(
          account: @account,
          name: name,
          template_type: template_def[:template_type],
          parameters: template_def[:parameters],
          execution_order: template_def[:execution_order],
          metadata: {
            created_by: 'master_bot_creator',
            creation_date: Time.current.iso8601,
            description: template_def[:description]
          }
        )
        puts "  ✅ Created: #{name}"
        @stats[:templates_created] += 1
        @created_template_ids[name] = template.id
        template
      rescue StandardError => e
        error_msg = "Failed to create template #{name}: #{e.message}"
        puts "  ❌ #{error_msg}"
        @stats[:errors] << error_msg
        nil
      end
    end
  end

  def create_agent_bot
    # Check if bot already exists
    existing = AgentBot.find_by(account: @account, name: MASTER_BOT_NAME)
    if existing
      puts "  ⏭️  AgentBot '#{MASTER_BOT_NAME}' already exists"
      return existing
    end

    if @dry_run
      puts "  📋 Would create: AgentBot '#{MASTER_BOT_NAME}'"
      puts "     Description: #{MASTER_BOT_DESCRIPTION}"
      return nil
    else
      begin
        bot = AgentBot.create!(
          account: @account,
          name: MASTER_BOT_NAME,
          description: MASTER_BOT_DESCRIPTION,
          bot_type: 'apple_messages_for_business',
          bot_config: {
            created_by: 'master_bot_creator',
            creation_date: Time.current.iso8601
          }
        )
        puts "  ✅ Created: AgentBot '#{MASTER_BOT_NAME}'"
        @stats[:agent_bots_created] += 1
        bot
      rescue StandardError => e
        error_msg = "Failed to create AgentBot: #{e.message}"
        puts "  ❌ #{error_msg}"
        @stats[:errors] << error_msg
        nil
      end
    end
  end

  def create_bot_flow(agent_bot)
    # Check if flow already exists
    existing = BotFlow.find_by(agent_bot: agent_bot)
    if existing
      puts '  ⏭️  BotFlow already exists for AgentBot'
      return existing
    end

    flow_data = build_flow_data

    if @dry_run
      puts "  📋 Would create: BotFlow with #{flow_data['nodes'].size} nodes and #{flow_data['edges'].size} edges"
      puts "     States: #{flow_data['nodes'].count { |n| n['type'] == 'state' }}"
      puts "     Intents: #{flow_data['nodes'].count { |n| n['type'] == 'intent' }}"
      puts "     Conditions: #{flow_data['nodes'].count { |n| n['type'] == 'condition' }}"
      return nil
    else
      begin
        flow = BotFlow.create!(
          agent_bot: agent_bot,
          name: 'Acoustic House Flow',
          flow_data: flow_data,
          is_active: true,
          is_published: true,
          metadata: {
            created_by: 'master_bot_creator',
            creation_date: Time.current.iso8601,
            description: 'Complete reference flow demonstrating all template types'
          }
        )
        puts "  ✅ Created: BotFlow with #{flow_data['nodes'].size} nodes"
        @stats[:bot_flows_created] += 1
        flow
      rescue StandardError => e
        error_msg = "Failed to create BotFlow: #{e.message}"
        puts "  ❌ #{error_msg}"
        @stats[:errors] << error_msg
        nil
      end
    end
  end

  def build_flow_data
    nodes = []
    edges = []
    y_position = 100
    x_position = 100
    x_spacing = 400
    y_spacing = 200

    # Node 1: Initial Welcome State
    nodes << {
      'id' => 'state-welcome',
      'type' => 'state',
      'position' => { 'x' => x_position, 'y' => y_position },
      'data' => {
        'state_id' => 'AHA1',
        'label' => 'Welcome',
        'is_initial' => true,
        'actions' => [
          {
            'type' => 'execute_templates',
            'template_ids' => [
              @created_template_ids['welcome_text_1'],
              @created_template_ids['welcome_text_2'],
              @created_template_ids['welcome_rich_link']
            ]
          }
        ]
      }
    }

    # Node 2: Region Selection Intent
    y_position += y_spacing
    nodes << {
      'id' => 'intent-region',
      'type' => 'intent',
      'position' => { 'x' => x_position, 'y' => y_position },
      'data' => {
        'intent_id' => 'select_region',
        'label' => 'Region Selection',
        'actions' => [
          {
            'type' => 'execute_template',
            'template_id' => @created_template_ids['region_quick_reply']
          }
        ]
      }
    }

    edges << {
      'id' => 'edge-welcome-region',
      'source' => 'state-welcome',
      'target' => 'intent-region',
      'type' => 'smoothstep'
    }

    # Node 3: Region Processing State
    x_position += x_spacing
    nodes << {
      'id' => 'state-region-process',
      'type' => 'state',
      'position' => { 'x' => x_position, 'y' => y_position },
      'data' => {
        'state_id' => 'AHA2',
        'label' => 'Process Region',
        'actions' => [
          {
            'type' => 'execute_template',
            'template_id' => @created_template_ids['region_update_attributes']
          }
        ]
      }
    }

    edges << {
      'id' => 'edge-region-process',
      'source' => 'intent-region',
      'target' => 'state-region-process',
      'type' => 'smoothstep'
    }

    # Node 4: Main Menu State
    y_position += y_spacing
    x_position = 100
    nodes << {
      'id' => 'state-menu',
      'type' => 'state',
      'position' => { 'x' => x_position, 'y' => y_position },
      'data' => {
        'state_id' => 'AHA3',
        'label' => 'Main Menu',
        'actions' => [
          {
            'type' => 'execute_template',
            'template_id' => @created_template_ids['main_menu_list_picker']
          }
        ]
      }
    }

    edges << {
      'id' => 'edge-region-menu',
      'source' => 'state-region-process',
      'target' => 'state-menu',
      'type' => 'smoothstep'
    }

    # Node 5: List Picker Demo Intent
    y_position += y_spacing
    nodes << {
      'id' => 'intent-list-picker-demo',
      'type' => 'intent',
      'position' => { 'x' => x_position, 'y' => y_position },
      'data' => {
        'intent_id' => 'list_picker_demo',
        'label' => 'List Picker Demo',
        'actions' => [
          {
            'type' => 'execute_template',
            'template_id' => @created_template_ids['guitar_list_picker']
          }
        ]
      }
    }

    edges << {
      'id' => 'edge-menu-list-picker',
      'source' => 'state-menu',
      'target' => 'intent-list-picker-demo',
      'type' => 'smoothstep',
      'label' => 'Guitar Selection'
    }

    # Node 6: Time Picker Demo Intent
    x_position += x_spacing
    nodes << {
      'id' => 'intent-time-picker-demo',
      'type' => 'intent',
      'position' => { 'x' => x_position, 'y' => y_position },
      'data' => {
        'intent_id' => 'time_picker_demo',
        'label' => 'Time Picker Demo',
        'actions' => [
          {
            'type' => 'execute_template',
            'template_id' => @created_template_ids['store_time_picker']
          }
        ]
      }
    }

    edges << {
      'id' => 'edge-menu-time-picker',
      'source' => 'state-menu',
      'target' => 'intent-time-picker-demo',
      'type' => 'smoothstep',
      'label' => 'Appointment'
    }

    # Node 7: Form Demo Intent
    x_position += x_spacing
    nodes << {
      'id' => 'intent-form-demo',
      'type' => 'intent',
      'position' => { 'x' => x_position, 'y' => y_position },
      'data' => {
        'intent_id' => 'form_demo',
        'label' => 'Form Demo',
        'actions' => [
          {
            'type' => 'execute_template',
            'template_id' => @created_template_ids['guitar_info_form']
          }
        ]
      }
    }

    edges << {
      'id' => 'edge-menu-form',
      'source' => 'state-menu',
      'target' => 'intent-form-demo',
      'type' => 'smoothstep',
      'label' => 'Info Form'
    }

    # Node 8: Conditional Branch Demo
    y_position += y_spacing
    x_position = 100 + x_spacing
    nodes << {
      'id' => 'condition-check-region',
      'type' => 'condition',
      'position' => { 'x' => x_position, 'y' => y_position },
      'data' => {
        'condition_id' => 'check_region',
        'label' => 'Check Region',
        'actions' => [
          {
            'type' => 'execute_template',
            'template_id' => @created_template_ids['region_conditional_branch']
          }
        ]
      }
    }

    edges << {
      'id' => 'edge-list-picker-condition',
      'source' => 'intent-list-picker-demo',
      'target' => 'condition-check-region',
      'type' => 'smoothstep'
    }

    # Node 9: Apple Pay Demo State
    y_position += y_spacing
    x_position = 100
    nodes << {
      'id' => 'state-apple-pay',
      'type' => 'state',
      'position' => { 'x' => x_position, 'y' => y_position },
      'data' => {
        'state_id' => 'AHA4',
        'label' => 'Apple Pay Demo',
        'actions' => [
          {
            'type' => 'execute_template',
            'template_id' => @created_template_ids['guitar_apple_pay']
          }
        ]
      }
    }

    edges << {
      'id' => 'edge-condition-apple-pay',
      'source' => 'condition-check-region',
      'target' => 'state-apple-pay',
      'type' => 'smoothstep',
      'label' => 'True Branch'
    }

    # Node 10: API Call Demo State
    x_position += x_spacing
    nodes << {
      'id' => 'state-api-call',
      'type' => 'state',
      'position' => { 'x' => x_position, 'y' => y_position },
      'data' => {
        'state_id' => 'AHA5',
        'label' => 'API Call Demo',
        'actions' => [
          {
            'type' => 'execute_template',
            'template_id' => @created_template_ids['inventory_api_call']
          }
        ]
      }
    }

    edges << {
      'id' => 'edge-condition-api-call',
      'source' => 'condition-check-region',
      'target' => 'state-api-call',
      'type' => 'smoothstep',
      'label' => 'False Branch'
    }

    # Node 11: iMessage App Demo State
    y_position += y_spacing
    x_position = 100 + (x_spacing / 2)
    nodes << {
      'id' => 'state-imessage-app',
      'type' => 'state',
      'position' => { 'x' => x_position, 'y' => y_position },
      'data' => {
        'state_id' => 'AHA6',
        'label' => 'iMessage App Demo',
        'actions' => [
          {
            'type' => 'execute_template',
            'template_id' => @created_template_ids['shazam_imessage_app']
          }
        ]
      }
    }

    edges << {
      'id' => 'edge-apple-pay-imessage',
      'source' => 'state-apple-pay',
      'target' => 'state-imessage-app',
      'type' => 'smoothstep'
    }

    edges << {
      'id' => 'edge-api-call-imessage',
      'source' => 'state-api-call',
      'target' => 'state-imessage-app',
      'type' => 'smoothstep'
    }

    # Node 12: App Clip Demo State
    y_position += y_spacing
    nodes << {
      'id' => 'state-app-clip',
      'type' => 'state',
      'position' => { 'x' => x_position, 'y' => y_position },
      'data' => {
        'state_id' => 'AHA7',
        'label' => 'App Clip Demo',
        'actions' => [
          {
            'type' => 'execute_template',
            'template_id' => @created_template_ids['tuner_app_clip']
          }
        ]
      }
    }

    edges << {
      'id' => 'edge-imessage-app-clip',
      'source' => 'state-imessage-app',
      'target' => 'state-app-clip',
      'type' => 'smoothstep'
    }

    # Node 13: Completion State
    y_position += y_spacing
    nodes << {
      'id' => 'state-complete',
      'type' => 'state',
      'position' => { 'x' => x_position, 'y' => y_position },
      'data' => {
        'state_id' => 'AHA8',
        'label' => 'Complete',
        'is_final' => true,
        'actions' => [
          {
            'type' => 'execute_template',
            'template_id' => @created_template_ids['completion_text']
          }
        ]
      }
    }

    edges << {
      'id' => 'edge-app-clip-complete',
      'source' => 'state-app-clip',
      'target' => 'state-complete',
      'type' => 'smoothstep'
    }

    {
      'nodes' => nodes,
      'edges' => edges,
      'viewport' => {
        'x' => 0,
        'y' => 0,
        'zoom' => 0.75
      }
    }
  end

  def template_definitions
    [
      # 1. SEND_TEXT_MESSAGE Templates (3)
      {
        name: 'welcome_text_1',
        template_type: 'send_text_message',
        parameters: {
          'message' => 'Welcome to Acoustic House! 🎸',
          'delay_seconds' => 0
        },
        execution_order: 0,
        description: 'First welcome message'
      },
      {
        name: 'welcome_text_2',
        template_type: 'send_text_message',
        parameters: {
          'message' => "We're here to help you find your perfect guitar and explore our full range of interactive features.",
          'delay_seconds' => 1
        },
        execution_order: 1,
        description: 'Second welcome message'
      },
      {
        name: 'completion_text',
        template_type: 'send_text_message',
        parameters: {
          'message' => "Thank you for exploring all our features! We've demonstrated all 12 template types. Feel free to start over or reach out to a human agent anytime.",
          'delay_seconds' => 0
        },
        execution_order: 2,
        description: 'Completion message'
      },

      # 2. SEND_RICH_LINK Template (1)
      {
        name: 'welcome_rich_link',
        template_type: 'send_rich_link',
        parameters: {
          'url' => 'https://acoustichouse.example.com',
          'title' => 'Visit Our Store',
          'subtitle' => 'Browse our complete guitar collection online',
          'image_url' => 'https://acoustichouse.example.com/images/store-banner.jpg'
        },
        execution_order: 3,
        description: 'Rich link to store website'
      },

      # 3. SEND_QUICK_REPLY Template (1)
      {
        name: 'region_quick_reply',
        template_type: 'send_quick_reply',
        parameters: {
          'message' => 'Which region are you shopping from?',
          'request_id' => 'qr_region_select',
          'items' => [
            { 'title' => 'Americas', 'value' => 'americas' },
            { 'title' => 'EMEA', 'value' => 'emea' },
            { 'title' => 'APAC', 'value' => 'apac' }
          ]
        },
        execution_order: 4,
        description: 'Region selection quick reply'
      },

      # 4. UPDATE_ATTRIBUTES Template (1)
      {
        name: 'region_update_attributes',
        template_type: 'update_attributes',
        parameters: {
          'attributes' => {
            'selected_region' => '{{user_selection}}',
            'region_timestamp' => '{{timestamp}}'
          }
        },
        execution_order: 5,
        description: 'Store region selection in conversation attributes'
      },

      # 5. SEND_LIST_PICKER Templates (2)
      {
        name: 'main_menu_list_picker',
        template_type: 'send_list_picker',
        parameters: {
          'template_id' => 'PLACEHOLDER_ah_main_menu',
          'wait_for_response' => true
        },
        execution_order: 6,
        description: 'Main menu list picker (requires MessageTemplate)'
      },
      {
        name: 'guitar_list_picker',
        template_type: 'send_list_picker',
        parameters: {
          'template_id' => 'PLACEHOLDER_ah_guitar_list_picker',
          'wait_for_response' => true
        },
        execution_order: 7,
        description: 'Guitar selection list picker (requires MessageTemplate)'
      },

      # 6. SEND_TIME_PICKER Template (1)
      {
        name: 'store_time_picker',
        template_type: 'send_time_picker',
        parameters: {
          'template_id' => 'PLACEHOLDER_time_picker_template',
          'timezone_offset' => -28_800,
          'location_data' => {
            'name' => 'Acoustic House - Downtown',
            'latitude' => 37.7749,
            'longitude' => -122.4194
          }
        },
        execution_order: 8,
        description: 'Store visit appointment time picker (requires MessageTemplate)'
      },

      # 7. SEND_FORM Template (1)
      {
        name: 'guitar_info_form',
        template_type: 'send_form',
        parameters: {
          'template_id' => 'PLACEHOLDER_ah_guitar_info_form',
          'pre_fill_data' => {
            'region' => '{{selected_region}}'
          }
        },
        execution_order: 9,
        description: 'Guitar information form (requires MessageTemplate)'
      },

      # 8. CONDITIONAL_BRANCH Template (1)
      {
        name: 'region_conditional_branch',
        template_type: 'conditional_branch',
        parameters: {
          'condition_type' => 'attribute_equals',
          'condition_value' => {
            'attribute' => 'selected_region',
            'value' => 'americas'
          },
          'true_action' => {
            'type' => 'send_text',
            'text' => 'Great! Apple Pay is available in your region.'
          },
          'false_action' => {
            'type' => 'send_text',
            'text' => "We'll check product availability for your region."
          }
        },
        execution_order: 10,
        description: 'Branch based on selected region'
      },

      # 9. SEND_APPLE_PAY Template (1)
      {
        name: 'guitar_apple_pay',
        template_type: 'send_apple_pay',
        parameters: {
          'merchant_id' => 'merchant.com.acoustichouse',
          'item_name' => 'Fender Stratocaster - Sunburst',
          'amount' => 1299.99,
          'currency' => 'USD'
        },
        execution_order: 11,
        description: 'Apple Pay payment request for guitar'
      },

      # 10. API_CALL Template (1)
      {
        name: 'inventory_api_call',
        template_type: 'api_call',
        parameters: {
          'url' => 'https://api.acoustichouse.example.com/inventory/check',
          'method' => 'POST',
          'headers' => {
            'Content-Type' => 'application/json',
            'Authorization' => 'Bearer {{api_token}}'
          },
          'body' => {
            'guitar_id' => '{{selected_guitar}}',
            'region' => '{{selected_region}}'
          },
          'store_response_in' => 'inventory_status'
        },
        execution_order: 12,
        description: 'Check guitar inventory via API'
      },

      # 11. SEND_IMESSAGE_APP Template (1)
      {
        name: 'shazam_imessage_app',
        template_type: 'send_imessage_app',
        parameters: {
          'app_id' => 'com.shazam.Shazam.MessagesExtension',
          'app_name' => 'Shazam',
          'app_icon_url' => 'https://acoustichouse.example.com/images/shazam-icon.png',
          'launch_url' => 'shazam://identify',
          'data' => {
            'context' => 'guitar_demo'
          }
        },
        execution_order: 13,
        description: 'Launch Shazam iMessage app'
      },

      # 12. SEND_APP_CLIP Template (1)
      {
        name: 'tuner_app_clip',
        template_type: 'send_app_clip',
        parameters: {
          'app_clip_url' => 'https://acoustichouse.example.com/clips/guitar-tuner',
          'title' => 'Acoustic House Guitar Tuner',
          'subtitle' => 'Tune your guitar instantly without installing an app',
          'image_url' => 'https://acoustichouse.example.com/images/tuner-hero.png',
          'action_title' => 'Launch Tuner'
        },
        execution_order: 14,
        description: 'App Clip for guitar tuner'
      }
    ]
  end

  def print_header
    puts '=' * 80
    puts 'Acoustic House Master Bot Creator'
    puts '=' * 80
    puts "Mode: #{@dry_run ? 'DRY RUN' : 'EXECUTE'}"
    puts
  end

  def print_summary
    puts "\n" + ('=' * 80)
    puts 'Creation Summary'
    puts '=' * 80
    puts "AgentBots created: #{@stats[:agent_bots_created]}"
    puts "BotFlows created: #{@stats[:bot_flows_created]}"
    puts "Templates created: #{@stats[:templates_created]}"
    puts "Errors: #{@stats[:errors].count}"

    if @stats[:errors].any?
      puts "\nErrors:"
      @stats[:errors].each do |error|
        puts "  - #{error}"
      end
    end

    if @dry_run
      puts "\n⚠️  This was a DRY RUN. No changes were made."
      puts '   Run with --execute to create the master bot.'
    else
      puts "\n✅ Master bot creation complete!"
      puts "\nNext Steps:"
      puts '1. Create required MessageTemplates (list_picker, time_picker, form)'
      puts '2. Update template placeholders with actual template IDs'
      puts '3. Configure bot in Bot Studio UI'
      puts '4. Test bot flow with real conversations'
    end
    puts '=' * 80
  end

  def error(message)
    @stats[:errors] << message
  end
end

# Parse command line arguments
account_id = nil
dry_run = true

ARGV.each do |arg|
  if arg =~ /--account-id=(\d+)/
    account_id = Regexp.last_match(1).to_i
  elsif arg == '--execute'
    dry_run = false
  end
end

# Run creator
creator = MasterBotCreator.new(account_id: account_id, dry_run: dry_run)
creator.run
