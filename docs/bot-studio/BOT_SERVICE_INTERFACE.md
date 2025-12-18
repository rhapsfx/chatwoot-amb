# BotServiceInterface - Implementation Guide

## Overview

The `BotServiceInterface` module provides a standardized contract for bot services to expose handler methods metadata. It enables dynamic discovery, validation, and documentation of handler methods across different bot service implementations.

## Location

- **Module**: `app/services/apple_messages_for_business/concerns/bot_service_interface.rb`
- **Specs**: `spec/services/apple_messages_for_business/concerns/bot_service_interface_spec.rb`

## Purpose

The interface enables:
- Runtime discovery of available handler methods
- Type-safe handler method validation
- Rich metadata for UI components (Bot Studio)
- Service-agnostic handler method management

## Including the Interface

To implement the interface in a bot service:

```ruby
class AppleMessagesForBusiness::CustomBotService
  include AppleMessagesForBusiness::BotServiceInterface

  # REQUIRED: Implement handler_methods_metadata class method
  def self.handler_methods_metadata
    {
      handle_welcome: {
        handler_type: :state,
        display_name: 'Welcome Handler',
        description: 'Sends initial welcome message and prompts for region',
        category: 'onboarding',
        status: :stable,
        parameters: {
          required: [],
          optional: ['custom_greeting']
        },
        returns: {
          type: 'state_transition',
          next_state: 'STATE2'
        },
        triggers: {
          state_ids: ['STATE1', 'RESTART'],
          keywords: [],
          interactive_ids: []
        },
        dependencies: {
          templates: ['welcome_message'],
          attributes: ['customer_name']
        },
        examples: [
          {
            scenario: 'First time user',
            input: 'User starts conversation',
            output: 'Welcome message with region prompt'
          }
        ],
        tags: ['welcome', 'onboarding']
      },
      handle_menu: {
        handler_type: :keyword,
        display_name: 'Main Menu',
        description: 'Displays the main menu options',
        category: 'navigation',
        status: :stable,
        triggers: {
          keywords: ['menu', 'start']
        }
      }
    }
  end

  # Implement your actual handler methods
  def handle_welcome
    # Implementation
  end

  def handle_menu
    # Implementation
  end
end
```

## Metadata Schema

### Required Fields

- `handler_type`: Symbol - `:state`, `:keyword`, `:interactive`, or `:action`
- `display_name`: String - Human-readable name for UI
- `description`: String - Detailed description (min 10 characters recommended)
- `category`: String - Category for grouping (e.g., 'onboarding', 'navigation', 'forms')
- `status`: Symbol - `:stable`, `:deprecated`, or `:experimental`

### Optional Fields

- `parameters`: Hash with `:required` and `:optional` arrays
- `returns`: Hash describing return value (`:type`, `:next_state`, etc.)
- `triggers`: Hash with `:state_ids`, `:keywords`, `:interactive_ids` arrays
- `dependencies`: Hash with `:templates` and `:attributes` arrays
- `examples`: Array of example hashes (`:scenario`, `:input`, `:output`)
- `tags`: Array of searchable tags

## Available Class Methods

### `.handler_methods_metadata`

Returns metadata for all handler methods. **Must be implemented** by service.

```ruby
metadata = CustomBotService.handler_methods_metadata
# => { handle_welcome: { ... }, handle_menu: { ... } }
```

### `.handler_method_exists?(method_name)`

Check if handler method exists (public or private).

```ruby
CustomBotService.handler_method_exists?(:handle_welcome)
# => true

CustomBotService.handler_method_exists?(:nonexistent)
# => false
```

### `.handler_method_signature(method_name)`

Get detailed signature information.

```ruby
CustomBotService.handler_method_signature(:handle_welcome)
# => {
#   arity: 0,
#   parameters: [],
#   source_location: ["/path/to/service.rb", 145]
# }
```

### `.handler_methods_by_type(handler_type)`

Filter methods by type.

```ruby
CustomBotService.handler_methods_by_type(:state)
# => [:handle_welcome, :handle_form_response]

CustomBotService.handler_methods_by_type(:keyword)
# => [:handle_menu, :handle_start_over]
```

### `.validate_handler_method(method_name)`

Validate method exists and is properly configured.

```ruby
# Valid handler
CustomBotService.validate_handler_method(:handle_welcome)
# => { valid: true, errors: [], warnings: [] }

# Non-existent handler
CustomBotService.validate_handler_method(:nonexistent)
# => {
#   valid: false,
#   errors: [
#     {
#       type: 'method_not_found',
#       message: "Handler method 'nonexistent' does not exist in CustomBotService",
#       suggestion: "Did you mean 'handle_menu'?"
#     }
#   ],
#   warnings: []
# }

# Handler with incomplete metadata
CustomBotService.validate_handler_method(:handle_undocumented)
# => {
#   valid: true,
#   errors: [],
#   warnings: [
#     {
#       type: 'missing_required_field',
#       message: "Handler method 'handle_undocumented' metadata missing required field: description"
#     }
#   ]
# }
```

## Error Classes

The interface defines three custom error classes:

- `HandlerMethodNotImplementedError` - Raised when `handler_methods_metadata` is not implemented
- `HandlerMethodNotFoundError` - For method not found errors
- `InvalidHandlerTypeError` - Raised for invalid handler types

## Handler Types

Valid handler types (defined in `HANDLER_TYPES` constant):

- `:state` - State-based handlers (triggered by state IDs)
- `:keyword` - Keyword-based handlers (triggered by text matching)
- `:interactive` - Interactive message handlers (triggered by user interactions)
- `:action` - Action handlers (triggered by events/actions)

## Validation Features

The interface provides comprehensive validation:

### Method Existence
- Checks both public and private methods
- Provides suggestions for similar methods if not found

### Metadata Completeness
- Validates all required fields are present
- Warns about missing optional but recommended fields

### Metadata Structure
- Validates `handler_type` is one of the allowed types
- Checks description length (warns if < 10 characters)
- Validates field types and structure

## Integration with Bot Studio

The BotServiceInterface is designed to work with:

1. **HandlerMethodsRegistry** - Service for discovering and managing handlers
2. **HandlerMethodsController** - API endpoints for handler operations
3. **Bot Studio UI Components** - Frontend components for browsing/selecting handlers

See [HANDLER_METHODS_ARCHITECTURE.md](./HANDLER_METHODS_ARCHITECTURE.md) for complete integration details.

## Testing

The interface includes comprehensive RSpec tests demonstrating all functionality. See `spec/services/apple_messages_for_business/concerns/bot_service_interface_spec.rb` for examples.

To run tests:

```bash
bundle exec rspec spec/services/apple_messages_for_business/concerns/bot_service_interface_spec.rb
```

## Best Practices

1. **Complete Metadata**: Provide all required fields and as many optional fields as possible
2. **Meaningful Descriptions**: Write clear, detailed descriptions (minimum 10 characters)
3. **Accurate Triggers**: Document all ways a handler can be triggered
4. **Example Usage**: Include examples showing typical usage scenarios
5. **Tags for Search**: Add relevant tags to improve discoverability
6. **Keep Updated**: Update metadata when handler logic changes

## Example: AcousticHouseBotService

The `AcousticHouseBotService` already includes this interface:

```ruby
class AppleMessagesForBusiness::AcousticHouseBotService
  include AppleMessagesForBusiness::BotServiceInterface

  # Implements handler_methods_metadata
  # See: app/services/apple_messages_for_business/acoustic_house_bot_service.rb
end
```

## Next Steps

After implementing BotServiceInterface:

1. Add metadata declarations for all handler methods
2. Integrate with HandlerMethodsRegistry (next phase)
3. Create API endpoints via HandlerMethodsController
4. Build UI components for Bot Studio

## Related Documentation

- [Handler Methods Architecture](./HANDLER_METHODS_ARCHITECTURE.md) - Complete system architecture
- [Handler Methods Reference](./HANDLER_METHODS_REFERENCE.md) - Handler method documentation
- [Bot Studio Architecture](../apple-messages/implementation/BOT_STUDIO_ARCHITECTURE.md) - Visual Bot Studio

## Support

For questions or issues with BotServiceInterface:
1. Review the RSpec tests for examples
2. Check the architecture documentation
3. Examine AcousticHouseBotService implementation
