#!/usr/bin/env ruby
# frozen_string_literal: true

# Filter Core Acoustic House Templates
# Separates production-ready templates from test/dev payloads
#
# Usage:
#   ruby scripts/filter_core_templates.rb [--business TYPE] [--dry-run]

require 'json'
require 'fileutils'
require 'time'

class CoreTemplateFilter
  # Core Acoustic House request IDs (production flows)
  CORE_REQUEST_IDS = {
    # List Pickers - Main flows
    'lp_summary_0319' => 'Feature summary with 13 options',
    'lp_guitar_0319' => 'Guitar selection list picker',
    'lp_menu_0319' => 'Main menu navigation',
    'lp_startover_1018' => 'Restart conversation flow',
    'guitar_listpicker' => 'Guitar catalog picker',
    'summary_listpicker' => 'Summary feature picker',
    'summary_listpicker_as' => 'Acoustic Shack summary',
    'menu_listpicker' => 'Main menu list picker',
    'region_listpicker' => 'Store region selector',

    # Time Pickers - Appointment scheduling
    'time_0319' => 'Appointment time picker (latest)',
    'time_1218' => 'Appointment time picker (legacy)',
    'time_1018' => 'Store visit scheduler',

    # Forms - Customer interaction
    'form_help_me_decide' => 'Guitar decision tree',
    'form_bia_ah' => 'Bia integration form',
    'form_covid_quest' => 'COVID questionnaire',
    'formdemo' => 'Demo form flow',

    # Quick Replies
    'qr_travel' => 'Travel preferences quick reply',
    'qr_name' => 'Name collection quick reply',
    'qr_view_ar' => 'AR view quick reply',
    'qr_place_ar' => 'AR placement quick reply',
    'qr_continue' => 'Continue flow quick reply',
    'qr_learn_more' => 'Learn more quick reply',
    'qr_photo' => 'Photo sharing quick reply',

    # Apple Pay - Purchase flows
    'applepay_1018' => 'Apple Pay payment request',
    'ApplePayPayload' => 'Apple Pay payload template',

    # Authentication
    'auth1220181p1' => 'LinkedIn authentication flow',
    'linkedin_server_side' => 'Server-side auth',
    'linkedin_response' => 'Auth response handler',

    # Location/Store
    'geoCode0504' => 'Geocoding location picker',
    'store0419' => 'Store locator',
    'region_0506' => 'Region selection',

    # Guitar-specific (Acoustic House core)
    'guitar2NLP' => 'Guitar NLP recommendations',
    'guitar_order' => 'Guitar order placement',

    # Messages (Acoustic House specific)
    'howhelp' => 'How can we help message',
    'menunlp' => 'NLP menu navigation',
    'topicsnlp' => 'Topic selection via NLP',

    # WISMO (Where Is My Order) - Guitar shipping
    'wismo.orderConfirmed.orderImage' => 'Order confirmed with guitar image',
    'wismo.orderShipped.GuitarImage' => 'Guitar shipped notification',
    'wismo.orderInTransit.orderGuitar' => 'Guitar in transit',
    'wismo.orderDeliveredGuitar' => 'Guitar delivered',
    'wismo.orderPickup' => 'Pickup ready notification',

    # Customer Satisfaction
    'csat_first' => 'CSAT survey',

    # Shopify Integration
    'shopify_menu' => 'Shopify product menu'
  }.freeze

  # Test/Dev patterns to exclude
  TEST_PATTERNS = [
    /^ap\d{4}$/,           # ap1000-ap9999 (Apple Pay tests)
    /^tp\d{4}/,            # tp1000-tp9999 (Time Picker tests)
    /^au\d+$/,             # au1-au99 (Auth tests)
    /^aui\d+$/,            # aui1-aui99 (Auth UI tests)
    /^gb\d+$/,             # gb1-gb99 (Generic tests)
    /^\d+_/,               # Files starting with numbers (test cases)
    /^form\d+$/,           # form1-form99 (Form tests - but keep named forms)
    /^qr\d+$/,             # qr1-qr99 (Quick reply tests - but keep qr_*)
    /_\d{3,}$/,            # Ending with 3+ digits (test variants)
    /sqa/i,                # SQA test files
    /^0_default/,          # Default test templates
    /nonalpha/i,           # Character encoding tests
    /backslash/i,          # Special character tests
    /^card_dispute/,       # Financial test flows (not Acoustic House)
    /^triage_/,            # Triage flows (not core)
    /^binaryChoice/,       # Binary choice tests
    /^binaryEngage/,       # Engagement tests
    /^confirm/,            # Confirmation tests
    /deliveryException/,   # Delivery exception tests
    /orderChanged/,        # Order change tests
    /^ss_/,                # Server-side tests (ss_google, ss_yahoo)
    /_bad$/,               # Bad input tests
    /_empty/,              # Empty field tests
    /_500/,                # Stress tests
    /_1000/,               # Max length tests
    /no_action/,           # No action tests
    /no_option/,           # No option tests
    /^dev/i                # Development menu
  ].freeze

  # Acoustic House specific keywords (guitar, music retail)
  AH_KEYWORDS = %w[
    guitar
    acoustic
    music
    shop
    store
    appointment
    feature
    summary
    menu
    help
    order
    wismo
    ship
  ].freeze

  attr_reader :options, :stats

  def initialize(options = {})
    @options = options
    @stats = {
      total_templates: 0,
      core_templates: 0,
      test_templates: 0,
      unknown_templates: 0
    }
  end

  def run
    puts '🔍 Filtering Core Acoustic House Templates'
    puts '=' * 60

    business = @options[:business] || 'acoustic_house'
    migration_file = find_migration_file(business)

    unless migration_file
      puts "❌ No migration data found for #{business}"
      puts "Run migration script first: ruby scripts/migrate_apple_bot.rb --business #{business}"
      return
    end

    puts "📁 Loading: #{migration_file}"
    data = JSON.parse(File.read(migration_file))

    @stats[:total_templates] = data['payloads'].size
    puts "📊 Total templates: #{@stats[:total_templates]}"
    puts

    # Categorize templates
    categorized = categorize_templates(data['payloads'])

    # Print analysis
    print_analysis(categorized)

    # Create filtered data
    save_filtered_data(business, data, categorized) unless @options[:dry_run]

    print_summary
  end

  private

  def find_migration_file(business)
    filepath = File.join('tmp', 'bot_migration', business, 'migration_data.json')
    File.exist?(filepath) ? filepath : nil
  end

  def categorize_templates(payloads)
    categories = {
      core: [],
      test: [],
      unknown: []
    }

    payloads.each do |payload|
      request_id = payload['request_id']
      file_name = payload['original_file']

      category = determine_category(request_id, file_name)
      categories[category] << payload

      @stats["#{category}_templates".to_sym] += 1
    end

    categories
  end

  def determine_category(request_id, file_name)
    # Check if it's a core template by request ID
    return :core if CORE_REQUEST_IDS.key?(request_id)

    # Check if it matches test patterns
    return :test if matches_test_pattern?(request_id) || matches_test_pattern?(file_name)

    # Check if it contains Acoustic House keywords
    return :core if contains_ah_keywords?(request_id) || contains_ah_keywords?(file_name)

    # Check for specific core patterns
    return :core if request_id&.start_with?('qr_', 'form_', 'lp_', 'time_') && !request_id.match?(/\d{4}/)

    # Default to unknown for manual review
    :unknown
  end

  def matches_test_pattern?(text)
    return false unless text

    TEST_PATTERNS.any? { |pattern| text.match?(pattern) }
  end

  def contains_ah_keywords?(text)
    return false unless text

    text_lower = text.downcase
    AH_KEYWORDS.any? { |keyword| text_lower.include?(keyword) }
  end

  def print_analysis(categorized)
    puts '📋 Template Categorization'
    puts '-' * 60
    puts

    # Core templates
    puts "✅ CORE TEMPLATES (#{categorized[:core].size}):"
    puts
    print_template_list(categorized[:core].first(20), show_details: true)
    puts "   ... and #{categorized[:core].size - 20} more core templates" if categorized[:core].size > 20
    puts

    # Test templates (sample)
    puts "🧪 TEST/DEV TEMPLATES (#{categorized[:test].size}):"
    puts
    print_template_list(categorized[:test].first(10))
    puts "   ... and #{categorized[:test].size - 10} more test templates" if categorized[:test].size > 10
    puts

    # Unknown (needs manual review)
    return unless categorized[:unknown].any?

    puts "⚠️  UNKNOWN TEMPLATES (#{categorized[:unknown].size}) - Manual Review Needed:"
    puts
    print_template_list(categorized[:unknown])
    puts
  end

  def print_template_list(templates, show_details: false)
    templates.each do |t|
      request_id = t['request_id'] || 'N/A'
      file_name = t['original_file']
      content_type = t['template']['content_type']

      if show_details && CORE_REQUEST_IDS[request_id]
        puts "   • #{request_id}"
        puts "     └─ #{CORE_REQUEST_IDS[request_id]}"
        puts "     └─ Type: #{content_type}, File: #{file_name}"
      else
        puts "   • #{request_id} (#{file_name})"
      end
    end
  end

  def save_filtered_data(business, original_data, categorized)
    puts '💾 Saving Filtered Data'
    puts '-' * 60

    # Save core templates
    core_data = original_data.merge(
      'payloads' => categorized[:core],
      'filter_applied' => 'core_only',
      'filtered_at' => Time.now.iso8601,
      'original_count' => @stats[:total_templates],
      'filtered_count' => categorized[:core].size
    )

    core_file = File.join('tmp', 'bot_migration', business, 'migration_data_CORE.json')
    File.write(core_file, JSON.pretty_generate(core_data))
    puts "✅ Core templates: #{core_file}"
    puts "   #{categorized[:core].size} templates"

    # Save test templates (for reference)
    test_data = original_data.merge(
      'payloads' => categorized[:test],
      'filter_applied' => 'test_only',
      'filtered_at' => Time.now.iso8601
    )

    test_file = File.join('tmp', 'bot_migration', business, 'migration_data_TEST.json')
    File.write(test_file, JSON.pretty_generate(test_data))
    puts "✅ Test templates: #{test_file}"
    puts "   #{categorized[:test].size} templates"

    # Save unknown templates (for manual review)
    if categorized[:unknown].any?
      unknown_data = original_data.merge(
        'payloads' => categorized[:unknown],
        'filter_applied' => 'unknown_review_needed',
        'filtered_at' => Time.now.iso8601
      )

      unknown_file = File.join('tmp', 'bot_migration', business, 'migration_data_UNKNOWN.json')
      File.write(unknown_file, JSON.pretty_generate(unknown_data))
      puts "⚠️  Unknown templates: #{unknown_file}"
      puts "   #{categorized[:unknown].size} templates (manual review needed)"
    end

    # Create summary report
    save_summary_report(business, categorized)
    puts
  end

  def save_summary_report(business, categorized)
    report = {
      business: business,
      filtered_at: Time.now.iso8601,
      statistics: {
        total_templates: @stats[:total_templates],
        core_templates: @stats[:core_templates],
        test_templates: @stats[:test_templates],
        unknown_templates: @stats[:unknown_templates]
      },
      core_templates: categorized[:core].map do |t|
        {
          request_id: t['request_id'],
          file_name: t['original_file'],
          content_type: t['template']['content_type'],
          language: t['language'],
          description: CORE_REQUEST_IDS[t['request_id']]
        }
      end,
      filter_criteria: {
        core_request_ids: CORE_REQUEST_IDS.keys,
        test_patterns: TEST_PATTERNS.map(&:source),
        ah_keywords: AH_KEYWORDS
      }
    }

    report_file = File.join('tmp', 'bot_migration', business, 'FILTER_REPORT.json')
    File.write(report_file, JSON.pretty_generate(report))
    puts "📊 Filter report: #{report_file}"
  end

  def print_summary
    puts
    puts '=' * 60
    puts '📊 Filtering Summary'
    puts '=' * 60
    puts "Total templates: #{@stats[:total_templates]}"
    puts "Core templates: #{@stats[:core_templates]} (#{percentage(:core_templates)}%)"
    puts "Test templates: #{@stats[:test_templates]} (#{percentage(:test_templates)}%)"
    puts "Unknown templates: #{@stats[:unknown_templates]} (#{percentage(:unknown_templates)}%)"
    puts

    if @options[:dry_run]
      puts 'ℹ️  Dry-run mode - no files saved'
    else
      puts '✨ Filtering complete!'
      puts
      puts '📋 Next steps:'
      puts '  1. Review migration_data_CORE.json for production import'
      puts '  2. Check FILTER_REPORT.json for detailed analysis'
      puts '  3. Manually review migration_data_UNKNOWN.json (if exists)'
      puts '  4. Import core templates:'
      puts '     rails runner scripts/import_migrated_bots.rb --account-id 1 --business acoustic_house --core-only'
    end
  end

  def percentage(stat)
    return 0 if @stats[:total_templates].zero?

    (((@stats[stat].to_f / @stats[:total_templates]) * 100).round(1))
  end
end

# Parse options
options = {}
ARGV.each_with_index do |arg, i|
  case arg
  when '--business'
    options[:business] = ARGV[i + 1]
  when '--dry-run'
    options[:dry_run] = true
  end
end

# Run filter
filter = CoreTemplateFilter.new(options)
filter.run
