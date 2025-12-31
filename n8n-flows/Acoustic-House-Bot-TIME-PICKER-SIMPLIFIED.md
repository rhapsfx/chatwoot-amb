# Acoustic House Bot - Time Picker Simplified Approach

## ✅ Solution: Template-Based Time Slots

### The Problem

When trying to use dynamically generated time slots with the AMB Time Picker node, validation errors appeared:
- "Parameter 'Identifier' is required"
- "Parameter 'Start Time' is required"

### Root Cause

The `availableSlots` parameter in the Time Picker node uses n8n's `fixedCollection` type, which validates fields **before expressions are evaluated**. This means:

1. Expression: `={{ $json.timeSlots }}` cannot be validated at design time
2. n8n UI shows validation errors even though the expression would work at runtime
3. This creates confusion and makes the workflow appear broken

### The Solution: Template-Based Configuration

Following the pattern from the working workflow (`Acoustic-House-Bot-n8n-FIXED.json`), we **simplified the Time Picker node** to only specify:

```json
{
  "parameters": {
    "accountId": "={{ $('Router with State').item.json.accountId }}",
    "conversationId": "={{ $('Router with State').item.json.conversationId }}",
    "templateId": 5
  },
  "type": "CUSTOM.chatwootAMBTimePicker"
}
```

**What Changed:**
- ❌ **Removed**: `availableSlots` (dynamic slot generation)
- ❌ **Removed**: `title` and `description`
- ❌ **Removed**: `receivedMessage` and `replyMessage`
- ❌ **Removed**: "Generate Time Slots" node
- ✅ **Kept**: Only `accountId`, `conversationId`, and `templateId`

---

## How It Works Now

### 1. Chatwoot Template Configuration

The time slots are now defined in the **Chatwoot template** (Template ID 5), not in the n8n workflow.

**In Chatwoot Admin**:
1. Go to Settings → Templates
2. Edit Template ID 5 (or create new Time Picker template)
3. Configure available time slots:
   - Define slot identifiers, start times, and durations
   - Set title and description text
   - Configure received and reply messages
   - Set timezone offset

### 2. Workflow Execution

When the workflow runs:
1. User triggers "appointment" or "time picker" flow
2. "Is Time?" condition routes to "AMB Time Picker"
3. Time Picker node sends `templateId: 5` to Chatwoot
4. Chatwoot fetches template configuration and generates the time picker
5. Apple Messages displays the time picker with template-defined slots

### 3. Benefits

| Aspect | Dynamic Slots (Old) | Template-Based (New) |
|--------|---------------------|----------------------|
| **n8n Validation** | ❌ Errors in UI | ✅ Clean, no errors |
| **Maintenance** | Update workflow code | Update Chatwoot template |
| **Flexibility** | Generate slots in n8n | Configure in Chatwoot UI |
| **Complexity** | Higher (Code node + expressions) | Lower (Just template ID) |
| **User Experience** | Confusing validation errors | Clean import/export |

---

## Configuration Guide

### Chatwoot Template Setup

**Template Type**: Time Picker

**Required Fields**:
```yaml
title: "📅 Select a time to visit our showroom"
description: "Choose your preferred appointment time"

available_slots:
  - identifier: "2025-11-03_09"
    start_time: "2025-11-03T09:00+0000"
    duration: 3600
  - identifier: "2025-11-03_10"
    start_time: "2025-11-03T10:00+0000"
    duration: 3600
  # ... more slots

timezone_offset: 0  # UTC, adjust as needed

received_message:
  title: "Visit our showroom"
  subtitle: "Book your appointment"

reply_message:
  title: "Appointment booked!"
  subtitle: "We look forward to seeing you"
```

### n8n Workflow Setup

1. **Import workflow**: `Acoustic-House-Bot-MIGRATED.json`
2. **Assign credentials**: `chatwootBotApi` to AMB Time Picker node
3. **Update template ID**: Set `templateId` to match your Chatwoot template
4. **Test flow**: Send "appointment" or "time picker" message

---

## Comparison: Before vs After

### Before (Dynamic Slots)

**Workflow Structure**:
```
Is Time? → Generate Time Slots (Code) → AMB Time Picker (with slots) → ...
```

**Time Picker Configuration**:
```json
{
  "templateId": 5,
  "title": "...",
  "description": "...",
  "availableSlots": {
    "slot": "={{ $json.timeSlots }}"  // ❌ Validation errors
  },
  "receivedMessage": {...},
  "replyMessage": {...}
}
```

**Issues**:
- n8n shows validation errors in UI
- Complex Code node for slot generation
- Mixed configuration (template + inline)

### After (Template-Based)

**Workflow Structure**:
```
Is Time? → AMB Time Picker (template only) → ...
```

**Time Picker Configuration**:
```json
{
  "templateId": 5  // ✅ Clean, simple
}
```

**Benefits**:
- No validation errors
- No Code node needed
- All configuration in Chatwoot template
- Simpler workflow maintenance

---

## Migration Notes

### What Was Removed

1. **"Generate Time Slots" node**: Entire Code node removed
2. **Time Picker parameters**: Removed `availableSlots`, `title`, `description`, `receivedMessage`, `replyMessage`
3. **Workflow connections**: Updated "Is Time?" to connect directly to "AMB Time Picker"

### What You Need to Do

1. **Configure Chatwoot template** with your desired time slots
2. **Update `templateId`** in Time Picker node to match your template
3. **Test the flow** to ensure time slots display correctly

---

## Dynamic Slots Alternative (Future)

If you still need **dynamic slot generation** in n8n, there are two options:

### Option 1: Modify Custom Node

Update `ChatwootAMBTimePicker.node.ts` to accept slots as a JSON expression instead of `fixedCollection`:

```typescript
{
  displayName: 'Available Time Slots (JSON)',
  name: 'availableSlotsJson',
  type: 'string',
  default: '={{ $json.timeSlots }}',
  description: 'JSON array of time slots'
}
```

Then parse the JSON in the execute function.

### Option 2: Use HTTP Request Node

Send time picker directly via HTTP POST to Chatwoot API (bypasses custom node validation).

**For now, the template-based approach is recommended** for simplicity and reliability.

---

## File Changes

**Modified**:
- `Acoustic-House-Bot-MIGRATED.json` - Simplified Time Picker, removed Generate Slots node
- Node count: 25 → 24 nodes

**Documentation**:
- `Acoustic-House-Bot-TIME-PICKER-SIMPLIFIED.md` - This file
- `Acoustic-House-Bot-FINAL-FIX.md` - Updated with simplified approach

---

## Testing

### Test the Simplified Flow

1. **Import workflow** into n8n
2. **Configure Chatwoot template** with time slots
3. **Send message**: "appointment" or "time picker"
4. **Verify**: Time picker displays with slots from template

### Expected Result

- ✅ No validation errors in n8n UI
- ✅ Time picker displays correctly in Apple Messages
- ✅ Time slots from Chatwoot template are shown
- ✅ Clean, simple workflow structure

---

## Summary

**The Fix**: Remove dynamic slot generation, use Chatwoot template configuration instead.

**Why**: n8n's `fixedCollection` validation doesn't work well with expressions.

**Result**: Clean, simple, error-free workflow that's easier to maintain.

**Trade-off**: Time slots configured in Chatwoot UI instead of n8n Code node.

This approach follows the working pattern from `Acoustic-House-Bot-n8n-FIXED.json` and eliminates all validation errors.
