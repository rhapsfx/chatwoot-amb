# Flow Management Vuex Integration

## Overview

This document describes the Vuex store integration for Flow Management in the Agent Bots module.

## Files Modified

### 1. `/app/javascript/dashboard/store/mutation-types.js`

Added flow management mutation types:

- `SET_FLOWS` - Set all flows for a bot
- `ADD_FLOW` - Add a new flow to the store
- `UPDATE_FLOW` - Update an existing flow
- `DELETE_FLOW` - Remove a flow from the store

### 2. `/app/javascript/dashboard/api/agentBots.js`

Added flow management API endpoints:

```javascript
// Get all flows for a bot
getFlows(botId)

// Get single flow by ID
getFlow(botId, flowId)

// Create new flow
createFlow(botId, flowData)

// Update existing flow
updateFlow(botId, flowId, flowData)

// Delete flow
deleteFlow(botId, flowId)

// Compile flow to bot_config
compileFlow(botId, flowId)

// Validate flow structure
validateFlow(botId, flowId)

// Get preview data
previewFlow(botId, flowId)
```

### 3. `/app/javascript/dashboard/store/modules/agentBots.js`

#### State Updates

Added to state:
```javascript
{
  flows: [],  // Array to store flows
  uiFlags: {
    isFetchingFlows: false,
    isCreatingFlow: false,
    isUpdatingFlow: false,
    isDeletingFlow: false,
    isCompilingFlow: false,
  }
}
```

#### Getters

Added flow getters:
```javascript
getFlows($state)           // Get all flows
getFlow($state)(flowId)    // Get single flow by ID
```

#### Actions

Added flow management actions:

```javascript
// Get all flows for a bot
getFlows({ commit }, botId)

// Get single flow (doesn't commit to store)
getFlow(_, { botId, flowId })

// Create new flow
createFlow({ commit }, { botId, ...flowData })

// Update existing flow
updateFlow({ commit }, { botId, flowId, ...flowData })

// Delete flow
deleteFlow({ commit }, { botId, flowId })

// Compile flow to bot_config
compileFlow({ commit }, { botId, flowId })

// Validate flow structure (no store mutation)
validateFlow(_, { botId, flowId })

// Get preview data (no store mutation)
previewFlow(_, { botId, flowId })
```

#### Mutations

Added flow mutations:

```javascript
SET_FLOWS($state, flows)      // Replace all flows
ADD_FLOW($state, flow)        // Add new flow
UPDATE_FLOW($state, flow)     // Update existing flow
DELETE_FLOW($state, flowId)   // Remove flow by ID
```

## API Endpoints Integrated

All API calls follow the pattern:
```
/api/v1/accounts/:account_id/agent_bots/:bot_id/flows/...
```

Endpoints:
- `GET    /flows` - List all flows
- `GET    /flows/:id` - Get single flow
- `POST   /flows` - Create flow
- `PATCH  /flows/:id` - Update flow
- `DELETE /flows/:id` - Delete flow
- `POST   /flows/:id/compile` - Compile flow
- `POST   /flows/:id/validate` - Validate flow
- `GET    /flows/:id/preview` - Preview flow

## Usage Examples

### Fetching Flows

```javascript
// In a Vue component
export default {
  async mounted() {
    const botId = this.$route.params.botId;
    await this.$store.dispatch('agentBots/getFlows', botId);

    // Access flows from store
    const flows = this.$store.getters['agentBots/getFlows'];
  }
}
```

### Creating a Flow

```javascript
const newFlow = await this.$store.dispatch('agentBots/createFlow', {
  botId: 123,
  name: 'Welcome Flow',
  description: 'Greets customers',
  flow_data: { nodes: [], edges: [] }
});

if (newFlow) {
  console.log('Flow created:', newFlow.id);
}
```

### Updating a Flow

```javascript
const updated = await this.$store.dispatch('agentBots/updateFlow', {
  botId: 123,
  flowId: 456,
  name: 'Updated Welcome Flow',
  flow_data: { nodes: [...], edges: [...] }
});
```

### Deleting a Flow

```javascript
const success = await this.$store.dispatch('agentBots/deleteFlow', {
  botId: 123,
  flowId: 456
});

if (success) {
  console.log('Flow deleted');
}
```

### Compiling a Flow

```javascript
const compiled = await this.$store.dispatch('agentBots/compileFlow', {
  botId: 123,
  flowId: 456
});

if (compiled) {
  console.log('Compiled bot_config:', compiled.bot_config);
}
```

### Validating a Flow

```javascript
const validation = await this.$store.dispatch('agentBots/validateFlow', {
  botId: 123,
  flowId: 456
});

if (validation.valid) {
  console.log('Flow is valid');
} else {
  console.log('Validation errors:', validation.errors);
}
```

### Getting Preview Data

```javascript
const preview = await this.$store.dispatch('agentBots/previewFlow', {
  botId: 123,
  flowId: 456
});

console.log('Preview:', preview);
```

### Accessing UI Flags

```javascript
computed: {
  uiFlags() {
    return this.$store.getters['agentBots/getUIFlags'];
  },
  isLoadingFlows() {
    return this.uiFlags.isFetchingFlows;
  },
  isSaving() {
    return this.uiFlags.isCreatingFlow || this.uiFlags.isUpdatingFlow;
  }
}
```

## Error Handling

All actions include error handling:

- Errors are thrown to the user via `throwErrorMessage(error)`
- Actions return `null` on error (except `deleteFlow` which returns `false`)
- UI flags are always reset in `finally` blocks

## Implementation Notes

1. **Follows existing patterns**: All code follows the established patterns in the agentBots module
2. **Proper UI flags**: Loading states are tracked for all async operations
3. **Error handling**: All API calls have proper error handling
4. **Store mutations**: Flows are properly managed in the store with full CRUD operations
5. **No side effects**: Validation and preview actions don't mutate the store

## Testing

To test the integration:

1. Ensure backend flow management API is implemented
2. Navigate to a bot's flow management page
3. Create, update, delete flows and verify store updates
4. Check that UI flags properly indicate loading states
5. Verify error handling with invalid data

## Future Enhancements

Potential improvements:

- Add flow pagination if needed
- Add flow search/filtering
- Add flow templates
- Add flow duplication
- Add flow export/import
- Add flow versioning integration
