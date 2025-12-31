# Region Selection Flow - State Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         ACOUSTIC HOUSE BOT                       │
│                     Region Selection Flow (AHA)                  │
└─────────────────────────────────────────────────────────────────┘

                            USER SENDS
                            "start"
                               │
                               ▼
                     ┌──────────────────┐
                     │   Is Welcome?    │
                     │   (IF node)      │
                     └────────┬─────────┘
                              │ TRUE
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                       AHA1 STATE                                │
│  Purpose: Welcome user and ask for region                      │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [1] AHA1 Welcome Message                                      │
│      → "Thanks for checking out Business Chat..."              │
│                                                                 │
│  [2] AHA1 Ask Region                                           │
│      → "Before we begin, where are you in the world?"          │
│                                                                 │
│  [3] AHA1 Region Selection (Quick Reply)                       │
│      → Options:                                                 │
│         • Americas (identifier: region_americas)                │
│         • EMEA (identifier: region_emea)                        │
│         • APAC (identifier: region_apac)                        │
│                                                                 │
│  State: bot_state = "welcomed"                                 │
└────────────────────────────────────────────────────────────────┘
                              │
                              │ USER SELECTS REGION
                              │ (quick-reply webhook)
                              ▼
                     ┌──────────────────┐
                     │  Router detects  │
                     │  quick-reply     │
                     │  with region_*   │
                     └────────┬─────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │ Is Region Selected?   │
                  │   (IF node)           │
                  └─────────┬─────────────┘
                            │ TRUE
                            ▼
┌────────────────────────────────────────────────────────────────┐
│                       AHA2 STATE                                │
│  Purpose: Parse region selection and store it                  │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [1] AHA2 Parse Region Selection (Code node)                   │
│      Logic:                                                     │
│        if (identifier === 'region_apac') {                      │
│          region = 'APAC';                                       │
│        } else if (identifier === 'region_emea') {               │
│          region = 'EMEA';                                       │
│        } else {                                                 │
│          region = 'Americas'; // default                        │
│        }                                                         │
│                                                                 │
│  [2] AHA2 Update Custom Attributes (HTTP Request)              │
│      → custom_attributes[region] = region                       │
│      → custom_attributes[bot_state] = "region_selected"         │
│                                                                 │
│  State: bot_state = "region_selected"                          │
│  Data: region = "Americas" | "EMEA" | "APAC"                   │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                       AHA3 STATE                                │
│  Purpose: Route to form or text input based on capability      │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [1] AHA3 Intro Message                                        │
│      → "Thank you, let's help you find your next guitar:"      │
│                                                                 │
│  [2] AHA3 Check Form Capability (IF node)                      │
│      Condition: Check if "FORM" in capability-list              │
│      (Currently hardcoded to TRUE)                              │
│                                                                 │
└─────────────────┬──────────────────────────────┬───────────────┘
                  │                              │
         TRUE (Form Available)       FALSE (No Form Support)
                  │                              │
                  ▼                              ▼
    ┌─────────────────────────┐    ┌──────────────────────────┐
    │ TODO: Help Me Decide    │    │ AHA3 Ask Name (No Form)  │
    │ Form (AHB1)             │    │ "What is your name?"     │
    │                         │    │                          │
    │ → Placeholder node      │    │ State: AHB1_2            │
    │ → To be implemented     │    └──────────────────────────┘
    │   by another agent      │                │
    └─────────────────────────┘                │
                  │                              │
                  │                              │ USER TYPES NAME
                  │ USER SUBMITS FORM            │
                  │                              │
                  ▼                              ▼
    ┌─────────────────────────┐    ┌──────────────────────────┐
    │ AHB1 - Parse Form       │    │ Parse Text Name Input    │
    │ Response                │    │ (Future implementation)  │
    │                         │    └──────────────────────────┘
    │ → Extract name          │                │
    │ → Extract stage name    │                │
    │   (if provided)         │                │
    └─────────────────────────┘                │
                  │                              │
                  │                              │
                  ▼                              ▼
    ┌─────────────────────────────────────────────────────────┐
    │              Continue to Guitar Selection                │
    │              (Next state in workflow)                    │
    └─────────────────────────────────────────────────────────┘


LEGEND:
┌────────┐
│ State  │  = State block (AHA1, AHA2, AHA3)
└────────┘

┌────────┐
│  Node  │  = Individual n8n node
└────────┘

    │
    ▼       = Flow direction

TRUE / FALSE = Conditional branch
```

## Data Flow

```
INPUT:  User message "start"
        ↓
OUTPUT: "Thanks for checking out Business Chat..." (AHA1)
        ↓
OUTPUT: "Before we begin, where are you in the world?" (AHA1)
        ↓
OUTPUT: Quick Reply with [Americas, EMEA, APAC] (AHA1)
        ↓
INPUT:  User selects region (e.g., "EMEA")
        ↓
PROCESS: Parse identifier "region_emea" → region = "EMEA" (AHA2)
        ↓
STORE:  custom_attributes { region: "EMEA", bot_state: "region_selected" }
        ↓
OUTPUT: "Thank you, let's help you find your next guitar:" (AHA3)
        ↓
CHECK:  Form capability available?
        ↓
OUTPUT: [TRUE] → Form UI (AHB1 - Future)
        [FALSE] → "What is your name?" (AHB1_2)
```

## Node Positions (Canvas Layout)

```
                                    [0, 0]
                                    Webhook
                                       │
                                    [200, 0]
                                Router with State
                                       │
                                    [400, 0]
                                Should Process?
                                       │
                    ┌──────────────────┴──────────────────┐
                    │ TRUE                          FALSE │
                 [600, 0]                           [600, 600]
              Is Welcome?                              Skip
                    │
        ┌───────────┴───────────┐
        │ TRUE            FALSE │
    [800, -300]         [800, 0]
  AHA1 Welcome        Continue to
    Message           Is Region
        │             Selected?
   [1000, -300]           │
  AHA1 Ask Region   [Continue chain]
        │
   [1000, -200]
  AHA1 Region
  Selection QR
        │
     (User selects)
        │
        └─────────────────────────────────────────┐
                                                   │
        [Router routes to REGION_SELECTED]        │
                                                   │
        [Check chain continues...]                 │
                                                   │
        [800, 0] → [1000, 0] → [1200, 0] →        │
        Is Menu?   Is Guitar?  Is AR? ... →       │
                                                   │
        → [2600, 0]                                │
        Is Region Selected? ◄──────────────────────┘
                │
           TRUE │
                ▼
         [1200, -200]
      AHA2 Parse Region
                │
         [1400, -200]
    AHA2 Update Custom Attrs
                │
         [1600, -200]
      AHA3 Intro Message
                │
         [1800, -200]
  AHA3 Check Form Capability
                │
        ┌───────┴───────┐
        │ TRUE    FALSE │
   [2000, -300]   [2000, -100]
   Help Me        Ask Name
   Decide Form    (No Form)
   (Placeholder)
```

## State Transitions

| From State | Event | To State | Action |
|-----------|-------|----------|--------|
| `null` | User sends "start" | `welcomed` | Show welcome + region question |
| `welcomed` | User selects region | `region_selected` | Store region in custom_attributes |
| `region_selected` | Form capability check (TRUE) | `form_shown` | Show "Help Me Decide" form (AHB1) |
| `region_selected` | Form capability check (FALSE) | `name_requested` | Ask for name via text (AHB1_2) |
| `form_shown` | User submits form | `name_collected` | Parse form data (AHB1) |
| `name_requested` | User types name | `name_collected` | Parse text input (AHB1_2) |
| `name_collected` | Continue flow | `guitar_list` | Show guitar catalog |

## Custom Attributes Schema

```javascript
conversation.custom_attributes = {
  // Set in AHA2
  region: "Americas" | "EMEA" | "APAC",

  // State tracking
  bot_state: "welcomed" | "region_selected" | "form_shown" | "name_requested" | "name_collected",

  // Set in AHB1 (future)
  user_name: string,
  stage_name: string | null,
  selected_name: string
}
```
