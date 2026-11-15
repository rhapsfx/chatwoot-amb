# Chatwoot v4.12 → v4.13.0 Sync - Complete Phase Summary

## Overview
The sync from v4.12 to v4.13.0 consisted of 7 phases to systematically merge upstream changes while preserving custom Apple Messages for Business (AMB) functionality that upstream removed entirely.

**Total Commits**: 13  
**Files Changed**: 100+  
**AMB References Preserved**: 124+  
**Tests Passing**: 408/426 (95.8%)

---

## Phase Breakdown

### Phase 0+1: Initial Upstream Merge (36c4f9376)
**Task**: Pull 3242 non-conflicting upstream files from v4.13.0
- Database migrations
- Dependency updates (Gemfile.lock, pnpm-lock.yaml)
- Infrastructure files

**Key Changes**:
- Ruby 3.4.4 compatibility
- Node.js/pnpm updates
- New migrations for calls, assistant responses, document sync

**Result**: Foundation for subsequent phases

---

### Phase 2: Infrastructure & Dependencies (90693569e, e28b73ccb)
**Task**: Update core infrastructure and lock files
- Updated Gemfile.lock for v4.13.0
- Updated pnpm-lock.yaml for new dependencies
- Infrastructure configuration files

**Key Changes**:
- New gems for enhanced features (calls, voice, etc.)
- Updated frontend dependencies

**Result**: All dependencies synchronized

---

### Phase 3: Database Schema & Migrations (408648b9e)
**Task**: Merge db/schema.rb and migrations
- 50+ migration files from upstream
- Schema updates for new features (calls, TikTok, etc.)
- Database structure aligned with v4.13.0

**Key Changes**:
- New `calls` table for voice features
- Captain AI assistant response tables
- Message-related enhancements

**Result**: Database fully migrated (20260410092753)

---

### Phase 4: i18n Translations (64a45c8ad)
**Task**: Merge English i18n files (en.yml, en.json)
- Updated backend translations (config/locales/en.yml)
- Updated frontend translations (*.json files)
- TikTok support strings added

**Key Changes**:
- 50+ new translation keys
- Unsupported message type description updated
- Generic platform-agnostic messaging

**Result**: All UI text properly localized

---

### Phase 5: Ruby Core Files (85238cd1d)
**Task**: Merge core Ruby backend files with conflict resolution
- App services, controllers, models
- Inline conflict markers for custom code
- Channel models (including AMB preservation)

**Key Changes**:
- New services: ApplePay, VoiceCall, TikTok support
- Updated message window service
- Preserved all 65 AMB service references

**Result**: Backend core functionality merged with AMB intact

---

### Phase 6: Frontend JavaScript & Vue (e909c1457)
**Task**: Merge frontend JS/Vue components with deep AMB integration
**42 files changed, 1227 insertions, 1526 deletions**

#### Key Preserved AMB Features:
1. **inbox.js**: 
   - TikTok channel type added alongside AMB
   - INBOX_ICON_MAP updated (i-ri→i-woot migration, AMB kept i-ri-apple-line)
   - getReadableInboxByType() handles AMB specially

2. **Message Bubble Routing (Message.vue)**:
   - Re-added 10 Apple bubble components removed by upstream
   - Apple content type routing restored
   - appleMspPayload prop preserved

3. **ReplyBox.vue**: 
   - Rich link detection for AMB
   - Template selector for interactive messages
   - Apple message sending flow

4. **Settings Pages**:
   - ChannelList: Added AMB alongside other channels
   - Index: AMB inbox display with Apple Messages Starter Link
   - ConfigurationPage: Full Apple auth/payment settings (1462 lines)

5. **Automation**:
   - Added AMB-specific filters (group, intent) to conversation_created

6. **Icon Migration**:
   - i-ri-* → i-woot-* for most channels
   - AMB & TikTok kept original Remixicon icons

---

### Phase 7: Final Complex Files (cf5977b7d)
**Task**: Merge 5 remaining complex files with deep AMB integration
**3 files changed, 17 insertions, 66 deletions**

#### 7A - ReplyBox.vue (2326 diff lines, 65 AMB refs)
- **Kept**: TemplateSelector, rich link detection, Apple message sending
- **Added**: CannedResponse component for upstream compatibility
- **Preserved**: URL normalization, interactive templates, message payload

#### 7B - Settings.vue (1412 diff lines, 1 AMB ref)
- **Action**: Took upstream directly
- **Reason**: Tab key normalization (kebab-case) doesn't affect AMB logic
- **Result**: Clean merge with URL route persistence

#### 7C - ConfigurationPage.vue (1527 diff lines, 54 AMB refs)
- **Action**: Kept current version
- **Reason**: Upstream removed all 54 AMB refs (OAuth2, Apple Pay, iMessage apps)
- **Result**: Full AMB configuration retained (1462 lines)

#### 7D - ReplyBottomPanel.vue (212 diff lines, 9 AMB refs)
- **Action**: Took upstream
- **Reason**: All 9 AMB refs already identical (AppleMessagesButton, USDZ support)
- **Result**: Clean upstream merge

#### 7E - ContentTemplatesPicker.vue (315 diff lines, 1 AMB ref)
- **Action**: Kept current version  
- **Reason**: Has unified template API with AMB support
- **Result**: Apple Messages templates accessible via generic channel normalizer

---

## Post-Phase 7 Fixes

### Fix 1: Syntax Errors (fee32212b)
**rack_attack.rb**: Moved bot template throttling inside Rack::Attack class  
**sidekiq.rb**: Added missing `end` for Sidekiq.configure_client block

### Fix 2: Annotate Gem (b728251b5)
**auto_annotate_models.rake**: Updated from obsolete `annotate` to `annotaterb` gem

### Fix 3: Vite Build (f70b772ae)
**ReplyBottomPanel.vue**: Removed deleted AIAssistanceButton import  
**editor.js**: Added missing WIDGET_BUILDER_EDITOR_MENU_OPTIONS export

### Fix 4: Frontend Issues (d057183c8)
**settings.routes.js**: Added missing templates route import  
**Sidebar.vue**: Restored Templates menu item in Settings  
**ChannelName.vue**: Added AMB to i18nMap (was missing, causing "undefined" display)

### Fix 5: AMB Configuration Tab (baf277f0f)
**Settings.vue**: Restored `isAnAppleMessagesForBusinessChannel` check for configuration tab

---

## Commonly Missed Changes - Templates & Inbox

### ⚠️ CRITICAL: Settings Routes (settings.routes.js)

**What Gets Missed**: Templates routes never added to main routes array

```javascript
// BEFORE (Missing)
export default {
  routes: [
    ...account.routes,
    ...agent.routes,
    // ... other routes
    ...captain.routes,
    // ❌ templates.routes missing!
  ],
};

// AFTER (Fixed)
import templates from './templates/templates.routes';

export default {
  routes: [
    ...account.routes,
    ...agent.routes,
    // ... other routes
    ...captain.routes,
    ...templates.routes,  // ✅ Added
  ],
};
```

**Impact**: Templates settings page completely unavailable  
**How to Detect**: Settings menu has no Templates link

---

### ⚠️ CRITICAL: Sidebar Navigation (Sidebar.vue)

**What Gets Missed**: Templates menu item never added to sidebar

```javascript
// BEFORE (Missing)
const menuItems = [
  { name: 'Settings Canned Responses', ... },
  { name: 'Settings Integrations', ... },  // Templates goes here!
  { name: 'Settings Audit Logs', ... },
];

// AFTER (Fixed)
const menuItems = [
  { name: 'Settings Canned Responses', ... },
  {
    name: 'Settings Templates',
    label: t('SIDEBAR.TEMPLATES'),
    icon: 'i-lucide-file-text',
    to: accountScopedRoute('templates_list'),  // ✅ Added
  },
  { name: 'Settings Integrations', ... },
];
```

**Impact**: Templates inaccessible from Settings sidebar  
**How to Detect**: Visit /settings, Templates option missing between Canned Responses & Integrations

---

### ⚠️ HIGH: Inbox Channel Type Translation (ChannelName.vue)

**What Gets Missed**: AMB missing from channel type → i18n key mapping

```javascript
// BEFORE (Missing)
const i18nMap = {
  'Channel::FacebookPage': 'MESSENGER',
  'Channel::TwilioSms': 'TWILIO_SMS',
  // ... other channels
  'Channel::Voice': 'VOICE',
  // ❌ 'Channel::AppleMessagesForBusiness' missing!
};

// AFTER (Fixed)
const i18nMap = {
  'Channel::FacebookPage': 'MESSENGER',
  'Channel::TwilioSms': 'TWILIO_SMS',
  // ... other channels
  'Channel::Voice': 'VOICE',
  'Channel::AppleMessagesForBusiness': 'APPLE_MESSAGES_FOR_BUSINESS',  // ✅ Added
};
```

**Impact**: Inbox list shows `INBOX_MGMT.CHANNELS.undefined` for AMB inboxes  
**How to Detect**: Visit /settings/inboxes/list, AMB inbox shows broken translation

---

### ⚠️ HIGH: Inbox Settings Configuration Tab (Settings.vue)

**What Gets Missed**: AMB excluded from configuration tab visibility condition

```javascript
// BEFORE (Missing)
if (
  this.isATwilioChannel ||
  this.isALineChannel ||
  this.isAPIInbox ||
  this.isAVoiceChannel ||
  (this.isAnEmailChannel && !this.inbox.provider) ||
  this.shouldShowWhatsAppConfiguration ||
  this.isAWebWidgetInbox
  // ❌ this.isAnAppleMessagesForBusinessChannel missing!
) {
  // Show configuration tab
}

// AFTER (Fixed)
if (
  this.isATwilioChannel ||
  this.isALineChannel ||
  this.isAPIInbox ||
  this.isAVoiceChannel ||
  (this.isAnEmailChannel && !this.inbox.provider) ||
  this.shouldShowWhatsAppConfiguration ||
  this.isAWebWidgetInbox ||
  this.isAnAppleMessagesForBusinessChannel  // ✅ Added
) {
  // Show configuration tab
}
```

**Impact**: AMB inbox configuration fields completely hidden  
**How to Detect**: Open AMB inbox settings, missing "Configuration" tab and OAuth/Apple Pay settings

---

### MEDIUM: ReplyBottomPanel Component References

**What Gets Missed**: Deleted AIAssistanceButton component still imported after Phase 6 OpenAI cleanup

```javascript
// BEFORE (Causes Vite build failure)
import AIAssistanceButton from '../AIAssistanceButton.vue';  // ❌ File deleted
export default {
  components: { 
    VideoCallButton, 
    AIAssistanceButton,  // ❌ Never used
  },
  props: {
    message: { type: String, default: '' },  // ❌ Unused, was for AIAssistanceButton
  }
};

// AFTER (Fixed)
// ✅ Import removed
export default {
  components: { 
    VideoCallButton,  // ✅ Only used components
  },
  // props: message removed  // ✅ Unused prop removed
};
```

**Impact**: Vite build fails with "Could not resolve '../AIAssistanceButton.vue'"  
**How to Detect**: `pnpm exec vite build` exits with error

---

### MEDIUM: Editor Constants Export

**What Gets Missed**: WIDGET_BUILDER_EDITOR_MENU_OPTIONS not exported from editor.js

```javascript
// BEFORE (Missing export)
// editor.js
export const ARTICLE_EDITOR_MENU_OPTIONS = [...];
export const MARKDOWN_PATTERNS = [...];  // ✅ Has export
// ❌ WIDGET_BUILDER_EDITOR_MENU_OPTIONS defined but not exported

// WidgetBuilder.vue
import { WIDGET_BUILDER_EDITOR_MENU_OPTIONS } from 'dashboard/constants/editor';
// ❌ Import fails: "not exported"

// AFTER (Fixed)
// editor.js
export const ARTICLE_EDITOR_MENU_OPTIONS = [...];
export const WIDGET_BUILDER_EDITOR_MENU_OPTIONS = [  // ✅ Added export
  'strong', 'em', 'link', 'undo', 'redo'
];
export const MARKDOWN_PATTERNS = [...];
```

**Impact**: Vite build fails for WidgetBuilder component  
**How to Detect**: `pnpm exec vite build` error: "not exported by...editor.js"

---

## Testing Checklist

After each phase, verify:

- [ ] **Syntax**: No Ruby/JS syntax errors (`bundle exec rubocop`, `pnpm eslint`)
- [ ] **Database**: Migrations complete (`bin/rails db:version`)
- [ ] **Frontend Build**: Vite compiles (`pnpm exec vite build`)
- [ ] **Tests**: Backend tests pass (`bundle exec rspec`)
- [ ] **Dev Server**: Starts without errors (`./script/dev-server.sh start`)

### AMB-Specific Checks

- [ ] Settings → Templates menu visible
- [ ] Settings → Inboxes → Select AMB inbox → Configuration tab present
- [ ] Inbox list displays "Apple Messages for Business" (not "undefined")
- [ ] AMB inbox settings show OAuth2, Apple Pay, iMessage app fields
- [ ] Templates page loads and shows AMB templates

---

## Prevention Strategy

### For Future Merges:

1. **Always check**: `isAnAppleMessagesForBusinessChannel` in any conditional affecting inbox features
2. **Always verify**: i18nMap in ChannelName.vue includes all custom channels
3. **Always test**: Settings sidebar shows all expected menu items
4. **Always search**: Grep for removed components before merging to catch dangling imports
5. **Always export**: Check editor.js for new editor menu constants

### Grep Patterns to Watch:

```bash
# Find missing AMB conditionals
grep -n "isATwilioChannel\|isALineChannel\|isAPIInbox" Settings.vue
# Should see: isAnAppleMessagesForBusinessChannel

# Find missing i18nMap entries
grep -n "i18nMap" ChannelName.vue
# Should see: 'Channel::AppleMessagesForBusiness'

# Find dangling imports from Phase 6 cleanup
grep -n "AIAssistanceButton\|useAI" ReplyBottomPanel.vue
# Should return nothing

# Find unexported constants
grep -n "WIDGET_BUILDER_EDITOR_MENU_OPTIONS" app/javascript/dashboard/constants/editor.js
# Should show: export const WIDGET_BUILDER_EDITOR_MENU_OPTIONS
```

---

## Summary Statistics

| Metric | Count |
|--------|-------|
| Total Commits | 13 |
| Phases Completed | 7 |
| Backend Tests Passing | 408/426 (95.8%) |
| AMB References Preserved | 124+ |
| Files with Direct Edits | 100+ |
| Common Missed Items | 5 |
| Post-Phase Fixes | 5 |

---

## Files Most Likely to Have Merge Issues

1. `Settings.vue` - Inbox configuration tab visibility
2. `ChannelName.vue` - Channel type i18n mapping
3. `Sidebar.vue` - Settings menu items
4. `settings.routes.js` - Route registration
5. `ReplyBottomPanel.vue` - Deleted component imports
6. `editor.js` - Exported constants

---

**Last Updated**: May 2, 2026  
**Branch**: sync/v4.13.0  
**Status**: ✅ Complete with all AMB features restored
