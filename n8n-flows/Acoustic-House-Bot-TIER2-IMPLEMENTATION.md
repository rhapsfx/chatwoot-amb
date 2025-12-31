# Tier 2 Flows Implementation for Acoustic House Bot

## Summary

This document tracks the implementation of Tier 2 flows (Rich Links, Documents, and Summary flows) for the Acoustic House Bot n8n migration.

## Implementation Plan

### Phase 1: Router Updates
- Add route handlers for: continue_yes, continue_no, photo_yes, photo_no, learn_more_yes, learn_more_no
- Add boolean flags: isContinueYes, isContinueNo, isPhotoYes, isPhotoNo, isLearnMoreYes, isLearnMoreNo

### Phase 2: Tier 2.1 - Rich Links Flow (AHI2, AHI3, AHI4)
**Nodes Added:**
1. AHI2 - Rich Link Message (HTTP Request) - Send Apple Messages documentation rich link
2. AHI3 - Photo Transition (HTTP Request) - "Earlier we sent you a photo"
3. AHI4 - Ask for Photo (HTTP Request) - Ask to share favorite food photo
4. AHI4 - Photo Quick Reply - Yes/No quick reply
5. Set State: photo_asked

**Route: Continue Yes → AHI2 → AHI3 → AHI4**

### Phase 3: Tier 2.2 - Documents Flow (AHJ1, AHJ2, AHJ3, AHJ4)
**Nodes Added:**
1. Check: Is Photo Response? (router check)
2. AHJ1 - Parse Photo Response (Code node)
3. AHJ1 - Photo Yes: Wait for Photo (HTTP Request)
4. AHJ1 - Photo No: Send Anytime Message (HTTP Request)
5. AHJ2 - Documents Intro (HTTP Request) - "In Business Chat, we can share documents..."
6. AHJ2 - Send Numbers File (Template Message) - metrics.numbers
7. AHJ3 - Send PDF (Template Message) - document.pdf
8. AHJ4 - Learn More Question (HTTP Request)
9. AHJ4 - Learn More Quick Reply - Yes/No
10. Set State: learn_more_asked

**Route: Photo Yes → Wait / Photo No → Documents → Learn More Question**

### Phase 4: Tier 2.3 - Summary & Wrap-up (AHK1, AHK2, AHK3)
**Nodes Added:**
1. Check: Is Learn More Response? (router check)
2. AHK1 - Parse Learn More Response (Code node)
3. AHK1 - Summary Intro (HTTP Request) - "We've thrown a handful..."
4. AHK1 - Summary List Picker (Template Message) - 13 feature images
5. AHK2 - Register Site Intro (HTTP Request) - "Visit our Register site..."
6. AHK3 - Register Rich Link (HTTP Request with rich link)
7. AHK3 - Final Message (HTTP Request) - "We will get back to you soon"
8. Set State: flow_complete

**Route: Learn More Yes → Summary → Register → Complete**
**Route: Continue No → Summary (skip rich links)**

## Node Count Summary

**Total New Nodes**: ~28 nodes
- Router checks: 3
- Code parsers: 3
- HTTP messages: 12
- Quick Replies: 3
- Template Messages: 3
- State setters: 4

## Flow Diagram

```
Apple Pay
  ↓
AHF2 → AHF3 → Set State location_requested
              ↓
         [Location input]
              ↓
         AHG1 Parse Location → Time Picker
                                    ↓
                              Confirm Appointment
                                    ↓
                              AHH2 Lesson Confirmation
                                    ↓
                              AHH2 Continue Question (QR: Yes/No)
                                    ↓
                              Set State: continue_asked
                                    ↓
                    ┌─────────────────┴─────────────────┐
                    ↓                                     ↓
              Continue Yes                         Continue No
                    ↓                                     ↓
            [Tier 2.1: Rich Links]                   [Skip to AHK1]
                    ↓
              AHI2 - Rich Link (Apple Docs)
                    ↓
              AHI3 - Photo Transition
                    ↓
              AHI4 - Ask for Photo (QR: Yes/No)
                    ↓
              Set State: photo_asked
                    ↓
        ┌───────────┴───────────┐
        ↓                       ↓
    Photo Yes               Photo No
        ↓                       ↓
    AHJ1 - Wait          AHJ1 - Anytime msg
        ↓                       ↓
        └───────────┬───────────┘
                    ↓
            [Tier 2.2: Documents]
                    ↓
          AHJ2 - Documents Intro
                    ↓
          AHJ2 - Send Numbers File
                    ↓
          AHJ3 - Send PDF
                    ↓
          AHJ4 - Learn More Question (QR: Yes/No)
                    ↓
          Set State: learn_more_asked
                    ↓
        ┌───────────┴───────────┐
        ↓                       ↓
  Learn More Yes          Learn More No
        ↓                       ↓
        └───────────┬───────────┘
                    ↓
            [Tier 2.3: Summary]
                    ↓
          AHK1 - Summary Intro
                    ↓
          AHK1 - Summary List Picker (13 features)
                    ↓
          AHK2 - Register Site Intro
                    ↓
          AHK3 - Register Rich Link
                    ↓
          AHK3 - Final Message
                    ↓
          Set State: flow_complete
                    ↓
                  [END]
```

## Router Logic Updates

Add to Router with State node's jsCode:

```javascript
// Add after existing quick reply handling
else if (reply === 'continue_yes' || reply === 'continue_no') {
  if (customAttrs.bot_state === 'continue_asked') {
    route = reply === 'continue_yes' ? 'CONTINUE_YES' : 'CONTINUE_NO';
    nextState = reply === 'continue_yes' ? 'rich_links_start' : 'summary_start';
  }
} else if (reply === 'photo_yes' || reply === 'photo_no') {
  if (customAttrs.bot_state === 'photo_asked') {
    route = reply === 'photo_yes' ? 'PHOTO_YES' : 'PHOTO_NO';
    nextState = reply === 'photo_yes' ? 'waiting_photo' : 'documents_start';
  }
} else if (reply === 'learn_more_yes' || reply === 'learn_more_no') {
  if (customAttrs.bot_state === 'learn_more_asked') {
    route = reply === 'learn_more_yes' ? 'LEARN_MORE_YES' : 'LEARN_MORE_NO';
    nextState = 'summary_start';
  }
}
```

Add to boolean flags:
```javascript
isContinueYes: route === 'CONTINUE_YES',
isContinueNo: route === 'CONTINUE_NO',
isPhotoYes: route === 'PHOTO_YES',
isPhotoNo: route === 'PHOTO_NO',
isLearnMoreYes: route === 'LEARN_MORE_YES',
isLearnMoreNo: route === 'LEARN_MORE_NO'
```

## Implementation Status

- [x] Planning complete
- [ ] Router updates applied
- [ ] Tier 2.1 nodes created
- [ ] Tier 2.2 nodes created
- [ ] Tier 2.3 nodes created
- [ ] All connections verified
- [ ] Testing complete

## Notes

- Rich link nodes will use CUSTOM.chatwootAMBRichLink if available, or HTTP Request with rich link format
- Template Messages for documents (metrics.numbers, document.pdf) need template IDs
- Summary List Picker needs template with 13 feature images
- Position coordinates need to be calculated to avoid overlaps

## Next Steps

1. Update the main JSON file with router changes
2. Add all Tier 2 nodes
3. Create all connections
4. Test flow in n8n
5. Document any template IDs needed
