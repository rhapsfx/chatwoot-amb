# Bot Studio Test Console Implementation

## Overview

The Test Console is a real-time testing interface integrated into Bot Studio that allows users to simulate conversations with their bot flows without deploying them. It provides immediate feedback on bot responses, execution path tracking, and node highlighting on the canvas.

## Features

### 1. Real-Time Conversation Testing
- Chat-like interface for simulating user messages
- Instant bot responses based on flow logic
- Message history with timestamps
- Processing indicator during simulation

### 2. Execution Tracking
- Display of executed nodes for each bot response
- Current state tracking
- Node highlighting on canvas during test
- Metadata display showing execution path

### 3. User Interface
- Collapsible panel integrated into Bot Studio
- Toggle button in the main toolbar
- Reset functionality to restart conversation
- Empty state with helpful hints

## Architecture

### Backend Components

#### 1. API Endpoint
**File**: `app/controllers/api/v1/accounts/agent_bots/flows_controller.rb`

```ruby
# POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/simulate
def simulate
  user_message = params[:message]
  session_data = params[:session] || {}

  simulator = AppleMessagesForBusiness::FlowSimulatorService.new(@flow, session_data)
  result = simulator.process_message(user_message)

  render json: {
    bot_response: result[:bot_response],
    current_state: result[:current_state],
    executed_nodes: result[:executed_nodes],
    session: result[:session],
    message: 'Message processed successfully'
  }
end
```

#### 2. FlowSimulatorService
**File**: `app/services/apple_messages_for_business/flow_simulator_service.rb`

**Key Methods**:
- `process_message(message)` - Main entry point for message processing
- `find_intent_match(message)` - Matches user message to intent nodes
- `process_state_node(node)` - Processes state node logic
- `process_template_node(node)` - Processes template nodes
- `process_action_node(node)` - Processes action nodes
- `process_condition_node(node)` - Evaluates conditions and follows branches

**Simulation Logic**:
1. Normalize and analyze user message
2. Check for keyword/intent matches
3. Process current state if no intent match
4. Execute node actions and follow edges
5. Track all executed nodes
6. Return bot response with metadata

#### 3. Route Configuration
**File**: `config/routes.rb`

```ruby
resources :flows, controller: 'agent_bots/flows' do
  member do
    post :compile
    post :validate
    post :simulate  # New route
    # ...
  end
end
```

### Frontend Components

#### 1. BotTestConsole Component
**File**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/BotTestConsole.vue`

**Features**:
- Message list with user/bot differentiation
- Processing indicator with animated dots
- Current state display
- Reset functionality
- Node execution event emission for canvas highlighting

**Props**:
- `botId` (Number, required) - Bot ID
- `flowId` (Number) - Flow ID
- `flowName` (String) - Display name for flow

**Events**:
- `node-executed` - Emitted when nodes are executed, sends array of node IDs

#### 2. useBotSimulator Composable
**File**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/composables/useBotSimulator.js`

**API**:
```javascript
const simulator = useBotSimulator(botId, flowId);

// Properties
simulator.messages        // Array of message objects
simulator.executedNodes   // Array of executed node IDs
simulator.currentState    // Current state ID
simulator.session         // Session data
simulator.isProcessing    // Processing state

// Methods
simulator.sendMessage(text)  // Send user message
simulator.reset()            // Reset conversation
```

#### 3. BotStudio Integration
**File**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/BotStudio.vue`

**Changes**:
- Added Test Console import
- Added `showTestConsole` state
- Added toggle button in toolbar
- Added collapsible test console panel
- Added `handleNodeExecuted` handler for canvas highlighting

#### 4. API Integration
**File**: `app/javascript/dashboard/api/agentBots.js`

```javascript
simulateFlow(botId, flowId, payload) {
  return axios.post(`${this.url}/${botId}/flows/${flowId}/simulate`, payload);
}
```

#### 5. Vuex Store
**File**: `app/javascript/dashboard/store/modules/agentBots.js`

```javascript
simulateFlow: async (_, { botId, flowId, message, session }) => {
  const response = await AgentBotsAPI.simulateFlow(botId, flowId, {
    message,
    session,
  });
  return response.data;
}
```

### Internationalization

**File**: `app/javascript/dashboard/i18n/locale/en/agentBots.json`

```json
"TEST_CONSOLE": {
  "TITLE": "Test Console",
  "TEST_FLOW": "Test Flow",
  "RESET": "Reset",
  "SEND": "Send",
  "INPUT_PLACEHOLDER": "Type a message to test the bot...",
  "EMPTY_STATE": "Start testing your bot flow",
  "EMPTY_HINT": "Send a message to see how your bot responds based on the flow logic",
  "PROCESSING": "Processing...",
  "CURRENT_STATE": "Current State",
  "EXECUTED_NODES": "Executed Nodes",
  "ERROR": "Error",
  "NO_FLOW": "No flow available to test"
}
```

## Usage

### 1. Opening Test Console

1. Navigate to Bot Studio for any bot
2. Click "Test Flow" button in the toolbar
3. Test Console panel slides in from the right

### 2. Testing Conversations

1. Type a message in the input field
2. Press Enter or click "Send"
3. Bot responds based on flow logic
4. Executed nodes highlight on canvas
5. Current state displays at bottom

### 3. Understanding Results

**Message Bubbles**:
- Blue (right-aligned): User messages
- Gray (left-aligned): Bot responses
- Red (with border): Error messages

**Metadata Display** (below bot messages):
- State indicator: Shows current state
- Executed nodes count: Number of nodes processed

**Canvas Highlighting**:
- Executed nodes are highlighted automatically
- Highlights persist until next message or reset

### 4. Resetting Conversation

Click "Reset" button in Test Console header to:
- Clear all messages
- Reset state to initial
- Clear canvas highlights
- Clear session data

## Flow Simulation Logic

### Node Processing Order

1. **Intent Nodes**: Checked first for keyword matches
2. **State Nodes**: Current state processed if no intent match
3. **Template Nodes**: Display template information
4. **Action Nodes**: Execute and follow to next node
5. **Condition Nodes**: Evaluate and branch

### State Transitions

The simulator follows edges between nodes:
- Default transitions: `transitions.default`
- Conditional transitions: Based on condition evaluation
- Intent-triggered transitions: From keyword match

### Response Format

Bot responses include:
- Descriptive text about actions taken
- Template information (type, purpose)
- State transitions
- Available next steps

Example response:
```
[State: Welcome]
Sending template: ah_main_menu
Interactive list picker - user can select from options

[Will transition to: menu_selection]
```

## Testing Flow Types

### 1. Simple Linear Flows
- State → Template → State
- Easy to test, predictable responses

### 2. Intent-Based Flows
- User keywords trigger specific intents
- Intent → State transitions
- Test various keyword combinations

### 3. Conditional Flows
- Test both true and false branches
- Condition evaluation shown in response
- Branch paths highlighted on canvas

### 4. Complex Multi-Path Flows
- Multiple intents and states
- Template interactions
- Action chains

## Error Handling

### Backend Errors
- Service errors caught and returned as JSON
- Status 422 for processing errors
- Error message included in response

### Frontend Errors
- Network errors displayed in red bubble
- Processing timeout protection
- Graceful degradation if flow not found

### Common Issues

**Issue**: "No flow available to test"
**Solution**: Ensure flowId is set and flow exists

**Issue**: "Failed to process message"
**Solution**: Check flow validation, ensure nodes are properly connected

**Issue**: Empty bot response
**Solution**: Verify state has actions or templates configured

## Performance Considerations

### Backend
- Stateless simulation (no database writes)
- In-memory flow processing
- Fast response times (<100ms typical)

### Frontend
- Reactive updates via Vue refs
- Minimal re-renders
- Efficient message list rendering

## Future Enhancements

### Planned Features
1. **Interactive Message Responses**: Simulate list picker, time picker selections
2. **Flow Recording**: Save test sessions for replay
3. **Multi-Turn Context**: Better session state management
4. **Visual Timeline**: Show execution path as timeline
5. **Export Test Cases**: Generate test scenarios from console sessions

### Potential Improvements
1. **Breakpoints**: Pause execution at specific nodes
2. **Variable Inspection**: View session variables in detail
3. **Template Preview**: Show actual template rendering
4. **Performance Metrics**: Track response times per node
5. **Error Replay**: Retry failed messages with debugging

## Best Practices

### For Developers

1. **Always validate flows** before testing
2. **Use descriptive state labels** for clearer test output
3. **Add comments to complex conditions** (future feature)
4. **Test all intent keywords** systematically
5. **Reset between major test changes** to avoid state pollution

### For Bot Designers

1. **Start with simple flows** to verify basic logic
2. **Test edge cases** (unknown keywords, invalid states)
3. **Verify all branches** in conditional flows
4. **Check state transitions** match expected flow
5. **Test error scenarios** (missing templates, invalid actions)

## Debugging Tips

### Viewing Execution Path

1. Watch for executed node count in metadata
2. Check canvas highlights match expected path
3. Verify state transitions in bot responses

### Understanding State Flow

1. Current state shown at bottom of console
2. Transitions shown in bot responses
3. State changes tracked in session

### Troubleshooting Non-Responsive Nodes

1. Check node has outgoing edges
2. Verify edge targets exist
3. Review node configuration in editor
4. Run flow validation

## Technical Notes

### Session Management

Session data is maintained client-side:
- Current state
- Message count
- Last update timestamp
- Custom variables (future)

### Node Execution Tracking

Executed nodes are accumulated during message processing:
- Intent node (if matched)
- State node (current state)
- Template nodes (if sent)
- Action nodes (if executed)
- Condition nodes (if evaluated)

### Canvas Interaction

Test Console interacts with canvas via:
- `node-executed` event emission
- Canvas `highlightedNodeIds` array
- Automatic highlight update

## API Reference

### Simulate Flow Endpoint

**Request**:
```http
POST /api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id/simulate
Content-Type: application/json

{
  "message": "hello",
  "session": {
    "current_state": "AHA1",
    "message_count": 0
  }
}
```

**Response** (Success):
```json
{
  "bot_response": "[State: Welcome]\nSending template: ah_main_menu",
  "current_state": "AHA2",
  "executed_nodes": ["node_1", "node_2", "node_3"],
  "session": {
    "current_state": "AHA2",
    "message_count": 1,
    "last_update": "2024-01-15T10:30:00Z"
  },
  "message": "Message processed successfully"
}
```

**Response** (Error):
```json
{
  "error": "Flow validation failed",
  "message": "Failed to simulate message"
}
```

## Deployment Notes

### Prerequisites
- Bot Studio must be deployed and functional
- Flow validation must be working
- Canvas highlighting feature must be available

### Files Added
- Backend: `flow_simulator_service.rb`
- Frontend: Enhanced `BotTestConsole.vue`, `useBotSimulator.js`
- Routes: Added `:simulate` action
- i18n: Added TEST_CONSOLE translations

### Files Modified
- `flows_controller.rb` - Added simulate action
- `BotStudio.vue` - Integrated test console
- `agentBots.js` (API) - Added simulateFlow method
- `agentBots.js` (store) - Added simulateFlow action
- `routes.rb` - Added simulate route
- `agentBots.json` - Added translations

### Testing Deployment

1. Create a simple bot flow with 2-3 states
2. Open Test Console
3. Send test message
4. Verify bot response appears
5. Check canvas highlighting works
6. Test reset functionality

---

**Last Updated**: December 2024
**Version**: 1.0.0
**Author**: Bot Studio Team
