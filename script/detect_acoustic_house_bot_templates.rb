#!/usr/bin/env ruby
# frozen_string_literal: true

# Acoustic House Bot Template Drift Detection
#
# This script validates that the REQUIRED_TEMPLATES constant in
# AcousticHouseBotService matches the actual template usage in the code.
#
# Usage:
#   rails runner script/detect_acoustic_house_bot_templates.rb
#   rails runner script/detect_acoustic_house_bot_templates.rb --verbose
#
# Exit codes:
#   0 - No drift detected (constant matches code)
#   1 - Drift detected (constant needs updating)
#   2 - Script error

class TemplateDriftDetector
  BOT_SERVICE_FILE = 'app/services/apple_messages_for_business/acoustic_house_bot_service.rb'

  # Template name patterns to search for in code
  TEMPLATE_PATTERNS = [
    /MessageTemplate\.find_by\([^)]*name:\s*['"]([^'"]+)['"]/,
    /name:\s*['"]ah_[^'"]+['"]/
  ].freeze

  def initialize(verbose: false)
    @verbose = verbose
    @errors = []
  end

  def detect
    puts '🔍 Acoustic House Bot Template Drift Detection'
    puts '=' * 70
    puts ''

    # Step 1: Get declared templates from constant
    declared_templates = get_declared_templates
    log "📋 Declared in REQUIRED_TEMPLATES constant: #{declared_templates.size}"
    declared_templates.each { |name| log "   - #{name}" }
    puts ''

    # Step 2: Detect templates from code usage
    detected_templates = detect_from_code
    log "🔎 Detected from code analysis: #{detected_templates.size}"
    detected_templates.each { |name| log "   - #{name}" }
    puts ''

    # Step 3: Compare and report drift
    compare_results(declared_templates, detected_templates)

    # Step 4: Exit with appropriate code
    if @errors.empty?
      puts ''
      puts '✅ No drift detected - constant matches code usage'
      exit 0
    else
      puts ''
      puts '❌ Drift detected - please update REQUIRED_TEMPLATES constant'
      exit 1
    end
  rescue StandardError => e
    puts "💥 Script error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    exit 2
  end

  private

  def get_declared_templates
    # Load the constant from the class
    require Rails.root.join(BOT_SERVICE_FILE)
    AppleMessagesForBusiness::AcousticHouseBotService::REQUIRED_TEMPLATES.dup
  rescue StandardError => e
    puts "❌ Error loading REQUIRED_TEMPLATES constant: #{e.message}"
    []
  end

  def detect_from_code
    templates = Set.new

    File.readlines(Rails.root.join(BOT_SERVICE_FILE)).each_with_index do |line, index|
      # Look for MessageTemplate.find_by patterns
      TEMPLATE_PATTERNS.each do |pattern|
        next unless line.match(pattern)

        # Extract template names (ah_* pattern)
        line.scan(/['"]ah_[a-z_]+['"]/).each do |match|
          template_name = match.tr("'\"", '')
          templates << template_name
          log "   Line #{index + 1}: Found '#{template_name}'" if @verbose
        end
      end
    end

    templates.to_a.sort
  end

  def compare_results(declared, detected)
    missing_from_constant = detected - declared
    extra_in_constant = declared - detected

    if missing_from_constant.any?
      puts '⚠️  Templates used in code but NOT in REQUIRED_TEMPLATES:'
      missing_from_constant.each { |name| puts "   - #{name}" }
      @errors << "Missing from constant: #{missing_from_constant.join(', ')}"
      puts ''
    end

    if extra_in_constant.any?
      puts '⚠️  Templates in REQUIRED_TEMPLATES but NOT used in code:'
      extra_in_constant.each { |name| puts "   - #{name}" }
      @errors << "Extra in constant: #{extra_in_constant.join(', ')}"
      puts ''
    end

    # Show dynamic templates (ah_doc_* pattern) if verbose
    return unless @verbose

    puts 'ℹ️  Note: Dynamic templates (ah_doc_*) are created on-demand'
    puts '   These are not included in REQUIRED_TEMPLATES'
    puts ''
  end

  def log(message)
    puts message if @verbose
  end
end

# Run detection
verbose = ARGV.include?('--verbose') || ARGV.include?('-v')
detector = TemplateDriftDetector.new(verbose: verbose)
detector.detect
