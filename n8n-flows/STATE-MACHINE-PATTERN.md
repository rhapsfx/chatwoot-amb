# State Machine Pattern for Interactive Messages

## The Problem You Discovered 🐛

When sending interactive messages (Quick Reply, List Picker, Time Picker, Form, Apple Pay), n8n executes the next node **immediately** without waiting for the user's response.

**Wrong Pattern**:
```
Send Quick Reply → Parse Response → Update Attribute
(All executes in same workflow run!)
```

**Result**: Parse node receives the Quick Reply **question**, not the user's **answer** → `region="unknown"` ❌

---

## The Solution: State Machine Pattern ✅

Break the flow into **2 separate workflow runs**:

### Run 1: Send Interactive Message
```
1. Detect trigger (e.g., "start")
2. Send interactive message (Quick Reply, List Picker, etc.)
3. Set bot_state to indicate what we're waiting for
4. END WORKFLOW ← Important!
```

### Run 2: Handle Response (triggered by user's answer)
```
1. Webhook triggers again
2. Router checks bot_state
3. Route to appropriate response handler
4. Parse the response
5. Continue flow
```

---

## Implementation Pattern

### Step 1: Send Interactive Message + Set State

**Node 1**: Send Quick Reply (or List Picker, Time Picker, etc.)
```json
{
  "type": "CUSTOM.chatwootAMBQuickReply",
  "parameters": {
    "message": "Where are you in the world?",
    "options": [
      {"title": "Americas", "value": "americas"},
      {"title": "EMEA", "value": "emea"},
      {"title": "APAC", "value": "apac"}
    ]
  }
}
```

**Node 2**: Set State
```json
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "https://.../custom_attributes",
    "bodyParameters": {
      "parameters": [
        {
          "name": "custom_attributes[bot_state]",
          "value": "region_asked"
        }
      ]
    }
  }
}
```

**Node 3**: No connection → Workflow ends

---

### Step 2: Router Detection

Add detection logic to Router:

```javascript
// In Router with State node
const customAttrs = conversation.custom_attributes || {};
const botState = customAttrs.bot_state;

// Detect region response
if (botState === 'region_asked') {
  console.log('Handling region selection response');
  route = 'REGION_RESPONSE';
}
```

---

### Step 3: Response Handler Branch

**After Router**: Add conditional node

```json
{
  "name": "Is Region Response?",
  "type": "n8n-nodes-base.if",
  "conditions": {
    "leftValue": "={{ $json.route }}",
    "operator": "equals",
    "rightValue": "REGION_RESPONSE"
  }
}
```

**TRUE Branch**: Parse the response

```javascript
// Parse Region Selection node
const data = $json.body || $json;
const contentAttrs = data.content_attributes || {};
const interactive = contentAttrs.interactive_data?.data?.['quick-reply'] || {};

// Get value from interactive data (most reliable)
let region = 'unknown';
if (interactive.value) {
  const value = interactive.value.toLowerCase();
  if (value === 'americas') region = 'Americas';
  else if (value === 'emea') region = 'EMEA';
  else if (value === 'apac') region = 'APAC';
}

return {
  json: {
    accountId: data.conversation?.account_id,
    conversationId: data.conversation?.id,
    region: region
  }
};
```

---

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────┐
│ WORKFLOW RUN #1                                     │
├─────────────────────────────────────────────────────┤
│ User: "start"                                       │
│   ↓                                                 │
│ Webhook                                             │
│   ↓                                                 │
│ Router with State                                   │
│   ↓                                                 │
│ Welcome Messages                                    │
│   ↓                                                 │
│ AHA2 - Region Selection (Quick Reply)              │
│   ↓                                                 │
│ Set State: region_asked                             │
│   ↓                                                 │
│ [END] ← Workflow stops here                        │
└─────────────────────────────────────────────────────┘

        ⏸️  User selects "Americas"

┌─────────────────────────────────────────────────────┐
│ WORKFLOW RUN #2 (triggered by user's selection)    │
├─────────────────────────────────────────────────────┤
│ Webhook (receives Quick Reply response)            │
│   ↓                                                 │
│ Router with State                                   │
│   ├─ bot_state = 'region_asked'                    │
│   └─ route = 'REGION_RESPONSE'                     │
│   ↓                                                 │
│ Is Region Response? → TRUE                          │
│   ↓                                                 │
│ Parse Region Selection                              │
│   ├─ Extracts: region='Americas'                   │
│   ↓                                                 │
│ Update Region Attribute                             │
│   ↓                                                 │
│ AHA3 - Region Confirmation                          │
│   ↓                                                 │
│ Continue to next flow...                            │
└─────────────────────────────────────────────────────┘
```

---

## Common Interactive Messages & States

| Interactive Type | State Name | Route Name | Parse Logic |
|-----------------|------------|------------|-------------|
| **Quick Reply (Region)** | `region_asked` | `REGION_RESPONSE` | `interactive_data.quick-reply.value` |
| **Form (Help Me Decide)** | `form_shown` | `FORM_RESPONSE` | `interactive_data.form.items[]` |
| **List Picker (Guitar)** | `guitar_list_shown` | `GUITAR_RESPONSE` | `interactive_data.list-picker.selectedItems[]` |
| **Time Picker** | `time_picker_shown` | `TIME_RESPONSE` | `interactive_data.time-picker.selectedTime` |
| **Apple Pay** | `payment_request` | `PAYMENT_RESPONSE` | `interactive_data.apple-pay.status` |

---

## Fixing Other Interactive Messages

The same pattern applies to **ALL** interactive messages in the workflow:

### Guitar List Picker
```
1. Send Guitar List → Set State: guitar_list_shown → END
2. User selects guitar
3. Router detects state → GUITAR_RESPONSE
4. Parse Guitar Selection → Continue
```

### Time Picker
```
1. Send Time Picker → Set State: time_picker_shown → END
2. User selects time
3. Router detects state → TIME_RESPONSE
4. Parse Time Selection → Continue
```

### Apple Pay
```
1. Send Apple Pay → Set State: payment_request → END
2. User completes/cancels payment
3. Router detects state → PAYMENT_RESPONSE
4. Parse Payment Status → Continue
```

---

## Key Points to Remember

1. **Always set state** after sending interactive messages
2. **Always end workflow** after setting state (no outgoing connections)
3. **User's response triggers a NEW workflow run** via webhook
4. **Router must detect the state** and route accordingly
5. **Parse node extracts data from `content_attributes.interactive_data`**
6. **Update state after successful response** to prevent re-processing

---

## Region Selection - FIXED Implementation

### Nodes in Order:

1. **AHA2 - Region Selection** (CUSTOM.chatwootAMBQuickReply)
   - Sends Quick Reply with 3 options

2. **Set State: region_asked** (HTTP Request)
   - Sets `bot_state = "region_asked"`
   - No outgoing connections → Workflow ends

3. **Router with State** (Code)
   - Detects `bot_state === "region_asked"`
   - Routes to `REGION_RESPONSE`

4. **Is Region Response?** (If node)
   - Checks `route === "REGION_RESPONSE"`
   - TRUE → Parse Region Selection

5. **Parse Region Selection** (Code)
   - Extracts region from `interactive_data`
   - Returns: `{ region: 'Americas' }`

6. **Update Region Attribute** (HTTP Request)
   - Stores region in `custom_attributes`

7. **AHA3 - Region Confirmation** (HTTP Request)
   - Sends confirmation message
   - Continues to Form flow

---

## Testing the Fix

### Test 1: Region Selection

```
User: "start"
Bot: "Welcome to Acoustic House! 🎸"
Bot: "Where are you in the world?"
     [Americas] [EMEA] [APAC]

← Workflow ends here (wait for user)

User: Clicks "Americas"

← Webhook triggers again

Bot: "Thank you! Let's help you find your next guitar."
Bot: Shows "Help Me Decide" form
```

### Test 2: Check State in Database

After user selects region, verify:
```
custom_attributes.bot_state = "region_asked"
custom_attributes.region = "Americas"
```

---

## Next Steps

Apply this pattern to:
1. ✅ **Region Selection** (Fixed in FINAL-v2)
2. ⚠️ **Guitar List Picker** (Needs fixing)
3. ⚠️ **Time Picker** (Needs fixing)
4. ⚠️ **Apple Pay** (Needs fixing)
5. ⚠️ **All other interactive messages**

---

## File Reference

- **Fixed Workflow**: `Acoustic-House-Bot-FINAL-v2.json`
- **Fix Script**: `fix-state-machine.py`
- **Pattern**: Apply to all interactive messages

---

## Summary

**The Issue**: Parse nodes ran immediately after sending interactive messages.

**The Fix**:
1. Send message → Set state → END workflow
2. User responds → Webhook triggers
3. Router detects state → Parse response

**Result**: Now `region="Americas"` ✅ (not "unknown" ❌)
