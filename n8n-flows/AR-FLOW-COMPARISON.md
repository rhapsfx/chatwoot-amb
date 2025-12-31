# AR Flow Node Replacement Diagram

## BEFORE (Simple Single-Question AR Flow)

```
Send Guitar Image
       ↓
AMB AR Prompt (ar-prompt)
"Would you like to see this guitar in AR?"
[Yes, show me!] [No thanks]
       ↓
Parse AR Response (parse-ar-response)
       ↓
Is AR Yes? (check-ar-yes)
       ├─ YES → Send AR File (send-ar-file) ──→ Apple Pay
       └─ NO → AR No Message (ar-no-message) ─→ Apple Pay

Old Router Check:
  Is AR? (check-ar) [deprecated]

OLD NODES REMOVED (6):
  ❌ ar-prompt
  ❌ parse-ar-response
  ❌ check-ar-yes
  ❌ send-ar-file
  ❌ ar-no-message
  ❌ check-ar
```

## AFTER (Complete Two-Question AR Flow)

```
Send Guitar Image
       ↓
═══════════════════════════════════════════
       AHC2: SEND AR FILE
═══════════════════════════════════════════
       ↓
AR Introduction (ar-introduction) NEW
"Just in. We have this cool Stratocaster..."
       ↓
Send AR File (send-ar-file) NEW
Template 344: stratocaster.usdz
       ↓
═══════════════════════════════════════════
       AHC3: FIRST QUESTION
═══════════════════════════════════════════
       ↓
First AR Question (first-ar-question) NEW
"Did you click on the image and see the 3D AR view?"
       ↓
AR View Question (ar-view-question) NEW
Quick Reply: [Yes] [No]
       ↓
Set State: ar_view_asked (set-state-ar-view-asked) NEW
       ↓
[New Webhook Event] → Router
       ↓
═══════════════════════════════════════════
       ROUTER INTEGRATION
═══════════════════════════════════════════
       ↓
Is AR View Response? (check-ar-view-response) NEW
       ↓
═══════════════════════════════════════════
       AHD1: FIRST RESPONSE HANDLER
═══════════════════════════════════════════
       ↓
Did View AR? (did-view-ar) NEW
       ├─ YES → AR View Success (ar-view-success) NEW
       │        "Awesome! Did you select AR..."
       │        ↓
       │        AR Place Question
       │
       └─ NO → AR View Instruction (ar-view-instruction) NEW
               "Try tapping on the image..."
                ↓
               Second AR Question (second-ar-question-after-no) NEW
               "Did you select AR from the top..."
                ↓
                AR Place Question

       ↓ [Both paths converge]

AR Place Question (ar-place-question) NEW
Quick Reply: [Yes] [No]
       ↓
Set State: ar_place_asked (set-state-ar-place-asked) NEW
       ↓
[New Webhook Event] → Router
       ↓
═══════════════════════════════════════════
       ROUTER INTEGRATION
═══════════════════════════════════════════
       ↓
Is AR Place Response? (check-ar-place-response) NEW
       ↓
═══════════════════════════════════════════
       AHE1: SECOND RESPONSE HANDLER
═══════════════════════════════════════════
       ↓
Did Place AR? (did-place-ar) NEW
       ├─ YES (user said No) → AR Place Instruction (ar-place-instruction) NEW
       │                       "Try tapping on the image..."
       │                       ↓
       │                       Apple Pay Transition
       │
       └─ NO (user said Yes) → Apple Pay Transition

       ↓ [Both paths converge]

Apple Pay Transition (apple-pay-transition) NEW
"Great, let's buy your new guitar."
       ↓
AMB Apple Pay Request
(Existing node, unchanged)

NEW NODES ADDED (16):
  ✅ ar-introduction
  ✅ send-ar-file (replacement)
  ✅ first-ar-question
  ✅ ar-view-question
  ✅ set-state-ar-view-asked
  ✅ check-ar-view-response
  ✅ did-view-ar
  ✅ ar-view-success
  ✅ ar-view-instruction
  ✅ second-ar-question-after-no
  ✅ ar-place-question
  ✅ set-state-ar-place-asked
  ✅ check-ar-place-response
  ✅ did-place-ar
  ✅ ar-place-instruction
  ✅ apple-pay-transition
```

## Router Cascade Changes

### BEFORE:
```
Is Guitar? [FALSE]
  ↓
Is AR? (check-ar) [deprecated]
  ↓
Is Payment? [FALSE]
```

### AFTER:
```
Is Guitar? [FALSE]
  ↓
Is AR View Response? (check-ar-view-response) NEW
  ↓
Is AR Place Response? (check-ar-place-response) NEW
  ↓
Is Payment? [FALSE]
```

## State Management

### BEFORE:
- No state tracking
- Single question, immediate response
- No conversation context preserved

### AFTER:
- State-aware routing
- Two questions with context preserved
- Conversation states:
  * `null` → Initial state
  * `ar_view_asked` → After first question
  * `ar_place_asked` → After second question
  * `null` → Cleared after Apple Pay

## Quick Reply Identifiers

### BEFORE:
- `ar_yes` → Send AR file
- `ar_no` → Skip

### AFTER:
- First Question:
  * `ar_view_yes` or `111` → Yes, viewed AR
  * `ar_view_no` or `222` → No, didn't view AR

- Second Question:
  * `ar_place_yes` or `111` → Yes, placed AR
  * `ar_place_no` or `222` → No, didn't place AR

## Conversation Paths

### BEFORE (1 path):
```
Guitar → AR Prompt → Yes/No → Apple Pay
```

### AFTER (4 paths):
```
Path 1: Guitar → AR File → Q1:Yes → Q2:Yes → Apple Pay
Path 2: Guitar → AR File → Q1:Yes → Q2:No → Instruction → Apple Pay
Path 3: Guitar → AR File → Q1:No → Instruction → Q2:Yes → Apple Pay
Path 4: Guitar → AR File → Q1:No → Instruction → Q2:No → Instruction → Apple Pay
```

## Summary of Changes

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Total Nodes | 41 | 51 | +10 |
| AR-related Nodes | 6 | 16 | +10 |
| Questions Asked | 1 | 2 | +1 |
| Instruction Messages | 1 | 3 | +2 |
| State Tracking | No | Yes | ✅ |
| Conversation Paths | 1 | 4 | +3 |
| Matches Python Bot | ❌ | ✅ | ✅ |
