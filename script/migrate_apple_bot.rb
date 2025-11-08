#!/usr/bin/env ruby
# frozen_string_literal: true

# Apple Messages Bot Migration Script
# Converts old Flask/Python bot JSON payloads to Chatwoot bot format
#
# Usage:
#   ruby scripts/migrate_apple_bot.rb [--dry-run] [--business TYPE]
#
# Options:
#   --dry-run: Preview changes without importing
#   --business TYPE: Only migrate specific business (acoustic_house, acoustic_shack, telco)

require 'json'
require 'base64'
require 'fileutils'
require 'optparse'
require 'time'

# Business type mappings
BUSINESS_TYPES = {
  'acoustic_house' => 'AH',
  'acoustic_shack' => 'AS',
  'telco' => 'Telco'
}.freeze

class AppleBotMigration
  REQUEST_ID_PATTERNS = {
    'qr_' => 'apple_quick_reply',
    'form_' => 'apple_form',
    'lp_' => 'apple_list_picker',
    'time_' => 'apple_time_picker',
    'auth' => 'apple_authentication',
    'applepay_' => 'apple_pay',
    'geoCode' => 'apple_list_picker', # Location picker
    'store' => 'apple_list_picker',   # Store locator
    'region_' => 'apple_list_picker'  # Region selection
  }.freeze

  CASE_MAPPINGS = {
    'imageIdentifier' => 'image_identifier',
    'multipleSelection' => 'multiple_selection',
    'receivedMessage' => 'received_message',
    'replyMessage' => 'reply_message',
    'listPicker' => 'list_picker',
    'timePicker' => 'time_picker',
    'requestIdentifier' => 'request_identifier',
    'mspVersion' => 'msp_version'
  }.freeze

  attr_reader :options, :stats

  def initialize(options = {})
    @options = options
    @stats = {
      files_processed: 0,
      payloads_converted: 0,
      images_extracted: 0,
      errors: []
    }
  end

  def run
    puts '🚀 Starting Apple Messages Bot Migration'
    puts '=' * 60
    puts "Dry run mode: #{@options[:dry_run]}" if @options[:dry_run]
    puts "Business filter: #{@options[:business]}" if @options[:business]
    puts

    bot_dir = find_bot_directory
    unless bot_dir
      puts '❌ Error: Could not find Acoustic-House-Bot-origin directory'
      return
    end

    puts "📁 Found bot directory: #{bot_dir}"

    # Scan JSON files
    json_files = scan_json_files(bot_dir)
    puts "📊 Found #{json_files.size} JSON payload files"
    puts

    # Process by business type
    BUSINESS_TYPES.each do |business_name, business_code|
      next if @options[:business] && @options[:business] != business_name

      puts "🏢 Processing: #{business_name.upcase} (#{business_code})"
      puts '-' * 60

      payloads = extract_business_payloads(json_files, business_name, business_code)
      migrate_business(business_name, payloads)
      puts
    end

    print_summary
  end

  private

  def find_bot_directory
    # Try multiple possible locations
    possible_paths = [
      '/Users/rhaps/LocalGit/chatwoot/_apple/Acoustic-House-Bot-origin/acoustichouse',
      File.expand_path('../../_apple/Acoustic-House-Bot-origin/acoustichouse', __dir__),
      File.expand_path('_apple/Acoustic-House-Bot-origin/acoustichouse')
    ]

    possible_paths.find { |path| Dir.exist?(path) }
  end

  def scan_json_files(bot_dir)
    json_dir = File.join(bot_dir, 'json')
    return [] unless Dir.exist?(json_dir)

    Dir.glob(File.join(json_dir, '**', '*.json'))
  end

  def extract_business_payloads(json_files, business_name, business_code)
    payloads = []

    json_files.each do |file_path|
      content = File.read(file_path)
      payload = JSON.parse(content)

      # Categorize by filename patterns and content
      business_type = categorize_business(file_path, payload, business_code)
      next unless business_type == business_name

      payloads << {
        file_path: file_path,
        file_name: File.basename(file_path, '.json'),
        language: extract_language(file_path),
        payload: payload,
        request_id: extract_request_id(payload),
        content_type: detect_content_type(payload)
      }

      @stats[:files_processed] += 1
    rescue JSON::ParserError => e
      @stats[:errors] << "Failed to parse #{file_path}: #{e.message}"
    end

    payloads.sort_by { |p| p[:request_id] || p[:file_name] }
  end

  def categorize_business(file_path, _payload, _business_code)
    # Check filename for business indicators
    filename = File.basename(file_path).downcase

    if filename.include?('telco') || filename.include?('phone')
      'telco'
    elsif filename.include?('_as') || filename.include?('shack') || filename.include?('bia')
      'acoustic_shack'
    else
      'acoustic_house' # Default
    end
  end

  def extract_language(file_path)
    # Extract from path: .../json/en/... or .../json/br/...
    match = file_path.match(%r{/json/([a-z]{2})/})
    match ? match[1] : 'en'
  end

  def extract_request_id(payload)
    payload.dig('data', 'requestIdentifier') ||
      payload.dig('data', 'request_identifier') ||
      payload['requestIdentifier'] ||
      payload['request_identifier']
  end

  def detect_content_type(payload)
    request_id = extract_request_id(payload)
    return 'unknown' unless request_id

    REQUEST_ID_PATTERNS.each do |pattern, content_type|
      return content_type if request_id.start_with?(pattern)
    end

    'text'
  end

  def migrate_business(business_name, payloads)
    output_dir = File.join('tmp', 'bot_migration', business_name)
    FileUtils.mkdir_p(output_dir) unless @options[:dry_run]

    migration_data = {
      business_name: business_name,
      migrated_at: Time.now.iso8601,
      payloads: []
    }

    payloads.each do |payload_info|
      puts "  📄 #{payload_info[:file_name]} (#{payload_info[:language]})"
      puts "     Request ID: #{payload_info[:request_id]}"
      puts "     Content Type: #{payload_info[:content_type]}"

      converted = convert_payload(payload_info)
      migration_data[:payloads] << converted

      # Extract images
      images = extract_images(payload_info[:payload], business_name)
      save_images(images, output_dir, payload_info[:file_name]) unless @options[:dry_run]

      @stats[:payloads_converted] += 1
      puts
    end

    # Save migration data
    save_migration_data(migration_data, output_dir) unless @options[:dry_run]
  end

  def convert_payload(payload_info)
    original = payload_info[:payload]

    {
      # Metadata
      original_file: payload_info[:file_name],
      language: payload_info[:language],
      request_id: payload_info[:request_id],
      content_type: payload_info[:content_type],

      # Chatwoot template format
      template: {
        name: generate_template_name(payload_info),
        category: payload_info[:content_type],
        content_type: payload_info[:content_type],
        content: extract_content_text(original),
        content_attributes: transform_content_attributes(original)
      },

      # Original payload (for reference)
      original_payload: original
    }
  end

  def generate_template_name(payload_info)
    parts = []
    parts << payload_info[:request_id] if payload_info[:request_id]
    parts << payload_info[:content_type]
    parts << payload_info[:language] if payload_info[:language] != 'en'
    parts.join('_')
  end

  def extract_content_text(payload)
    # Extract text content from various locations
    payload.dig('receivedMessage', 'title') ||
      payload.dig('received_message', 'title') ||
      payload.dig('data', 'listPicker', 'title') ||
      payload.dig('data', 'list_picker', 'title') ||
      payload.dig('data', 'timePicker', 'title') ||
      payload.dig('data', 'time_picker', 'title') ||
      ''
  end

  def transform_content_attributes(payload)
    attrs = {}

    # Transform main data section
    if payload['data']
      payload['data'].each do |key, value|
        next if key == 'images' # Handle separately

        snake_key = camel_to_snake(key)
        attrs[snake_key] = transform_value(value)
      end
    end

    # Add received_message
    if payload['receivedMessage'] || payload['received_message']
      msg = payload['receivedMessage'] || payload['received_message']
      attrs['received_message'] = transform_object(msg)
    end

    # Add reply_message
    if payload['replyMessage'] || payload['reply_message']
      msg = payload['replyMessage'] || payload['reply_message']
      attrs['reply_message'] = transform_object(msg)
    end

    attrs
  end

  def transform_value(value)
    case value
    when Hash
      transform_object(value)
    when Array
      value.map { |v| transform_value(v) }
    else
      value
    end
  end

  def transform_object(obj)
    return obj unless obj.is_a?(Hash)

    obj.transform_keys { |key| camel_to_snake(key) }
       .transform_values { |value| transform_value(value) }
  end

  def camel_to_snake(str)
    return str unless str.is_a?(String)

    # Use predefined mappings first
    return CASE_MAPPINGS[str] if CASE_MAPPINGS[str]

    # Convert camelCase to snake_case
    str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
       .gsub(/([a-z\d])([A-Z])/, '\1_\2')
       .downcase
  end

  def extract_images(payload, business_name)
    images = []
    return images unless payload.dig('data', 'images')

    payload['data']['images'].each do |img|
      images << {
        identifier: img['identifier'],
        data: img['data'],
        business_name: business_name
      }
      @stats[:images_extracted] += 1
    end

    images
  end

  def save_images(images, output_dir, base_name)
    images_dir = File.join(output_dir, 'images')
    FileUtils.mkdir_p(images_dir)

    images.each do |img|
      filename = "#{base_name}_#{img[:identifier]}.png"
      filepath = File.join(images_dir, filename)

      begin
        decoded = Base64.decode64(img[:data])
        File.write(filepath, decoded)
        puts "     💾 Saved image: #{filename} (#{(decoded.size / 1024.0).round(2)} KB)"
      rescue StandardError => e
        @stats[:errors] << "Failed to save image #{filename}: #{e.message}"
      end
    end
  end

  def save_migration_data(data, output_dir)
    filepath = File.join(output_dir, 'migration_data.json')
    File.write(filepath, JSON.pretty_generate(data))
    puts "  ✅ Saved migration data: #{filepath}"
  end

  def print_summary
    puts
    puts '=' * 60
    puts '📊 Migration Summary'
    puts '=' * 60
    puts "Files processed: #{@stats[:files_processed]}"
    puts "Payloads converted: #{@stats[:payloads_converted]}"
    puts "Images extracted: #{@stats[:images_extracted]}"

    if @stats[:errors].any?
      puts
      puts "❌ Errors (#{@stats[:errors].size}):"
      @stats[:errors].each { |error| puts "  - #{error}" }
    end

    puts
    puts '✨ Migration complete!'
  end
end

# Parse command-line options
options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: ruby scripts/migrate_apple_bot.rb [options]'

  opts.on('--dry-run', 'Preview changes without importing') do
    options[:dry_run] = true
  end

  opts.on('--business TYPE', BUSINESS_TYPES.keys, 'Only migrate specific business') do |type|
    options[:business] = type
  end

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end
end.parse!

# Run migration
migration = AppleBotMigration.new(options)
migration.run
