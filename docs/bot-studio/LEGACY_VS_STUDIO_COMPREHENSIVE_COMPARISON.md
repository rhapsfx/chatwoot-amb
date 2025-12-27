# Legacy vs Studio: Comprehensive Bot Flow Comparison

**Document Version**: 1.0
**Date**: December 26, 2025
**Comparison**: Legacy `AcousticHouseBotService` vs Bot Studio Flow #5

---

## Executive Summary

### Current State Assessment

| Aspect | Legacy Service | Studio Flow #5 | Gap Severity |
|--------|---------------|----------------|--------------|
| **Lines of Code** | 4,115 lines | N/A (visual) | - |
| **States** | 30+ states (AHA1-AHK3) | 11 state nodes | 🔴 **CRITICAL** |
| **Conversation Flow** | Full conversational experience | Simple demo only | 🔴 **CRITICAL** |
| **Retry Logic** | Progressive retry with auto-select | None | 🔴 **CRITICAL** |
| **Timeout Handling** | 30-min idle auto-reset | None | 🔴 **CRITICAL** |
| **Error Recovery** | Comprehensive catchers | None | 🔴 **CRITICAL** |
| **Regional Features** | Region-based customization | Basic region storage only | 🟡 **HIGH** |
| **Templates** | 6 required templates | 8 bot action templates | 🟡 **HIGH** |
| **Idempotency** | Redis-based deduplication | None | 🟡 **HIGH** |

### Implementation Effort

**Estimated Timeline**: 6-8 weeks full-time development

**Complexity Breakdown**:
- **Phase 1 - Core Flow** (2 weeks): States, transitions, basic handlers
- **Phase 2 - Advanced Features** (2 weeks): Retry logic, timeout, error handling
- **Phase 3 - Integration** (2 weeks): Maps, OAuth, idempotency
- **Phase 4 - Testing & Refinement** (2 weeks): End-to-end testing, edge cases

---

## 1. Legacy Service Complete Flow Analysis

### 1.1 State Machine Architecture

The legacy service implements a sophisticated state machine with **30+ states** organized into logical phases:

#### State Categories

**Phase A - Welcome & Region Selection (AHA1-AHA3)**
```
AHA1: Welcome state (entry point)
AHA2: Region prompt (quick reply)
AHA3: Form or name prompt (device capability check)
```

**Phase B - Name Collection (AHB1-AHB3)**
```
AHB1: Form response handler
AHB1_2: Text name input (fallback for non-form devices)
AHB2: Name preference selection
AHB3: Guitar list prompt
```

**Phase C - Guitar Selection & AR (AHC1-AHC3)**
```
AHC1: Guitar selection catcher (retry logic)
AHC2: AR introduction
AHC3: AR first question
```

**Phase D - AR Interaction (AHD1, AHE1-AHE2)**
```
AHD1: AR view response catcher
AHE1: AR place response catcher
AHE2: Apple Pay prompt
```

**Phase F - Payment (AHF1-AHF3)**
```
AHF1: Apple Pay catcher (retry with joke)
AHF1_skip: Skip payment prompt
AHF2: Lesson introduction
AHF3: Location request
```

**Phase G - Location & Store Selection (AHG1-AHG2)**
```
AHG1: Location response (geocoding + store search)
AHG2: Store selection (list picker or quick reply)
```

**Phase H - Time Picker (AHH1-AHH2)**
```
AHH1: Time picker catcher (retry with auto-skip)
AHH2: Continue prompt
```

**Phase I - Rich Links & Photos (AHI1-AHI4)**
```
AHI1: Continue response router
AHI2: Rich link display
AHI3: Photo introduction
AHI4: Photo request
```

**Phase J - Documents & Learn More (AHJ1-AHJ4)**
```
AHJ1: Photo response (yes/no/attachment)
AHJ2: Documents intro (.numbers)
AHJ3: PDF document
AHJ4: Learn more prompt
```

**Phase K - Summary & Completion (AHK0-AHK3)**
```
AHK0: Learn more catcher
AHK1: Summary list picker
AHK2: Final message
AHK3: Register rich link + reset
```

**Special States**
```
DEMO_MODE: Isolated template demos
DEMO_MODE_LARGE_FORM: Large form demo state
STOPPED: Bot paused state
AH-restart: Flow restart trigger
```

### 1.2 Message Routing System

The legacy service has **three layers** of message routing:

#### Layer 1: Timeout Detection
```ruby
# Check every message
if conversation_timed_out? (30 minutes idle)
  reset_to_welcome
  # Clear ALL attributes
  # Reset to AHA1
end
```

#### Layer 2: Keyword Handlers
```ruby
# Priority 1: Demo Keywords (isolated execution)
DEMO_KEYWORDS = {
  'list picker' => :handle_list_picker_demo,
  'time picker' => :handle_time_picker_demo,
  'apple pay' => :handle_apple_pay_demo,
  'form' => :handle_form_demo,
  'large form' => :handle_large_form_demo,
  'ar' => :handle_ar_demo,
  'imessage app' => :handle_imessage_app,
  'authentication' => :handle_authentication_menu,
  'appclip' => :handle_app_clip_demo
}

# Priority 2: Flow Control Keywords
FLOW_CONTROL_KEYWORDS = {
  'menu' => :handle_menu,
  'start' => :handle_start_over,
  'stop' => :handle_stop,
  'summary' => :handle_summary,
  'skip' => :handle_skip_payment,
  'schedule' => :handle_schedule_lesson
}
```

#### Layer 3: State-Based Processing
```ruby
case @bot_state
when 'AHA1' then handle_welcome
when 'AHA2' then handle_region_prompt
# ... 30+ state handlers
end
```

### 1.3 Interactive Response Routing

**Interactive Handlers** (triggered by request_identifier):
```ruby
INTERACTIVE_HANDLERS = {
  'qr_travel' => :handle_region_selection,
  'qr_name' => :handle_name_preference_selection,
  'lp_guitar_0319' => :handle_guitar_selection,
  'lp_store_selection' => :handle_store_selection,
  'qr_store_selection' => :handle_store_selection_qr,
  'applepay_1018' => :handle_apple_pay_response,
  'qr_skip_payment' => :handle_skip_payment,
  'time_0319' => :handle_time_picker_response,
  'qr_view_ar' => :handle_ar_view_response,
  'qr_place_ar' => :handle_ar_place_response,
  'qr_continue' => :handle_continue_response,
  'qr_photo' => :handle_photo_response,
  'qr_learn_more' => :handle_learn_more_response,
  'lp_menu_0319' => :handle_menu_selection,
  'form_large_content' => :handle_large_form_response,
  'act_imessage_app' => :handle_imessage_app,
  'qr_oauth_provider' => :handle_oauth_provider_selection
}
```

### 1.4 Data Management

**Conversation Attributes** (stored in `custom_attributes`):
```ruby
# User Data
'customer_name'          # From form or text input
'stage_name'             # Alternative name from form
'preferred_name'         # Which name to use (real_name/stage_name)
'delivery_address'       # Parsed from form (street, city, state, zip, country)

# Flow State
'bot_state'              # Current state (AHA1, AHB2, etc.)
'bot_state_updated_at'   # Last state update timestamp
'retry_count'            # Progressive retry counter

# User Selections
'region'                 # Americas / EMEA / Asia Pacific
'selected_guitar'        # Guitar name from list picker
'selected_timeslot'      # Time picker selection
'selected_store'         # Store selection data
'selected_store_name'    # Store name

# Search Data (temporary)
'available_stores'       # JSON array of nearby stores
'store_search_lat'       # User location latitude
'store_search_lon'       # User location longitude
```

### 1.5 Retry & Error Handling

**Progressive Retry Logic** (example: Guitar Selection):
```ruby
def handle_guitar_list_catcher
  retry_count = increment_retry_count

  case retry_count
  when 1
    send_text_message('Please select a guitar from the list above.')
  when 2
    send_text_message("Looks like we're waiting for you to select a guitar.")
  when 3
    send_text_message('You may also use this menu as well.')
    send_guitar_list_picker  # Resend the picker
  when 4
    send_text_message("If stuck, you may use keyword 'Menu'.")
  else
    # After 5+ retries, auto-select every 3rd attempt
    if retry_count >= 5 && (retry_count % 3).zero?
      send_text_message("Okay, we'll just pretend you selected the Martin DC28E.")
      auto_select_guitar('Martin DC28E Dreadnought')
      reset_retry_count
      update_bot_state('AHC2')
    else
      send_text_message('Still waiting for your selection...')
    end
  end
end
```

**Catcher States** (defensive handlers for unexpected input):
- `handle_name_preference_catcher` (AHB2)
- `handle_guitar_list_catcher` (AHC1)
- `handle_ar_view_catcher` (AHD1)
- `handle_ar_place_catcher` (AHE1)
- `handle_apple_pay_catcher` (AHF1)
- `handle_time_picker_catcher` (AHH1)

### 1.6 Advanced Features

#### Idempotency Guards (Redis-based)
```ruby
# Prevent duplicate processing of same response
selection_hash = Digest::MD5.hexdigest("#{@conversation.id}:#{selection_data}")
selection_key = "guitar_selection:#{selection_hash}"

if Redis::Alfred.get(selection_key).present?
  log_info "Already processed, skipping"
  return
end

Redis::Alfred.setex(selection_key, '1', 2.minutes.to_i)
# ... process selection
```

#### Typing Indicators
```ruby
def with_typing_indicator
  return yield unless TYPING_INDICATORS_ENABLED

  send_typing_indicator(:start)
  sleep(TYPING_INDICATOR_DELAY)  # 1.5 seconds
  result = yield
  send_typing_indicator(:end)
  result
end
```

#### Apple Maps Integration
```ruby
# Geocode user input
coordinates = maps_service.geocode(user_message)

# Search nearby stores
stores = maps_service.search_nearby(
  coordinates[:latitude],
  coordinates[:longitude],
  'Apple Store',
  radius: 10_000 # 10km
)

# Route based on count:
# 1 store → Rich link + time picker
# 2-5 stores → Quick reply
# 6+ stores → List picker
```

#### OAuth Authentication
```ruby
# Check provider availability
unless @conversation.inbox.channel.oauth2_provider_enabled?('linkedin')
  send_text_message('LinkedIn OAuth is not enabled')
  return
end

# Send authentication request
send_oauth_authentication('linkedin')
```

---

## 2. Current Studio Flow Analysis

### 2.1 Flow Structure

**Total Components**:
- 19 nodes (11 states, 7 intents, 1 condition)
- 18 connections
- 8 bot action templates
- 1 message template (ah_main_menu)

### 2.2 Node Breakdown

#### State Nodes (11)
```
1. state-welcome: Executes templates + region_quick_reply
2. state-region-process: Updates attributes (region_update_attributes)
3. state-menu: Shows main menu (main_menu_list_picker)
4. state-apple-pay: Apple Pay demo (guitar_apple_pay)
5. state-api-call: API call demo (inventory_api_call)
6. state-imessage-app: iMessage app demo (shazam_imessage_app)
7. state-app-clip: App Clip demo (tuner_app_clip)
8. state-complete: Completion message (completion_text)
9. state-time-picker-demo: Time picker demo (empty execute_templates)
10. state-form-demo: Form demo (empty execute_templates)
11. state-summary-demo: Summary demo (completion_text)
```

#### Intent Nodes (7)
```
1. intent-region: Region selection (no keywords)
2. intent-list-picker-demo: Keywords: ["list picker", "listpicker", "guitar", "guitars"]
3. intent-time-picker-demo: Keywords: ["time picker", "timepicker"]
4. intent-form-demo: Keywords: ["form", "help me decide"]
5. intent-menu: Keywords: ["menu"]
6. intent-start_over: Keywords: ["start", "startover", "start over", "restart", "begin", "reset"]
7. intent-summary: Keywords: ["summary"]
```

#### Condition Nodes (1)
```
1. condition-check-region: No condition type specified
```

### 2.3 Execution Flow

**Primary Path** (from "start" keyword):
```
1. Start Over Intent
2. Welcome State → execute_templates + region_quick_reply
3. Region Selection Intent
4. Process Region State → region_update_attributes
5. Main Menu State → main_menu_list_picker
6. List Picker Demo Intent
7. Check Region Condition
8. Apple Pay Demo State → guitar_apple_pay
9. iMessage App Demo State → shazam_imessage_app
10. App Clip Demo State → tuner_app_clip
11. Complete State → completion_text
```

### 2.4 Template Configuration

**Bot Action Templates** (execute_template actions):
```yaml
ID 51: completion_text (send_text_message)
ID 53: region_quick_reply (send_quick_reply)
ID 54: region_update_attributes (update_attributes)
ID 55: main_menu_list_picker (send_list_picker) → ah_main_menu (ID 366)
ID 60: guitar_apple_pay (send_apple_pay)
ID 61: inventory_api_call (api_call)
ID 62: shazam_imessage_app (send_imessage_app)
ID 63: tuner_app_clip (send_app_clip)
```

### 2.5 Current Capabilities

**What Studio Flow #5 CAN Do**:
✅ Welcome flow with region selection
✅ Store region in conversation attributes
✅ Show main menu
✅ Route to template demos via keywords
✅ Execute basic template actions
✅ Simple state transitions

**What Studio Flow #5 CANNOT Do**:
❌ Progressive retry logic
❌ Timeout detection/auto-reset
❌ Error recovery (catcher states)
❌ Form response parsing
❌ Guitar selection with retry
❌ AR file sending + questions
❌ Apple Maps geocoding/search
❌ Store selection routing
❌ Time picker with location
❌ Photo handling
❌ Document sending
❌ Rich link generation
❌ OAuth authentication
❌ Idempotency guards
❌ Typing indicators
❌ Region-based customization
❌ Complex conditional routing
❌ State-based data persistence
❌ Menu selection handling
❌ Full conversational experience

---

## 3. Comprehensive Gap Analysis

### 3.1 States Comparison

| Legacy State | Studio Equivalent | Gap Description | Severity |
|--------------|-------------------|-----------------|----------|
| **AHA1** (Welcome) | state-welcome | ✅ Exists | ✅ OK |
| **AHA2** (Region Prompt) | Built into welcome | ⚠️ Combined, not separate | 🟡 Minor |
| **AHA3** (Form/Name Prompt) | ❌ Missing | Device capability check, form vs text routing | 🔴 Critical |
| **AHB1** (Form Response) | ❌ Missing | Form parsing, address extraction | 🔴 Critical |
| **AHB1_2** (Text Name) | ❌ Missing | Fallback for non-form devices | 🔴 Critical |
| **AHB2** (Name Preference) | ❌ Missing | Real name vs stage name selection | 🔴 Critical |
| **AHB3** (Guitar Prompt) | ❌ Missing | Send guitar list picker | 🔴 Critical |
| **AHC1** (Guitar Catcher) | ❌ Missing | Retry logic with auto-select | 🔴 Critical |
| **AHC2** (AR Intro) | ❌ Missing | AR file + introduction | 🔴 Critical |
| **AHC3** (AR Question 1) | ❌ Missing | AR view question | 🔴 Critical |
| **AHD1** (AR View Catcher) | ❌ Missing | Retry for AR view response | 🔴 Critical |
| **AHE1** (AR Place Catcher) | ❌ Missing | Retry for AR placement | 🔴 Critical |
| **AHE2** (Apple Pay Prompt) | state-apple-pay | ⚠️ No retry logic, no guitar context | 🟡 High |
| **AHF1** (Apple Pay Catcher) | ❌ Missing | Retry with joke, skip option | 🔴 Critical |
| **AHF2** (Lesson Intro) | ❌ Missing | Lesson scheduling introduction | 🔴 Critical |
| **AHF3** (Location Request) | ❌ Missing | Ask for zipcode/location | 🔴 Critical |
| **AHG1** (Location Response) | ❌ Missing | Geocode + store search + routing | 🔴 Critical |
| **AHG2** (Store Selection) | ❌ Missing | Store list picker or quick reply | 🔴 Critical |
| **AHH1** (Time Picker Catcher) | state-time-picker-demo | ⚠️ No retry, no location context | 🟡 High |
| **AHH2** (Continue Prompt) | ❌ Missing | Shall we continue? | 🔴 Critical |
| **AHI1** (Continue Response) | ❌ Missing | Route yes/no | 🔴 Critical |
| **AHI2** (Rich Link Display) | ❌ Missing | Send rich link | 🔴 Critical |
| **AHI3** (Photo Intro) | ❌ Missing | Photo introduction | 🔴 Critical |
| **AHI4** (Photo Request) | ❌ Missing | Photo quick reply | 🔴 Critical |
| **AHJ1** (Photo Response) | ❌ Missing | Handle yes/no/attachment | 🔴 Critical |
| **AHJ2** (Documents Intro) | ❌ Missing | Send .numbers file | 🔴 Critical |
| **AHJ3** (PDF Document) | ❌ Missing | Send PDF | 🔴 Critical |
| **AHJ4** (Learn More Prompt) | ❌ Missing | Learn more question | 🔴 Critical |
| **AHK0** (Learn More Catcher) | ❌ Missing | Retry for learn more response | 🔴 Critical |
| **AHK1** (Summary) | state-summary-demo | ⚠️ Exists but simplified | 🟡 High |
| **AHK2** (Final Message) | state-complete | ⚠️ Exists but simplified | 🟡 High |
| **AHK3** (Register Link) | ❌ Missing | Rich link + flow reset | 🔴 Critical |
| **DEMO_MODE** | N/A | ❌ Missing | Demo mode isolation | 🟡 High |
| **STOPPED** | N/A | ❌ Missing | Bot pause functionality | 🟡 High |

**Summary**: 9 states partially present, 24 states completely missing

### 3.2 Intents Comparison

| Legacy Handler | Studio Intent | Keywords | Gap |
|----------------|---------------|----------|-----|
| handle_list_picker_demo | intent-list-picker-demo | ✅ Match | ✅ OK |
| handle_time_picker_demo | intent-time-picker-demo | ✅ Match | ✅ OK |
| handle_form_demo | intent-form-demo | ✅ Match | ✅ OK |
| handle_menu | intent-menu | ✅ Match | ✅ OK |
| handle_start_over | intent-start_over | ✅ Match | ✅ OK |
| handle_summary | intent-summary | ✅ Match | ✅ OK |
| handle_apple_pay_demo | ❌ Missing | ["apple pay", "payment", "pay"] | 🔴 Critical |
| handle_large_form_demo | ❌ Missing | ["large form", "big form"] | 🔴 Critical |
| handle_ar_demo | ❌ Missing | ["ar", "augmented reality"] | 🔴 Critical |
| handle_imessage_app | ❌ Missing | ["imessage app", "shazam"] | 🔴 Critical |
| handle_authentication_menu | ❌ Missing | ["authentication", "auth"] | 🔴 Critical |
| handle_app_clip_demo | ❌ Missing | ["appclip"] | 🔴 Critical |
| handle_stop | ❌ Missing | ["stop"] | 🔴 Critical |
| handle_schedule_lesson | ❌ Missing | ["schedule", "lesson", "appointment"] | 🔴 Critical |
| handle_skip_payment | ❌ Missing | ["skip"] | 🔴 Critical |

**Summary**: 6 intents present, 9 intents missing

### 3.3 Actions Comparison

| Legacy Action | Studio Template | Implementation | Gap |
|---------------|-----------------|----------------|-----|
| send_quick_reply | region_quick_reply | ✅ Template exists | ✅ OK |
| send_guitar_list_picker | ❌ Missing | Uses ah_guitar_list_picker template | 🔴 Critical |
| send_guitar_info_form | ❌ Missing | Uses ah_guitar_info_form template | 🔴 Critical |
| send_summary_list_picker | ❌ Missing | Uses ah_summary template | 🔴 Critical |
| send_menu_list_picker | main_menu_list_picker | ✅ Template exists | ✅ OK |
| send_ar_file | ❌ Missing | Copies attachment from ah_ar_guitar template | 🔴 Critical |
| send_apple_pay_request | guitar_apple_pay | ⚠️ No guitar context, no retry | 🟡 High |
| send_lesson_time_picker | ❌ Missing | Dynamic timeslots, location data | 🔴 Critical |
| send_document | ❌ Missing | Sends .numbers, .pdf files | 🔴 Critical |
| send_rich_link | ❌ Missing | URL + title + image | 🔴 Critical |
| send_app_clip | tuner_app_clip | ✅ Template exists | ✅ OK |
| send_oauth_authentication | ❌ Missing | OAuth provider routing | 🔴 Critical |
| send_store_selection_list_picker | ❌ Missing | Dynamic store data from Maps API | 🔴 Critical |
| send_store_quick_reply | ❌ Missing | Quick reply with 2-5 stores | 🔴 Critical |
| send_single_store_rich_link | ❌ Missing | Apple Maps link for 1 store | 🔴 Critical |
| update_conversation_attribute | region_update_attributes | ⚠️ Only for region | 🟡 High |
| increment_retry_count | ❌ Missing | Retry counter management | 🔴 Critical |
| reset_retry_count | ❌ Missing | Reset counter | 🔴 Critical |
| auto_select_guitar | ❌ Missing | Fallback after retries | 🔴 Critical |

**Summary**: 4 actions present (2 fully, 2 partially), 15 actions missing

### 3.4 Data Management Comparison

| Legacy Attribute | Studio Handling | Gap |
|------------------|-----------------|-----|
| customer_name | ❌ Not captured | 🔴 Critical |
| stage_name | ❌ Not captured | 🔴 Critical |
| preferred_name | ❌ Not captured | 🔴 Critical |
| delivery_address | ❌ Not parsed | 🔴 Critical |
| bot_state | ⚠️ Managed by FlowExecutor | 🟡 Different system |
| bot_state_updated_at | ⚠️ Managed by FlowExecutor | 🟡 Different system |
| retry_count | ❌ Not implemented | 🔴 Critical |
| region | ✅ Stored via template | ✅ OK |
| selected_guitar | ❌ Not captured | 🔴 Critical |
| selected_timeslot | ❌ Not captured | 🔴 Critical |
| selected_store | ❌ Not captured | 🔴 Critical |
| available_stores | ❌ Not managed | 🔴 Critical |
| store_search_lat/lon | ❌ Not managed | 🔴 Critical |

**Summary**: 1 attribute captured (region), 12 attributes missing

---

## 4. Studio Flow Editorial Changes

### 4.1 Critical Missing States to Add

#### State: Form or Name Prompt (AHA3 equivalent)
```yaml
name: state-form-or-name-prompt
type: state
actions:
  - type: check_device_capability
    capability: FORM
    on_true: send_template(ah_guitar_info_form)
    on_false: send_text_message("What's your name?")
```

#### State: Form Response Handler (AHB1)
```yaml
name: state-form-response
type: state
actions:
  - type: execute_custom_code
    handler: parse_form_response
  - type: extract_address
  - type: store_attributes
```

#### State: Guitar List Prompt (AHB3)
```yaml
name: state-guitar-list-prompt
type: state
actions:
  - type: send_template
    template_id: ah_guitar_list_picker_bot_template
```

#### State: Guitar Selection Catcher (AHC1)
```yaml
name: state-guitar-catcher
type: state
actions:
  - type: execute_custom_code
    handler: handle_guitar_retry_logic
  - type: conditional
    check: retry_count > 5
    on_true: auto_select_guitar
```

#### State: AR Introduction (AHC2)
```yaml
name: state-ar-intro
type: state
actions:
  - type: send_text_message
    content: "Just in. We have this cool Stratocaster. Check it out in AR!"
  - type: send_template
    template_id: ah_ar_guitar_bot_template
```

#### State: Location Request (AHF3)
```yaml
name: state-location-request
type: state
actions:
  - type: send_text_message
    content: "We can find the closest location for you, just message us your zipcode and city."
```

#### State: Location Response Handler (AHG1)
```yaml
name: state-location-response
type: state
actions:
  - type: execute_custom_code
    handler: handle_location_geocoding
  - type: execute_custom_code
    handler: search_nearby_stores
  - type: conditional
    check: stores.count
    routes:
      1: send_single_store_rich_link
      2-5: send_store_quick_reply
      6+: send_store_list_picker
```

### 4.2 Missing Intents to Add

```yaml
- name: intent-apple-pay-demo
  keywords: ["apple pay", "payment", "pay"]
  target: state-apple-pay

- name: intent-large-form-demo
  keywords: ["large form", "big form"]
  target: state-large-form-demo

- name: intent-ar-demo
  keywords: ["ar", "augmented reality"]
  target: state-ar-demo

- name: intent-stop
  keywords: ["stop"]
  target: state-stopped

- name: intent-schedule-lesson
  keywords: ["schedule", "lesson", "appointment", "time"]
  target: state-location-request

- name: intent-skip-payment
  keywords: ["skip"]
  target: state-lesson-intro
```

### 4.3 Missing Conditions to Add

```yaml
- name: condition-device-supports-forms
  type: capability_check
  capability: FORM
  true_path: state-send-form
  false_path: state-text-name-input

- name: condition-store-count-router
  type: count_check
  variable: available_stores
  routes:
    1: state-single-store-rich-link
    2-5: state-store-quick-reply
    6+: state-store-list-picker

- name: condition-retry-threshold
  type: comparison
  variable: retry_count
  operator: ">="
  value: 5
  true_path: state-auto-select
  false_path: state-retry-prompt

- name: condition-conversation-timeout
  type: time_check
  variable: bot_state_updated_at
  threshold: 30_minutes
  true_path: state-welcome
  false_path: state-continue-flow
```

### 4.4 Missing Bot Action Templates to Create

```yaml
# Guitar List Picker
- name: guitar_list_picker_bot
  type: send_list_picker
  message_template_id: ah_guitar_list_picker
  request_identifier: lp_guitar_0319

# Guitar Info Form
- name: guitar_info_form_bot
  type: send_form
  message_template_id: ah_guitar_info_form
  request_identifier: form_0343

# AR Guitar File
- name: ar_guitar_bot
  type: send_attachment
  message_template_id: ah_ar_guitar
  attachment_type: ar_file

# Summary List Picker
- name: summary_list_picker_bot
  type: send_list_picker
  message_template_id: ah_summary
  request_identifier: lp_summary_0319

# Store Selection List Picker (Dynamic)
- name: store_selection_bot
  type: send_dynamic_list_picker
  custom_handler: build_store_list_picker
  request_identifier: lp_store_selection

# Time Picker (Dynamic)
- name: lesson_time_picker_bot
  type: send_time_picker
  custom_handler: build_time_picker
  request_identifier: time_0319

# Document Sending
- name: send_numbers_document_bot
  type: send_document
  filename: metrics.numbers

- name: send_pdf_document_bot
  type: send_document
  filename: document.pdf

# Rich Links
- name: register_rich_link_bot
  type: send_rich_link
  url: https://register.apple.com/business-chat
  image_asset: heroImage.png
  title: Apple Messages for Business

# OAuth Authentication
- name: linkedin_oauth_bot
  type: send_oauth
  provider: linkedin
```

### 4.5 Transition Updates

**Add Missing Transitions**:
```yaml
# Form to Name Preference
state-form-response → state-name-preference

# Name Preference to Guitar List
state-name-preference → state-guitar-list-prompt

# Guitar Selection to AR
state-guitar-selection → state-ar-intro

# AR to Apple Pay
state-ar-questions → state-apple-pay-prompt

# Apple Pay to Lesson
state-apple-pay → state-lesson-intro

# Location to Store Selection
state-location-response → [state-single-store | state-store-qr | state-store-list]

# Store to Time Picker
state-store-selection → state-time-picker

# Time Picker to Continue
state-time-picker → state-continue-prompt

# Continue to Photo/Rich Link
state-continue → [state-photo-intro | state-learn-more]

# Photo to Documents
state-photo-response → state-documents-intro

# Learn More to Summary
state-learn-more → state-summary

# Summary to Complete
state-summary → state-register-link → state-welcome (reset)
```

---

## 5. Features Not Supported by Studio Built-in System

### 5.1 Progressive Retry Logic

**Description**: The legacy service has sophisticated retry counters with escalating messages and auto-fallback.

**Example**:
```ruby
retry_count = increment_retry_count
case retry_count
when 1 then send "Please select from list"
when 2 then send "Looks like we're waiting"
when 3 then resend_picker
when 4 then send "Type 'Menu' if stuck"
else
  if retry_count >= 5 && (retry_count % 3).zero?
    auto_select_default
  end
end
```

**Studio Gap**: No retry counter, no progressive messaging, no auto-fallback.

**Impact**: Users stuck when they don't understand how to interact with templates.

### 5.2 Timeout Detection & Auto-Reset

**Description**: After 30 minutes of inactivity, conversation automatically resets to welcome state and clears all attributes.

**Legacy Implementation**:
```ruby
def conversation_timed_out?
  last_updated = attrs['bot_state_updated_at']
  return false unless last_updated
  Time.zone.parse(last_updated) < IDLE_TIMEOUT.ago
end

if timed_out
  reset_to_welcome  # Clear all attributes, reset to AHA1
end
```

**Studio Gap**: No timeout detection, stale conversations persist indefinitely.

**Impact**: Confusing user experience when returning after hours/days.

### 5.3 Idempotency Guards

**Description**: Prevents duplicate processing of same interactive response (e.g., user taps list picker item twice).

**Legacy Implementation**:
```ruby
selection_hash = Digest::MD5.hexdigest("#{conversation.id}:#{selection_data}")
selection_key = "guitar_selection:#{selection_hash}"

if Redis::Alfred.get(selection_key).present?
  log_info "Already processed, skipping"
  return
end

Redis::Alfred.setex(selection_key, '1', 2.minutes.to_i)
```

**Studio Gap**: No deduplication mechanism.

**Impact**: Double-processing if user taps quickly or message duplicates.

### 5.4 Form Response Parsing

**Description**: Extract structured data from Apple form responses, including nested fields and address parsing.

**Legacy Implementation**:
```ruby
def handle_form_response
  form_data = @message.content_attributes.dig('form_response', 'selections')

  customer_name = find_field(form_data, 'full name')
  stage_name = find_field(form_data, 'stage name')
  address = extract_address_from_form(form_data)

  update_conversation_attribute('customer_name', customer_name)
  update_conversation_attribute('delivery_address', address)
end
```

**Studio Gap**: No form parsing logic in action templates.

**Impact**: Cannot extract data from form responses.

### 5.5 Apple Maps Integration

**Description**: Geocode user input, search nearby stores, route based on count.

**Legacy Implementation**:
```ruby
# Geocode zipcode or address
coordinates = maps_service.geocode(user_message)

# Search nearby
stores = maps_service.search_nearby(
  coordinates[:latitude],
  coordinates[:longitude],
  'Apple Store',
  radius: 10_000
)

# Route based on count
case stores.length
when 1 then send_rich_link(store)
when 2..5 then send_quick_reply(stores)
else send_list_picker(stores)
end
```

**Studio Gap**: No geocoding, no Maps API, no dynamic routing.

**Impact**: Cannot implement location-based features.

### 5.6 Dynamic Content Generation

**Description**: Generate list pickers, time pickers, quick replies with runtime data.

**Legacy Examples**:
- Store list picker with geocoding results
- Time picker with location timezone
- Quick reply with dynamic store names

**Studio Gap**: Templates are static, cannot populate with API/runtime data.

**Impact**: All content must be pre-configured.

### 5.7 Attachment Handling

**Description**: Detect photo uploads, respond accordingly, copy template attachments to messages.

**Legacy Implementation**:
```ruby
def handle_received_attachment
  if @message.attachments.any? { |a| a.file.content_type.start_with?('image/') }
    send_text_message('Awesome photo! #photooftheday')
    update_bot_state('AHJ4')
  end
end

def send_ar_file
  template.attachments.each do |template_attachment|
    message.attachments.build.file.attach(
      io: StringIO.new(template_attachment.download),
      filename: template_attachment.filename
    )
  end
end
```

**Studio Gap**: No attachment detection, no file copying logic.

**Impact**: Cannot handle photo uploads or send template attachments.

### 5.8 OAuth Provider Routing

**Description**: Check provider availability, route to correct OAuth handler.

**Legacy Implementation**:
```ruby
unless @conversation.inbox.channel.oauth2_provider_enabled?('linkedin')
  send_text_message('LinkedIn OAuth is not enabled')
  return
end

send_oauth_authentication('linkedin')
```

**Studio Gap**: No OAuth capability checks, no provider routing.

**Impact**: Cannot implement OAuth flows.

### 5.9 State-Based Data Persistence

**Description**: Store/retrieve arbitrary conversation attributes throughout flow.

**Legacy Implementation**:
```ruby
update_conversation_attribute('selected_guitar', guitar_name)
update_conversation_attribute('selected_store', store_data)
update_conversation_attribute('available_stores', stores.to_json)

guitar = get_conversation_attribute('selected_guitar')
```

**Studio Gap**: Only one `update_attributes` template, no runtime get/set.

**Impact**: Cannot persist user selections across states.

### 5.10 Typing Indicators

**Description**: Send typing start/end indicators for natural feel.

**Legacy Implementation**:
```ruby
def with_typing_indicator
  send_typing_indicator(:start)
  sleep(1.5)
  result = yield
  send_typing_indicator(:end)
  result
end
```

**Studio Gap**: No typing indicator support.

**Impact**: Messages appear instantly, less natural.

---

## 6. Required Code Changes for Missing Features

### 6.1 FlowExecutorService Enhancements

**File**: `app/services/apple_messages_for_business/flow_executor_service.rb`

#### Add Retry Counter Management

```ruby
# Add to FlowExecutorService class

def increment_retry_count
  session = load_session_state
  session['retry_count'] ||= 0
  session['retry_count'] += 1
  save_session_state(session)
  session['retry_count']
end

def get_retry_count
  session = load_session_state
  session['retry_count'] || 0
end

def reset_retry_count
  session = load_session_state
  session['retry_count'] = 0
  save_session_state(session)
end
```

#### Add Timeout Detection

```ruby
# Add to execute method, before processing

def execute
  # Check timeout FIRST
  if conversation_timed_out?
    Rails.logger.info "[FlowExecutor] 🕐 Conversation timed out, resetting"
    reset_conversation_to_welcome
    # Process welcome state
    execute_welcome_state
    return
  end

  # ... rest of execution
end

private

def conversation_timed_out?
  session = load_session_state
  last_updated = session['last_updated_at']
  return false unless last_updated

  timeout = 30.minutes
  Time.zone.parse(last_updated) < timeout.ago
end

def reset_conversation_to_welcome
  # Clear all conversation attributes
  @conversation.custom_attributes = {}
  @conversation.save!

  # Reset session state
  save_session_state({
    'current_state' => 'welcome',
    'message_count' => 0,
    'last_updated_at' => Time.current.iso8601
  })
end
```

#### Add Idempotency Guards

```ruby
# Add to process_interactive_response

def process_interactive_response(interactive_data)
  # Generate idempotency key
  selection_data = interactive_data['ldtext'] || interactive_data.to_json
  selection_hash = Digest::MD5.hexdigest("#{@conversation.id}:#{selection_data}")
  cache_key = "flow_executor:#{@flow.id}:interaction:#{selection_hash}"

  # Check if already processed
  if Rails.cache.read(cache_key).present?
    Rails.logger.info "[FlowExecutor] 🔒 Interaction already processed (#{selection_hash}), skipping"
    return { success: true, skipped: true }
  end

  # Mark as processed (2 minute TTL)
  Rails.cache.write(cache_key, '1', expires_in: 2.minutes)

  # ... process interaction
end
```

### 6.2 New Action Type: Custom Code Execution

**File**: `app/services/apple_messages_for_business/flow_executor_service.rb`

```ruby
# Add to execute_node_actions

def execute_node_actions(node)
  actions = node.dig('data', 'actions') || []

  actions.each do |action|
    case action['type']
    when 'execute_template'
      execute_template_action(action)
    when 'execute_custom_code'
      execute_custom_code_action(action)  # NEW
    when 'send_text_message'
      send_text_message_action(action)
    end
  end
end

def execute_custom_code_action(action)
  handler_name = action['handler']

  # Invoke custom handler from AcousticHouseBotService
  service = AppleMessagesForBusiness::AcousticHouseBotService.new(
    @conversation,
    @message,
    @bot,
    @config
  )

  if service.respond_to?(handler_name)
    Rails.logger.info "[FlowExecutor] 🔧 Executing custom handler: #{handler_name}"
    service.send(handler_name)
  else
    Rails.logger.warn "[FlowExecutor] ⚠️ Unknown handler: #{handler_name}"
  end
end
```

### 6.3 New Condition Type: Capability Check

**File**: `app/services/apple_messages_for_business/flow_executor_service.rb`

```ruby
def evaluate_condition(condition_node)
  condition_type = condition_node.dig('data', 'condition_type')

  case condition_type
  when 'capability_check'
    evaluate_capability_condition(condition_node)
  when 'count_check'
    evaluate_count_condition(condition_node)
  when 'comparison'
    evaluate_comparison_condition(condition_node)
  when 'time_check'
    evaluate_time_condition(condition_node)
  else
    Rails.logger.warn "[FlowExecutor] Unknown condition type: #{condition_type}"
    false
  end
end

def evaluate_capability_condition(condition_node)
  capability = condition_node.dig('data', 'capability')
  contact = @conversation.contact
  capabilities = contact.additional_attributes&.dig('apple_messages_capabilities') || ''

  capabilities.include?(capability)
end

def evaluate_count_condition(condition_node)
  variable = condition_node.dig('data', 'variable')
  value = get_conversation_attribute(variable)

  if value.is_a?(String) && value.start_with?('[')
    count = JSON.parse(value).length
  else
    count = value.to_i
  end

  routes = condition_node.dig('data', 'routes') || {}

  # Find matching route
  routes.each do |range_str, target|
    if range_str.include?('..')
      # Range: "2..5"
      range = eval(range_str)
      return target if range.include?(count)
    elsif range_str.include?('+')
      # "6+" means >= 6
      threshold = range_str.to_i
      return target if count >= threshold
    else
      # Exact: "1"
      return target if count == range_str.to_i
    end
  end

  nil
end

def evaluate_comparison_condition(condition_node)
  variable = condition_node.dig('data', 'variable')
  operator = condition_node.dig('data', 'operator')
  threshold = condition_node.dig('data', 'value')

  value = get_conversation_attribute(variable)

  case operator
  when '>=' then value.to_i >= threshold.to_i
  when '>' then value.to_i > threshold.to_i
  when '<=' then value.to_i <= threshold.to_i
  when '<' then value.to_i < threshold.to_i
  when '==' then value.to_s == threshold.to_s
  else false
  end
end

def evaluate_time_condition(condition_node)
  variable = condition_node.dig('data', 'variable')
  threshold_str = condition_node.dig('data', 'threshold') # "30_minutes"

  timestamp = get_conversation_attribute(variable)
  return false unless timestamp

  threshold = eval(threshold_str) # 30.minutes
  Time.zone.parse(timestamp) < threshold.ago
end
```

### 6.4 New Template Type: Dynamic List Picker

**File**: `app/services/apple_messages_for_business/template_executor_service.rb` (new file)

```ruby
class AppleMessagesForBusiness::TemplateExecutorService
  def initialize(conversation, message, bot)
    @conversation = conversation
    @message = message
    @bot = bot
  end

  def execute_dynamic_template(template_action)
    handler = template_action['custom_handler']

    case handler
    when 'build_store_list_picker'
      build_store_list_picker
    when 'build_time_picker'
      build_time_picker
    else
      Rails.logger.error "[TemplateExecutor] Unknown handler: #{handler}"
    end
  end

  private

  def build_store_list_picker
    # Get stores from conversation attributes
    stores_json = @conversation.custom_attributes['available_stores']
    return unless stores_json

    stores = JSON.parse(stores_json)

    # Build list picker sections
    items = stores.map.with_index do |store, index|
      {
        'identifier' => index.to_s,
        'title' => store['name'],
        'subtitle' => "#{store['distance_km']} km away",
        'style' => 'large',
        'image_identifier' => 'apple_store_logo'
      }
    end

    sections = [{
      'title' => 'Nearby Apple Stores',
      'multiple_selection' => false,
      'items' => items
    }]

    # Send via SendListPickerService
    content_attrs = {
      'sections' => sections,
      'request_identifier' => 'lp_store_selection',
      'images' => fetch_images(['apple_store_logo'])
    }

    Messages::MessageBuilder.new(
      message_sender,
      @conversation,
      {
        message_type: :outgoing,
        content: 'Select an Apple Store',
        content_type: 'apple_list_picker',
        content_attributes: content_attrs
      }
    ).perform
  end

  def build_time_picker
    # Get location from conversation attributes
    location_name = @conversation.custom_attributes['selected_store_name']
    lat = @conversation.custom_attributes['store_search_lat'].to_f
    lon = @conversation.custom_attributes['store_search_lon'].to_f

    # Calculate timezone
    timezone_offset = calculate_timezone_offset(lon)

    # Generate timeslots
    day1 = 7.days.from_now.to_date
    day2 = 8.days.from_now.to_date

    timeslots = [
      { 'identifier' => '0', 'start_time' => "#{day1}T15:30#{timezone_offset}", 'duration' => 3600 },
      { 'identifier' => '1', 'start_time' => "#{day1}T17:00#{timezone_offset}", 'duration' => 3600 },
      { 'identifier' => '2', 'start_time' => "#{day1}T19:30#{timezone_offset}", 'duration' => 3600 },
      { 'identifier' => '3', 'start_time' => "#{day2}T15:00#{timezone_offset}", 'duration' => 3600 },
      { 'identifier' => '4', 'start_time' => "#{day2}T17:30#{timezone_offset}", 'duration' => 3600 },
      { 'identifier' => '5', 'start_time' => "#{day2}T19:00#{timezone_offset}", 'duration' => 3600 }
    ]

    # Send via SendTimePickerService
    content_attrs = {
      'request_identifier' => 'time_0319',
      'received_title' => 'Schedule a lesson',
      'received_subtitle' => location_name,
      'event' => {
        'identifier' => SecureRandom.uuid,
        'title' => 'Guitar Lesson',
        'location' => {
          'latitude' => lat,
          'longitude' => lon,
          'title' => location_name
        },
        'timeslots' => timeslots
      }
    }

    Messages::MessageBuilder.new(
      message_sender,
      @conversation,
      {
        message_type: :outgoing,
        content: 'Schedule a lesson',
        content_type: 'apple_time_picker',
        content_attributes: content_attrs
      }
    ).perform
  end

  def calculate_timezone_offset(longitude)
    # Copy from AcousticHouseBotService
    # ... same logic
  end
end
```

### 6.5 New Service: Form Parser

**File**: `app/services/apple_messages_for_business/form_parser_service.rb` (new file)

```ruby
class AppleMessagesForBusiness::FormParserService
  def initialize(form_response_data)
    @form_data = form_response_data.dig('form_response', 'selections') || []
  end

  def extract_customer_name
    find_field_value(['full name', 'name', 'customer name'])
  end

  def extract_stage_name
    find_field_value(['stage name', 'artist name'])
  end

  def extract_address
    address_fields = {}

    field_patterns = {
      street: ['street', 'address', 'addr', 'line 1', 'address line'],
      city: %w[city town],
      state: %w[state province region],
      zip: ['zip', 'postal', 'postcode', 'zip code', 'postal code'],
      country: ['country']
    }

    @form_data.each do |section|
      title = section['title']&.downcase || ''
      value = section.dig('items', 0, 'value')

      next unless value.present?

      field_patterns.each do |field_type, patterns|
        if patterns.any? { |pattern| title.include?(pattern) }
          address_fields[field_type] = value
          break
        end
      end
    end

    address_fields.present? ? address_fields : nil
  end

  private

  def find_field_value(patterns)
    section = @form_data.find do |s|
      title = s['title']&.downcase || ''
      patterns.any? { |pattern| title.include?(pattern) }
    end

    section&.dig('items', 0, 'value')
  end
end
```

### 6.6 Attachment Handler Integration

**File**: `app/services/apple_messages_for_business/flow_executor_service.rb`

```ruby
# Add to execute method

def execute
  # ... existing code

  # Check for attachments FIRST (before keyword/state processing)
  if @message.attachments.present?
    handle_attachment
    return { success: true, attachment_handled: true }
  end

  # ... rest of execution
end

def handle_attachment
  # Check if current state expects attachments
  current_node = find_current_state_node
  return unless current_node

  attachment_handler = current_node.dig('data', 'attachment_handler')
  return unless attachment_handler

  # Check for image attachments
  has_image = @message.attachments.any? do |attachment|
    attachment.file&.content_type&.start_with?('image/')
  end

  if has_image && attachment_handler == 'handle_photo_upload'
    send_text_message('Awesome photo! #photooftheday #instadaily')

    # Find next state
    next_state = current_node.dig('data', 'attachment_next_state')
    transition_to_state(next_state) if next_state
  end
end
```

### 6.7 OAuth Integration

**File**: `app/services/apple_messages_for_business/flow_executor_service.rb`

```ruby
def execute_oauth_action(action)
  provider = action['provider']

  # Check if provider is enabled
  unless @conversation.inbox.channel.oauth2_provider_enabled?(provider)
    send_text_message("#{provider.capitalize} OAuth is not enabled for this inbox.")
    return
  end

  # Build authentication data
  authentication_data = { 'provider' => provider }

  message_content = "Sign in with #{provider.capitalize} to continue"

  # Use SendAuthenticationService
  service = AppleMessagesForBusiness::SendAuthenticationService.new(
    channel: @conversation.inbox.channel,
    destination_id: @conversation.contact_inbox.source_id,
    authentication_data: authentication_data,
    message_content: message_content
  )

  result = service.perform

  if result[:success]
    Rails.logger.info "[FlowExecutor] ✅ OAuth authentication sent"
  else
    Rails.logger.error "[FlowExecutor] ❌ OAuth failed: #{result[:error]}"
    send_text_message('Sorry, authentication is unavailable. Please try again.')
  end
end
```

---

## 7. Implementation Roadmap

### Phase 1: Foundation (Week 1-2)

**Objectives**: Enable basic conversational flow

**Tasks**:
1. ✅ Add retry counter management to FlowExecutorService
2. ✅ Add timeout detection & auto-reset
3. ✅ Create missing state nodes (AHA3, AHB1, AHB3, AHC1)
4. ✅ Create missing intent nodes (apple pay, ar, large form, etc.)
5. ✅ Add transitions between new states
6. ✅ Test basic flow: Welcome → Region → Form → Guitar → Summary

**Deliverables**:
- FlowExecutorService with retry/timeout support
- 15 new state nodes
- 9 new intent nodes
- Updated flow transitions

### Phase 2: Advanced Features (Week 3-4)

**Objectives**: Dynamic content, Maps integration

**Tasks**:
1. ✅ Create FormParserService for form response handling
2. ✅ Create TemplateExecutorService for dynamic content
3. ✅ Implement Apple Maps geocoding integration
4. ✅ Add store search & routing logic
5. ✅ Create dynamic time picker generation
6. ✅ Test location-based features

**Deliverables**:
- FormParserService
- TemplateExecutorService
- Maps integration
- Dynamic list/time pickers

### Phase 3: Reliability (Week 5-6)

**Objectives**: Idempotency, error handling, edge cases

**Tasks**:
1. ✅ Add idempotency guards (Redis-based)
2. ✅ Implement attachment detection
3. ✅ Add OAuth authentication support
4. ✅ Create catcher state logic
5. ✅ Add typing indicators
6. ✅ Test edge cases (timeout, retry, duplicate taps)

**Deliverables**:
- Idempotency system
- Attachment handling
- OAuth integration
- Comprehensive error handling

### Phase 4: Testing & Refinement (Week 7-8)

**Objectives**: End-to-end testing, bug fixes, optimization

**Tasks**:
1. ✅ End-to-end flow testing (all 30+ states)
2. ✅ Performance optimization
3. ✅ Bug fixes
4. ✅ Documentation updates
5. ✅ User acceptance testing
6. ✅ Production deployment prep

**Deliverables**:
- Fully tested bot flow
- Performance benchmarks
- Updated documentation
- Production-ready system

---

## 8. Success Criteria

### Functional Requirements

✅ **All 30+ States Implemented**: Every legacy state has Studio equivalent
✅ **Retry Logic Works**: Progressive retry with auto-fallback
✅ **Timeout Resets**: 30-min idle auto-reset to welcome
✅ **Form Parsing**: Extract name, address from forms
✅ **Maps Integration**: Geocode, search, route based on count
✅ **Dynamic Content**: Generate list/time pickers from runtime data
✅ **Idempotency**: No duplicate processing
✅ **Attachment Handling**: Detect photos, copy template files
✅ **OAuth**: Authentication flow works

### Non-Functional Requirements

✅ **Performance**: <500ms average response time
✅ **Reliability**: 99.9% uptime
✅ **Scalability**: Handle 1000+ concurrent conversations
✅ **Maintainability**: Code coverage >80%
✅ **Documentation**: Complete API docs

### User Experience

✅ **Natural Flow**: Conversation feels smooth
✅ **Error Recovery**: Graceful handling of unexpected input
✅ **Helpful Messages**: Progressive retry guidance
✅ **Regional Customization**: Region-aware messaging

---

## Appendix A: State Transition Diagram

```
[Welcome] → Region Prompt → Region Selection
    ↓
Form/Name Prompt → [Form Response | Text Name] → Name Preference
    ↓
Guitar List → Guitar Selection (with retries) → AR Introduction
    ↓
AR Questions → Apple Pay (with retries) → Lesson Intro
    ↓
Location Request → Location Response → [Single Store | QR (2-5) | List (6+)]
    ↓
Time Picker (with retries) → Continue Prompt → [Yes → Photos | No → Learn More]
    ↓
Documents → Learn More → Summary → Register Link → [Reset to Welcome]

Special Flows:
- "menu" keyword → Main Menu → Demo states → DEMO_MODE
- "stop" keyword → STOPPED state
- Timeout (30 min) → Reset to Welcome
```

---

## Appendix B: Template Mapping

| Legacy Template | Studio Template/Action | Status |
|-----------------|------------------------|--------|
| ah_guitar_list_picker | ❌ Need bot action template | Missing |
| ah_guitar_info_form | ❌ Need bot action template | Missing |
| ah_large_form_demo | ❌ Need bot action template | Missing |
| ah_main_menu | ✅ main_menu_list_picker (ID 55) | Exists |
| ah_ar_guitar | ❌ Need attachment copy logic | Missing |
| ah_summary | ❌ Need bot action template | Missing |

---

## Appendix C: Critical Code Snippets

### C.1 Progressive Retry Template

```ruby
# Add to FlowExecutorService or custom handler

def handle_retry_logic(state_name, retry_prompts)
  retry_count = increment_retry_count

  if retry_count <= retry_prompts.length
    send_text_message(retry_prompts[retry_count - 1])
  else
    # Auto-fallback after max retries
    handle_auto_fallback(state_name)
  end
end

# Usage in state node:
# {
#   "type": "execute_custom_code",
#   "handler": "handle_retry_logic",
#   "params": {
#     "state_name": "guitar_selection",
#     "retry_prompts": [
#       "Please select a guitar from the list above.",
#       "Looks like we're waiting for your selection.",
#       "You may also use this menu as well.",
#       "If stuck, type 'Menu' for help."
#     ]
#   }
# }
```

### C.2 Dynamic Store Routing

```ruby
def route_stores_by_count(stores, user_coordinates)
  case stores.length
  when 1
    send_single_store_rich_link(stores.first, user_coordinates)
    transition_to_state('time_picker')
  when 2..5
    send_store_quick_reply(stores, user_coordinates)
    transition_to_state('store_selection_qr')
  else
    send_store_list_picker(stores, user_coordinates)
    transition_to_state('store_selection_list')
  end
end
```

---

**END OF DOCUMENT**

*For questions or clarifications, refer to:*
- Legacy Service: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`
- Flow Executor: `app/services/apple_messages_for_business/flow_executor_service.rb`
- Bot Studio Guide: `docs/bot-studio/BOT_STUDIO_GUIDE.md`
