# frozen_string_literal: true

module AppleMessagesForBusiness
  class TemplateMigrator
    # Automatically migrates templates to optimal storage on first edit
    # Non-destructive: keeps original data until migration confirmed successful

    def initialize(template)
      @template = template
      @facade = TemplateFacade.new(template)
    end

    def migrate_if_needed!
      # Skip if already migrated
      return if migration_completed?

      # Determine target strategy
      target_strategy = determine_target_strategy

      # Skip if already using target strategy
      return if @facade.storage_type == target_strategy

      # Perform migration
      migrate_to_strategy(target_strategy)
    end

    private

    def migration_completed?
      @template.metadata&.dig('migration_completed_at').present?
    end

    def determine_target_strategy
      complexity = @facade.complexity_score

      if complexity <= TemplateFacade::COMPLEXITY_THRESHOLD
        'MetadataStrategy'
      else
        'ContentBlocksStrategy'
      end
    end

    def migrate_to_strategy(target_strategy)
      case target_strategy
      when 'MetadataStrategy'
        migrate_to_metadata
      when 'ContentBlocksStrategy'
        migrate_to_content_blocks
      end

      # Mark migration as complete
      @template.metadata ||= {}
      @template.metadata['migration_completed_at'] = Time.current.iso8601
      @template.metadata['migrated_from'] = @facade.storage_type
      @template.metadata['migrated_to'] = target_strategy
      @template.save!
    end

    def migrate_to_metadata
      # Load raw properties directly from content_blocks WITHOUT normalization
      # This prevents double-normalization which can corrupt data
      blocks = @template.content_blocks.map do |block|
        {
          'block_type' => block.block_type,
          'properties' => block.properties  # Raw properties from DB (already snake_case)
        }
      end

      # Save to metadata
      metadata_strategy = StorageStrategies::MetadataStrategy.new(@template)
      blocks.each do |block|
        metadata_strategy.save_data(block['block_type'], block['properties'])
      end

      # Archive content_blocks (don't delete for safety)
      @template.content_blocks.update_all(
        conditions: { 'archived' => true, 'archived_at' => Time.current.iso8601 }
      )

      Rails.logger.info "[TemplateMigrator] Migrated template #{@template.id} to metadata storage"
    end

    def migrate_to_content_blocks
      # Load raw properties directly from metadata WITHOUT extra normalization
      # Access metadata structure directly to avoid double-normalization
      content_attrs = @template.metadata&.dig('apple_message_content', 'content_attributes') || {}

      # Convert metadata structure to blocks array
      blocks = content_attrs.map do |block_type, properties|
        {
          'block_type' => block_type,
          'properties' => properties  # Raw properties from metadata (already snake_case)
        }
      end

      # Save to content_blocks
      blocks.each_with_index do |block, index|
        # Create content block with order
        @template.content_blocks.create!(
          block_type: block['block_type'],
          properties: block['properties'],
          order_index: index
        )
      end

      # Archive metadata content (keep for rollback)
      @template.metadata ||= {}
      @template.metadata['apple_message_content_archived'] =
        @template.metadata.delete('apple_message_content')
      @template.save!

      Rails.logger.info "[TemplateMigrator] Migrated template #{@template.id} to content_blocks storage"
    end
  end
end
