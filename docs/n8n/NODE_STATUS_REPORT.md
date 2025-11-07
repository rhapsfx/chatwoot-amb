# n8n Custom Node Status Report

**Date**: November 7, 2025  
**Status**: ✅ RESOLVED - Custom nodes are properly installed and recognized by n8n

## Issue Resolution

### Initial Issue
```
Unrecognized node type: CUSTOM.chatwootAMBListPicker
Activation of workflow "Acoustic House flow 0.91" (tUS32chOsTi9vXfr) did fail
```

### Root Cause
The error was from an earlier session before n8n was restarted. After proper installation and restart, all custom nodes are now recognized and executing.

### Installation Steps Completed

1. **Package Location**: `/Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb/`
2. **Build**: Compiled successfully with TypeScript
3. **Symlink**: Created global npm link and linked to `~/.n8n/custom/`
4. **Package.json**: Updated `~/.n8n/custom/package.json` with dependency

```json
{
  "dependencies": {
    "n8n-nodes-chatwoot-amb": "file:../../LocalGit/chatwoot/n8n-nodes-chatwoot-amb"
  }
}
```

### Verification

**Node Files**:
- ✅ `/Users/rhaps/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/` (symlink)
- ✅ All compiled nodes exist in `dist/nodes/`
- ✅ Credentials compiled in `dist/credentials/`

**Execution Logs** (from n8n):
```
CUSTOM.chatwootAMBListPicker - Executing successfully
CUSTOM.chatwootAMBQuickReply - Executing successfully
CUSTOM.chatwootAMBForm - Executing successfully
```

## Current Issue: Backend Validation Errors

While the n8n nodes are working, there are **Chatwoot backend validation errors** when sending messages:

### List Picker Error
```
422 - Failed to send template message: 
Validation failed: Content attributes contains invalid keys for apple_list_picker: 
[:reply_message, :received_message]
```

### Form Error
```
422 - Failed to send template message:
Validation failed: Content attributes contains invalid keys for apple_form:
[:received_title, :received_subtitle, :received_image_identifier, 
 :reply_title, :reply_subtitle, :reply_image_identifier]
```

### Analysis
The n8n nodes are sending field names that the Chatwoot backend doesn't recognize. This is likely due to:

1. **Naming mismatch**: The n8n node uses field names that don't match backend expectations
2. **Structure mismatch**: The way the n8n node structures received_message/reply_message differs from backend

### Files Involved

**Frontend (Working)**:
- `/Users/rhaps/LocalGit/chatwoot/app/javascript/dashboard/components-next/message/modals/EnhancedTimePickerModal.vue`
- `/Users/rhaps/LocalGit/chatwoot/app/javascript/dashboard/components-next/message/modals/AppleFormBuilder.vue`

**Backend Validation**:
- Template validation in message template models
- Bot API controller validation

**n8n Node**:
- `/Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb/nodes/ChatwootAMBListPicker/ChatwootAMBListPicker.node.ts`

## Next Steps

1. ✅ **COMPLETED**: Custom nodes are installed and recognized by n8n
2. 🔧 **TODO**: Fix field name validation between n8n nodes and Chatwoot backend
3. 🔧 **TODO**: Align n8n node field structure with backend expectations

## How to Rebuild Nodes

If you make changes to the n8n custom nodes:

```bash
cd /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
npm run build
```

n8n will automatically detect changes via the symlink (no restart needed for code changes).

## Commands for Reference

**Build custom nodes**:
```bash
cd /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb && npm run build
```

**Link to n8n** (already done):
```bash
cd /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb && npm link
cd ~/.n8n/custom && npm link n8n-nodes-chatwoot-amb
```

**Check n8n logs**:
```bash
tail -100 ~/.n8n/n8nEventLog-2.log | grep -i chatwoot
```

**Verify node exists**:
```bash
ls -la ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/dist/nodes/
```

