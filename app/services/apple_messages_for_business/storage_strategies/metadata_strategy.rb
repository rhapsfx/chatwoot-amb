# frozen_string_literal: true

module AppleMessagesForBusiness
  module StorageStrategies
    class MetadataStrategy < BaseStrategy
      def load_data(block_type)
        content_attrs = metadata_content_attributes

        # NEW UNIFIED FORMAT: Check if data is in flat format (has 'sections', 'event', 'pages' directly)
        # This indicates the template uses the new unified storage format
        block_data = case block_type
                     when 'list_picker'
                       if content_attrs['sections'].present?
                         # New flat format - return all content_attrs
                         content_attrs
                       else
                         # Old nested format - extract from list_picker key
                         content_attrs['list_picker'] || {}
                       end
                     when 'time_picker'
                       if content_attrs['event'].present?
                         # New flat format - return all content_attrs
                         content_attrs
                       else
                         # Old nested format - extract from time_picker key
                         content_attrs['time_picker'] || {}
                       end
                     when 'form'
                       if content_attrs['pages'].present?
                         # New flat format - return all content_attrs
                         content_attrs
                       else
                         # Old nested format - extract from form key
                         content_attrs['form'] || {}
                       end
                     when 'quick_reply'
                       if content_attrs['items'].present?
                         # New flat format - return all content_attrs
                         content_attrs
                       else
                         # Old nested format - extract from quick_reply key
                         content_attrs['quick_reply'] || {}
                       end
                     else
                       {}
                     end

        # Return normalized (snake_case) data without embedded images.
        normalize_properties(block_data).except('images')
      end

      def save_data(block_type, properties)
        @template.metadata ||= {}

        # Ensure metadata structure exists
        # Normalize properties to snake_case for storage
        normalized = normalize_properties(properties)

        if @template.metadata['apple_message_content'].present?
          @template.metadata['apple_message_content']['content_attributes'] ||= {}
          @template.metadata['apple_message_content']['content_attributes'][block_type] = normalized
        else
          # Backward-compatible top-level storage for legacy templates/tests
          @template.metadata[block_type] = normalized
        end

        # Add storage metadata
        @template.metadata['storage_strategy'] = 'metadata'
        @template.metadata['last_updated'] = Time.current.iso8601

        @template.save!
      end

      def all_blocks
        metadata_content_attributes
          .select { |_block_type, properties| properties.is_a?(Hash) }
          .transform_values { |properties| normalize_properties(properties) }
      end

      def image_identifiers
        identifiers = Set.new

        all_blocks.each do |block_type, properties|
          identifiers.merge(extract_identifiers_from_block(block_type, properties))
        end

        identifiers.to_a.compact
      end

      def complexity_score
        all_blocks.size
      end

      private

      def metadata_content_attributes
        metadata = @template.metadata
        return {} unless metadata.is_a?(Hash)

        nested_attrs = metadata.dig('apple_message_content', 'content_attributes')
        return nested_attrs if nested_attrs.is_a?(Hash)

        metadata.except('storage_strategy', 'last_updated', 'apple_message_content', 'apple_message_content_archived')
      end

      def extract_identifiers_from_block(type, props)
        identifiers = []

        case type
        when 'list_picker'
          identifiers << props['received_image_identifier']
          identifiers << props['reply_image_identifier']

          (props['sections'] || []).each do |section|
            (section['items'] || []).each do |item|
              identifiers << item['image_identifier']
            end
          end
          (props['images'] || []).each do |image|
            identifiers << image['identifier']
          end

        when 'time_picker', 'form'
          identifiers << props['received_image_identifier']
          identifiers << props['reply_image_identifier']
          (props['images'] || []).each do |image|
            identifiers << image['identifier']
          end
        end

        identifiers.compact
      end
    end
  end
end
