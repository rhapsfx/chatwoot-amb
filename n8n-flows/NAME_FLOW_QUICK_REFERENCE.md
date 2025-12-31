# Name Collection Flow - Quick Reference

## Summary

The Name Collection Flow (AHB1, AHB2, AHB1_2, AHB3) has been successfully implemented in:
- **File**: `/Users/rhaps/LocalGit/chatwoot/n8n-flows/Acoustic-House-Bot-MIGRATED.json`
- **Date**: 2025-11-10
- **Nodes Added**: 11
- **Connections Created**: 13

## Node Overview

| Node ID | Node Name | Type | Purpose |
|---------|-----------|------|---------|
| `check-region-selected` | Is Region Selected? | IF | Detect region selection |
| `check-name-collected` | Is Name Collected? | IF | Detect form submission |
| `check-name-selected` | Is Name Selected? | IF | Detect name preference QR |
| `parse-form-response` | AHB1 - Parse Form Response | Code | Extract name fields from form |
| `has-stage-name` | Has Stage Name? | IF | Check if stage name provided |
| `ask-name-preference` | AHB2 - Ask Name Preference | HTTP | Ask preference question |
| `name-selection-qr` | AHB2 - Name Selection Quick Reply | Custom AMB QR | Present name choice |
| `select-name` | AHB2 - Select Name | Code | Choose final name |
| `parse-text-name` | AHB1_2 - Parse Text Name | Code | Fallback text input |
| `update-name-attrs` | Update Name Attributes | HTTP | Store name data |
| `personalized-greeting` | AHB3 - Personalized Greeting | HTTP | Send welcome with name |

## Flow Paths

### Path 1: Form with Both Names
```
Form Submitted → Parse Form → Has Stage Name (YES)
  → Ask Preference → Name Selection QR → Select Name
  → Update Attrs → Greeting → Guitar List
```

### Path 2: Form with Only Real Name
```
Form Submitted → Parse Form → Has Stage Name (NO)
  → Update Attrs → Greeting → Guitar List
```

### Path 3: Text Input Fallback
```
Text Input → Parse Text Name
  → Update Attrs → Greeting → Guitar List
```

## Router Updates

### New Route Detection
```javascript
// In quick_reply handler
else if (reply === 'name_real' || reply === 'name_stage') {
  route = 'NAME_SELECTED';
  nextState = 'name_selected';
}
```

### New Output Flag
```javascript
isNameSelected: route === 'NAME_SELECTED',
```

## Data Structures

### Form Response (AHB1)
```json
{
  "userName": "John",
  "stageName": "JRock",
  "hasStageName": true,
  "conversationId": 123,
  "accountId": 1
}
```

### Name Selection (AHB2)
```json
{
  "selectedName": "JRock",
  "nameSelection": "name_stage",
  "conversationId": 123,
  "accountId": 1
}
```

### Custom Attributes Stored
```json
{
  "user_name": "John",
  "stage_name": "JRock",
  "selected_name": "JRock"
}
```

## State Progression

1. `region_selected` - Region chosen
2. `name_collected` - Form submitted
3. `awaiting_name_preference` - (if stage name exists)
4. `name_selected` - Name choice made
5. `name_confirmed` - Name finalized
6. `guitar_list_shown` - Continuing to guitar selection

## Integration Points

### Entry Points
- After region selection quick reply
- Form submission webhook
- Text message after region selection

### Exit Point
- AMB Guitar List (template 329)

## Quick Reply Options

**Template ID**: 3

| Identifier | Title | Result |
|------------|-------|--------|
| `name_real` | "Use my name" | Uses `user_name` from form |
| `name_stage` | "Use stage name" | Uses `stage_name` from form |

## Message Templates

### Ask Name Preference
```
"How would you like to be addressed?"
```

### Personalized Greeting
```
"Hello {{name}}. We have some cool guitars we would like you to see."
```

## Testing Commands

### Test Router Update
```bash
python3 -c "
import json
with open('Acoustic-House-Bot-MIGRATED.json') as f:
    wf = json.load(f)
    router = next(n for n in wf['nodes'] if n['id'] == 'router')
    print('NAME_SELECTED' in router['parameters']['jsCode'])
"
```

### Verify Connections
```bash
python3 -c "
import json
with open('Acoustic-House-Bot-MIGRATED.json') as f:
    wf = json.load(f)
    print('Greeting to Guitar:',
          wf['connections']['AHB3 - Personalized Greeting']['main'][0][0]['node'])
"
```

### Count Name Flow Nodes
```bash
python3 -c "
import json
with open('Acoustic-House-Bot-MIGRATED.json') as f:
    wf = json.load(f)
    name_nodes = [n for n in wf['nodes']
                  if 'AHB' in n['name'] or 'Name' in n['name']
                  or 'Region Selected' in n['name']]
    print(f'Name flow nodes: {len(name_nodes)}')
"
```

## Next Steps

1. **Create Form Template**: Design "Help Me Decide" form with fields 4 & 5
2. **Test Form Path**: Submit form with both names, verify parsing
3. **Test QR Path**: Verify name selection quick reply works
4. **Test Text Path**: Implement state-based detection for AHB1_2 path
5. **Add Error Handling**: Handle missing fields, API failures
6. **Multi-language**: Add support for translated messages

## Common Issues

### Issue: Form fields not parsing
- **Check**: Form field indices (items[3] and items[4])
- **Verify**: Form structure matches expected format

### Issue: Name preference not showing
- **Check**: `hasStageName` flag is true
- **Verify**: Stage name field has value

### Issue: Wrong name displayed in greeting
- **Check**: `selectedName` value in Update Attributes node
- **Verify**: Custom attributes are being stored correctly

## Files Created

- `/Users/rhaps/LocalGit/chatwoot/n8n-flows/Acoustic-House-Bot-MIGRATED.json` - Updated workflow
- `/Users/rhaps/LocalGit/chatwoot/n8n-flows/add_name_collection.py` - Implementation script
- `/Users/rhaps/LocalGit/chatwoot/n8n-flows/NAME_COLLECTION_FLOW_IMPLEMENTATION.md` - Full documentation
- `/Users/rhaps/LocalGit/chatwoot/n8n-flows/NAME_FLOW_DIAGRAM.txt` - Visual diagram
- `/Users/rhaps/LocalGit/chatwoot/n8n-flows/NAME_FLOW_QUICK_REFERENCE.md` - This file

## Python Reference

Original functions from `/Users/rhaps/LocalGit/chatwoot/_apple/Acoustic-House-Bot-origin/acoustichouse/AH.py`:

- **Lines 973-989**: `AHB1()` - Form parsing and flow decision
- **Lines 991-999**: `AHB2()` - Name selection logic
- **Lines 1001-1005**: `AHB1_2()` - Text input fallback
- **Lines 1007-1011**: `AHB3()` - Personalized greeting

## Verification Status

✅ Router updated with NAME_SELECTED route
✅ Router updated with isNameSelected flag
✅ 11 nodes added to workflow
✅ 13 connections created
✅ All key connections verified
✅ Greeting connects to Guitar List
✅ Workflow file valid JSON
✅ Node IDs unique
✅ Integration points connected

**Status**: Ready for testing
