# Handler Methods 401 Fix - Verification & Testing

**Date**: December 18, 2025
**Status**: ✅ **FIXED** - Ready for testing

## Changes Applied

### Primary Fix: HandlerMethodSelector.vue

**File**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/HandlerMethodSelector.vue`

**✅ Changed line 5**:
```javascript
// BEFORE
import axios from 'axios';

// AFTER
import { getAxios } from 'dashboard/helper/axios';
```

**✅ Changed line 94** (search endpoint):
```javascript
// BEFORE
const response = await axios.get(url, { params });

// AFTER
const response = await getAxios().get(url, { params });
```

**✅ Changed line 178** (validate endpoint):
```javascript
// BEFORE
const response = await axios.post(url, params);

// AFTER
const response = await getAxios().post(url, params);
```

### Additional Fix: useHandlerMethods.js (for future consistency)

**File**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/composables/useHandlerMethods.js`

**Note**: This composable is NOT currently used in the application, but was fixed for consistency.

**✅ Changed**: Replaced all axios calls with `getAxios()` helper
- Line 104: `getAxios().get()` for list endpoint
- Line 151: `getAxios().get()` for show endpoint
- Line 212: `getAxios().get()` for search endpoint
- Line 223: `getAxios().isCancel()` for cancel check
- Line 269: `getAxios().post()` for validate endpoint

### Helper Created: axios.js

**File**: `app/javascript/dashboard/helper/axios.js`

**✅ Created**: New helper function to provide authenticated axios instance
- Returns `window.axios` which has auth headers configured
- Includes error handling if `window.axios` is not initialized
- Used by both HandlerMethodSelector.vue and useHandlerMethods.js

## What Was the Issue?

**Root Cause**: `HandlerMethodSelector.vue` was importing axios directly from the npm package:
```javascript
import axios from 'axios';  // ❌ No auth headers!
```

This axios instance does NOT have authentication headers (access-token, client, uid) configured.

**Correct Pattern**: Use the `getAxios()` helper which returns `window.axios`:
```javascript
import { getAxios } from 'dashboard/helper/axios';
const response = await getAxios().get(url);  // ✅ Has auth headers!
```

## Testing Instructions

### 1. Clear Vite Cache and Rebuild

**CRITICAL**: You must clear the Vite cache to ensure the new code is loaded.

```bash
# Stop the dev server if running
./script/dev-server.sh stop

# Clear Vite cache
rm -rf node_modules/.vite

# Restart dev server
./script/dev-server.sh start
```

**Alternative** (if dev server is running):
```bash
# In a separate terminal
rm -rf node_modules/.vite
# Then hard refresh browser (Cmd+Shift+R on macOS)
```

### 2. Hard Refresh Browser

**macOS**: `Cmd + Shift + R`
**Windows/Linux**: `Ctrl + Shift + R`

This ensures the browser loads the new JavaScript, not cached assets.

### 3. Test Handler Methods Flow

1. **Navigate to Bot Studio**:
   - Go to: Settings → Agent Bots → [Select a bot] → Visual Studio

2. **Add or Select a State Node**:
   - Drag "State" node from palette onto canvas (or click existing State node)
   - Click on the State node to open config panel

3. **Test Handler Method Selection**:
   - Find the "Handler Method" input field
   - Type at least 2 characters (e.g., "work", "menu", "help")
   - Autocomplete dropdown should appear

4. **Expected Results** ✅:
   - Autocomplete dropdown appears after typing 2+ characters
   - Search results show matching handlers with descriptions
   - Handler type badges visible (state, keyword, etc.)
   - Status badges visible (stable, experimental, deprecated)
   - NO 401 errors in browser console
   - NO authentication errors in Rails logs
   - Selection updates field correctly
   - Validation works on blur (green checkmark for valid handlers)

### 4. Verify in Browser Console (F12)

**Check Network Tab**:
```
GET /api/v1/accounts/1/agent_bots/15/handler_methods/search?q=work&limit=20
Status: 200 OK  ✅

POST /api/v1/accounts/1/agent_bots/15/handler_methods/validate
Status: 200 OK  ✅
```

**Check Request Headers** (should include):
```
access-token: [your token]
client: [your client id]
uid: [your email]
```

**Check Console Logs** (should see):
```
[Dashboard] window.axios configured: {exists: true, type: 'function', ...}
[getAxios] Called. window.axios status: {exists: true, type: 'function', ...}
```

**Should NOT see**:
```
❌ 401 (Unauthorized)
❌ Failed to load resource
❌ window.axios is undefined
```

### 5. Verify in Rails Logs

```bash
tail -f log/development.log
```

**Expected** (when using handler methods):
```
Started GET "/api/v1/accounts/1/agent_bots/15/handler_methods/search?q=work"
Processing by Api::V1::Accounts::AgentBots::HandlerMethodsController#search
Current.user set to: 1 (user@example.com)
Completed 200 OK
```

**Should NOT see**:
```
Current.user set to:  ()  ← Empty user
Completed 401 Unauthorized
```

## Troubleshooting

### Issue: Still getting 401 errors

**Solution 1**: Vite cache not cleared
```bash
rm -rf node_modules/.vite
./script/dev-server.sh restart
# Hard refresh browser (Cmd+Shift+R)
```

**Solution 2**: Browser cache not cleared
```bash
# Open browser DevTools (F12)
# Right-click refresh button → "Empty Cache and Hard Reload"
```

**Solution 3**: Old service worker
```bash
# Open DevTools → Application tab → Service Workers
# Click "Unregister" if any service workers are registered
# Hard refresh browser
```

### Issue: "window.axios is undefined"

**Check**: This message appearing in console during app initialization is normal.
**Verify**: Check later in the console - it should be defined after app loads.

```javascript
// In browser console AFTER page loads:
console.log('window.axios exists?', typeof window.axios);
// Should output: "function"

// Check if it has auth headers:
console.log('Auth headers:', window.axios.defaults.headers.common);
// Should show: access-token, client, uid
```

If still undefined after page loads:
1. Check `app/javascript/entrypoints/dashboard.js` line 101 exists
2. Check no JavaScript errors preventing app initialization
3. Try a full page reload (not just hard refresh)

### Issue: Auth headers still not sent

**Verify** auth cookie exists:
```javascript
// In browser console:
document.cookie.split(';').find(c => c.includes('cw_d_session_info'))
```

Should return a cookie string. If null:
- Log out and log back in
- Check Rails session is working
- Verify Devise Token Auth is configured

## Success Criteria

✅ Search endpoint returns 200 OK with handler results
✅ Validate endpoint returns 200 OK with validation data
✅ User can type and see autocomplete suggestions
✅ User can select handlers from dropdown
✅ Validation shows green checkmark for valid handlers
✅ NO 401 errors in browser console
✅ NO authentication errors in Rails logs
✅ Request headers include access-token, client, uid
✅ Complete handler selection workflow works end-to-end

## Architecture Summary

**Component Chain**:
```
StateNodeEditor.vue (Bot Studio)
  └─ imports HandlerMethodSelector.vue
      └─ imports getAxios() from 'dashboard/helper/axios'
          └─ returns window.axios (configured with auth headers)
```

**Data Flow**:
```
1. User types in Handler Method field
2. HandlerMethodSelector.vue triggers search after 2+ characters
3. Calls getAxios().get('/handler_methods/search')
4. getAxios() returns window.axios (has auth headers)
5. Request sent with access-token, client, uid headers
6. Backend authenticates user via Devise Token Auth
7. HandlerMethodsController returns results (200 OK)
8. Dropdown displays matching handlers
```

## Related Files

**Fixed**:
- `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/HandlerMethodSelector.vue` (PRIMARY)
- `app/javascript/dashboard/routes/dashboard/settings/agentBots/composables/useHandlerMethods.js` (consistency)

**Created**:
- `app/javascript/dashboard/helper/axios.js` (helper function)

**Documentation**:
- `docs/bot-studio/HANDLER_METHODS_401_FIX.md` - Root cause analysis
- `docs/bot-studio/HANDLER_METHODS_INTEGRATION_GUIDE.md` - Integration guide
- `docs/bot-studio/HANDLER_METHODS_REFERENCE.md` - API reference

**Backend** (already working, no changes needed):
- `app/controllers/api/v1/accounts/agent_bots/handler_methods_controller.rb`
- `app/policies/agent_bot_policy.rb`

## Next Steps After Verification

Once verified working:

1. **Commit the fix**:
   ```bash
   git add app/javascript/dashboard/routes/dashboard/settings/agentBots/components/HandlerMethodSelector.vue
   git add app/javascript/dashboard/routes/dashboard/settings/agentBots/composables/useHandlerMethods.js
   git add app/javascript/dashboard/helper/axios.js
   git add docs/bot-studio/HANDLER_METHODS_401_FIX.md
   git add docs/bot-studio/HANDLER_METHODS_FIX_VERIFICATION.md
   git commit -m "Fix: Use window.axios in handler method components for authentication

   - Replace bare axios import with getAxios() helper in HandlerMethodSelector.vue
   - Also fix useHandlerMethods.js composable for consistency (not currently used)
   - Create getAxios() helper function to provide authenticated axios instance
   - Fix 401 Unauthorized errors on handler_methods search and validate endpoints
   - Update documentation with root cause analysis and testing guide"
   ```

2. **Optional**: Audit other components for the same issue
   ```bash
   # Find components that import axios directly
   grep -r "import axios from 'axios'" app/javascript/dashboard/routes/
   grep -r "import axios from 'axios'" app/javascript/dashboard/components/
   ```

   If found, check if they're making authenticated API calls and need the same fix.

---

**Fix Status**: ✅ **COMPLETE** - Ready for testing
**Estimated Test Time**: 5 minutes
**Risk Level**: Low (frontend-only change)
**Breaking Changes**: None (only fixing broken functionality)
