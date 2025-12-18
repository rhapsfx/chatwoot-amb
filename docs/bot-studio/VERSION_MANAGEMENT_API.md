# Bot Studio Flow Version Management API

## Overview

This document describes the version management API endpoints for Bot Studio flows. The version management system allows users to create versions, publish/unpublish flows, compare versions, and restore previous versions.

## API Endpoints

All endpoints are scoped under:
```
/api/v1/accounts/:account_id/agent_bots/:agent_bot_id/flows/:id
```

### 1. Create New Version

**Endpoint:** `POST /flows/:id/create_version`

Creates a new version of the flow with an incremented version number.

**Parameters:**
- `version_tag` (optional, string) - Custom version tag (e.g., "v2.0", "stable")
- `changelog` (optional, string) - Description of changes

**Response:**
```json
{
  "flow": {
    "id": 123,
    "name": "My Flow",
    "version": 2,
    "version_tag": "v2.0",
    "changelog": "Added new features",
    "parent_flow_id": 122,
    "is_published": false,
    "published_at": null,
    "node_count": 5,
    "edge_count": 4,
    "version_display": "v2.0"
  },
  "message": "Version v2.0 created successfully"
}
```

**Example:**
```javascript
POST /api/v1/accounts/1/agent_bots/5/flows/10/create_version
{
  "version_tag": "v2.0",
  "changelog": "Added validation nodes"
}
```

---

### 2. Publish Version

**Endpoint:** `POST /flows/:id/publish`

Publishes the current flow version. Only one version can be published per bot at a time. Publishing automatically:
- Unpublishes all other versions for the same bot
- Sets `is_published` to true
- Sets `published_at` timestamp
- Compiles the flow and updates the agent_bot's `bot_config`

**Response:**
```json
{
  "flow": {
    "id": 123,
    "name": "My Flow",
    "version": 2,
    "version_tag": "v2.0",
    "is_published": true,
    "published_at": "2025-12-17T10:30:00Z",
    "version_display": "v2.0"
  },
  "message": "Flow v2.0 published successfully"
}
```

**Example:**
```javascript
POST /api/v1/accounts/1/agent_bots/5/flows/10/publish
```

---

### 3. Unpublish Version

**Endpoint:** `POST /flows/:id/unpublish`

Unpublishes the current flow version.

**Response:**
```json
{
  "flow": {
    "id": 123,
    "version_tag": "v2.0",
    "is_published": false,
    "version_display": "v2.0"
  },
  "message": "Flow v2.0 unpublished successfully"
}
```

---

### 4. List All Versions

**Endpoint:** `GET /flows/:id/versions`

Returns all versions in the same version family (root + all children), ordered by version number descending.

**Response:**
```json
{
  "versions": [
    {
      "id": 125,
      "name": "My Flow",
      "version": 3,
      "version_tag": "v3.0",
      "changelog": "Bug fixes",
      "is_published": true,
      "published_at": "2025-12-17T11:00:00Z",
      "parent_flow_id": 122,
      "node_count": 6,
      "edge_count": 5,
      "version_display": "v3.0"
    },
    {
      "id": 123,
      "version": 2,
      "version_tag": "v2.0",
      "is_published": false,
      "parent_flow_id": 122,
      "version_display": "v2.0"
    },
    {
      "id": 122,
      "version": 1,
      "version_tag": "v1.0",
      "is_published": false,
      "parent_flow_id": null,
      "version_display": "v1.0"
    }
  ]
}
```

---

### 5. Get Version Tree

**Endpoint:** `GET /flows/:id/version_tree`

Returns the version hierarchy from root to current flow.

**Response:**
```json
{
  "tree": [
    {
      "id": 122,
      "version": 1,
      "version_tag": "v1.0",
      "version_display": "v1.0"
    },
    {
      "id": 123,
      "version": 2,
      "version_tag": "v2.0",
      "version_display": "v2.0"
    },
    {
      "id": 125,
      "version": 3,
      "version_tag": "v3.0",
      "version_display": "v3.0"
    }
  ]
}
```

---

### 6. Compare Versions

**Endpoint:** `GET /flows/:id/compare/:other_id`

Compares two flow versions and returns the differences.

**Response:**
```json
{
  "diff": {
    "nodes": {
      "added": [
        {
          "id": "node2",
          "type": "template",
          "data": { "label": "New Node" }
        }
      ],
      "removed": [],
      "modified": [
        {
          "id": "node1",
          "changes": {
            "label": {
              "old": "Start",
              "new": "Modified Start"
            }
          }
        }
      ]
    },
    "edges": {
      "added": [
        {
          "id": "edge1",
          "source": "node1",
          "target": "node2"
        }
      ],
      "removed": [],
      "modified": []
    },
    "summary": {
      "nodes_added": 1,
      "nodes_removed": 0,
      "nodes_modified": 1,
      "edges_added": 1,
      "edges_removed": 0,
      "edges_modified": 0
    }
  },
  "message": "Flow comparison completed successfully"
}
```

**Example:**
```javascript
GET /api/v1/accounts/1/agent_bots/5/flows/123/compare/122
```

---

### 7. Restore Version

**Endpoint:** `POST /flows/:id/restore`

Restores a previous version by creating a new version based on the selected flow's data. The new version will have:
- Incremented version number (latest + 1)
- Same flow_data as the restored version
- Auto-generated version_tag indicating it's a restore
- Unpublished status

**Response:**
```json
{
  "flow": {
    "id": 126,
    "name": "My Flow",
    "version": 4,
    "version_tag": "v4 (Restored from v1.0)",
    "changelog": "Restored from v1.0",
    "parent_flow_id": 122,
    "is_published": false,
    "published_at": null,
    "node_count": 5,
    "edge_count": 4,
    "version_display": "v4 (Restored from v1.0)"
  },
  "message": "Flow restored as v4 (Restored from v1.0)"
}
```

**Example:**
```javascript
POST /api/v1/accounts/1/agent_bots/5/flows/122/restore
```

---

## Model Methods

### BotFlow Model

#### `create_version(version_tag:, changelog: nil)`

Creates a new version of the flow.

```ruby
new_version = flow.create_version(
  version_tag: 'v2.0',
  changelog: 'Added new features'
)
```

#### `publish!`

Publishes the flow and compiles it to bot_config.

```ruby
flow.publish!
```

#### `unpublish!`

Unpublishes the flow.

```ruby
flow.unpublish!
```

#### `restore_as_new_version`

Restores the flow as a new version.

```ruby
restored = old_flow.restore_as_new_version
```

#### `version_tree`

Returns array of versions from root to current.

```ruby
tree = flow.version_tree
# => [root_flow, v2_flow, current_flow]
```

#### `compare_with(other_flow)`

Compares with another flow and returns differences.

```ruby
diff = flow.compare_with(other_flow)
```

#### `version_display`

Returns display-friendly version string.

```ruby
flow.version_display
# => "v2.0" or "v2" if no tag
```

---

## Database Schema

The `bot_flows` table includes these version-related columns:

- `version` (integer, default: 1) - Version number
- `version_tag` (string) - Custom version tag
- `changelog` (text) - Version changelog
- `is_published` (boolean, default: false) - Published status
- `published_at` (datetime) - Publication timestamp
- `parent_flow_id` (bigint) - Reference to parent version

**Indexes:**
- `index_bot_flows_on_agent_bot_id_and_version_tag` (UNIQUE)
- `index_bot_flows_on_parent_flow_id`

---

## Authorization

All endpoints require:
- Authenticated user
- User belongs to the account
- `check_authorization(AgentBot)` passes

---

## Error Handling

### Common Error Responses

**Not Found (404):**
```json
{
  "error": "Flow not found"
}
```

**Unprocessable Entity (422):**
```json
{
  "error": "Validation failed: Version tag has already been taken"
}
```

**Unauthorized (401):**
```json
{
  "error": "Unauthorized access"
}
```

---

## Frontend Integration

### Example Vue.js Usage

```javascript
// Create new version
const createVersion = async (flowId, versionTag, changelog) => {
  const response = await axios.post(
    `/api/v1/accounts/${accountId}/agent_bots/${botId}/flows/${flowId}/create_version`,
    { version_tag: versionTag, changelog }
  );
  return response.data;
};

// Publish version
const publishVersion = async (flowId) => {
  const response = await axios.post(
    `/api/v1/accounts/${accountId}/agent_bots/${botId}/flows/${flowId}/publish`
  );
  return response.data;
};

// Get all versions
const getVersions = async (flowId) => {
  const response = await axios.get(
    `/api/v1/accounts/${accountId}/agent_bots/${botId}/flows/${flowId}/versions`
  );
  return response.data.versions;
};

// Restore version
const restoreVersion = async (flowId) => {
  const response = await axios.post(
    `/api/v1/accounts/${accountId}/agent_bots/${botId}/flows/${flowId}/restore`
  );
  return response.data;
};

// Compare versions
const compareVersions = async (flowId, otherFlowId) => {
  const response = await axios.get(
    `/api/v1/accounts/${accountId}/agent_bots/${botId}/flows/${flowId}/compare/${otherFlowId}`
  );
  return response.data.diff;
};
```

---

## Testing

Comprehensive test coverage is provided in:
- `spec/requests/api/v1/accounts/agent_bots/flows_controller_spec.rb`
- `spec/models/bot_flow_spec.rb`

To run tests:
```bash
# Controller tests
bundle exec rspec spec/requests/api/v1/accounts/agent_bots/flows_controller_spec.rb

# Model tests
bundle exec rspec spec/models/bot_flow_spec.rb
```

---

## Version Management Workflow

### Typical Version Management Flow

1. **Create Initial Flow**
   - User creates a flow with version 1

2. **Create New Version**
   - User makes changes and creates v2.0
   - System duplicates flow with incremented version
   - New version is unpublished

3. **Test New Version**
   - User tests v2.0 in preview mode
   - Can compare with v1.0 to see changes

4. **Publish New Version**
   - User publishes v2.0
   - System unpublishes v1.0
   - System compiles v2.0 to bot_config

5. **Rollback if Needed**
   - User restores v1.0
   - System creates v3 based on v1.0 data
   - User can publish v3 to revert

---

## Implementation Files

**Backend:**
- Controller: `app/controllers/api/v1/accounts/agent_bots/flows_controller.rb`
- Model: `app/models/bot_flow.rb`
- Routes: `config/routes.rb`

**Tests:**
- `spec/requests/api/v1/accounts/agent_bots/flows_controller_spec.rb`
- `spec/models/bot_flow_spec.rb`

**Services:**
- `app/services/apple_messages_for_business/flow_compiler_service.rb`
- `app/services/apple_messages_for_business/flow_diff_service.rb`

---

## Notes

1. **Single Published Version**: Only one version per bot can be published at a time
2. **Version Numbering**: Versions are auto-incremented integers (1, 2, 3...)
3. **Version Tags**: Custom tags are optional but must be unique per bot
4. **Parent-Child Relationships**: Versions form a tree structure via `parent_flow_id`
5. **Restore Creates New Version**: Restoring doesn't modify existing versions
6. **Compile on Publish**: Publishing automatically compiles the flow to bot_config
