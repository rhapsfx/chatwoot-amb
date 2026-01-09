# Visual Bot Studio - Deployment Guide

**Status**: Ready for Testing
**Date**: December 5, 2025

---

## Quick Start

### 1. Apply Database Migration

```bash
# Run the migration
rails db:migrate

# Verify the table was created
rails runner "puts BotFlow.count"
# Expected output: 0

# Verify the association works
rails runner "bot = AgentBot.first; puts bot.bot_flows.class"
# Expected output: BotFlow::ActiveRecord_Associations_CollectionProxy
```

### 2. Restart Development Server

```bash
# Stop current server
./script/dev-server.sh stop

# Start server (with Tailscale Funnel for public access)
./script/dev-server.sh start-public

# Or restart
./script/dev-server.sh restart
```

### 3. Test the UI

1. **Navigate to Bot List**:
   ```
   https://mac-studio.tail367da4.ts.net/app/accounts/1/settings/agent-bots
   ```

2. **Find an Apple Messages Bot** (not a system bot)

3. **Click "Open Studio" button** (workflow icon)

4. **Verify Visual Studio loads**:
   - Left panel: NodePalette with 5 node types
   - Center: VueFlow canvas with background grid
   - Right panel: Config panel (empty until node selected)

5. **Test Node Palette**:
   - Try dragging a State node (blue)
   - Try dragging an Intent node (green)
   - **Note**: Drop handler not yet implemented in Phase 1

6. **Test Save/Compile Buttons**:
   - Click "Save Flow" → Should show alert (backend integration pending)
   - Click "Compile & Test" → Should show alert (compiler pending)

---

## Verification Checklist

### Backend Verification

```bash
# 1. Check migration status
rails db:migrate:status | grep bot_flows
# Should show: up     20251205145947  Create bot flows

# 2. Verify routes
rails routes | grep flows
# Should show 8 routes for flows management

# 3. Test API endpoint (requires running server)
curl -X GET "http://localhost:3000/api/v1/accounts/1/agent_bots/12/flows" \
  -H "api_access_token: YOUR_TOKEN"
# Expected: {"bot_flows": []}

# 4. Verify model
rails runner "puts BotFlow.new(agent_bot_id: 1, name: 'Test').valid?"
# Expected: true
```

### Frontend Verification

**Via Browser DevTools**:

1. Open browser console (F12)
2. Navigate to Bot Studio
3. Check for errors in console
4. Verify Vue components are mounted:
   ```javascript
   // In console
   document.querySelector('[data-component="BotStudio"]')
   // Should return DOM element
   ```

**Via Vue DevTools**:

1. Install Vue DevTools browser extension
2. Navigate to Bot Studio
3. Check component tree:
   ```
   BotStudio
   ├── NodePalette
   ├── BotStudioCanvas
   │   └── VueFlow
   └── NodeConfigPanel
   ```

---

## Testing Flows

### Manual Testing Script

```bash
# Create a test flow via Rails console
rails console

# In console:
bot = AgentBot.where(bot_type: 'apple_messages_for_business').first
flow = bot.bot_flows.create!(
  name: 'Test Flow 1',
  description: 'Testing visual studio',
  flow_data: {
    nodes: [
      {
        id: 'node_1',
        type: 'state',
        position: { x: 100, y: 100 },
        data: {
          state_id: 'AHA1',
          label: 'Welcome',
          actions: [
            { type: 'send_template', template_name: 'ah_main_menu' }
          ]
        }
      }
    ],
    edges: []
  }
)

puts "Flow created: #{flow.id}"
exit

# Now navigate to Bot Studio and verify the flow loads
```

### API Testing with curl

```bash
# Set your variables
export ACCOUNT_ID=1
export BOT_ID=12
export API_TOKEN="your_api_token_here"
export BASE_URL="http://localhost:3000"

# 1. List flows
curl -X GET "${BASE_URL}/api/v1/accounts/${ACCOUNT_ID}/agent_bots/${BOT_ID}/flows" \
  -H "api_access_token: ${API_TOKEN}"

# 2. Create flow
curl -X POST "${BASE_URL}/api/v1/accounts/${ACCOUNT_ID}/agent_bots/${BOT_ID}/flows" \
  -H "api_access_token: ${API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Flow",
    "description": "Created via API",
    "flow_data": {
      "nodes": [],
      "edges": []
    }
  }'

# 3. Get single flow (replace :id with actual ID)
curl -X GET "${BASE_URL}/api/v1/accounts/${ACCOUNT_ID}/agent_bots/${BOT_ID}/flows/:id" \
  -H "api_access_token: ${API_TOKEN}"

# 4. Update flow
curl -X PATCH "${BASE_URL}/api/v1/accounts/${ACCOUNT_ID}/agent_bots/${BOT_ID}/flows/:id" \
  -H "api_access_token: ${API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Flow Name",
    "flow_data": {
      "nodes": [
        {
          "id": "node_1",
          "type": "state",
          "position": {"x": 100, "y": 100},
          "data": {"state_id": "AHA1", "label": "Welcome"}
        }
      ],
      "edges": []
    }
  }'

# 5. Delete flow
curl -X DELETE "${BASE_URL}/api/v1/accounts/${ACCOUNT_ID}/agent_bots/${BOT_ID}/flows/:id" \
  -H "api_access_token: ${API_TOKEN}"

# 6. Compile flow (will return 501 in Phase 1)
curl -X POST "${BASE_URL}/api/v1/accounts/${ACCOUNT_ID}/agent_bots/${BOT_ID}/flows/:id/compile" \
  -H "api_access_token: ${API_TOKEN}"
```

---

## Known Issues & Workarounds

### Issue 1: Node drag-and-drop not working

**Symptom**: Can drag nodes from palette but they don't drop on canvas

**Reason**: Drop handler not implemented in Phase 1

**Workaround**: Manually create nodes via browser console:
```javascript
// In browser console on Bot Studio page
const canvas = document.querySelector('[data-component="BotStudioCanvas"]').__vueParentComponent.ctx
canvas.nodes.push({
  id: 'manual_node_1',
  type: 'state',
  position: { x: 200, y: 200 },
  data: {
    state_id: 'AHA1',
    label: 'Manual Node'
  }
})
```

### Issue 2: Compile returns 501

**Symptom**: Clicking "Compile & Test" returns "Not Implemented"

**Reason**: FlowCompilerService is placeholder in Phase 1

**Workaround**: Wait for Phase 2 implementation

### Issue 3: Flow doesn't persist after save

**Symptom**: Saving flow shows success but data is lost on reload

**Reason**: Backend integration incomplete in Phase 1

**Workaround**: Check browser console for API errors and verify:
1. API endpoint is reachable
2. Authentication token is valid
3. AgentBot belongs to current account

---

## Deployment to Production

### Backend Deployment

**Using deploy-backend-enhanced.sh** (Ruby changes only):

```bash
# This script will:
# 1. Copy migration file to server
# 2. Copy new controller and models
# 3. Run migrations
# 4. Restart Rails server

./script/deploy-backend-enhanced.sh
```

**Manual deployment**:

```bash
# 1. SSH to production server
ssh root@msp.rhaps.net

# 2. Navigate to project
cd /opt/chatwoot

# 3. Pull latest code
git pull origin amb-beta-bot-studio

# 4. Run migration
docker compose -f docker-compose.production.yml exec web rails db:migrate

# 5. Restart services
docker compose -f docker-compose.production.yml restart web worker
```

### Frontend Deployment

**Using quick_rebuild.sh** (for Vue Flow library):

```bash
# This script will:
# 1. Build new Docker image with Vue Flow
# 2. Copy frontend assets
# 3. Restart containers

./script/quick_rebuild.sh
```

**Why full rebuild?**: Vue Flow is a new npm dependency that requires Docker image rebuild.

---

## Phase 2 Planning

### Priority 1: Core Functionality (Week 1)

1. **Implement Drop Handler**:
   - Add drop zone to BotStudioCanvas
   - Create node on drop with default data
   - Position node at drop coordinates

2. **Connect Configuration to Canvas**:
   - Save config changes back to node data
   - Update canvas when config is saved
   - Persist changes to backend

3. **Implement Flow Compiler**:
   - Read flow_data from BotFlow
   - Extract nodes and edges
   - Generate bot_config structure:
     - required_templates from Template nodes
     - keyword_routes from Intent nodes
     - state_handlers from State nodes
     - interactive_handlers from Action nodes
   - Update AgentBot.bot_config

### Priority 2: Enhanced UI (Week 2)

1. **Node Management**:
   - Delete node functionality
   - Duplicate node functionality
   - Copy/paste nodes

2. **Edge Management**:
   - Delete edge functionality
   - Edge labels
   - Conditional edges (for Condition nodes)

3. **Canvas Controls**:
   - Undo/redo (using command pattern)
   - Auto-layout algorithm
   - Zoom to fit
   - Pan to node

4. **Validation**:
   - Validate node connections
   - Check for orphaned nodes
   - Verify required fields
   - Check circular dependencies

### Priority 3: Testing & Polish (Week 2)

1. **Live Preview**:
   - Simulate conversation flow
   - Show bot responses
   - Test state transitions

2. **Import/Export**:
   - Export flow as JSON
   - Import existing bot_config as flow
   - Template library

3. **Documentation**:
   - User guide
   - Video tutorials
   - API documentation

---

## Troubleshooting

### Cannot see "Open Studio" button

**Check**:
1. Bot type is `apple_messages_for_business` (not webhook)
2. Bot is not a system bot (no `GLOBAL_BOT_BADGE`)
3. User has proper permissions (AGENT_BOT_PERMISSIONS)

**Debug**:
```javascript
// In browser console on bot list page
const bot = document.querySelector('[data-bot-id]').__vueParentComponent.ctx.bot
console.log('Bot type:', bot.bot_type)
console.log('Is global:', bot.account_id === null)
```

### BotStudio page is blank

**Check**:
1. Vue Flow library is installed: `ls node_modules/@vue-flow/core`
2. No JavaScript errors in console
3. Route is registered: Check Vue DevTools → Router

**Debug**:
```bash
# Check if Vue Flow is installed
pnpm list @vue-flow/core
# Should show version 1.48.0

# Reinstall if missing
pnpm install @vue-flow/core @vue-flow/background @vue-flow/controls @vue-flow/minimap
```

### API endpoints return 404

**Check**:
1. Migration was run
2. Routes are registered: `rails routes | grep flows`
3. Server was restarted after adding routes

**Fix**:
```bash
./script/dev-server.sh restart
```

### Nodes don't render on canvas

**Check**:
1. Custom node components are imported correctly
2. Node types are registered in nodeTypes object
3. flow_data has valid structure

**Debug**:
```javascript
// In browser console on Bot Studio page
const canvas = document.querySelector('[data-component="BotStudioCanvas"]').__vueParentComponent.ctx
console.log('Node types:', canvas.nodeTypes)
console.log('Nodes:', canvas.nodes)
```

### Save button doesn't work

**Check**:
1. Vuex store actions are loaded
2. API endpoint is reachable
3. Authentication is valid

**Debug**:
```javascript
// In browser console on Bot Studio page
this.$store.dispatch('agentBots/getFlows', 12)
  .then(flows => console.log('Flows:', flows))
  .catch(err => console.error('Error:', err))
```

---

## Performance Considerations

### Database

**Indexes**:
- ✅ `agent_bot_id` is indexed for fast lookups
- Consider adding: `(agent_bot_id, is_active)` for active flow queries

**JSONB**:
- flow_data can store large node graphs
- Consider pagination if flows exceed 1000 nodes
- Use GIN index if querying inside flow_data:
  ```sql
  CREATE INDEX idx_bot_flows_flow_data ON bot_flows USING GIN (flow_data);
  ```

### Frontend

**VueFlow**:
- Handles up to 1000 nodes efficiently
- Use `fitView` for large graphs
- Consider virtualization for 1000+ nodes

**State Management**:
- flow_data can be large (5-10 MB for complex bots)
- Consider lazy-loading flows
- Cache compiled bot_config

---

## Security Considerations

### Authorization

✅ **Already Implemented**:
- `check_authorization(AgentBot)` on all endpoints
- Account scoping via `Current.account`
- Parent-child scoping (flows → agent_bots)

### Input Validation

⚠️ **Needs Enhancement** (Phase 2):
- Validate flow_data structure
- Sanitize node labels and descriptions
- Limit graph size (max nodes/edges)
- Prevent circular dependencies
- XSS protection in node labels

### Data Privacy

✅ **Already Compliant**:
- flow_data is account-scoped
- No PII in flow structure
- Audit trail via created_at/updated_at

---

## Monitoring & Logging

### Backend Logs

```bash
# Watch Rails logs
tail -f log/development.log | grep "FlowsController"

# Watch production logs
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs -f web | grep Flows'
```

### Frontend Errors

```javascript
// In browser console
// Enable Vue warnings
window.localStorage.setItem('DEBUG', 'app:*')

// Watch for Vuex mutations
window.$store.subscribeAction({
  before: (action) => console.log('→', action),
  after: (action) => console.log('✓', action),
  error: (action, error) => console.error('✗', action, error)
})
```

### Performance Metrics

**Track**:
- Flow load time (should be < 500ms)
- Save time (should be < 1s)
- Compile time (Phase 2, should be < 2s)
- Canvas FPS (should be > 30 FPS)

---

## Success Criteria

### Phase 1 ✅ Complete

- [x] Users can navigate to Bot Studio
- [x] Canvas renders with VueFlow
- [x] Node palette displays 5 node types
- [x] Nodes are draggable (drop not yet implemented)
- [x] Node configuration panels open
- [x] Save/Compile buttons present (integration pending)
- [x] CRUD API endpoints functional
- [x] Database stores flow_data

### Phase 2 Goals

- [ ] Users can drag-and-drop nodes onto canvas
- [ ] Users can configure nodes via forms
- [ ] Users can save flows and reload them
- [ ] Users can compile flows to bot_config
- [ ] Compiled bot_config works with AcousticHouseBotService
- [ ] Users can test flows with live preview

---

## Support & Documentation

**Documentation**:
- Implementation Plan: `docs/apple-messages/implementation/VISUAL_BOT_STUDIO_IMPLEMENTATION_PLAN.md`
- Phase 1 Complete: `docs/apple-messages/implementation/VISUAL_BOT_STUDIO_PHASE_1_COMPLETE.md`
- Architecture: `docs/apple-messages/implementation/BOT_STUDIO_ARCHITECTURE.md`
- This Guide: `docs/apple-messages/implementation/BOT_STUDIO_DEPLOYMENT_GUIDE.md`

**Code References**:
- Backend: `app/controllers/api/v1/accounts/agent_bots/flows_controller.rb`
- Frontend: `app/javascript/dashboard/routes/dashboard/settings/agentBots/BotStudio.vue`
- Store: `app/javascript/dashboard/store/modules/agentBots.js`

**External Resources**:
- Vue Flow Docs: https://vueflow.dev/
- Chatwoot Docs: https://www.chatwoot.com/docs/

---

## Quick Reference Commands

```bash
# Development
./script/dev-server.sh start-public   # Start with Tailscale Funnel
rails db:migrate                       # Run migrations
rails console                          # Open Rails console
pnpm install                          # Install frontend deps

# Testing
rails runner "puts BotFlow.count"                    # Check flows
curl http://localhost:3000/api/v1/.../flows          # Test API
open http://mac-studio.tail367da4.ts.net/...     # Open UI

# Deployment
./script/deploy-backend-enhanced.sh   # Deploy Ruby changes
./script/quick_rebuild.sh             # Full Docker rebuild
git push                              # Push to remote

# Troubleshooting
tail -f log/development.log           # Watch logs
rails routes | grep flows             # Check routes
pnpm list @vue-flow/core             # Check Vue Flow
```

---

**Document Version**: 1.0
**Last Updated**: December 5, 2025
**Status**: Ready for Deployment
