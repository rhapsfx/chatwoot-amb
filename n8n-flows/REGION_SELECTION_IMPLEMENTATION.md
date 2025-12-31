# Region Selection Flow Implementation (AHA1, AHA2, AHA3)

## Overview
Implementation of the region selection onboarding flow from Acoustic House Bot Python code (lines 929-970).

## Python Reference Code Analysis

```python
def AHA1(usr):
    """ Step 1 """
    dbLastMessage(usr.userId, "AHA1-wait")
    sendMessage(AH_ID, usr.userId, findMsg("welcome_1", usr.lang))
    typingStart(AH_ID, usr.userId)
    sendMessage(AH_ID, usr.userId, "Before we begin, where are you in the world?")
    typingStart(AH_ID, usr.userId)
    sendInteractive(AH_ID, usr.userId, "qr_travel.json", usr.lang)
    dbLastMessage(usr.userId, "AHA2")

def AHA2(usr):
    dbLastMessage(usr.userId, "AHA2-wait")
    updateIntent(usr.userId, "")
    if usr.selection == 2:
        region = "APAC"
    elif usr.selection == 1:
        region = "EMEA"
    else:
        region = "Americas"
    updateRegion(usr.userId, region)
    dbLastMessage(usr.userId, "AHA3")
    AHA3(usr)

def AHA3(usr):
    dbLastMessage(usr.userId, "AHA3-wait")
    typingStart(AH_ID, usr.userId)
    sendMessage(AH_ID, usr.userId, "Thank you, let's help you find your next guitar:")
    typingStart(AH_ID, usr.userId)
    if "FORM" in str(usr.payload["capability-list"]):
        sendInteractive(AH_ID, usr.userId, "help_me_decide.json", usr.lang)
        dbLastMessage(usr.userId, "AHB1")
    else:
        sendMessage(AH_ID, usr.userId, "Looks like you are on a device that does not support forms, let's move on. What is your name?")
        dbLastMessage(usr.userId, "AHB1_2")
```

## n8n Implementation

### Nodes Required

#### 1. AHA1 State - Welcome & Region Question

**Node ID**: `aha1-welcome-msg`
- Type: HTTP Request (POST)
- Content: "Thanks for checking out Business Chat. This is an interactive demo. By the way, the info you share may be used to help us improve the Business Chat experience."
- Position: [800, -300]

**Node ID**: `aha1-ask-region`
- Type: HTTP Request (POST)
- Content: "Before we begin, where are you in the world?"
- Position: [1000, -300]

**Node ID**: `aha1-region-quick-reply`
- Type: CUSTOM.chatwootAMBQuickReply
- Template ID: 3 (reusing AR quick reply template)
- Summary Text: "Where are you in the world?"
- Items:
  - identifier: "region_americas", title: "Americas"
  - identifier: "region_emea", title: "EMEA"
  - identifier: "region_apac", title: "APAC"
- Position: [1000, -200]

#### 2. AHA2 State - Region Response Handler

**Node ID**: `aha2-parse-region`
- Type: Code (JavaScript)
- Purpose: Parse quick-reply identifier and map to region name
- Logic:
  ```javascript
  const identifier = contentAttrs.interactive_data?.data?.['quick-reply']?.identifier || '';

  // Map identifiers to regions (matching Python logic)
  let region = 'Americas'; // default (usr.selection == 0)
  if (identifier === 'region_apac') {
    region = 'APAC'; // usr.selection == 2
  } else if (identifier === 'region_emea') {
    region = 'EMEA'; // usr.selection == 1
  } else if (identifier === 'region_americas') {
    region = 'Americas'; // usr.selection == 0
  }
  ```
- Position: [1200, -200]

**Node ID**: `aha2-update-custom-attrs`
- Type: HTTP Request (POST)
- URL: `/api/v1/accounts/{accountId}/conversations/{conversationId}/custom_attributes`
- Body:
  - `custom_attributes[region]`: `={{ $json.region }}`
  - `custom_attributes[bot_state]`: `region_selected`
- Position: [1400, -200]

#### 3. AHA3 State - Route to Form or Text Input

**Node ID**: `aha3-intro-msg`
- Type: HTTP Request (POST)
- Content: "Thank you, let's help you find your next guitar:"
- Position: [1600, -200]

**Node ID**: `aha3-check-form-capability`
- Type: IF node
- Condition: Check if FORM capability exists
- Current Implementation: Always returns TRUE (hardcoded)
- Position: [1800, -200]
- TRUE path → Form flow (to be implemented)
- FALSE path → Text input flow

**Node ID**: `aha3-help-me-decide-form-placeholder`
- Type: NoOp (placeholder)
- Purpose: Placeholder for "Help Me Decide" form (AHB1 state)
- Position: [2000, -300]
- Notes: This will be implemented by another agent

**Node ID**: `aha3-no-form-ask-name`
- Type: HTTP Request (POST)
- Content: "Looks like you are on a device that does not support forms, let's move on. What is your name?"
- Position: [2000, -100]
- Notes: Routes to AHB1_2 state (text name input)

### Router Updates

The **Router with State** node already handles region selection:

```javascript
else if (contentAttrs.interactive_type === 'quick_reply') {
  const reply = contentAttrs.interactive_data?.data?.['quick-reply']?.identifier || '';

  if (reply.includes('region_')) {
    route = 'REGION_SELECTED';
    nextState = 'region_selected';
  }
  // ... other quick reply handlers
}
```

Boolean flags added:
- `isRegionSelected`: true when route === 'REGION_SELECTED'

### Connection Flow

```
1. Is Welcome? (TRUE)
   → AHA1 Welcome Message
   → AHA1 Ask Region
   → AHA1 Region Selection Quick Reply

2. User selects region (quick-reply webhook received)
   → Router detects quick-reply with 'region_' prefix
   → Routes to REGION_SELECTED

3. Is Region Selected? (TRUE)
   → AHA2 Parse Region Selection
   → AHA2 Update Custom Attributes (stores region + bot_state)
   → AHA3 Intro Message
   → AHA3 Check Form Capability

4. Form Capability Check:
   - TRUE → TODO: Help Me Decide Form (AHB1)
   - FALSE → AHA3 Ask Name (No Form) (AHB1_2)
```

### Check Node in Router Chain

New check node added:

**Node ID**: `check-region-selected`
- Type: IF node
- Condition: `{{ $json.isRegionSelected }} === true`
- Position: In router chain between `Is Features?` and `Is Name Collected?`
- TRUE → `AHA2 Parse Region Selection`
- FALSE → Continue to next check

## State Management

### Bot States
- `welcomed` → User saw welcome message (AHA1)
- `region_selected` → User selected region (AHA2)
- `form_shown` → User saw "Help Me Decide" form (AHB1)
- `name_requested` → User was asked for name via text (AHB1_2)

### Custom Attributes Stored
- `region`: "Americas" | "EMEA" | "APAC"
- `bot_state`: Current state in the flow

## Testing Checklist

1. **AHA1 Flow**:
   - [ ] Send "start" message
   - [ ] Verify welcome message appears
   - [ ] Verify "Before we begin..." message appears
   - [ ] Verify quick reply with 3 region options appears

2. **AHA2 Flow**:
   - [ ] Select "Americas" → verify region="Americas" stored
   - [ ] Select "EMEA" → verify region="EMEA" stored
   - [ ] Select "APAC" → verify region="APAC" stored
   - [ ] Verify bot_state="region_selected" stored

3. **AHA3 Flow**:
   - [ ] After region selection, verify intro message appears
   - [ ] If FORM capability: verify form is shown (future implementation)
   - [ ] If NO FORM capability: verify name question appears

## Future Work

- Implement "Help Me Decide" form (AHB1 state)
- Handle form response parsing
- Implement name selection logic (AHB2 state)
- Connect to Guitar List flow

## Notes

- Template ID 3 is reused for region selection quick reply (same as AR quick reply)
- In production, you may want to create a dedicated template for region selection
- The form capability check is currently hardcoded to TRUE (assumes forms are always available)
- To add dynamic form capability detection, parse `data.conversation.inbox.capability_list` from webhook
