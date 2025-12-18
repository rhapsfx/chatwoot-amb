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
- `spec/models/bot_flow_spec.rb`
- `spec/services/apple_messages_for_business/flow_diff_service_spec.rb`
- `spec/requests/api/v1/accounts/agent_bots/flows_controller_spec.rb`
- `spec/factories/bot_flows.rb`
- `docs/apple-messages/BOT_STUDIO_PHASE_6_VERSION_MANAGEMENT.md` (this file)

### Modified Files
- `app/models/bot_flow.rb` - Added version management methods
- `app/controllers/api/v1/accounts/agent_bots/flows_controller.rb` - Added version endpoints
- `config/routes.rb` - Added version management routes

## Summary

Phase 6 successfully implements a complete version management system for bot flows with:

- ✅ Database schema for versioning
- ✅ Parent-child flow relationships
- ✅ Version creation and tagging
- ✅ Publish/unpublish functionality
- ✅ Version history tracking
- ✅ Flow comparison and diff
- ✅ Comprehensive API endpoints
- ✅ Complete test coverage
- ✅ Factory support for testing

The system is production-ready and follows Chatwoot's coding standards. Frontend integration can now proceed using the documented API endpoints.
