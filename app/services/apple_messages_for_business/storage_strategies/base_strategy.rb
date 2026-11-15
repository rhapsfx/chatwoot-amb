# frozen_string_literal: true

module AppleMessagesForBusiness
  module StorageStrategies
    class BaseStrategy
      def initialize(template)
        @template = template
      end

      # Abstract methods - must be implemented by concrete strategies
      def load_data(block_type)
        raise NotImplementedError, "#{self.class.name}#load_data must be implemented"
      end

      def save_data(block_type, properties)
        raise NotImplementedError, "#{self.class.name}#save_data must be implemented"
      end

      def all_blocks
        raise NotImplementedError, "#{self.class.name}#all_blocks must be implemented"
      end

      def image_identifiers
        raise NotImplementedError, "#{self.class.name}#image_identifiers must be implemented"
      end

      def complexity_score
        raise NotImplementedError, "#{self.class.name}#complexity_score must be implemented"
      end

      protected

      # Shared normalization logic using CaseTransformer
      def normalize_properties(properties)
        return {} if properties.blank?

        AppleMessagesForBusiness::CaseTransformer.normalize_content_attributes(properties)
      end

      def denormalize_properties(properties)
        return {} if properties.blank?

        AppleMessagesForBusiness::CaseTransformer.to_apple_format(properties)
      end
    end
  end
end
