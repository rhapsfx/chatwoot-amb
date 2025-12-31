# Handler Methods Integration Guide

## Overview

The Handler Methods Management System provides a generic, framework-agnostic interface for browsing, searching, validating, and selecting handler methods from bot service classes. This system is integrated into the Visual Bot Studio to enable intelligent handler method selection with autocomplete, validation, and metadata display.

**Status**: ✅ **Complete** (Deployed Dec 2025)

## Architecture

### Backend Components

**HandlerMethodsController** (`app/controllers/api/v1/accounts/agent_bots/handler_methods_controller.rb`)
- RESTful API for handler methods
- Endpoints: `index`, `show`, `validate`, `search`
- Authorization: Pundit policy-based (admin + agent access)
- Dynamic service class loading via `bot_type` or `service_name` param

**AgentBotPolicy** (`app/policies/agent_bot_policy.rb`)
- Authorization methods: `index?`, `show?`, `validate?`, `search?`
- Access level: Administrator OR Agent

**API Methods** (`app/javascript/dashboard/api/agentBots.js`)
```javascript
getHandlerMethods(botId, params)      // List all handlers
getHandlerMethod(botId, methodName)   // Get specific handler
searchHandlerMethods(botId, query, params)  // Search handlers
validateHandlerMethod(botId, methodName, params)  // Validate handler
```

### Frontend Components

**HandlerMethodSelector** (`app/javascript/dashboard/routes/dashboard/settings/agentBots/components/HandlerMethodSelector.vue`)
- Autocomplete dropdown for handler method selection
- Real-time search with debounce (300ms)
- Validation on blur and selection
- Type badges (state, keyword, interactive, action)
- Status indicators (stable, experimental, deprecated)
- Props:
  - `modelValue` - Selected handler method name
  - `botId` - Agent bot ID (required for API calls)
  - `serviceName` - Service class name (default: from bot)
  - `handlerType` - Filter by handler type
  - `required` - Validation requirement
  - `disabled` - Disable input

**useHandlerMethods Composable** (`app/javascript/dashboard/routes/dashboard/settings/agentBots/composables/useHandlerMethods.js`)
- API integration layer
- Reactive state management
- Error handling
- Search result caching

**StateNodeEditor** (`app/javascript/dashboard/routes/dashboard/settings/agentBots/components/editors/StateNodeEditor.vue`)
- Integrates HandlerMethodSelector
- Auto-fills description and label from handler metadata
- Passes `botId` prop from parent BotStudio component

### Data Flow

```
User types in Handler Method field
  ↓
HandlerMethodSelector (debounced search)
  ↓
useHandlerMethods composable
  ↓
API: GET /api/v1/accounts/:account_id/agent_bots/:bot_id/handler_methods/search?q=<query>
  ↓
HandlerMethodsController#search
  ↓
Queries handler_methods_metadata from service class
  ↓
Returns: { results: [{method_name, display_name, description, match_score, ...}] }
  ↓
Display autocomplete dropdown with results
  ↓
User selects handler
  ↓
Validate selection via POST /handler_methods/validate
  ↓
Update node data and auto-fill metadata
```

## API Endpoints

### Base URL
```
/api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods
```

### GET /handler_methods
List all handler methods with optional filtering.

**Query Parameters**:
- `handler_type` - Filter by type (state, keyword, interactive, action)
- `category` - Filter by category
- `status` - Filter by status (stable, experimental, deprecated)
- `search` - Search term

**Response**:
```json
{
  "handler_methods": [
    {
      "method_name": "handle_welcome",
      "handler_type": "state",
      "display_name": "Welcome Handler",
      "description": "Handles initial welcome state",
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
    "categories": ["onboarding", "navigation", "forms"],
    "handler_types": ["state", "keyword", "interactive"],
    "statuses": ["stable", "experimental"]
  }
}
```

### GET /handler_methods/:id
Get detailed information about a specific handler method.

**Response**:
```json
{
  "handler_method": {
    "method_name": "handle_welcome",
    "handler_type": "state",
    "display_name": "Welcome Handler",
    "description": "Handles initial welcome state",
    "category": "onboarding",
    "status": "stable",
    "service_name": "AcousticHouseBotService",
    "triggers": {
      "state_ids": ["AHA1", "WELCOME"]
    },
    "dependencies": {
      "templates": ["ah_welcome"],
      "attributes": ["user_name"]
    },
    "signature": {
      "arity": 0,
      "parameters": [],
      "source_location": ["/path/to/file.rb", 42]
    },
    "source_file": "/path/to/file.rb",
    "source_line": 42
  }
}
```

### GET /handler_methods/search?q=<query>
Search handler methods with fuzzy matching and relevance scoring.

**Query Parameters**:
- `q` - Search query (required, min 2 characters)
- `limit` - Max results (default: 20)
- `handler_type` - Filter by type
- `service_name` - Override bot's service class

**Response**:
```json
{
  "results": [
    {
      "method_name": "handle_welcome",
      "display_name": "Welcome Handler",
      "description": "Handles initial welcome state",
      "match_score": 0.95,
      "match_reason": "Matches in method name",
      "category": "onboarding",
      "handler_type": "state",
      "status": "stable"
    }
  ],
  "meta": {
    "query": "welcome",
    "total_results": 3,
    "available_results": 8
  }
}
```

**Matching Algorithm**:
- Exact match: score 1.0
- Contains query: score 0.9
- Word-by-word matching: score 0.0-1.0
- Weighted by field: method_name (1.0) > display_name (0.9) > description (0.7) > tags (0.6)
- Minimum score threshold: 0.3

### POST /handler_methods/validate
Validate a handler method exists and get warnings/errors.

**Request Body**:
```json
{
  "method_name": "handle_welcome",
  "handler_type": "state",  // Optional: verify type matches
  "state_id": "AHA1"        // Optional: verify state is in triggers
}
```

**Response (Valid)**:
```json
{
  "valid": true,
  "errors": [],
  "warnings": []
}
```

**Response (Invalid)**:
```json
{
  "valid": false,
  "errors": [
    {
      "type": "method_not_found",
      "message": "Handler method 'handle_welcom' does not exist in AcousticHouseBotService",
      "suggestion": "Did you mean 'handle_welcome'?"
    }
  ],
  "warnings": []
}
```

**Response (Valid but Warnings)**:
```json
{
  "valid": true,
  "errors": [],
  "warnings": [
    {
      "type": "no_documentation",
      "message": "Handler method 'handle_custom' lacks documentation metadata",
      "recommendation": "Add metadata to handler_methods_metadata in the service class"
    },
    {
      "type": "incomplete_metadata",
      "field": "description",
      "message": "Handler 'handle_custom' is missing required metadata field: description"
    }
  ]
}
```

## Integration into Bot Studio

### Component Hierarchy

```
BotStudio.vue
  ├── Props: botId (from route params)
  ├── NodeConfigPanel.vue
  │     └── Dynamic component based on node type
  │           └── StateNodeEditor.vue
  │                 ├── Props: node, botId
  │                 └── HandlerMethodSelector
  │                       ├── Props: modelValue, botId, serviceName, handlerType
  │                       └── Uses: useHandlerMethods composable
  │                             └── API: agentBots.searchHandlerMethods()
```

### StateNodeEditor Integration

**Template**:
```vue
<div>
  <label class="block text-sm font-medium text-n-slate-11 mb-1">
    {{ t('AGENT_BOTS.HANDLER_METHODS.SELECT_HANDLER') }}
  </label>
  <HandlerMethodSelector
    v-model="editedData.handler"
    :bot-id="botId"
    service-name="AcousticHouseBotService"
    handler-type="state"
    :required="false"
    @handler-selected="handleHandlerSelected"
  />
  <p class="text-xs text-n-slate-10 mt-1">
    {{ t('AGENT_BOTS.HANDLER_METHODS.HELP_TEXT') }}
  </p>
</div>
```

**Auto-fill Logic**:
```javascript
const handleHandlerSelected = handler => {
  // Auto-fill description from handler metadata if empty
  if (!editedData.value.description && handler.description) {
    editedData.value.description = handler.description;
  }

  // Auto-fill label from display_name if empty
  if (!editedData.value.label && handler.display_name) {
    editedData.value.label = handler.display_name;
  }
};
```

## I18n Translations

All user-facing text is in `app/javascript/dashboard/i18n/locale/en/agentBots.json`:

```json
{
  "AGENT_BOTS": {
    "HANDLER_METHODS": {
      "TITLE": "Handler Methods",
      "BROWSE_HANDLERS": "Browse Handler Methods",
      "SELECT_HANDLER": "Select Handler Method",
      "HELP_TEXT": "The method name in AcousticHouseBotService that will handle this state (e.g., handle_welcome, handle_menu)",
      "SEARCH_PLACEHOLDER": "Search handler methods...",
      "NO_RESULTS": "No handler methods found",
      "NO_RESULTS_MESSAGE": "Try adjusting your search or filters",
      "METHODS_FOUND": "{count} handler methods found",
      "LOADING": "Loading handler methods...",
      "ERROR_LOADING": "Failed to load handler methods",
      "VALIDATION": {
        "REQUIRED": "Handler method is required",
        "NOT_FOUND": "Handler method not found",
        "INVALID": "Invalid handler method",
        "INVALID_FORMAT": "Handler method name must be a valid Ruby method name"
      }
    }
  }
}
```

## Authorization

**Policy**: `AgentBotPolicy`

**Required Methods**:
```ruby
def index?
  @account_user.administrator? || @account_user.agent?
end

def show?
  @account_user.administrator? || @account_user.agent?
end

def validate?
  @account_user.administrator? || @account_user.agent?
end

def search?
  @account_user.administrator? || @account_user.agent?
end
```

**Controller Authorization**:
```ruby
class Api::V1::Accounts::AgentBots::HandlerMethodsController < Api::V1::Accounts::BaseController
  before_action :set_agent_bot
  before_action :set_service_class
  before_action -> { authorize @agent_bot }

  # ... controller actions
end
```

## Testing

### Backend Testing

**RSpec Tests**: `spec/controllers/api/v1/accounts/agent_bots/handler_methods_controller_spec.rb`

```bash
# Run all handler methods tests
bundle exec rspec spec/controllers/api/v1/accounts/agent_bots/handler_methods_controller_spec.rb

# Run specific test
bundle exec rspec spec/controllers/api/v1/accounts/agent_bots/handler_methods_controller_spec.rb:42
```

**Policy Tests**: `spec/policies/agent_bot_policy_spec.rb`

```bash
bundle exec rspec spec/policies/agent_bot_policy_spec.rb
```

### Frontend Testing

**Component Tests**: `spec/javascript/dashboard/routes/dashboard/settings/agentBots/components/HandlerMethodSelector.spec.js`

```bash
# Run all frontend tests
pnpm test

# Run specific test file
pnpm test HandlerMethodSelector.spec.js

# Watch mode for development
pnpm test:watch
```

### Manual Testing

1. **Start development server**:
   ```bash
   ./script/dev-server.sh restart
   ```

2. **Navigate to Bot Studio**:
   - Go to Settings → Agent Bots
   - Click "Open Visual Studio" on an Apple Messages bot
   - Add a State node to canvas
   - Click on the State node

3. **Test Handler Method Selection**:
   - Type in the Handler Method field
   - Verify autocomplete dropdown appears
   - Verify search results show:
     - Method name
     - Display name
     - Description
     - Type badge (state/keyword/interactive/action)
     - Status indicator (stable/experimental/deprecated)
   - Select a handler from dropdown
   - Verify description and label auto-fill

4. **Test Validation**:
   - Type invalid handler name (e.g., "invalid_handler")
   - Tab out of field
   - Verify error message appears: "Handler method not found"
   - Verify suggestion if similar method exists

5. **Test Search**:
   - Type partial name (e.g., "welcome")
   - Verify matching handlers appear
   - Verify match score ordering (most relevant first)

6. **Verify Browser Console**:
   - Should see no 401 errors
   - Should see no 500 errors
   - API calls should complete successfully

## Troubleshooting

### 401 Unauthorized Errors

**Symptoms**:
- Browser console shows: "Failed to load resource: the server responded with a status of 401 () (validate, line 0)"
- Handler method field shows plain text input instead of autocomplete

**Causes**:
1. AgentBotPolicy missing required method (`search?`, `validate?`)
2. Controller not using proper authorization pattern
3. Server not restarted after policy/controller changes

**Solutions**:
1. Verify policy methods exist:
   ```bash
   grep -n "def search?" app/policies/agent_bot_policy.rb
   grep -n "def validate?" app/policies/agent_bot_policy.rb
   ```

2. Verify controller authorization:
   ```bash
   grep -n "authorize @agent_bot" app/controllers/api/v1/accounts/agent_bots/handler_methods_controller.rb
   ```

3. Restart Rails server:
   ```bash
   ./script/dev-server.sh restart
   ```

4. Hard refresh browser:
   - macOS: Cmd+Shift+R
   - Windows: Ctrl+Shift+R

### Component Not Appearing

**Symptoms**:
- Plain text input shows instead of HandlerMethodSelector autocomplete dropdown

**Causes**:
1. Vite dev server hasn't detected new component
2. Component import path incorrect
3. Component not registered in parent

**Solutions**:
1. Verify component exists:
   ```bash
   ls -lh app/javascript/dashboard/routes/dashboard/settings/agentBots/components/HandlerMethodSelector.vue
   ```

2. Check import in StateNodeEditor:
   ```bash
   grep -n "HandlerMethodSelector" app/javascript/dashboard/routes/dashboard/settings/agentBots/components/editors/StateNodeEditor.vue
   ```

3. Restart dev server:
   ```bash
   ./script/dev-server.sh restart
   ```

4. Clear browser cache and hard refresh

### Search Returns No Results

**Symptoms**:
- Typing in handler method field shows "No handler methods found"
- Bot service has methods but they don't appear

**Causes**:
1. Service class doesn't implement `handler_methods_metadata`
2. Handler metadata is empty
3. Search query too short (< 2 characters)

**Solutions**:
1. Verify service class has metadata:
   ```bash
   rails runner "puts AcousticHouseBotService.handler_methods_metadata.keys"
   ```

2. Check if methods are documented:
   ```ruby
   # In service class
   def self.handler_methods_metadata
     {
       handle_welcome: {
         handler_type: :state,
         display_name: 'Welcome Handler',
         description: 'Handles initial welcome state',
         category: 'onboarding',
         status: :stable
       }
       # ... more methods
     }
   end
   ```

3. Verify minimum search length (2 characters)

### Validation Always Fails

**Symptoms**:
- All handler methods show "Handler method not found" error
- API returns 404 or validation failures

**Causes**:
1. Method name case mismatch (camelCase vs snake_case)
2. Service class not found
3. Method not defined in service class

**Solutions**:
1. Verify method exists:
   ```bash
   rails runner "puts AcousticHouseBotService.instance_methods(false).grep(/handle_/)"
   ```

2. Check service name param:
   ```javascript
   // In HandlerMethodSelector
   service-name="AcousticHouseBotService"  // Must match service class name
   ```

3. Verify method is public (not private):
   ```ruby
   # In service class - methods should be public
   def handle_welcome
     # ... implementation
   end
   ```

## Best Practices

### Service Class Implementation

**Always document handler methods**:
```ruby
class MyBotService
  def self.handler_methods_metadata
    {
      handle_custom_state: {
        handler_type: :state,
        display_name: 'Custom State Handler',
        description: 'Handles custom business logic',
        category: 'custom',
        status: :stable,
        triggers: {
          state_ids: ['CUSTOM_STATE_1']
        },
        dependencies: {
          templates: ['custom_template'],
          attributes: ['custom_field']
        },
        tags: [:custom, :business_logic]
      }
    }
  end

  def handle_custom_state
    # Implementation
  end
end
```

### Frontend Integration

**Always pass botId prop**:
```vue
<!-- Parent component -->
<StateNodeEditor
  :node="selectedNode"
  :bot-id="botId"  <!-- Required for API calls -->
  @save="handleSave"
/>

<!-- Child component -->
<HandlerMethodSelector
  v-model="handler"
  :bot-id="botId"  <!-- Pass through to selector -->
/>
```

**Use handler-selected event for auto-fill**:
```vue
<HandlerMethodSelector
  v-model="editedData.handler"
  :bot-id="botId"
  @handler-selected="handleHandlerSelected"
/>

<script setup>
const handleHandlerSelected = handler => {
  // Auto-fill from metadata
  if (!editedData.value.description) {
    editedData.value.description = handler.description;
  }
};
</script>
```

### Search Query Optimization

**Debounce user input** (already implemented in component):
```javascript
const debouncedSearch = computed(() => {
  return debounce(searchHandlers, 300);  // 300ms delay
});
```

**Set appropriate result limits**:
```javascript
// Component default: 20 results
// For extensive metadata: 10 results
// For simple lists: 50 results
searchHandlerMethods(botId, query, { limit: 20 })
```

## Related Documentation

- **Backend Controller**: `app/controllers/api/v1/accounts/agent_bots/handler_methods_controller.rb` (420 lines)
- **Frontend Component**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/HandlerMethodSelector.vue` (316 lines)
- **Composable**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/composables/useHandlerMethods.js` (283 lines)
- **Policy**: `app/policies/agent_bot_policy.rb` (lines 76-90)
- **API Client**: `app/javascript/dashboard/api/agentBots.js` (lines 149-169)
- **Routes**: `config/routes.rb` (lines 143-148)
- **I18n**: `app/javascript/dashboard/i18n/locale/en/agentBots.json` (lines 475-623)

## Summary

The Handler Methods Management System provides a complete, production-ready solution for managing handler method selection in the Visual Bot Studio. Key features:

✅ **RESTful API** with list, show, search, and validate endpoints
✅ **Intelligent search** with fuzzy matching and relevance scoring
✅ **Autocomplete component** with real-time validation
✅ **Type-safe integration** with proper authorization and error handling
✅ **Comprehensive documentation** with troubleshooting guides
✅ **I18n support** for all user-facing text
✅ **Metadata-driven** for easy extension to new bot services

The system is framework-agnostic and can be extended to support any bot service class that implements the `handler_methods_metadata` interface.
