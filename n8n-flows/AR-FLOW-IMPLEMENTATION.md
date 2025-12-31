# Complete AR Flow Implementation for Acoustic House Bot

## Overview
This document describes the complete two-question AR flow implementation based on the Python code (AH.py lines 1037-1087).

## Flow Architecture

### State Machine
```
Guitar Selected
  ↓
AHC2: Send AR Introduction & File
  ↓
AHC3: Ask "Did you view AR?" (First Question)
  ↓  Set state: ar_view_asked
  ├─ Yes (111/ar_view_yes) → AHD1_YES
  │   ↓
  │   Send: "Awesome! Did you place AR?"
  │   ↓
  │   Ask Second Question → Set state: ar_place_asked
  │
  └─ No (222/ar_view_no) → AHD1_NO
      ↓
      Send: "Try tapping on the image..."
      ↓
      Send: "Did you place AR?"
      ↓
      Ask Second Question → Set state: ar_place_asked

Both paths converge to:
  ↓
AHE1: Handle Second AR Response
  ├─ Yes (111/ar_place_yes) → Continue to Apple Pay
  └─ No (222/ar_place_no) → Send instruction, then Apple Pay

Final:
  ↓
Send: "Great, let's buy your new guitar."
  ↓
Apple Pay Request
```

## Implementation Changes Required

### 1. Router Node Updates (COMPLETED)
- ✅ Added state-aware quick reply handling
- ✅ Added `botState` to return object
- ✅ Added new route flags: `isARViewYes`, `isARViewNo`, `isARPlaceYes`, `isARPlaceNo`
- ✅ Removed old flags: `isAR`, `isARYes`, `isARNo`

### 2. Node Routing Chain Updates (NEEDED)

#### Remove Old Nodes:
- ❌ "Is AR?" node (check-ar)
- ❌ "Parse AR Response" node (parse-ar-response)
- ❌ "Is AR Yes?" node (check-ar-yes)
- ❌ "AR No Message" node (ar-no-message)
- ❌ Old "AMB AR Prompt" node (ar-prompt)
- ❌ Old "Send AR File" node (send-ar-file)

#### Add New Nodes:

**After "Send Guitar Image" node:**

1. **"AR Introduction"** (HTTP Request)
   - Content: "Just in. We have this cool Stratocaster. Check it out!!!"
   - Position: [1650, -200]

2. **"Send AR File"** (Template Message)
   - Template ID: 344 (stratocaster.usdz)
   - Position: [1800, -200]

3. **"First AR Question"** (HTTP Request)
   - Content: "Did you click on the image and see the 3D augmented reality view of the guitar? (Yes | No)"
   - Position: [1950, -200]

4. **"AR View Question"** (Quick Reply)
   - Items:
     - identifier: ar_view_yes, title: "Yes"
     - identifier: ar_view_no, title: "No"
   - Position: [2100, -200]

5. **"Set State: ar_view_asked"** (HTTP Request)
   - Update conversation custom_attributes
   - Set bot_state = "ar_view_asked"
   - Position: [2250, -200]

**After Router detects AR View Response:**

6. **"Check AR View Response?"** (IF node)
   - Condition: isARViewYes OR isARViewNo
   - Position: [1200, 0] (replace old check-ar)

7. **"Did View AR?"** (IF node)
   - Condition: isARViewYes === true
   - Position: [1350, -300]
   - TRUE path → "AR View Success"
   - FALSE path → "AR View Instruction"

8. **"AR View Success"** (HTTP Request)
   - Content: "Awesome! Did you select AR from the top of the image and set it down in front of you? (Yes | No)"
   - Position: [1500, -400]

9. **"AR View Instruction"** (HTTP Request)
   - Content: "Try tapping on the image to see the AR image of the guitar!"
   - Position: [1500, -200]

10. **"Second AR Question (After No)"** (HTTP Request)
    - Content: "Did you select AR from the top of the image and set it down in front of you? (Yes | No)"
    - Position: [1650, -300]

11. **"AR Place Question"** (Quick Reply)
    - Items:
      - identifier: ar_place_yes, title: "Yes"
      - identifier: ar_place_no, title: "No"
    - Position: [1800, -300]
    - Both paths converge here

12. **"Set State: ar_place_asked"** (HTTP Request)
    - Update conversation custom_attributes
    - Set bot_state = "ar_place_asked"
    - Position: [1950, -300]

**After Router detects AR Place Response:**

13. **"Check AR Place Response?"** (IF node)
    - Condition: isARPlaceYes OR isARPlaceNo
    - Position: [1400, 0]

14. **"Did Place AR?"** (IF node)
    - Condition: isARPlaceNo === true (note: checking for NO)
    - Position: [1550, -400]
    - TRUE path (No) → "AR Place Instruction"
    - FALSE path (Yes) → "Apple Pay Transition"

15. **"AR Place Instruction"** (HTTP Request)
    - Content: "Try tapping on the image to see the AR image of the guitar!"
    - Position: [1700, -500]
    - Connects to → "Apple Pay Transition"

16. **"Apple Pay Transition"** (HTTP Request)
    - Content: "Great, let's buy your new guitar."
    - Position: [1850, -400]
    - Connects to → "AMB Apple Pay Request"

### 3. Connection Updates

**Linear Flow (Happy Path):**
```
Send Guitar Image
→ AR Introduction
→ Send AR File
→ First AR Question
→ AR View Question
→ Set State: ar_view_asked
[User responds, webhook triggers with bot_state="ar_view_asked"]
→ Router detects isARViewYes or isARViewNo
→ Check AR View Response? [TRUE]
→ Did View AR?
  ├─ TRUE: AR View Success → AR Place Question
  └─ FALSE: AR View Instruction → Second AR Question → AR Place Question
→ Set State: ar_place_asked
[User responds, webhook triggers with bot_state="ar_place_asked"]
→ Router detects isARPlaceYes or isARPlaceNo
→ Check AR Place Response? [TRUE]
→ Did Place AR?
  ├─ TRUE (they said No): AR Place Instruction → Apple Pay Transition
  └─ FALSE (they said Yes): Apple Pay Transition
→ AMB Apple Pay Request
```

**Router Cascading IF Chain:**
```
Should Process? [TRUE]
→ Is Welcome? [FALSE]
→ Is Menu? [FALSE]
→ Is Guitar? [FALSE]
→ Check AR View Response? [if AR view response]
→ Check AR Place Response? [if AR place response]
→ Is Payment? [FALSE]
→ Is Time? [FALSE]
→ Is Confirm? [FALSE]
→ Is Location? [FALSE]
→ Is Features? [FALSE]
→ Is Region Selected? [FALSE]
→ Is Name Collected? [FALSE]
→ Is Name Selected? [FALSE]
→ Unknown Route
```

### 4. State Management

**Conversation Custom Attributes:**
- `bot_state`: Current state of the AR flow
  - Values: `null` → `ar_view_asked` → `ar_place_asked` → cleared after Apple Pay

**State Transitions:**
1. Guitar selected → Send AR content → Set `ar_view_asked`
2. User responds to first question → Check state, route accordingly → Set `ar_place_asked`
3. User responds to second question → Check state, route accordingly → Continue to payment

### 5. Quick Reply Identifiers

**First Question (AR View):**
- Yes: `ar_view_yes` or `111` (for compatibility with Python bot)
- No: `ar_view_no` or `222`

**Second Question (AR Place):**
- Yes: `ar_place_yes` or `111`
- No: `ar_place_no` or `222`

## Implementation Status

✅ **Phase 1: Router Logic** (COMPLETED)
- Updated quick reply handling to be state-aware
- Added new route flags for four AR responses
- Added botState to context

❌ **Phase 2: Node Structure** (PENDING)
- Need to remove old AR nodes
- Need to add 16 new nodes for complete flow
- Need to update all connections

❌ **Phase 3: Testing** (PENDING)
- Test first question flow (both Yes/No paths)
- Test second question flow (both Yes/No paths)
- Verify state transitions
- Verify Apple Pay integration

## Python Code Reference

**AHC2 (lines 1037-1046):** Send AR introduction + file
**AHC3 (lines 1048-1054):** First AR question
**AHD1 (lines 1056-1071):** Handle first response + ask second question
**AHE1 (lines 1073-1087):** Handle second response + transition to Apple Pay

## Next Steps

1. ✅ Update Router logic (DONE)
2. Add 16 new nodes to workflow JSON
3. Remove 6 old AR nodes
4. Update connection mappings
5. Test end-to-end AR flow
6. Deploy to n8n instance

## Notes

- Template ID 344 contains the stratocaster.usdz AR file
- Template ID 3 is the Quick Reply template
- All HTTP requests need Chatwoot Bot API credentials
- State management is critical for proper routing
- The Python bot uses numeric identifiers (111/222) but we use descriptive ones for clarity
