# frozen_string_literal: true

# HandlerMethodsRegistry - Centralized handler method discovery and management
#
# This service provides a unified interface for discovering, validating, and searching
# handler methods across bot services. It enables dynamic lookup and fuzzy search
# capabilities for the Bot Studio interface.
#
# Features:
# - Dynamic handler discovery from bot services
# - Handler metadata extraction and enrichment
# - Handler existence and configuration validation
# - Fuzzy search with similarity scoring
# - "Did you mean" suggestions for typos
#
# Usage:
#   # Discover all handlers
#   handlers = HandlerMethodsRegistry.discover_handlers(AcousticHouseBotService)
#
#   # Get specific handler metadata
#   metadata = HandlerMethodsRegistry.get_handler_metadata(
#     AcousticHouseBotService,
#     'handle_welcome'
#   )
#
#   # Validate handler exists
#   result = HandlerMethodsRegistry.validate_handler(
#     AcousticHouseBotService,
#     'handle_custom_state'
#   )
#
#   # Search handlers with fuzzy matching
#   results = HandlerMethodsRegistry.search_handlers(
#     AcousticHouseBotService,
#     'welcome',
#     limit: 10
#   )
#
# rubocop:disable Metrics/ClassLength
class AppleMessagesForBusiness::HandlerMethodsRegistry
  # Minimum match score threshold for search results
  MIN_MATCH_SCORE = 0.3

  # Maximum Levenshtein distance for similarity suggestions
  MAX_SUGGESTION_DISTANCE = 3

  # Default search result limit
  DEFAULT_SEARCH_LIMIT = 20

  class << self
    # Discover all handler methods from a bot service
    #
    # @param service_class [Class] Bot service class that implements BotServiceInterface
    # @return [Hash<Symbol, Hash>] method_name => metadata
    # @raise [ArgumentError] if service_class doesn't include BotServiceInterface
    #
    # @example
    #   handlers = HandlerMethodsRegistry.discover_handlers(AcousticHouseBotService)
    #   # => { handle_welcome: { method_name: 'handle_welcome', ... }, ... }
    #
    def discover_handlers(service_class)
      validate_service_class!(service_class)

      begin
        service_class.handler_methods_metadata
      rescue NotImplementedError => e
        Rails.logger.warn("[HandlerMethodsRegistry] #{service_class.name} hasn't implemented handler_methods_metadata: #{e.message}")
        {}
      rescue StandardError => e
        Rails.logger.error("[HandlerMethodsRegistry] Error discovering handlers from #{service_class.name}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        {}
      end
    end

    # Get detailed metadata for a specific handler method
    #
    # @param service_class [Class] Bot service class
    # @param method_name [String, Symbol] Handler method name
    # @return [Hash, nil] Handler metadata or nil if not found
    #
    # @example
    #   metadata = HandlerMethodsRegistry.get_handler_metadata(
    #     AcousticHouseBotService,
    #     'handle_welcome'
    #   )
    #   # => { method_name: 'handle_welcome', handler_type: 'state', ... }
    #
    def get_handler_metadata(service_class, method_name)
      validate_service_class!(service_class)

      method_sym = method_name.to_sym
      metadata = service_class.handler_methods_metadata[method_sym]
      return nil unless metadata

      # Enrich with runtime data
      enrich_metadata(service_class, method_sym, metadata)
    rescue StandardError => e
      Rails.logger.error("[HandlerMethodsRegistry] Error getting metadata for #{method_name}: #{e.message}")
      nil
    end

    # Validate that a handler method exists and is properly configured
    #
    # @param service_class [Class] Bot service class
    # @param method_name [String, Symbol] Handler method name
    # @return [Hash] Validation result with :valid, :errors, :warnings keys
    #
    # @example
    #   result = HandlerMethodsRegistry.validate_handler(
    #     AcousticHouseBotService,
    #     'handle_custom_state'
    #   )
    #   # => {
    #   #   valid: false,
    #   #   errors: [{ type: 'method_not_found', message: '...', suggestion: '...' }],
    #   #   warnings: []
    #   # }
    #
    # rubocop:disable Metrics/MethodLength
    def validate_handler(service_class, method_name)
      validate_service_class!(service_class)

      errors = []
      warnings = []

      # Check if method exists
      unless service_class.handler_method_exists?(method_name)
        suggestion = find_similar_method(service_class, method_name)
        errors << {
          type: 'method_not_found',
          message: "Handler method '#{method_name}' does not exist in #{service_class.name}",
          suggestion: suggestion
        }
        return { valid: false, errors: errors, warnings: warnings }
      end

      # Check if metadata exists
      metadata = service_class.handler_methods_metadata[method_name.to_sym]
      if metadata.nil?
        warnings << {
          type: 'no_documentation',
          message: "Handler method '#{method_name}' lacks documentation metadata"
        }
      else
        # Validate metadata completeness
        validate_metadata_completeness(metadata, warnings)
      end

      # Check method signature
      begin
        signature = service_class.handler_method_signature(method_name)
        if signature.nil?
          warnings << {
            type: 'signature_unavailable',
            message: "Unable to retrieve method signature for '#{method_name}'"
          }
        end
      rescue StandardError => e
        warnings << {
          type: 'signature_error',
          message: "Error retrieving signature: #{e.message}"
        }
      end

      { valid: errors.empty?, errors: errors, warnings: warnings }
    rescue StandardError => e
      {
        valid: false,
        errors: [{
          type: 'validation_error',
          message: "Validation failed: #{e.message}"
        }],
        warnings: []
      }
    end
    # rubocop:enable Metrics/MethodLength

    # Search handler methods with fuzzy matching and scoring
    #
    # @param service_class [Class] Bot service class
    # @param query [String] Search query
    # @param options [Hash] Search options
    # @option options [Integer] :limit Maximum results (default: 20)
    # @option options [String] :handler_type Filter by handler type
    # @option options [String] :category Filter by category
    # @option options [String] :status Filter by status
    # @return [Array<Hash>] Search results sorted by match score (descending)
    #
    # @example
    #   results = HandlerMethodsRegistry.search_handlers(
    #     AcousticHouseBotService,
    #     'form',
    #     limit: 10,
    #     handler_type: 'state'
    #   )
    #   # => [
    #   #   {
    #   #     method_name: 'handle_form_response',
    #   #     display_name: 'Form Response Handler',
    #   #     match_score: 0.95,
    #   #     ...
    #   #   }
    #   # ]
    #
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
    def search_handlers(service_class, query, options = {})
      validate_service_class!(service_class)

      handlers = service_class.handler_methods_metadata
      query_normalized = query.to_s.strip.downcase

      return [] if query_normalized.empty?

      # Apply filters
      handlers = apply_filters(handlers, options)

      # Score and filter results
      results = handlers.filter_map do |method_name, metadata|
        score = calculate_match_score(query_normalized, method_name, metadata)
        next if score < MIN_MATCH_SCORE

        {
          method_name: method_name,
          display_name: metadata[:display_name] || method_name.to_s.humanize,
          description: metadata[:description],
          match_score: score.round(3),
          match_reason: explain_match(query_normalized, method_name, metadata),
          category: metadata[:category],
          handler_type: metadata[:handler_type],
          status: metadata[:status] || 'stable'
        }
      end

      # Sort by score (descending) and limit
      results.sort_by! { |r| -r[:match_score] }
      limit = options[:limit] || DEFAULT_SEARCH_LIMIT
      results.take(limit)
    rescue StandardError => e
      Rails.logger.error("[HandlerMethodsRegistry] Search error: #{e.message}")
      []
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity

    private

    # Validate that service class includes BotServiceInterface
    #
    # @param service_class [Class] Service class to validate
    # @raise [ArgumentError] if service doesn't include interface
    #
    def validate_service_class!(service_class)
      raise ArgumentError, "Expected a Class, got #{service_class.class}" unless service_class.is_a?(Class)

      return if service_class.include?(AppleMessagesForBusiness::Concerns::BotServiceInterface)

      raise ArgumentError, "#{service_class.name} must include AppleMessagesForBusiness::Concerns::BotServiceInterface"
    end

    # Enrich metadata with runtime information
    #
    # @param service_class [Class] Bot service class
    # @param method_sym [Symbol] Method name as symbol
    # @param metadata [Hash] Base metadata
    # @return [Hash] Enriched metadata
    #
    def enrich_metadata(service_class, method_sym, metadata)
      enriched = metadata.dup

      # Add method signature
      begin
        signature = service_class.handler_method_signature(method_sym)
        enriched[:signature] = signature if signature
      rescue StandardError => e
        Rails.logger.warn("[HandlerMethodsRegistry] Failed to get signature for #{method_sym}: #{e.message}")
      end

      # Add service name
      enriched[:service_name] = service_class.name

      # Add computed fields
      enriched[:triggers_count] = count_triggers(metadata)
      enriched[:dependencies_count] = count_dependencies(metadata)

      enriched
    end

    # Count total number of triggers in metadata
    #
    # @param metadata [Hash] Handler metadata
    # @return [Integer] Total trigger count
    #
    # rubocop:disable Metrics/CyclomaticComplexity
    def count_triggers(metadata)
      triggers = metadata[:triggers] || {}
      (triggers[:state_ids]&.length || 0) +
        (triggers[:keywords]&.length || 0) +
        (triggers[:interactive_ids]&.length || 0)
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    # Count total number of dependencies in metadata
    #
    # @param metadata [Hash] Handler metadata
    # @return [Integer] Total dependency count
    #
    # rubocop:disable Metrics/CyclomaticComplexity
    def count_dependencies(metadata)
      deps = metadata[:dependencies] || {}
      (deps[:templates]&.length || 0) +
        (deps[:attributes]&.length || 0) +
        (deps[:services]&.length || 0)
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    # Validate metadata completeness and add warnings
    #
    # @param metadata [Hash] Handler metadata
    # @param warnings [Array] Array to append warnings to
    #
    def validate_metadata_completeness(metadata, warnings)
      required_fields = %i[method_name handler_type display_name description]
      missing_fields = required_fields.reject { |field| metadata[field].present? }

      if missing_fields.any?
        warnings << {
          type: 'incomplete_metadata',
          message: "Missing metadata fields: #{missing_fields.join(', ')}"
        }
      end

      # Check for empty description
      if metadata[:description].to_s.strip.empty?
        warnings << {
          type: 'missing_description',
          message: 'Handler method should have a meaningful description'
        }
      end

      # Check for tags (optional but recommended)
      return if metadata[:tags].present?

      warnings << {
        type: 'no_tags',
        message: 'Consider adding tags to improve searchability'
      }
    end

    # Find similar method names using Levenshtein distance
    #
    # @param service_class [Class] Bot service class
    # @param method_name [String, Symbol] Target method name
    # @return [String, nil] Suggestion string or nil
    #
    # rubocop:disable Metrics/CyclomaticComplexity
    def find_similar_method(service_class, method_name)
      target = method_name.to_s
      all_methods = service_class.instance_methods(false) + service_class.private_instance_methods(false)
      handler_methods = all_methods.select { |m| m.to_s.start_with?('handle_') }

      # Find methods with similar names
      candidates = handler_methods.map do |method|
        distance = levenshtein_distance(target, method.to_s)
        { method: method, distance: distance }
      end

      # Get best match within threshold
      best_match = candidates
                   .select { |c| c[:distance] <= MAX_SUGGESTION_DISTANCE }
                   .min_by { |c| c[:distance] }

      return "Did you mean '#{best_match[:method]}'?" if best_match

      # Fallback: suggest methods with similar prefix
      prefix_match = handler_methods.find { |m| m.to_s.start_with?(target[0..5]) }
      return "Did you mean '#{prefix_match}'?" if prefix_match

      nil
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    # Apply filters to handler collection
    #
    # @param handlers [Hash] Handler methods hash
    # @param options [Hash] Filter options
    # @return [Hash] Filtered handlers
    #
    # rubocop:disable Metrics/CyclomaticComplexity
    def apply_filters(handlers, options)
      filtered = handlers

      filtered = filtered.select { |_, meta| meta[:handler_type].to_s == options[:handler_type] } if options[:handler_type].present?

      filtered = filtered.select { |_, meta| meta[:category].to_s == options[:category] } if options[:category].present?

      filtered = filtered.select { |_, meta| (meta[:status] || 'stable').to_s == options[:status] } if options[:status].present?

      filtered
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    # Calculate match score for search query
    #
    # @param query [String] Normalized query string
    # @param method_name [Symbol] Method name
    # @param metadata [Hash] Handler metadata
    # @return [Float] Match score (0.0 to 1.0)
    #
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    def calculate_match_score(query, method_name, metadata)
      scores = []

      # Match against method name
      name_score = fuzzy_match(query, method_name.to_s.downcase)
      scores << (name_score * 1.0) # Weight: 1.0

      # Match against display name
      if metadata[:display_name].present?
        display_score = fuzzy_match(query, metadata[:display_name].to_s.downcase)
        scores << (display_score * 0.9) # Weight: 0.9
      end

      # Match against description
      if metadata[:description].present?
        desc_score = fuzzy_match(query, metadata[:description].to_s.downcase)
        scores << (desc_score * 0.7) # Weight: 0.7
      end

      # Match against tags
      if metadata[:tags].present?
        tag_matches = metadata[:tags].map { |tag| fuzzy_match(query, tag.to_s.downcase) }
        best_tag_score = tag_matches.max || 0
        scores << (best_tag_score * 0.8) # Weight: 0.8
      end

      # Match against category
      if metadata[:category].present?
        cat_score = fuzzy_match(query, metadata[:category].to_s.downcase)
        scores << (cat_score * 0.6) # Weight: 0.6
      end

      # Return best match score
      scores.max || 0.0
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

    # Explain why a handler matched the search query
    #
    # @param query [String] Normalized query string
    # @param method_name [Symbol] Method name
    # @param metadata [Hash] Handler metadata
    # @return [String] Human-readable explanation
    #
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def explain_match(query, method_name, metadata)
      reasons = []

      # Check method name
      reasons << 'method name' if method_name.to_s.downcase.include?(query)

      # Check display name
      reasons << 'display name' if metadata[:display_name].to_s.downcase.include?(query)

      # Check description
      reasons << 'description' if metadata[:description].to_s.downcase.include?(query)

      # Check tags
      reasons << 'tags' if metadata[:tags]&.any? { |tag| tag.to_s.downcase.include?(query) }

      # Check category
      reasons << 'category' if metadata[:category].to_s.downcase.include?(query)

      if reasons.any?
        "Matches query in #{reasons.join(', ')}"
      else
        'Fuzzy match'
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # Fuzzy string matching with scoring
    #
    # @param query [String] Search query
    # @param text [String] Text to match against
    # @return [Float] Match score (0.0 to 1.0)
    #
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def fuzzy_match(query, text)
      return 1.0 if text == query
      return 0.9 if text.include?(query)

      # Exact word match
      query_words = query.split(/\W+/).reject(&:empty?)
      text_words = text.split(/\W+/).reject(&:empty?)

      return 0.0 if query_words.empty?

      # Count matching words
      exact_matches = query_words.count { |qw| text_words.any?(qw) }
      return 0.8 * (exact_matches.to_f / query_words.length) if exact_matches.positive?

      # Partial word match
      partial_matches = query_words.count { |qw| text_words.any? { |tw| tw.include?(qw) || qw.include?(tw) } }
      return 0.5 * (partial_matches.to_f / query_words.length) if partial_matches.positive?

      # Levenshtein distance for very short queries (typo correction)
      if query.length <= 5
        distance = levenshtein_distance(query, text[0...query.length + 2])
        max_distance = query.length
        similarity = 1.0 - (distance.to_f / max_distance)
        return [similarity * 0.4, 0.0].max
      end

      0.0
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # Calculate Levenshtein distance between two strings
    #
    # @param str1 [String] First string
    # @param str2 [String] Second string
    # @return [Integer] Edit distance
    #
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    def levenshtein_distance(str1, str2)
      s = str1.to_s
      t = str2.to_s
      m = s.length
      n = t.length

      return n if m.zero?
      return m if n.zero?

      # Create distance matrix
      d = Array.new(m + 1) { Array.new(n + 1) }

      # Initialize first column and row
      (0..m).each { |i| d[i][0] = i }
      (0..n).each { |j| d[0][j] = j }

      # Calculate distances
      (1..m).each do |i|
        (1..n).each do |j|
          cost = s[i - 1] == t[j - 1] ? 0 : 1
          d[i][j] = [
            d[i - 1][j] + 1,      # deletion
            d[i][j - 1] + 1,      # insertion
            d[i - 1][j - 1] + cost # substitution
          ].min
        end
      end

      d[m][n]
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
  end
end
# rubocop:enable Metrics/ClassLength
