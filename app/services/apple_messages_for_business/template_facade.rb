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
      metadata_blocks = StorageStrategies::MetadataStrategy.new(@template).all_blocks
      content_block_blocks = StorageStrategies::ContentBlocksStrategy.new(@template).all_blocks

      # Content blocks take precedence for duplicate block types.
      metadata_blocks.merge(content_block_blocks)
    end

    def image_identifiers
      all_blocks.values.flat_map { |block_data| extract_image_identifiers(block_data) }.uniq
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
      extract_image_identifiers(data)
    end

    def determine_storage_strategy
      # Priority 1: Check if template has explicit storage preference
      if @template.metadata.is_a?(Hash) && @template.metadata['storage_strategy'].present?
        return create_strategy(@template.metadata['storage_strategy'])
      end

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
      return false unless @template.metadata.is_a?(Hash)

      @template.metadata['apple_message_content'].present? ||
        @template.metadata.any? { |key, value| value.is_a?(Hash) && !%w[apple_message_content apple_message_content_archived].include?(key) }
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

    # Backward-compatible helper used by specs and internal callers.
    def detect_storage_strategy(block_type)
      return @template.metadata['storage_strategy'] if @template.metadata.is_a?(Hash) && @template.metadata['storage_strategy'].present?
      return 'metadata' if @template.metadata.is_a?(Hash) && @template.metadata[block_type].is_a?(Hash)
      return 'metadata' if @template.metadata.is_a?(Hash) && @template.metadata.dig('apple_message_content', 'content_attributes',
                                                                                    block_type).is_a?(Hash)
      return 'content_blocks' if @template.content_blocks.where(block_type: block_type).exists?

      'metadata'
    end

    # Recursively extract image identifiers from rich nested structures.
    def extract_image_identifiers(data)
      identifiers = []

      case data
      when Hash
        data.each do |key, value|
          key_name = key.to_s
          if %w[image_identifier received_image_identifier reply_image_identifier].include?(key_name) && value.present?
            identifiers << value
            next
          end

          if key_name == 'images' && value.is_a?(Array)
            value.each do |image|
              next unless image.is_a?(Hash)

              identifier = image['identifier'] || image[:identifier]
              identifiers << identifier if identifier.present?
            end
          end

          identifiers.concat(extract_image_identifiers(value))
        end
      when Array
        data.each { |item| identifiers.concat(extract_image_identifiers(item)) }
      end

      identifiers.compact.uniq
    end
  end
end
