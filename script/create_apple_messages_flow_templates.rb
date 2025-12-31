#!/usr/bin/env ruby
# frozen_string_literal: true

# Apple Messages Flow Templates Creator
# Creates 4 reusable flow templates for common AMB use cases
# Usage: rails runner script/create_apple_messages_flow_templates.rb [--account-id=N] [--execute]
#
# This script creates flow templates for:
# 1. Welcome & Menu Navigation
# 2. Product/Service Selection
# 3. Appointment Booking
# 4. Information Collection
#
# By default runs in dry-run mode. Pass --execute to create templates.

require 'json'

class FlowTemplatesCreator
  FLOW_TEMPLATES = [
    {
      name: 'Welcome & Menu Navigation',
      description: 'Basic welcome flow with menu navigation using List Picker',
      category: 'navigation',
      use_case: 'First-time user onboarding and main menu',
      template_data: :welcome_menu_flow
    },
    {
      name: 'Product Selection Flow',
      description: 'Browse and select products/services with visual list picker',
      category: 'commerce',
      use_case: 'Product browsing, service selection, catalog navigation',
      template_data: :product_selection_flow
    },
    {
      name: 'Appointment Booking Flow',
      description: 'Schedule appointments with time picker and location',
      category: 'scheduling',
      use_case: 'Store visits, consultations, service appointments',
      template_data: :appointment_booking_flow
    },
    {
      name: 'Information Collection Flow',
      description: 'Collect customer information using forms and attributes',
      category: 'data_collection',
      use_case: 'Registration, surveys, feedback collection',
      template_data: :information_collection_flow
    }
  ].freeze

  def initialize(account_id: nil, dry_run: true)
    @account_id = account_id
    @dry_run = dry_run
    @stats = {
      templates_created: 0,
      errors: []
    }
  end

  def run
    print_header

    @account = find_or_validate_account
    return unless @account

    create_flow_templates
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

  def create_flow_templates
    puts "\n--- Creating Flow Templates for Account: #{@account.name} (ID: #{@account.id}) ---\n\n"

    FLOW_TEMPLATES.each do |template_def|
      create_flow_template(template_def)
    end
  end

  def create_flow_template(template_def)
    name = template_def[:name]

    # Check if template already exists
    existing = BotFlow.joins(:agent_bot)
                      .where(agent_bots: { account_id: @account.id })
                      .find_by(name: name)

    if existing
      puts "  ⏭️  Flow template '#{name}' already exists"
      return existing
    end

    if @dry_run
      puts "  📋 Would create: #{name}"
      puts "     Category: #{template_def[:category]}"
      puts "     Use Case: #{template_def[:use_case]}"
      puts "     Description: #{template_def[:description]}"
      return nil
    else
      begin
        # Find or create a template agent bot for this account
        template_bot = find_or_create_template_bot

        # Build flow data
        flow_data = send(template_def[:template_data])

        # Create flow template
        flow = BotFlow.create!(
          agent_bot: template_bot,
          name: name,
          flow_data: flow_data,
          is_active: false,  # Templates are not meant to be executed directly
          is_published: true,  # Templates should be visible in template browser
          metadata: {
            is_template: true,
            category: template_def[:category],
            use_case: template_def[:use_case],
            description: template_def[:description],
            created_by: 'flow_templates_creator',
            creation_date: Time.current.iso8601
          }
        )

        puts "  ✅ Created: #{name}"
        @stats[:templates_created] += 1
        flow
      rescue StandardError => e
        error_msg = "Failed to create flow template '#{name}': #{e.message}"
        puts "  ❌ #{error_msg}"
        @stats[:errors] << error_msg
        nil
      end
    end
  end

  def find_or_create_template_bot
    bot_name = 'Flow Templates Bot'

    bot = AgentBot.find_by(account: @account, name: bot_name)
    return bot if bot

    AgentBot.create!(
      account: @account,
      name: bot_name,
      description: 'Container bot for reusable flow templates',
      bot_type: 'apple_messages_for_business',
      bot_config: {
        is_template_bot: true,
        created_by: 'flow_templates_creator',
        creation_date: Time.current.iso8601
      }
    )
  end

  # Flow Template 1: Welcome & Menu Navigation
  def welcome_menu_flow
    {
      'nodes' => [
        {
          'id' => 'state-welcome',
          'type' => 'state',
          'position' => { 'x' => 100, 'y' => 100 },
          'data' => {
            'state_id' => 'START',
            'label' => 'Welcome Message',
            'is_initial' => true,
            'description' => 'Send welcome message to customer',
            'actions' => [
              {
                'type' => 'send_text',
                'text' => 'Welcome! How can we help you today?'
              }
            ]
          }
        },
        {
          'id' => 'state-menu',
          'type' => 'state',
          'position' => { 'x' => 100, 'y' => 300 },
          'data' => {
            'state_id' => 'MENU',
            'label' => 'Main Menu',
            'description' => 'Display main menu with list picker',
            'actions' => [
              {
                'type' => 'send_template',
                'template_name' => 'PLACEHOLDER_main_menu',
                'comment' => 'Replace with your list picker template'
              }
            ]
          }
        },
        {
          'id' => 'intent-selection',
          'type' => 'intent',
          'position' => { 'x' => 100, 'y' => 500 },
          'data' => {
            'intent_id' => 'menu_selection',
            'label' => 'Process Selection',
            'description' => 'Handle menu item selection',
            'actions' => [
              {
                'type' => 'update_attributes',
                'attributes' => {
                  'selected_option' => '{{user_selection}}'
                }
              }
            ]
          }
        },
        {
          'id' => 'state-confirmation',
          'type' => 'state',
          'position' => { 'x' => 100, 'y' => 700 },
          'data' => {
            'state_id' => 'CONFIRM',
            'label' => 'Confirmation',
            'is_final' => true,
            'description' => 'Confirm selection',
            'actions' => [
              {
                'type' => 'send_text',
                'text' => 'Got it! You selected: {{selected_option}}'
              }
            ]
          }
        }
      ],
      'edges' => [
        {
          'id' => 'edge-welcome-menu',
          'source' => 'state-welcome',
          'target' => 'state-menu',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-menu-intent',
          'source' => 'state-menu',
          'target' => 'intent-selection',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-intent-confirm',
          'source' => 'intent-selection',
          'target' => 'state-confirmation',
          'type' => 'smoothstep'
        }
      ],
      'viewport' => { 'x' => 0, 'y' => 0, 'zoom' => 1 }
    }
  end

  # Flow Template 2: Product Selection Flow
  def product_selection_flow
    {
      'nodes' => [
        {
          'id' => 'state-browse-intro',
          'type' => 'state',
          'position' => { 'x' => 100, 'y' => 100 },
          'data' => {
            'state_id' => 'BROWSE_START',
            'label' => 'Browse Introduction',
            'is_initial' => true,
            'description' => 'Introduce product browsing',
            'actions' => [
              {
                'type' => 'send_text',
                'text' => "Let's find the perfect product for you!"
              }
            ]
          }
        },
        {
          'id' => 'state-product-list',
          'type' => 'state',
          'position' => { 'x' => 100, 'y' => 300 },
          'data' => {
            'state_id' => 'PRODUCT_LIST',
            'label' => 'Product List Picker',
            'description' => 'Display product catalog',
            'actions' => [
              {
                'type' => 'send_template',
                'template_name' => 'PLACEHOLDER_product_list',
                'comment' => 'Replace with your product list picker template'
              }
            ]
          }
        },
        {
          'id' => 'intent-product-selected',
          'type' => 'intent',
          'position' => { 'x' => 100, 'y' => 500 },
          'data' => {
            'intent_id' => 'product_selection',
            'label' => 'Product Selected',
            'description' => 'Store selected product',
            'actions' => [
              {
                'type' => 'update_attributes',
                'attributes' => {
                  'selected_product_id' => '{{item_id}}',
                  'selected_product_name' => '{{item_name}}'
                }
              }
            ]
          }
        },
        {
          'id' => 'state-product-details',
          'type' => 'state',
          'position' => { 'x' => 100, 'y' => 700 },
          'data' => {
            'state_id' => 'PRODUCT_DETAILS',
            'label' => 'Product Details',
            'description' => 'Show product information',
            'actions' => [
              {
                'type' => 'send_rich_link',
                'url' => 'https://example.com/products/{{selected_product_id}}',
                'title' => '{{selected_product_name}}',
                'subtitle' => 'View full details'
              }
            ]
          }
        },
        {
          'id' => 'condition-interested',
          'type' => 'condition',
          'position' => { 'x' => 100, 'y' => 900 },
          'data' => {
            'condition_id' => 'check_interest',
            'label' => 'Check Interest',
            'description' => 'Ask if customer wants to proceed',
            'actions' => [
              {
                'type' => 'send_quick_reply',
                'message' => 'Would you like to purchase this product?',
                'request_id' => 'qr_purchase_interest',
                'items' => [
                  { 'title' => 'Yes, proceed', 'value' => 'yes' },
                  { 'title' => 'See more options', 'value' => 'browse' }
                ]
              }
            ]
          }
        },
        {
          'id' => 'state-proceed-purchase',
          'type' => 'state',
          'position' => { 'x' => -100, 'y' => 1100 },
          'data' => {
            'state_id' => 'PURCHASE',
            'label' => 'Proceed to Purchase',
            'is_final' => true,
            'description' => 'Start purchase flow',
            'actions' => [
              {
                'type' => 'send_text',
                'text' => 'Great! Connecting you with our sales team...'
              }
            ]
          }
        },
        {
          'id' => 'state-continue-browsing',
          'type' => 'state',
          'position' => { 'x' => 300, 'y' => 1100 },
          'data' => {
            'state_id' => 'BROWSE_MORE',
            'label' => 'Continue Browsing',
            'description' => 'Loop back to product list',
            'actions' => [
              {
                'type' => 'send_text',
                'text' => 'No problem! Let me show you more options.'
              }
            ]
          }
        }
      ],
      'edges' => [
        {
          'id' => 'edge-intro-list',
          'source' => 'state-browse-intro',
          'target' => 'state-product-list',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-list-selected',
          'source' => 'state-product-list',
          'target' => 'intent-product-selected',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-selected-details',
          'source' => 'intent-product-selected',
          'target' => 'state-product-details',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-details-condition',
          'source' => 'state-product-details',
          'target' => 'condition-interested',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-condition-purchase',
          'source' => 'condition-interested',
          'target' => 'state-proceed-purchase',
          'type' => 'smoothstep',
          'label' => 'Yes'
        },
        {
          'id' => 'edge-condition-browse',
          'source' => 'condition-interested',
          'target' => 'state-continue-browsing',
          'type' => 'smoothstep',
          'label' => 'Browse'
        },
        {
          'id' => 'edge-browse-back-list',
          'source' => 'state-continue-browsing',
          'target' => 'state-product-list',
          'type' => 'smoothstep'
        }
      ],
      'viewport' => { 'x' => 0, 'y' => 0, 'zoom' => 0.8 }
    }
  end

  # Flow Template 3: Appointment Booking Flow
  def appointment_booking_flow
    {
      'nodes' => [
        {
          'id' => 'state-booking-start',
          'type' => 'state',
          'position' => { 'x' => 100, 'y' => 100 },
          'data' => {
            'state_id' => 'BOOKING_START',
            'label' => 'Start Booking',
            'is_initial' => true,
            'description' => 'Initialize appointment booking',
            'actions' => [
              {
                'type' => 'send_text',
                'text' => "Great! Let's schedule your appointment."
              }
            ]
          }
        },
        {
          'id' => 'state-service-selection',
          'type' => 'state',
          'position' => { 'x' => 100, 'y' => 300 },
          'data' => {
            'state_id' => 'SERVICE_SELECT',
            'label' => 'Select Service',
            'description' => 'Choose service type',
            'actions' => [
              {
                'type' => 'send_quick_reply',
                'message' => 'What type of appointment do you need?',
                'request_id' => 'qr_service_type',
                'items' => [
                  { 'title' => 'Consultation', 'value' => 'consultation' },
                  { 'title' => 'Store Visit', 'value' => 'store_visit' },
                  { 'title' => 'Service/Repair', 'value' => 'service' }
                ]
              }
            ]
          }
        },
        {
          'id' => 'intent-service-selected',
          'type' => 'intent',
          'position' => { 'x' => 100, 'y' => 500 },
          'data' => {
            'intent_id' => 'service_selection',
            'label' => 'Service Selected',
            'description' => 'Store service type',
            'actions' => [
              {
                'type' => 'update_attributes',
                'attributes' => {
                  'appointment_type' => '{{user_selection}}'
                }
              }
            ]
          }
        },
        {
          'id' => 'state-time-picker',
          'type' => 'state',
          'position' => { 'x' => 100, 'y' => 700 },
          'data' => {
            'state_id' => 'TIME_SELECT',
            'label' => 'Select Time',
            'description' => 'Pick appointment time',
            'actions' => [
              {
                'type' => 'send_template',
                'template_name' => 'PLACEHOLDER_time_picker',
                'comment' => 'Replace with your time picker template'
              }
            ]
          }
        },
        {
          'id' => 'intent-time-selected',
          'type' => 'intent',
          'position' => { 'x' => 100, 'y' => 900 },
          'data' => {
            'intent_id' => 'time_selection',
            'label' => 'Time Selected',
            'description' => 'Store selected time',
            'actions' => [
              {
                'type' => 'update_attributes',
                'attributes' => {
                  'appointment_time' => '{{selected_time}}',
                  'appointment_location' => '{{selected_location}}'
                }
              }
            ]
          }
        },
        {
          'id' => 'state-confirmation',
          'type' => 'state',
          'position' => { 'x' => 100, 'y' => 1100 },
          'data' => {
            'state_id' => 'CONFIRM_BOOKING',
            'label' => 'Confirm Booking',
            'is_final' => true,
            'description' => 'Send booking confirmation',
            'actions' => [
              {
                'type' => 'send_text',
                'text' => "Perfect! Your {{appointment_type}} is scheduled for {{appointment_time}} at {{appointment_location}}. We'll send you a confirmation shortly."
              }
            ]
          }
        }
      ],
      'edges' => [
        {
          'id' => 'edge-start-service',
          'source' => 'state-booking-start',
          'target' => 'state-service-selection',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-service-intent',
          'source' => 'state-service-selection',
          'target' => 'intent-service-selected',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-intent-time',
          'source' => 'intent-service-selected',
          'target' => 'state-time-picker',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-time-intent',
          'source' => 'state-time-picker',
          'target' => 'intent-time-selected',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-intent-confirm',
          'source' => 'intent-time-selected',
          'target' => 'state-confirmation',
          'type' => 'smoothstep'
        }
      ],
      'viewport' => { 'x' => 0, 'y' => 0, 'zoom' => 0.9 }
    }
  end

  # Flow Template 4: Information Collection Flow
  def information_collection_flow
    {
      'nodes' => [
        {
          'id' => 'state-collection-start',
          'type' => 'state',
          'position' => { 'x' => 100, 'y' => 100 },
          'data' => {
            'state_id' => 'INFO_START',
            'label' => 'Start Collection',
            'is_initial' => true,
            'description' => 'Initialize data collection',
            'actions' => [
              {
                'type' => 'send_text',
                'text' => "We'd like to know a bit more about you to serve you better."
              }
            ]
          }
        },
        {
          'id' => 'state-basic-info',
          'type' => 'state',
          'position' => { 'x' => 100, 'y' => 300 },
          'data' => {
            'state_id' => 'BASIC_INFO',
            'label' => 'Basic Information',
            'description' => 'Collect basic details via quick replies',
            'actions' => [
              {
                'type' => 'send_quick_reply',
                'message' => 'Are you a new or returning customer?',
                'request_id' => 'qr_customer_type',
                'items' => [
                  { 'title' => 'New Customer', 'value' => 'new' },
                  { 'title' => 'Returning', 'value' => 'returning' }
                ]
              }
            ]
          }
        },
        {
          'id' => 'intent-customer-type',
          'type' => 'intent',
          'position' => { 'x' => 100, 'y' => 500 },
          'data' => {
            'intent_id' => 'customer_type_selected',
            'label' => 'Customer Type',
            'description' => 'Store customer type',
            'actions' => [
              {
                'type' => 'update_attributes',
                'attributes' => {
                  'customer_type' => '{{user_selection}}'
                }
              }
            ]
          }
        },
        {
          'id' => 'state-detailed-form',
          'type' => 'state',
          'position' => { 'x' => 100, 'y' => 700 },
          'data' => {
            'state_id' => 'DETAILED_FORM',
            'label' => 'Detailed Information',
            'description' => 'Collect detailed information via form',
            'actions' => [
              {
                'type' => 'send_template',
                'template_name' => 'PLACEHOLDER_info_form',
                'comment' => 'Replace with your information collection form'
              }
            ]
          }
        },
        {
          'id' => 'intent-form-submitted',
          'type' => 'intent',
          'position' => { 'x' => 100, 'y' => 900 },
          'data' => {
            'intent_id' => 'form_submission',
            'label' => 'Form Submitted',
            'description' => 'Process form data',
            'actions' => [
              {
                'type' => 'update_attributes',
                'attributes' => {
                  'form_data' => '{{form_responses}}',
                  'submission_timestamp' => '{{timestamp}}'
                }
              }
            ]
          }
        },
        {
          'id' => 'condition-validate',
          'type' => 'condition',
          'position' => { 'x' => 100, 'y' => 1100 },
          'data' => {
            'condition_id' => 'validate_data',
            'label' => 'Validate Data',
            'description' => 'Check if data is complete',
            'actions' => [
              {
                'type' => 'conditional_branch',
                'condition_type' => 'attribute_exists',
                'condition_value' => {
                  'attribute' => 'form_data'
                }
              }
            ]
          }
        },
        {
          'id' => 'state-success',
          'type' => 'state',
          'position' => { 'x' => -100, 'y' => 1300 },
          'data' => {
            'state_id' => 'SUCCESS',
            'label' => 'Success',
            'is_final' => true,
            'description' => 'Confirm successful collection',
            'actions' => [
              {
                'type' => 'send_text',
                'text' => "Thank you! Your information has been saved. We'll use this to provide you with personalized service."
              }
            ]
          }
        },
        {
          'id' => 'state-retry',
          'type' => 'state',
          'position' => { 'x' => 300, 'y' => 1300 },
          'data' => {
            'state_id' => 'RETRY',
            'label' => 'Retry Form',
            'description' => 'Ask to complete form again',
            'actions' => [
              {
                'type' => 'send_text',
                'text' => 'It looks like some information is missing. Would you like to complete the form?'
              }
            ]
          }
        }
      ],
      'edges' => [
        {
          'id' => 'edge-start-basic',
          'source' => 'state-collection-start',
          'target' => 'state-basic-info',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-basic-intent',
          'source' => 'state-basic-info',
          'target' => 'intent-customer-type',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-intent-form',
          'source' => 'intent-customer-type',
          'target' => 'state-detailed-form',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-form-intent',
          'source' => 'state-detailed-form',
          'target' => 'intent-form-submitted',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-intent-validate',
          'source' => 'intent-form-submitted',
          'target' => 'condition-validate',
          'type' => 'smoothstep'
        },
        {
          'id' => 'edge-validate-success',
          'source' => 'condition-validate',
          'target' => 'state-success',
          'type' => 'smoothstep',
          'label' => 'Valid'
        },
        {
          'id' => 'edge-validate-retry',
          'source' => 'condition-validate',
          'target' => 'state-retry',
          'type' => 'smoothstep',
          'label' => 'Invalid'
        },
        {
          'id' => 'edge-retry-form',
          'source' => 'state-retry',
          'target' => 'state-detailed-form',
          'type' => 'smoothstep'
        }
      ],
      'viewport' => { 'x' => 0, 'y' => 0, 'zoom' => 0.75 }
    }
  end

  def print_header
    puts '=' * 80
    puts 'Apple Messages Flow Templates Creator'
    puts '=' * 80
    puts "Mode: #{@dry_run ? 'DRY RUN' : 'EXECUTE'}"
    puts
  end

  def print_summary
    puts "\n" + ('=' * 80)
    puts 'Creation Summary'
    puts '=' * 80
    puts "Flow templates created: #{@stats[:templates_created]}"
    puts "Errors: #{@stats[:errors].count}"

    if @stats[:errors].any?
      puts "\nErrors:"
      @stats[:errors].each do |error|
        puts "  - #{error}"
      end
    end

    if @dry_run
      puts "\n⚠️  This was a DRY RUN. No changes were made."
      puts '   Run with --execute to create the flow templates.'
    else
      puts "\n✅ Flow template creation complete!"
      puts "\nCreated Templates:"
      FLOW_TEMPLATES.each do |template|
        puts "  - #{template[:name]}"
        puts "    Category: #{template[:category]}"
        puts "    Use Case: #{template[:use_case]}"
      end
      puts "\nNext Steps:"
      puts '1. Update TemplateBrowserDialog to load templates from database'
      puts '2. Add API endpoint for retrieving flow templates'
      puts '3. Enable template cloning in Bot Studio UI'
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
creator = FlowTemplatesCreator.new(account_id: account_id, dry_run: dry_run)
creator.run
