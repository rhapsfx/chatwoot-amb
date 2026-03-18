# frozen_string_literal: true

# == Schema Information
#
# Table name: message_templates
#
#  id                  :bigint           not null, primary key
#  attachment_metadata :jsonb
#  category            :string
#  description         :text
#  metadata            :jsonb
#  name                :string           not null
#  parameters          :jsonb
#  status              :string           default("active")
#  supported_channels  :text             default([]), is an Array
#  tags                :text             default([]), is an Array
#  use_cases           :text             default([]), is an Array
#  version             :integer          default(1)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_message_templates_on_account_id               (account_id)
#  index_message_templates_on_account_id_and_category  (account_id,category)
#  index_message_templates_on_account_id_and_status    (account_id,status)
#  index_message_templates_on_attachment_metadata      (attachment_metadata) USING gin
#  index_message_templates_on_category                 (category)
#  index_message_templates_on_metadata                 (metadata) USING gin
#  index_message_templates_on_status                   (status)
#  index_message_templates_on_supported_channels       (supported_channels) USING gin
#  index_message_templates_on_tags                     (tags) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#

class MessageTemplate < ApplicationRecord
  include Rails.application.routes.url_helpers

  # Constants
  STATUSES = %w[active draft deprecated].freeze
  CATEGORIES = %w[
    general payment scheduling support marketing
    feedback notification confirmation sales
  ].freeze

  # Attachment constants
  MAX_ATTACHMENTS = 5
  MAX_ATTACHMENT_SIZE = 100.megabytes
  ALLOWED_ATTACHMENT_TYPES = %w[
    image/jpeg image/png image/gif image/webp image/heic
    video/mp4 video/quicktime video/mpeg
    audio/mpeg audio/mp4 audio/wav audio/aac
    application/pdf
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    text/plain text/csv
    application/zip application/x-7z-compressed application/vnd.rar
    model/vnd.usdz+zip model/usd
  ].freeze

  # Associations
  belongs_to :account
  has_many :content_blocks, class_name: 'TemplateContentBlock', dependent: :destroy
  has_many :channel_mappings, class_name: 'TemplateChannelMapping', dependent: :destroy
  has_many :usage_logs, class_name: 'TemplateUsageLog', dependent: :destroy
  has_many_attached :attachments

  accepts_nested_attributes_for :content_blocks, allow_destroy: true
  accepts_nested_attributes_for :channel_mappings, allow_destroy: true

  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id }
  validates :status, inclusion: { in: STATUSES }
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
  validates :version, numericality: { only_integer: true, greater_than: 0 }

  validate :validate_parameters_format
  validate :validate_supported_channels_format
  validate :validate_attachments_count
  validate :validate_attachments_size
  validate :validate_attachments_content_type

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :draft, -> { where(status: 'draft') }
  scope :deprecated, -> { where(status: 'deprecated') }

  scope :by_category, ->(category) { where(category: category) if category.present? }

  scope :compatible_with_channel, lambda { |channel_type|
    where('? = ANY(supported_channels)', channel_type) if channel_type.present?
  }

  scope :with_required_parameters, lambda { |param_names|
    return all if param_names.blank?

    param_array = Array(param_names)
    where(
      param_array.map { |_param| 'parameters ? :param' }.join(' AND '),
      param: param_array
    )
  }

  scope :tagged_with, lambda { |tag_names|
    return all if tag_names.blank?

    tag_array = Array(tag_names)
    where('tags && ARRAY[?]::text[]', tag_array)
  }

  scope :for_use_case, lambda { |use_case|
    where('? = ANY(use_cases)', use_case) if use_case.present?
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_version, ->(version) { where(version: version) if version.present? }

  # Instance Methods

  # Returns a bot-friendly summary of the template
  def bot_summary
    {
      id: id,
      name: name,
      category: category,
      description: description,
      channels: supported_channels,
      tags: tags,
      use_cases: use_cases,
      parameters: parameters_summary,
      content_blocks: content_blocks_summary,
      version: version,
      status: status
    }
  end

  # Check if the template is compatible with a specific channel
  def compatible_with?(channel_type)
    supported_channels.include?(channel_type.to_s)
  end

  # Get channel-specific mapping for a channel type
  def mapping_for_channel(channel_type)
    channel_mappings.find_by(channel_type: channel_type)
  end

  # Check if a parameter is required
  def parameter_required?(param_name)
    parameters.dig(param_name.to_s, 'required') == true
  end

  # Get default value for a parameter
  def parameter_default(param_name)
    parameters.dig(param_name.to_s, 'default')
  end

  # Validate provided parameters against template requirements
  def validate_provided_parameters(provided_params)
    errors_list = []

    parameters.each do |param_name, config|
      value = provided_params[param_name] || provided_params[param_name.to_sym]

      errors_list << "Required parameter '#{param_name}' is missing" if config['required'] && value.blank?

      next unless value.present? && config['type']

      errors_list << "Parameter '#{param_name}' has invalid type. Expected #{config['type']}" unless valid_parameter_type?(value, config['type'])
    end

    errors_list
  end

  # Create a new version of this template
  def create_new_version
    dup.tap do |new_template|
      new_template.version = version + 1
      new_template.status = 'draft'

      # Duplicate content blocks
      content_blocks.each do |block|
        new_template.content_blocks.build(block.attributes.except('id', 'message_template_id', 'created_at', 'updated_at'))
      end

      # Duplicate channel mappings
      channel_mappings.each do |mapping|
        new_template.channel_mappings.build(mapping.attributes.except('id', 'message_template_id', 'created_at', 'updated_at'))
      end
    end
  end

  # Returns lightweight JSON for list views — no content, no attachments
  def summary_json
    {
      id: id,
      name: name,
      category: category,
      description: description,
      supportedChannels: supported_channels || [],
      tags: tags || [],
      useCases: use_cases || [],
      status: status,
      version: version,
      metadata: metadata || {},
      createdAt: created_at,
      updatedAt: updated_at
    }
  end

  # Returns detailed JSON representation for API responses
  def detailed_json(include_content_blocks: false)
    # Build content first to catch any errors early
    content_data = build_content_safely

    result = {
      id: id,
      name: name,
      category: category,
      description: description,
      supportedChannels: supported_channels || [],
      tags: tags || [],
      useCases: use_cases || [],
      parameters: parameters || {},
      status: status,
      version: version,
      metadata: metadata || {},
      content: content_data,  # Use safely built content
      attachmentsSummary: attachments_summary(camel_case: true),  # Add attachments summary in camelCase
      createdAt: created_at,
      updatedAt: updated_at
    }.compact  # Remove nil values

    if include_content_blocks
      result[:contentBlocks] = content_blocks.order(:order_index).map do |block|
        {
          id: block.id,
          blockType: block.block_type,
          properties: block.properties || {},
          conditions: block.conditions || {},
          orderIndex: block.order_index
        }
      end

      result[:channelMappings] = channel_mappings.map do |mapping|
        {
          id: mapping.id,
          channelType: mapping.channel_type,
          contentType: mapping.content_type,
          fieldMappings: mapping.field_mappings || {}
        }
      end

      # Include referenced AppleListPickerImage records for time_picker and form blocks
      result[:referencedImages] = referenced_images
    end

    result
  end

  # Returns all AppleListPickerImage records referenced in content blocks
  # Extracts image identifiers from time_picker and form blocks and loads the images
  def referenced_images
    # Return empty array if template isn't persisted or has no account
    return [] unless persisted?
    return [] if account_id.nil?

    identifiers = extract_image_identifiers_from_blocks
    return [] if identifiers.empty?

    # Load images by identifier with error handling
    # AppleListPickerImage records are scoped to the account
    images = AppleListPickerImage.where(account_id: account_id, identifier: identifiers)

    # Serialize images in the same format as the API
    images.map do |image|
      {
        id: image.id,
        identifier: image.identifier,
        description: image.description,
        originalName: image.original_name,
        imageUrl: image.image_url,
        createdAt: image.created_at,
        updatedAt: image.updated_at
      }
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordNotFound => e
    # Log error but don't break template serialization
    Rails.logger.warn "[MessageTemplate] Failed to load referenced images: #{e.message}"
    []
  end

  # Extracts all image identifiers from content block properties
  # Looks for common image identifier fields in time_picker and form blocks
  def extract_image_identifiers_from_blocks
    identifiers = Set.new

    # Return empty set if content_blocks association isn't loaded or empty
    return identifiers unless content_blocks.loaded? || persisted?

    content_blocks.each do |block|
      properties = block.properties || {}

      case block.block_type
      when 'list_picker'
        # Extract from list_picker message properties
        identifiers << properties['received_image_identifier'] if properties['received_image_identifier'].present?
        identifiers << properties['reply_image_identifier'] if properties['reply_image_identifier'].present?
        identifiers << properties['receivedImageIdentifier'] if properties['receivedImageIdentifier'].present?
        identifiers << properties['replyImageIdentifier'] if properties['replyImageIdentifier'].present?

        # Extract from images array
        if properties['images'].is_a?(Array)
          properties['images'].each do |img|
            identifiers << img['identifier'] if img.is_a?(Hash) && img['identifier'].present?
          end
        end

        # Extract from section items
        sections = properties['sections'] || []
        sections.each do |section|
          items = section['items'] || []
          items.each do |item|
            # Handle both snake_case and camelCase
            identifiers << item['image_identifier'] if item['image_identifier'].present?
            identifiers << item['imageIdentifier'] if item['imageIdentifier'].present?
          end
        end

      when 'time_picker'
        # Extract from time_picker properties
        identifiers << properties['received_image_identifier'] if properties['received_image_identifier'].present?
        identifiers << properties['reply_image_identifier'] if properties['reply_image_identifier'].present?
        identifiers << properties['receivedImageIdentifier'] if properties['receivedImageIdentifier'].present?
        identifiers << properties['replyImageIdentifier'] if properties['replyImageIdentifier'].present?

        # Extract from nested event structure
        if properties['event'].is_a?(Hash)
          identifiers << properties['event']['image_identifier'] if properties['event']['image_identifier'].present?
          identifiers << properties['event']['imageIdentifier'] if properties['event']['imageIdentifier'].present?
        end

        # Extract from images array
        if properties['images'].is_a?(Array)
          properties['images'].each do |img|
            identifiers << img['identifier'] if img.is_a?(Hash) && img['identifier'].present?
          end
        end

      when 'form'
        # Extract from form properties
        if properties['received_message'].is_a?(Hash)
          identifiers << properties['received_message']['image_identifier'] if properties['received_message']['image_identifier'].present?
          identifiers << properties['received_message']['imageIdentifier'] if properties['received_message']['imageIdentifier'].present?
        end

        if properties['reply_message'].is_a?(Hash)
          identifiers << properties['reply_message']['image_identifier'] if properties['reply_message']['image_identifier'].present?
          identifiers << properties['reply_message']['imageIdentifier'] if properties['reply_message']['imageIdentifier'].present?
        end

        if properties['receivedMessage'].is_a?(Hash) && properties['receivedMessage']['imageIdentifier'].present?
          identifiers << properties['receivedMessage']['imageIdentifier']
        end

        if properties['replyMessage'].is_a?(Hash) && properties['replyMessage']['imageIdentifier'].present?
          identifiers << properties['replyMessage']['imageIdentifier']
        end

        # Extract from nested form structure
        if properties['form'].is_a?(Hash)
          form = properties['form']
          if form['received_message'].is_a?(Hash) && form['received_message']['image_identifier'].present?
            identifiers << form['received_message']['image_identifier']
          end
          if form['reply_message'].is_a?(Hash) && form['reply_message']['image_identifier'].present?
            identifiers << form['reply_message']['image_identifier']
          end
        end

        # Extract from images array
        if properties['images'].is_a?(Array)
          properties['images'].each do |img|
            identifiers << img['identifier'] if img.is_a?(Hash) && img['identifier'].present?
          end
        end

        # Extract from form images array (nested structure)
        if properties['form'].is_a?(Hash) && properties['form']['images'].is_a?(Array)
          properties['form']['images'].each do |img|
            identifiers << img['identifier'] if img.is_a?(Hash) && img['identifier'].present?
          end
        end

        # Extract from field options (singleSelect/multiSelect fields)
        pages = properties['pages'] || []
        pages.each do |page|
          items = page['items'] || []
          items.each do |item|
            next unless %w[singleSelect multiSelect].include?(item['item_type'])
            next unless item['options'].is_a?(Array)

            item['options'].each do |option|
              # Handle both snake_case and camelCase
              identifiers << option['image_identifier'] if option['image_identifier'].present?
              identifiers << option['imageIdentifier'] if option['imageIdentifier'].present?
            end
          end
        end
      end
    end

    identifiers.to_a.compact
  end

  # Safe wrapper around build_content with error handling
  def build_content_safely
    content = build_content
    # Recursively remove nil values from content
    deep_compact(content)
  rescue StandardError => e
    Rails.logger.error "[MessageTemplate] build_content failed for template #{id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    # Return empty hash instead of raising error
    {}
  end

  # Recursively remove nil values from hashes and arrays
  def deep_compact(obj)
    case obj
    when Hash
      obj.each_with_object({}) do |(key, value), result|
        compacted_value = deep_compact(value)
        result[key] = compacted_value unless compacted_value.nil?
      end
    when Array
      obj.map { |item| deep_compact(item) }.compact
    else
      obj
    end
  end

  # Build content from metadata or content blocks
  def build_content
    # UNIFIED TEMPLATE APPROACH: Use TemplateFacade for ALL Apple Messages templates
    # This ensures data is always returned in unified format (flat structure, snake_case)
    # regardless of whether it's stored in metadata or content_blocks
    if apple_messages_template?
      # Determine block type from either content_blocks or metadata
      block_type = if content_blocks.any?
                     content_blocks.first.block_type
                   elsif metadata.present? && metadata['apple_message_content'].present?
                     # Detect block type from metadata structure
                     detect_block_type_from_metadata
                   else
                     'list_picker' # default
                   end

      facade = AppleMessagesForBusiness::TemplateFacade.new(self)
      return { content_attributes: facade.load_data(block_type) }
    end

    # For non-Apple Messages templates:
    # If metadata has apple_message_content, use that (legacy path)
    return metadata['apple_message_content'] if metadata.present? && metadata['apple_message_content'].present?

    # Otherwise, try to build from content blocks
    return nil if content_blocks.empty?

    # For simple templates with one content block, return its properties
    if content_blocks.count == 1
      block = content_blocks.first
      # For quick_reply blocks, ensure the structure matches what the frontend expects
      return block.properties if block.block_type == 'quick_reply' && block.properties.present?
      return block.properties if block.properties.present?
    end

    # For complex templates, return an array of blocks
    content_blocks.order(:order_index).map(&:properties)
  end

  # Detect block type from metadata structure
  def detect_block_type_from_metadata
    return 'list_picker' unless metadata.present? && metadata['apple_message_content'].present?

    content = metadata['apple_message_content']
    attrs = content['content_attributes'] || content || {}

    # Check for list_picker indicators
    return 'list_picker' if attrs['sections'].present?
    return 'list_picker' if attrs['list_picker'].present?

    # Check for time_picker indicators
    return 'time_picker' if attrs['event'].present? && attrs.dig('event', 'timeslots').present?
    return 'time_picker' if attrs['time_picker'].present?

    # Check for form indicators
    return 'form' if attrs['pages'].present?
    return 'form' if attrs['form'].present?

    # Default to list_picker
    'list_picker'
  end

  # Check if this template is for Apple Messages for Business
  def apple_messages_template?
    supported_channels&.include?('apple_messages_for_business')
  end

  def apple_invitation_template?
    apple_messages_template? && metadata['invitation_template_id'].present?
  end

  def invitation_template_id
    metadata['invitation_template_id']
  end

  # Attachment Management Methods

  # Returns summary of all attachments with metadata
  def attachments_summary(camel_case: false)
    return [] unless attachments.attached?

    result = attachments.map do |attachment|
      stored_metadata = find_attachment_metadata(attachment.id)

      {
        id: attachment.id,
        filename: attachment.filename.to_s,
        content_type: attachment.content_type,
        byte_size: attachment.byte_size,
        url: url_for(attachment),
        created_at: attachment.created_at,
        display_order: stored_metadata&.dig('display_order'),
        description: stored_metadata&.dig('description'),
        metadata: stored_metadata
      }
    end.sort_by { |a| a[:display_order] || Float::INFINITY }

    return result unless camel_case

    # Transform to camelCase for API responses
    result.map do |attachment|
      {
        id: attachment[:id],
        name: attachment[:filename],
        contentType: attachment[:content_type],
        size: attachment[:byte_size],
        url: attachment[:url],
        preview: attachment[:content_type]&.start_with?('image/') ? attachment[:url] : nil,
        createdAt: attachment[:created_at],
        displayOrder: attachment[:display_order],
        description: attachment[:description],
        metadata: attachment[:metadata]
      }
    end
  end

  # Attach multiple files and update metadata
  def attach_files(files)
    return false if files.blank?

    ActiveRecord::Base.transaction do
      Array(files).each_with_index do |file, index|
        attachment = attachments.attach(file)
        next unless attachment

        # Get the newly attached file
        new_attachment = attachments.last

        # Update metadata for this attachment
        update_attachment_metadata(
          new_attachment.id,
          display_order: (attachment_metadata['attachments']&.length || 0) + index,
          attached_at: Time.current.iso8601
        )
      end

      save!
    end

    true
  rescue StandardError => e
    Rails.logger.error "Failed to attach files to MessageTemplate #{id}: #{e.message}"
    errors.add(:attachments, "Failed to attach files: #{e.message}")
    false
  end

  # Remove a specific attachment by ID
  def remove_attachment(attachment_id)
    attachment = attachments.find_by(id: attachment_id)
    return false unless attachment

    ActiveRecord::Base.transaction do
      # Remove from ActiveStorage
      attachment.purge

      # Remove from metadata
      remove_attachment_metadata(attachment_id)

      # Reindex remaining attachments
      reindex_attachment_display_order

      save!
    end

    true
  rescue StandardError => e
    Rails.logger.error "Failed to remove attachment #{attachment_id} from MessageTemplate #{id}: #{e.message}"
    errors.add(:attachments, "Failed to remove attachment: #{e.message}")
    false
  end

  # Reorder attachments by providing ordered array of attachment IDs
  def reorder_attachments(ordered_ids)
    return false if ordered_ids.blank?

    ActiveRecord::Base.transaction do
      ordered_ids.each_with_index do |attachment_id, index|
        update_attachment_metadata(attachment_id, display_order: index)
      end

      save!
    end

    true
  rescue StandardError => e
    Rails.logger.error "Failed to reorder attachments for MessageTemplate #{id}: #{e.message}"
    errors.add(:attachments, "Failed to reorder attachments: #{e.message}")
    false
  end

  private

  def parameters_summary
    return {} if parameters.blank?

    parameters.transform_values do |config|
      {
        type: config['type'],
        required: config['required'] || false,
        description: config['description'],
        default: config['default'],
        example: config['example']
      }.compact
    end
  end

  def content_blocks_summary
    content_blocks.order(:order_index).map do |block|
      {
        type: block.block_type,
        order: block.order_index,
        has_conditions: block.conditions.present?
      }
    end
  end

  def validate_parameters_format
    return if parameters.blank?

    unless parameters.is_a?(Hash)
      errors.add(:parameters, 'must be a hash')
      return
    end

    parameters.each do |param_name, config|
      unless config.is_a?(Hash)
        errors.add(:parameters, "parameter '#{param_name}' configuration must be a hash")
        next
      end

      errors.add(:parameters, "parameter '#{param_name}' must have a type") if config['type'].blank?

      if config['required'] && !config['required'].in?([true, false])
        errors.add(:parameters, "parameter '#{param_name}' required field must be boolean")
      end
    end
  end

  def validate_supported_channels_format
    return if supported_channels.blank?

    unless supported_channels.is_a?(Array)
      errors.add(:supported_channels, 'must be an array')
      return
    end

    supported_channels.each do |channel|
      unless channel.is_a?(String)
        errors.add(:supported_channels, 'all channels must be strings')
        break
      end
    end
  end

  def valid_parameter_type?(value, expected_type)
    case expected_type.to_s
    when 'string'
      value.is_a?(String)
    when 'integer', 'number'
      value.is_a?(Integer) || value.is_a?(Numeric)
    when 'boolean'
      value.in?([true, false])
    when 'array'
      value.is_a?(Array)
    when 'object', 'hash'
      value.is_a?(Hash)
    when 'datetime'
      value.is_a?(Time) || value.is_a?(DateTime) || begin
        value.is_a?(String) && Time.zone.parse(value)
      rescue StandardError
        false
      end
    else
      true # Unknown type, allow it
    end
  end

  # Attachment Validation Methods

  def validate_attachments_count
    return unless attachments.attached?

    return unless attachments.count > MAX_ATTACHMENTS

    errors.add(:attachments, "cannot exceed #{MAX_ATTACHMENTS} files")
  end

  def validate_attachments_size
    return unless attachments.attached?

    attachments.each do |attachment|
      next unless attachment.byte_size > MAX_ATTACHMENT_SIZE

      errors.add(
        :attachments,
        "file '#{attachment.filename}' exceeds maximum size of #{MAX_ATTACHMENT_SIZE / 1.megabyte}MB"
      )
    end
  end

  def validate_attachments_content_type
    return unless attachments.attached?

    attachments.each do |attachment|
      next if ALLOWED_ATTACHMENT_TYPES.include?(attachment.content_type)

      errors.add(
        :attachments,
        "file '#{attachment.filename}' has unsupported type '#{attachment.content_type}'"
      )
    end
  end

  # Attachment Metadata Management Methods

  def initialize_attachment_metadata
    self.attachment_metadata ||= { 'attachments' => [] }
  end

  def find_attachment_metadata(attachment_id)
    initialize_attachment_metadata
    attachment_metadata['attachments']&.find { |meta| meta['id'] == attachment_id.to_s }
  end

  def update_attachment_metadata(attachment_id, additional_metadata = {})
    initialize_attachment_metadata

    attachments_array = attachment_metadata['attachments'] || []
    existing_index = attachments_array.index { |meta| meta['id'] == attachment_id.to_s }

    metadata_entry = {
      'id' => attachment_id.to_s,
      'updated_at' => Time.current.iso8601
    }.merge(additional_metadata.stringify_keys)

    if existing_index
      attachments_array[existing_index].merge!(metadata_entry)
    else
      attachments_array << metadata_entry
    end

    self.attachment_metadata = attachment_metadata.merge('attachments' => attachments_array)
  end

  def remove_attachment_metadata(attachment_id)
    initialize_attachment_metadata

    attachments_array = attachment_metadata['attachments'] || []
    attachments_array.reject! { |meta| meta['id'] == attachment_id.to_s }

    self.attachment_metadata = attachment_metadata.merge('attachments' => attachments_array)
  end

  def reindex_attachment_display_order
    return unless attachments.attached?

    attachments.each_with_index do |attachment, index|
      update_attachment_metadata(attachment.id, display_order: index)
    end
  end
end
