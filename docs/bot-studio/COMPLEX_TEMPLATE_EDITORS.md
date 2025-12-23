# Complex Template Editor Components - Documentation

## Overview

Four advanced template editor components for conditional branching, API calls, iMessage apps, and App Clips have been created for the Bot Studio. These components handle the most complex parameter structures and provide sophisticated UI patterns.

## Components Created

### 1. ConditionalBranchTemplate.vue

**Location**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/editors/templates/ConditionalBranchTemplate.vue`

**Purpose**: Create conditional logic branches that execute different actions based on conditions.

**Parameters**:
- `condition_type` (required) - Enum: attribute_equals, attribute_contains, message_contains, custom_expression
- `condition_value` (required) - Object/String (structure depends on condition_type)
- `true_action` (optional) - Integer (BotActionTemplate ID to execute if true)
- `false_action` (optional) - Integer (BotActionTemplate ID to execute if false)

**Key Features**:
- Dynamic UI that changes based on selected condition type
- Four condition types:
  - **attribute_equals**: Check if a conversation attribute equals a specific value
  - **attribute_contains**: Check if a conversation attribute contains a substring
  - **message_contains**: Check if the incoming message contains specific text (case-insensitive)
  - **custom_expression**: Advanced Ruby expression evaluation with @conversation and @message variables
- Live preview of the condition logic
- Warning box for custom expressions (advanced feature)
- Template ID inputs for branching logic

**Condition Value Structure**:
```javascript
// attribute_equals / attribute_contains
{
  attribute: "custom_attribute_key",
  value: "expected_value"
}

// message_contains
{
  text: "search text"
}

// custom_expression
{
  expression: "@conversation.custom_attributes['key'] == 'value'"
}
```

---

### 2. ApiCallTemplate.vue

**Location**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/editors/templates/ApiCallTemplate.vue`

**Purpose**: Make HTTP API calls during bot execution with full control over headers, body, and response storage.

**Parameters**:
- `url` (required) - String (API endpoint URL)
- `method` (required) - Enum: GET, POST, PUT, PATCH, DELETE
- `headers` (optional) - JSON object (HTTP headers)
- `body` (optional) - JSON object (request body, only for POST/PUT/PATCH)
- `store_response_in` (optional) - String (conversation attribute name to store response)

**Key Features**:
- URL input with validation
- HTTP method selector (GET, POST, PUT, PATCH, DELETE)
- JSON editor for headers with format button
- JSON editor for body (conditional - only shows for POST/PUT/PATCH)
- Separate error states for headers and body validation
- Store response in conversation attribute
- Example section showing proper JSON format

**Example Usage**:
```javascript
{
  url: "https://api.example.com/customer/lookup",
  method: "POST",
  headers: {
    "Authorization": "Bearer abc123",
    "Content-Type": "application/json"
  },
  body: {
    "email": "customer@example.com"
  },
  store_response_in: "customer_data"
}
```

---

### 3. SendIMessageAppTemplate.vue

**Location**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/editors/templates/SendIMessageAppTemplate.vue`

**Purpose**: Send iMessage app invitations to launch native iOS apps within the Messages conversation.

**Parameters**:
- `app_id` (required) - String (iMessage app bundle identifier)
- `app_name` (required) - String (display name)
- `app_icon_url` (optional) - URL (app icon image)
- `launch_url` (optional) - URL (deep link to specific app feature)
- `data` (optional) - JSON object (app-specific data)

**Key Features**:
- Bundle ID input with help text and examples
- App name input
- Optional app icon URL
- Optional launch URL for deep linking
- JSON editor for app-specific data with format button
- Educational info box with common iMessage apps:
  - Shazam: com.shazam.Shazam.MessagesExtension
  - Apple Music: com.apple.Music.MessagesExtension
  - Photos: com.apple.mobileslideshow.PhotosMessagesApp

**Example Usage**:
```javascript
{
  app_id: "com.example.guitartune.MessagesExtension",
  app_name: "Guitar Tuner",
  app_icon_url: "https://example.com/icon.png",
  launch_url: "imessage-app://open?feature=tuner",
  data: {
    mode: "tune",
    instrument: "guitar"
  }
}
```

---

### 4. SendAppClipTemplate.vue

**Location**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/editors/templates/SendAppClipTemplate.vue`

**Purpose**: Send App Clip invocations for lightweight app experiences without installation.

**Parameters**:
- `app_clip_url` (required) - URL (must be registered in App Store Connect)
- `title` (required) - String (card title)
- `subtitle` (optional) - String (card subtitle)
- `image_url` (optional) - URL (hero image for card)
- `action_title` (optional) - String (button text, default: "Open")

**Key Features**:
- App Clip URL input with validation and help text
- Title and subtitle inputs
- Optional hero image URL
- Optional action button text
- Educational info box explaining App Clips:
  - Max 10MB size
  - No installation required
  - Perfect for quick interactions
  - Use cases: tuning, reservations, product details

**Example Usage**:
```javascript
{
  app_clip_url: "https://example.com/clips/guitar-tuner",
  title: "Try our Guitar Tuner",
  subtitle: "Tune your guitar without installing an app",
  image_url: "https://example.com/hero.png",
  action_title: "Start Tuning"
}
```

---

## Technical Implementation

### Common Patterns

All four components follow these best practices:

1. **Composition API** with `<script setup>` syntax
2. **Two-way binding** using computed properties with get/set
3. **Tailwind CSS only** - No custom CSS
4. **Full i18n** - All user-facing strings translated
5. **Validation** - Required field markers, JSON validation where applicable
6. **Help text** - Clear explanations and examples
7. **Error handling** - Separate error states for different fields
8. **Format buttons** - JSON formatting for complex fields

### JSON Validation Pattern

Components with JSON fields (ApiCallTemplate, SendIMessageAppTemplate) use this pattern:

```javascript
const jsonField = computed({
  get: () => {
    const data = props.modelValue.field || {};
    try {
      return JSON.stringify(data, null, 2);
    } catch (e) {
      return '{}';
    }
  },
  set: value => {
    try {
      const parsed = JSON.parse(value);
      error.value = '';
      emit('update:modelValue', { ...props.modelValue, field: parsed });
    } catch (e) {
      error.value = t('PATH.TO.JSON_ERROR');
    }
  },
});
```

### Conditional UI Pattern

ConditionalBranchTemplate demonstrates dynamic UI based on selection:

```vue
<div v-if="conditionType === 'attribute_equals'">
  <!-- Show attribute-specific fields -->
</div>
<div v-else-if="conditionType === 'message_contains'">
  <!-- Show message-specific fields -->
</div>
```

---

## Internationalization

All translations added to: `app/javascript/dashboard/i18n/locale/en/agentBots.json`

**Translation Paths**:
- `AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.*`
- `AGENT_BOTS.ACTION_TEMPLATES.TYPES.API_CALL.*`
- `AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.*`
- `AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.*`

---

## Integration Requirements

To integrate these components into the Bot Studio:

1. **Import** the components in the parent editor
2. **Register** in the component mapping:
   ```javascript
   const templateComponents = {
     'conditional_branch': ConditionalBranchTemplate,
     'api_call': ApiCallTemplate,
     'send_imessage_app': SendIMessageAppTemplate,
     'send_app_clip': SendAppClipTemplate,
     // ... other templates
   }
   ```
3. **Backend support** - Ensure corresponding services exist to process these template types

---

## Next Steps

1. **Backend Services**:
   - ConditionalBranchService - Evaluate conditions and route to correct action
   - ApiCallService - Execute HTTP requests and store responses
   - SendIMessageAppService - Format and send iMessage app invocations
   - SendAppClipService - Format and send App Clip cards

2. **Testing**:
   - Unit tests for condition evaluation logic
   - API call integration tests with mock responses
   - iMessage app format validation
   - App Clip URL validation

3. **Documentation**:
   - User guide for each template type
   - Examples of common use cases
   - Best practices for custom expressions
   - Security considerations for API calls

---

## Summary

These four components complete the template editor suite with the most advanced capabilities:

- **ConditionalBranchTemplate**: Complex conditional logic with multiple evaluation types
- **ApiCallTemplate**: Full HTTP API integration with response storage
- **SendIMessageAppTemplate**: Native iOS app integration
- **SendAppClipTemplate**: Lightweight app experiences

All components maintain consistency with existing templates while providing sophisticated UIs for their complex parameter structures.
