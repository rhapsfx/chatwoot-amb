# Bot Studio Flow #5 Configuration Analysis

**⚠️ SUPERSEDED**: This analysis was INCORRECT. See the corrected analysis at:
**`docs/bot-studio/BOT_STUDIO_FLOW_5_CORRECTED_ANALYSIS.md`**

---

## Original (Incorrect) Analysis

**Analysis Date**: 2025-12-28
**Flow Backup**: `tmp/flow_5_backup_1766829675.json`

**Status**: ❌ This analysis incorrectly concluded Flow #5 was just a demo flow. In reality, Flow #5 IS supposed to be the full Acoustic House conversational bot, but the migration script was never run.

## Executive Summary (INCORRECT - DO NOT USE)

~~Flow #5 is a **DEMO/REFERENCE FLOW** showcasing all 12 Apple Messages template types, NOT the conversational Acoustic House bot flow. This flow is designed for template demonstrations, not for actual customer conversations.~~

**CORRECTION**: Flow #5 IS the full Acoustic House conversational bot. The migration script `script/migrate_bot_flow_to_full_acoustic_house.rb` was never executed, so all 29 conversational nodes are missing.

## Flow Architecture

### Flow Purpose: Template Showcase

This flow demonstrates:
- List Picker interactions
- Time Picker scheduling
- Apple Pay transactions
- Form submissions
- iMessage App integration
- App Clip experiences
- API Call integrations
- Condition-based routing

### Node Structure

**Total Nodes**: 18 (16 nodes in visual flow)
- **5 State Nodes**: Welcome, Process Region, Main Menu, and various demo states
- **7 Intent Nodes**: Region selection, menu, start over, summary, and template demos
- **1 Condition Node**: Region checking logic
- **5 Demo State Nodes**: Time Picker, Form, Summary, Apple Pay, API Call, iMessage App, App Clip

### Edge Structure

**Total Edges**: 13 auto-transition edges connecting:
- `state-welcome` → `intent-region` → `state-region-process` → `state-menu`
- `state-menu` → Various demo intent nodes
- Demo flow branches through condition node to Apple Pay or API Call
- Final completion path through iMessage App → App Clip → Complete

## Critical Configuration Issues Identified

### Issue #1: Intent with No Keywords (CRITICAL)

**Node**: `intent-region` (Region Selection Intent)
**Problem**: Contextual intent has EMPTY keywords array

```json
{
  "id": "intent-region",
  "data": {
    "label": "Region Selection Intent",
    "scope": "contextual",
    "keywords": [],  // ❌ EMPTY - Will never match text input
    "intent_id": "select_region"
  }
}
```

**Impact**: This intent will NEVER match text input from the user. It can only execute via:
1. Interactive message responses (list picker, quick reply selection)
2. Being found as a "waiting intent" by `find_waiting_intent_for_interactive_response()`

**Expected Behavior**: Template 53 must be a quick reply or list picker that captures region selection via button clicks, not text keywords.

### Issue #2: Auto-Transition Architecture

**Pattern**: All state nodes have unconditional outgoing edges

**Example**:
- `state-welcome` executes templates → immediately transitions to `intent-region`
- `state-region-process` executes template → immediately transitions to `state-menu`
- `state-menu` executes template → waits for intent match (3 branches)

**Design**: This flow uses:
- **Active intents**: Menu, start over, summary (with keywords)
- **Passive states**: States execute templates and transition immediately
- **No waiting states**: No states configured to wait for user text input

### Issue #3: Template-Dependent Execution

**Critical Dependency**: Flow success depends ENTIRELY on templates being correctly configured

**Required Template Behavior**:
- Template 53 (in state-welcome and intent-region): MUST be region selection interactive message
- Template 54 (state-region-process): MUST confirm region selection
- Template 55 (state-menu): MUST be menu with multiple options
- Templates 56-63: Demo templates for various template types

**If templates are missing or misconfigured**: Flow will auto-transition through all states without waiting for user input.

## Comparison with Acoustic House Bot Flow

### Expected Acoustic House States (NOT in Flow #5)

The user reported issues with states that DO NOT exist in this flow:
- `state-name-preference` ❌ Not found
- `state-ar-question-1` ❌ Not found
- `state-ar-place-question` ❌ Not found
- `state-ar-view-catcher` ❌ Not found
- `state-form-or-name-prompt` ❌ Not found
- `state-guitar-list-prompt` ❌ Not found

### Conclusion

**Flow #5 is NOT the Acoustic House conversational bot flow.** It's a demo/reference flow for showcasing template types.

The user's reported issues with "random flow execution" and messages like:
- "Welcome to Acoustic House!"
- "Which region are you shopping from?"
- "Just in. We have this cool Stratocaster. Check it out in AR!"
- "Please select 'Yes' or 'No'..."

...are from a DIFFERENT flow (likely the actual Acoustic House bot flow with nodes like `state-name-preference`, `state-ar-question-1`, etc.).

## Recommendations

### Immediate Actions

1. **Identify the correct flow**: Find the actual Acoustic House conversational bot flow
   ```ruby
   rails runner "puts BotFlow.where('name LIKE ?', '%Acoustic%').pluck(:id, :name, :is_active, :is_published)"
   ```

2. **Backup the correct flow**: Once identified, create a backup
   ```ruby
   rails runner script/backup_bot_flow.rb [CORRECT_FLOW_ID]
   ```

3. **Analyze the correct flow**: Apply the analysis from `tmp/analyze_flow_actions.rb` to the actual conversational flow

### Flow #5 Specific Fixes (If Needed)

If Flow #5 needs to be fixed as a working demo:

1. **Add keywords to intent-region**:
   ```json
   "keywords": ["americas", "emea", "apac", "north america", "europe", "asia"]
   ```

2. **OR ensure Template 53 is properly configured** as an interactive message (list picker/quick reply) with region options

3. **Test template execution**: Verify all templates (49, 50, 53-63) exist and render correctly

## Files to Review

1. `app/services/apple_messages_for_business/flow_executor_service.rb:606-626` - ✅ Fixed send_quick_reply implementation
2. `app/services/apple_messages_for_business/acoustic_house_bot_service.rb:836-851` - ✅ Reverted incorrect handler changes
3. **Missing**: Actual Acoustic House bot flow configuration

## Test Plan

Once the correct flow is identified:

1. Start bot flow with "startover" keyword
2. Verify welcome message appears
3. Select region (via interactive message or text)
4. Verify state transitions properly
5. Test name input capture
6. Test guitar selection
7. Test AR question responses
8. Test through to completion

## Summary

**Flow #5 Status**: ✅ Demo flow is correctly structured for template showcase
**User's Issue**: ❌ Not related to Flow #5 - Different flow needs analysis
**Code Fixes Applied**: ✅ send_quick_reply and handler reversion completed
**Next Step**: 🔍 Identify and analyze the actual Acoustic House conversational bot flow
