# frozen_string_literal: true

module AppleMessagesForBusiness
  class TemplateFacade
    # Unified interface for template data access
    # Automatically routes to optimal storage based on template complexity

    COMPLEXITY_THRESHOLD = 2  # Templates with ≤2 blocks use metadata

    def initialize(template)
      @template = template
      @storage_strategy = determine_storage_strategy
    end

    # Public API - consumers don't need to know storage details
    def load_data(block_type)
      @storage_strategy.load_data(block_type)
    end

    # Load data WITH images encoded (same as BotRendererService)
    # This is the method bot service should use for complete template rendering
    def load_data_with_images(block_type)
      # Get base template data
      data = load_data(block_type)

      # Load and encode images from storage
      load_images_into_data(data)
    end

    def save_data(block_type, properties)
      @storage_strategy.save_data(block_type, properties)
    end

    def all_blocks
      @storage_strategy.all_blocks
    end

    def image_identifiers
      @storage_strategy.image_identifiers
    end

    # Storage information (for debugging/monitoring)
    def storage_type
      @storage_strategy.class.name.demodulize
    end

    def complexity_score
      @storage_strategy.complexity_score
    end

    private

    # Load images from ActiveStorage and add them to the data hash
    # Uses ImageFetchService with three-tier fallback (inbox-specific, shared, embedded)
    def load_images_into_data(data)
      # Collect all image identifiers from the data
      identifiers = collect_image_identifiers(data)
      return data if identifiers.empty?

      # Extract embedded images from template data (if any)
      # These are images stored in the template's metadata or content_blocks
      embedded_images = extract_embedded_images(data)

      # Use ImageFetchService for three-tier fallback
      images = ImageFetchService.new(
        account_id: @template.account_id,
        inbox_id: nil, # Bot sends to any inbox
        embedded_images: embedded_images # Pass embedded images for tier 3 fallback
      ).fetch_and_encode(identifiers)

      # Add images array to data (in snake_case format)
      # IMPORTANT: Only include allowed keys to pass ContentAttributeValidator
      unless images.empty?
        data['images'] = images.map do |img|
          {
            'identifier' => img[:identifier],
            'data' => img[:data],
            'description' => img[:description] || ''
          }.compact
        end
      end

      data
    end

    # Extract embedded images from template data
    # Returns array of sanitized image hashes with only allowed keys
    def extract_embedded_images(data)
      embedded_images = data['images'] || []
      return [] if embedded_images.empty?

      # Sanitize images: only keep allowed keys (identifier, data, description)
      # Remove invalid keys like size, preview, original_name
      embedded_images.map do |img|
        {
          'identifier' => img['identifier'] || img[:identifier],
          'data' => img['data'] || img[:data],
          'description' => img['description'] || img[:description] || ''
        }.compact
      end
    end

    # Collect all image identifiers from data (works for all block types)
    def collect_image_identifiers(data)
      identifiers = []

      # List picker: sections items
      if data['sections'].present?
        data['sections'].each do |section|
          (section['items'] || []).each do |item|
            identifiers << item['image_identifier'] if item['image_identifier'].present?
          end
        end
      end

      # Form: pages items options
      if data['pages'].present?
        data['pages'].each do |page|
          (page['items'] || []).each do |item|
            next unless %w[singleSelect multiSelect].include?(item['item_type'])

            (item['options'] || []).each do |option|
              identifiers << option['image_identifier'] if option['image_identifier'].present?
            end
          end
        end
      end

      # Time picker/Form: received/reply images
      identifiers << data['received_image_identifier'] if data['received_image_identifier'].present?
      identifiers << data['reply_image_identifier'] if data['reply_image_identifier'].present?

      identifiers.compact.uniq
    end

    def determine_storage_strategy
      # Priority 1: Check if template has explicit storage preference
      return create_strategy(@template.metadata['storage_strategy']) if @template.metadata&.dig('storage_strategy')

      # Priority 2: Check for existing data and use its format
      return StorageStrategies::ContentBlocksStrategy.new(@template) if has_content_blocks?

      return StorageStrategies::MetadataStrategy.new(@template) if has_metadata_content?

      # Priority 3: For new templates, choose based on complexity
      # Default to metadata for simplicity
      StorageStrategies::MetadataStrategy.new(@template)
    end

    def has_content_blocks?
      @template.content_blocks.exists?
    end

    def has_metadata_content?
      @template.metadata.present? &&
        @template.metadata['apple_message_content'].present?
    end

    def create_strategy(strategy_name)
      case strategy_name
      when 'metadata'
        StorageStrategies::MetadataStrategy.new(@template)
      when 'content_blocks'
        StorageStrategies::ContentBlocksStrategy.new(@template)
      else
        raise ArgumentError, "Unknown storage strategy: #{strategy_name}"
      end
    end
  end
end
