# n8n-nodes-chatwoot-amb Upgrade Guide

## Version 1.1.0 - Credential and Icon Improvements

### Overview
This update improves the n8n AMB nodes by:
1. **Centralizing Chatwoot URL in credentials** - No need to enter URL in each node
2. **Using the official Apple Messages for Business icon** - Green iMessage bubble icon

### Breaking Changes

#### Credential Structure Updated
The `Chatwoot Bot API` credential now includes the Chatwoot URL field:

**Before:**
```
Credential fields:
- API Access Token
```

**After:**
```
Credential fields:
- Chatwoot URL (new)
- API Access Token
```

#### Node Properties Removed
All AMB nodes no longer have the `Chatwoot URL` property. This value is now retrieved from credentials.

**Affected Nodes:**
- Chatwoot AMB List Picker
- Chatwoot AMB Time Picker
- Chatwoot AMB Quick Reply
- Chatwoot AMB Form
- Chatwoot AMB Apple Pay
- Chatwoot AMB Rich Link

### Migration Steps

#### For Existing Users

1. **Update your credentials:**
   - Go to **Credentials** in n8n
   - Edit your existing `Chatwoot Bot API` credential
   - Add your **Chatwoot URL** (e.g., `https://app.chatwoot.com`)
   - Save the credential

2. **Update your workflows:**
   - Open each workflow using AMB nodes
   - For each AMB node:
     - The `Chatwoot URL` field will show an error (field no longer exists)
     - Simply re-save the node (the URL is now from credentials)
   - Save the workflow

3. **Verify:**
   - Test your workflows to ensure they work correctly
   - The Chatwoot URL is now centrally managed in credentials

#### For New Users

1. **Create credential:**
   - Go to **Credentials** → **Add Credential**
   - Search for **Chatwoot Bot API**
   - Enter:
     - **Chatwoot URL**: Your instance URL (e.g., `https://app.chatwoot.com`)
     - **API Access Token**: Your bot token from Chatwoot
   - Save

2. **Use in workflows:**
   - Add any AMB node to your workflow
   - Select your credential
   - Configure node parameters (no URL needed!)

### Benefits

#### 1. Centralized Configuration
- **Before**: Enter Chatwoot URL in every single AMB node
- **After**: Enter once in credentials, use everywhere

#### 2. Easier Updates
- **Before**: Change URL in 10+ nodes when switching instances
- **After**: Update once in credentials

#### 3. Better Security
- Credentials are stored securely by n8n
- URL is managed alongside the API token

#### 4. Visual Identity
- All AMB nodes now display the official Apple Messages for Business icon
- Easy to identify AMB nodes in your workflows

### Technical Details

#### Files Changed

**Credentials:**
- `credentials/ChatwootBotApi.credentials.ts` - Added `chatwootUrl` field

**Icons:**
- `icons/amb.svg` - New Apple Messages for Business icon (green iMessage bubble)

**Nodes Updated:**
- `nodes/ChatwootAMBListPicker/ChatwootAMBListPicker.node.ts`
- `nodes/ChatwootAMBTimePicker/ChatwootAMBTimePicker.node.ts`
- `nodes/ChatwootAMBQuickReply/ChatwootAMBQuickReply.node.ts`
- `nodes/ChatwootAMBForm/ChatwootAMBForm.node.ts`
- `nodes/ChatwootAMBApplePay/ChatwootAMBApplePay.node.ts`
- `nodes/ChatwootAMBRichLink/ChatwootAMBRichLink.node.ts`

**Changes per node:**
1. Removed `chatwootUrl` property from node properties
2. Updated icon from `file:chatwoot.svg` to `file:amb.svg`
3. Modified execute method to get URL from credentials instead of node parameters

#### Code Example

**Before:**
```typescript
// In node properties
{
  displayName: 'Chatwoot URL',
  name: 'chatwootUrl',
  type: 'string',
  default: 'https://app.chatwoot.com',
  required: true,
}

// In execute method
const chatwootUrl = this.getNodeParameter('chatwootUrl', i) as string;
const credentials = await this.getCredentials('chatwootBotApi');
const botToken = credentials.apiToken as string;
```

**After:**
```typescript
// No chatwootUrl in node properties

// In execute method
const credentials = await this.getCredentials('chatwootBotApi');
const chatwootUrl = credentials.chatwootUrl as string;
const botToken = credentials.apiToken as string;
```

### Troubleshooting

#### Error: "chatwootUrl is not defined"
**Solution:** Update your credential to include the Chatwoot URL field.

#### Error: "Unknown property 'chatwootUrl'"
**Solution:** You're using an old version. Update to v1.1.0 or later.

#### Workflows not working after update
**Solution:** 
1. Check credential has Chatwoot URL
2. Re-save each AMB node in your workflows
3. Test the workflow

### Support

If you encounter issues:
1. Check this upgrade guide
2. Review the [README.md](README.md) for setup instructions
3. Open an issue on [GitHub](https://github.com/chatwoot/n8n-nodes-chatwoot-amb/issues)

---

**Version:** 1.1.0  
**Date:** November 2025  
**Compatibility:** n8n v1.0.0+