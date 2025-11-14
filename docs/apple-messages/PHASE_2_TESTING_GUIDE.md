# Phase 2 Testing Guide: AR File & Apple Pay

**Quick Reference for Testing Phase 2 Implementation**

---

## Pre-Test Setup

### 1. Start Development Server

```bash
cd /Users/rhaps/LocalGit/chatwoot
./dev-server.sh start
```

### 2. Verify Code Syntax

```bash
# Check for syntax errors
bundle exec rubocop app/services/apple_messages_for_business/acoustic_house_bot_service.rb

# Should show: "1 file inspected, no offenses detected"
```

### 3. Test Service Loading

```bash
rails runner "
  bot = AppleMessagesForBusiness::AcousticHouseBotService
  puts 'Bot service loaded successfully'
  puts 'Interactive handlers: ' + bot::INTERACTIVE_HANDLERS.keys.sort.join(', ')
"
```

**Expected Output**:
```
Bot service loaded successfully
Interactive handlers: applepay_1018, form_help_me_decide, lp_guitar_0319, lp_menu_0319, qr_continue, qr_learn_more, qr_name, qr_photo, qr_place_ar, qr_travel, qr_view_ar, time_0319
```

---

## Test Flow: Complete Phase 2 Walkthrough

### Step 1: Start Conversation

**Action**: Open Messages on iPhone, send message to bot

**Expected**:
```
Bot: Thank you for contacting Acoustic Bot Prod.
Bot: Let's help you find your next guitar 🎸.
Bot: Which region are you traveling from?
     [Quick Reply: Americas | Europe | Asia Pacific]
```

**State**: `AHA2`

---

### Step 2: Select Region

**Action**: Tap "Americas"

**Expected**:
```
You: Americas
Bot: Great! You selected Americas.
Bot: Tell us about yourself!
```

**State**: `AHB1`

---

### Step 3: View Guitar List

**Action**: Wait for list picker or send any text message

**Expected**:
```
Bot: Here are some amazing guitars:
     [List Picker with guitar options]
```

**State**: `AHC1`

---

### Step 4: Select Guitar (Phase 1 → Phase 2 Transition)

**Action**: Select "Fender Stratocaster" from list

**Expected**:
```
You: [Fender Stratocaster selected]
Bot: Great choice! You selected Fender Stratocaster.
Bot: Just in. We have this cool Stratocaster. Check it out!!!
Bot: [AR File: stratocaster.usdz would be sent here]
```

**State**: `AHC2` → `AHC3`

**✅ CHECKPOINT**: Phase 2 starts here

---

### Step 5: AR View Question

**Auto-proceeds from Step 4**

**Expected**:
```
Bot: Did you click on the image and see the 3D augmented reality view of the guitar?
     [Quick Reply: Yes | No]
```

**State**: `AHD1` (waiting for response)

---

### Step 6A: AR View Response - YES Path

**Action**: Tap "Yes"

**Expected**:
```
You: Yes
Bot: Awesome! [your name] did you select AR from the top of the image and set it down in front of you?
     [Quick Reply: Yes | No]
```

**State**: `AHE1` (waiting for response)

**Note**: If customer name was captured in Phase 1, it will be personalized. Otherwise shows "there".

---

### Step 6B: AR View Response - NO Path

**Action**: Tap "No"

**Expected**:
```
You: No
Bot: Try tapping on the image to see the AR image of the guitar!
Bot: Did you select AR from the top of the image and set it down in front of you?
     [Quick Reply: Yes | No]
```

**State**: `AHE1` (waiting for response)

---

### Step 7A: AR Place Response - YES Path

**Action**: Tap "Yes"

**Expected**:
```
You: Yes
Bot: Great, let's buy your new Fender Stratocaster.
     [Apple Pay Bubble Appears]
```

**Apple Pay Details**:
- Merchant: Acoustic House
- Item: Fender Stratocaster
- Amount: $0.01
- Subtitle: "test payment"

**State**: `AHE2` → `AHF1`

---

### Step 7B: AR Place Response - NO Path

**Action**: Tap "No"

**Expected**:
```
You: No
Bot: Try tapping on the image to see the AR image of the guitar!
Bot: Great, let's buy your new Fender Stratocaster.
     [Apple Pay Bubble Appears]
```

**Note**: Both Yes/No paths lead to Apple Pay

**State**: `AHE2` → `AHF1`

---

### Step 8A: Apple Pay - Ignore (Catcher Retry Logic)

**Action**: Don't interact with Apple Pay bubble, send random text messages

**Expected**:
```
You: [any text message]
Bot: Waiting for Apple Pay response...
```

**Retry 1**: "Waiting for Apple Pay response..."
**Retry 2**: "Waiting for Apple Pay response..."
**Retry 3+**:
```
Bot: Just kidding [your name]. We wouldn't process a payment for this demo.
Bot: However, let's schedule a lesson with your new Fender Stratocaster.
```

**State**: `AHF1` → `AHF2` (Phase 3)

---

### Step 8B: Apple Pay - Complete Payment

**Action**: Tap Apple Pay bubble, authenticate with Face ID/Touch ID, complete payment

**Expected**:
```
You: [Payment completed]
Bot: Payment received! (Just kidding - this is a demo)
Bot: However, let's schedule a lesson with your new Fender Stratocaster.
```

**State**: `AHF1` → `AHF2` (Phase 3)

**✅ CHECKPOINT**: Phase 2 complete, transitions to Phase 3

---

## Error Scenario Testing

### Scenario 1: Apple Pay Service Failure

**Simulate**: Temporarily disable Apple Pay merchant session

**Expected Flow**:
```
Bot: Great, let's buy your new Fender Stratocaster.
Bot: We are experiencing some technical difficulties with our Apple Pay service. We apologize for this inconvenience and we are working on a fix.
Bot: However, let's schedule a lesson with your new Fender Stratocaster.
```

**State**: `AHE2` → `AHF2` (skips AHF1 catcher)

**Recovery**: Re-enable merchant session for future tests

---

### Scenario 2: Missing Customer Name

**Setup**: Start fresh conversation, don't capture customer name in Phase 1

**Expected**:
- Messages that reference `{{firstName}}` will show "there" instead
- Example: "Awesome! there did you select AR..."

---

### Scenario 3: Missing Guitar Selection

**Setup**: Manually trigger AR flow without going through guitar selection

**Expected**:
- Guitar name falls back to "guitar"
- Messages: "Great, let's buy your new guitar."
- Apple Pay line item: "guitar" instead of specific model

---

## Database Verification

### Check Conversation State

```bash
rails runner "
  conversation = Conversation.last
  attrs = conversation.custom_attributes

  puts 'Bot State: ' + attrs['bot_state'].to_s
  puts 'Selected Guitar: ' + attrs['selected_guitar'].to_s
  puts 'Customer Name: ' + attrs['customer_name'].to_s
  puts 'Retry Count: ' + attrs['retry_count'].to_s
"
```

### Check Message History

```bash
rails runner "
  conversation = Conversation.last
  messages = conversation.messages.order(:created_at).last(10)

  messages.each do |msg|
    puts '[' + msg.message_type + '] ' + msg.content.to_s[0..50]
  end
"
```

---

## Log Monitoring

### Real-time Log Tail

```bash
# Terminal 1: Rails server logs
tail -f /Users/rhaps/LocalGit/chatwoot/log/development.log | grep -E "(Bot|AMB|ApplePay)"

# Terminal 2: Specific service logs
tail -f /Users/rhaps/LocalGit/chatwoot/log/development.log | grep "AcousticHouseBotService"
```

### Key Log Messages to Watch For

**AR File Sending**:
```
[Bot] Sending AR file (stratocaster.usdz)
```

**Apple Pay Request**:
```
[AMB ApplePay] Creating merchant session...
[AMB ApplePay] Merchant session created successfully
[AMB ApplePay] Successfully sent Apple Pay request (message_id: ...)
```

**State Transitions**:
```
Bot state updated: AHC2 → AHC3
Bot state updated: AHC3 → AHD1
Bot state updated: AHD1 → AHE1
Bot state updated: AHE1 → AHE2
Bot state updated: AHE2 → AHF1
Bot state updated: AHF1 → AHF2
```

**Retry Counter**:
```
Retry count incremented: 1
Retry count incremented: 2
Retry count incremented: 3
Retry count reset: 0
```

---

## Quick Debugging Commands

### Reset Conversation State

```bash
rails runner "
  conversation = Conversation.last
  conversation.custom_attributes['bot_state'] = 'AHA1'
  conversation.custom_attributes['retry_count'] = 0
  conversation.save!
  puts 'Conversation reset to welcome state'
"
```

### Manually Trigger State

```bash
# Jump directly to AR introduction
rails runner "
  conversation = Conversation.last
  conversation.custom_attributes['bot_state'] = 'AHC2'
  conversation.custom_attributes['selected_guitar'] = 'Test Guitar'
  conversation.save!
  puts 'Conversation set to AHC2 (AR introduction)'
"
```

### Check Interactive Handler Routing

```bash
rails runner "
  bot = AppleMessagesForBusiness::AcousticHouseBotService

  # Check if handlers exist
  puts 'qr_view_ar handler: ' + bot::INTERACTIVE_HANDLERS['qr_view_ar'].to_s
  puts 'qr_place_ar handler: ' + bot::INTERACTIVE_HANDLERS['qr_place_ar'].to_s
  puts 'applepay_1018 handler: ' + bot::INTERACTIVE_HANDLERS['applepay_1018'].to_s
"
```

---

## Performance Benchmarks

### Expected Response Times

| Action | Expected Time | Notes |
|--------|--------------|-------|
| AR file send | < 500ms | Placeholder text only |
| Quick Reply send | < 200ms | Small JSON payload |
| Apple Pay request | < 2s | Includes merchant session |
| State transition | < 50ms | Database update only |

### Monitor with

```bash
# Time a specific action
time rails runner "
  # Your test code here
"
```

---

## Known Issues & Workarounds

### Issue 1: AR File Not Displaying

**Symptom**: AR file placeholder shows but no actual file

**Cause**: Phase 2 uses placeholder implementation

**Workaround**: Check documentation for production AR file setup
**Reference**: `PHASE_2_AR_APPLE_PAY_IMPLEMENTATION.md` section "Production Deployment Checklist"

---

### Issue 2: Apple Pay Not Appearing

**Symptom**: No Apple Pay bubble after "Great, let's buy..."

**Possible Causes**:
1. Merchant session not configured
2. Apple Pay service error
3. Test device doesn't support Apple Pay

**Debug**:
```bash
# Check merchant session service
rails runner "
  channel = Channel::AppleMessagesForBusiness.last
  service = AppleMessagesForBusiness::MerchantSessionService.new(channel)
  result = service.create_session
  puts result.inspect
"
```

---

### Issue 3: Retry Counter Not Working

**Symptom**: Bot doesn't show "Just kidding..." after 3+ messages

**Debug**:
```bash
rails runner "
  conversation = Conversation.last
  puts 'Current retry count: ' + conversation.custom_attributes['retry_count'].to_s
  puts 'Current bot state: ' + conversation.custom_attributes['bot_state'].to_s
"
```

**Fix**: Ensure bot state is `AHF1` and user is sending text messages (not interactive responses)

---

## Test Coverage Checklist

### Core Functionality
- [ ] AR file sending (placeholder)
- [ ] qr_view_ar Quick Reply displays
- [ ] qr_place_ar Quick Reply displays
- [ ] Apple Pay request sends successfully
- [ ] State transitions execute correctly

### Conditional Logic
- [ ] AR view "Yes" path works
- [ ] AR view "No" path works
- [ ] AR place "Yes" path works
- [ ] AR place "No" path works
- [ ] Both AR place paths lead to Apple Pay

### Error Handling
- [ ] Apple Pay service failure routes to AHF2
- [ ] Missing guitar name falls back to "guitar"
- [ ] Missing customer name falls back to "there"

### Retry Logic
- [ ] Retry counter increments on text messages in AHF1
- [ ] After 3 retries, shows demo reveal message
- [ ] Retry counter resets after revealing demo
- [ ] Apple Pay completion resets counter

### Data Persistence
- [ ] Bot state persists across requests
- [ ] Selected guitar carries from Phase 1
- [ ] Customer name carries from Phase 1
- [ ] Retry count persists correctly

### Phase Transitions
- [ ] Phase 1 (AHC1) → Phase 2 (AHC2) works
- [ ] Phase 2 (AHF1) → Phase 3 (AHF2) works
- [ ] Error paths route correctly to Phase 3

---

## Success Metrics

### Phase 2 Test Passes When:

1. ✅ User can select guitar and see AR introduction
2. ✅ AR view question displays with Yes/No options
3. ✅ Conditional responses work correctly (Yes vs No)
4. ✅ AR place question displays with Yes/No options
5. ✅ Apple Pay request sends with correct guitar name
6. ✅ Retry logic reveals demo after 3+ attempts
7. ✅ Apple Pay completion transitions to Phase 3
8. ✅ Error scenarios handled gracefully
9. ✅ All states transition correctly
10. ✅ Conversation attributes persist properly

---

## Next Steps After Testing

1. **If tests pass**: Proceed to Phase 3 implementation
2. **If AR file issues**: Implement production AR file storage
3. **If Apple Pay issues**: Configure merchant session properly
4. **If state issues**: Review state machine logic

**Phase 3 Preview**:
- Lesson booking introduction
- Location request (zipcode/Apple Maps)
- Time Picker with geocoded location
- Rich Links and photos
- Document sending

---

## Quick Reference Commands

```bash
# Start server
./dev-server.sh start

# Check syntax
bundle exec rubocop app/services/apple_messages_for_business/acoustic_house_bot_service.rb

# Reset conversation
rails runner "Conversation.last.update(custom_attributes: { bot_state: 'AHA1', retry_count: 0 })"

# Check current state
rails runner "puts Conversation.last.custom_attributes.inspect"

# Tail logs
tail -f log/development.log | grep -E "(Bot|AMB)"
```

---

**Last Updated**: November 12, 2025
**Phase**: 2 (AR File & Apple Pay)
**Status**: Ready for Testing
