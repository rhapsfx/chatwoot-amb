# Visual Bot Studio - Phase 6: Version Management System

## Overview

Phase 6 implements a comprehensive version management system for bot flows, enabling users to create, manage, compare, and deploy different versions of their bot configurations.

## Implementation Status

**Status**: ✅ **Complete**
**Date**: December 8, 2025

## Features Implemented

### 1. Database Schema

**Migration**: `db/migrate/20251208102513_add_version_management_to_bot_flows.rb`

**New Columns**:
- `version_tag` (string) - User-friendly version identifier (e.g., "v1.0", "stable", "production")
- `parent_flow_id` (bigint) - Reference to parent version for branching
- `is_published` (boolean) - Publication status (only one published version per bot)
- `published_at` (datetime) - Publication timestamp
- `changelog` (text) - Description of changes in this version

**Indexes**:
- `parent_flow_id` - For efficient parent-child queries
- `[agent_bot_id, version_tag]` - Unique constraint for version tags per bot

### 2. Model Updates

**File**: `app/models/bot_flow.rb`

**New Associations**:
```ruby
belongs_to :parent_flow, class_name: 'BotFlow', optional: true
has_many :child_flows, class_name: 'BotFlow', foreign_key: :parent_flow_id
```

**New Scopes**:
- `published` - Get only published flows
- `drafts` - Get only draft flows
- `ordered_by_version` - Order by version number descending

**Key Methods**:

#### `create_version(version_tag:, changelog: nil)`
Creates a new version of the flow with incremented version number.

```ruby
new_version = flow.create_version(
  version_tag: 'v2.0',
  changelog: 'Added new menu options'
)
```

#### `publish!`
Publishes the flow and unpublishes all other versions for the same bot. Also compiles and updates the agent_bot's bot_config.

```ruby
flow.publish!  # Publishes this version, unpublishes others
```

#### `unpublish!`
Unpublishes the flow.

```ruby
flow.unpublish!
```

#### `version_tree`
Returns the complete version history from root to current version.

```ruby
tree = flow.version_tree  # Returns array of BotFlow objects
```

#### `compare_with(other_flow)`
Compares this flow with another flow and returns a detailed diff.

```ruby
diff = flow.compare_with(other_flow)
```

#### `version_display`
Returns user-friendly version string (version_tag if present, otherwise "vN").

```ruby
flow.version_display  # => "v2.0" or "v5"
```

### 3. FlowDiffService

**File**: `app/services/apple_messages_for_business/flow_diff_service.rb`

Compares two flows and identifies:
- Added nodes
- Removed nodes
- Modified nodes (with detailed change tracking)
- Added edges
- Removed edges
- Summary statistics

**Usage**:
```ruby
service = AppleMessagesForBusiness::FlowDiffService.new(flow_a, flow_b)
diff = service.diff

# Returns:
{
  flows: {
    flow_a: { id, name, version, version_tag, ... },
    flow_b: { id, name, version, version_tag, ... }
  },
  nodes: {
    added: [...],      # Nodes in flow_b not in flow_a
    removed: [...],    # Nodes in flow_a not in flow_b
    modified: [...]    # Nodes with changes
  },
  edges: {
    added: [...],
    removed: [...]
  },
  summary: {
    nodes_added: 2,
    nodes_removed: 1,
    nodes_modified: 3,
    edges_added: 2,
    edges_removed: 1,
    total_changes: 9
  }
}
```

**Change Detection**:
- Node type changes
- Position changes
- Data field changes (any key in node['data'])
- Tracks old and new values for each change

### 4. API Endpoints

**Base URL**: `/api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id`

#### POST `/create_version`
Creates a new version from the current flow.

**Parameters**:
- `version_tag` (optional) - Custom version tag (auto-generated if not provided)
- `changelog` (optional) - Description of changes

**Response**:
```json
{
  "flow": {
    "id": 123,
    "name": "Main Flow",
    "version": 2,
    "version_tag": "v2.0",
    "changelog": "Added new features",
    "parent_flow_id": 122,
    "is_published": false,
    "node_count": 5,
    "edge_count": 4
  },
  "message": "Version v2.0 created successfully"
}
```

#### POST `/publish`
Publishes the flow version and compiles it to bot_config.

**Response**:
```json
{
  "flow": {
    "id": 123,
    "is_published": true,
    "published_at": "2025-12-08T10:25:13Z"
  },
  "message": "Flow v2.0 published successfully"
}
```

**Side Effects**:
- Unpublishes all other versions for this bot
- Compiles flow and updates `agent_bot.bot_config`
- Sets `published_at` timestamp

#### POST `/unpublish`
Unpublishes the flow version.

**Response**:
```json
{
  "flow": {
    "id": 123,
    "is_published": false
  },
  "message": "Flow v2.0 unpublished successfully"
}
```

#### GET `/versions`
Returns all versions in the flow family (root and all children).

**Response**:
```json
{
  "versions": [
    {
      "id": 125,
      "version": 3,
      "version_tag": "v3.0",
      "is_published": true,
      "published_at": "2025-12-08T10:25:13Z"
    },
    {
      "id": 124,
      "version": 2,
      "version_tag": "v2.0",
      "is_published": false
    },
    {
      "id": 123,
      "version": 1,
      "version_tag": "v1.0",
      "is_published": false
    }
  ]
}
```

#### GET `/version_tree`
Returns the version hierarchy from root to current version.

**Response**:
```json
{
  "tree": [
    { "id": 123, "version": 1, "version_tag": "v1.0" },
    { "id": 124, "version": 2, "version_tag": "v2.0" },
    { "id": 125, "version": 3, "version_tag": "v3.0" }
  ]
}
```

#### GET `/compare/:other_id`
Compares this flow with another flow.

**Response**:
```json
{
  "diff": {
    "flows": { ... },
    "nodes": {
      "added": [...],
      "removed": [...],
      "modified": [
        {
          "id": "node1",
          "type": "state",
          "label": "Start",
          "changes": {
            "label": { "old": "Start", "new": "Begin" },
            "position": { "old": {...}, "new": {...} }
          }
        }
      ]
    },
    "edges": { ... },
    "summary": { ... }
  },
  "message": "Flow comparison completed successfully"
}
```

### 5. Routes Configuration

**File**: `config/routes.rb`

```ruby
resources :flows, controller: 'agent_bots/flows' do
  member do
    # ... existing routes ...
    # Version management
    post :create_version
    post :publish
    post :unpublish
    get :versions
    get :version_tree
    get 'compare/:other_id', action: :compare
  end
end
```

## Testing

### RSpec Specs Created

1. **Model Specs** (`spec/models/bot_flow_spec.rb`)
   - Association tests
   - Validation tests
   - Scope tests
   - Version management method tests
   - Edge cases and error handling

2. **Service Specs** (`spec/services/apple_messages_for_business/flow_diff_service_spec.rb`)
   - Node diff detection
   - Edge diff detection
   - Change tracking accuracy
   - Identical flow handling

3. **Request Specs** (`spec/requests/api/v1/accounts/agent_bots/flows_controller_spec.rb`)
   - All version management endpoints
   - Authorization checks
   - Error handling
   - Response format validation

4. **Factory** (`spec/factories/bot_flows.rb`)
   - Base factory
   - Traits: `with_version_tag`, `published`, `inactive`, `with_changelog`, `with_parent`, `complex_flow`

### Running Tests

```bash
# Run all bot flow tests
bundle exec rspec spec/models/bot_flow_spec.rb

# Run diff service tests
bundle exec rspec spec/services/apple_messages_for_business/flow_diff_service_spec.rb

# Run controller tests
bundle exec rspec spec/requests/api/v1/accounts/agent_bots/flows_controller_spec.rb

# Run all flow-related tests
bundle exec rspec spec/ -e "BotFlow\|FlowDiff"
```

## Usage Patterns

### Creating and Publishing a New Version

```ruby
# Create a new version
new_version = current_flow.create_version(
  version_tag: 'v2.0',
  changelog: 'Added appointment booking flow'
)

# Make changes to the new version
new_version.flow_data['nodes'] << new_node
new_version.save!

# Publish when ready
new_version.publish!
```

### Comparing Versions

```ruby
# Compare two versions
diff = v2.compare_with(v1)

# Check summary
if diff[:summary][:total_changes] > 0
  puts "#{diff[:summary][:nodes_added]} nodes added"
  puts "#{diff[:summary][:nodes_modified]} nodes modified"
end

# Examine specific changes
diff[:nodes][:modified].each do |change|
  puts "Node #{change[:id]} changes:"
  change[:changes].each do |field, values|
    puts "  #{field}: #{values[:old]} → #{values[:new]}"
  end
end
```

### Managing Version History

```ruby
# Get all versions
versions = flow.agent_bot.bot_flows.where(
  parent_flow_id: flow.id
).or(
  flow.agent_bot.bot_flows.where(id: flow.id)
).ordered_by_version

# Get version tree
tree = flow.version_tree
puts "Version chain: #{tree.map(&:version_display).join(' → ')}"

# Find published version
published = flow.agent_bot.bot_flows.published.first
```

## Frontend Integration (To Be Implemented)

The backend is ready for frontend integration. Frontend should implement:

1. **Version Creation UI**
   - Button to "Create New Version"
   - Modal for version tag and changelog input
   - Auto-save current flow before creating version

2. **Version Management Panel**
   - List of all versions
   - Publish/unpublish buttons
   - Published status indicator
   - Version tags and changelogs

3. **Version Comparison UI**
   - Side-by-side flow visualization
   - Highlight added nodes (green)
   - Highlight removed nodes (red)
   - Highlight modified nodes (yellow)
   - Show detailed change diff

4. **Version Tree Visualization**
   - Timeline view of versions
   - Branch visualization
   - Quick navigation between versions

## Database Migration

```bash
# Run the migration
rails db:migrate

# Rollback if needed
rails db:rollback
```

## Security Considerations

- ✅ Version tags must be unique per agent_bot
- ✅ Only one published version allowed per bot
- ✅ Authorization checks prevent cross-account access
- ✅ Transactions ensure atomic publish operations
- ✅ Cascading deletes handled properly (nullify children)

## Performance Considerations

- Indexed columns for efficient queries
- Scopes use efficient SQL queries
- Diff service works in memory (fast for typical flows)
- Version tree walks parent chain (optimized for typical depth)

## Production Deployment (Phase 6+)

**Status**: ✅ **Complete** (December 2025)

### FlowExecutorService - Production Flow Execution

Bot Studio flows are now production-ready via the new `FlowExecutorService`, which replaces the legacy `AcousticHouseBotService` for bots with published flows.

**File**: `app/services/apple_messages_for_business/flow_executor_service.rb`

**Key Features**:
- Executes visual bot flows on real devices
- Sends actual messages via Apple MSP
- Stores conversation state persistently
- Handles all node types (state, intent, template, action)
- Integrates with existing send services

### Automatic Routing

**File**: `app/services/apple_messages_for_business/incoming_message_service.rb`

The system automatically routes to the appropriate service:

```ruby
# Check if bot has an active published flow
active_flow = configured_bot.bot_flows.active.published.first

if active_flow
  # NEW: Use visual flow executor
  executor = AppleMessagesForBusiness::FlowExecutorService.new(
    active_flow, @conversation, @message
  )
  executor.execute
else
  # LEGACY: Use old service (will be deprecated)
  bot_service = AppleMessagesForBusiness::AcousticHouseBotService.new(
    @conversation, @message, configured_bot, configured_bot.bot_config
  )
  bot_service.process_message
end
```

### Deployment Workflow

1. **Design Flow**: Create flow in Bot Studio visual editor
2. **Test Flow**: Use test console to verify behavior
3. **Create Version**: `POST /flows/:id/create_version`
4. **Publish Version**: `POST /flows/:id/publish`
   - Sets `is_published: true`
   - Unpublishes other versions
   - Compiles flow to bot_config (for backwards compatibility)
5. **Activate**: Ensure `is_active: true` (default)
6. **Test on Device**: Send messages from real Apple Messages device
7. **Monitor**: Check logs for execution flow and errors

### Production Requirements

For a flow to execute in production:

1. ✅ **Bot assigned to inbox**: `AgentBotInbox.active?` → true
2. ✅ **Flow published**: `flow.is_published` → true
3. ✅ **Flow active**: `flow.is_active` → true
4. ✅ **Valid flow data**: `flow.flow_data` contains nodes and edges

### Session State Management

Flow execution state is stored in `conversation.additional_attributes`:

```ruby
{
  'bot_session' => {
    'current_state' => 'AHA2',
    'message_count' => 5,
    'last_update' => '2025-12-19T10:30:00Z',
    'flow_id' => 123,
    'flow_name' => 'Main Flow v2.0'
  }
}
```

### Migration Path

**Phase 1** ✅ **Complete**: Parallel Operation
- Bots with active published flows → `FlowExecutorService`
- Bots without flows → `AcousticHouseBotService` (legacy)
- Both systems work simultaneously

**Phase 2** ✅ **Complete**: Visual Flows Created
- Visual flows created for all bots in Bot Studio
- Flows tested in test console
- Flows ready for production deployment

**Phase 3** (Current): Production Publishing
- Publish flows to production (set `is_published: true`)
- Monitor production execution via FlowExecutorService
- Verify behavior on real devices
- Gather feedback and iterate

**Phase 4** (Future): Deprecation
- Remove `AcousticHouseBotService`
- All bots use visual flows exclusively
- Legacy bot_config format deprecated

### Logging and Monitoring

FlowExecutorService provides comprehensive logging:

```
[FlowExecutor] 🚀 Executing flow 'Main Flow v2.0' for message: hello
[FlowExecutor] 📍 Current state: AHA1
[FlowExecutor] 🔑 Intent matched: Welcome
[FlowExecutor] 🔧 Executing handler: handle_welcome
[FlowExecutor] 📤 Sending template: ah_welcome_message (list_picker)
[FlowExecutor] ➡️ Transitioned to state: AHA2
[FlowExecutor] ✅ Execution complete. Nodes: 2, Messages: 1
```

### Troubleshooting Production Flows

**Flow not executing**:
- Verify flow is published: `flow.is_published` → true
- Check flow is active: `flow.is_active` → true
- Confirm bot assigned to inbox
- Check logs for routing decision

**Messages not sending**:
- Verify templates exist with correct names
- Check templates support 'apple_messages_for_business' channel
- Test send services individually
- Check network connectivity to Apple MSP

**State not persisting**:
- Check `conversation.additional_attributes` is writable
- Verify database transactions committing
- Check for exceptions in `save_session_state`

### Documentation

**Complete Guide**: `docs/bot-studio/FLOW_EXECUTOR_SERVICE.md`

**Key Topics**:
- Service architecture
- How it works (step-by-step)
- Handler method execution
- Template sending
- State management
- Error handling
- Testing strategies

### Example Production Flow

```javascript
// Published flow for bot ID 12
{
  name: "Main Flow v2.0",
  is_published: true,
  is_active: true,
  version: 2,
  version_tag: "v2.0",
  flow_data: {
    nodes: [
      {
        id: 'welcome-state',
        type: 'state',
        data: {
          state_id: 'AHA1',
          label: 'Welcome',
          handler: 'handle_welcome',
          is_initial: true
        }
      },
      {
        id: 'menu-intent',
        type: 'intent',
        data: {
          label: 'Main Menu',
          keywords: ['menu', 'help'],
          handler: 'handle_menu'
        }
      }
    ],
    edges: [
      {
        source: 'menu-intent',
        target: 'welcome-state'
      }
    ]
  }
}

// Execution flow:
// 1. User sends: "hello"
//    → Matches initial state (AHA1)
//    → Executes handle_welcome handler
//    → Sends welcome templates
//    → State saved to conversation
//
// 2. User sends: "menu"
//    → Matches intent keywords
//    → Executes handle_menu handler
//    → Sends menu template
//    → Transitions to next state
```

## Future Enhancements

1. **Version Tags Presets** - Common tags like "stable", "beta", "production"
2. **Diff Caching** - Cache comparison results for frequently compared versions
3. **Version Rollback** - One-click rollback to previous version
4. **Branch Management** - Create branches from any version (not just linear)
5. **Merge Versions** - Merge changes from one version into another
6. **Version Export/Import** - Export version as standalone JSON

## Files Modified/Created

### Created Files
- `db/migrate/20251208102513_add_version_management_to_bot_flows.rb`
- `app/services/apple_messages_for_business/flow_diff_service.rb`
- **`app/services/apple_messages_for_business/flow_executor_service.rb`** - **Production executor**
- **`app/services/apple_messages_for_business/flow_simulator_service.rb`** - Test console simulator
- `spec/models/bot_flow_spec.rb`
- `spec/services/apple_messages_for_business/flow_diff_service_spec.rb`
- `spec/requests/api/v1/accounts/agent_bots/flows_controller_spec.rb`
- `spec/factories/bot_flows.rb`
- **`docs/bot-studio/FLOW_EXECUTOR_SERVICE.md`** - **Production deployment guide**
- **`docs/bot-studio/TEST_CONSOLE_IMPLEMENTATION.md`** - Test console guide
- `docs/apple-messages/BOT_STUDIO_PHASE_6_VERSION_MANAGEMENT.md` (this file)

### Modified Files
- `app/models/bot_flow.rb` - Added version management methods
- `app/controllers/api/v1/accounts/agent_bots/flows_controller.rb` - Added version endpoints + simulate endpoint
- **`app/services/apple_messages_for_business/incoming_message_service.rb`** - **Added FlowExecutorService routing**
- `config/routes.rb` - Added version management routes
- **`docs/bot-studio/README.md`** - Updated with production deployment info

## Summary

Phase 6+ successfully implements a complete version management system AND production deployment for bot flows with:

**Version Management**:
- ✅ Database schema for versioning
- ✅ Parent-child flow relationships
- ✅ Version creation and tagging
- ✅ Publish/unpublish functionality
- ✅ Version history tracking
- ✅ Flow comparison and diff
- ✅ Comprehensive API endpoints
- ✅ Complete test coverage
- ✅ Factory support for testing

**Production Deployment** (Phase 6+):
- ✅ **FlowExecutorService** - Production flow execution engine
- ✅ **Automatic routing** - Flows or legacy service
- ✅ **Test console** - Visual template previews for testing
- ✅ **FlowSimulatorService** - Safe in-studio testing
- ✅ **Session state management** - Persistent conversation state
- ✅ **Handler method integration** - Reuses existing handlers
- ✅ **Template sending** - Uses existing send services
- ✅ **Comprehensive logging** - Production debugging
- ✅ **Migration path** - Gradual transition from legacy

The system is **production-ready** and follows Chatwoot's coding standards. Visual flows can now be:
1. Designed in Bot Studio
2. Tested in test console
3. Published to production
4. Executed on real devices
5. Monitored via comprehensive logs

**Next Steps**:
1. Test FlowExecutorService with bot ID 12 published flow
2. Monitor production execution logs
3. Gradually migrate remaining bots to visual flows
4. Eventually deprecate legacy AcousticHouseBotService

