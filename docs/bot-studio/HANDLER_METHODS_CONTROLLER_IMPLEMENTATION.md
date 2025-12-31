# Handler Methods Controller - Implementation Summary

## Files Created

### Controller
**Location**: `/app/controllers/api/v1/accounts/agent_bots/handler_methods_controller.rb`

**Actions**:
- `index` - List all handler methods with filtering
- `show` - Get detailed handler method metadata
- `validate` - Validate handler method exists and configuration
- `search` - Search handlers with fuzzy matching and scoring

### Specs
**Location**: `/spec/requests/api/v1/accounts/agent_bots/handler_methods_controller_spec.rb`

**Coverage**:
- All four controller actions
- Authentication (administrator and agent)
- Authorization checks
- Filtering (handler_type, category, status, search)
- Validation logic (errors and warnings)
- Search functionality with scoring
- Error handling (bad request, not found, unauthorized)

### Policy Updates
**Location**: `/app/policies/agent_bot_policy.rb`

**Permissions Added**:
- `handler_methods?` - List and show permissions
- `search_handler_methods?` - Search permission
- `validate_handler_method?` - Validate permission

All permissions allow both administrators and agents (read-only access for discovery).

### Documentation
**Location**: `/docs/api/handler_methods_api.md`

**Contents**:
- Complete API endpoint documentation
- Request/response examples
- Query parameters and filters
- Error responses
- Frontend integration examples
- Development guide for adding handlers

## API Endpoints

### Routes (Already Configured in `/config/routes.rb`)

```ruby
resources :handler_methods, controller: 'agent_bots/handler_methods', only: [:index, :show] do
  collection do
    post :validate
    get :search
  end
end
```

### Available Endpoints

1. **GET** `/api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods`
   - Lists all handlers with optional filtering
   - Filters: `handler_type`, `category`, `status`, `search`

2. **GET** `/api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods/:id`
   - Gets detailed metadata for specific handler
   - Includes method signature and source location

3. **POST** `/api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods/validate`
   - Validates handler exists and configuration
   - Returns errors and warnings

4. **GET** `/api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods/search`
   - Fuzzy search with relevance scoring
   - Required param: `q` (query)
   - Optional param: `limit` (default: 20)

## Key Features

### 1. Dynamic Discovery
- Reads handler metadata from `handler_methods_metadata` class method
- No hard-coded handler lists
- Service-agnostic (supports any bot service)

### 2. Rich Filtering
```ruby
# By handler type
GET /handler_methods?handler_type=state

# By category
GET /handler_methods?category=onboarding

# By status
GET /handler_methods?status=stable

# Combined filters
GET /handler_methods?handler_type=state&category=onboarding&status=stable

# Text search
GET /handler_methods?search=welcome
```

### 3. Intelligent Search
- Fuzzy matching across multiple fields
- Weighted scoring (method name > display name > description > tags)
- Results sorted by relevance
- Filters out low-score matches (< 0.3)

```ruby
# Match scoring algorithm
name_match * 1.0 + display_match * 0.9 + desc_match * 0.7 + tag_match * 0.6
```

### 4. Comprehensive Validation
- Checks if method exists in service class
- Validates metadata presence and completeness
- Type checking (expected vs actual handler type)
- State ID validation for state handlers
- Returns actionable errors and warnings

### 5. Metadata Enrichment
- Adds method signature (arity, parameters)
- Includes source location (file and line number)
- Counts triggers and dependencies
- Provides service information

## Response Formats

### List Response
```json
{
  "handler_methods": [
    {
      "method_name": "handle_welcome",
      "handler_type": "state",
      "display_name": "Welcome Handler",
      "description": "Sends initial welcome message",
      "category": "onboarding",
      "status": "stable",
      "service_name": "AppleMessagesForBusiness::AcousticHouseBotService",
      "triggers_count": 2,
      "dependencies_count": 1
    }
  ],
  "meta": {
    "total": 45,
    "services": ["AppleMessagesForBusiness::AcousticHouseBotService"],
    "categories": ["onboarding", "forms", "payments"],
    "handler_types": ["state", "keyword", "interactive", "action"],
    "statuses": ["stable", "experimental"]
  }
}
```

### Detail Response
```json
{
  "handler_method": {
    "method_name": "handle_welcome",
    "handler_type": "state",
    "display_name": "Welcome Handler",
    "description": "Sends initial welcome message",
    "category": "onboarding",
    "status": "stable",
    "triggers": {
      "state_ids": ["AHA1", "AH-restart"],
      "keywords": [],
      "interactive_ids": []
    },
    "dependencies": {
      "templates": ["ah_welcome_message"],
      "attributes": ["customer_name"],
      "services": []
    },
    "service_name": "AppleMessagesForBusiness::AcousticHouseBotService",
    "signature": {
      "arity": 0,
      "parameters": [],
      "source_location": ["/path/to/service.rb", 145]
    },
    "source_file": "/path/to/service.rb",
    "source_line": 145
  }
}
```

### Validation Response
```json
{
  "valid": true,
  "errors": [],
  "warnings": [
    {
      "type": "incomplete_metadata",
      "field": "examples",
      "message": "Handler 'handle_welcome' is missing required metadata field: examples"
    }
  ]
}
```

### Search Response
```json
{
  "results": [
    {
      "method_name": "handle_form_response",
      "display_name": "Form Response Handler",
      "description": "Process form submission",
      "match_score": 2.5,
      "match_reason": "Matches in method name",
      "category": "forms",
      "handler_type": "state",
      "status": "stable"
    }
  ],
  "meta": {
    "query": "form",
    "total_results": 2,
    "available_results": 5
  }
}
```

## Integration with Bot Studio

### Frontend Composable Example

```javascript
// composables/useHandlerMethods.js
export function useHandlerMethods(botId) {
  const accountId = useCurrentAccount().id;

  async function listHandlers(filters = {}) {
    const response = await axios.get(
      `/api/v1/accounts/${accountId}/agent_bots/${botId}/handler_methods`,
      { params: filters }
    );
    return response.data;
  }

  async function getHandler(methodName) {
    const response = await axios.get(
      `/api/v1/accounts/${accountId}/agent_bots/${botId}/handler_methods/${methodName}`
    );
    return response.data.handler_method;
  }

  async function validateHandler(methodName, handlerType = null, stateId = null) {
    const response = await axios.post(
      `/api/v1/accounts/${accountId}/agent_bots/${botId}/handler_methods/validate`,
      { method_name: methodName, handler_type: handlerType, state_id: stateId }
    );
    return response.data;
  }

  async function searchHandlers(query, limit = 20) {
    const response = await axios.get(
      `/api/v1/accounts/${accountId}/agent_bots/${botId}/handler_methods/search`,
      { params: { q: query, limit } }
    );
    return response.data;
  }

  return {
    listHandlers,
    getHandler,
    validateHandler,
    searchHandlers
  };
}
```

## Error Handling

### Controller Error Responses

**400 Bad Request**:
- Invalid service class
- Service doesn't implement handler_methods_metadata
- Missing required parameters

**401 Unauthorized**:
- User not authenticated

**403 Forbidden**:
- User lacks permission (handled by policy)

**404 Not Found**:
- Agent bot not found
- Handler method not found

**500 Internal Server Error**:
- Unexpected errors (logged and returned)

## Testing

### Running the Specs

```bash
# Run all handler methods controller specs
bundle exec rspec spec/requests/api/v1/accounts/agent_bots/handler_methods_controller_spec.rb

# Run specific test
bundle exec rspec spec/requests/api/v1/accounts/agent_bots/handler_methods_controller_spec.rb:10
```

### Test Coverage

- ✅ Index action with all filters
- ✅ Show action with enriched metadata
- ✅ Validate action with errors and warnings
- ✅ Search action with scoring
- ✅ Authentication checks (admin and agent)
- ✅ Authorization via policy
- ✅ Error handling (404, 400, 401)
- ✅ Service class validation

## Next Steps

### Phase 1: Backend Complete ✅
- [x] Controller implementation
- [x] Policy permissions
- [x] Specs
- [x] Documentation

### Phase 2: Frontend Components (Next)
- [ ] Create `HandlerMethodSelector.vue` component
- [ ] Create `HandlerMethodsBrowser.vue` component
- [ ] Create `useHandlerMethods` composable
- [ ] Integrate into Bot Studio node editors

### Phase 3: Enhanced Features (Future)
- [ ] Handler method usage analytics
- [ ] Visual handler code editor
- [ ] Handler testing interface
- [ ] Real-time validation in node editors

## Related Documentation

- **Architecture**: `/docs/bot-studio/HANDLER_METHODS_ARCHITECTURE.md`
- **API Reference**: `/docs/api/handler_methods_api.md`
- **Bot Studio**: `/docs/bot-studio/BOT_STUDIO_ARCHITECTURE.md`
- **Handler Reference**: `/docs/bot-studio/HANDLER_METHODS_REFERENCE.md`

## Summary

The HandlerMethodsController provides a complete REST API for discovering, browsing, searching, and validating bot handler methods. It follows Rails conventions, includes comprehensive error handling, and is fully tested. The API enables the Bot Studio frontend to provide intelligent autocomplete, validation, and documentation features for handler method configuration.

**Key Benefits**:
- ✅ Dynamic discovery (no hard-coded lists)
- ✅ Service-agnostic (supports any bot service)
- ✅ Rich filtering and search
- ✅ Comprehensive validation
- ✅ Detailed metadata and documentation
- ✅ RESTful design
- ✅ Fully tested
- ✅ Well documented
