# frozen_string_literal: true

module AppleMessagesForBusiness
  module Concerns
    module BotServiceInterface
      # BotServiceInterface provides a standardized contract for bot services to expose
      # handler methods metadata and enable dynamic discovery, validation, and documentation
      # of handler methods across different bot service implementations.
      #
      # This interface enables:
      # - Runtime discovery of available handler methods
      # - Type-safe handler method validation
      # - Rich metadata for UI components (Bot Studio)
      # - Service-agnostic handler method management
      #
      # @example Including in a bot service
      #   class AppleMessagesForBusiness::AcousticHouseBotService
      #     include AppleMessagesForBusiness::Concerns::BotServiceInterface
      #
      #     def self.handler_methods_metadata
      #       {
      #         handle_welcome: {
      #           handler_type: :state,
      #           display_name: 'Welcome Handler',
      #           description: 'Sends initial welcome message',
      #           category: 'onboarding',
      #           status: :stable
      #         }
      #       }
      #     end
      #   end
      #
      # @see docs/bot-studio/HANDLER_METHODS_ARCHITECTURE.md
      extend ActiveSupport::Concern

      # Custom error classes for handler method operations
      class HandlerMethodNotImplementedError < StandardError; end
      class HandlerMethodNotFoundError < StandardError; end
      class InvalidHandlerTypeError < StandardError; end

      # Valid handler types
      HANDLER_TYPES = %i[state keyword interactive action].freeze

  # rubocop:disable Metrics/BlockLength
  class_methods do
    # Returns metadata for all handler methods defined in the bot service.
    # This method MUST be implemented by any service including this interface.
    #
    # @return [Hash<Symbol, Hash>] Hash of method_name => metadata
    # @raise [HandlerMethodNotImplementedError] if not implemented by service
    #
    # @example Return format
    #   {
    #     handle_welcome: {
    #       handler_type: :state,
    #       display_name: 'Welcome Handler',
    #       description: 'Sends initial welcome message and prompts for region',
    #       parameters: {
    #         required: [],
    #         optional: ['custom_greeting']
    #       },
    #       returns: {
    #         type: 'state_transition',
    #         next_state: 'AHA2'
    #       },
    #       triggers: {
    #         state_ids: ['AHA1', 'AH-restart'],
    #         keywords: [],
    #         interactive_ids: []
    #       },
    #       dependencies: {
    #         templates: ['ah_welcome_message'],
    #         attributes: ['customer_name']
    #       },
    #       examples: [
    #         {
    #           scenario: 'First time user',
    #           input: 'User starts conversation',
    #           output: 'Welcome message with region prompt'
    #         }
    #       ],
    #       tags: ['welcome', 'onboarding', 'region'],
    #       category: 'onboarding',
    #       status: :stable
    #     }
    #   }
    def handler_methods_metadata
      raise HandlerMethodNotImplementedError,
            "#{name} must implement handler_methods_metadata class method"
    end

    # Check if a handler method exists in the service.
    # Checks both public and private instance methods.
    #
    # @param method_name [String, Symbol] Handler method name to check
    # @return [Boolean] true if method exists, false otherwise
    #
    # @example
    #   AcousticHouseBotService.handler_method_exists?(:handle_welcome)
    #   # => true
    #
    #   AcousticHouseBotService.handler_method_exists?(:nonexistent_method)
    #   # => false
    def handler_method_exists?(method_name)
      method_sym = method_name.to_sym
      method_defined?(method_sym) || private_method_defined?(method_sym)
    end

    # Get detailed signature information for a handler method.
    # Returns method arity, parameters, and source location.
    #
    # @param method_name [String, Symbol] Handler method name
    # @return [Hash, nil] Method signature details or nil if method not found
    #
    # @example
    #   AcousticHouseBotService.handler_method_signature(:handle_welcome)
    #   # => {
    #   #   arity: 0,
    #   #   parameters: [],
    #   #   source_location: ["/path/to/service.rb", 145]
    #   # }
    def handler_method_signature(method_name)
      method_sym = method_name.to_sym
      return nil unless handler_method_exists?(method_sym)

      method = instance_method(method_sym)
      {
        arity: method.arity,
        parameters: method.parameters,
        source_location: method.source_location
      }
    rescue NameError => e
      Rails.logger.warn("[BotServiceInterface] Failed to get signature for #{method_name}: #{e.message}")
      nil
    end

    # Get all handler methods filtered by handler type.
    #
    # @param handler_type [Symbol] Type to filter by (:state, :keyword, :interactive, :action)
    # @return [Array<Symbol>] Array of method names matching the type
    # @raise [InvalidHandlerTypeError] if handler_type is not valid
    #
    # @example
    #   AcousticHouseBotService.handler_methods_by_type(:state)
    #   # => [:handle_welcome, :handle_region_selection, :handle_form_response]
    #
    #   AcousticHouseBotService.handler_methods_by_type(:keyword)
    #   # => [:handle_menu, :handle_start_over, :handle_summary]
    def handler_methods_by_type(handler_type)
      handler_type_sym = handler_type.to_sym

      unless HANDLER_TYPES.include?(handler_type_sym)
        raise InvalidHandlerTypeError,
              "Invalid handler type: #{handler_type}. Must be one of: #{HANDLER_TYPES.join(', ')}"
      end

      handler_methods_metadata.select do |_, metadata|
        metadata[:handler_type] == handler_type_sym
      end.keys
    end

    # Validate that a handler method exists and is properly configured.
    # Returns detailed validation result with errors and warnings.
    #
    # @param method_name [String, Symbol] Handler method name to validate
    # @return [Hash] Validation result with :valid, :errors, :warnings keys
    #
    # @example Successful validation
    #   AcousticHouseBotService.validate_handler_method(:handle_welcome)
    #   # => {
    #   #   valid: true,
    #   #   errors: [],
    #   #   warnings: []
    #   # }
    #
    # @example Failed validation (method not found)
    #   AcousticHouseBotService.validate_handler_method(:nonexistent)
    #   # => {
    #   #   valid: false,
    #   #   errors: [
    #   #     {
    #   #       type: 'method_not_found',
    #   #       message: "Handler method 'nonexistent' does not exist in AcousticHouseBotService",
    #   #       suggestion: "Did you mean 'handle_menu'?"
    #   #     }
    #   #   ],
    #   #   warnings: []
    #   # }
    #
    # @example Warning (missing documentation)
    #   AcousticHouseBotService.validate_handler_method(:handle_undocumented)
    #   # => {
    #   #   valid: true,
    #   #   errors: [],
    #   #   warnings: [
    #   #     {
    #   #       type: 'no_documentation',
    #   #       message: "Handler method 'handle_undocumented' lacks documentation metadata"
    #   #     }
    #   #   ]
    #   # }
    # rubocop:disable Metrics/MethodLength
    def validate_handler_method(method_name)
      method_sym = method_name.to_sym
      errors = []
      warnings = []

      # Check if method exists
      unless handler_method_exists?(method_sym)
        similar_method = find_similar_method(method_sym)
        suggestion = similar_method ? "Did you mean '#{similar_method}'?" : nil

        errors << {
          type: 'method_not_found',
          message: "Handler method '#{method_name}' does not exist in #{name}",
          suggestion: suggestion
        }

        return { valid: false, errors: errors, warnings: warnings }
      end

      # Check if metadata exists
      metadata = handler_methods_metadata[method_sym]
      if metadata.nil?
        warnings << {
          type: 'no_documentation',
          message: "Handler method '#{method_name}' lacks documentation metadata"
        }
      else
        # Validate metadata structure
        validate_metadata_structure(method_sym, metadata, warnings)
      end

      { valid: errors.empty?, errors: errors, warnings: warnings }
    end
    # rubocop:enable Metrics/MethodLength

    private

    # Find similar method names using string similarity.
    # Helps provide suggestions when a method is not found.
    #
    # @param method_name [Symbol] Method name that wasn't found
    # @return [Symbol, nil] Most similar method name or nil if none found
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    def find_similar_method(method_name)
      all_handler_methods = instance_methods(false).select { |m| m.to_s.start_with?('handle_') } +
                            private_instance_methods(false).select { |m| m.to_s.start_with?('handle_') }

      return nil if all_handler_methods.empty?

      # Find method with longest common prefix
      method_str = method_name.to_s
      similar = all_handler_methods.max_by do |m|
        m_str = m.to_s
        common_length = method_str.chars.zip(m_str.chars).take_while { |a, b| a == b }.length
        common_length
      end

      # Only return if there's reasonable similarity (at least 5 characters match)
      similar if method_str.chars.zip(similar.to_s.chars).take_while { |a, b| a == b }.length >= 5
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

    # Validate metadata structure and add warnings for missing/invalid fields.
    #
    # @param method_name [Symbol] Method name being validated
    # @param metadata [Hash] Metadata hash to validate
    # @param warnings [Array<Hash>] Array to append warnings to
    # @return [void]
    # rubocop:disable Metrics/MethodLength
    def validate_metadata_structure(method_name, metadata, warnings)
      # Check required fields
      required_fields = %i[handler_type display_name description category status]
      required_fields.each do |field|
        next if metadata[field].present?

        warnings << {
          type: 'missing_required_field',
          message: "Handler method '#{method_name}' metadata missing required field: #{field}"
        }
      end

      # Validate handler_type
      if metadata[:handler_type].present? && HANDLER_TYPES.exclude?(metadata[:handler_type])
        warnings << {
          type: 'invalid_handler_type',
          message: "Handler method '#{method_name}' has invalid handler_type: #{metadata[:handler_type]}. " \
                   "Must be one of: #{HANDLER_TYPES.join(', ')}"
        }
      end

      # Check for description length (should be meaningful)
      return unless metadata[:description].present? && metadata[:description].length < 10

      warnings << {
        type: 'short_description',
        message: "Handler method '#{method_name}' has very short description. Consider adding more detail."
      }
    end
    # rubocop:enable Metrics/MethodLength
  end
  # rubocop:enable Metrics/BlockLength

  # Instance methods for bot service instances
  # (Currently no instance methods needed, but structure provided for future expansion)

  included do
    # This block runs when the module is included in a class
    # Can be used for instance-level setup if needed in the future
  end
    end
  end
end
