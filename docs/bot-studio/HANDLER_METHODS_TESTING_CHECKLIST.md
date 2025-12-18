# Handler Methods System - Testing Checklist

## Pre-Testing Setup

### 1. Restart Development Server

**CRITICAL**: The Rails server must be restarted to load the latest authorization code changes.

```bash
# Stop and restart the dev server
./script/dev-server.sh restart

# Wait for server to fully start (check for "Listening on...")
# Then hard refresh browser: Cmd+Shift+R (macOS) or Ctrl+Shift+R (Windows)
```

**Why**: The authorization fixes won't take effect until the server reloads the controller and policy code.

### 2. Verify Files Exist

```bash
# Backend files
ls -lh app/controllers/api/v1/accounts/agent_bots/handler_methods_controller.rb
ls -lh app/policies/agent_bot_policy.rb

# Frontend files
ls -lh app/javascript/dashboard/routes/dashboard/settings/agentBots/components/HandlerMethodSelector.vue
ls -lh app/javascript/dashboard/routes/dashboard/settings/agentBots/composables/useHandlerMethods.js
ls -lh app/javascript/dashboard/routes/dashboard/settings/agentBots/components/editors/StateNodeEditor.vue

# API client
grep -A 20 "Handler Methods" app/javascript/dashboard/api/agentBots.js

# Translations
grep -A 5 '"HANDLER_METHODS"' app/javascript/dashboard/i18n/locale/en/agentBots.json
```

**Expected**: All files should exist with recent modification dates.

## Backend API Testing

### Test 1: List Handler Methods

```bash
# Start Rails console
rails console

# Get account and bot
account = Account.first
bot = account.agent_bots.find_by(bot_type: 'AcousticHouseBotService')

# Test handler_methods_metadata exists
puts AcousticHouseBotService.handler_methods_metadata.keys.inspect
```

**Expected Output**: Array of handler method names like `[:handle_welcome, :handle_menu, ...]`

### Test 2: API Endpoints via cURL

```bash
# Set variables (adjust IDs as needed)
ACCOUNT_ID=1
BOT_ID=15

# Get auth token from browser developer tools:
# 1. Open DevTools → Network tab
# 2. Look for any API request
# 3. Copy the 'access-token', 'client', and 'uid' headers

ACCESS_TOKEN="your-access-token-here"
CLIENT="your-client-here"
UID="your-uid-here"

# Test list endpoint
curl -H "access-token: $ACCESS_TOKEN" \
     -H "client: $CLIENT" \
     -H "uid: $UID" \
     "https://liquid-m3-pro.tail367da4.ts.net/api/v1/accounts/$ACCOUNT_ID/agent_bots/$BOT_ID/handler_methods" \
     | jq

# Test search endpoint
curl -H "access-token: $ACCESS_TOKEN" \
     -H "client: $CLIENT" \
     -H "uid: $UID" \
     "https://liquid-m3-pro.tail367da4.ts.net/api/v1/accounts/$ACCOUNT_ID/agent_bots/$BOT_ID/handler_methods/search?q=welcome" \
     | jq

# Test validate endpoint
curl -X POST \
     -H "access-token: $ACCESS_TOKEN" \
     -H "client: $CLIENT" \
     -H "uid: $UID" \
     -H "Content-Type: application/json" \
     -d '{"method_name":"handle_welcome","handler_type":"state"}' \
     "https://liquid-m3-pro.tail367da4.ts.net/api/v1/accounts/$ACCOUNT_ID/agent_bots/$BOT_ID/handler_methods/validate" \
     | jq
```

**Expected Responses**:

**List** (200 OK):
```json
{
  "handler_methods": [
    {
      "method_name": "handle_welcome",
      "handler_type": "state",
      "display_name": "Welcome Handler",
      "description": "...",
      "category": "onboarding",
      "status": "stable"
    }
  ],
  "meta": {
    "total": 45,
    "categories": ["onboarding", "navigation"],
    "handler_types": ["state", "keyword"]
  }
}
```

**Search** (200 OK):
```json
{
  "results": [
    {
      "method_name": "handle_welcome",
      "display_name": "Welcome Handler",
      "match_score": 0.95,
      "match_reason": "Matches in method name"
    }
  ],
  "meta": {
    "query": "welcome",
    "total_results": 1
  }
}
```

**Validate** (200 OK):
```json
{
  "valid": true,
  "errors": [],
  "warnings": []
}
```

### Test 3: Authorization (Should NOT Return 401)

```bash
# Check Rails logs for authorization errors
tail -50 log/development.log | grep -i "401\|unauthorized\|pundit"
```

**Expected**: No "401" or "Unauthorized" errors after the API calls above.

## Frontend UI Testing

### Test 4: Component Visibility

1. **Navigate to Bot Studio**:
   - Go to https://liquid-m3-pro.tail367da4.ts.net/app/accounts/1/settings/agent-bots/15/studio
   - Wait for Bot Studio to load

2. **Add State Node**:
   - Drag "State" node from palette to canvas
   - Click on the new State node

3. **Verify HandlerMethodSelector Appears**:
   - Node config panel should open on the right
   - Look for "Handler Method" field
   - Should see an **input field with dropdown icon** (not plain text input)

**Expected**:
- ✅ Input field has autocomplete styling
- ✅ Placeholder text: "Search handler methods..."
- ✅ Help text below: "The method name in AcousticHouseBotService..."
- ❌ NOT a plain `<input type="text">` field

### Test 5: Autocomplete Search

1. **Type in Handler Method Field**:
   - Click in the handler method field
   - Type: "welcome"

2. **Verify Dropdown Appears**:
   - Dropdown menu should appear below input
   - Should show matching handlers

**Expected Results**:
```
┌─────────────────────────────────────────┐
│ handle_welcome                    state │
│ Welcome Handler                         │
│ Handles initial welcome state           │
│ ● stable                                │
├─────────────────────────────────────────┤
│ handle_welcome_back               state │
│ Welcome Back Handler                    │
│ ...                                     │
└─────────────────────────────────────────┘
```

Each result should show:
- ✅ Method name (e.g., "handle_welcome")
- ✅ Type badge (e.g., "state" in blue)
- ✅ Display name (e.g., "Welcome Handler")
- ✅ Description
- ✅ Status indicator (● stable / ⚠ experimental / ⚠ deprecated)

### Test 6: Selection and Auto-Fill

1. **Select a Handler**:
   - Click on "handle_welcome" in dropdown
   - Dropdown should close

2. **Verify Auto-Fill**:
   - Check "Label" field → Should auto-fill with "Welcome Handler"
   - Check "Description" field → Should auto-fill with handler description

**Expected Behavior**:
- ✅ Handler method field shows "handle_welcome"
- ✅ Label field auto-filled (if was empty)
- ✅ Description field auto-filled (if was empty)
- ✅ No errors in browser console

### Test 7: Validation

1. **Type Invalid Handler**:
   - Clear the handler method field
   - Type: "invalid_handler_xyz"
   - Press Tab (blur the field)

2. **Verify Error Message**:
   - Should see validation error below field
   - Error should be red/warning color

**Expected Error**: "Handler method not found" or similar

3. **Check for Suggestions**:
   - If you typed "handle_welcom" (missing 'e')
   - Should suggest: "Did you mean 'handle_welcome'?"

### Test 8: Real-Time Search

1. **Type Partial Name**:
   - Type: "hand"
   - Wait 300ms (debounce delay)

2. **Verify Search Results**:
   - Dropdown should show ALL handlers starting with "handle_"
   - Results should be sorted by relevance (match_score)

3. **Continue Typing**:
   - Add "le_menu"
   - Dropdown should update to show only "handle_menu" matches

**Expected**: Smooth, debounced search with no lag or stuttering

### Test 9: Browser Console Checks

**Open Browser DevTools** (F12 or Cmd+Option+I):

1. **Console Tab**:
   - Should see NO errors
   - Should see NO 401 Unauthorized warnings
   - Should see NO 500 Internal Server errors

2. **Network Tab**:
   - Filter: "handler_methods"
   - Try typing in handler field
   - Watch for API calls

**Expected Network Calls**:
```
GET /api/v1/accounts/1/agent_bots/15/handler_methods/search?q=welcome
Status: 200 OK
Response: { results: [...] }

POST /api/v1/accounts/1/agent_bots/15/handler_methods/validate
Status: 200 OK
Response: { valid: true, errors: [], warnings: [] }
```

3. **Verify NO 401 Errors**:
   ```
   ❌ Should NOT see:
   Failed to load resource: the server responded with a status of 401 () (validate, line 0)
   Failed to load resource: the server responded with a status of 401 () (search, line 0)
   ```

## Automated Testing

### Backend Tests

```bash
# Run handler methods controller tests
bundle exec rspec spec/controllers/api/v1/accounts/agent_bots/handler_methods_controller_spec.rb

# Run policy tests
bundle exec rspec spec/policies/agent_bot_policy_spec.rb

# Run all bot-related tests
bundle exec rspec spec/controllers/api/v1/accounts/agent_bots/
bundle exec rspec spec/services/apple_messages_for_business/
```

**Expected**: All tests pass (green)

### Frontend Tests

```bash
# Run all frontend tests
pnpm test

# Run specific component test
pnpm test HandlerMethodSelector

# Watch mode for continuous testing
pnpm test:watch
```

**Expected**: All tests pass

### Linting

```bash
# Check Ruby code style
bundle exec rubocop app/controllers/api/v1/accounts/agent_bots/handler_methods_controller.rb
bundle exec rubocop app/policies/agent_bot_policy.rb

# Check JavaScript/Vue code style
pnpm eslint app/javascript/dashboard/routes/dashboard/settings/agentBots/components/HandlerMethodSelector.vue
pnpm eslint app/javascript/dashboard/api/agentBots.js
```

**Expected**: No offenses detected

## Integration Testing

### Test 10: End-to-End Flow

**Complete Bot Flow with Handler Methods**:

1. **Create New Flow**:
   - Navigate to Bot Studio
   - Create fresh flow (or import existing)

2. **Add State Nodes**:
   - Add 3 State nodes to canvas
   - Name them: "Welcome", "Main Menu", "Goodbye"

3. **Assign Handlers**:
   - Welcome node → Search and select "handle_welcome"
   - Main Menu node → Search and select "handle_menu"
   - Goodbye node → Search and select "handle_goodbye"

4. **Verify Auto-Fill**:
   - Each node should have label and description auto-filled
   - Each handler should validate successfully (green checkmark)

5. **Connect Nodes**:
   - Draw edges: Welcome → Main Menu → Goodbye

6. **Validate Flow**:
   - Click "Validate" button in toolbar
   - Should see: "✅ Valid Flow" or minimal warnings

7. **Save Flow**:
   - Click "Save Flow"
   - Should see success message
   - Flow should persist to database

**Expected**: Complete flow creation with no errors

### Test 11: Cross-Browser Testing

Test in multiple browsers:
- ✅ Chrome/Edge (Chromium)
- ✅ Firefox
- ✅ Safari (if on macOS)

**Verify in Each Browser**:
- Autocomplete dropdown works
- Search is responsive
- Validation messages appear
- No console errors
- No 401 authorization errors

## Troubleshooting Failed Tests

### If You See 401 Errors

**Problem**: API returns 401 Unauthorized

**Solutions**:
1. Verify server was restarted: `./script/dev-server.sh restart`
2. Check policy has search? method: `grep "def search?" app/policies/agent_bot_policy.rb`
3. Check controller authorization: `grep "authorize @agent_bot" app/controllers/.../handler_methods_controller.rb`
4. Hard refresh browser: Cmd+Shift+R
5. Check Rails logs: `tail -50 log/development.log`

### If Component Doesn't Appear

**Problem**: Still seeing plain text input

**Solutions**:
1. Verify file exists: `ls -lh .../HandlerMethodSelector.vue`
2. Check import in StateNodeEditor: `grep HandlerMethodSelector .../StateNodeEditor.vue`
3. Restart dev server (Vite may not detect new files)
4. Clear browser cache
5. Check for JavaScript errors in console

### If Search Returns Nothing

**Problem**: Typing returns "No handler methods found"

**Solutions**:
1. Check service has metadata:
   ```bash
   rails runner "puts AcousticHouseBotService.handler_methods_metadata.keys.length"
   ```
2. Verify botId is passed to component
3. Check API endpoint returns results (via cURL test above)
4. Check search query is at least 2 characters

### If Auto-Fill Doesn't Work

**Problem**: Label and description don't auto-fill

**Solutions**:
1. Check handler metadata has display_name and description
2. Verify @handler-selected event is wired up in StateNodeEditor
3. Check handleHandlerSelected function is defined
4. Look for JavaScript errors in console

## Success Criteria

### All Tests Pass If:

✅ **Backend**:
- All API endpoints return 200 OK (not 401)
- Policy methods exist and return true for admin/agent
- Controller authorization uses `authorize @agent_bot`
- Handler methods metadata is accessible

✅ **Frontend**:
- HandlerMethodSelector component appears (not plain text input)
- Autocomplete dropdown shows on typing
- Search returns relevant results
- Selection updates modelValue
- Validation shows errors/warnings
- Auto-fill populates label and description

✅ **Integration**:
- Can create complete flow with handler methods
- Can save and load flows
- No console errors
- No 401 authorization errors
- Smooth user experience

## Next Steps After Testing

Once all tests pass:

1. **Commit Changes**:
   ```bash
   git add .
   git commit -m "feat: Add handler methods management system with autocomplete selector

   - Implemented HandlerMethodsController with search, validate, list endpoints
   - Added AgentBotPolicy methods for authorization
   - Built HandlerMethodSelector Vue component with autocomplete
   - Created useHandlerMethods composable for API integration
   - Integrated into StateNodeEditor with auto-fill functionality
   - Added comprehensive i18n translations
   - Includes full documentation and testing guides"
   ```

2. **Push to Remote**:
   ```bash
   git push origin amb-beta-bot-studio
   ```

3. **Optional - Deploy to Production**:
   ```bash
   # Deploy backend changes
   ./script/deploy-backend-enhanced.sh

   # OR full rebuild if needed
   ./script/quick_rebuild.sh
   ```

4. **Mark Todo Complete**:
   - ✅ Test all components and update documentation

## Documentation Created

- ✅ **Integration Guide**: `docs/bot-studio/HANDLER_METHODS_INTEGRATION_GUIDE.md`
- ✅ **Testing Checklist**: `docs/bot-studio/HANDLER_METHODS_TESTING_CHECKLIST.md` (this file)
- ✅ **Reference Documentation**: Inline comments in all source files
