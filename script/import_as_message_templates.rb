#!/usr/bin/env ruby
# frozen_string_literal: true

# Apple Messages Bot Import Script - MessageTemplate Version
# Imports migrated bot data as MessageTemplate records (visible in UI)
#
# Prerequisites:
#   - Run migrate_apple_bot.rb first
#   - Migration data in tmp/bot_migration/
#
# Usage:
#   rails runner scripts/import_as_message_templates.rb [--business TYPE] [--account-id ID] [--dry-run]

require 'json'

class MessageTemplateImporter
  attr_reader :options, :stats

  def initialize(options = {})
    @options = options
    @stats = {
      templates_created: 0,
      templates_would_create: 0,
      images_uploaded: 0,
      images_would_upload: 0,
      errors: []
    }
    @name_counter = {} # Track name usage for uniqueness
  end

  def run
    puts '🚀 Importing Bot Templates as MessageTemplates'
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
    # Check for filtered file first (removes duplicates and empty templates)
    filtered_file = File.join('tmp', 'bot_migration', business_name, 'migration_data_FILTERED.json')
    return filtered_file if File.exist?(filtered_file)

    # Check for CORE file (Apple-specific templates only)
    core_file = File.join('tmp', 'bot_migration', business_name, 'migration_data_CORE.json')
    return core_file if File.exist?(core_file)

    # Fall back to full migration file
    full_file = File.join('tmp', 'bot_migration', business_name, 'migration_data.json')
    return full_file if File.exist?(full_file)

    nil
  end

  def import_business(account, business_name, migration_file)
    data = JSON.parse(File.read(migration_file))

    if dry_run?
      preview_import(account, business_name, data)
    else
      execute_import(account, business_name, data)
    end
  end

  def preview_import(account, business_name, data)
    puts "  📊 Would import #{data['payloads'].size} templates as MessageTemplate records"
    puts "     Business type: #{business_name}"
    puts "     Filtered at: #{data['filtered_at'] || 'N/A'}"
    puts

    # Reset name counter for preview
    @name_counter = {}

    # Preview first 10 templates with their generated names
    puts '  📄 Sample templates (with generated names):'
    data['payloads'].first(10).each do |payload_data|
      template_data = payload_data['template']
      content_type = template_data['content_type']

      # Generate the actual name that will be used
      base_name = generate_descriptive_name(template_data, content_type)
      template_name = make_unique_name(account, base_name)

      puts "     • #{template_name}"
      puts "       - Original: #{template_data['name']}"
      puts "       - Content Type: #{content_type}"
      puts "       - Category: #{map_to_category(content_type)}"
      puts
      @stats[:templates_would_create] += 1
    end

    if data['payloads'].size > 10
      remaining = data['payloads'].size - 10
      puts "     ... and #{remaining} more templates"
      @stats[:templates_would_create] += remaining
    end
    puts

    # Note about images
    images_dir = File.join('tmp', 'bot_migration', business_name, 'images')
    return unless Dir.exist?(images_dir)

    image_count = Dir.glob(File.join(images_dir, '*.png')).size
    puts "  ℹ️  Found #{image_count} images (will need to be uploaded via UI per inbox)"
    @stats[:images_would_upload] = image_count
  end

  def execute_import(account, business_name, data)
    # Reset name counter for actual import to match preview
    @name_counter = {}

    data['payloads'].each do |payload_data|
      import_template(account, business_name, payload_data)
    end

    # Import images
    import_images(account, business_name)
  end

  def import_template(account, business_name, payload_data)
    template_data = payload_data['template']
    request_id = payload_data['request_id']
    content_type = template_data['content_type']
    content_attrs = template_data['content_attributes'] || {}

    # Detect actual content type from content_attributes if mislabeled as "text"
    if content_type == 'text' && content_attrs.present?
      if content_attrs['list_picker'].present?
        content_type = 'apple_list_picker'
      elsif content_attrs['time_picker'].present?
        content_type = 'apple_time_picker'
      elsif content_attrs.dig('dynamic', 'template') == 'formSelect'
        content_type = 'apple_form'
      elsif content_attrs['options'].present?
        content_type = 'apple_quick_reply'
      end
    end

    # Generate meaningful name based on template content
    base_name = generate_descriptive_name(template_data, content_type)
    template_name = make_unique_name(account, base_name)
    puts "  📄 Creating: #{template_name}"

    # Build block properties FIRST (before creating template)
    # This validates the template structure and may return nil for invalid templates
    block_properties = build_block_properties(content_type, template_data['content_attributes'] || {}, payload_data)

    # Skip if block_properties is nil (invalid template structure or navigation form)
    if block_properties.nil?
      puts '     ⚠️  Skipped: Invalid template structure'
      return
    end

    # Map content_type to MessageTemplate category
    category = map_to_category(content_type)

    # Determine supported channels (use lowercase with underscores, no "Channel::" prefix)
    supported_channels = if content_type.start_with?('apple_')
                           ['apple_messages_for_business']
                         else
                           %w[apple_messages_for_business whatsapp sms]
                         end

    # Create MessageTemplate
    template = MessageTemplate.create!(
      account: account,
      name: template_name,
      category: category,
      description: "Migrated from #{business_name} bot - #{payload_data['original_file']}",
      status: 'active',
      supported_channels: supported_channels,
      tags: [business_name, content_type, 'migrated'],
      use_cases: [determine_use_case(content_type)],
      version: 1,
      parameters: {},  # Could be extracted from content_attributes if needed
      metadata: {
        migrated_from: business_name,
        original_file: payload_data['original_file'],
        request_id: request_id,
        original_content_type: content_type,
        language: payload_data['language'],
        # Store Apple Messages specific content here
        apple_message_content: {
          content: template_data['content'],
          content_type: content_type,
          content_attributes: template_data['content_attributes']
        }
      }
    )

    # Create content block with the validated properties
    template.content_blocks.create!(
      block_type: map_to_block_type(content_type),
      properties: block_properties,
      order_index: 0
    )

    # Don't create channel mapping for migrated templates
    # Let the adapter use adapt_with_defaults which reads from content_blocks.properties
    # Creating a mapping with template variables ({{content_attributes}}) causes errors
    # because there are no parameters to substitute

    @stats[:templates_created] += 1
    puts "     ✅ Template created (ID: #{template.id})"
  rescue StandardError => e
    @stats[:errors] << "Failed to import template #{template_name}: #{e.message}"
    puts "     ❌ Error: #{e.message}"
  end

  def import_images(_account, _business_name)
    # Skip image import - AppleListPickerImage requires inbox_id
    # Images should be uploaded via the UI when using templates
    puts '  ℹ️  Skipping image import (images need to be uploaded per inbox via UI)'
    return

    # Original code commented out for reference:
    # images_dir = File.join('tmp', 'bot_migration', business_name, 'images')
    # return unless Dir.exist?(images_dir)
    #
    # puts "  🖼️  Uploading images..."
    #
    # Dir.glob(File.join(images_dir, '*.png')).first(10).each do |image_path|
    #   import_image(account, image_path)
    # end
    #
    # remaining = Dir.glob(File.join(images_dir, '*.png')).size - 10
    # puts "     ... and #{remaining} more images" if remaining > 0
  end

  def import_image(_account, _image_path)
    # This method is no longer used - see import_images comment above
    # AppleListPickerImage requires inbox_id which varies per conversation
    # Images should be uploaded via the UI when configuring templates for specific inboxes
    nil
  end

  def map_to_category(content_type)
    # Map bot content types to MessageTemplate categories
    case content_type
    when /list_picker/
      'general'
    when /time_picker/
      'scheduling'
    when /form/
      'support'
    when /pay/
      'payment'
    when /quick_reply/
      'general'
    when /authentication/
      'support'
    else
      'general'
    end
  end

  def map_to_block_type(content_type)
    # Map to content block types (must match TemplateContentBlock::BLOCK_TYPES)
    case content_type
    when /list_picker/
      'list_picker'
    when /time_picker/
      'time_picker'
    when /form/
      'form'
    when /pay/
      'apple_pay'
    when /quick_reply/
      'quick_reply'
    else
      'text'
    end
  end

  def determine_use_case(content_type)
    # Determine use case from content type
    case content_type
    when /list_picker/
      'product_selection'
    when /time_picker/
      'appointment_booking'
    when /form/
      'information_collection'
    when /pay/
      'payment_processing'
    when /quick_reply/
      'quick_response'
    else
      'general_communication'
    end
  end

  def generate_descriptive_name(template_data, content_type)
    content_attrs = template_data['content_attributes'] || {}
    content = template_data['content']

    case content_type
    when /list_picker/
      # Extract title from receivedMessage or first section
      title = content_attrs.dig('receivedMessage', 'title') ||
              content_attrs.dig('received_message', 'title') ||
              content_attrs.dig('sections', 0, 'title') ||
              content_attrs.dig('dynamic', 'page', 'title') ||
              'List Picker'
      sanitize_name(title)

    when /time_picker/
      # Extract title from receivedMessage
      title = content_attrs.dig('receivedMessage', 'title') ||
              content_attrs.dig('received_message', 'title') ||
              content_attrs.dig('dynamic', 'page', 'title') ||
              'Time Picker'
      sanitize_name(title)

    when /form/
      # Extract form title
      title = content_attrs.dig('receivedMessage', 'title') ||
              content_attrs.dig('received_message', 'title') ||
              content_attrs.dig('title') ||
              content_attrs.dig('dynamic', 'page', 'title') ||
              'Form'
      sanitize_name(title)

    when /quick_reply/
      # Extract title or first button text
      title = content_attrs.dig('title') ||
              content_attrs.dig('options', 0, 'title') ||
              content_attrs.dig('dynamic', 'page', 'title') ||
              'Quick Reply'
      sanitize_name(title)

    when /pay/
      # Extract payment description
      title = content_attrs.dig('payment', 'lineItems', 0, 'label') ||
              content_attrs.dig('dynamic', 'page', 'title') ||
              'Apple Pay'
      sanitize_name(title)

    else
      # For text messages, try multiple sources
      title = if content.present? && content.strip.length > 0
                # Use content if it's meaningful
                content.strip
              elsif content_attrs.dig('dynamic', 'page', 'title').present?
                # Use dynamic page title
                content_attrs.dig('dynamic', 'page', 'title')
              elsif content_attrs.dig('dynamic', 'template').present?
                # Use template type as context
                "#{content_attrs.dig('dynamic', 'template')} Message"
              else
                # Last resort fallback
                'Text Message'
              end

      # For longer content, take first few meaningful words
      if title.length > 50
        words = title.split(/\s+/).first(5).join(' ')
        sanitize_name("#{words}...")
      else
        sanitize_name(title)
      end
    end
  end

  def sanitize_name(name)
    # Remove special characters, limit length, make readable
    name.to_s
        .gsub(/[<>{}﹤﹥]/, '') # Remove angle brackets and special chars
        .gsub(/\s+/, ' ')       # Normalize spaces
        .strip
        .slice(0, 50)           # Limit to 50 chars
        .presence || 'Template'
  end

  def make_unique_name(account, base_name)
    # Initialize counter for this base name if not exists
    @name_counter[base_name] ||= 0

    # Try the base name first
    candidate = base_name

    # Keep incrementing counter until we find a unique name
    loop do
      # Check both in-memory counter and database
      exists_in_db = MessageTemplate.where(account: account, name: candidate).exists?

      unless exists_in_db
        # Mark this name as used
        @name_counter[base_name] = @name_counter[base_name] + 1
        return candidate
      end

      # Try next variant
      @name_counter[base_name] += 1
      candidate = "#{base_name} (#{@name_counter[base_name]})"
    end
  end

  def build_block_properties(content_type, content_attrs, payload_data = {})
    # Extract received and reply message data once (used by multiple types)
    received_msg = content_attrs['received_message'] || content_attrs['receivedMessage'] || {}
    reply_msg = content_attrs['reply_message'] || content_attrs['replyMessage'] || {}

    # Extract images from original_payload.data.images (for list picker and time picker)
    images_data = payload_data.dig('original_payload', 'data', 'images') || []
    images_array = images_data.map do |img|
      base64_data = img['data']
      next if base64_data.nil? || base64_data.empty?

      # Detect image format from base64 data
      image_format = if base64_data.start_with?('iVBORw0KGgo')
                       'png'
                     elsif base64_data.start_with?('/9j/')
                       'jpeg'
                     elsif base64_data.start_with?('R0lGODlh', 'R0lGODdh')
                       'gif'
                     elsif base64_data.start_with?('UklGR')
                       'webp'
                     elsif base64_data.start_with?('AAAAHG', 'AAAADGpQ')  # JP2/J2K
                       'jpeg'  # Treat JP2 as JPEG for compatibility
                     else
                       'png'  # Default fallback
                     end

      {
        'identifier' => img['identifier'],
        'data' => base64_data,
        # Add preview field for Vue component (full data URL with correct MIME type)
        'preview' => "data:image/#{image_format};base64,#{base64_data}",
        # Add metadata for better UI display
        'description' => "Migrated image #{img['identifier']}",
        'originalName' => "image_#{img['identifier']}.#{image_format}",
        'size' => (base64_data.length * 0.75).to_i  # Approximate original size
      }
    end.compact

    # Flatten message structures to match validator expectations
    # Validator expects: received_title, received_subtitle, reply_title, etc.
    # NOT nested: receivedMessage: { title: ..., subtitle: ... }
    flattened_messages = {
      'received_title' => received_msg['title'],
      'received_subtitle' => received_msg['subtitle'],
      'received_image_identifier' => received_msg['image_identifier'] || received_msg['imageIdentifier'],
      'received_style' => received_msg['style'],
      'reply_title' => reply_msg['title'],
      'reply_subtitle' => reply_msg['subtitle'],
      'reply_image_title' => reply_msg['image_title'] || reply_msg['imageTitle'],
      'reply_image_subtitle' => reply_msg['image_subtitle'] || reply_msg['imageSubtitle'],
      'reply_secondary_subtitle' => reply_msg['secondary_subtitle'] || reply_msg['secondarySubtitle'],
      'reply_tertiary_subtitle' => reply_msg['tertiary_subtitle'] || reply_msg['tertiarySubtitle'],
      'reply_image_identifier' => reply_msg['image_identifier'] || reply_msg['imageIdentifier'],
      'reply_style' => reply_msg['style']
    }.compact # Remove nil values

    case content_type
    when /list_picker/
      # Extract list picker structure
      # List Picker editor uses snake_case flat fields (received_title, reply_title)
      list_picker_data = content_attrs['list_picker'] || {}
      flattened_messages.merge({
                                 'sections' => list_picker_data['sections'] || [],
                                 'multiple_selection' => list_picker_data['multiple_selection'] || false,
                                 'images' => images_array  # Use extracted images from original_payload
                               })

    when /time_picker/
      # Extract time picker structure
      # Time Picker editor uses camelCase flat fields (receivedTitle, replyTitle)
      time_picker_data = content_attrs['time_picker'] || {}
      event_data = time_picker_data['event'] || {}

      # CRITICAL: Keep timeslots at top level (validator line 302 checks here)
      # Even though auto-generator moves them into event, validator expects top-level
      timeslots = time_picker_data['timeslots'] || event_data['timeslots'] || []

      # Convert snake_case to camelCase for Time Picker editor
      {
        'event' => event_data,
        'timeslots' => timeslots,
        'timezoneOffset' => content_attrs['timezone_offset'] || time_picker_data['timezone_offset'] || 0,
        'receivedTitle' => received_msg['title'] || 'Please pick a time',
        'receivedSubtitle' => received_msg['subtitle'] || 'Select your preferred time slot',
        'receivedImageIdentifier' => received_msg['image_identifier'] || received_msg['imageIdentifier'] || '',
        'receivedStyle' => received_msg['style'] || 'large',
        'replyTitle' => reply_msg['title'] || 'Thank you!',
        'replySubtitle' => reply_msg['subtitle'] || '',
        'replyImageIdentifier' => reply_msg['image_identifier'] || reply_msg['imageIdentifier'] || '',
        'replyStyle' => reply_msg['style'] || 'large',
        'replyImageTitle' => reply_msg['image_title'] || reply_msg['imageTitle'] || '',
        'replyImageSubtitle' => reply_msg['image_subtitle'] || reply_msg['imageSubtitle'] || '',
        'replySecondarySubtitle' => reply_msg['secondary_subtitle'] || reply_msg['secondarySubtitle'] || '',
        'replyTertiarySubtitle' => reply_msg['tertiary_subtitle'] || reply_msg['tertiarySubtitle'] || '',
        'images' => images_array  # Include images for time picker too
      }

    when /form/
      # Extract form structure
      # Forms can have 'pages' OR 'fields' structure (validator requires at least one)
      dynamic_config = content_attrs['dynamic'] || {}
      dynamic_page = dynamic_config['page'] || {}
      dynamic_data = dynamic_config['data'] || {}

      form_data = {
        'title' => dynamic_page['title'] || dynamic_data['splash']&.[]('splashtext') || content_attrs['title'] || '',
        'description' => content_attrs['description'] || '',
        'version' => content_attrs['version'] || dynamic_config['version'] || '1.0'
      }

      # Check for pages in various locations
      if dynamic_data['pages'].present?
        # Pages in dynamic.data.pages (e.g., covid_quest messageForms)
        form_data['pages'] = dynamic_data['pages']
      elsif dynamic_page['sections'].present?
        # Pages in dynamic.page.sections (e.g., formSelect)
        # Check if this is a navigation form (all fields are type: "page")
        sections = dynamic_page['sections'] || []
        first_section = sections[0] || {}
        fields = first_section['fields'] || []

        # Skip navigation-only forms (fields with type: "page" are navigation buttons)
        if fields.all? { |f| f['type'] == 'page' }
          puts '     ⚠️  Skipped: Navigation form (not a data collection form)'
          return nil
        end

        form_data['pages'] = [{
          'page_id' => '1',
          'title' => dynamic_page['title'] || '',
          'sections' => dynamic_page['sections'] || []
        }]
      elsif dynamic_page['fields'].present?
        # Dynamic page with flat fields
        form_data['fields'] = dynamic_page['fields']
      elsif content_attrs['fields'].present?
        # Direct fields structure
        form_data['fields'] = content_attrs['fields']
      else
        # No valid form structure - skip this template
        return nil
      end

      # CRITICAL: Forms need BOTH formats:
      # 1. Flattened snake_case for validator (received_title, reply_title)
      # 2. Nested camelCase for Vue editor (receivedMessage, replyMessage)
      flattened_messages.merge(form_data).merge({
                                                  # Add nested camelCase format for Vue Form Editor
                                                  'receivedMessage' => {
                                                    'title' => received_msg['title'] || form_data['title'] || '',
                                                    'subtitle' => received_msg['subtitle'] || form_data['description'] || '',
                                                    'imageIdentifier' => received_msg['image_identifier'] || received_msg['imageIdentifier'] || '',
                                                    'style' => received_msg['style'] || 'large'
                                                  }.compact,
                                                  'replyMessage' => {
                                                    'title' => reply_msg['title'] || '',
                                                    'subtitle' => reply_msg['subtitle'] || '',
                                                    'imageIdentifier' => reply_msg['image_identifier'] || reply_msg['imageIdentifier'] || '',
                                                    'style' => reply_msg['style'] || 'large'
                                                  }.compact,
                                                  'images' => images_array  # Include images for form editor
                                                })

    when /quick_reply/
      # Extract quick reply structure
      # Validator expects 'items' not 'options', and 'summary_text' is required
      # Check both 'quick_reply' and 'quick-reply' (hyphenated variant)
      quick_reply_data = content_attrs['quick_reply'] || content_attrs['quick-reply'] || {}

      flattened_messages.merge({
                                 'summary_text' => quick_reply_data['summary_text'] || content_attrs['title'] || content_attrs['summary_text'] || '',
                                 'items' => quick_reply_data['items'] || content_attrs['options'] || content_attrs['items'] || []
                               })

    else
      # For text and other types, use content_attributes as-is
      content_attrs
    end
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
      puts "Would create templates: #{@stats[:templates_would_create]}"
      puts "Images found (need UI upload): #{@stats[:images_would_upload]}" if @stats[:images_would_upload] > 0

      total_changes = @stats[:templates_would_create]
      puts
      puts "Templates that would be created: #{total_changes}"
    else
      puts "Templates created: #{@stats[:templates_created]}"
      puts "Images (need UI upload): #{@stats[:images_would_upload]}" if @stats[:images_would_upload] > 0
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
      cmd = 'rails runner scripts/import_as_message_templates.rb'
      cmd += " --account-id #{@options[:account_id]}" if @options[:account_id]
      cmd += " --business #{@options[:business]}" if @options[:business]
      puts "  #{cmd}"
    else
      puts '✨ Import complete!'
      puts
      puts '📋 Next steps:'
      puts '  1. Go to Settings → Message Templates in Chatwoot UI'
      puts '  2. You should see your imported templates'
      puts '  3. For templates with images (List Picker, Time Picker):'
      puts '     - Upload images via the Apple List Picker Image UI'
      puts '     - Reference them in templates using image identifiers'
      puts '  4. Test sending a template message in a conversation'
      puts
      puts '💡 To use templates in conversations:'
      puts '   - Open a conversation'
      puts '   - Click the template icon'
      puts '   - Search for templates by name or category'
      puts '   - Select and send!'
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
importer = MessageTemplateImporter.new(options)
importer.run
