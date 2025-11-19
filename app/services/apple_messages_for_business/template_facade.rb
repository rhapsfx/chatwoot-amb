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
