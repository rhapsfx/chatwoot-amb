# frozen_string_literal: true

module AppleMessagesForBusiness
  module StorageStrategies
    class ContentBlocksStrategy < BaseStrategy
      def load_data(block_type)
        content_block = @template.content_blocks.find_by(block_type: block_type)
        return {} unless content_block

        # Properties should already be in snake_case, but normalize to ensure consistency
        normalize_properties(content_block.properties || {})
      end

      def save_data(block_type, properties)
        # Normalize properties to snake_case
        normalized = normalize_properties(properties)

        # Find or create content block
        content_block = @template.content_blocks.find_or_initialize_by(
          block_type: block_type
        )

        content_block.properties = normalized
        content_block.save!

        # Mark template as using content_blocks strategy
        @template.metadata ||= {}
        @template.metadata['storage_strategy'] = 'content_blocks'
        @template.save! if @template.changed?
      end

      def all_blocks
        @template.content_blocks.order(:order_index).to_h do |block|
          [block.block_type, normalize_properties(block.properties || {})]
        end
      end

      def image_identifiers
        @template.extract_image_identifiers_from_blocks || []
      end

      def complexity_score
        all_blocks.size
      end
    end
  end
end
