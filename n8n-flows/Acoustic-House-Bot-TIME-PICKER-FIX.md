# Acoustic House Bot - Time Picker Data Format Fix

## ✅ Issue Resolved!

### The Problem
**Validation errors** in AMB Time Picker node when importing workflow:
- ❌ `Parameter "Identifier" is required` - Wrong format
- ❌ `Parameter "Start Time" is required` - Wrong format
- ❌ Duration value incorrect

### Root Cause
The "Generate Time Slots" node was producing data in incorrect formats for Apple Messages for Business Time Picker requirements.

---

## Data Format Requirements

### Apple Time Picker Expected Formats

| Field | Format | Example |
|-------|--------|---------|
| **identifier** | `YYYY-MM-DD_HH` | `2025-11-03_14` |
| **startTime** | `YYYY-MM-DDTHH:MM+0000` | `2025-11-03T14:00+0000` |
| **duration** | Seconds (integer) | `3600` (1 hour) |

### What Was Wrong

**Before Fix**:
```javascript
slots.push({
  identifier: `${dateStr}_${time.replace(':', '')}`,  // ❌ 2025-11-03_0900 (HHMM)
  startTime: slotTime.toISOString(),                  // ❌ 2025-11-03T14:00:00.000Z
  duration: 60                                         // ❌ 60 seconds (1 minute)
});
```

**Issues**:
1. **Identifier**: Used `HHMM` format (e.g., `_0900`) instead of just `HH` (e.g., `_09`)
2. **Start Time**: Used full ISO format with seconds/milliseconds and `Z` timezone
3. **Duration**: Used 60 seconds (1 minute) instead of 3600 seconds (1 hour)

---

## The Fix

### Corrected Code

```javascript
// Helper function to format date/time for Apple Time Picker
function formatTimePickerDateTime(date) {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  const hour = String(date.getUTCHours()).padStart(2, '0');
  const minute = String(date.getUTCMinutes()).padStart(2, '0');
  return `${year}-${month}-${day}T${hour}:${minute}+0000`;
}

slots.push({
  identifier: `${dateStr}_${hour}`,           // ✅ 2025-11-03_14 (HH only)
  startTime: formatTimePickerDateTime(slotTime), // ✅ 2025-11-03T14:00+0000
  duration: 3600                               // ✅ 3600 seconds (1 hour)
});
```

### Changes Applied

| Field | Before | After |
|-------|--------|-------|
| **identifier** | `2025-11-03_0900` | `2025-11-03_09` ✅ |
| **startTime** | `2025-11-03T14:00:00.000Z` | `2025-11-03T14:00+0000` ✅ |
| **duration** | `60` | `3600` ✅ |

---

## Verification

### Expected Slot Data

After the fix, each time slot will be formatted as:

```json
{
  "identifier": "2025-11-03_09",
  "startTime": "2025-11-03T09:00+0000",
  "duration": 3600
}
```

### Sample Generated Slots

For next 7 weekdays (skipping weekends), 6 slots per day:

```json
[
  {
    "identifier": "2025-11-04_09",
    "startTime": "2025-11-04T09:00+0000",
    "duration": 3600
  },
  {
    "identifier": "2025-11-04_10",
    "startTime": "2025-11-04T10:00+0000",
    "duration": 3600
  },
  {
    "identifier": "2025-11-04_11",
    "startTime": "2025-11-04T11:00+0000",
    "duration": 3600
  },
  {
    "identifier": "2025-11-04_14",
    "startTime": "2025-11-04T14:00+0000",
    "duration": 3600
  },
  {
    "identifier": "2025-11-04_15",
    "startTime": "2025-11-04T15:00+0000",
    "duration": 3600
  },
  {
    "identifier": "2025-11-04_16",
    "startTime": "2025-11-04T16:00+0000",
    "duration": 3600
  }
]
```

---

## Technical Details

### Format Helper Function

The `formatTimePickerDateTime()` function ensures the exact format Apple expects:

**Purpose**: Convert JavaScript Date to `YYYY-MM-DDTHH:MM+0000` format

**Why Manual Formatting?**
- `toISOString()` produces: `2025-11-03T14:00:00.000Z` ❌
- Apple expects: `2025-11-03T14:00+0000` ✅

**Key Differences**:
- ❌ No seconds (`:00`)
- ❌ No milliseconds (`.000`)
- ❌ No `Z` timezone notation
- ✅ Uses explicit `+0000` UTC offset

### Identifier Simplification

**Before**: `${dateStr}_${time.replace(':', '')}`
- Produced: `2025-11-03_0900` (includes minutes)
- Issue: Too detailed for identifier requirements

**After**: `${dateStr}_${hour}`
- Produces: `2025-11-03_09` (hour only)
- Matches: Apple's expected `YYYY-MM-DD_HH` format

### Duration Correction

**Before**: `60` seconds = 1 minute ❌
**After**: `3600` seconds = 1 hour ✅

This ensures each appointment slot is properly shown as a 1-hour booking.

---

## Node Location

**Node**: "Generate Time Slots"
**Type**: `n8n-nodes-base.code`
**Position**: Line 694-706 in `Acoustic-House-Bot-MIGRATED.json`

**Triggers Before**: "Is Time?" condition check
**Feeds Into**: "AMB Time Picker" node

---

## Testing

### Test the Fix

1. **Import workflow** into n8n
2. **Activate workflow**
3. **Test webhook** with message: `time picker` or `appointment`
4. **Verify**: Time Picker displays with no validation errors

### Expected Result

- ✅ No parameter validation errors
- ✅ Time slots display correctly
- ✅ Each slot shows 1-hour duration
- ✅ Identifier format correct: `YYYY-MM-DD_HH`
- ✅ Start time format correct: `YYYY-MM-DDTHH:MM+0000`

---

## Related Files

- **Workflow**: `Acoustic-House-Bot-MIGRATED.json` (updated)
- **Node**: "Generate Time Slots" (Code node)
- **Custom Node**: `ChatwootAMBTimePicker` (`n8n-nodes-chatwoot-amb/nodes/`)

---

## Status

✅ **Fixed**: Time slot data format corrected
✅ **Validated**: JSON syntax valid
✅ **Ready**: Workflow ready to import and test

**Date Fixed**: November 10, 2025

---

## Quick Reference

### Correct Format Summary

```javascript
// Identifier: Date + Hour only
`${date}_${hour}`  // "2025-11-03_14"

// Start Time: ISO format without seconds/ms, explicit UTC offset
`YYYY-MM-DDTHH:MM+0000`  // "2025-11-03T14:00+0000"

// Duration: Seconds (3600 = 1 hour)
3600
```

This fix ensures the AMB Time Picker node receives properly formatted data that passes Apple Messages for Business validation requirements.
