# Generic Handler Methods Management System - Architecture

## Overview

This document describes the architecture for a centralized, service-agnostic handler methods management system that enables dynamic lookup, editing, and manipulation of handler methods across multiple bot services.

## Current State Analysis

### Problems with Current Implementation

1. **Hard-coded Service Reference**: Handler methods are statically referenced in `AcousticHouseBotService`
2. **No Discovery Mechanism**: No way to dynamically discover available handler methods
3. **Single Service Only**: System only supports one bot service class
4. **No Validation**: No validation that handler methods actually exist
5. **No Documentation**: Handler methods lack inline documentation
6. **No Editing Interface**: No UI to view/edit handler method mappings

### Current Architecture

```
Frontend (Bot Studio)
  ↓
  Manual entry of handler method names (string input)
  ↓
Backend (Bot Service)
  ↓
  Hard-coded constants:
  - KEYWORD_HANDLERS
  - INTERACTIVE_HANDLERS
  - process_state case statement
```

## Proposed Architecture

### Core Principles

1. **Service-Agnostic**: Support any bot service class that follows the interface
2. **Runtime Discovery**: Dynamically discover handler methods via reflection
3. **Type Safety**: Strongly typed handler method metadata
4. **Documentation**: Built-in documentation for each handler
5. **Validation**: Validate handler existence and signatures
6. **UI-Driven**: Rich UI for browsing, searching, and selecting handlers

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                     Frontend Layer                          │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ HandlerBrowser   │  │ HandlerEditor    │                │
│  │   Component      │  │   Component      │                │
│  └────────┬─────────┘  └────────┬─────────┘                │
│           │                     │                           │
│           └──────────┬──────────┘                           │
│                      │                                      │
└──────────────────────┼──────────────────────────────────────┘
                       │
                   API Layer
                       │
┌──────────────────────┼──────────────────────────────────────┐
│                      │                                      │
│  ┌───────────────────▼───────────────────┐                 │
│  │  HandlerMethodsController             │                 │
│  │  - list_methods                       │                 │
│  │  - get_method_details                 │                 │
│  │  - validate_method                    │                 │
│  │  - search_methods                     │                 │
│  └───────────────────┬───────────────────┘                 │
│                      │                                      │
└──────────────────────┼──────────────────────────────────────┘
                       │
                Service Layer
                       │
┌──────────────────────┼──────────────────────────────────────┐
│                      │                                      │
│  ┌───────────────────▼───────────────────┐                 │
│  │  HandlerMethodsRegistry               │                 │
│  │  - discover_all_handlers              │                 │
│  │  - get_handler_metadata               │                 │
│  │  - validate_handler_exists            │                 │
│  │  - extract_documentation              │                 │
│  └───────────────────┬───────────────────┘                 │
│                      │                                      │
│  ┌───────────────────▼───────────────────┐                 │
│  │  BotServiceInterface                  │                 │
│  │  - handler_methods_metadata           │                 │
│  │  - handler_method_exists?             │                 │
│  │  - handler_method_signature           │                 │
│  └───────────────────┬───────────────────┘                 │
│                      │                                      │
└──────────────────────┼──────────────────────────────────────┘
                       │
            Bot Service Implementation
                       │
┌──────────────────────┼──────────────────────────────────────┐
│  ┌───────────────────▼───────────────────┐                 │
│  │  AcousticHouseBotService              │                 │
│  │  │  Implements BotServiceInterface    │                 │
│  │  └─ handler_methods_metadata          │                 │
│  │     └─ Declares metadata inline       │                 │
│  └───────────────────────────────────────┘                 │
│                                                             │
│  ┌───────────────────────────────────────┐                 │
│  │  CustomBotService (Future)            │                 │
│  │  │  Implements BotServiceInterface    │                 │
│  │  └─ handler_methods_metadata          │                 │
│  └───────────────────────────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

## Handler Method Metadata Schema

Each handler method should declare rich metadata:

```ruby
{
  method_name: 'handle_welcome',
  handler_type: 'state',  # state, keyword, interactive, action
  display_name: 'Welcome Handler',
  description: 'Sends initial welcome message and prompts for region',
  parameters: {
    required: [],
    optional: ['custom_greeting']
  },
  returns: {
    type: 'state_transition',
    next_state: 'AHA2'
  },
  triggers: {
    state_ids: ['AHA1', 'AH-restart'],
    keywords: [],
    interactive_ids: []
  },
  dependencies: {
    templates: ['ah_welcome_message'],
    attributes: ['customer_name']
  },
  examples: [
    {
      scenario: 'First time user',
      input: 'User starts conversation',
      output: 'Welcome message with region prompt'
    }
  ],
  tags: ['welcome', 'onboarding', 'region'],
  category: 'onboarding',
  status: 'stable'  # stable, deprecated, experimental
}
```

## API Endpoints

### 1. List Handler Methods

**Endpoint**: `GET /api/v1/accounts/:account_id/agent_bots/:bot_id/handler_methods`

**Query Parameters**:
- `service_name` (optional): Filter by bot service class
- `handler_type` (optional): Filter by type (state, keyword, interactive, action)
- `category` (optional): Filter by category
- `search` (optional): Search by name/description/tags
- `status` (optional): Filter by status (stable, deprecated, experimental)

**Response**:
```json
{
  "handler_methods": [
    {
      "method_name": "handle_welcome",
      "handler_type": "state",
      "display_name": "Welcome Handler",
      "description": "Sends initial welcome message...",
      "category": "onboarding",
      "status": "stable",
      "service_name": "AcousticHouseBotService",
      "triggers_count": 2,
      "dependencies_count": 1
    }
  ],
  "meta": {
    "total": 45,
    "services": ["AcousticHouseBotService"],
    "categories": ["onboarding", "forms", "payments", "ar"],
    "handler_types": ["state", "keyword", "interactive", "action"]
  }
}
```

### 2. Get Handler Method Details

**Endpoint**: `GET /api/v1/accounts/:account_id/agent_bots/:bot_id/handler_methods/:method_name`

**Query Parameters**:
- `service_name` (required): Bot service class name

**Response**:
```json
{
  "handler_method": {
    "method_name": "handle_welcome",
    "handler_type": "state",
    "display_name": "Welcome Handler",
    "description": "Sends initial welcome message and prompts for region selection",
    "parameters": {
      "required": [],
      "optional": ["custom_greeting"]
    },
    "returns": {
      "type": "state_transition",
      "next_state": "AHA2"
    },
    "triggers": {
      "state_ids": ["AHA1", "AH-restart"],
      "keywords": [],
      "interactive_ids": []
    },
    "dependencies": {
      "templates": ["ah_welcome_message"],
      "attributes": ["customer_name"]
    },
    "examples": [
      {
        "scenario": "First time user",
        "input": "User starts conversation",
        "output": "Welcome message with region prompt"
      }
    ],
    "tags": ["welcome", "onboarding", "region"],
    "category": "onboarding",
    "status": "stable",
    "service_name": "AcousticHouseBotService",
    "source_file": "app/services/apple_messages_for_business/acoustic_house_bot_service.rb",
    "source_line": 145
  }
}
```

### 3. Validate Handler Method

**Endpoint**: `POST /api/v1/accounts/:account_id/agent_bots/:bot_id/handler_methods/validate`

**Request Body**:
```json
{
  "method_name": "handle_custom_state",
  "service_name": "AcousticHouseBotService",
  "handler_type": "state",
  "state_id": "CUSTOM1"
}
```

**Response**:
```json
{
  "valid": false,
  "errors": [
    {
      "type": "method_not_found",
      "message": "Handler method 'handle_custom_state' does not exist in AcousticHouseBotService",
      "suggestion": "Did you mean 'handle_custom_flow'?"
    }
  ],
  "warnings": [
    {
      "type": "no_documentation",
      "message": "Handler method lacks documentation metadata"
    }
  ]
}
```

### 4. Search Handler Methods

**Endpoint**: `GET /api/v1/accounts/:account_id/agent_bots/:bot_id/handler_methods/search`

**Query Parameters**:
- `q` (required): Search query
- `handler_type` (optional): Filter by type
- `limit` (optional): Max results (default: 20)

**Response**:
```json
{
  "results": [
    {
      "method_name": "handle_form_response",
      "display_name": "Form Response Handler",
      "description": "Process form submission...",
      "match_score": 0.95,
      "match_reason": "Matches query in method name and description",
      "category": "forms",
      "handler_type": "state"
    }
  ],
  "meta": {
    "query": "form",
    "total_results": 5,
    "search_time_ms": 12
  }
}
```

## Frontend Components

### 1. HandlerMethodsBrowser Component

**Purpose**: Browse and search available handler methods

**Features**:
- List view with filtering (type, category, status)
- Search with fuzzy matching
- Category grouping
- Quick preview on hover
- Click to insert into node editor

**Props**:
```typescript
interface HandlerMethodsBrowserProps {
  botId: number;
  serviceName?: string;  // defaults to bot's service
  handlerType?: 'state' | 'keyword' | 'interactive' | 'action';
  onSelect: (method: HandlerMethod) => void;
}
```

**Location**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/HandlerMethodsBrowser.vue`

### 2. HandlerMethodEditor Component

**Purpose**: View and edit handler method configuration

**Features**:
- View full metadata
- Edit trigger mappings
- View dependencies
- See usage examples
- Jump to source code (GitHub link)

**Props**:
```typescript
interface HandlerMethodEditorProps {
  methodName: string;
  serviceName: string;
  readonly?: boolean;
}
```

**Location**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/HandlerMethodEditor.vue`

### 3. HandlerMethodSelector Component

**Purpose**: Dropdown/autocomplete for selecting handler methods

**Features**:
- Autocomplete with fuzzy search
- Shows method signature on hover
- Validates method exists
- Groups by category

**Props**:
```typescript
interface HandlerMethodSelectorProps {
  modelValue: string;
  botId: number;
  serviceName?: string;
  handlerType?: string;
  required?: boolean;
}
```

**Location**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/HandlerMethodSelector.vue`

## Backend Implementation

### 1. BotServiceInterface Module

**Purpose**: Define the contract that all bot services must implement

**Location**: `app/services/apple_messages_for_business/concerns/bot_service_interface.rb`

```ruby
module AppleMessagesForBusiness
  module BotServiceInterface
    extend ActiveSupport::Concern

    class_methods do
      # Returns metadata for all handler methods
      # @return [Hash<Symbol, Hash>] method_name => metadata
      def handler_methods_metadata
        raise NotImplementedError, "#{name} must implement handler_methods_metadata"
      end

      # Check if handler method exists
      # @param method_name [String, Symbol] Handler method name
      # @return [Boolean]
      def handler_method_exists?(method_name)
        method_defined?(method_name) || private_method_defined?(method_name)
      end

      # Get handler method signature
      # @param method_name [String, Symbol] Handler method name
      # @return [Hash] method signature details
      def handler_method_signature(method_name)
        method = instance_method(method_name.to_sym)
        {
          arity: method.arity,
          parameters: method.parameters,
          source_location: method.source_location
        }
      rescue NameError
        nil
      end

      # Get all handler methods by type
      # @param handler_type [Symbol] :state, :keyword, :interactive, :action
      # @return [Array<Symbol>] method names
      def handler_methods_by_type(handler_type)
        handler_methods_metadata.select { |_, meta| meta[:handler_type] == handler_type }.keys
      end
    end
  end
end
```

### 2. HandlerMethodsRegistry Service

**Purpose**: Central registry for discovering and managing handler methods

**Location**: `app/services/apple_messages_for_business/handler_methods_registry.rb`

```ruby
module AppleMessagesForBusiness
  class HandlerMethodsRegistry
    # Discover all handler methods from a bot service
    # @param service_class [Class] Bot service class
    # @return [Hash] Discovered handlers with metadata
    def self.discover_handlers(service_class)
      unless service_class.include?(BotServiceInterface)
        raise ArgumentError, "#{service_class} must include BotServiceInterface"
      end

      service_class.handler_methods_metadata
    end

    # Get handler method details
    # @param service_class [Class] Bot service class
    # @param method_name [String, Symbol] Handler method name
    # @return [Hash, nil] Handler metadata or nil if not found
    def self.get_handler_metadata(service_class, method_name)
      metadata = service_class.handler_methods_metadata[method_name.to_sym]
      return nil unless metadata

      # Enrich with runtime data
      metadata.merge(
        signature: service_class.handler_method_signature(method_name),
        service_name: service_class.name
      )
    end

    # Validate handler method exists and is properly configured
    # @param service_class [Class] Bot service class
    # @param method_name [String, Symbol] Handler method name
    # @return [Hash] Validation result with errors/warnings
    def self.validate_handler(service_class, method_name)
      errors = []
      warnings = []

      # Check if method exists
      unless service_class.handler_method_exists?(method_name)
        errors << {
          type: 'method_not_found',
          message: "Handler method '#{method_name}' does not exist",
          suggestion: find_similar_method(service_class, method_name)
        }
        return { valid: false, errors: errors, warnings: warnings }
      end

      # Check if metadata exists
      metadata = service_class.handler_methods_metadata[method_name.to_sym]
      if metadata.nil?
        warnings << {
          type: 'no_documentation',
          message: "Handler method lacks documentation metadata"
        }
      end

      { valid: errors.empty?, errors: errors, warnings: warnings }
    end

    # Search handler methods
    # @param service_class [Class] Bot service class
    # @param query [String] Search query
    # @param options [Hash] Search options
    # @return [Array<Hash>] Search results with scores
    def self.search_handlers(service_class, query, options = {})
      handlers = service_class.handler_methods_metadata

      results = handlers.map do |method_name, metadata|
        score = calculate_match_score(query, method_name, metadata)
        next if score < 0.3

        {
          method_name: method_name,
          display_name: metadata[:display_name],
          description: metadata[:description],
          match_score: score,
          match_reason: explain_match(query, method_name, metadata),
          category: metadata[:category],
          handler_type: metadata[:handler_type]
        }
      end.compact.sort_by { |r| -r[:match_score] }

      limit = options[:limit] || 20
      results.take(limit)
    end

    private

    def self.calculate_match_score(query, method_name, metadata)
      query_lower = query.to_s.downcase
      name_match = fuzzy_match(query_lower, method_name.to_s.downcase)
      desc_match = fuzzy_match(query_lower, metadata[:description].to_s.downcase)
      tag_match = metadata[:tags]&.any? { |tag| fuzzy_match(query_lower, tag.downcase) } ? 0.8 : 0

      [name_match, desc_match, tag_match].max
    end

    def self.fuzzy_match(query, text)
      # Simple fuzzy matching (can be enhanced with Levenshtein distance)
      return 1.0 if text == query
      return 0.9 if text.include?(query)

      # Check word-by-word
      query_words = query.split(/\W+/)
      text_words = text.split(/\W+/)

      matches = query_words.count { |qw| text_words.any? { |tw| tw.include?(qw) } }
      matches.to_f / query_words.length
    end

    def self.find_similar_method(service_class, method_name)
      # Find similar method names using Levenshtein distance
      all_methods = service_class.instance_methods(false) + service_class.private_instance_methods(false)
      handler_methods = all_methods.select { |m| m.to_s.start_with?('handle_') }

      # Simple suggestion based on starts_with
      similar = handler_methods.find { |m| m.to_s.start_with?(method_name.to_s[0..5]) }
      similar ? "Did you mean '#{similar}'?" : nil
    end
  end
end
```

### 3. HandlerMethodsController

**Purpose**: API controller for handler methods operations

**Location**: `app/controllers/api/v1/accounts/agent_bots/handler_methods_controller.rb`

```ruby
class Api::V1::Accounts::AgentBots::HandlerMethodsController < Api::V1::Accounts::BaseController
  before_action :set_agent_bot
  before_action :set_service_class

  # GET /api/v1/accounts/:account_id/agent_bots/:bot_id/handler_methods
  def index
    handlers = AppleMessagesForBusiness::HandlerMethodsRegistry.discover_handlers(@service_class)

    # Apply filters
    handlers = filter_by_type(handlers) if params[:handler_type].present?
    handlers = filter_by_category(handlers) if params[:category].present?
    handlers = filter_by_status(handlers) if params[:status].present?
    handlers = search_handlers(handlers) if params[:search].present?

    # Build response
    render json: {
      handler_methods: format_handlers_list(handlers),
      meta: build_meta(handlers)
    }
  end

  # GET /api/v1/accounts/:account_id/agent_bots/:bot_id/handler_methods/:method_name
  def show
    method_name = params[:id]
    metadata = AppleMessagesForBusiness::HandlerMethodsRegistry.get_handler_metadata(
      @service_class,
      method_name
    )

    if metadata
      render json: { handler_method: metadata }
    else
      render json: { error: 'Handler method not found' }, status: :not_found
    end
  end

  # POST /api/v1/accounts/:account_id/agent_bots/:bot_id/handler_methods/validate
  def validate
    result = AppleMessagesForBusiness::HandlerMethodsRegistry.validate_handler(
      @service_class,
      params[:method_name]
    )

    render json: result
  end

  # GET /api/v1/accounts/:account_id/agent_bots/:bot_id/handler_methods/search
  def search
    results = AppleMessagesForBusiness::HandlerMethodsRegistry.search_handlers(
      @service_class,
      params[:q],
      limit: params[:limit]
    )

    render json: {
      results: results,
      meta: {
        query: params[:q],
        total_results: results.length,
        search_time_ms: 0
      }
    }
  end

  private

  def set_agent_bot
    @agent_bot = Current.account.agent_bots.find(params[:agent_bot_id])
  end

  def set_service_class
    service_name = params[:service_name] || @agent_bot.bot_type
    @service_class = service_name.constantize
  rescue NameError
    render json: { error: 'Invalid service class' }, status: :bad_request
  end

  def filter_by_type(handlers)
    handlers.select { |_, meta| meta[:handler_type].to_s == params[:handler_type] }
  end

  def filter_by_category(handlers)
    handlers.select { |_, meta| meta[:category].to_s == params[:category] }
  end

  def filter_by_status(handlers)
    handlers.select { |_, meta| meta[:status].to_s == params[:status] }
  end

  def search_handlers(handlers)
    query = params[:search].downcase
    handlers.select do |method_name, meta|
      method_name.to_s.downcase.include?(query) ||
        meta[:description].to_s.downcase.include?(query) ||
        meta[:tags]&.any? { |tag| tag.downcase.include?(query) }
    end
  end

  def format_handlers_list(handlers)
    handlers.map do |method_name, metadata|
      {
        method_name: method_name,
        handler_type: metadata[:handler_type],
        display_name: metadata[:display_name],
        description: metadata[:description],
        category: metadata[:category],
        status: metadata[:status],
        service_name: @service_class.name,
        triggers_count: count_triggers(metadata),
        dependencies_count: count_dependencies(metadata)
      }
    end
  end

  def count_triggers(metadata)
    triggers = metadata[:triggers] || {}
    (triggers[:state_ids]&.length || 0) +
      (triggers[:keywords]&.length || 0) +
      (triggers[:interactive_ids]&.length || 0)
  end

  def count_dependencies(metadata)
    deps = metadata[:dependencies] || {}
    (deps[:templates]&.length || 0) + (deps[:attributes]&.length || 0)
  end

  def build_meta(handlers)
    {
      total: handlers.length,
      services: [@service_class.name],
      categories: handlers.map { |_, m| m[:category] }.compact.uniq,
      handler_types: handlers.map { |_, m| m[:handler_type] }.compact.uniq
    }
  end
end
```

## Migration Strategy

### Phase 1: Add Interface Support (Week 1)

1. Create `BotServiceInterface` module
2. Create `HandlerMethodsRegistry` service
3. Update `AcousticHouseBotService` to implement interface
4. Add metadata declarations to existing handler methods

### Phase 2: API Layer (Week 2)

1. Create `HandlerMethodsController`
2. Add routes
3. Create API specs
4. Document API endpoints

### Phase 3: Frontend Components (Week 3-4)

1. Create `HandlerMethodSelector` component
2. Create `HandlerMethodsBrowser` component
3. Create `HandlerMethodEditor` component
4. Add to Bot Studio node editors

### Phase 4: Integration (Week 5)

1. Replace text inputs with `HandlerMethodSelector` in node editors
2. Add "Browse Handlers" button
3. Add validation integration
4. Update documentation

### Phase 5: Testing & Rollout (Week 6)

1. End-to-end testing
2. User acceptance testing
3. Documentation updates
4. Gradual rollout

## Benefits

1. **Discoverability**: Users can browse all available handlers
2. **Validation**: Immediate feedback if handler doesn't exist
3. **Documentation**: Inline docs for each handler
4. **Extensibility**: Easy to add new bot services
5. **Maintainability**: Centralized handler management
6. **Type Safety**: Strong typing prevents typos
7. **Better UX**: Rich UI instead of text input

## Future Enhancements

1. **Handler Code Editor**: Edit handler code directly in UI
2. **Visual Debugger**: Step through handler execution
3. **Handler Testing**: Test handlers with mock data
4. **Handler Analytics**: Track which handlers are most used
5. **Handler Templates**: Create handlers from templates
6. **Multi-Service Support**: Manage handlers across multiple bot services
7. **Version Control**: Track handler changes over time

## References

- [Bot Studio Architecture](./BOT_STUDIO_ARCHITECTURE.md)
- [Handler Methods Reference](./HANDLER_METHODS_REFERENCE.md)
- [Bot Service Interface](../../app/services/apple_messages_for_business/concerns/bot_service_interface.rb)
- [Handler Methods Registry](../../app/services/apple_messages_for_business/handler_methods_registry.rb)


Handler UI 

 1. "Handlers" Button in Toolbar ✨ NEW!

  - Located in the top toolbar next to "Templates"
  - Click to open the comprehensive Handler Methods Browser dialog
  - Features:
    - Search bar - Find handlers by name/description/tags
    - Filters - Type (state/keyword/interactive/action), Category, Status
    - Sort options - Alphabetical, by type, by status
    - Preview panel - Hover to see full metadata (triggers, dependencies, examples)
    - Grouped display - Handlers organized by category

  2. In Node Editors (Autocomplete)

  When you double-click a node to edit it:
  - State nodes - Handler selector with type filter state
  - Intent nodes - Handler selector with type filter keyword
  - Action nodes - Handler selector with type filter action

  The selector provides:
  - Type-ahead search with fuzzy matching
  - Handler type badges (color-coded)
  - Status badges (stable/experimental/deprecated)
  - Match reason display
  - Auto-validation with visual feedback (✓ green when valid)
  - Auto-fill label from handler metadata

  3. Visual Display on Canvas

  Handlers appear directly on nodes:
  - Gray badge with </> code icon
  - Monospace font for method name
  - Visible at a glance without editing

  How It Works

  The system is now fully independent from hard-coded references:
  - ✅ Dynamically discovers handlers from AcousticHouseBotService
  - ✅ No hard-coded KEYWORD_HANDLERS or INTERACTIVE_HANDLERS needed
  - ✅ Extensible - works with any service implementing BotServiceInterface
  - ✅ Rich metadata: description, triggers, dependencies, examples, tags
  - ✅ Real-time validation

