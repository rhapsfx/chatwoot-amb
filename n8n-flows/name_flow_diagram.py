"""
Name Collection Flow - Visual Diagram
=====================================

ASCII Flowchart showing the complete name collection implementation
"""

print("""
╔═══════════════════════════════════════════════════════════════════════════════════╗
║                        NAME COLLECTION FLOW (AHB1, AHB2, AHB1_2, AHB3)            ║
╚═══════════════════════════════════════════════════════════════════════════════════╝


ENTRY POINT
-----------
                                    [Webhook]
                                        |
                                        v
                              [Router with State]
                                        |
                                        v
                                [Should Process?]
                                        |
                         ┌──────────────┴──────────────┐
                         v                             v
                    [TRUE]                          [FALSE]
                         |                             |
                         v                             v
        [Chain of IF checks...]              [Skip - NoOp]
                         |
                         v
        ┌────────────────┴────────────────┐
        v                                  v
  [Is Welcome?]                      [Is Menu?]
        |                                  |
        v                                  v
  [Is Guitar?]                       [Is AR?]
        |                                  |
        v                                  v
  [Is Payment?]                      [Is Time?]
        |                                  |
        v                                  v
  [Is Confirm?]                      [Is Location?]
        |                                  |
        v                                  v
  [Is Features?]              [Is Region Selected?] ◄── NEW!
        |                                  |
        v                                  |
  [Unknown]                                |
                                          v
                          ┌───────────────┴───────────────┐
                          v                               v
                    [TRUE Path]                    [FALSE Path]
        (Region just selected,                (Check next route)
         await form submission)                      |
                          |                           v
                          |                  [Is Name Collected?] ◄── NEW!
                          |                           |
                          |                           |
                          |         ┌─────────────────┴─────────────────┐
                          |         v                                   v
                          |   [TRUE Path]                          [FALSE Path]
                          |  (Form submitted)                    (Check next route)
                          |         |                                   |
                          └─────────┘                                   v
                                    |                      [Is Name Selected?] ◄── NEW!
                                    |                                   |
                                    v                                   |
                      [AHB1: Parse Form Response] ◄── NEW!             |
                                    |                                   |
              Extract: userName, stageName                             |
                                    |                   ┌───────────────┴───────────────┐
                                    v                   v                               v
                          [Has Stage Name?] ◄── NEW!  [TRUE Path]                 [FALSE Path]
                                    |             (QR response)                  (Unhandled)
                    ┌───────────────┴───────────────┐         |                         |
                    v                               v         v                         v
              [YES Path]                      [NO Path]  [AHB2: Select Name] ◄── NEW! [Unknown]
        (Stage name provided)          (Only real name)       |                    (Route end)
                    |                               |         |
                    v                               |         |
      [AHB2: Ask Name Preference] ◄── NEW!         |         |
                    |                               |         |
  Message: "How would you like                     |         |
           to be addressed?"                        |         |
                    |                               |         |
                    v                               |         |
   [AHB2: Name Selection QR] ◄── NEW!              |         |
                    |                               |         |
    Options: "Use my name" (name_real)             |         |
             "Use stage name" (name_stage)          |         |
                    |                               |         |
           [User selects option]                    |         |
                    |                               |         |
                    v                               |         |
              [Router detects                       |         |
             NAME_SELECTED route]                   |         |
                    |                               |         |
                    v                               |         |
     [Is Name Selected?] = TRUE ─────────────────→─┘         |
                                                              |
                                                              v
                                        [Update Name Attributes] ◄── NEW!
                                                              |
                              Store in custom_attributes:     |
                                  - user_name                 |
                                  - stage_name                |
                                  - selected_name             |
                                                              |
                                                              v
                                    [AHB3: Personalized Greeting] ◄── NEW!
                                                              |
                      Message: "Hello {{name}}. We have      |
                               some cool guitars we would     |
                               like you to see."              |
                                                              |
                                                              v
                                             [AMB Guitar List] (existing)
                                                              |
                                        (Continue to AR, Payment, etc.)


ALTERNATIVE PATH: Text Input Fallback (when form not available)
----------------------------------------------------------------

                                [User types name directly]
                                             |
                                             v
                              [Router: state-based detection]
                                             |
                                             v
                          [AHB1_2: Parse Text Name] ◄── NEW!
                                             |
                       Capitalize first letter of text
                                             |
                                             v
                                [Update Name Attributes]
                                             |
                                             v
                           [AHB3: Personalized Greeting]
                                             |
                                             v
                                    [AMB Guitar List]


KEY COMPONENTS
--------------

┌─────────────────────────────────────────────────────────────────────────────────┐
│ ROUTING NODES (IF checks)                                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│  • Is Region Selected?    - Detects region selection quick reply                │
│  • Is Name Collected?     - Detects form submission with name data              │
│  • Is Name Selected?      - Detects name preference quick reply                 │
│  • Has Stage Name?        - Checks if stage name provided in form               │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│ PROCESSING NODES (Code)                                                         │
├─────────────────────────────────────────────────────────────────────────────────┤
│  • AHB1: Parse Form Response  - Extract userName and stageName from form        │
│  • AHB2: Select Name          - Choose between real name and stage name         │
│  • AHB1_2: Parse Text Name    - Process text input as name (capitalize)         │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│ INTERACTION NODES (HTTP/Custom)                                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│  • AHB2: Ask Name Preference       - Send question message                      │
│  • AHB2: Name Selection QR         - Present quick reply options                │
│  • Update Name Attributes          - Store name data in conversation            │
│  • AHB3: Personalized Greeting     - Send personalized welcome message          │
└─────────────────────────────────────────────────────────────────────────────────┘


DATA FLOW EXAMPLE
-----------------

Step 1: Form Submission
┌──────────────────────────────────────────────────────────────┐
│ Form Fields:                                                  │
│   [1] ... (other fields)                                      │
│   [4] Name:       "John"                                      │
│   [5] Stage Name: "JRock"                                     │
└──────────────────────────────────────────────────────────────┘
                    ↓
Step 2: Parse Form Response
┌──────────────────────────────────────────────────────────────┐
│ {                                                             │
│   userName: "John",                                           │
│   stageName: "JRock",                                         │
│   hasStageName: true                                          │
│ }                                                             │
└──────────────────────────────────────────────────────────────┘
                    ↓
Step 3: Ask Preference (because hasStageName = true)
┌──────────────────────────────────────────────────────────────┐
│ Message: "How would you like to be addressed?"               │
│                                                               │
│ Quick Reply Options:                                          │
│   [ Use my name ]  identifier: name_real                      │
│   [ Use stage name ]  identifier: name_stage                  │
└──────────────────────────────────────────────────────────────┘
                    ↓
Step 4: User Selects "Use stage name"
┌──────────────────────────────────────────────────────────────┐
│ {                                                             │
│   identifier: "name_stage"                                    │
│ }                                                             │
└──────────────────────────────────────────────────────────────┘
                    ↓
Step 5: Select Name
┌──────────────────────────────────────────────────────────────┐
│ {                                                             │
│   selectedName: "JRock",  // from stage_name                 │
│   nameSelection: "name_stage"                                 │
│ }                                                             │
└──────────────────────────────────────────────────────────────┘
                    ↓
Step 6: Update Custom Attributes
┌──────────────────────────────────────────────────────────────┐
│ custom_attributes: {                                          │
│   user_name: "John",                                          │
│   stage_name: "JRock",                                        │
│   selected_name: "JRock"                                      │
│ }                                                             │
└──────────────────────────────────────────────────────────────┘
                    ↓
Step 7: Personalized Greeting
┌──────────────────────────────────────────────────────────────┐
│ "Hello JRock. We have some cool guitars we would like        │
│  you to see."                                                 │
└──────────────────────────────────────────────────────────────┘
                    ↓
Step 8: Show Guitar List (existing flow continues)


STATE TRANSITIONS
-----------------

region_selected
       ↓
  (form submitted)
       ↓
name_collected
       ↓
  (has stage name?)
       ↓                ↓
  YES                 NO
       ↓                ↓
awaiting_name_     name_confirmed
preference             ↓
       ↓                ↓
  (name selected)       ↓
       ↓                ↓
name_selected ─────────→┘
       ↓
  (greeting sent)
       ↓
guitar_list_shown


INTEGRATION SUMMARY
-------------------

Entry Points:
  1. Form submission after region selection (primary path)
  2. Text input after region selection (fallback path)
  3. Name preference quick reply (secondary path)

Exit Points:
  1. AMB Guitar List (template 329) - main continuation
  2. Unknown Route - for unhandled cases

Stored Data:
  • custom_attributes.user_name      - Real name from form
  • custom_attributes.stage_name     - Stage name from form (optional)
  • custom_attributes.selected_name  - Final name to use
  • custom_attributes.bot_state      - Current conversation state

""")
