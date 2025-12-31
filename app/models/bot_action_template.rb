# frozen_string_literal: true

# == Schema Information
#
# Table name: bot_action_templates
#
#  id              :bigint           not null, primary key
#  execution_order :integer          default(0)
#  metadata        :jsonb
#  name            :string           not null
#  parameters      :jsonb            not null
#  template_type   :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#
# Indexes
#
#  index_bot_action_templates_on_account_id           (account_id)
#  index_bot_action_templates_on_account_id_and_name  (account_id,name) UNIQUE
#  index_bot_action_templates_on_template_type        (template_type)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

class BotActionTemplate < ApplicationRecord
  # Template types supported by the bot action system
  TEMPLATE_TYPES = %w[
    send_text_message
    send_list_picker
    send_time_picker
    send_form
    send_rich_link
    send_quick_reply
    update_attributes
    conditional_branch
    send_apple_pay
    api_call
    send_imessage_app
    send_app_clip
  ].freeze

  # Parameter schemas for each template type
  # Defines required and optional parameters for validation
  PARAMETER_SCHEMAS = {
    'send_text_message' => {
      required: %w[message],
      optional: %w[delay_seconds]
    },
    'send_list_picker' => {
      required: %w[template_id],
      optional: %w[wait_for_response]
    },
    'send_time_picker' => {
      required: %w[template_id],
      optional: %w[timezone_offset]
    },
    'send_form' => {
      required: %w[template_id],
      optional: %w[pre_fill_data]
    },
    'send_rich_link' => {
      required: %w[url title],
      optional: %w[subtitle image_url]
    },
    'send_quick_reply' => {
      required: %w[message request_id items],
      optional: []
    },
    'update_attributes' => {
      required: %w[attributes],
      optional: []
    },
    'conditional_branch' => {
      required: %w[condition_type condition_value],
      optional: %w[true_action false_action]
    },
    'send_apple_pay' => {
      required: %w[merchant_id item_name amount],
      optional: %w[currency]
    },
    'api_call' => {
      required: %w[url method],
      optional: %w[headers body store_response_in]
    },
    'send_imessage_app' => {
      required: %w[app_id app_name],
      optional: %w[app_icon_url launch_url data]
    },
    'send_app_clip' => {
      required: %w[app_clip_url title],
      optional: %w[subtitle image_url action_title]
    }
  }.freeze

  # Associations
  belongs_to :account

  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id }
  validates :template_type, presence: true
  validates :template_type, inclusion: { in: TEMPLATE_TYPES }
  validates :execution_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Custom validation handles parameters (including presence of required parameters)
  validate :validate_template_parameters

  # Scopes
  scope :by_type, ->(type) { where(template_type: type) if type.present? }
  scope :ordered, -> { order(:execution_order, :created_at) }

  # Instance Methods

  # Returns the schema for this template's type
  def parameter_schema
    PARAMETER_SCHEMAS[template_type] || { required: [], optional: [] }
  end

  # Returns array of required parameter names
  def required_parameters
    parameter_schema[:required] || []
  end

  # Returns array of optional parameter names
  def optional_parameters
    parameter_schema[:optional] || []
  end

  # Returns array of all valid parameter names
  def valid_parameter_names
    required_parameters + optional_parameters
  end

  # Check if a specific parameter is required
  def parameter_required?(param_name)
    required_parameters.include?(param_name.to_s)
  end

  # Check if a specific parameter is optional
  def parameter_optional?(param_name)
    optional_parameters.include?(param_name.to_s)
  end

  # Validate that all required parameters are present and no unknown parameters exist
  def validate_provided_parameters(provided_params)
    errors_list = []
    provided_hash = provided_params.is_a?(Hash) ? provided_params.stringify_keys : {}

    # Check for missing required parameters
    required_parameters.each do |param_name|
      errors_list << "Required parameter '#{param_name}' is missing" if provided_hash[param_name].blank?
    end

    # Check for unknown parameters
    provided_hash.each_key do |param_name|
      unless valid_parameter_names.include?(param_name)
        errors_list << "Unknown parameter '#{param_name}' is not allowed for template type '#{template_type}'"
      end
    end

    errors_list
  end

  # Returns a summary of the template suitable for bot execution
  def execution_summary
    {
      id: id,
      name: name,
      type: template_type,
      parameters: parameters,
      metadata: metadata,
      execution_order: execution_order
    }
  end

  private

  # Validates that parameters hash contains all required parameters
  # and does not contain unknown parameters
  def validate_template_parameters
    # Parameters must be present (not nil)
    if parameters.nil?
      errors.add(:parameters, "can't be blank")
      return
    end

    # Parameters must be a Hash
    return add_parameter_type_error unless parameters.is_a?(Hash)
    return if parameter_schema.nil?

    # Validate required parameters are present and no unknown parameters
    validate_required_parameters_present
    validate_no_unknown_parameters
  end

  def validate_required_parameters_present
    required_parameters.each do |param_name|
      next if parameter_present?(param_name)

      errors.add(:parameters, "missing required parameter '#{param_name}' for template type '#{template_type}'")
    end
  end

  def validate_no_unknown_parameters
    unknown_params = parameters.keys.map(&:to_s) - valid_parameter_names
    return unless unknown_params.any?

    errors.add(
      :parameters,
      "contains unknown parameters: #{unknown_params.join(', ')} (allowed: #{valid_parameter_names.join(', ')})"
    )
  end

  def parameter_present?(param_name)
    parameters[param_name].present? || parameters[param_name.to_sym].present?
  end

  def add_parameter_type_error
    errors.add(:parameters, 'must be a hash')
  end
end
