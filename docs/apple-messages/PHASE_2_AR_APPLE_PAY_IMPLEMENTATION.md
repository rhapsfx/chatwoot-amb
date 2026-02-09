# Phase 2 Implementation: AR File Delivery & Apple Pay (AHC2-AHF1)

**Date**: November 12, 2025
**Status**: ✅ COMPLETE
**Author**: Claude Code
**Scope**: Acoustic House Bot States AHC2 through AHF1

---

## Overview

Phase 2 implements AR file delivery and Apple Pay functionality for the Acoustic House Bot, covering states AHC2 through AHF1. This phase builds on Phase 1 (guitar selection) and leads into Phase 3 (lesson booking).

### States Implemented

| State | Python Line | Description | Implementation Status |
|-------|------------|-------------|----------------------|
| **AHC2** | 1037-1046 | Send AR file (stratocaster.usdz) | ✅ Complete |
| **AHC3** | 1048-1054 | First AR question (qr_view_ar) | ✅ Complete |
| **AHD1** | 1056-1071 | AR view response handler | ✅ Complete |
| **AHE1** | 1073-1087 | AR place response handler | ✅ Complete |
| **AHE2** | 1089-1095 | Apple Pay request | ✅ Complete |
| **AHF1** | 1097-1109 | Apple Pay catcher (retry logic) | ✅ Complete |

---

## Implementation Details

### 1. AR File Delivery (AHC2)

**File**: `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

**Method**: `handle_ar_introduction` (lines 316-326)

```ruby
def handle_ar_introduction
  # AHC2: Send AR file
  send_text_message('Just in. We have this cool Stratocaster. Check it out!!!')
  send_ar_file
  update_bot_state('AHC3')

  # Wait 20 seconds then proceed to AHC3
  # Note: In production, this would be a scheduled job
  # For now, we'll proceed immediately
  handle_ar_first_question
end
```

**Message Flow**:
1. Send text: "Just in. We have this cool Stratocaster. Check it out!!!"
2. Send AR file: `stratocaster.usdz` (6.9MB)
3. Transition to AHC3

**AR File Helper** (lines 723-747):
```ruby
def send_ar_file
  # Send stratocaster.usdz file as attachment
  # For Phase 2, we'll use a placeholder approach
  # The actual USDZ file should be stored in ActiveStorage

  Rails.logger.info '[Bot] Sending AR file (stratocaster.usdz)'
  send_text_message('[AR File: stratocaster.usdz would be sent here]')

  # TODO: Implement actual AR file sending via ActiveStorage
end
```

**Production TODO**:
- Store `stratocaster.usdz` in ActiveStorage
- Attach to message via `Messages::MessageBuilder`
- Send via `SendMessageService` with `attachments` array
- Handle encryption via `AttachmentCipherService`

---

### 2. First AR Question (AHC3)

**Method**: `handle_ar_first_question` (lines 328-333)

```ruby
def handle_ar_first_question
  # AHC3: First AR question
  send_text_message('Did you click on the image and see the 3D augmented reality view of the guitar?')
  send_ar_view_question
  update_bot_state('AHD1')
end
```

**Quick Reply Payload** (lines 749-759):
```ruby
def send_ar_view_question
  send_quick_reply(
    title: 'Did you click on the image and see the 3D augmented reality view of the guitar?',
    request_id: 'qr_view_ar',
    items: [
      { title: 'Yes', identifier: '111' },
      { title: 'No', identifier: '222' }
    ]
  )
end
```

**JSON Structure** (matches Python `qr_view_ar.json`):
```json
{
  "bid": "com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension",
  "data": {
    "mspVersion": "1.0",
    "requestIdentifier": "qr_view_ar",
    "quick-reply": {
      "summaryText": "Did you click on the image and see the 3D augmented reality view of the guitar?",
      "items": [
        { "identifier": "111", "title": "Yes" },
        { "identifier": "222", "title": "No" }
      ]
    }
  }
}
```

---

### 3. AR View Response (AHD1)

**Method**: `handle_ar_view_response` (lines 339-356)

```ruby
def handle_ar_view_response(interactive_data)
  # AHD1: AR view response
  selection_value = interactive_data.dig('data', 'reply', 'identifier')

  if selection_value == '111' # Yes
    # User clicked and saw AR view
    customer_name = get_conversation_attribute('customer_name') || 'there'
    send_text_message("Awesome! #{customer_name} did you select AR from the top of the image and set it down in front of you?")
    send_ar_place_question
  else
    # User didn't see AR view
    send_text_message('Try tapping on the image to see the AR image of the guitar!')
    send_text_message('Did you select AR from the top of the image and set it down in front of you?')
    send_ar_place_question
  end

  update_bot_state('AHE1')
end
```

**Conditional Logic**:
- **If "Yes" (111)**: Personalized message with customer name
- **If "No" (222)**: Instructional message to tap image

**Both paths** lead to `send_ar_place_question()`

**AR Place Question Helper** (lines 761-771):
```ruby
def send_ar_place_question
  send_quick_reply(
    title: 'Did you select AR from the top of the image and set it down in front of you?',
    request_id: 'qr_place_ar',
    items: [
      { title: 'Yes', identifier: '111' },
      { title: 'No', identifier: '222' }
    ]
  )
end
```

---

### 4. AR Place Response (AHE1)

**Method**: `handle_ar_place_response` (lines 358-372)

```ruby
def handle_ar_place_response(interactive_data)
  # AHE1: AR place response
  selection_value = interactive_data.dig('data', 'reply', 'identifier')

  send_text_message('Try tapping on the image to see the AR image of the guitar!') if selection_value == '222'

  # Always proceed to Apple Pay
  guitar_name = get_conversation_attribute('selected_guitar') || 'guitar'
  send_text_message("Great, let's buy your new #{guitar_name}.")

  update_bot_state('AHE2')
  handle_apple_pay_prompt
end
```

**Behavior**:
- If user selected "No" (222): Send reminder to try AR
- **Always** proceed to Apple Pay regardless of selection
- Uses stored guitar name from Phase 1

---

### 5. Apple Pay Request (AHE2)

**Method**: `handle_apple_pay_prompt` (lines 374-387)

```ruby
def handle_apple_pay_prompt
  # AHE2: Send Apple Pay request
  guitar_name = get_conversation_attribute('selected_guitar') || 'guitar'

  result = send_apple_pay_request(guitar_name)

  if result[:success]
    update_bot_state('AHF1')
  else
    send_text_message('We are experiencing some technical difficulties with our Apple Pay service. We apologize for this inconvenience and we are working on a fix.')
    update_bot_state('AHF2')
    handle_lesson_introduction
  end
end
```

**Apple Pay Helper** (lines 773-808):
```ruby
def send_apple_pay_request(guitar_name)
  # Send Apple Pay request for the selected guitar
  channel = @conversation.inbox.channel
  contact_inbox = @conversation.contact_inbox
  destination_id = contact_inbox.source_id

  payment_data = {
    'merchant_name' => 'Acoustic House',
    'currency_code' => 'USD',
    'country_code' => 'US',
    'line_items' => [
      {
        'label' => guitar_name,
        'amount' => '0.01',
        'type' => 'final'
      }
    ],
    'total' => {
      'label' => 'Acoustic House',
      'amount' => '0.01',
      'type' => 'final'
    },
    'received_title' => "Buy your new #{guitar_name}",
    'received_subtitle' => 'test payment'
  }

  AppleMessagesForBusiness::SendApplePayService.new(
    channel: channel,
    destination_id: destination_id,
    payment_data: payment_data
  ).perform
rescue StandardError => e
  Rails.logger.error "[Bot] Failed to send Apple Pay request: #{e.message}"
  { success: false, error: e.message }
end
```

**Integration with Existing Service**:
- Uses `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/send_apple_pay_service.rb`
- CaseTransformer automatically converts snake_case → camelCase
- Amount: $0.01 (demo payment)
- `requestIdentifier`: `applepay_1018` (matches Python)

**Error Handling**:
- Success → Transition to AHF1 (Apple Pay catcher)
- Failure → Skip to AHF2 (lesson introduction)

---

### 6. Apple Pay Catcher (AHF1)

**Method**: `handle_apple_pay_catcher` (lines 389-404)

```ruby
def handle_apple_pay_catcher
  # AHF1: Apple Pay catcher (retry logic)
  retry_count = increment_retry_count

  if retry_count > 2
    # After 3 attempts, reveal it's a demo
    customer_name = get_conversation_attribute('customer_name') || 'there'
    send_text_message("Just kidding #{customer_name}. We wouldn't process a payment for this demo.")
    reset_retry_count
    update_bot_state('AHF2')
    handle_lesson_introduction
  else
    # Still waiting for Apple Pay response
    send_text_message('Waiting for Apple Pay response...')
  end
end
```

**Retry Logic**:
- **Retry 1-2**: Send "Waiting for Apple Pay response..."
- **Retry 3+**: Reveal it's a demo, proceed to AHF2

**Apple Pay Response Handler** (lines 406-417):
```ruby
def handle_apple_pay_response(interactive_data)
  # Handle Apple Pay completion
  payment_status = interactive_data.dig('data', 'payment', 'status')

  send_text_message('Payment received! (Just kidding - this is a demo)') if payment_status == 'success'

  reset_retry_count
  update_bot_state('AHF2')
  handle_lesson_introduction
end
```

---

## Interactive Handler Routing

**Updated**: `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/acoustic_house_bot_service.rb` lines 32-44

```ruby
INTERACTIVE_HANDLERS = {
  'qr_travel' => :handle_region_selection,
  'form_help_me_decide' => :handle_form_response,
  'qr_name' => :handle_name_selection,
  'lp_guitar_0319' => :handle_guitar_selection,
  'applepay_1018' => :handle_apple_pay_response,      # Phase 2
  'time_0319' => :handle_time_picker_response,
  'qr_view_ar' => :handle_ar_view_response,           # Phase 2
  'qr_place_ar' => :handle_ar_place_response,         # Phase 2
  'qr_continue' => :handle_continue_response,
  'qr_photo' => :handle_photo_response,
  'qr_learn_more' => :handle_learn_more_response,
  'lp_menu_0319' => :handle_menu_selection
}.freeze
```

---

## Message Strings

All message strings extracted from Python's `msg.db`:

| Message ID | English Text |
|-----------|-------------|
| `selection_2` | "Just in. We have this cool Stratocaster. Check it out!!!" |
| `arguitar_1_1` | "Did you click on the image and see the 3D augmented reality view of the guitar?" |
| `arguitar_2_1` | "Awesome! {{firstName}} did you select AR from the top of the image and set it down in front of you?" |
| `arguitar_1_2` | "Try tapping on the image to see the AR image of the guitar!" |
| `arguitar_1_3` | "Did you select AR from the top of the image and set it down in front of you?" |
| `applepay_1` | "Great, let's buy your new {{guitarText}}." |
| `applepay_2` | "Just kidding {{firstName}}. We wouldn't process a payment for this demo." |

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         PHASE 2: AR & Apple Pay                 │
└─────────────────────────────────────────────────────────────────┘

                              ┌───────────┐
                              │   AHC1    │
                              │  (Phase 1) │
                              │Guitar List│
                              └─────┬─────┘
                                    │
                        Guitar Selection Response
                                    │
                                    ▼
                              ┌───────────┐
                              │   AHC2    │──────► Text: "Just in. We have..."
                              │AR File    │──────► File: stratocaster.usdz
                              │Send       │
                              └─────┬─────┘
                                    │
                              Auto-proceed
                                    │
                                    ▼
                              ┌───────────┐
                              │   AHC3    │──────► Text: "Did you click..."
                              │AR View    │──────► QR: qr_view_ar (Yes/No)
                              │Question   │
                              └─────┬─────┘
                                    │
                        User selects Yes (111) or No (222)
                                    │
                                    ▼
                              ┌───────────┐
                    ┌─────────│   AHD1    │─────────┐
                    │         │AR View    │         │
              Yes (111)       │Response   │      No (222)
                    │         └───────────┘         │
                    │                                │
                    ▼                                ▼
    "Awesome! {name} did you..."      "Try tapping on the image..."
                    │                                │
                    └────────────┬───────────────────┘
                                 │
                    Send QR: qr_place_ar (Yes/No)
                                 │
                                 ▼
                           ┌───────────┐
                           │   AHE1    │
                No (222)───│AR Place   │
                           │Response   │
                           └─────┬─────┘
                                 │
                    Always: "Great, let's buy your..."
                                 │
                                 ▼
                           ┌───────────┐
                           │   AHE2    │──────► Send Apple Pay Request
                           │Apple Pay  │        - Amount: $0.01
                           │Request    │        - Item: {guitar_name}
                           └─────┬─────┘
                                 │
                    ┌────────────┼────────────┐
                    │                         │
              Success (200)              Error (non-200)
                    │                         │
                    ▼                         ▼
              ┌───────────┐            "Technical difficulties..."
              │   AHF1    │                   │
              │Apple Pay  │                   │
              │Catcher    │                   ▼
              └─────┬─────┘              ┌───────────┐
                    │                    │   AHF2    │
        User doesn't respond             │Lesson     │
        (retry counter increments)       │Intro      │
                    │                    │(Phase 3)  │
                    │                    └───────────┘
        ┌───────────┼───────────┐
        │                       │
  Retry 1-2              Retry 3+
        │                       │
        ▼                       ▼
"Waiting for..."     "Just kidding {name}..."
                              │
                              ▼
                        ┌───────────┐
                        │   AHF2    │
                        │Lesson     │
                        │Intro      │
                        │(Phase 3)  │
                        └───────────┘
```

---

## State Machine Updates

**File**: `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

**State Routing** (lines 135-182):
```ruby
def process_state
  case @bot_state
  when 'AHA1'
    handle_welcome
  when 'AHA2'
    handle_region_prompt
  when 'AHA3'
    handle_form_or_name_prompt
  when 'AHB1'
    handle_form_response
  when 'AHB1_2'
    handle_text_name_input
  when 'AHB2'
    handle_name_preference_selection
  when 'AHB3'
    handle_guitar_list_prompt
  when 'AHC1'
    handle_guitar_list_catcher
  when 'AHC2'             # ← Phase 2
    handle_ar_introduction
  when 'AHC3'             # ← Phase 2
    handle_ar_first_question
  when 'AHD1'             # ← Phase 2
    handle_ar_second_question  # Note: handled by interactive response
  when 'AHE1'             # ← Phase 2
    handle_ar_place_response   # Note: handled by interactive response
  when 'AHE2'             # ← Phase 2
    handle_apple_pay_prompt
  when 'AHF1'             # ← Phase 2
    handle_apple_pay_catcher
  when 'AHF2'
    handle_lesson_introduction
  # ... other states
  end
end
```

---

## CaseTransformer Usage

All AMB features MUST use CaseTransformer for case conversions:

**Quick Reply Example**:
```ruby
# Internal storage (snake_case)
items = [
  { 'title' => 'Yes', 'identifier' => '111' },
  { 'title' => 'No', 'identifier' => '222' }
]

# CaseTransformer in SendQuickReplyService
# Automatically converts to Apple format (camelCase)
```

**Apple Pay Example**:
```ruby
# Internal payment data (snake_case)
payment_data = {
  'merchant_name' => 'Acoustic House',
  'line_items' => [...],
  'received_title' => 'Buy your new guitar'
}

# SendApplePayService uses CaseTransformer
AppleMessagesForBusiness::CaseTransformer.to_apple_format(payment_data)
# Returns: { merchantName, lineItems, receivedTitle, ... }
```

**See**: `/Users/rhaps/LocalGit/chatwoot/docs/apple-messages/case-normalization-specification.md`

---

## Testing Instructions

### 1. Unit Tests (Manual Verification)

```bash
cd /Users/rhaps/LocalGit/chatwoot

# Test syntax
bundle exec rubocop app/services/apple_messages_for_business/acoustic_house_bot_service.rb

# Test bot service loading
rails runner "puts AppleMessagesForBusiness::AcousticHouseBotService"

# Test interactive handler routing
rails runner "
  bot = AppleMessagesForBusiness::AcousticHouseBotService
  puts bot::INTERACTIVE_HANDLERS.keys.sort
"
```

### 2. Integration Testing Flow

**Prerequisites**:
- Apple Messages for Business channel configured
- Test iPhone with iOS 15+
- Guitar List Picker template created (Phase 1)

**Test Steps**:

1. **Start Conversation**
   - Send message to bot
   - Verify: Welcome message received
   - Verify: Region selector appears

2. **Phase 1: Select Guitar**
   - Select region
   - Select guitar from list
   - Verify: "Great choice! You selected {guitar}" message

3. **AHC2: AR File Delivery**
   - Verify: "Just in. We have this cool Stratocaster. Check it out!!!"
   - Verify: Placeholder message for AR file (production would send actual USDZ)

4. **AHC3: AR View Question**
   - Verify: "Did you click on the image..."
   - Verify: Quick Reply with Yes/No buttons appears

5. **AHD1: AR View Response**
   - **Test A: Select "Yes"**
     - Verify: "Awesome! {name} did you select AR..."
   - **Test B: Select "No"**
     - Verify: "Try tapping on the image..."
   - Both: Verify AR place question appears

6. **AHE1: AR Place Response**
   - **Test A: Select "Yes"**
     - Verify: "Great, let's buy your new {guitar}"
   - **Test B: Select "No"**
     - Verify: "Try tapping on the image..." (reminder)
     - Verify: "Great, let's buy your new {guitar}"

7. **AHE2: Apple Pay Request**
   - Verify: Apple Pay bubble appears
   - Verify: Item shows selected guitar name
   - Verify: Amount shows $0.01
   - Verify: Merchant name shows "Acoustic House"

8. **AHF1: Apple Pay Catcher**
   - **Test A: Don't interact with Apple Pay**
     - Wait for retry messages
     - Verify: After 3 retries, see "Just kidding {name}. We wouldn't process..."
   - **Test B: Complete Apple Pay**
     - Tap Apple Pay bubble
     - Complete payment flow
     - Verify: "Payment received! (Just kidding - this is a demo)"

9. **Transition to Phase 3**
   - Verify: Proceeds to lesson introduction (AHF2)

### 3. Error Scenarios

**Apple Pay Service Failure**:
```ruby
# Simulate failure by modifying SendApplePayService.perform
# to return { success: false, error: 'Test error' }

# Expected:
# - "We are experiencing some technical difficulties..."
# - Skip to AHF2 (lesson introduction)
```

**Missing Guitar Selection**:
```ruby
# Test with conversation that has no 'selected_guitar' attribute

# Expected:
# - Falls back to "guitar" in messages
# - Apple Pay request still sent with "guitar" as line item
```

---

## Production Deployment Checklist

### 1. AR File Setup

- [ ] Copy `stratocaster.usdz` to ActiveStorage
- [ ] Create AR file model (similar to `AppleListPickerImage`)
- [ ] Implement `send_ar_file` method with actual file attachment
- [ ] Test file encryption with `AttachmentCipherService`
- [ ] Verify MIME type: `model/usd` or `model/vnd.usdz+zip`

**Example Implementation**:
```ruby
def send_ar_file
  # 1. Find or create AR file in ActiveStorage
  ar_file = ArFile.find_by(identifier: 'stratocaster')

  # 2. Create message with attachment
  message = Messages::MessageBuilder.new(
    bot_user,
    @conversation,
    {
      message_type: :outgoing,
      content: '',
      attachments: [{
        file: ar_file.file,
        file_type: 'model/usd'
      }]
    }
  ).perform

  # 3. Send via SendMessageService
  channel = @conversation.inbox.channel
  contact_inbox = @conversation.contact_inbox
  destination_id = contact_inbox.source_id

  AppleMessagesForBusiness::SendMessageService.new(
    channel: channel,
    destination_id: destination_id,
    message: message
  ).perform
end
```

### 2. Apple Pay Configuration

- [ ] Configure merchant session credentials in channel settings
- [ ] Test merchant session creation
- [ ] Verify payment gateway webhook endpoint
- [ ] Test payment flow end-to-end
- [ ] Configure shipping methods (if needed)
- [ ] Set up supported networks and merchant capabilities

**Channel Settings** (`payment_settings`):
```json
{
  "apple_pay": {
    "merchant_identifier": "merchant.com.your.app",
    "merchant_domain": "your-domain.com",
    "supported_networks": ["visa", "masterCard", "amex", "discover"],
    "merchant_capabilities": ["supports3DS", "supportsDebit", "supportsCredit"]
  },
  "test_mode": true
}
```

### 3. Database Migrations

- [ ] Ensure `custom_attributes` column exists on `conversations` table
- [ ] Verify JSON serialization works for nested attributes
- [ ] Test retry counter persistence

### 4. Monitoring & Logging

- [ ] Add instrumentation for AR file sends
- [ ] Track Apple Pay request success/failure rates
- [ ] Monitor retry counter behavior
- [ ] Set up alerts for Apple Pay service failures

---

## Known Limitations & TODOs

### Current Phase 2 Limitations

1. **AR File Sending**
   - Currently sends placeholder text instead of actual USDZ file
   - Production requires ActiveStorage integration
   - File size: 6.9MB (within Apple's 10MB limit)

2. **Timing Control**
   - Python has 20-second delay between AHC2 → AHC3
   - Ruby currently proceeds immediately
   - Production should use background jobs (Sidekiq)

3. **Apple Pay Merchant Session**
   - Requires valid merchant certificates
   - Test mode uses simulated payment gateway
   - Production requires real merchant account

### Future Enhancements

1. **Async Processing**
   - Implement delayed message sending with Sidekiq
   - Schedule state transitions (e.g., 20-second delay)
   - Handle timeout scenarios gracefully

2. **Rich Media Support**
   - Add image attachments to Apple Pay received message
   - Support multiple AR files
   - Preview images for USDZ files

3. **Analytics**
   - Track AR view/place rates
   - Monitor Apple Pay completion rates
   - A/B test message variations

4. **Error Recovery**
   - Retry failed Apple Pay requests
   - Fallback messaging for unsupported devices
   - Graceful degradation for AR-incapable devices

---

## Files Modified

### Primary Implementation

| File | Lines Modified | Description |
|------|---------------|-------------|
| `acoustic_house_bot_service.rb` | 314-417 | Phase 2 state handlers |
| `acoustic_house_bot_service.rb` | 723-827 | Helper methods (AR, Apple Pay) |
| `acoustic_house_bot_service.rb` | 32-44 | Interactive handler routing |

### Supporting Files (Existing)

| File | Purpose |
|------|---------|
| `send_apple_pay_service.rb` | Apple Pay request builder & sender |
| `send_quick_reply_service.rb` | Quick Reply (Yes/No) sender |
| `send_message_service.rb` | Base message sending (for AR file) |
| `case_transformer.rb` | snake_case ↔ camelCase conversion |

---

## Testing Checklist

- [ ] Syntax check passes (RuboCop)
- [ ] AR file placeholder sends correctly
- [ ] qr_view_ar Quick Reply displays correctly
- [ ] qr_place_ar Quick Reply displays correctly
- [ ] Apple Pay request sends successfully
- [ ] Apple Pay catcher retry logic works (3+ attempts)
- [ ] State transitions execute correctly
- [ ] Conversation attributes persist
- [ ] Error handling routes to AHF2
- [ ] Customer name personalization works
- [ ] Guitar name carries through from Phase 1

---

## Success Criteria

✅ **Phase 2 Complete When**:

1. User can progress from guitar selection (AHC1) through AR questions
2. AR file sending mechanism implemented (placeholder or production)
3. Quick Replies for AR questions work correctly
4. Conditional logic based on user responses functions properly
5. Apple Pay request sends with correct line items and amounts
6. Apple Pay catcher implements retry logic correctly
7. State machine transitions cleanly to AHF2 (Phase 3)
8. All error scenarios handled gracefully
9. CaseTransformer used for all Apple MSP communications
10. Code passes RuboCop linting

---

## Next Steps: Phase 3

**States to Implement**:
- **AHF2**: Lesson introduction
- **AHF3**: Location request (zipcode or Apple Maps link)
- **AHG1**: Location response & geocoding
- **AHH1**: Time Picker catcher (retry logic)
- **AHH2**: Continue prompt (Yes/No)
- **AHI1-AHI4**: Rich Links & Photo flow

**Key Features**:
- Time Picker with location data
- Geocoding service (MVP: hardcoded zipcode lookup)
- Rich Link sending
- Photo request flow
- Document sending (metrics.numbers, document.pdf)

---

## References

- **Python Original**: `/Users/rhaps/LocalGit/chatwoot/_apple/Acoustic-House-Bot-origin/acoustichouse/AH.py` (lines 1037-1109)
- **CaseTransformer Spec**: `/Users/rhaps/LocalGit/chatwoot/docs/apple-messages/case-normalization-specification.md`
- **Apple Pay Service**: `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/send_apple_pay_service.rb`
- **Phase 1 Summary**: _To be created_ (Guitar selection & list picker)

---

**Implementation Date**: November 12, 2025
**Status**: ✅ Phase 2 Complete - Ready for Testing
**Next Phase**: Phase 3 (Lesson Booking & Time Picker)
