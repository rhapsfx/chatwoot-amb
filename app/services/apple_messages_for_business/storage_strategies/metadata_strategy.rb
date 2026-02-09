# frozen_string_literal: true

module AppleMessagesForBusiness
  module StorageStrategies
    class MetadataStrategy < BaseStrategy
      def load_data(block_type)
        content_attrs = @template.metadata
                                 &.dig('apple_message_content', 'content_attributes') || {}

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

        # Return normalized (snake_case) data
        normalize_properties(block_data)
      end

      def save_data(block_type, properties)
        # Ensure metadata structure exists
        @template.metadata ||= {}
        @template.metadata['apple_message_content'] ||= {}
        @template.metadata['apple_message_content']['content_attributes'] ||= {}

        # Normalize properties to snake_case for storage
        normalized = normalize_properties(properties)

        # Store in metadata
        attrs = @template.metadata['apple_message_content']['content_attributes']
        attrs[block_type] = normalized

        # Add storage metadata
        @template.metadata['storage_strategy'] = 'metadata'
        @template.metadata['last_updated'] = Time.current.iso8601

        @template.save!
      end

      def all_blocks
        content_attrs = @template.metadata
                                 &.dig('apple_message_content', 'content_attributes') || {}

        content_attrs.map do |block_type, properties|
          {
            'block_type' => block_type,
            'properties' => normalize_properties(properties)
          }
        end
      end

      def image_identifiers
        identifiers = Set.new

        all_blocks.each do |block|
          identifiers.merge(extract_identifiers_from_block(block))
        end

        identifiers.to_a.compact
      end

      def complexity_score
        all_blocks.size
      end

      private

      def extract_identifiers_from_block(block)
        identifiers = []
        props = block['properties']
        type = block['block_type']

        case type
        when 'list_picker'
          identifiers << props['received_image_identifier']
          identifiers << props['reply_image_identifier']

          (props['sections'] || []).each do |section|
            (section['items'] || []).each do |item|
              identifiers << item['image_identifier']
            end
          end

        when 'time_picker', 'form'
          identifiers << props['received_image_identifier']
          identifiers << props['reply_image_identifier']
        end

        identifiers.compact
      end
    end
  end
end
