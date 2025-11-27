# frozen_string_literal: true

module AppleMessagesForBusiness
  # Centralizes all snake_case ↔ camelCase transformations for Apple Messages for Business
  #
  # Design Principle:
  #   - Internal storage (database, services): ALWAYS snake_case (Rails convention)
  #   - External APIs (frontend input, Apple MSP output): camelCase
  #   - Single source of truth for all field mappings
  #
  # Usage:
  #   # Convert internal snake_case → Apple MSP camelCase
  #   CaseTransformer.to_apple_format(hash, context: :received_message)
  #
  #   # Convert frontend/Apple camelCase → internal snake_case
  #   CaseTransformer.from_apple_format(hash)
  #
  #   # Normalize any mixed-case input → snake_case
  #   CaseTransformer.normalize_content_attributes(hash)
  #
  module CaseTransformer
    # Complete field mapping: snake_case → camelCase for Apple MSP API
    # These are context-independent direct mappings
    TO_APPLE_MAPPINGS = {
      # Image identifiers (context-dependent - see CONTEXT_MAPPINGS)
      'image_identifier' => 'imageIdentifier',

      # Message structures
      'received_message' => 'receivedMessage',
      'reply_message' => 'replyMessage',

      # List picker specific
      'multiple_selection' => 'multipleSelection',

      # Time picker specific
      'timezone_offset' => 'timezoneOffset',
      'start_time' => 'startTime',

      # Quick reply
      'summary_text' => 'summaryText',

      # Form specific
      'page_id' => 'pageIdentifier',
      'item_id' => 'itemId',
      'item_type' => 'itemType',
      'default_value' => 'defaultValue',
      'max_length' => 'maxLength',
      'min_length' => 'minLength',
      'keyboard_type' => 'keyboardType',
      'text_content_type' => 'textContentType',
      'min_value' => 'minValue',
      'max_value' => 'maxValue',
      'picker_type' => 'pickerType',
      'picker_options' => 'pickerOptions',
      'button_style' => 'buttonStyle',
      'image_url' => 'imageUrl',
      'use_live_layout' => 'useLiveLayout',
      'show_summary' => 'showSummary',
      'next_page_identifier' => 'nextPageIdentifier',
      'submit_form' => 'submitForm',
      'date_format' => 'dateFormat',
      'min_date' => 'minDate',
      'max_date' => 'maxDate',
      'toggle_style' => 'toggleStyle',
      'start_date' => 'startDate',
      'maximum_date' => 'maximumDate',
      'label_text' => 'labelText',
      'maximum_character_count' => 'maximumCharacterCount',

      # Common message fields
      'source_id' => 'sourceId',
      'destination_id' => 'destinationId',
      'request_identifier' => 'requestIdentifier',
      'interactive_data' => 'interactiveData',

      # Rich link
      'mime_type' => 'mimeType',
      'video_url' => 'videoUrl',
      'video_mime_type' => 'videoMimeType',
      'site_name' => 'siteName',

      # Custom app
      'app_id' => 'appId',
      'app_name' => 'appName',

      # Payment
      'merchant_identifier' => 'merchantIdentifier',
      'merchant_name' => 'merchantName',
      'country_code' => 'countryCode',
      'currency_code' => 'currencyCode',
      'payment_networks' => 'paymentNetworks',
      'line_items' => 'lineItems',
      'total_label' => 'totalLabel',
      'total_type' => 'totalType',
      'payment_request' => 'paymentRequest',
      'merchant_session' => 'merchantSession',
      'payment_gateway_url' => 'paymentGatewayUrl',
      'apple_pay' => 'applePay',
      'supported_networks' => 'supportedNetworks',
      'merchant_capabilities' => 'merchantCapabilities',
      'required_billing_contact_fields' => 'requiredBillingContactFields',
      'required_shipping_contact_fields' => 'requiredShippingContactFields',

      # OAuth
      'response_type' => 'responseType',
      'response_encryption_key' => 'responseEncryptionKey',
      'redirect_uri' => 'redirectURI'  # Apple uses uppercase 'URI' per AuthV2 spec
    }.freeze

    # Fields that change name based on context
    # e.g., received_title → title (in receivedMessage context)
    CONTEXT_MAPPINGS = {
      received_message: {
        'received_title' => 'title',
        'received_subtitle' => 'subtitle',
        'received_image_identifier' => 'imageIdentifier',
        'received_style' => 'style'
      },
      reply_message: {
        'reply_title' => 'title',
        'reply_subtitle' => 'subtitle',
        'reply_image_identifier' => 'imageIdentifier',
        'reply_style' => 'style',
        'reply_image_title' => 'imageTitle',
        'reply_image_subtitle' => 'imageSubtitle',
        'reply_secondary_subtitle' => 'secondarySubtitle',
        'reply_tertiary_subtitle' => 'tertiarySubtitle'
      }
    }.freeze

    # Fields that should NEVER be transformed (keep as-is)
    # These are Apple MSP standard fields with established casing
    PRESERVE_KEYS = %w[
      identifier title subtitle description style order duration
      v id type bid data version placeholder label name value
      required pattern options default state
      images items sections pages timeslots event location
      oauth2 payment form fields
    ].freeze

    class << self
      # Convert snake_case hash to camelCase for Apple MSP API
      #
      # @param hash [Hash] Input hash with snake_case keys
      # @param context [Symbol, nil] Context for transformation
      #   - :received_message - Transform received_* fields → base fields
      #   - :reply_message - Transform reply_* fields → base fields
      #   - :item - List picker item
      #   - :section - List picker section
      #   - :event - Time picker event
      #   - nil - Default transformation
      # @return [Hash] Output hash with camelCase keys (symbolized)
      #
      # @example
      #   input = { 'received_title' => 'Select', 'received_image_identifier' => 'img_123' }
      #   CaseTransformer.to_apple_format(input, context: :received_message)
      #   # => { title: 'Select', imageIdentifier: 'img_123' }
      #
      def to_apple_format(hash, context: nil)
        return hash unless hash.is_a?(Hash)

        transformed = {}

        hash.each do |key, value|
          string_key = key.to_s

          # Skip nil values
          next if value.nil?

          # Check if this key should be preserved as-is
          if PRESERVE_KEYS.include?(string_key)
            transformed[string_key.to_sym] = transform_value(value, context)
            next
          end

          # Apply context-specific mapping if available
          if context && CONTEXT_MAPPINGS[context]&.key?(string_key)
            camel_key = CONTEXT_MAPPINGS[context][string_key]
            transformed[camel_key.to_sym] = transform_value(value, context)
            next
          end

          # Apply standard mapping
          if TO_APPLE_MAPPINGS.key?(string_key)
            camel_key = TO_APPLE_MAPPINGS[string_key]
            transformed[camel_key.to_sym] = transform_value(value, context)
            next
          end

          # Default: use ActiveSupport's camelize for unmapped fields
          camel_key = string_key.camelize(:lower)
          transformed[camel_key.to_sym] = transform_value(value, context)
        end

        transformed
      end

      # Convert camelCase hash to snake_case for internal storage
      #
      # @param hash [Hash] Input hash with camelCase keys
      # @return [Hash] Output hash with snake_case keys (string keys)
      #
      # @example
      #   input = { 'imageIdentifier' => 'img_123', 'multipleSelection' => true }
      #   CaseTransformer.from_apple_format(input)
      #   # => { 'image_identifier' => 'img_123', 'multiple_selection' => true }
      #
      def from_apple_format(hash)
        return hash unless hash.is_a?(Hash)

        # Build reverse mapping on first use
        @reverse_mapping ||= build_reverse_mapping

        transformed = {}

        hash.each do |key, value|
          string_key = key.to_s

          # Skip nil values
          next if value.nil?

          # Check if this key should be preserved as-is
          if PRESERVE_KEYS.include?(string_key)
            transformed[string_key] = transform_value_from_apple(value)
            next
          end

          # Apply reverse mapping
          if @reverse_mapping.key?(string_key)
            snake_key = @reverse_mapping[string_key]
            transformed[snake_key] = transform_value_from_apple(value)
            next
          end

          # Default: use ActiveSupport's underscore for unmapped fields
          snake_key = string_key.underscore
          transformed[snake_key] = transform_value_from_apple(value)
        end

        transformed
      end

      # Normalize any mixed-case hash to consistent snake_case
      # This is a convenience method that calls from_apple_format
      #
      # @param hash [Hash] Input hash with potentially mixed casing
      # @return [Hash] Output hash with snake_case keys
      #
      # @example
      #   input = { 'imageIdentifier' => 'img_123', 'received_title' => 'Test' }
      #   CaseTransformer.normalize_content_attributes(input)
      #   # => { 'image_identifier' => 'img_123', 'received_title' => 'Test' }
      #
      def normalize_content_attributes(hash)
        from_apple_format(hash)
      end

      private

      # Build reverse mapping: camelCase → snake_case
      # Includes both direct mappings and context mappings
      def build_reverse_mapping
        reverse = {}

        # Add direct mappings
        TO_APPLE_MAPPINGS.each do |snake, camel|
          reverse[camel] = snake
        end

        # Add context-specific mappings with prefixes preserved
        CONTEXT_MAPPINGS.each_value do |context_map|
          context_map.each do |snake, camel|
            # For reverse mapping, we want to preserve the prefix
            # e.g., receivedImageIdentifier → received_image_identifier
            reverse[camel] ||= snake
          end
        end

        # Special cases for context fields that map to same camelCase
        # These need to preserve their prefix when converting back
        reverse['imageIdentifier'] = 'image_identifier' # Default
        # Note: receivedImageIdentifier, replyImageIdentifier will be handled by context

        reverse
      end

      # Transform a value recursively
      def transform_value(value, context)
        case value
        when Hash
          # Detect nested context from key patterns
          nested_context = detect_nested_context(value, context)
          to_apple_format(value, context: nested_context)
        when Array
          value.map { |item| transform_value(item, context) }
        else
          value
        end
      end

      # Transform a value recursively (from Apple format)
      def transform_value_from_apple(value)
        case value
        when Hash
          from_apple_format(value)
        when Array
          value.map { |item| transform_value_from_apple(item) }
        else
          value
        end
      end

      # Detect nested context based on hash structure
      # This helps apply correct transformations to nested objects
      def detect_nested_context(hash, parent_context)
        # If already in a specific context, maintain it for nested structures
        return parent_context if parent_context && parent_context != :default

        # Check if this hash looks like a received_message or reply_message
        keys = hash.keys.map(&:to_s)

        if keys.any? { |k| k.start_with?('received_') }
          :received_message
        elsif keys.any? { |k| k.start_with?('reply_') }
          :reply_message
        end
      end
    end
  end
end
