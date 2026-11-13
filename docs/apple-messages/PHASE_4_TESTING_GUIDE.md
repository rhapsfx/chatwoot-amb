# Phase 4 Complete Testing Guide

## Acoustic House Bot - End-to-End Testing (Phases 1-4)

**Test Date**: _______________
**Tester**: _______________
**Environment**: [ ] Development [ ] Staging [ ] Production

---

## Pre-Test Setup

### 1. Create Summary Template

```bash
cd /Users/rhaps/LocalGit/chatwoot
rails runner script/create_summary_list_picker_template.rb
```

**Expected Output**: ✅
```
✓ Found account: Chatwoot (ID: X)
✓ Encoded 13 images
✓ Created 13 items
✅ Template created successfully!
```

**Verify**:
```bash
rails runner "puts MessageTemplate.where(name: 'Summary List Picker').count"
# Should output: 1
```

### 2. Verify Guitar List Picker Template Exists

```bash
rails runner "puts MessageTemplate.where(name: 'Guitar List Picker').count"
# Should output: 1
```

If not, create it using the Phase 1 script.

### 3. Configure Apple Messages Channel

- [ ] Apple Messages inbox created
- [ ] AMB channel connected to Apple MSP
- [ ] Bot enabled (custom_attributes: `bot_enabled: true`)
- [ ] Test device configured

---

## Complete Flow Test (Phases 1-4)

### Phase 1: Welcome & Guitar Selection (AHA-AHC)

#### **Test 1.1: Welcome Message** (AHA1)
- [ ] Open conversation with bot
- [ ] Bot sends: "Thank you for contacting Acoustic Bot Prod."
- [ ] Bot sends: "Let's help you find your next guitar 🎸."
- [ ] **State**: AHA2

#### **Test 1.2: Region Selection** (AHA2)
- [ ] Bot sends: "Which region are you traveling from?"
- [ ] Quick Reply appears with: Americas | Europe | Asia Pacific
- [ ] Select: **Americas**
- [ ] Bot responds: "Great! You selected Americas."
- [ ] **State**: AHA3

#### **Test 1.3: Name Collection** (AHA3-AHB)
- [ ] Bot sends: "Tell us about yourself!"
- [ ] *(Future: Form appears here)*
- [ ] For now, type your name: **"Test User"**
- [ ] **State**: AHB3

#### **Test 1.4: Guitar List Picker** (AHB3-AHC1)
- [ ] Bot sends: "Here are some amazing guitars:"
- [ ] List picker appears with 4 guitars + images
- [ ] Select: **Martin DC28E Dreadnought**
- [ ] Bot responds: "Great choice! You selected Martin DC28E Dreadnought."
- [ ] **State**: AHC2

---

### Phase 2: AR Experience & Apple Pay (AHC-AHF)

#### **Test 2.1: AR File** (AHC2)
- [ ] Bot sends: "Just in. We have this cool Stratocaster. Check it out!!!"
- [ ] AR file placeholder message appears
- [ ] *(Future: Actual USDZ file should display)*
- [ ] **State**: AHC3

#### **Test 2.2: AR View Question** (AHC3-AHD1)
- [ ] Bot sends: "Did you click on the image and see the 3D augmented reality view of the guitar?"
- [ ] Quick Reply appears: Yes | No
- [ ] Select: **Yes**
- [ ] Bot responds: "Awesome! Test User did you select AR from the top of the image and set it down in front of you?"
- [ ] **State**: AHE1

#### **Test 2.3: AR Place Question** (AHE1)
- [ ] Quick Reply appears: Yes | No
- [ ] Select: **Yes**
- [ ] Bot responds: "Great, let's buy your new Martin DC28E Dreadnought."
- [ ] **State**: AHE2

#### **Test 2.4: Apple Pay Request** (AHE2-AHF1)
- [ ] Apple Pay bubble appears
- [ ] Amount: $0.01
- [ ] Item: Martin DC28E Dreadnought
- [ ] Tap once (don't authorize)
- [ ] **State**: AHF1

#### **Test 2.5: Apple Pay Catcher** (AHF1)
- [ ] Send any text message
- [ ] Bot sends: "Waiting for Apple Pay response..."
- [ ] Send another message
- [ ] Send a third message
- [ ] Bot sends: "Just kidding Test User. We wouldn't process a payment for this demo."
- [ ] **State**: AHF2

---

### Phase 3: Lesson Booking & Time Picker (AHF-AHI)

#### **Test 3.1: Lesson Introduction** (AHF2-AHG1)
- [ ] Bot sends: "However, let's schedule a lesson with your new Martin DC28E Dreadnought."
- [ ] Bot sends: "We can find the closest location for you, just message us your zipcode. Where are you?"
- [ ] **State**: AHG1

#### **Test 3.2: Location Response** (AHG1-AHH1)
- [ ] Type zipcode: **95014** (Apple Park)
- [ ] Bot sends: "We were unable to locate your nearest Apple Store, so here are the available times at Apple Park."
- [ ] Time picker appears with 6 timeslots
- [ ] **State**: AHH1

#### **Test 3.3: Time Picker Selection** (AHH1-AHH2)
- [ ] Select any timeslot
- [ ] Bot responds: "Thank you for your co-operation, you're all set to learn to shred. 🤘"
- [ ] Bot sends: "Shall we continue?"
- [ ] Quick Reply appears: Yes | No
- [ ] **State**: AHI1

#### **Test 3.4: Continue to Rich Links** (AHI1-AHI4)
- [ ] Select: **Yes**
- [ ] Bot sends: "There's so much more you can do like sharing beautiful links to your website:"
- [ ] Rich link appears (Apple Messages for Business docs)
- [ ] Bot sends: "Earlier we sent you a photo."
- [ ] Bot sends: "You can send us one too!!! Test User will you share a picture of your favorite food or place to eat?"
- [ ] Quick Reply appears: Yes | No
- [ ] **State**: AHJ1 (Phase 4 begins)

---

### Phase 4: Photo Response, Documents & Summary (AHJ-AHK)

#### **Test 4.1: Photo Response** (AHJ1-AHJ2)
- [ ] Select: **Yes** (or upload a photo)
- [ ] Bot responds: "Awesome! We will hang tight while you send us your fav."
- [ ] Bot sends: "In Messages for Business, we can also share documents like these forms."
- [ ] **State**: AHJ2

#### **Test 4.2: Document Sharing - Numbers File** (AHJ2-AHJ3)
- [ ] Metrics.numbers file sent (or placeholder message)
- [ ] *(Future: Actual file should be downloadable)*
- [ ] **State**: AHJ3

#### **Test 4.3: Document Sharing - PDF File** (AHJ3-AHJ4)
- [ ] Document.pdf file sent (or placeholder message)
- [ ] *(Future: Actual PDF should be downloadable)*
- [ ] Bot sends: "Test User, would you like to learn more about Messages for Business?"
- [ ] Quick Reply appears: Yes | No
- [ ] **State**: AHJ4

#### **Test 4.4: Learn More Response** (AHJ4-AHK1)
**Scenario A: Select "Yes"**
- [ ] Select: **Yes**
- [ ] Bot responds: "Please connect with your Apple rep for more information."
- [ ] Bot sends: "We've thrown a handful of Messages for Business features at you today. Check out what you saw."
- [ ] **State**: AHK1
- [ ] Proceed to Test 4.5

**Scenario B: Select "No"**
- [ ] Select: **No**
- [ ] Bot sends: "We've thrown a handful of Messages for Business features at you today. Check out what you saw."
- [ ] **State**: AHK1
- [ ] Proceed to Test 4.5

#### **Test 4.5: Summary List Picker** (AHK1-AHK2) ⭐ **CRITICAL TEST**
- [ ] **List picker appears** with:
  - **Title**: "Select a Feature to Learn More"
  - **Received bubble**: "Feature Sheet"
  - **Subtitle**: "Key features that you were exposed to."
  - **Image**: Summary icon (identifier 0)
- [ ] **Verify 13 items visible** in list:
  1. [ ] 1. Apple Pay (with image)
  2. [ ] 2. Apple Wallet (with image)
  3. [ ] 3. AR Experience (with image)
  4. [ ] 4. Authentication (with image)
  5. [ ] 5. File Sharing (with image)
  6. [ ] 6. iMessage Apps (with image)
  7. [ ] 7. List Picker (with image)
  8. [ ] 8. Media Sharing (with image)
  9. [ ] 9. QR Code Origination (with image)
  10. [ ] 10. Quick Type Keyboard (with image)
  11. [ ] 11. Rich Link Locator (with image)
  12. [ ] 12. Rich Website Links (with image)
  13. [ ] 13. Time Picker (with image)
- [ ] **All images load correctly** (no broken icons)
- [ ] Select any item (e.g., "1. Apple Pay")
- [ ] Reply bubble appears: "Response - Tap this message to view your selection"
- [ ] **State**: AHK2

#### **Test 4.6: Final Message** (AHK2-AHK3)
- [ ] Bot sends: "A great first step will be to visit our Register site to get started."
- [ ] **State**: AHK3

#### **Test 4.7: Register Rich Link & Flow Reset** (AHK3-AH-restart) ⭐ **CRITICAL TEST**
- [ ] **Rich link appears**:
  - URL: https://register.apple.com/business-chat
  - Image: heroImage.png
  - Title: "Apple Messages for Business"
- [ ] Bot sends: "We will get back to you soon 😀"
- [ ] **State**: AH-restart
- [ ] **Flow automatically resets** to AHA1
- [ ] Bot sends welcome message again (starts over)

---

## Attachment Handling Tests

### Test 5.1: Photo Upload During Flow
**Setup**: Progress to AHI or AHJ state

- [ ] Upload a photo (any image file)
- [ ] Bot responds: "Awesome photo! #photooftheday #instadaily"
- [ ] Bot proceeds to AHJ2 (document sharing)
- [ ] **State**: AHJ2

### Test 5.2: Numbers File Upload
**Setup**: Any state

- [ ] Upload a `.numbers` file
- [ ] Bot responds: "Thank you for the spreadsheet."
- [ ] **State**: Unchanged

---

## Edge Case Tests

### Test 6.1: Flow Timeout (30 minutes)
- [ ] Start conversation
- [ ] Wait 31 minutes
- [ ] Send any message
- [ ] Bot resets to welcome (AHA1)
- [ ] ✅ Flow successfully restarted

### Test 6.2: Keyword Commands
**Test "menu"**:
- [ ] Type: `menu`
- [ ] Bot shows menu options
- [ ] ✅ Menu command works

**Test "startover"**:
- [ ] Progress to middle of flow (e.g., AHE1)
- [ ] Type: `startover`
- [ ] Bot resets to AHA1
- [ ] ✅ Startover command works

**Test "summary"** (from AHK1 state):
- [ ] Type: `summary`
- [ ] Bot shows summary list picker
- [ ] ✅ Summary command works

### Test 6.3: Invalid Inputs
**Guitar selection catcher**:
- [ ] Reach AHC1 (guitar list displayed)
- [ ] Send random text (don't select from list)
- [ ] Bot sends: "Please select a guitar from the list above."
- [ ] Send another message
- [ ] Bot sends: "Looks like we're waiting for you to select a guitar from the list."
- [ ] Send a third message
- [ ] Bot re-sends guitar list picker
- [ ] ✅ Catcher logic works

---

## Performance Tests

### Test 7.1: Summary List Picker Load Time
- [ ] Reach AHK1 state
- [ ] Note time when summary is triggered
- [ ] Note time when list picker appears
- [ ] **Load time**: _______ seconds
- [ ] ✅ Should be < 3 seconds

### Test 7.2: Document Send Time
- [ ] Reach AHJ2/AHJ3 state
- [ ] Note time when documents are sent
- [ ] **Send time**: _______ seconds
- [ ] ✅ Should be < 5 seconds each

### Test 7.3: Complete Flow Duration
- [ ] Start at AHA1
- [ ] Progress to AHK3 completion
- [ ] **Total time**: _______ minutes
- [ ] ✅ Should be < 5 minutes for fast progression

---

## Known Issues to Verify

### Issue 1: Document Sending (TODO)
- [ ] **Expected**: Actual .numbers and .pdf files sent
- [ ] **Actual**: Placeholder log messages
- [ ] **Status**: ⚠️ TODO - ActiveStorage implementation needed

### Issue 2: Rich Link Sending (TODO)
- [ ] **Expected**: Actual rich link with image
- [ ] **Actual**: Placeholder log message
- [ ] **Status**: ⚠️ TODO - RichLinkService implementation needed

### Issue 3: Summary Item Selection Handler
- [ ] **Expected**: Bot responds to selected summary item
- [ ] **Actual**: No response after selection
- [ ] **Status**: ⚠️ Optional - Handler not implemented

---

## Bug Report Template

**Bug ID**: _______________
**Test Step**: _______________
**Expected Behavior**: _______________
**Actual Behavior**: _______________
**State When Bug Occurred**: _______________
**Attachments**: (Screenshots, logs)

**Severity**: [ ] Critical [ ] High [ ] Medium [ ] Low

---

## Test Results Summary

**Total Tests**: 40+
**Passed**: _____ / _____
**Failed**: _____ / _____
**Skipped**: _____ / _____

**Critical Tests Passed**:
- [ ] Summary List Picker (13 items with images)
- [ ] Rich Link Display
- [ ] Flow Reset (AH-restart)
- [ ] Attachment Handler

**Overall Status**: [ ] ✅ PASS [ ] ⚠️ PASS WITH ISSUES [ ] ❌ FAIL

**Notes**:
_______________________________________________
_______________________________________________
_______________________________________________

---

## Production Deployment Checklist

After successful testing:

- [ ] Run template creation script on production
- [ ] Verify all 13 images load correctly
- [ ] Test complete flow end-to-end on production
- [ ] Implement document sending (ActiveStorage)
- [ ] Implement rich link sending
- [ ] Monitor bot performance for 24 hours
- [ ] Review error logs
- [ ] Update documentation with production URLs

---

**Test Completed By**: _______________
**Date**: _______________
**Signature**: _______________
