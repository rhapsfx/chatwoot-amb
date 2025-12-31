# Handler Methods API Documentation

## Overview

The Handler Methods API provides endpoints for discovering, browsing, searching, and validating handler methods available in bot services. This API enables the Bot Studio UI to dynamically discover available handlers and provide autocomplete, validation, and documentation features.

## Base URL

```
/api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods
```

## Authentication

All endpoints require authentication. Users must be either:
- **Administrator**: Full access to all endpoints
- **Agent**: Read-only access (index, show, validate, search)

## Endpoints

### 1. List Handler Methods

**Endpoint**: `GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods`

**Description**: Lists all handler methods available in the bot service with optional filtering.

**Query Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `service_name` | string | No | Override bot's default service class |
| `handler_type` | string | No | Filter by type: `state`, `keyword`, `interactive`, `action` |
| `category` | string | No | Filter by category (e.g., `onboarding`, `forms`, `payments`) |
| `status` | string | No | Filter by status: `stable`, `deprecated`, `experimental` |
| `search` | string | No | Search in method names, descriptions, and tags |

**Response**: `200 OK`

```json
{
  "handler_methods": [
    {
      "method_name": "handle_welcome",
      "handler_type": "state",
      "display_name": "Welcome Handler",
      "description": "Sends initial welcome message and prompts for region selection",
      "category": "onboarding",
      "status": "stable",
      "service_name": "AppleMessagesForBusiness::AcousticHouseBotService",
      "triggers_count": 2,
      "dependencies_count": 1
    },
    {
      "method_name": "handle_region_selection",
      "handler_type": "interactive",
      "display_name": "Region Selection Handler",
      "description": "Processes region list picker response",
      "category": "onboarding",
      "status": "stable",
      "service_name": "AppleMessagesForBusiness::AcousticHouseBotService",
      "triggers_count": 1,
      "dependencies_count": 2
    }
  ],
  "meta": {
    "total": 45,
    "services": ["AppleMessagesForBusiness::AcousticHouseBotService"],
    "categories": ["onboarding", "forms", "payments", "ar"],
    "handler_types": ["state", "keyword", "interactive", "action"],
    "statuses": ["stable", "experimental"]
  }
}
```

**Examples**:

```bash
# Get all handlers
GET /api/v1/accounts/1/agent_bots/1/handler_methods

# Get only state handlers
GET /api/v1/accounts/1/agent_bots/1/handler_methods?handler_type=state

# Get onboarding handlers
GET /api/v1/accounts/1/agent_bots/1/handler_methods?category=onboarding

# Get stable handlers only
GET /api/v1/accounts/1/agent_bots/1/handler_methods?status=stable

# Search for form-related handlers
GET /api/v1/accounts/1/agent_bots/1/handler_methods?search=form

# Combine filters
GET /api/v1/accounts/1/agent_bots/1/handler_methods?handler_type=state&category=onboarding&status=stable
```

---

### 2. Get Handler Method Details

**Endpoint**: `GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods/:id`

**Description**: Gets detailed metadata for a specific handler method, including method signature, source location, triggers, and dependencies.

**Path Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Handler method name (e.g., `handle_welcome`) |

**Query Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `service_name` | string | No | Override bot's default service class |

**Response**: `200 OK`

```json
{
  "handler_method": {
    "method_name": "handle_welcome",
    "handler_type": "state",
    "display_name": "Welcome Handler",
    "description": "Sends initial welcome message and prompts for region selection. Entry point for new conversations and restarts.",
    "category": "onboarding",
    "status": "stable",
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
      "attributes": ["customer_name"],
      "services": []
    },
    "examples": [
      {
        "scenario": "First time user",
        "input": "User starts conversation",
        "output": "Welcome message with region prompt"
      }
    ],
    "tags": ["welcome", "onboarding", "region"],
    "service_name": "AppleMessagesForBusiness::AcousticHouseBotService",
    "signature": {
      "arity": 0,
      "parameters": [],
      "source_location": [
        "/app/services/apple_messages_for_business/acoustic_house_bot_service.rb",
        145
      ]
    },
    "source_file": "/app/services/apple_messages_for_business/acoustic_house_bot_service.rb",
    "source_line": 145
  }
}
```

**Response**: `404 Not Found`

```json
{
  "error": "Handler method not found",
  "message": "Handler method 'non_existent_handler' does not exist in AppleMessagesForBusiness::AcousticHouseBotService"
}
```

**Examples**:

```bash
# Get details for handle_welcome
GET /api/v1/accounts/1/agent_bots/1/handler_methods/handle_welcome

# Get details with custom service
GET /api/v1/accounts/1/agent_bots/1/handler_methods/handle_welcome?service_name=CustomBotService
```

---

### 3. Validate Handler Method

**Endpoint**: `POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods/validate`

**Description**: Validates that a handler method exists, has proper documentation, and matches expected configuration.

**Request Body**:

```json
{
  "method_name": "handle_custom_state",
  "handler_type": "state",
  "state_id": "CUSTOM1"
}
```

**Request Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `method_name` | string | Yes | Handler method name to validate |
| `handler_type` | string | No | Expected handler type for validation |
| `state_id` | string | No | State ID to validate against triggers (for state handlers) |
| `service_name` | string | No | Override bot's default service class |

**Response**: `200 OK` (Valid)

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

**Response**: `200 OK` (Invalid)

```json
{
  "valid": false,
  "errors": [
    {
      "type": "method_not_found",
      "message": "Handler method 'handle_custom_state' does not exist in AppleMessagesForBusiness::AcousticHouseBotService",
      "suggestion": "Did you mean 'handle_custom_flow'?"
    }
  ],
  "warnings": []
}
```

**Response**: `200 OK` (Valid with warnings)

```json
{
  "valid": true,
  "errors": [],
  "warnings": [
    {
      "type": "type_mismatch",
      "message": "Handler type mismatch: expected keyword, got state"
    },
    {
      "type": "state_not_in_triggers",
      "message": "State 'CUSTOM1' is not listed in handler triggers",
      "recommendation": "Add 'CUSTOM1' to triggers.state_ids in metadata"
    },
    {
      "type": "no_documentation",
      "message": "Handler method 'handle_custom' lacks documentation metadata",
      "recommendation": "Add metadata to handler_methods_metadata in the service class"
    }
  ]
}
```

**Validation Types**:

**Errors** (method invalid):
- `missing_method_name`: No method name provided
- `method_not_found`: Method doesn't exist in service class

**Warnings** (method valid but has issues):
- `no_documentation`: Missing metadata
- `incomplete_metadata`: Missing required metadata fields
- `type_mismatch`: Handler type doesn't match expected type
- `state_not_in_triggers`: State ID not in handler's triggers
- `missing_triggers`: Handler should define triggers but doesn't

**Examples**:

```bash
# Basic validation
POST /api/v1/accounts/1/agent_bots/1/handler_methods/validate
Content-Type: application/json
{
  "method_name": "handle_welcome"
}

# Validate with type check
POST /api/v1/accounts/1/agent_bots/1/handler_methods/validate
Content-Type: application/json
{
  "method_name": "handle_welcome",
  "handler_type": "state"
}

# Validate state handler with state_id
POST /api/v1/accounts/1/agent_bots/1/handler_methods/validate
Content-Type: application/json
{
  "method_name": "handle_welcome",
  "handler_type": "state",
  "state_id": "AHA1"
}
```

---

### 4. Search Handler Methods

**Endpoint**: `GET /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/handler_methods/search`

**Description**: Searches handler methods with fuzzy matching and relevance scoring. Results are sorted by match score.

**Query Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `q` | string | Yes | Search query |
| `limit` | integer | No | Max results to return (default: 20) |
| `service_name` | string | No | Override bot's default service class |

**Response**: `200 OK`

```json
{
  "results": [
    {
      "method_name": "handle_form_response",
      "display_name": "Form Response Handler",
      "description": "Process form submission and validate data",
      "match_score": 2.5,
      "match_reason": "Matches in method name",
      "category": "forms",
      "handler_type": "state",
      "status": "stable"
    },
    {
      "method_name": "handle_large_form_demo",
      "display_name": "Large Form Demo",
      "description": "Demonstrates multi-section form",
      "match_score": 1.8,
      "match_reason": "Matches in description",
      "category": "forms",
      "handler_type": "keyword",
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

**Response**: `400 Bad Request`

```json
{
  "error": "Query parameter is required",
  "message": "Please provide a search query using the q parameter"
}
```

**Match Scoring**:

The search algorithm calculates match scores using weighted matching:
- **Method name match**: 1.0x weight
- **Display name match**: 0.9x weight
- **Description match**: 0.7x weight
- **Tag match**: 0.6x weight

**Score values**:
- `1.0`: Exact match in text
- `0.9`: Query is substring of text
- `0.0-0.8`: Word-by-word fuzzy match

Results with score < 0.3 are filtered out.

**Examples**:

```bash
# Search for "form"
GET /api/v1/accounts/1/agent_bots/1/handler_methods/search?q=form

# Search with limit
GET /api/v1/accounts/1/agent_bots/1/handler_methods/search?q=welcome&limit=5

# Multi-word search
GET /api/v1/accounts/1/agent_bots/1/handler_methods/search?q=apple+pay

# Fuzzy search
GET /api/v1/accounts/1/agent_bots/1/handler_methods/search?q=authen
```

---

## Error Responses

### 400 Bad Request

**Invalid Service Class**:
```json
{
  "error": "Invalid service class",
  "message": "Service class 'NonExistentService' not found"
}
```

**Service Missing Handler Metadata**:
```json
{
  "error": "Invalid service class",
  "message": "CustomBotService does not implement handler_methods_metadata"
}
```

**Missing Service Name**:
```json
{
  "error": "Service name not specified",
  "message": "Bot service class name is required"
}
```

**Missing Search Query**:
```json
{
  "error": "Query parameter is required",
  "message": "Please provide a search query using the q parameter"
}
```

### 401 Unauthorized

User is not authenticated.

### 403 Forbidden

User lacks permission to access handler methods.

### 404 Not Found

**Agent Bot Not Found**:
```json
{
  "error": "Agent bot not found"
}
```

**Handler Method Not Found**:
```json
{
  "error": "Handler method not found",
  "message": "Handler method 'non_existent_handler' does not exist in AppleMessagesForBusiness::AcousticHouseBotService"
}
```

### 500 Internal Server Error

Unexpected server error occurred.

---

## Usage Examples

### Frontend Integration - Handler Method Selector Component

```vue
<script setup>
import { ref, watch } from 'vue';
import { useHandlerMethods } from '@/composables/useHandlerMethods';

const props = defineProps({
  botId: Number,
  handlerType: String,
  modelValue: String
});

const emit = defineEmits(['update:modelValue']);

const { searchHandlers, validateHandler } = useHandlerMethods(props.botId);

const searchQuery = ref('');
const searchResults = ref([]);
const isValid = ref(true);
const validationErrors = ref([]);

// Search as user types
watch(searchQuery, async (query) => {
  if (query.length > 2) {
    const response = await searchHandlers(query, props.handlerType);
    searchResults.value = response.results;
  }
});

// Validate on selection
watch(() => props.modelValue, async (methodName) => {
  if (methodName) {
    const result = await validateHandler(methodName, props.handlerType);
    isValid.value = result.valid;
    validationErrors.value = result.errors;
  }
});
</script>
```

### Frontend Integration - Handler Method Browser

```vue
<script setup>
import { ref, onMounted } from 'vue';
import axios from 'axios';

const props = defineProps({
  botId: Number,
  accountId: Number
});

const handlers = ref([]);
const filters = ref({
  handlerType: null,
  category: null,
  status: 'stable'
});

const loadHandlers = async () => {
  const response = await axios.get(
    `/api/v1/accounts/${props.accountId}/agent_bots/${props.botId}/handler_methods`,
    { params: filters.value }
  );

  handlers.value = response.data.handler_methods;
};

onMounted(() => {
  loadHandlers();
});
</script>

<template>
  <div class="handler-browser">
    <div class="filters">
      <select v-model="filters.handlerType" @change="loadHandlers">
        <option :value="null">All Types</option>
        <option value="state">State</option>
        <option value="keyword">Keyword</option>
        <option value="interactive">Interactive</option>
        <option value="action">Action</option>
      </select>

      <select v-model="filters.status" @change="loadHandlers">
        <option value="stable">Stable</option>
        <option value="experimental">Experimental</option>
      </select>
    </div>

    <div class="handlers-list">
      <div
        v-for="handler in handlers"
        :key="handler.method_name"
        class="handler-card"
      >
        <h3>{{ handler.display_name }}</h3>
        <p>{{ handler.description }}</p>
        <div class="handler-meta">
          <span class="type">{{ handler.handler_type }}</span>
          <span class="category">{{ handler.category }}</span>
          <span class="status">{{ handler.status }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
```

---

## Development Notes

### Adding Handler Methods to Bot Service

To make a handler method discoverable via this API:

1. **Implement the handler method** in your bot service class
2. **Add metadata** to the `handler_methods_metadata` class method

Example:

```ruby
class MyBotService
  def self.handler_methods_metadata
    {
      handle_welcome: {
        method_name: :handle_welcome,
        handler_type: :state,
        display_name: 'Welcome Handler',
        description: 'Sends welcome message',
        category: 'onboarding',
        status: :stable,
        triggers: {
          state_ids: ['START'],
          keywords: [],
          interactive_ids: []
        },
        dependencies: {
          templates: ['welcome_template'],
          attributes: [],
          services: []
        },
        examples: [
          {
            scenario: 'New user',
            input: 'Conversation start',
            output: 'Welcome message sent'
          }
        ],
        tags: ['welcome', 'start', 'greeting']
      }
    }
  end

  def handle_welcome
    # Implementation
  end
end
```

### Metadata Schema

Required fields:
- `method_name` (Symbol): Handler method name
- `handler_type` (Symbol): `:state`, `:keyword`, `:interactive`, or `:action`
- `display_name` (String): Human-readable name
- `description` (String): Detailed description
- `category` (String): Logical grouping
- `status` (Symbol): `:stable`, `:experimental`, or `:deprecated`

Optional fields:
- `parameters` (Hash): Required and optional parameters
- `returns` (Hash): Return value description
- `triggers` (Hash): What triggers this handler
- `dependencies` (Hash): Templates, attributes, services needed
- `examples` (Array): Usage examples
- `tags` (Array): Search tags

---

## Related Documentation

- [Handler Methods Architecture](../bot-studio/HANDLER_METHODS_ARCHITECTURE.md)
- [Handler Methods Reference](../bot-studio/HANDLER_METHODS_REFERENCE.md)
- [Bot Studio Integration](../bot-studio/BOT_STUDIO_ARCHITECTURE.md)
